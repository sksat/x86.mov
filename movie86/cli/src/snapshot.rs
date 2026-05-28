//! Memory + register snapshot file format.
//!
//! Why this exists: the `multi-add` fixture cycles the same 1474
//! `master_loop` PCs whether you stop at 1M or 100M steps. PC cycling
//! alone can't tell "stuck" from "extremely slow" — movfuscator's
//! `master_loop` encodes logical progress in *memory state*, not in
//! different code paths. To answer "is the program making progress",
//! we need to capture the full machine state at two step counts and
//! diff them.
//!
//! Format is a small custom container, not gdb core / QEMU migration:
//! [`FlatMemory`] is already `base + raw bytes`, so a fat external
//! format would just add irrelevant semantics. Layout:
//!
//! ```text
//!   0..4    magic = b"M86S"        (Movie86 Snapshot)
//!   4..6    version u16 LE         (currently 1)
//!   6..7    kind u8                (see SnapshotKind below)
//!   7..8    reserved (0)
//!   8..16   step_count u64 LE      (successful steps completed)
//!  16..48   regs[8] u32 LE         (Reg32 enum order: eax, ecx, edx,
//!                                   ebx, esp, ebp, esi, edi)
//!  48..52   eip u32 LE
//!  52..56   sigsegv_handler u32 LE (or SENTINEL_NONE)
//!  56..60   sigill_handler u32 LE  (or SENTINEL_NONE)
//!  60..64   detail u32 LE          (kind-specific; e.g. exit status,
//!                                   fault-variant payload, break addr)
//!  64..68   mem_base u32 LE
//!  68..72   mem_len u32 LE
//!  72..     raw memory bytes       (mem_len bytes)
//! ```
//!
//! **Capture semantics is "AFTER step N succeeded".** `step_count`
//! always reflects the number of `Cpu::step()` calls that returned
//! `Ok`. For fault captures, `step_count` is the count before the
//! faulting step (i.e. the last successful one); `eip` still points
//! at the faulting instruction since `step()` only advances eip on
//! success.

use std::io::{self, Read, Write};
use std::path::Path;

use movie86_core::{Memory, Signal};

const MAGIC: &[u8; 4] = b"M86S";
const VERSION: u16 = 1;
const HEADER_LEN: usize = 72;
/// Sentinel `u32` for "no handler registered". Picked because no real
/// movfuscator binary places a handler at the very top of the address
/// space — small risk of collision, big readability win in dumps.
const SENTINEL_NONE: u32 = u32::MAX;

/// What caused the snapshot to be taken.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SnapshotKind {
    /// `--snapshot-at-step N` fired after step N completed.
    AfterStep,
    /// Guest called `exit(status)`. `detail` is the status word.
    Exit,
    /// `Cpu::step()` returned a non-Exit `Fault`. `detail` is the
    /// fault's primary u32 payload (0 if the variant carries none).
    Fault,
    /// `--break-at` matched. `detail` is the break address.
    Break,
    /// `--max-steps` reached. `detail` is the configured max.
    MaxSteps,
}

impl SnapshotKind {
    fn to_byte(self) -> u8 {
        match self {
            Self::AfterStep => 0,
            Self::Exit => 1,
            Self::Fault => 2,
            Self::Break => 3,
            Self::MaxSteps => 4,
        }
    }

    fn from_byte(b: u8) -> Option<Self> {
        Some(match b {
            0 => Self::AfterStep,
            1 => Self::Exit,
            2 => Self::Fault,
            3 => Self::Break,
            4 => Self::MaxSteps,
            _ => return None,
        })
    }

    /// Human-readable label for diff output.
    #[must_use]
    pub fn label(self) -> &'static str {
        match self {
            Self::AfterStep => "after-step",
            Self::Exit => "exit",
            Self::Fault => "fault",
            Self::Break => "break",
            Self::MaxSteps => "max-steps",
        }
    }
}

