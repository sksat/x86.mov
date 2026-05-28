#![no_std]

#[panic_handler]
fn panic(_: &core::panic::PanicInfo) -> ! { loop {} }

use base64::Engine;
use base64::engine::general_purpose::STANDARD;

// Compiler-rt stubs (div/rem only). The backend selects 32-bit MUL
// to MUL32{rr,ri} pseudos with byte-table lowering at stage 7f, so
// `__mulsi3` is no longer needed — every `q * d` here lowers
// directly into the mov-only schoolbook chain. The DIV/REM stubs
// still go through their libcall names because the byte-chain
// legalize for them hasn't landed yet (see future work).
#[inline(always)]
fn udiv(n: u32, d: u32) -> u32 {
    if d == 0 { return 0; }
    let mut q: u32 = 0;
    let mut r: u32 = 0;
    let mut i: i32 = 31;
    while i >= 0 {
        r = (r << 1) | ((n >> i as u32) & 1);
        if r >= d { r = r - d; q = q | (1u32 << i as u32); }
        i = i - 1;
    }
    q
}
#[unsafe(no_mangle)] pub extern "C" fn __udivsi3(n: u32, d: u32) -> u32 { udiv(n, d) }
#[unsafe(no_mangle)] pub extern "C" fn __umodsi3(n: u32, d: u32) -> u32 {
    let q = udiv(n, d); n.wrapping_sub(q.wrapping_mul(d))
}
#[unsafe(no_mangle)] pub extern "C" fn __divsi3(a: i32, b: i32) -> i32 {
    let neg = (a < 0) ^ (b < 0);
    let abs_a = if a < 0 { (a as u32).wrapping_neg() } else { a as u32 };
    let abs_b = if b < 0 { (b as u32).wrapping_neg() } else { b as u32 };
    let r = udiv(abs_a, abs_b) as i32;
    if neg { r.wrapping_neg() } else { r }
}
#[unsafe(no_mangle)] pub extern "C" fn __modsi3(a: i32, b: i32) -> i32 {
    let abs_a = if a < 0 { (a as u32).wrapping_neg() } else { a as u32 };
    let abs_b = if b < 0 { (b as u32).wrapping_neg() } else { b as u32 };
    let q = udiv(abs_a, abs_b);
    let r = abs_a.wrapping_sub(q.wrapping_mul(abs_b)) as i32;
    if a < 0 { r.wrapping_neg() } else { r }
}
#[unsafe(no_mangle)]
pub unsafe extern "C" fn memset(dst: *mut u8, c: i32, n: usize) -> *mut u8 {
    let mut i: usize = 0;
    while i < n { unsafe { *dst.add(i) = c as u8; } i = i + 1; }
    dst
}
#[unsafe(no_mangle)]
pub unsafe extern "C" fn memcpy(dst: *mut u8, src: *const u8, n: usize) -> *mut u8 {
    let mut i: usize = 0;
    while i < n { unsafe { *dst.add(i) = *src.add(i); } i = i + 1; }
    dst
}

#[unsafe(no_mangle)]
pub static BASE64_INPUT: &[u8] = b"SGVsbG8sIFdvcmxkIQ==";

#[unsafe(no_mangle)]
pub extern "C" fn base64_decode_main() -> i32 {
    let mut out = [0u8; 16];
    let n = match STANDARD.decode_slice(BASE64_INPUT, &mut out) {
        Ok(n) => n,
        Err(_) => return -1,
    };
    let mut sum: u32 = 0;
    let mut i: usize = 0;
    while i < n { sum = sum + out[i] as u32; i = i + 1; }
    (sum & 0xff) as i32
}
