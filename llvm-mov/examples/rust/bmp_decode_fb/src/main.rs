//! Full BMP → framebuffer decode for benchmarking, no_std no_alloc.
//!
//! Layout: 32bpp uncompressed, BITMAPINFOHEADER (54-byte total
//! header). Source pixels are BGRA bottom-up; we rewrite them as RGBA
//! top-down into a static OUT buffer. The per-pixel work is one
//! 32-bit load + a byte swap (BGRA → RGBA) + a 32-bit store, so the
//! emitted mov-only code stays in 32-bit register-width territory.
//!
//! Returns a one-byte integrity check (XOR of corner pixels' R).
//! Exits via the mov-only ABI write to `0x1FFE_00FE`.

#![no_std]
#![no_main]

#[panic_handler]
fn panic(_: &core::panic::PanicInfo) -> ! { loop {} }

// compiler-rt stubs.
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

const W: usize = 32;
const H: usize = 32;

// Embed the BMP fixture (32bpp BI_RGB, 54-byte header).
static BMP: &[u8] = include_bytes!("../fixtures/test_32x32.bmp");

// Output framebuffer — 4 bytes per pixel (RGBA), top-down.
static mut OUT: [u8; W * H * 4] = [0; W * H * 4];

#[inline(always)]
fn le_u32(b: &[u8], off: usize) -> u32 {
    (b[off] as u32)
        | ((b[off + 1] as u32) << 8)
        | ((b[off + 2] as u32) << 16)
        | ((b[off + 3] as u32) << 24)
}

#[unsafe(no_mangle)]
pub extern "C" fn main() -> i32 {
    // 1. Signature check.
    if BMP.len() < 54 { return 1; }
    if BMP[0] != b'B' || BMP[1] != b'M' { return 2; }

    // 2. Read pixel-array offset, width, height, bpp.
    let pixel_off = le_u32(BMP, 10) as usize;
    let w = le_u32(BMP, 18) as i32;  // signed: negative h = top-down
    let h = le_u32(BMP, 22) as i32;
    let bpp = (BMP[28] as u16) | ((BMP[29] as u16) << 8);
    if bpp != 32 { return 3; }
    if w as usize != W { return 4; }
    if h.unsigned_abs() as usize != H { return 5; }

    let top_down = h < 0;
    let abs_h = h.unsigned_abs() as usize;
    let pixels_len = abs_h * (w as usize) * 4;
    if pixel_off + pixels_len > BMP.len() { return 6; }

    // 3. Walk pixels.
    //
    // Source: 32bpp BGRA, row stride = w*4 (already 4-aligned at
    // 32bpp, no padding needed). Bottom-up: source row 0 = bottom of
    // image. Top-down: source row 0 = top.
    //
    // Per-pixel transform: read u32 (BGRA little-endian = bytes B,G,R,A
    // in memory), swap to RGBA = bytes R,G,B,A. As a u32 endian-swap
    // it's:
    //   rgba = (bgra & 0xFF00FF00)       (G,A untouched)
    //        | ((bgra & 0x00FF0000) >> 16)  (R into byte 0)
    //        | ((bgra & 0x000000FF) << 16); (B into byte 2)
    let mut y = 0usize;
    while y < H {
        let src_y = if top_down { y } else { H - 1 - y };
        let src_row = pixel_off + src_y * W * 4;
        let dst_row = y * W * 4;
        let mut x = 0usize;
        while x < W {
            unsafe {
                let src = (BMP.as_ptr()).add(src_row + x * 4) as *const u32;
                let bgra = core::ptr::read_unaligned(src);
                let rgba = (bgra & 0xFF00FF00)
                    | ((bgra & 0x00FF0000) >> 16)
                    | ((bgra & 0x000000FF) << 16);
                let dst = ((&raw mut OUT) as *mut u8).add(dst_row + x * 4) as *mut u32;
                core::ptr::write_unaligned(dst, rgba);
            }
            x += 1;
        }
        y += 1;
    }

    // 4. XOR of corner pixels' R channel. With the gradient fixture
    //    R = x*4 & 0xff, expected is (W-1)*4 & 0xff. For W=320 → 1276
    //    & 0xff = 0xfc (252).
    let out = (&raw const OUT) as *const u8;
    let r00 = unsafe { *out.add(0) } as u32;
    let g00 = unsafe { *out.add(1) } as u32;
    let b00 = unsafe { *out.add(2) } as u32;
    let last_r = unsafe { *out.add((H - 1) * W * 4 + (W - 1) * 4) } as u32;
    ((r00 ^ g00 ^ b00 ^ last_r) & 0xff) as i32
}
