//! Canonical guest-state snapshot for engine handoff between movie86
//! and turbo86.
//!
//! Schema mirrors turbo86's `proto.Context` so a `Context` captured in
//! either engine can be loaded into the other and execution resumed
//! from the same machine state. Pure data — JSON serialization lives
//! on each engine's wire boundary (movie86-cli, movie86-wasm).
//!
//! What this carries:
//! - All 8 32-bit GPRs + EIP + EFLAGS (movie86 captures EFLAGS as 0
//!   and ignores on load — movie86 has no flags register today, and
//!   the schema field is preserved so wire payloads match turbo86's
//!   byte-for-byte for the same logical state).
//! - One or more sparse memory regions. The capture helper
//!   [`capture_sparse_regions`] walks a [`Memory`] page by page,
//!   emits only non-zero pages, and merges adjacent ones — the same
//!   algorithm turbo86's `snapshotMemory` runs over its ptrace'd
//!   guest's mmap regions.
//!
//! What this does NOT carry (v1):
//! - Signal handler dispositions. The receiving engine re-scans the
//!   ELF symbol table for `dispatch` / `master_loop`. Both engines
//!   already do this at load time. (Tracked as a follow-up; turbo86's
//!   DESIGN.md flags signal-disposition as deferred for the same
//!   reason.)
//! - Step count, fault kind, snapshot reason. Those are debug
//!   metadata, not migration-load-bearing — they live on the cli
//!   `Snapshot` type.

use alloc::vec::Vec;

use crate::cpu::Cpu;
use crate::insn::Reg32;
use crate::{Fault, Memory};

/// One contiguous chunk of guest memory.
///
/// `addr` is the starting guest virtual address; `bytes.len()` gives
/// the extent. Multiple regions may be disjoint or overlap; on load
/// they are applied in array order so a later region wins for
/// overlapping bytes.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MemRegion {
    pub addr: u32,
    pub bytes: Vec<u8>,
}

/// An address range the receiver must map before resuming, even when
/// the snapshot carries no bytes for it. Mirrors turbo86's
/// `proto.Reservation`. The motivating case is the mov-only ABI
/// `mmap_request` side effect: the sender executed the request, the
/// resulting page is still all-zero, so `capture_sparse_regions`
/// skipped it — but the next guest write expects the page to be
/// mapped. Receivers with a fixed [`FlatMemory`] (movie86 core)
/// treat reservations as a no-op; receivers that mmap dynamically
/// (turbo86) replay them at load time.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Reservation {
    pub addr: u32,
    pub size: u32,
}

/// Canonical i386 register set for migration.
///
/// Field order matches turbo86's `proto.Regs` so a JSON encoder can
/// map field-by-field. movie86 doesn't model EFLAGS today, so on
/// capture it's always 0 and on load it's ignored.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct Regs {
    pub eax: u32,
    pub ebx: u32,
    pub ecx: u32,
    pub edx: u32,
    pub esi: u32,
    pub edi: u32,
    pub ebp: u32,
    pub esp: u32,
    pub eip: u32,
    pub eflags: u32,
}

impl Regs {
    /// Capture the architectural register state of a [`Cpu`].
    /// `eflags` is always 0 — movie86 doesn't model the flags register.
    #[must_use]
    pub fn from_cpu(cpu: &Cpu) -> Self {
        Self {
            eax: cpu.reg(Reg32::Eax),
            ebx: cpu.reg(Reg32::Ebx),
            ecx: cpu.reg(Reg32::Ecx),
            edx: cpu.reg(Reg32::Edx),
            esi: cpu.reg(Reg32::Esi),
            edi: cpu.reg(Reg32::Edi),
            ebp: cpu.reg(Reg32::Ebp),
            esp: cpu.reg(Reg32::Esp),
            eip: cpu.eip,
            eflags: 0,
        }
    }

    /// Apply the register set to a [`Cpu`]. `eflags` is ignored —
    /// movie86 doesn't model the flags register.
    pub fn load_into(&self, cpu: &mut Cpu) {
        cpu.set_reg(Reg32::Eax, self.eax);
        cpu.set_reg(Reg32::Ebx, self.ebx);
        cpu.set_reg(Reg32::Ecx, self.ecx);
        cpu.set_reg(Reg32::Edx, self.edx);
        cpu.set_reg(Reg32::Esi, self.esi);
        cpu.set_reg(Reg32::Edi, self.edi);
        cpu.set_reg(Reg32::Ebp, self.ebp);
        cpu.set_reg(Reg32::Esp, self.esp);
        cpu.eip = self.eip;
    }
}

/// Page size for [`capture_sparse_regions`]. Matches turbo86's 4 KiB
/// granularity — making the on-wire payloads from the two engines
/// identical for the same logical memory state.
pub const SPARSE_PAGE_SIZE: u32 = 4096;

