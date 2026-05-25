//! Stage-6.5 example: smallest end-to-end Rust → mov-only x86 ELF.
//!
//! Constraints (per the stage-6.5 design pass): `no_std`, `no_main`,
//! `panic=abort`, `extern "C"`, scalar `i32` return, no args. The
//! function name is `rust_main` (NOT `main`); `_start.s` calls it.
//!
//! Anything richer (FP, atomics, struct return, dynamic alloca,
//! formatting) currently lies outside the Mov backend's supported IR
//! surface — see [`run.sh`](run.sh) for the data-layout-mismatch note
//! and [`README.md`](README.md) for the broader rationale.

#![no_std]
#![no_main]

/// Required for `no_std` + `panic=abort`. We never actually panic from
/// `rust_main`, so the loop body is unreachable in practice.
#[panic_handler]
fn panic(_: &core::panic::PanicInfo) -> ! { loop {} }

/// Mirrors the C `int rust_main(void)`. The hand-written `_start.s` does
/// `call rust_main; mov ebx, eax; mov eax, 1; int 0x80`, so the value
/// returned here becomes the process exit code (mod 256).
#[no_mangle]
pub extern "C" fn rust_main() -> i32 {
    42
}
