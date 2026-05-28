//! Stage-6e indirect-call demo: a function-pointer dispatch through
//! a formal `extern "C" fn(i32) -> i32` argument. `apply` is the
//! site that contains the actual `CALL32r` (the callee comes from
//! the stack-passed function-pointer parameter, not from a known
//! global symbol).
//!
//! `#[inline(never)]` on `apply` is belt-and-braces: at opt-level=0
//! rustc won't inline anyway, but the attribute guarantees the
//! function-pointer arg stays a runtime value even if the build
//! profile or rustc version gets bumped — otherwise the call would
//! collapse to a direct CALL32d to `add25` and we'd silently stop
//! exercising the new codepath.
//!
//! `indirect_call_main` calls `apply(add25, 17)`, so `apply` invokes
//! `add25(17) = 42` indirectly. The runner exits with `eax & 0xff`
//! → 42.

#![no_std]
#![no_main]

#[panic_handler]
fn panic(_: &core::panic::PanicInfo) -> ! { loop {} }

#[unsafe(no_mangle)]
pub extern "C" fn add25(x: i32) -> i32 {
    x + 25
}

#[inline(never)]
#[unsafe(no_mangle)]
pub extern "C" fn apply(f: extern "C" fn(i32) -> i32, x: i32) -> i32 {
    f(x)
}

#[unsafe(no_mangle)]
pub extern "C" fn indirect_call_main() -> i32 {
    apply(add25, 17)
}
