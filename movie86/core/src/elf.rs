//! Minimal ELF32 loader for Linux/i386 executables.
//!
//! Parses the ELF header and iterates program headers, collecting every
//! `PT_LOAD` segment as a `(vaddr, memsz, file-data)` triple. The caller
//! is responsible for materializing the segments into a [`Memory`] (the
//! [`flatten_into_region`] helper does the common "one flat region
//! covering all segments" case).
//!
//! Scope: just enough for the movfuscator / mov-only-LLVM output we want
//! to run. Dynamic linking (`PT_DYNAMIC`, `PT_INTERP`) is intentionally
//! out of scope — those binaries are statically linked.

use alloc::vec::Vec;

use crate::{FlatMemory, Memory};

/// Errors the ELF loader can report. Distinct from [`crate::Fault`]
/// because these surface at load time, not during execution.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ElfError {
    /// Buffer is shorter than the header / program-header table demands.
    Truncated,
    /// First four bytes are not `\x7fELF`.
    BadMagic,
    /// `EI_CLASS` is not `ELFCLASS32`.
    NotElf32,
    /// `EI_DATA` is not `ELFDATA2LSB`.
    NotLittleEndian,
    /// `e_machine` is not `EM_386`.
    NotI386,
    /// `e_type` is not `ET_EXEC`. `ET_DYN` (PIE) is rejected on purpose
    /// — without dynamic relocation / load-bias support, mapping segments
    /// at their raw `p_vaddr` would silently start execution from the
    /// wrong addresses.
    NotExecutable,
    /// Loadable segment's `p_memsz` is smaller than `p_filesz`.
    NonsenseSegmentSizes,
}

/// One `PT_LOAD` segment from the ELF.
#[derive(Debug, Clone)]
pub struct LoadSegment<'a> {
    /// Virtual address the segment starts at.
    pub vaddr: u32,
    /// Total in-memory size (may exceed `data.len()`; the tail is BSS,
    /// zero-filled when materialized).
    pub memsz: u32,
    /// Bytes copied verbatim from the file into `[vaddr, vaddr + data.len())`.
    pub data: &'a [u8],
}

/// Parsed ELF, holding borrowed references into the original buffer.
#[derive(Debug, Clone)]
pub struct LoadedElf<'a> {
    pub entry: u32,
    pub segments: Vec<LoadSegment<'a>>,
}

/// Parse `bytes` as an ELF32 little-endian i386 executable.
pub fn parse(bytes: &[u8]) -> Result<LoadedElf<'_>, ElfError> {
    // --- e_ident ---
    let ident = bytes.get(0..16).ok_or(ElfError::Truncated)?;
    if &ident[0..4] != b"\x7fELF" {
        return Err(ElfError::BadMagic);
    }
    if ident[4] != 1 {
        return Err(ElfError::NotElf32);
    }
    if ident[5] != 1 {
        return Err(ElfError::NotLittleEndian);
    }

    // --- rest of Ehdr ---
    let e_type = read_u16(bytes, 16)?;
    if e_type != 2 {
        // ET_EXEC only — see ElfError::NotExecutable for the rationale.
        return Err(ElfError::NotExecutable);
    }
    let e_machine = read_u16(bytes, 18)?;
    if e_machine != 3 {
        return Err(ElfError::NotI386);
    }
    let e_entry = read_u32(bytes, 24)?;
    let e_phoff = read_u32(bytes, 28)?;
    let e_phentsize = read_u16(bytes, 42)?;
    let e_phnum = read_u16(bytes, 44)?;

    // --- program headers ---
    let mut segments = Vec::new();
    for i in 0..e_phnum {
        let off = e_phoff as usize + usize::from(i) * usize::from(e_phentsize);
        let p_type = read_u32(bytes, off)?;
        if p_type != 1 {
            // not PT_LOAD
            continue;
        }
        let p_offset = read_u32(bytes, off + 4)?;
        let p_vaddr = read_u32(bytes, off + 8)?;
        let p_filesz = read_u32(bytes, off + 16)?;
        let p_memsz = read_u32(bytes, off + 20)?;
        if p_memsz < p_filesz {
            return Err(ElfError::NonsenseSegmentSizes);
        }
        let end = (p_offset as usize)
            .checked_add(p_filesz as usize)
            .ok_or(ElfError::Truncated)?;
        let data = bytes
            .get(p_offset as usize..end)
            .ok_or(ElfError::Truncated)?;
        segments.push(LoadSegment {
            vaddr: p_vaddr,
            memsz: p_memsz,
            data,
        });
    }

    Ok(LoadedElf {
        entry: e_entry,
        segments,
    })
}

