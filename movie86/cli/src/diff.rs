//! Snapshot-to-snapshot diff with span-based memory output.
//!
//! Smart-friend's review pinned the gotcha: a movfuscator binary's
//! `FlatMemory` is ~10 MB end-to-end. Listing every changed byte is
//! unreadable. So this module
//!
//! 1. computes byte-level differences (that's the source of truth),
//! 2. coalesces adjacent / near-adjacent changes into ranges so the
//!    output stays bounded, and
//! 3. summarizes by 4 KiB pages so you can see structural location at
//!    a glance ("the stack" vs "data segment" vs "heap").
//!
//! Output is plain text — easy to grep, easy to paste into a PR
//! comment. Returns a `String` so the CLI can `print!` it and tests
//! can assert on it.

use std::fmt::Write as _;

use crate::snapshot::{reg_name, signal_name, Snapshot};
use movie86_core::Signal;

/// Treat two changed byte spans as one when they're within this many
/// equal bytes of each other. Tunable trade-off: small gap → more
/// faithful ranges; large gap → tighter summary.
const COALESCE_GAP: u32 = 16;

/// Maximum number of detailed range entries to print before
/// truncating to a TOTAL summary line. Beyond this, individual ranges
/// stop being useful and you want the page summary anyway.
const MAX_RANGE_ENTRIES: usize = 32;

/// One coalesced "memory changed here" span.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ChangedRange {
    /// Inclusive start address (guest).
    pub start: u32,
    /// Inclusive end address (guest).
    pub end: u32,
    /// Number of bytes in `[start, end]` that actually differ between
    /// the two snapshots. (`end - start + 1` is the *span*; this is
    /// the strict number of changed bytes inside it.)
    pub changed_bytes: u32,
}

impl ChangedRange {
    #[must_use]
    pub fn span(&self) -> u32 {
        self.end.wrapping_sub(self.start).wrapping_add(1)
    }
}

/// Compute coalesced byte-difference ranges between two equal-base /
/// equal-length raw byte buffers, starting at `base`.
///
/// Two changed bytes get merged into one [`ChangedRange`] when the
/// gap between them is `< COALESCE_GAP` bytes. The `changed_bytes`
/// field still reflects the *actual* count of differing bytes inside
/// the span, so callers see the merge without losing fidelity.
///
/// # Panics
///
/// Panics if `a.len() != b.len()`. Callers must check structural
/// equality (`mem_base` + length) before invoking — [`diff_snapshots`]
/// already does this and only calls into here on success.
#[must_use]
pub fn changed_ranges(a: &[u8], b: &[u8], base: u32) -> Vec<ChangedRange> {
    assert_eq!(a.len(), b.len(), "callers must check equal-length first");
    let mut out: Vec<ChangedRange> = Vec::new();
    let mut i: usize = 0;
    while i < a.len() {
        if a[i] == b[i] {
            i += 1;
            continue;
        }
        // Found a difference. Walk forward, treating any run of <=
        // COALESCE_GAP equal bytes as still being part of this range.
        let range_start = i;
        let mut last_diff = i;
        let mut changed: u32 = 1;
        let mut j = i + 1;
        while j < a.len() {
            if a[j] == b[j] {
                // Look ahead: if a difference reappears within the
                // gap, keep going; otherwise close this range.
                let gap_end = j.saturating_add(COALESCE_GAP as usize).min(a.len());
                let found = ((j + 1)..gap_end).any(|k| a[k] != b[k]);
                if found {
                    j += 1;
                } else {
                    break;
                }
            } else {
                last_diff = j;
                changed = changed.saturating_add(1);
                j += 1;
            }
        }
        out.push(ChangedRange {
            start: base.wrapping_add(u32::try_from(range_start).unwrap_or(u32::MAX)),
            end: base.wrapping_add(u32::try_from(last_diff).unwrap_or(u32::MAX)),
            changed_bytes: changed,
        });
        i = last_diff + 1;
    }
    out
}

