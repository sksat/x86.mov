//! End-to-end tests: build a tiny ELF programmatically, run it through
//! the CLI library, and assert the outcome. Mirrors the byte-identical
//! TDD style the rest of the repo uses.

use movie86_cli::{run_elf, run_elf_with_host, RunOutcome};
use movie86_core::libc_host::LibcHost;
use movie86_core::syscall::{SysHost, SyscallArgs, SyscallResult};
use movie86_core::{decode, Fault, Memory};

/// Build a minimal ELF32-LE-i386 `ET_EXEC` whose entry runs `program`.
/// One `PT_LOAD` segment covering exactly the program bytes.
#[allow(clippy::cast_possible_truncation)] // tiny fixtures
fn build_elf(entry: u32, program: &[u8]) -> Vec<u8> {
    const EHDR_SIZE: usize = 52;
    const PHDR_SIZE: usize = 32;

    let mut bytes: Vec<u8> = vec![0; EHDR_SIZE + PHDR_SIZE];
    // Ehdr
    bytes[0..4].copy_from_slice(b"\x7fELF");
    bytes[4] = 1; // ELFCLASS32
    bytes[5] = 1; // ELFDATA2LSB
    bytes[6] = 1; // EV_CURRENT
    bytes[16..18].copy_from_slice(&2u16.to_le_bytes()); // ET_EXEC
    bytes[18..20].copy_from_slice(&3u16.to_le_bytes()); // EM_386
    bytes[20..24].copy_from_slice(&1u32.to_le_bytes()); // e_version
    bytes[24..28].copy_from_slice(&entry.to_le_bytes());
    bytes[28..32].copy_from_slice(&(EHDR_SIZE as u32).to_le_bytes()); // e_phoff
    bytes[40..42].copy_from_slice(&(EHDR_SIZE as u16).to_le_bytes()); // e_ehsize
    bytes[42..44].copy_from_slice(&(PHDR_SIZE as u16).to_le_bytes()); // e_phentsize
    bytes[44..46].copy_from_slice(&1u16.to_le_bytes()); // e_phnum
                                                        // Phdr (single PT_LOAD)
    let p = EHDR_SIZE;
    let seg_offset = bytes.len() as u32; // program data appended at the end
    bytes[p..p + 4].copy_from_slice(&1u32.to_le_bytes()); // PT_LOAD
    bytes[p + 4..p + 8].copy_from_slice(&seg_offset.to_le_bytes());
    bytes[p + 8..p + 12].copy_from_slice(&entry.to_le_bytes()); // p_vaddr
    bytes[p + 12..p + 16].copy_from_slice(&entry.to_le_bytes()); // p_paddr
    bytes[p + 16..p + 20].copy_from_slice(&(program.len() as u32).to_le_bytes()); // p_filesz
    bytes[p + 20..p + 24].copy_from_slice(&(program.len() as u32).to_le_bytes()); // p_memsz
    bytes[p + 24..p + 28].copy_from_slice(&5u32.to_le_bytes()); // PF_R | PF_X
    bytes[p + 28..p + 32].copy_from_slice(&0x1000u32.to_le_bytes()); // p_align
    bytes.extend_from_slice(program);
    bytes
}

/// Test host that buffers all `write(1, ...)` bytes and treats `exit(1)`
/// the same way `StdHost` does. Lets us assert on captured stdout
/// without spawning a subprocess.
struct CapturingHost {
    stdout: Vec<u8>,
}

impl CapturingHost {
    fn new() -> Self {
        Self { stdout: Vec::new() }
    }
}

impl SysHost for CapturingHost {
    fn syscall(
        &mut self,
        args: &SyscallArgs,
        mem: &mut dyn Memory,
    ) -> Result<SyscallResult, Fault> {
        match args.eax {
            1 => Err(Fault::Exit(args.ebx)),
            4 => {
                assert_eq!(args.ebx, 1, "test only captures stdout");
                let mut buf = vec![0u8; args.edx as usize];
                mem.read_bytes(args.ecx, &mut buf)?;
                self.stdout.extend_from_slice(&buf);
                Ok(SyscallResult::Return(args.edx))
            }
            n => Err(Fault::UnknownSyscall(n)),
        }
    }
}

// CapturingHost has no libc-wrapper expectations — empty impl picks
// up the trait's default `Fault::UnsupportedInterrupt(0x81)` trap.
impl LibcHost for CapturingHost {}