/// Build a [`FlatMemory`] covering the smallest contiguous range that
/// holds every segment, then write each segment's bytes (zero-filling
/// the BSS tail). Convenience for callers that don't need a sparse
/// address space.
///
/// Returns `None` if the loaded ELF has no `PT_LOAD` segments.
pub fn flatten_into_region(elf: &LoadedElf<'_>) -> Result<FlatMemory, ElfError> {
    let Some(first) = elf.segments.first() else {
        return Err(ElfError::NonsenseSegmentSizes); // reused: "nothing to load"
    };
    let mut lo: u64 = u64::from(first.vaddr);
    let mut hi: u64 = u64::from(first.vaddr) + u64::from(first.memsz);
    for seg in &elf.segments[1..] {
        let seg_lo = u64::from(seg.vaddr);
        let seg_hi = seg_lo + u64::from(seg.memsz);
        lo = lo.min(seg_lo);
        hi = hi.max(seg_hi);
    }
    let base = u32::try_from(lo).map_err(|_| ElfError::Truncated)?;
    let size = usize::try_from(hi - lo).map_err(|_| ElfError::Truncated)?;
    let mut mem = FlatMemory::new_zeroed(base, size);
    for seg in &elf.segments {
        // Memory is already zeroed, so we only have to copy filesz bytes.
        mem.write_bytes(seg.vaddr, seg.data)
            .map_err(|_| ElfError::Truncated)?;
    }
    Ok(mem)
}

fn read_u16(bytes: &[u8], off: usize) -> Result<u16, ElfError> {
    let s = bytes.get(off..off + 2).ok_or(ElfError::Truncated)?;
    Ok(u16::from_le_bytes([s[0], s[1]]))
}

fn read_u32(bytes: &[u8], off: usize) -> Result<u32, ElfError> {
    let s = bytes.get(off..off + 4).ok_or(ElfError::Truncated)?;
    Ok(u32::from_le_bytes([s[0], s[1], s[2], s[3]]))
}

#[cfg(test)]
#[allow(clippy::cast_possible_truncation)] // tiny test fixtures
mod tests {
    use super::*;

    /// Minimal ELF32-LE-i386 `ET_EXEC` builder. Lays out:
    ///   `[Ehdr | Phdr_0 | ... | Phdr_n-1 | seg0 data | seg1 data | ...]`
    /// Each segment starts immediately after the program header table.
    /// Returned bytes are a valid ELF the loader should accept.
    ///
    /// All `as` casts are over hand-picked tiny fixtures — safe within
    /// the test harness, not worth the noise of `try_from(...).unwrap()`.
    #[allow(clippy::cast_possible_truncation)]
    fn build_elf(entry: u32, segments: &[(u32 /*vaddr*/, u32 /*memsz*/, &[u8])]) -> Vec<u8> {
        const EHDR_SIZE: usize = 52;
        const PHDR_SIZE: usize = 32;

        // Ehdr placeholder (filled at the end).
        let mut bytes: Vec<u8> = alloc::vec![0; EHDR_SIZE];
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
        bytes[44..46].copy_from_slice(&u16::try_from(segments.len()).unwrap().to_le_bytes());

        // Reserve space for program headers.
        let phdr_start = bytes.len();
        bytes.resize(phdr_start + segments.len() * PHDR_SIZE, 0);

        // Append segment data, recording each one's file offset.
        let mut seg_offsets: Vec<u32> = Vec::new();
        for &(_, _, data) in segments {
            seg_offsets.push(u32::try_from(bytes.len()).unwrap());
            bytes.extend_from_slice(data);
        }

        // Fill program headers.
        for (i, &(vaddr, memsz, data)) in segments.iter().enumerate() {
            let off = phdr_start + i * PHDR_SIZE;
            bytes[off..off + 4].copy_from_slice(&1u32.to_le_bytes()); // PT_LOAD
            bytes[off + 4..off + 8].copy_from_slice(&seg_offsets[i].to_le_bytes());
            bytes[off + 8..off + 12].copy_from_slice(&vaddr.to_le_bytes());
            bytes[off + 12..off + 16].copy_from_slice(&vaddr.to_le_bytes()); // p_paddr
            bytes[off + 16..off + 20]
                .copy_from_slice(&u32::try_from(data.len()).unwrap().to_le_bytes()); // p_filesz
            bytes[off + 20..off + 24].copy_from_slice(&memsz.to_le_bytes());
            bytes[off + 24..off + 28].copy_from_slice(&5u32.to_le_bytes()); // PF_R | PF_X
            bytes[off + 28..off + 32].copy_from_slice(&0x1000u32.to_le_bytes());
            // p_align
        }
        bytes
    }