/// Bucket the changed-byte counts by 4 KiB page.
fn page_summary(changed: &[ChangedRange]) -> Vec<(u32, u32)> {
    const PAGE_SHIFT: u32 = 12; // 4 KiB
    let mut map: std::collections::BTreeMap<u32, u32> = std::collections::BTreeMap::new();
    for r in changed {
        // Distribute changed_bytes across the pages the range covers.
        // Span > page is rare for movfuscator output (most writes are
        // local), but handle it honestly: count *each page's share*.
        // Approximation: assume changed bytes are uniformly distributed
        // across the span. Good enough for "where did writes happen".
        let span = u64::from(r.span());
        let mut addr = r.start;
        let mut remaining = u64::from(r.changed_bytes);
        while addr <= r.end && remaining > 0 {
            let page = addr & !((1u32 << PAGE_SHIFT) - 1);
            let page_end = page.saturating_add((1u32 << PAGE_SHIFT) - 1);
            let span_in_page =
                u64::from(page_end.min(r.end).saturating_sub(addr).saturating_add(1));
            // Ceil-divide weighted share. span == 0 is impossible here
            // (we'd never have entered the loop), but use checked_div
            // to make that explicit and avoid a clippy-flagged manual
            // ceil-div.
            let share = (remaining * span_in_page)
                .checked_div(span)
                .map_or(remaining, |q| {
                    if remaining * span_in_page % span == 0 {
                        q
                    } else {
                        q + 1
                    }
                });
            let share_u32 = u32::try_from(share.min(remaining)).unwrap_or(u32::MAX);
            let entry = map.entry(page).or_insert(0);
            *entry = entry.saturating_add(share_u32);
            remaining = remaining.saturating_sub(u64::from(share_u32));
            // Advance to the next page boundary.
            addr = page_end.saturating_add(1);
        }
    }
    map.into_iter().collect()
}

/// Render a register comparison line, omitting unchanged ones unless
/// `show_all` is set.
fn reg_diff_line(idx: usize, a: u32, b: u32, show_all: bool) -> Option<String> {
    let name = reg_name(idx);
    if a == b {
        if show_all {
            Some(format!("  {name}: {a:#010x} (unchanged)\n"))
        } else {
            None
        }
    } else {
        Some(format!("  {name}: {a:#010x} → {b:#010x}\n"))
    }
}

fn handler_diff_line(sig: Signal, a: Option<u32>, b: Option<u32>) -> String {
    let fmt = |v: Option<u32>| v.map_or("None".to_string(), |x| format!("{x:#010x}"));
    let label = signal_name(sig);
    if a == b {
        format!("  {label}: {} (unchanged)\n", fmt(a))
    } else {
        format!("  {label}: {} → {}\n", fmt(a), fmt(b))
    }
}