/// A point-in-time capture of guest state.
///
/// Owns its memory bytes. The struct is intentionally bulky — a
/// movfuscator-built ELF expands to ~10 MB of `FlatMemory`, and the
/// snapshot includes that verbatim. That's fine for human-driven
/// debugging; don't put one of these in a tight loop.
#[derive(Debug, Clone)]
pub struct Snapshot {
    pub kind: SnapshotKind,
    /// Number of successfully completed `Cpu::step()` calls.
    pub step_count: u64,
    pub regs: [u32; 8],
    pub eip: u32,
    pub sigsegv_handler: Option<u32>,
    pub sigill_handler: Option<u32>,
    /// Kind-specific primary payload — exit status, fault payload,
    /// break addr, max-steps limit. 0 when the kind carries none.
    pub detail: u32,
    pub mem_base: u32,
    pub mem_bytes: Vec<u8>,
}

impl Snapshot {
    /// Snapshot the current state of a CPU + a [`Memory`] region.
    ///
    /// The memory range is `[base, base + len)`. Reads go through the
    /// `Memory` trait so it works for any impl, not just `FlatMemory`.
    /// Returns `Err` if any byte in the range is unmapped.
    ///
    /// # Errors
    ///
    /// Returns [`io::Error`] of kind `InvalidInput` if `mem.read_bytes`
    /// faults — typically because the region passed in extends past
    /// the live memory map.
    #[allow(clippy::too_many_arguments)] // every field of the snapshot must be supplied; grouping into a struct just spreads the work
    pub fn capture<M: Memory + ?Sized>(
        kind: SnapshotKind,
        step_count: u64,
        regs: [u32; 8],
        eip: u32,
        sigsegv_handler: Option<u32>,
        sigill_handler: Option<u32>,
        detail: u32,
        mem: &M,
        mem_base: u32,
        mem_len: u32,
    ) -> Result<Self, io::Error> {
        let mut mem_bytes = vec![0u8; mem_len as usize];
        // FlatMemory exposes `read_bytes(addr, &mut [u8])`. Use the
        // trait so a future paged memory impl works too.
        mem.read_bytes(mem_base, &mut mem_bytes).map_err(|f| {
            io::Error::new(
                io::ErrorKind::InvalidInput,
                format!("memory snapshot read failed: {f:?}"),
            )
        })?;
        Ok(Self {
            kind,
            step_count,
            regs,
            eip,
            sigsegv_handler,
            sigill_handler,
            detail,
            mem_base,
            mem_bytes,
        })
    }

    /// Serialize to a writer. The format is the fixed-layout header
    /// above followed by `mem_bytes`.
    pub fn write_to<W: Write>(&self, w: &mut W) -> io::Result<()> {
        let mut hdr = [0u8; HEADER_LEN];
        hdr[0..4].copy_from_slice(MAGIC);
        hdr[4..6].copy_from_slice(&VERSION.to_le_bytes());
        hdr[6] = self.kind.to_byte();
        hdr[7] = 0;
        hdr[8..16].copy_from_slice(&self.step_count.to_le_bytes());
        for (i, &r) in self.regs.iter().enumerate() {
            let off = 16 + i * 4;
            hdr[off..off + 4].copy_from_slice(&r.to_le_bytes());
        }
        hdr[48..52].copy_from_slice(&self.eip.to_le_bytes());
        hdr[52..56].copy_from_slice(&self.sigsegv_handler.unwrap_or(SENTINEL_NONE).to_le_bytes());
        hdr[56..60].copy_from_slice(&self.sigill_handler.unwrap_or(SENTINEL_NONE).to_le_bytes());
        hdr[60..64].copy_from_slice(&self.detail.to_le_bytes());
        hdr[64..68].copy_from_slice(&self.mem_base.to_le_bytes());
        let mem_len = u32::try_from(self.mem_bytes.len())
            .map_err(|_| io::Error::new(io::ErrorKind::InvalidInput, "mem_bytes >= 4GiB"))?;
        hdr[68..72].copy_from_slice(&mem_len.to_le_bytes());
        w.write_all(&hdr)?;
        w.write_all(&self.mem_bytes)?;
        Ok(())
    }

