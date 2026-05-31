// Stage-6.5 trivial Rust fixture, mirroring tests/fixtures/ret_42.c.
//
// Edition 2021 (not 2024) so the same source can be compiled by older
// rustc versions — the wasm side currently uses the rubrc v0.2.0
// artefact which is built from Rust 1.79 (pre-edition-2024). The
// version-switch design (see llvm-mov.mjs `RUSTC_VERSIONS`) lets us
// later swap in a 1.96+ rustc.wasm and migrate this fixture to 2024
// (`#[unsafe(no_mangle)]`) without touching the wrapper.
//
// Build shape (native side of the parity test):
//
//   rustc --edition=2021 --crate-type=lib --target=i686-unknown-linux-gnu \
//         --emit=llvm-ir -C panic=abort -C overflow-checks=false \
//         -C opt-level=2 -C debuginfo=0 -C strip=symbols ret_42.rs

#![no_std]

#[panic_handler]
fn panic(_: &core::panic::PanicInfo) -> ! {
    loop {}
}

#[no_mangle]
pub extern "C" fn rust_main() -> i32 {
    42
}