/// A transferable guest-state snapshot. Receivers apply [`Context::regions`]
/// to memory first, then load [`Context::regs`] into the CPU, then continue
/// execution. [`Context::reservations`] declares additional ranges that
/// need to be mapped on the receiver but carry no bytes (e.g. an ABI
/// `mmap_request` whose page was still zero at snapshot time).
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct Context {
    pub regs: Regs,
    pub regions: Vec<MemRegion>,
    pub reservations: Vec<Reservation>,
}

/// Walk `mem` from `base` to `base + len` page by page, emitting only
/// the non-zero pages merged into runs of adjacent non-zero pages.
///
/// The same algorithm turbo86's `snapshotMemory` runs over its
/// ptrace'd guest's mmap regions — keeping the two implementations
/// algorithmically identical means a captured Context has the same
/// wire shape regardless of which engine produced it.
///
/// The final page is truncated at the requested `len` boundary so no
/// off-end bytes leak when `len` is not a multiple of the page size.
///
/// # Errors
///
/// Returns the first [`Fault`] encountered while reading a page from
/// `mem`. A typical cause is `len` extending past the mapped region.
pub fn capture_sparse_regions<M: Memory + ?Sized>(
    mem: &M,
    base: u32,
    len: u32,
) -> Result<Vec<MemRegion>, Fault> {
    let mut regions: Vec<MemRegion> = Vec::new();
    if len == 0 {
        return Ok(regions);
    }

    let mut current: Option<MemRegion> = None;
    let page = SPARSE_PAGE_SIZE;
    let mut offset: u32 = 0;
    while offset < len {
        let remaining = len - offset;
        let this_page = remaining.min(page);
        let addr = base.wrapping_add(offset);

        let mut buf: Vec<u8> = alloc::vec![0u8; this_page as usize];
        mem.read_bytes(addr, &mut buf)?;

        let any_nonzero = buf.iter().any(|&b| b != 0);
        if any_nonzero {
            match current.as_mut() {
                Some(run) => run.bytes.extend_from_slice(&buf),
                None => current = Some(MemRegion { addr, bytes: buf }),
            }
        } else if let Some(run) = current.take() {
            regions.push(run);
        }

        offset = offset.saturating_add(this_page);
    }
    if let Some(run) = current.take() {
        regions.push(run);
    }
    Ok(regions)
}