    #[test]
    fn parses_single_pt_load_segment() {
        let prog = b"\xb8\x2a\x00\x00\x00"; // mov eax, 42
        let elf = build_elf(0x0804_8000, &[(0x0804_8000, prog.len() as u32, prog)]);
        let loaded = parse(&elf).unwrap();
        assert_eq!(loaded.entry, 0x0804_8000);
        assert_eq!(loaded.segments.len(), 1);
        assert_eq!(loaded.segments[0].vaddr, 0x0804_8000);
        assert_eq!(loaded.segments[0].data, prog);
    }

    #[test]
    fn rejects_bad_magic() {
        let mut elf = build_elf(0, &[(0, 4, &[0, 0, 0, 0])]);
        elf[0] = b'X';
        assert_eq!(parse(&elf).unwrap_err(), ElfError::BadMagic);
    }

    #[test]
    fn rejects_non_i386_machine() {
        let mut elf = build_elf(0, &[(0, 4, &[0, 0, 0, 0])]);
        elf[18..20].copy_from_slice(&62u16.to_le_bytes()); // EM_X86_64
        assert_eq!(parse(&elf).unwrap_err(), ElfError::NotI386);
    }

    #[test]
    fn rejects_et_dyn_until_we_support_load_bias() {
        // Build a normal ET_EXEC, then flip e_type to ET_DYN. The
        // loader has no relocation / load-bias machinery, so accepting
        // ET_DYN would silently jump to the wrong address.
        let mut elf = build_elf(0, &[(0, 4, &[0, 0, 0, 0])]);
        elf[16..18].copy_from_slice(&3u16.to_le_bytes()); // ET_DYN
        assert_eq!(parse(&elf).unwrap_err(), ElfError::NotExecutable);
    }

    #[test]
    fn rejects_64bit_class() {
        let mut elf = build_elf(0, &[(0, 4, &[0, 0, 0, 0])]);
        elf[4] = 2; // ELFCLASS64
        assert_eq!(parse(&elf).unwrap_err(), ElfError::NotElf32);
    }

    #[test]
    fn truncated_buffer_reported() {
        let elf = build_elf(0, &[(0, 4, &[0, 0, 0, 0])]);
        assert_eq!(parse(&elf[..10]).unwrap_err(), ElfError::Truncated);
    }

    #[test]
    fn bss_tail_is_zero_filled_when_flattened() {
        let prog = b"\x90\x90"; // 2 bytes of program
        let elf = build_elf(0x1000, &[(0x1000, 16, prog)]); // memsz=16, filesz=2
        let loaded = parse(&elf).unwrap();
        let mem = flatten_into_region(&loaded).unwrap();
        assert_eq!(mem.read_u8(0x1000).unwrap(), 0x90);
        assert_eq!(mem.read_u8(0x1001).unwrap(), 0x90);
        // Trailing BSS — must read as zero.
        for off in 2..16 {
            assert_eq!(
                mem.read_u8(0x1000 + off).unwrap(),
                0,
                "BSS byte at 0x{:x} not zeroed",
                0x1000 + off
            );
        }
    }

    #[test]
    fn flattened_region_covers_multiple_segments() {
        let text = b"\x90";
        let data = b"\xaa\xbb";
        let elf = build_elf(0x1000, &[(0x1000, 1, text), (0x2000, 2, data)]);
        let loaded = parse(&elf).unwrap();
        let mem = flatten_into_region(&loaded).unwrap();
        assert_eq!(mem.read_u8(0x1000).unwrap(), 0x90);
        assert_eq!(mem.read_u8(0x2000).unwrap(), 0xaa);
        assert_eq!(mem.read_u8(0x2001).unwrap(), 0xbb);
        // Gap between segments is zero.
        assert_eq!(mem.read_u8(0x1500).unwrap(), 0);
    }
}
