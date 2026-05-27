//! Unit tests for the host-side syscall translation.

use super::{errno_to_eax, write_syscall, LibcFn, StdHost, SyscallArgs, SyscallResult};
use movie86_core::libc_host::{LibcCall, LibcHost};
use movie86_core::{Fault, FlatMemory, Memory, Reg32};

#[test]
fn errno_to_eax_matches_two_complement() {
    // -32 (EPIPE) in u32 bit pattern.
    assert_eq!(errno_to_eax(32), 0xffff_ffe0);
    assert_eq!(errno_to_eax(1), 0xffff_ffff); // -1
}

#[test]
fn write_with_unknown_fd_returns_negative_ebadf() {
    let mut mem = FlatMemory::new_zeroed(0x1000, 16);
    mem.write_bytes(0x1000, b"hello").unwrap();
    let args = SyscallArgs {
        eax: 4,
        ebx: 99, // bogus fd — not stdout/stderr
        ecx: 0x1000,
        edx: 5,
        esi: 0,
        edi: 0,
        ebp: 0,
    };
    let r = write_syscall(&args, &mut mem).unwrap();
    let SyscallResult::Return(v) = r;
    assert_eq!(
        v,
        errno_to_eax(9),
        "should be -EBADF before any bytes written"
    );
}

#[test]
fn write_with_bad_fd_does_not_dereference_guest_buffer() {
    // The buffer pointer is *unmapped*. Linux returns -EBADF for a bad
    // fd without ever touching the user buffer, so we must do the same
    // — touching it would surface as Fault::Unmapped instead of EBADF.
    let mut mem = FlatMemory::new_zeroed(0x1000, 16);
    let args = SyscallArgs {
        eax: 4,
        ebx: 99,          // bogus fd
        ecx: 0xdead_0000, // unmapped buf pointer
        edx: 64,
        esi: 0,
        edi: 0,
        ebp: 0,
    };
    let r = write_syscall(&args, &mut mem).expect("should not Fault on unmapped buf");
    let SyscallResult::Return(v) = r;
    assert_eq!(v, errno_to_eax(9));
}

#[test]
fn write_with_unmapped_buf_returns_negative_efault() {
    // Linux convention: write(2) with an unreadable user buffer returns
    // -EFAULT, not a hard segfault. We must mirror that — otherwise a
    // guest probing user pointers via syscall reads sees an emulator
    // panic instead of the syscall failure.
    let mut mem = FlatMemory::new_zeroed(0x1000, 16);
    let args = SyscallArgs {
        eax: 4,
        ebx: 1,           // stdout (valid fd, so we pass the fd check)
        ecx: 0xdead_0000, // unmapped buf
        edx: 64,
        esi: 0,
        edi: 0,
        ebp: 0,
    };
    let r = write_syscall(&args, &mut mem).expect("should not Fault on unmapped buf");
    let SyscallResult::Return(v) = r;
    assert_eq!(v, errno_to_eax(14), "-EFAULT (14)");
}

#[test]
fn write_with_huge_count_does_not_pre_allocate_4gb() {
    // The guest claims to want to write 4 GiB, but the buffer is
    // unmapped past the first page. We should not allocate 4 GiB to
    // copy nothing — we should stream in chunks and the FIRST chunk's
    // read_bytes should fault, returning Unmapped to the caller.
    let mut mem = FlatMemory::new_zeroed(0x1000, 4096); // exactly one chunk
    mem.write_bytes(0x1000, &[0xaa; 4096]).unwrap();
    let args = SyscallArgs {
        eax: 4,
        ebx: 99, // bad fd so we don't actually touch stdout in the test
        ecx: 0x1000,
        edx: 0xffff_ffff,
        esi: 0,
        edi: 0,
        ebp: 0,
    };
    // Either Ok(EBADF) (caught before any read) or Err(Unmapped) (if a
    // future change reads first). Either way: NOT a 4 GiB allocation.
    // Asserting no panic is the load-bearing thing here.
    let _ = write_syscall(&args, &mut mem);
}

/// Invoke `host.libc_call` with a synthetic guest layout: stub at
/// `trap_addr`, stack at `esp` pre-staged with cdecl args.
fn libc_call_with_args(
    host: &mut StdHost,
    trap_addr: u32,
    esp: u32,
    args: &[u32],
    mem: &mut FlatMemory,
) -> Result<u32, Fault> {
    mem.write_u32(esp, 0xdead_beef).unwrap(); // retaddr placeholder
    for (i, &v) in args.iter().enumerate() {
        let off = u32::try_from(i).unwrap();
        mem.write_u32(esp + 4 + off * 4, v).unwrap();
    }
    let mut regs = [0u32; 8];
    regs[Reg32::Esp as usize] = esp;
    let mut call = LibcCall {
        trap_addr,
        regs: &regs,
        mem,
    };
    host.libc_call(&mut call).map(|r| {
        let super::LibcResult::Return(v) = r;
        v
    })
}

#[test]
fn libc_exit_wrapper_returns_fault_exit_with_cdecl_arg() {
    // Stub registered at 0x9000. Guest calls `exit(42)` → cdecl arg
    // 0 is 42. Wrapper surfaces Fault::Exit(42) so the existing
    // process_exit_code path produces the right shell status.
    let mut host = StdHost::default();
    host.register_libc_stub(0x9000, LibcFn::Exit);
    let mut mem = FlatMemory::new_zeroed(0x8000, 0x2000);
    match libc_call_with_args(&mut host, 0x9000, 0x8000, &[42], &mut mem) {
        Err(Fault::Exit(42)) => {}
        other => panic!("expected Fault::Exit(42), got {other:?}"),
    }
}

