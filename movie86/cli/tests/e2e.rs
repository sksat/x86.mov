//! End-to-end tests: build a tiny ELF programmatically, run it through
//! the CLI library, and assert the outcome. Mirrors the byte-identical
//! TDD style the rest of the repo uses.

use movie86_cli::{run_elf, RunOutcome};

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