#[test]
fn runs_minimal_exit_42_elf() {
    // The shortest meaningful program: set up exit(42) and trap.
    //   mov eax, 1        ; SYS_exit
    //   mov ebx, 42
    //   int 0x80
    let program: &[u8] = &[
        0xb8, 0x01, 0x00, 0x00, 0x00, // mov eax, 1
        0xbb, 0x2a, 0x00, 0x00, 0x00, // mov ebx, 42
        0xcd, 0x80, // int 0x80
    ];
    let elf = build_elf(0x0804_8000, program);
    match run_elf(&elf) {
        RunOutcome::Exit(status) => assert_eq!(status, 42),
        other => panic!("expected Exit(42), got {other:?}"),
    }
}

#[test]
fn writes_hello_to_stdout_and_exits_zero() {
    // Layout: one PT_LOAD covering [code | data] at 0x08048000.
    //   code: write(1, msg_addr, 6); exit(0)    (34 bytes)
    //   data: "Hello\n"                          (6 bytes at code+34)
    const ENTRY: u32 = 0x0804_8000;
    const MSG_OFF: u32 = 34;
    let msg_addr = ENTRY + MSG_OFF;
    let m = msg_addr.to_le_bytes();
    let program: Vec<u8> = vec![
        // mov eax, 4    (SYS_write)
        0xb8, 0x04, 0x00, 0x00, 0x00, // mov ebx, 1    (fd = stdout)
        0xbb, 0x01, 0x00, 0x00, 0x00, // mov ecx, msg_addr
        0xb9, m[0], m[1], m[2], m[3], // mov edx, 6    (count)
        0xba, 0x06, 0x00, 0x00, 0x00, // int 0x80
        0xcd, 0x80, // mov eax, 1    (SYS_exit)
        0xb8, 0x01, 0x00, 0x00, 0x00, // mov ebx, 0
        0xbb, 0x00, 0x00, 0x00, 0x00, // int 0x80
        0xcd, 0x80, // data:
        b'H', b'e', b'l', b'l', b'o', b'\n',
    ];
    assert_eq!(program.len(), (MSG_OFF + 6) as usize);

    let elf = build_elf(ENTRY, &program);
    let mut host = CapturingHost::new();
    match run_elf_with_host(&elf, &mut host) {
        RunOutcome::Exit(0) => {}
        other => panic!("expected Exit(0), got {other:?}"),
    }
    assert_eq!(host.stdout, b"Hello\n");
}

#[test]
fn call_function_that_writes_and_rets_then_exits() {
    // Exercises call + ret end-to-end alongside the syscall path.
    // Layout (entry at 0x08048000):
    //   00 .. 04: call func        (5 bytes; relative)
    //   05 .. 0e: mov eax,1; mov ebx,0; int 0x80   (12 bytes; exit)
    //   11 .. 27: func: write(1, msg, 3); ret      (23 bytes)
    //   28 .. 2a: data "Hi\n"                       (3 bytes)
    const ENTRY: u32 = 0x0804_8000;
    const FUNC_OFF: u32 = 17;
    const MSG_OFF: u32 = 40;
    let msg_addr = ENTRY + MSG_OFF;
    // call rel32: displacement is from the instruction AFTER the call
    // (at ENTRY + 5) to the target (func_addr).
    let call_disp: i32 = i32::try_from(FUNC_OFF).unwrap() - 5;
    let cd = call_disp.to_le_bytes();
    let m = msg_addr.to_le_bytes();
    #[rustfmt::skip]
    let program: Vec<u8> = vec![
        // 00: call func
        0xe8, cd[0], cd[1], cd[2], cd[3],
        // 05: mov eax, 1
        0xb8, 0x01, 0x00, 0x00, 0x00,
        // 0a: mov ebx, 0
        0xbb, 0x00, 0x00, 0x00, 0x00,
        // 0f: int 0x80
        0xcd, 0x80,
        // 11: func: mov eax, 4
        0xb8, 0x04, 0x00, 0x00, 0x00,
        // 16: mov ebx, 1
        0xbb, 0x01, 0x00, 0x00, 0x00,
        // 1b: mov ecx, msg
        0xb9, m[0], m[1], m[2], m[3],
        // 20: mov edx, 3
        0xba, 0x03, 0x00, 0x00, 0x00,
        // 25: int 0x80
        0xcd, 0x80,
        // 27: ret
        0xc3,
        // 28: data "Hi\n"
        b'H', b'i', b'\n',
    ];
    assert_eq!(program.len(), (MSG_OFF + 3) as usize);

    let elf = build_elf(ENTRY, &program);
    let mut host = CapturingHost::new();
    match run_elf_with_host(&elf, &mut host) {
        RunOutcome::Exit(0) => {}
        other => panic!("expected Exit(0), got {other:?}"),
    }
    assert_eq!(host.stdout, b"Hi\n");
}

