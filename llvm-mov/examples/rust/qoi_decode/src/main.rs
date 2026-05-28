//! Full no_std QOI decode via the `qoi = "0.4", default-features = false"`
//! crate. Embeds a hand-built 2x2 RGBA fixture (4 pixels via
//! QOI_OP_RGBA chunks), runs `Decoder::decode_to_buf` into a stack
//! `[u8; 16]`, and returns the byte sum mod 256.
//!
//! Pixel sum = (10+20+30+255) + (40+50+60+255) + (70+80+90+255)
//!           + (100+110+120+255) = 1800.
//! 1800 mod 256 = 8.

#![no_std]
#![no_main]

#[panic_handler]
fn panic(_: &core::panic::PanicInfo) -> ! { loop {} }

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
