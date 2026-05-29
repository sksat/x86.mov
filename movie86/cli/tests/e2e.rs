//! End-to-end tests: build a tiny ELF programmatically, run it through
//! the CLI library, and assert the outcome. Mirrors the byte-identical
//! TDD style the rest of the repo uses.

use movie86::libc_host::LibcHost;
use movie86::syscall::{SysHost, SyscallArgs, SyscallResult};
use movie86::{decode, Fault, Memory};
use movie86_cli::{run_elf, run_elf_with_host, RunOutcome};

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
// Same story for BIOS (`int 0x10`): no expectations, trap on call.
impl movie86::BiosHost for CapturingHost {}
// And mov-only ABI: no expectations either; the default trap fires
// on any call so a regression test that's expecting an ABI write
// surfaces it explicitly.
impl movie86::AbiHost for CapturingHost {}

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
        match movie86::decode(&text[pos..]) {
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
fn handover_round_trip_via_dump_load_context_continues_to_exit() {
    // Phase 2 of the engine-handoff plumbing: a single guest run can
    // be cut in two by dumping the canonical Context to JSON mid-way
    // and feeding it back to a fresh load. The combined outcome must
    // match an uninterrupted single-pass run — same exit code, same
    // observable side effects.
    use movie86_cli::context_json::from_json;
    use movie86_cli::{run_elf_with_debug, DebugConfig, DebugStop, StdHost};

    // mov eax, 1 ; mov ebx, 42 ; int 0x80  → exit(42).
    let program: &[u8] = &[
        0xb8, 0x01, 0x00, 0x00, 0x00, // mov eax, 1
        0xbb, 0x2a, 0x00, 0x00, 0x00, // mov ebx, 42
        0xcd, 0x80, // int 0x80
    ];
    let entry: u32 = 0x0804_8000;
    let elf = build_elf(entry, program);

    let dump_path =
        std::env::temp_dir().join(format!("movie86-ctx-roundtrip-{}.json", std::process::id()));
    let _ = std::fs::remove_file(&dump_path);

    // Pass 1: run 2 steps, dump context, halt at the int 0x80.
    let mut host1 = StdHost::default();
    let cfg1 = DebugConfig {
        max_steps: Some(2),
        dump_context_at_step: Some((2, dump_path.clone())),
        ..DebugConfig::default()
    };
    match run_elf_with_debug(&elf, &mut host1, &cfg1) {
        RunOutcome::DebugStop(DebugStop::MaxSteps(2)) => {}
        other => panic!("pass 1: expected MaxSteps(2), got {other:?}"),
    }

    let json = std::fs::read(&dump_path).expect("context json file should exist");
    let ctx = from_json(&json).expect("ctx json should parse");

    // Sanity-check the captured regs: 2 movs done, eip at the int 0x80.
    assert_eq!(ctx.regs.eax, 1, "after step 1: eax=1");
    assert_eq!(ctx.regs.ebx, 42, "after step 2: ebx=42");
    assert_eq!(
        ctx.regs.eip,
        entry + 10,
        "eip should sit at the int 0x80 (10 bytes in)"
    );

    // Pass 2: same ELF, load the captured context, run to completion.
    let mut host2 = StdHost::default();
    let cfg2 = DebugConfig {
        load_context: Some(ctx),
        ..DebugConfig::default()
    };
    match run_elf_with_debug(&elf, &mut host2, &cfg2) {
        RunOutcome::Exit(42) => {}
        other => panic!("pass 2: expected Exit(42), got {other:?}"),
    }

    let _ = std::fs::remove_file(&dump_path);
}

/// movfuscator-runtime link-order pin: when caller user/stub objects
/// are placed between `crt0.o` and `crtf.o` on the `ld` command line,
/// `master_loop`'s straight-line body is fragmented — its head lives
/// in `crt0.o.text` (1406 bytes) and its tail (`mov esp, [&sesp]; mov
/// cs, ax`) lives in `crtf.o.text` (8 bytes), and the linker
/// concatenates the two adjacently *only* if nothing else's `.text`
/// sits between them.
///
/// Drop a caller `stub.o` (`sigaction` / `exit`) between them and the
/// `master_loop` fallthrough crosses the stub's body. The stub's
/// `c3 ret` pops a value off the *shadow* stack that `master_loop`
/// staged for itself — a movfuscator-encoded label `0x80000000 + dest`
/// — and the CPU's `ret` jumps to that high-bit-set address.
/// `FlatMemory` traps it as `Fault::Unmapped(addr)`.
///
/// This is **not** a movie86 emulation bug — the bit is set
/// deliberately by `mov eax, 0x88049309` in `master_loop`'s body,
/// which is movfuscator's `MOV_OFFSET` label encoding (real addr +
/// `0x80000000`). movie86 preserves the value correctly through every
/// move; the runtime would have stripped the high bit at a later
/// stage if execution had stayed on the `master_loop` fallthrough
/// path.
///
/// The fix lives on the link-recipe side: caller objects must be
/// linked *after* `crtf.o crtd.o softfloat32.o`, not between `crt0.o`
/// and `crtf.o`. `movie86/scripts/link-real-return42.sh` does this
/// correctly; the `movfuscator-wasm` `link({ static: true })` wrapper
/// does not (issue surfaced through PR #39's static-link branch).
///
/// This test pins both the failing layout (so a future fix to that
/// wrapper still observes the same emulator-side fault as a hard
/// signal) and the working layout (so a regression that breaks the
/// working layout fails loudly here).
///
/// Skipped (returns silently) when the vendored movfuscator runtime
/// objects aren't materialized. Materialize via:
///   cd movfuscator-wasm && make setup && make build-native
/// The test picks up the canonical paths automatically; override via
/// `MOVIE86_MOVF_BUILD` and `MOVIE86_MOVF_SOFTFLOAT_DIR`.
#[test]
#[allow(clippy::too_many_lines, clippy::similar_names)]
fn movfuscator_runtime_link_order_pin() {
    use std::path::PathBuf;
    use std::process::Command;

    // Resolve where vendor objects live. Default to the canonical
    // movfuscator-wasm layout one repo above this crate; allow override
    // for git-worktree or CI shapes.
    let manifest_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let repo_root = manifest_dir
        .ancestors()
        .nth(2)
        .expect("repo root above cli/")
        .to_path_buf();
    let default_build = repo_root.join("movfuscator-wasm/vendor/movfuscator/build");
    let default_softfloat = repo_root.join("movfuscator-wasm/vendor/movfuscator/movfuscator/lib");
    let build_dir = std::env::var_os("MOVIE86_MOVF_BUILD").map_or(default_build, PathBuf::from);
    let softfloat_dir =
        std::env::var_os("MOVIE86_MOVF_SOFTFLOAT_DIR").map_or(default_softfloat, PathBuf::from);
    let crt0 = build_dir.join("crt0.o");
    let crtf = build_dir.join("crtf.o");
    let crtd = build_dir.join("crtd.o");
    let softfloat32 = softfloat_dir.join("softfloat32.o");
    let return42_o = repo_root.join("movfuscator-wasm/tests/goldens-o/return42.o");
    for f in [&crt0, &crtf, &crtd, &softfloat32, &return42_o] {
        if !f.exists() {
            eprintln!(
                "movfuscator_runtime_link_order_pin: skipping — missing {}",
                f.display()
            );
            eprintln!("  to enable: cd movfuscator-wasm && make setup && make build-native");
            return;
        }
    }
    // /usr/bin/as and /usr/bin/ld required.
    if !std::path::Path::new("/usr/bin/as").exists()
        || !std::path::Path::new("/usr/bin/ld").exists()
    {
        eprintln!(
            "movfuscator_runtime_link_order_pin: skipping — /usr/bin/as or /usr/bin/ld missing"
        );
        return;
    }

    let tmp = std::env::temp_dir().join(format!("movie86-linkorder-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&tmp);
    std::fs::create_dir_all(&tmp).expect("create tmpdir");

    // Caller-supplied stub matching PR #39's static-link test:
    // sigaction returns 0; exit(status) issues int 0x80 SYS_exit. The
    // cdecl `ret` inside `sigaction` is the load-bearing instruction
    // for this test — it's the one that pops the master_loop-staged
    // label when the stub object is inserted between crt0 and crtf.
    let stub_s = tmp.join("stub.s");
    std::fs::write(
        &stub_s,
        b".text\n\
         .globl sigaction\n\
         .type sigaction, @function\n\
         sigaction:\n    \
             movl $0, %eax\n    \
             ret\n\
         .globl exit\n\
         .type exit, @function\n\
         exit:\n    \
             movl 4(%esp), %ebx\n    \
             movl $1, %eax\n    \
             int $0x80\n",
    )
    .expect("write stub.s");
    let stub_o = tmp.join("stub.o");
    let as_status = Command::new("/usr/bin/as")
        .args(["--32", "-o"])
        .arg(&stub_o)
        .arg(&stub_s)
        .status()
        .expect("spawn /usr/bin/as");
    assert!(as_status.success(), "as failed: {as_status}");

    // Helper: invoke /usr/bin/ld with a given object order and run the
    // result through `run_elf`. Returns the outcome.
    let link_and_run = |out: &std::path::Path, order: &[&std::path::Path]| -> RunOutcome {
        let mut cmd = Command::new("/usr/bin/ld");
        cmd.args(["-m", "elf_i386", "-static", "--hash-style=gnu"]);
        for o in order {
            cmd.arg(o);
        }
        cmd.arg("-o").arg(out);
        let status = cmd.status().expect("spawn /usr/bin/ld");
        assert!(status.success(), "ld failed: {status}");
        let bytes = std::fs::read(out).expect("read linked elf");
        run_elf(&bytes)
    };

    // --- Broken layout: stub between user code and crtf ---
    // This is the exact order PR #39's link({ static: true }) emits.
    // master_loop's straight-line body falls through the stub's
    // `sigaction: mov eax,0; ret` sequence; the ret pops the value
    // master_loop staged on the shadow stack (a movfuscator-encoded
    // label, high bit set), and the CPU jumps there.
    let broken_out = tmp.join("return42-broken.elf");
    let broken_outcome = link_and_run(
        &broken_out,
        &[&crt0, &return42_o, &stub_o, &crtf, &crtd, &softfloat32],
    );
    match broken_outcome {
        RunOutcome::Fault(movie86::Fault::Unmapped(addr)) => {
            // Bit 31 must be set — that's the movfuscator MOV_OFFSET
            // encoding. The low 31 bits land somewhere inside the
            // linked binary's text region (master_loop body).
            assert!(
                addr & 0x8000_0000 != 0,
                "expected MOV_OFFSET-encoded label (bit 31 set), got {addr:#010x}"
            );
            let real = addr & 0x7fff_ffff;
            assert!(
                (0x0804_8000..=0x0904_8000).contains(&real),
                "expected target near linked text (~0x08049...), got {addr:#010x}"
            );
        }
        other => panic!("broken layout: expected Fault::Unmapped(MOV_OFFSET addr), got {other:?}"),
    }

    // --- Working layout: stub at the end, after the movfuscator
    // runtime objects. master_loop's body stays contiguous. ---
    let good_out = tmp.join("return42-good.elf");
    let good_outcome = link_and_run(
        &good_out,
        &[&crt0, &return42_o, &crtf, &crtd, &softfloat32, &stub_o],
    );
    match good_outcome {
        // movfuscator's crt0 hardcodes `push("$0"); jmp_extern("exit")`,
        // so the int-0x80 SYS_exit stub terminates with status 0
        // regardless of what `main` returned. See `link-real-return42.sh`
        // for the same observation.
        RunOutcome::Exit(0) => {}
        other => panic!("working layout: expected Exit(0), got {other:?}"),
    }

    let _ = std::fs::remove_dir_all(&tmp);
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
        RunOutcome::Fault(movie86::Fault::UnknownSyscall(999)) => {}
        other => panic!("expected UnknownSyscall(999), got {other:?}"),
    }
}