/// Decoder-coverage test: walk every byte of the `.text` section in
/// the committed `return42.o` (real movfuscator output) through
/// `decode()` and assert it all decodes cleanly. Catches a class of
/// regressions the hand-crafted tests can't: a real movfuscator
/// binary's instruction mix.
///
/// The .text offset/size are taken from a one-time `objdump -h` of
/// the file (`52..52+0x0adc`). If the golden is regenerated and that
/// changes, update the constants; the test will fail loud either way.
#[test]
fn decoder_covers_return42_o_text() {
    const RETURN42_O: &[u8] =
        include_bytes!("../../../movfuscator-wasm/tests/goldens-o/return42.o");
    const TEXT_OFFSET: usize = 0x34;
    const TEXT_LEN: usize = 0x0adc;

    let text = &RETURN42_O[TEXT_OFFSET..TEXT_OFFSET + TEXT_LEN];
    let mut pos = 0;
    let mut insns = 0;
    while pos < text.len() {
        match decode(&text[pos..]) {
            Ok((_, len)) => {
                assert!(len > 0, "decode returned 0-length insn at {pos:#x}");
                pos += usize::from(len);
                insns += 1;
            }
            Err(e) => panic!("decode failed at .text offset {pos:#x} ({insns} insns in): {e:?}"),
        }
    }
    assert_eq!(pos, text.len(), "decoder consumed exactly the .text bytes");
    // Lower bound — return42.o is ~2.7 KB of mov-heavy code, so we
    // expect many hundreds of decoded instructions. Pinning a precise
    // count would couple the test to the golden, but the floor catches
    // a degenerate "every byte was a 0xb8 imm32 swallowing 5" pattern.
    assert!(insns > 100, "expected >100 instructions, got {insns}");
}

/// One-off decoder-coverage probe: walk the `.text` section of an
/// arbitrary committed-or-not ELF32 `.o` file through `decode()` and
/// report the first byte that fails. Gated behind `#[ignore]` + env var
/// so vendor-derived `.o`s don't have to be checked in.
///
/// Usage: `MOVIE86_FIXTURE=path/to/crt0_cf.o cargo test -- --ignored \
///         investigate_decoder_coverage`
#[test]
#[ignore = "requires MOVIE86_FIXTURE to point at an ELF32 .o"]
fn investigate_decoder_coverage() {
    let Ok(path) = std::env::var("MOVIE86_FIXTURE") else {
        return;
    };
    let bytes = std::fs::read(&path).expect("read fixture");
    // Minimal ET_REL .text locator: find the section header table,
    // walk sections, find SHT_PROGBITS named ".text" via the section
    // string table. Keeps the test self-contained.
    let e_shoff = u32::from_le_bytes(bytes[32..36].try_into().unwrap()) as usize;
    let e_shentsize = u16::from_le_bytes(bytes[46..48].try_into().unwrap()) as usize;
    let e_shnum = u16::from_le_bytes(bytes[48..50].try_into().unwrap()) as usize;
    let e_shstrndx = u16::from_le_bytes(bytes[50..52].try_into().unwrap()) as usize;
    let shstr_h_off = e_shoff + e_shstrndx * e_shentsize;
    let shstr_off = u32::from_le_bytes(
        bytes[shstr_h_off + 16..shstr_h_off + 20]
            .try_into()
            .unwrap(),
    ) as usize;
    let shstr_size = u32::from_le_bytes(
        bytes[shstr_h_off + 20..shstr_h_off + 24]
            .try_into()
            .unwrap(),
    ) as usize;
    let shstr = &bytes[shstr_off..shstr_off + shstr_size];

    let mut text_off = 0usize;
    let mut text_size = 0usize;
    for i in 0..e_shnum {
        let h_off = e_shoff + i * e_shentsize;
        let sh_name = u32::from_le_bytes(bytes[h_off..h_off + 4].try_into().unwrap()) as usize;
        let nul = shstr[sh_name..].iter().position(|&b| b == 0).unwrap_or(0);
        let name = std::str::from_utf8(&shstr[sh_name..sh_name + nul]).unwrap_or("");
        if name == ".text" {
            text_off =
                u32::from_le_bytes(bytes[h_off + 16..h_off + 20].try_into().unwrap()) as usize;
            text_size =
                u32::from_le_bytes(bytes[h_off + 20..h_off + 24].try_into().unwrap()) as usize;
            break;
        }
    }
    assert!(text_size > 0, "no .text section in {path}");
    let text = &bytes[text_off..text_off + text_size];

    let mut pos = 0;
    let mut insns = 0;
    while pos < text.len() {
        match movie86_core::decode(&text[pos..]) {
            Ok((insn, len)) => {
                assert!(len > 0);
                pos += usize::from(len);
                insns += 1;
                // Print every 20th instruction so we can scan the trace.
                if insns % 20 == 0 || pos >= text.len() {
                    eprintln!("  ok  +{pos:04x}  insn#{insns}  ({insn:?})");
                }
            }
            Err(e) => {
                let window: Vec<String> = text[pos..(pos + 8).min(text.len())]
                    .iter()
                    .map(|b| format!("{b:02x}"))
                    .collect();
                panic!(
                    "decode failed at {path} .text offset {pos:#x} \
                     after {insns} instructions: {e:?}; bytes: {}",
                    window.join(" ")
                );
            }
        }
    }
    eprintln!(
        "=== {path}: {insns} insns covering {} bytes of .text ===",
        text.len()
    );
}

