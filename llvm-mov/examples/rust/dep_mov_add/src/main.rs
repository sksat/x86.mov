//! Smallest possible "user crate + path dep" demo for issue #11
//! Option C. Body of the work lives in `triv_dep::triv_add` so the
//! dep's `.o` is what we want to drive through llvm-mov-llc; the
//! user crate is reduced to a single cross-crate call.
//!
//! Returns 42 → `_start.s` puts it into `ebx` and `int 0x80`s.

#![no_std]
#![no_main]

#[panic_handler]
fn panic(_: &core::panic::PanicInfo) -> ! {
    loop {}
}

#[unsafe(no_mangle)]
pub extern "C" fn dep_mov_add_main() -> i32 {
    triv_dep::triv_add(40, 2) as i32
}
