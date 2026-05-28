//! Full no_std QOI decode via the `qoi = "0.4", default-features = false"`
//! crate. Embeds a hand-built 2x2 RGBA fixture (4 pixels via
//! QOI_OP_RGBA chunks), runs `Decoder::decode_to_buf` into a stack
//! `[u8; 16]`, and returns the byte sum mod 256.
//!
//! Pixel sum = (10+20+30+255) + (40+50+60+255) + (70+80+90+255)
//!           + (100+110+120+255) = 1800.
//! 1800 mod 256 = 8.

#![no_std]

#[panic_handler]
fn panic(_: &core::panic::PanicInfo) -> ! { loop {} }

// libcall stubs — identical shape to examples/rust/base64_decode/.
// Each crate that needs MUL/DIV ships its own copy because the
// backend Expand-s to libcall and we have no compiler-rt to link.

#[inline(always)]
fn umul(mut a: u32, mut b: u32) -> u32 {
    let mut r: u32 = 0;
    let mut i = 0u32;
    while i < 32 {
        if (b & 1) != 0 { r = r.wrapping_add(a); }
        a = a << 1;
        b = b >> 1;
        i = i + 1;
    }
    r
}
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
#[unsafe(no_mangle)] pub extern "C" fn __mulsi3(a: i32, b: i32) -> i32 { umul(a as u32, b as u32) as i32 }
#[unsafe(no_mangle)] pub extern "C" fn __udivsi3(n: u32, d: u32) -> u32 { udiv(n, d) }
#[unsafe(no_mangle)] pub extern "C" fn __umodsi3(n: u32, d: u32) -> u32 {
    let q = udiv(n, d); n.wrapping_sub(umul(q, d))
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
    let r = abs_a.wrapping_sub(umul(q, abs_b)) as i32;
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
pub static QOI_FIXTURE: [u8; 42] = [
    // header: "qoif", width=2, height=2, channels=4, colorspace=0
    0x71, 0x6f, 0x69, 0x66, 0x00, 0x00, 0x00, 0x02,
    0x00, 0x00, 0x00, 0x02, 0x04, 0x00,
    // 4 × QOI_OP_RGBA (1+4=5 bytes each)
    0xff, 0x0a, 0x14, 0x1e, 0xff, 0xff, 0x28, 0x32,
    0x3c, 0xff, 0xff, 0x46, 0x50, 0x5a, 0xff, 0xff,
    0x64, 0x6e, 0x78, 0xff,
    // end marker
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01,
];

#[unsafe(no_mangle)]
pub extern "C" fn qoi_decode_main() -> i32 {
    let mut buf = [0u8; 16];
    let mut decoder = match qoi::Decoder::new(&QOI_FIXTURE[..]) {
        Ok(d) => d,
        Err(_) => return -1,
    };
    if decoder.decode_to_buf(&mut buf).is_err() { return -2; }
    let mut sum: u32 = 0;
    let mut i: usize = 0;
    while i < 16 { sum = sum + buf[i] as u32; i = i + 1; }
    (sum & 0xff) as i32
}