#[test]
fn libc_call_with_unregistered_trap_addr_returns_unsupported_interrupt() {
    // No stub registered. The host can't tell which function was
    // called → trap with Fault::UnsupportedInterrupt(0x81). This
    // is the failure mode if the ELF loader's symbol-table sweep
    // missed a sentinel — surfaces loudly instead of silently doing
    // nothing.
    let mut host = StdHost::default();
    let mut mem = FlatMemory::new_zeroed(0x8000, 0x2000);
    match libc_call_with_args(&mut host, 0xdead_dead, 0x8000, &[], &mut mem) {
        Err(Fault::UnsupportedInterrupt(0x81)) => {}
        other => panic!("expected UnsupportedInterrupt(0x81), got {other:?}"),
    }
}

#[test]
fn libc_sigaction_wrapper_returns_zero() {
    // movie86 wires dispatch/master_loop directly from the ELF
    // symbol table — sigaction itself is a stub that says "success"
    // so the guest's installation code thinks it succeeded.
    let mut host = StdHost::default();
    host.register_libc_stub(0x9100, LibcFn::Sigaction);
    let mut mem = FlatMemory::new_zeroed(0x8000, 0x2000);
    let v = libc_call_with_args(&mut host, 0x9100, 0x8000, &[11, 0xdead_beef, 0], &mut mem)
        .expect("sigaction wrapper should not Err");
    assert_eq!(v, 0, "sigaction returns 0 on success");
}

/// Stage a NUL-terminated string at `addr`. Returns `addr` for chaining.
fn put_cstr(mem: &mut FlatMemory, addr: u32, s: &[u8]) -> u32 {
    mem.write_bytes(addr, s).unwrap();
    mem.write_u8(addr + u32::try_from(s.len()).unwrap(), 0)
        .unwrap();
    addr
}

#[test]
fn libc_printf_emits_plain_string_and_returns_byte_count() {
    // The simplest case: a fmt string with no conversions.
    // `printf("Hello\n")` → 6 bytes written, EAX = 6. This is the
    // case the previous hand-written cdecl stub hardcoded.
    let mut host = StdHost::default();
    host.register_libc_stub(0x9200, LibcFn::Printf);
    let mut mem = FlatMemory::new_zeroed(0x8000, 0x2000);
    let fmt = put_cstr(&mut mem, 0x8800, b"Hello\n");
    let v = libc_call_with_args(&mut host, 0x9200, 0x8000, &[fmt], &mut mem)
        .expect("printf wrapper should not Err");
    assert_eq!(v, 6);
}

#[test]
fn libc_printf_expands_percent_d() {
    // `printf("%d", -1)` → "-1", 2 bytes.
    let mut host = StdHost::default();
    host.register_libc_stub(0x9200, LibcFn::Printf);
    let mut mem = FlatMemory::new_zeroed(0x8000, 0x2000);
    let fmt = put_cstr(&mut mem, 0x8800, b"%d");
    let v = libc_call_with_args(
        &mut host,
        0x9200,
        0x8000,
        &[fmt, /* arg = -1 */ u32::MAX],
        &mut mem,
    )
    .expect("printf wrapper should not Err");
    assert_eq!(v, 2, "'-1' is 2 bytes");
}

#[test]
fn libc_printf_expands_percent_s() {
    // `printf("%s!\n", "world")` → "world!\n", 7 bytes.
    let mut host = StdHost::default();
    host.register_libc_stub(0x9200, LibcFn::Printf);
    let mut mem = FlatMemory::new_zeroed(0x8000, 0x2000);
    let fmt = put_cstr(&mut mem, 0x8800, b"%s!\n");
    let s = put_cstr(&mut mem, 0x8900, b"world");
    let v = libc_call_with_args(&mut host, 0x9200, 0x8000, &[fmt, s], &mut mem)
        .expect("printf wrapper should not Err");
    assert_eq!(v, 7, "'world!\\n' is 7 bytes");
}

#[test]
fn libc_printf_rejects_percent_n_with_negative_return() {
    // %n writes to a guest pointer based on bytes written so far —
    // classic format-string attack vector. Smart-friend pinned this
    // as out-of-scope. Wrapper bails with -1 (cdecl convention).
    let mut host = StdHost::default();
    host.register_libc_stub(0x9200, LibcFn::Printf);
    let mut mem = FlatMemory::new_zeroed(0x8000, 0x2000);
    let fmt = put_cstr(&mut mem, 0x8800, b"abc%n");
    let v = libc_call_with_args(&mut host, 0x9200, 0x8000, &[fmt, 0xdead_beef], &mut mem)
        .expect("printf wrapper should not Err");
    assert_eq!(v, u32::MAX, "u32::MAX is the bit pattern of -1");
}

#[test]
fn libc_printf_unmapped_fmt_pointer_propagates_fault() {
    // If the guest hands us a fmt pointer that isn't mapped, we
    // can't read the first byte → Fault::Unmapped propagates. This
    // is *different* from the bounded fmt case: the host had nothing
    // to flush, and the fault is the only honest answer.
    let mut host = StdHost::default();
    host.register_libc_stub(0x9200, LibcFn::Printf);
    let mut mem = FlatMemory::new_zeroed(0x8000, 0x2000);
    match libc_call_with_args(&mut host, 0x9200, 0x8000, &[0xdead_0000], &mut mem) {
        Err(Fault::Unmapped(0xdead_0000)) => {}
        other => panic!("expected Unmapped(0xdead_0000), got {other:?}"),
    }
}