    /// Convenience: write the snapshot to `path`.
    pub fn write_to_path(&self, path: &Path) -> io::Result<()> {
        let mut f = std::fs::File::create(path)?;
        self.write_to(&mut f)
    }

    /// Deserialize from a reader. Rejects bad magic / unsupported
    /// version / unknown kind / truncated body.
    ///
    /// # Errors
    ///
    /// Surfaces an [`io::Error`] for: bad magic, unsupported version,
    /// unknown kind byte, or a read short of the declared body length.
    ///
    /// # Panics
    ///
    /// The `try_into().unwrap()` calls inside index fixed-length
    /// slices from the already-read 72-byte header; they cannot panic
    /// in practice. Documented for completeness.
    pub fn read_from<R: Read>(r: &mut R) -> io::Result<Self> {
        let mut hdr = [0u8; HEADER_LEN];
        r.read_exact(&mut hdr)?;
        if &hdr[0..4] != MAGIC {
            return Err(io::Error::new(
                io::ErrorKind::InvalidData,
                "snapshot: bad magic",
            ));
        }
        let version = u16::from_le_bytes([hdr[4], hdr[5]]);
        if version != VERSION {
            return Err(io::Error::new(
                io::ErrorKind::InvalidData,
                format!("snapshot: unsupported version {version}"),
            ));
        }
        let kind = SnapshotKind::from_byte(hdr[6]).ok_or_else(|| {
            io::Error::new(
                io::ErrorKind::InvalidData,
                format!("snapshot: unknown kind byte {:#x}", hdr[6]),
            )
        })?;
        let step_count = u64::from_le_bytes(hdr[8..16].try_into().unwrap());
        let mut regs = [0u32; 8];
        for (i, slot) in regs.iter_mut().enumerate() {
            let off = 16 + i * 4;
            *slot = u32::from_le_bytes(hdr[off..off + 4].try_into().unwrap());
        }
        let eip = u32::from_le_bytes(hdr[48..52].try_into().unwrap());
        let sigsegv_raw = u32::from_le_bytes(hdr[52..56].try_into().unwrap());
        let sigill_raw = u32::from_le_bytes(hdr[56..60].try_into().unwrap());
        let detail = u32::from_le_bytes(hdr[60..64].try_into().unwrap());
        let mem_base = u32::from_le_bytes(hdr[64..68].try_into().unwrap());
        let mem_len = u32::from_le_bytes(hdr[68..72].try_into().unwrap()) as usize;
        let mut mem_bytes = vec![0u8; mem_len];
        r.read_exact(&mut mem_bytes)?;
        Ok(Self {
            kind,
            step_count,
            regs,
            eip,
            sigsegv_handler: handler_from_raw(sigsegv_raw),
            sigill_handler: handler_from_raw(sigill_raw),
            detail,
            mem_base,
            mem_bytes,
        })
    }

    /// Convenience: read a snapshot from `path`.
    pub fn read_from_path(path: &Path) -> io::Result<Self> {
        let mut f = std::fs::File::open(path)?;
        Self::read_from(&mut f)
    }
}

fn handler_from_raw(raw: u32) -> Option<u32> {
    if raw == SENTINEL_NONE {
        None
    } else {
        Some(raw)
    }
}

/// Helper for diff output: name a GPR by its `Reg32` index.
#[must_use]
pub fn reg_name(idx: usize) -> &'static str {
    // Same order as Reg32 enum.
    ["eax", "ecx", "edx", "ebx", "esp", "ebp", "esi", "edi"]
        .get(idx)
        .copied()
        .unwrap_or("?")
}