#[test]
fn snapshot_at_step_zero_captures_initial_state_before_any_step() {
    // Regression for codex P2-2: --snapshot-at-step 0 used to silently
    // never fire because the loop-body capture only ran after
    // step_count was incremented. The fix captures once before
    // entering the loop, so step 0 = "the initial state".

    use movie86_cli::snapshot::{Snapshot, SnapshotKind};
    use movie86_cli::{run_elf_with_debug, DebugConfig, StdHost};

    let program: &[u8] = &[
        0xb8, 0x01, 0x00, 0x00, 0x00, // mov eax, 1   (SYS_exit)
        0xbb, 0x07, 0x00, 0x00, 0x00, // mov ebx, 7
        0xcd, 0x80, // int 0x80
    ];
    let entry: u32 = 0x0804_8000;
    let elf = build_elf(entry, program);

    // Pick a tmp path that doesn't clash with parallel test runs.
    let path = std::env::temp_dir().join(format!("movie86-snap-step0-{}.bin", std::process::id()));
    let _ = std::fs::remove_file(&path);

    let cfg = DebugConfig {
        snapshot_at_step: Some((0, path.clone())),
        ..DebugConfig::default()
    };
    let mut host = StdHost::default();
    let outcome = run_elf_with_debug(&elf, &mut host, &cfg);
    matches!(outcome, RunOutcome::Exit(7))
        .then_some(())
        .expect("program runs to exit(7)");

    // The snapshot file must exist and reflect the pre-step state:
    // step_count = 0, eip = entry, all GPRs zero (no `mov` has run
    // yet).
    let snap = Snapshot::read_from_path(&path).expect("snapshot file should exist");
    assert_eq!(snap.kind, SnapshotKind::AfterStep);
    assert_eq!(snap.step_count, 0);
    assert_eq!(snap.eip, entry, "eip should be the ELF entry point");
    assert_eq!(
        snap.regs[0], 0,
        "EAX should be 0 — the program hasn't run yet"
    );

    let _ = std::fs::remove_file(&path);
}

#[test]
fn fault_on_unsupported_syscall() {
    // mov eax, 999 ; int 0x80  → syscall 999 is unimplemented
    let program: &[u8] = &[
        0xb8, 0xe7, 0x03, 0x00, 0x00, // mov eax, 999
        0xcd, 0x80, // int 0x80
    ];
    let elf = build_elf(0x0804_8000, program);
    match run_elf(&elf) {
        RunOutcome::Fault(movie86_core::Fault::UnknownSyscall(999)) => {}
        other => panic!("expected UnknownSyscall(999), got {other:?}"),
    }
}
