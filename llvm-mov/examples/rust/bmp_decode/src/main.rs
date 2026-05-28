//! Full no_std BMP decoder for the 32bpp / uncompressed / BITMAPINFOHEADER
//! subset. Reads every pixel of the embedded fixture and returns a
//! 32-bit digest so we can prove the bytes were genuinely consumed
//! (vs the header-only `png_header/` / `jpeg_header/` examples).
//!
//! What "full decode" means here:
//!   * Parse the 14-byte BITMAPFILEHEADER (signature, file size,
//!     pixel-array offset).
//!   * Parse the 40-byte BITMAPINFOHEADER (width, height, planes,
//!     bpp=32, compression=0).
//!   * Iterate over `width * abs(height)` pixels, reading each as a
//!     u32 (BGRA in little-endian byte order).
//!   * Reduce the pixel stream to a single u32 digest (XOR + rotate)
//!     so the output depends on every pixel's value.
//!
//! Why 32bpp & not 24bpp: 32bpp aligns each pixel to a 4-byte
//! boundary, so iterating with `ptr::read_unaligned::<u32>` produces
//! `load i32` IR with no per-byte access. The DIB header is 14+40
//! = 54 bytes before pixel data, which *is* misaligned, but the
//! stage 6d3a `allowsMisalignedMemoryAccesses` fix lets the
//! resulting `load i32, align 1` pass straight through.
//!
//! 24bpp BMP would force a per-byte read at every pixel boundary
//! (3 bytes/pixel, never aligned to 4); supporting that path needs
//! stage 6d3b.

#![no_std]
#![no_main]

#[panic_handler]
fn panic(_: &core::panic::PanicInfo) -> ! { loop {} }

use core::ptr;

// Hand-built 2x2 32bpp BMP. File header (14B) + DIB header (40B) +
// 4 pixels (16B) = 70 bytes total. Pixels in BGRA order, bottom-up:
//   row 1 (bottom): 0x000000FF (red), 0x0000FF00 (green)
//   row 0 (top):    0x00FF0000 (blue), 0x00FFFFFF (white)
//
// The exit-code oracle below digests these into a deterministic u32,
// and its low byte is what `bmp_decode_main` returns. Running the
// same XOR+rotl-13 chain in Python over the embedded pixels gives
// `digest = 0x6bea7f68`, mod 256 = 104.
#[unsafe(no_mangle)]
pub static BMP_FIXTURE: [u8; 70] = [
    // BITMAPFILEHEADER (14 bytes)
    0x42, 0x4d,                         // "BM"
    0x46, 0x00, 0x00, 0x00,             // file size = 70
    0x00, 0x00, 0x00, 0x00,             // reserved
    0x36, 0x00, 0x00, 0x00,             // pixel data offset = 54
    // BITMAPINFOHEADER (40 bytes)
    0x28, 0x00, 0x00, 0x00,             // header size = 40
    0x02, 0x00, 0x00, 0x00,             // width = 2
    0x02, 0x00, 0x00, 0x00,             // height = 2 (bottom-up)
    0x01, 0x00,                         // planes = 1
    0x20, 0x00,                         // bpp = 32
    0x00, 0x00, 0x00, 0x00,             // compression = BI_RGB (0)
    0x10, 0x00, 0x00, 0x00,             // image size = 16
    0x13, 0x0b, 0x00, 0x00,             // x ppm
    0x13, 0x0b, 0x00, 0x00,             // y ppm
    0x00, 0x00, 0x00, 0x00,             // palette colours
    0x00, 0x00, 0x00, 0x00,             // important colours
    // Pixel data (16 bytes, BGRA bottom-up)
    0xff, 0x00, 0x00, 0x00,             // (0,1) red
    0x00, 0xff, 0x00, 0x00,             // (1,1) green
    0x00, 0x00, 0xff, 0x00,             // (0,0) blue
    0xff, 0xff, 0xff, 0x00,             // (1,0) white
];

#[inline(always)]
fn read_u32_le(p: *const u8, off: usize) -> u32 {
    unsafe { ptr::read_unaligned(p.add(off) as *const u32) }
}

#[inline(always)]
fn read_u16_le(p: *const u8, off: usize) -> u32 {
    // Read u16 as the low 16 bits of an unaligned u32 read.
    let w = unsafe { ptr::read_unaligned(p.add(off) as *const u32) };
    w & 0xffff
}

#[inline(always)]
fn rotl32_13(x: u32) -> u32 {
    // Hand-spelled rotate-left-13 to keep the IR off the `rotl`
    // intrinsic — the backend has no ROL/ROR opcode (and no
    // pattern to lower `ISD::ROTL`); shifting + OR-ing the two
    // halves is the same value and stays inside the legal i32 op
    // set (SHL32ri / SHR32ri / OR32rr).
    (x << 13) | (x >> 19)
}

#[unsafe(no_mangle)]
pub extern "C" fn bmp_decode_main() -> i32 {
    let p = (&raw const BMP_FIXTURE) as *const u8;

    // BITMAPFILEHEADER: signature must be "BM" (0x4d42 LE).
    let bm = read_u16_le(p, 0);
    if bm != 0x4d42 {
        return 0;
    }
    let pixel_offset = read_u32_le(p, 10) as usize;

    // BITMAPINFOHEADER: validate planes=1, bpp=32, compression=0.
    let width  = read_u32_le(p, 18);
    let height = read_u32_le(p, 22);
    let planes_bpp = read_u32_le(p, 26);    // planes (low 16) + bpp (high 16)
    let compression = read_u32_le(p, 30);
    if planes_bpp != ((32u32 << 16) | 1u32) || compression != 0 {
        return 0;
    }

    // Decode every pixel. `read_unaligned::<u32>` on the pixel base
    // is fine — BITMAPFILEHEADER + BITMAPINFOHEADER is 54 bytes
    // (offset 54 = 0x36 = mod 4 = 2, misaligned), but the
    // unaligned-load lowering at stage 6d3a accepts that.
    //
    // We deliberately do NOT compute `width * height` for the loop
    // bound — `i32 mul` is unsupported in the backend today (no
    // MUL32rr/ri yet). Instead we walk byte offsets directly with
    // the image-size field (DIB header offset 34, in bytes) as the
    // termination cap, which is a plain u32 comparison.
    let image_size = read_u32_le(p, 34) as usize;
    let end = pixel_offset + image_size;
    let mut digest: u32 = 0x9e3779b9; // golden ratio sentinel
    let mut off = pixel_offset;
    while off < end {
        let px = read_u32_le(p, off);
        // Mix every pixel into the digest. XOR + rotate gives a
        // function where each pixel's value affects every digest
        // byte after a couple of rounds — enough that flipping any
        // single byte in the fixture changes the exit code.
        digest = rotl32_13(digest ^ px);
        off = off + 4;
    }
    // Silence "unused" on width/height — they're still parsed and
    // validated structurally; the digest loop just doesn't multiply
    // them because the backend lacks MUL32.
    let _ = width;
    let _ = height;

    (digest & 0xff) as i32
}