/// Signal-handler labels matching [`Signal`].
#[must_use]
pub fn signal_name(sig: Signal) -> &'static str {
    match sig {
        Signal::Segv => "SIGSEGV",
        Signal::Ill => "SIGILL",
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use movie86_core::FlatMemory;

    fn make_snapshot() -> Snapshot {
        let mut mem = FlatMemory::new_zeroed(0x1000, 0x100);
        mem.write_bytes(0x1000, &[0xde, 0xad, 0xbe, 0xef]).unwrap();
        Snapshot::capture(
            SnapshotKind::AfterStep,
            42,
            [1, 2, 3, 4, 5, 6, 7, 8],
            0x0804_8000,
            Some(0x0804_9000),
            None,
            0xcafe,
            &mem,
            0x1000,
            0x100,
        )
        .unwrap()
    }

    #[test]
    fn snapshot_roundtrips_through_a_buffer() {
        let s = make_snapshot();
        let mut buf: Vec<u8> = Vec::new();
        s.write_to(&mut buf).unwrap();
        // Magic + version + body sanity.
        assert_eq!(&buf[0..4], b"M86S");
        assert_eq!(u16::from_le_bytes([buf[4], buf[5]]), 1);
        // 72-byte header + 0x100 memory = 72 + 256.
        assert_eq!(buf.len(), HEADER_LEN + 0x100);
        let r = Snapshot::read_from(&mut std::io::Cursor::new(&buf)).unwrap();
        assert_eq!(r.kind, SnapshotKind::AfterStep);
        assert_eq!(r.step_count, 42);
        assert_eq!(r.regs, [1, 2, 3, 4, 5, 6, 7, 8]);
        assert_eq!(r.eip, 0x0804_8000);
        assert_eq!(r.sigsegv_handler, Some(0x0804_9000));
        assert_eq!(r.sigill_handler, None);
        assert_eq!(r.detail, 0xcafe);
        assert_eq!(r.mem_base, 0x1000);
        assert_eq!(r.mem_bytes.len(), 0x100);
        assert_eq!(&r.mem_bytes[..4], &[0xde, 0xad, 0xbe, 0xef]);
    }

    #[test]
    fn snapshot_read_rejects_bad_magic() {
        let mut buf = vec![0u8; HEADER_LEN];
        buf[0..4].copy_from_slice(b"XXXX");
        let err = Snapshot::read_from(&mut std::io::Cursor::new(&buf)).unwrap_err();
        assert!(err.to_string().contains("bad magic"));
    }

    #[test]
    fn snapshot_read_rejects_unsupported_version() {
        let s = make_snapshot();
        let mut buf: Vec<u8> = Vec::new();
        s.write_to(&mut buf).unwrap();
        // Bump version to 99.
        buf[4] = 99;
        let err = Snapshot::read_from(&mut std::io::Cursor::new(&buf)).unwrap_err();
        assert!(err.to_string().contains("unsupported version 99"));
    }

    #[test]
    fn snapshot_read_rejects_unknown_kind() {
        let s = make_snapshot();
        let mut buf: Vec<u8> = Vec::new();
        s.write_to(&mut buf).unwrap();
        buf[6] = 250; // not in the SnapshotKind table
        let err = Snapshot::read_from(&mut std::io::Cursor::new(&buf)).unwrap_err();
        assert!(err.to_string().contains("unknown kind"));
    }

    #[test]
    fn snapshot_read_rejects_truncated_body() {
        let s = make_snapshot();
        let mut buf: Vec<u8> = Vec::new();
        s.write_to(&mut buf).unwrap();
        // Cut off half the memory.
        buf.truncate(HEADER_LEN + 0x80);
        let err = Snapshot::read_from(&mut std::io::Cursor::new(&buf)).unwrap_err();
        // io::ErrorKind::UnexpectedEof from read_exact.
        assert_eq!(err.kind(), io::ErrorKind::UnexpectedEof);
    }

    #[test]
    fn sentinel_none_round_trip_for_unset_handlers() {
        let mut s = make_snapshot();
        s.sigsegv_handler = None;
        s.sigill_handler = None;
        let mut buf: Vec<u8> = Vec::new();
        s.write_to(&mut buf).unwrap();
        let r = Snapshot::read_from(&mut std::io::Cursor::new(&buf)).unwrap();
        assert_eq!(r.sigsegv_handler, None);
        assert_eq!(r.sigill_handler, None);
    }
}
