//! Stage-7h7 f64 Rust example: mandelbrot escape-iteration sum.
//!
//! Computes `Σᵢ mandel_iter(cx_i, 0.0, 32)` for cx_i sweeping
//! `-2.0, -1.75, …, 1.75` (16 points along the real axis),
//! accumulates the sum in an f64 score, and returns the score
//! cast back to i32 (mod 256) as the exit code.
//!
//! Why this set of arithmetic is well-suited to the bring-up:
//!   - all start values are exact powers of two / quarters, so
//!     every intermediate is representable exactly in f64 — the
//!     deterministic answer doesn't depend on rounding-tie
//!     decisions and the cross-platform reference value is
//!     unambiguous;
//!   - each `mandel_iter` call exercises `sitofp` (for the loop
//!     index → cx conversion via `__floatsidf`), `fmul` / `fadd` /
//!     `fsub` (the `z² + c` step), `fcmp ogt` (the
//!     `xx + yy > 4.0` escape check);
//!   - accumulating each iter count into the f64 `score` adds
//!     `uitofp` (`__floatunsidf`), and casting `score as i32` at
//!     the end adds `fptosi` (`__fixdfsi`) — so the example
//!     genuinely covers the i32 ↔ f64 conversion surface beyond
//!     the cheap `i as f64` step (codex-review P2).
//!
//! The 10 points cx ∈ [-2.0, 0.25] lie inside the Mandelbrot set
//! (or right on the period-1 boundary) and return `max_iter = 32`.
//! The 6 outside points return their escape iteration count:
//!     cx=0.5  → 5
//!     cx=0.75 → 3
//!     cx=1.0  → 3   (xx == 4 exactly at i=2, not strict-greater)
//!     cx=1.25 → 2
//!     cx=1.5  → 2
//!     cx=1.75 → 2
//! Total: 10 × 32 + 5 + 3 + 3 + 2 + 2 + 2 = 337
//! Exit code: 337 % 256 = 81.

#![no_std]
#![no_main]

#[panic_handler]
fn panic(_: &core::panic::PanicInfo) -> ! { loop {} }

fn mandel_iter(cx: f64, cy: f64, max_iter: u32) -> u32 {
    let mut x = 0.0_f64;
    let mut y = 0.0_f64;
    let mut i: u32 = 0;
    while i < max_iter {
        let xx = x * x;
        let yy = y * y;
        if xx + yy > 4.0 {
            return i;
        }
        let two_xy = 2.0 * x * y;
        x = xx - yy + cx;
        y = two_xy + cy;
        i += 1;
    }
    max_iter
}

#[unsafe(no_mangle)]
pub extern "C" fn mandelbrot_main() -> i32 {
    // Accumulate in f64 so the loop exercises `uitofp` on the iter
    // count and `to_int_unchecked` at the tail exercises raw `fptosi`.
    // 337 fits exactly in an f64 mantissa, so the round-trip is
    // bit-exact.
    //
    // We use `to_int_unchecked` (which lowers to a plain LLVM
    // `fptosi`) instead of `as i32` (which Rust 1.45+ lowers to
    // `llvm.fptosi.sat.i32.f64`). Our backend has no Custom
    // FP_TO_SINT_SAT lowering yet, so SDAG falls back to expanding
    // the saturating intrinsic into a NaN/range compare-cascade of
    // libcall fcmps — which combines so poorly with the bit-blended
    // selects that compilation times out. The `to_int_unchecked`
    // form is sound here because the score is bounded by 32×16 = 512
    // (well inside i32 range) and never NaN. (Lifting the FP_TO_SINT_
    // SAT restriction is a backend follow-up; once it's done, `as
    // i32` will work without the safety dance.)
    let mut score: f64 = 0.0;
    let mut i: i32 = 0;
    while i < 16 {
        // cx ranges over -2.0, -1.75, …, 1.75 with step 0.25.
        let cx: f64 = -2.0 + (i as f64) * 0.25;
        let iter = mandel_iter(cx, 0.0, 32);
        score = score + (iter as f64);
        i += 1;
    }
    // SAFETY: score ≤ 512 (< i32::MAX) and is not NaN by construction
    // (all inputs are exact rationals).
    unsafe { score.to_int_unchecked::<i32>() }
}
