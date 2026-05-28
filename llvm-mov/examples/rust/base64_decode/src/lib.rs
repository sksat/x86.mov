#![no_std]

#[panic_handler]
fn panic(_: &core::panic::PanicInfo) -> ! { loop {} }

use base64::Engine;
use base64::engine::general_purpose::STANDARD;

// compiler-rt stubs are no longer required: MUL32{rr,ri} (stage 7f1)
// covers `__mulsi3`, and stage 7f2's llvm-mov-llc driver injects
// `__udivsi3 / __umodsi3 / __divsi3 / __modsi3` bodies into any module
// whose IR uses udiv/sdiv/urem/srem. Only memset/memcpy stay here
// because the backend's libcall set still routes through them.
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
