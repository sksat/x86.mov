// Host-rustc smoke fixture for `rsHostToIR()`. Mirrors the existing
// `examples/rust/main/src/main.rs` source (edition 2024 +
// `#[unsafe(no_mangle)]`) so the bypass path covers the same surface
// our cargo-built example uses.
//
// Native invocation (what the test runs):
//
//   rustc --edition=2024 --crate-type=lib --target=i686-unknown-linux-gnu \
//         --emit=llvm-ir -C panic=abort -C overflow-checks=false \
//         -C opt-level=2 -C debuginfo=0 -C strip=symbols host_ret_42.rs
//
// Requires the host toolchain to have `i686-unknown-linux-gnu` added:
//
//   rustup target add i686-unknown-linux-gnu

#![no_std]

#[panic_handler]
fn panic(_: &core::panic::PanicInfo) -> ! {
    loop {}
}

#[unsafe(no_mangle)]
pub extern "C" fn rust_main() -> i32 {
    42
}
