//! Stage-7d3 recursive Fibonacci in Rust → mov-only x86-32 ELF.
//!
//! Recursion stresses stage-7d1's single-slot
//! `__mov_return_addr_slot` invariant (each `ret` writes its own
//! return address into the global slot and immediately jumps,
//! before any nested call can return). Stage-7d3 (`CALL32d` →
//! `JMP32d_CALL`) sees two call sites per `fib` invocation.
//!
//! Build constraints (same as ../main/):
//!   - `panic=abort`, `overflow-checks=false` so the integer
//!     subtractions in `fib` don't lower to
//!     `llvm.ssub.with.overflow.i32` (the returned `{i32, i1}`
//!     aggregate would need backend work the demo doesn't pull in).
//!
//! `fib_main` returns `fib(24) = 46368`. We pick n=24 (rather than
//! the smaller n=10 the earlier shape used) so the wall-clock
//! benchmark stays well above the bare process-exit overhead —
//! the recursion depth itself is what stresses the return-addr
//! invariant, but the runtime number only becomes meaningful when
//! the compute dominates exec()'s ~150 µs startup. The `_start.s`
//! runner takes the i32 modulo 256 for the exit code; the bench
//! doesn't check it.

#![no_std]
#![no_main]

#[panic_handler]
fn panic(_: &core::panic::PanicInfo) -> ! { loop {} }

#[unsafe(no_mangle)]
pub extern "C" fn fib(n: i32) -> i32 {
    if n < 2 { n } else { fib(n - 1) + fib(n - 2) }
}

#[unsafe(no_mangle)]
pub extern "C" fn fib_main() -> i32 {
    fib(24)
}
