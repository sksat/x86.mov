//! Stage-6.5 trivial Rust → mov-only x86-32 ELF example.
//!
//! Bin crate, `#![no_main]`: rustc does not emit any entry symbol;
//! the real ELF entry is `_start` in [`../_start.s`](../_start.s),
//! which calls `rust_main` and `int 0x80`s with the return value.
//!
//! Edition 2024: `#[no_mangle]` is now an unsafe attribute. See
//! [`Cargo.toml`](Cargo.toml) for the `panic=abort` /
//! `overflow-checks=false` profile knobs that keep the IR within
//! the Mov backend's supported surface.

#![no_std]
#![no_main]

#[panic_handler]
fn panic(_: &core::panic::PanicInfo) -> ! {
    loop {}
}

#[unsafe(no_mangle)]
pub extern "C" fn rust_main() -> i32 {
    42
}