/// Apply each region of `ctx` to `mem` in array order, then load
/// `ctx.regs` into `cpu`. Convenience for the common case; callers
/// that need to interleave region writes with other setup can do the
/// two steps manually.
///
/// # Errors
///
/// Returns the first [`Fault`] from `mem.write_bytes` — typically the
/// region extends past the mapped extent.
pub fn load_context<M: Memory + ?Sized>(
    ctx: &Context,
    cpu: &mut Cpu,
    mem: &mut M,
) -> Result<(), Fault> {
    for region in &ctx.regions {
        mem.write_bytes(region.addr, &region.bytes)?;
    }
    ctx.regs.load_into(cpu);
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::FlatMemory;

    #[test]
    fn regs_round_trip_through_cpu_preserves_all_gprs_and_eip() {
        let mut cpu = Cpu::new(0xdead_beef);
        cpu.set_reg(Reg32::Eax, 0x1111_1111);
        cpu.set_reg(Reg32::Ecx, 0x2222_2222);
        cpu.set_reg(Reg32::Edx, 0x3333_3333);
        cpu.set_reg(Reg32::Ebx, 0x4444_4444);
        cpu.set_reg(Reg32::Esp, 0x5555_5555);
        cpu.set_reg(Reg32::Ebp, 0x6666_6666);
        cpu.set_reg(Reg32::Esi, 0x7777_7777);
        cpu.set_reg(Reg32::Edi, 0x8888_8888);
        let r = Regs::from_cpu(&cpu);
        assert_eq!(r.eax, 0x1111_1111);
        assert_eq!(r.ecx, 0x2222_2222);
        assert_eq!(r.edx, 0x3333_3333);
        assert_eq!(r.ebx, 0x4444_4444);
        assert_eq!(r.esp, 0x5555_5555);
        assert_eq!(r.ebp, 0x6666_6666);
        assert_eq!(r.esi, 0x7777_7777);
        assert_eq!(r.edi, 0x8888_8888);
        assert_eq!(r.eip, 0xdead_beef);
        assert_eq!(r.eflags, 0, "movie86 captures eflags as 0");

        let mut other = Cpu::new(0);
        r.load_into(&mut other);
        assert_eq!(Regs::from_cpu(&other), r);
    }

    #[test]
    fn capture_sparse_regions_emits_nothing_for_all_zero_memory() {
        let mem = FlatMemory::new_zeroed(0x1000, 0x4000);
        let regions = capture_sparse_regions(&mem, 0x1000, 0x4000).unwrap();
        assert!(regions.is_empty());
    }

    #[test]
    fn capture_sparse_regions_merges_adjacent_nonzero_pages_into_one_run() {
        // Two adjacent 4 KiB pages, both touched: one MemRegion 8 KiB long.
        let mut mem = FlatMemory::new_zeroed(0x1000, 0x4000);
        mem.write_u8(0x1000, 1).unwrap();
        mem.write_u8(0x2010, 2).unwrap();
        let regions = capture_sparse_regions(&mem, 0x1000, 0x4000).unwrap();
        assert_eq!(regions.len(), 1);
        assert_eq!(regions[0].addr, 0x1000);
        assert_eq!(regions[0].bytes.len(), 0x2000);
        assert_eq!(regions[0].bytes[0], 1);
        assert_eq!(regions[0].bytes[0x1010], 2);
    }

    #[test]
    fn capture_sparse_regions_separates_runs_across_a_zero_page() {
        // Touch pages 0 and 2 (not 1) — should emit two regions.
        let mut mem = FlatMemory::new_zeroed(0x1000, 0x4000);
        mem.write_u8(0x1000, 1).unwrap();
        mem.write_u8(0x3000, 2).unwrap();
        let regions = capture_sparse_regions(&mem, 0x1000, 0x4000).unwrap();
        assert_eq!(regions.len(), 2);
        assert_eq!(regions[0].addr, 0x1000);
        assert_eq!(regions[0].bytes.len(), 0x1000);
        assert_eq!(regions[1].addr, 0x3000);
        assert_eq!(regions[1].bytes.len(), 0x1000);
    }

    #[test]
    fn capture_sparse_regions_truncates_final_page_at_len_boundary() {
        // 5 KiB scan: page 0 is full 4 KiB, page 1 is 1 KiB. Both touched.
        let mut mem = FlatMemory::new_zeroed(0x1000, 0x2000);
        mem.write_u8(0x1000, 1).unwrap();
        mem.write_u8(0x2010, 2).unwrap();
        let regions = capture_sparse_regions(&mem, 0x1000, 0x1400).unwrap();
        assert_eq!(regions.len(), 1);
        assert_eq!(regions[0].bytes.len(), 0x1400);
    }

    #[test]
    fn capture_sparse_regions_empty_len_returns_empty() {
        let mem = FlatMemory::new_zeroed(0x1000, 0x1000);
        let regions = capture_sparse_regions(&mem, 0x1000, 0).unwrap();
        assert!(regions.is_empty());
    }

    #[test]
    fn capture_sparse_regions_propagates_read_fault_outside_mapped_range() {
        let mem = FlatMemory::new_zeroed(0x1000, 0x1000);
        let err = capture_sparse_regions(&mem, 0x1000, 0x2000).unwrap_err();
        assert!(matches!(err, Fault::Unmapped(_)));
    }

    #[test]
    fn context_round_trip_through_cpu_and_memory_preserves_state() {
        let mut mem = FlatMemory::new_zeroed(0x1000, 0x4000);
        mem.write_u32(0x1000, 0xdead_beef).unwrap();
        mem.write_u32(0x3000, 0xcafe_d00d).unwrap();
        let mut cpu = Cpu::new(0x1234);
        cpu.set_reg(Reg32::Eax, 42);
        cpu.set_reg(Reg32::Esp, 0x4000);

        let ctx = Context {
            regs: Regs::from_cpu(&cpu),
            regions: capture_sparse_regions(&mem, 0x1000, 0x4000).unwrap(),
            reservations: Vec::new(),
        };

        // Load into a fresh CPU + zero memory of the same extent.
        let mut mem2 = FlatMemory::new_zeroed(0x1000, 0x4000);
        let mut cpu2 = Cpu::new(0);
        load_context(&ctx, &mut cpu2, &mut mem2).unwrap();

        assert_eq!(Regs::from_cpu(&cpu2), ctx.regs);
        assert_eq!(mem2.read_u32(0x1000).unwrap(), 0xdead_beef);
        assert_eq!(mem2.read_u32(0x3000).unwrap(), 0xcafe_d00d);
        // Zero pages between the two writes stay zero.
        assert_eq!(mem2.read_u32(0x2000).unwrap(), 0);
    }

    #[test]
    fn eflags_is_dropped_silently_on_load_since_movie86_does_not_model_it() {
        let mut cpu = Cpu::new(0x100);
        let r = Regs {
            eflags: 0xFFFF_FFFF,
            ..Default::default()
        };
        r.load_into(&mut cpu);
        let captured = Regs::from_cpu(&cpu);
        assert_eq!(captured.eflags, 0, "EFLAGS round-trips as 0");
    }
}
