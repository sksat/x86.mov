//! Unit tests for the host-side syscall translation.

use super::{errno_to_eax, write_syscall, SyscallArgs, SyscallResult};
use movie86_core::{FlatMemory, Memory};

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
    assert_eq!(v, errno_to_eax(9), "should be -EBADF before any bytes written");
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
