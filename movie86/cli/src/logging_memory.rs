//! Range-limited memory write logger — `--log-writes-in START:END`.
//!
//! Motivation: snapshot+diff answered "did state move between step A
//! and step B?" but not "which instruction wrote to this dispatch
//! cell, in what order?". The multi-add fixture in particular has
//! ~2 bytes of movement per million steps concentrated at a few
//! addresses (movfuscator's `target` / `branch_temp` / dispatch
//! state). To trace the temporal sequence, hook into the Memory
//! write path and log per-write `(step, eip, addr, old → new)` for a
//! caller-supplied range — typically the 3 pages the snapshot diff
//! revealed.
//!
//! Design (smart-friend's option B):
//!
//! - **Wrap, don't change the trait.** `LoggingMemory<M: Memory>`
//!   delegates every operation; for writes that touch a registered
//!   range, it captures `(addr, width, old, new)` into a `pending`
//!   buffer instead of logging directly. The run loop drains the
//!   buffer after each `cpu.step()` and prepends `(step, eip)`. Two
//!   reasons: (a) the Memory trait doesn't know about step counts or
//!   eip, and (b) batching writes by step gives users a clean
//!   per-step log instead of interleaving multiple writes per
//!   instruction.
//!
//! - **Out-of-range writes pay one bounds check.** No allocation, no
//!   inner-trait perturbation. Empty `log_ranges` ⇒ the adapter is a
//!   zero-cost pass-through.
//!
//! - **Old value is the pre-write byte.** Captured by reading the
//!   inner memory before delegating the write. A read fault on the
//!   pre-image is swallowed (logged as 0) — the post-write is what
//!   the user cares about.

use core::ops::Range;

use movie86::{Fault, FlatMemory, Memory};

/// One captured write that fell inside a registered range.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct LoggedWrite {
    pub addr: u32,
    /// Write width in bytes: 1, 2, or 4. `write_bytes` is split into
    /// individual byte entries (rare in practice — only the loader
    /// uses bulk, and the adapter is applied after load).
    pub width: u8,
    /// Pre-write value, zero-extended into u32. Reads that faulted
    /// pre-write surface as 0; the post-write value is the
    /// load-bearing one.
    pub old: u32,
    pub new: u32,
}

/// Memory adapter that records writes inside any of `log_ranges`.
///
/// Wrap once at startup; drain after each `cpu.step()`. When
/// `log_ranges` is empty, every operation passes through with a
/// single empty-Vec check — keep the adapter on the run path
/// unconditionally so the trait bound stays uniform.
#[derive(Debug)]
pub struct LoggingMemory<M: Memory> {
    inner: M,
    log_ranges: Vec<Range<u32>>,
    pending: Vec<LoggedWrite>,
}

impl<M: Memory> LoggingMemory<M> {
    #[must_use]
    pub fn new(inner: M, log_ranges: Vec<Range<u32>>) -> Self {
        Self {
            inner,
            log_ranges,
            pending: Vec::new(),
        }
    }

    /// True when at least one address in `[addr, addr+width)` falls
    /// in a registered range. Cheap when `log_ranges` is empty.
    fn in_log_range(&self, addr: u32, width: u8) -> bool {
        if self.log_ranges.is_empty() {
            return false;
        }
        let end = addr.saturating_add(u32::from(width));
        self.log_ranges
            .iter()
            .any(|r| addr < r.end && end > r.start)
    }

    /// Drain captured writes since the last call. Caller appends
    /// `(step, eip)` context and formats.
    pub fn drain_pending(&mut self) -> Vec<LoggedWrite> {
        core::mem::take(&mut self.pending)
    }

    /// Expose the inner Memory immutably (for tests / introspection).
    #[must_use]
    pub fn inner(&self) -> &M {
        &self.inner
    }
}

impl LoggingMemory<FlatMemory> {
    /// Forward `FlatMemory::base` / `len` for snapshot capture, which
    /// needs the wrapped memory's geometry.
    #[must_use]
    pub fn base(&self) -> u32 {
        self.inner.base()
    }

    #[must_use]
    pub fn len(&self) -> usize {
        self.inner.len()
    }

    #[must_use]
    pub fn is_empty(&self) -> bool {
        self.inner.is_empty()
    }
}

impl<M: Memory> Memory for LoggingMemory<M> {
    fn read_u8(&self, addr: u32) -> Result<u8, Fault> {
        self.inner.read_u8(addr)
    }
    fn read_u16(&self, addr: u32) -> Result<u16, Fault> {
        self.inner.read_u16(addr)
    }
    fn read_u32(&self, addr: u32) -> Result<u32, Fault> {
        self.inner.read_u32(addr)
    }
    fn read_bytes(&self, addr: u32, dst: &mut [u8]) -> Result<(), Fault> {
        self.inner.read_bytes(addr, dst)
    }

    fn write_u8(&mut self, addr: u32, val: u8) -> Result<(), Fault> {
        if self.in_log_range(addr, 1) {
            let old = u32::from(self.inner.read_u8(addr).unwrap_or(0));
            self.pending.push(LoggedWrite {
                addr,
                width: 1,
                old,
                new: u32::from(val),
            });
        }
        self.inner.write_u8(addr, val)
    }

    fn write_u16(&mut self, addr: u32, val: u16) -> Result<(), Fault> {
        if self.in_log_range(addr, 2) {
            let old = u32::from(self.inner.read_u16(addr).unwrap_or(0));
            self.pending.push(LoggedWrite {
                addr,
                width: 2,
                old,
                new: u32::from(val),
            });
        }
        self.inner.write_u16(addr, val)
    }