/// Produce a human-readable diff of two snapshots.
///
/// Always prints register and step-count info. Memory diff is
/// performed only when both snapshots agree on `mem_base` and
/// `mem_len`; mismatches surface as a structural-mismatch note.
#[must_use]
#[allow(clippy::too_many_lines)] // narrative top-level report; splitting fragments the story
pub fn diff_snapshots(a: &Snapshot, b: &Snapshot) -> String {
    let mut out = String::new();
    let _ = writeln!(out, "=== movie86 snapshot diff ===");
    let _ = writeln!(
        out,
        "A: {} step={} eip={:#010x} detail={:#010x}",
        a.kind.label(),
        a.step_count,
        a.eip,
        a.detail,
    );
    let _ = writeln!(
        out,
        "B: {} step={} eip={:#010x} detail={:#010x}",
        b.kind.label(),
        b.step_count,
        b.eip,
        b.detail,
    );
    let _ = writeln!(out);

    let step_delta = i128::from(b.step_count) - i128::from(a.step_count);
    let _ = writeln!(out, "step delta: {step_delta:+} steps");
    let _ = writeln!(out);

    let _ = writeln!(out, "registers:");
    let mut reg_changed = false;
    for i in 0..8 {
        if let Some(line) = reg_diff_line(i, a.regs[i], b.regs[i], false) {
            out.push_str(&line);
            reg_changed = true;
        }
    }
    if a.eip != b.eip {
        let _ = writeln!(out, "  eip: {:#010x} → {:#010x}", a.eip, b.eip);
        reg_changed = true;
    }
    if !reg_changed {
        out.push_str("  (no register changes)\n");
    }
    let _ = writeln!(out);

    let _ = writeln!(out, "signal handlers:");
    out.push_str(&handler_diff_line(
        Signal::Segv,
        a.sigsegv_handler,
        b.sigsegv_handler,
    ));
    out.push_str(&handler_diff_line(
        Signal::Ill,
        a.sigill_handler,
        b.sigill_handler,
    ));
    let _ = writeln!(out);

    // Memory structural mismatch is a hard stop for byte-level diff —
    // we can't meaningfully compare regions with different shapes.
    if a.mem_base != b.mem_base || a.mem_bytes.len() != b.mem_bytes.len() {
        let _ = writeln!(
            out,
            "memory base/len MISMATCH: A {:#010x}/{} bytes vs B {:#010x}/{} bytes",
            a.mem_base,
            a.mem_bytes.len(),
            b.mem_base,
            b.mem_bytes.len(),
        );
        let _ = writeln!(out, "(skipping byte-level memory diff)");
        // If literally nothing changed we'd never get here — at minimum
        // the structural mismatch counts as a difference. Don't claim
        // "no differences" in this branch.
        return out;
    }
    let _ = writeln!(
        out,
        "memory base/len match: {:#010x} / {} bytes",
        a.mem_base,
        a.mem_bytes.len(),
    );

    let ranges = changed_ranges(&a.mem_bytes, &b.mem_bytes, a.mem_base);
    let total_changed: u64 = ranges.iter().map(|r| u64::from(r.changed_bytes)).sum();
    let total_span: u64 = ranges.iter().map(|r| u64::from(r.span())).sum();
    let _ = writeln!(
        out,
        "\nmemory deltas (coalesced ranges, gap ≤ {COALESCE_GAP}):"
    );
    if ranges.is_empty() {
        out.push_str("  (none)\n");
    } else {
        for r in ranges.iter().take(MAX_RANGE_ENTRIES) {
            let _ = writeln!(
                out,
                "  [{:#010x}..={:#010x}]  span {} bytes, {} changed",
                r.start,
                r.end,
                r.span(),
                r.changed_bytes,
            );
        }
        if ranges.len() > MAX_RANGE_ENTRIES {
            let _ = writeln!(
                out,
                "  ... ({} more ranges suppressed)",
                ranges.len() - MAX_RANGE_ENTRIES,
            );
        }
        let _ = writeln!(
            out,
            "  TOTAL: {} bytes changed across {} ranges (covering {} bytes of span)",
            total_changed,
            ranges.len(),
            total_span,
        );
    }

    let pages = page_summary(&ranges);
    if !pages.is_empty() {
        let _ = writeln!(out, "\npage summary (4 KiB pages, > 0 bytes changed):");
        for (page, bytes) in &pages {
            let _ = writeln!(out, "  page {page:#010x}: {bytes} bytes");
        }
        let _ = writeln!(out, "  TOTAL: {} pages", pages.len());
    }

    // Tail line that the CLI subcommand uses to choose exit code.
    // `kind` and `detail` participate in the equality check — the report
    // header already shows them, so a diff between (e.g.) an
    // `--snapshot-at-step` capture and a `--snapshot-on-stop` break
    // capture that happen to land on the same eip/regs/mem must NOT
    // claim "no differences".
    if ranges.is_empty()
        && a.kind == b.kind
        && a.detail == b.detail
        && a.step_count == b.step_count
        && a.eip == b.eip
        && a.regs == b.regs
        && a.sigsegv_handler == b.sigsegv_handler
        && a.sigill_handler == b.sigill_handler
    {
        out.push_str("\nresult: no differences\n");
    } else {
        out.push_str("\nresult: differences detected\n");
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::snapshot::SnapshotKind;
    use movie86_core::FlatMemory;

    fn snap_with(regs: [u32; 8], eip: u32, mem_bytes: Vec<u8>, kind: SnapshotKind) -> Snapshot {
        Snapshot {
            kind,
            step_count: 0,
            regs,
            eip,
            sigsegv_handler: None,
            sigill_handler: None,
            detail: 0,
            mem_base: 0x1000,
            mem_bytes,
        }
    }

    #[test]
    fn changed_ranges_finds_single_isolated_byte() {
        let a = vec![0u8; 32];
        let mut b = a.clone();
        b[10] = 0xff;
        let r = changed_ranges(&a, &b, 0x1000);
        assert_eq!(
            r,
            vec![ChangedRange {
                start: 0x1000 + 10,
                end: 0x1000 + 10,
                changed_bytes: 1
            }]
        );
    }

    #[test]
    fn changed_ranges_coalesces_nearby_changes_within_gap() {
        // Two changes 4 bytes apart → one range that spans both.
        let a = vec![0u8; 32];
        let mut b = a.clone();
        b[10] = 0xff;
        b[14] = 0xee;
        let r = changed_ranges(&a, &b, 0x1000);
        assert_eq!(r.len(), 1);
        assert_eq!(r[0].start, 0x1000 + 10);
        assert_eq!(r[0].end, 0x1000 + 14);
        // Two actual changes in a 5-byte span.
        assert_eq!(r[0].changed_bytes, 2);
        assert_eq!(r[0].span(), 5);
    }

    #[test]
    fn changed_ranges_keeps_distant_changes_separate() {
        // Two changes far apart (> COALESCE_GAP) → two ranges.
        let a = vec![0u8; 64];
        let mut b = a.clone();
        b[5] = 0xff;
        b[50] = 0xee;
        let r = changed_ranges(&a, &b, 0x1000);
        assert_eq!(r.len(), 2);
        assert_eq!(r[0].start, 0x1005);
        assert_eq!(r[1].start, 0x1032);
    }

    #[test]
    fn diff_reports_no_differences_for_identical_snapshots() {
        let mem = FlatMemory::new_zeroed(0x1000, 32);
        let regs = [0; 8];
        let _ = mem;
        let a = snap_with(regs, 0x0804_8000, vec![0u8; 32], SnapshotKind::AfterStep);
        let b = a.clone();
        let report = diff_snapshots(&a, &b);
        assert!(
            report.contains("result: no differences"),
            "report:\n{report}"
        );
    }

    #[test]
    fn diff_calls_out_register_and_memory_changes() {
        // Build a + b where eax flips and a single mem byte flips.
        let a = snap_with(
            [1, 0, 0, 0, 0, 0, 0, 0],
            0x0804_8000,
            vec![0u8; 32],
            SnapshotKind::AfterStep,
        );
        let mut b = a.clone();
        b.regs[0] = 42;
        b.mem_bytes[5] = 0xab;
        let report = diff_snapshots(&a, &b);
        assert!(
            report.contains("eax: 0x00000001 → 0x0000002a"),
            "report:\n{report}"
        );
        assert!(
            report.contains("[0x00001005..=0x00001005]"),
            "report:\n{report}"
        );
        assert!(
            report.contains("result: differences detected"),
            "report:\n{report}"
        );
    }

    #[test]
    fn diff_treats_kind_or_detail_mismatch_as_a_difference() {
        // Regression for codex P2-1: a `--snapshot-at-step N` capture
        // and a `--snapshot-on-stop` break capture can land on the
        // same eip/regs/mem (e.g. user broke right at step N). They
        // are NOT the same snapshot — header surfaces `kind`/`detail`,
        // so the equality check has to include them too.
        let a = snap_with(
            [1, 2, 3, 4, 5, 6, 7, 8],
            0x0804_8000,
            vec![0u8; 32],
            SnapshotKind::AfterStep,
        );
        // Same regs + mem + eip, but a Break with the eip-as-detail.
        let mut b = a.clone();
        b.kind = SnapshotKind::Break;
        b.detail = 0x0804_8000;
        let report = diff_snapshots(&a, &b);
        assert!(
            report.contains("result: differences detected"),
            "kind/detail diff must NOT be reported as identical; report:\n{report}",
        );
    }

    #[test]
    fn diff_handles_structural_mismatch_gracefully() {
        let a = snap_with(
            [0u32; 8],
            0x0804_8000,
            vec![0u8; 32],
            SnapshotKind::AfterStep,
        );
        let mut b = a.clone();
        b.mem_base = 0x9000; // different base
        let report = diff_snapshots(&a, &b);
        assert!(report.contains("base/len MISMATCH"), "report:\n{report}");
    }
}