    fn write_u32(&mut self, addr: u32, val: u32) -> Result<(), Fault> {
        if self.in_log_range(addr, 4) {
            let old = self.inner.read_u32(addr).unwrap_or(0);
            self.pending.push(LoggedWrite {
                addr,
                width: 4,
                old,
                new: val,
            });
        }
        self.inner.write_u32(addr, val)
    }

    fn write_bytes(&mut self, addr: u32, src: &[u8]) -> Result<(), Fault> {
        // Bulk write — split into per-byte log entries so the user
        // sees the actual range. Rare in practice; the ELF loader is
        // the typical caller and it runs before the adapter is set
        // up. Keep correct anyway.
        if !self.log_ranges.is_empty() {
            for (i, &b) in src.iter().enumerate() {
                let a = addr.wrapping_add(u32::try_from(i).unwrap_or(u32::MAX));
                if self.in_log_range(a, 1) {
                    let old = u32::from(self.inner.read_u8(a).unwrap_or(0));
                    self.pending.push(LoggedWrite {
                        addr: a,
                        width: 1,
                        old,
                        new: u32::from(b),
                    });
                }
            }
        }
        self.inner.write_bytes(addr, src)
    }
}

#[cfg(test)]
#[allow(clippy::single_range_in_vec_init)] // tests deliberately use one-range Vecs to mirror the real API shape
mod tests {
    use super::*;

    fn empty_log_mem() -> LoggingMemory<FlatMemory> {
        LoggingMemory::new(FlatMemory::new_zeroed(0x1000, 0x100), Vec::new())
    }

    fn ranged_log_mem(ranges: Vec<Range<u32>>) -> LoggingMemory<FlatMemory> {
        LoggingMemory::new(FlatMemory::new_zeroed(0x1000, 0x100), ranges)
    }

    #[test]
    fn passthrough_when_log_ranges_empty() {
        let mut m = empty_log_mem();
        m.write_u32(0x1004, 0xdead_beef).unwrap();
        assert_eq!(m.read_u32(0x1004).unwrap(), 0xdead_beef);
        // No writes captured — the adapter is a no-op.
        assert!(m.drain_pending().is_empty());
    }

    #[test]
    fn captures_in_range_u32_write_with_old_value() {
        let mut m = ranged_log_mem(vec![0x1000..0x1010]);
        m.write_u32(0x1004, 0xaaaa_bbbb).unwrap();
        m.write_u32(0x1004, 0xcccc_dddd).unwrap();
        let pending = m.drain_pending();
        assert_eq!(pending.len(), 2);
        // First write: pre-image is the freshly-zeroed FlatMemory.
        assert_eq!(
            pending[0],
            LoggedWrite {
                addr: 0x1004,
                width: 4,
                old: 0,
                new: 0xaaaa_bbbb,
            }
        );
        // Second write: pre-image is the first write's payload.
        assert_eq!(
            pending[1],
            LoggedWrite {
                addr: 0x1004,
                width: 4,
                old: 0xaaaa_bbbb,
                new: 0xcccc_dddd,
            }
        );
        // drain is consumptive — calling again returns empty.
        assert!(m.drain_pending().is_empty());
    }

    #[test]
    fn skips_writes_outside_log_range() {
        let mut m = ranged_log_mem(vec![0x1000..0x1010]);
        // Out of range — not captured.
        m.write_u32(0x1020, 0xdead_beef).unwrap();
        assert!(m.drain_pending().is_empty());
        // Verify the inner FlatMemory still got the write.
        assert_eq!(m.read_u32(0x1020).unwrap(), 0xdead_beef);
    }

    #[test]
    fn write_straddling_range_boundary_is_captured() {
        // A u32 at 0x100e (bytes 0x100e..0x1012) overlaps a range
        // that ends at 0x1010 — the first 2 bytes are in-range. The
        // adapter logs the *whole* write, since the range was
        // touched.
        let mut m = ranged_log_mem(vec![0x1000..0x1010]);
        m.write_u32(0x100e, 0x1234_5678).unwrap();
        let pending = m.drain_pending();
        assert_eq!(pending.len(), 1);
        assert_eq!(pending[0].addr, 0x100e);
        assert_eq!(pending[0].width, 4);
        assert_eq!(pending[0].new, 0x1234_5678);
    }

    #[test]
    fn write_u8_and_u16_log_with_correct_widths() {
        let mut m = ranged_log_mem(vec![0x1000..0x1010]);
        m.write_u8(0x1000, 0xab).unwrap();
        m.write_u16(0x1002, 0xbeef).unwrap();
        let pending = m.drain_pending();
        assert_eq!(pending.len(), 2);
        assert_eq!(pending[0].width, 1);
        assert_eq!(pending[0].new, 0xab);
        assert_eq!(pending[1].width, 2);
        assert_eq!(pending[1].new, 0xbeef);
    }

    #[test]
    fn write_bytes_explodes_into_per_byte_entries_when_in_range() {
        // The loader uses write_bytes; we capture per-byte to keep
        // the log consistent with single-byte writes. Only the bytes
        // that land in a log range are recorded.
        let mut m = ranged_log_mem(vec![0x1002..0x1005]);
        m.write_bytes(0x1000, &[0x11, 0x22, 0x33, 0x44, 0x55, 0x66])
            .unwrap();
        let pending = m.drain_pending();
        // bytes 0x1002, 0x1003, 0x1004 are in range. 0x1000, 0x1001,
        // 0x1005 are not.
        assert_eq!(pending.len(), 3);
        assert_eq!(pending[0].addr, 0x1002);
        assert_eq!(pending[0].new, 0x33);
        assert_eq!(pending[1].addr, 0x1003);
        assert_eq!(pending[1].new, 0x44);
        assert_eq!(pending[2].addr, 0x1004);
        assert_eq!(pending[2].new, 0x55);
    }
}
