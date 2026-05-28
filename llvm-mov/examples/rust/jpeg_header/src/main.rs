//! Tiny JPEG header parser, no_std/no_alloc. Same shape as
//! `png_header/`: read 32-bit words via `ptr::read_unaligned::<u32>`,
//! extract bytes via shift/mask. The whole point is that the
//! resulting IR stays in i32-land — no individual `load i8` ops —
//! so it round-trips through llvm-mov-llc once stage 6d3a's
//! `allowsMisalignedMemoryAccesses` lets unaligned 32-bit loads
//! survive.
//!
//! JPEG layout we look at:
//!   * 2-byte SOI marker `FF D8`
//!   * marker stream: each marker is `FF xx`; length-bearing markers
//!     are followed by 2-byte big-endian length (incl. the length
//!     itself), then the payload.
//!   * SOF0 (Start Of Frame, baseline) is `FF C0`; payload begins
//!     with `precision (1B) height (2B BE) width (2B BE) ...`.
//!
//! `jpeg_header_main` walks the marker chain, finds SOF0, and
//! returns the height & 0xff. The embedded fixture is a 16-tall
//! image, so expected exit code is 16.

#![no_std]
#![no_main]

#[panic_handler]
fn panic(_: &core::panic::PanicInfo) -> ! { loop {} }

use core::ptr;

// Hand-built JPEG prefix: SOI + JFIF APP0 (18 bytes) + SOF0 (17 bytes).
// Just enough that the parser can find the SOF0 marker and read the
// frame dimensions. Image is 24 wide × 16 tall (arbitrary).
//
// SOI:  ff d8
// APP0: ff e0  00 10  4a 46 49 46 00  01 01 00  00 01 00 01  00 00
//       (marker, length=16, "JFIF\0", version, density, x/y, thumbnail)
// SOF0: ff c0  00 11  08  00 10  00 18  03  01 22 00  02 11 01  03 11 01
//       (marker, length=17, precision=8, height=16, width=24,
//        components=3, then 3 × (id, sampling, qtbl))
#[unsafe(no_mangle)]
pub static JPEG_FIXTURE: [u8; 39] = [
    0xff, 0xd8,
    0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00,
    0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00,
    0xff, 0xc0, 0x00, 0x11, 0x08, 0x00, 0x10, 0x00, 0x18,
    0x03, 0x01, 0x22, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01,
];

#[inline(always)]
fn read_u32_le(p: *const u8, off: usize) -> u32 {
    unsafe { ptr::read_unaligned(p.add(off) as *const u32) }
}

#[inline(always)]
fn byte_at(w: u32, lane: u32) -> u32 {
    (w >> (lane * 8)) & 0xff
}

#[unsafe(no_mangle)]
pub extern "C" fn jpeg_header_main() -> i32 {
    let p = (&raw const JPEG_FIXTURE) as *const u8;

    // Word 0 contains bytes [0..4] (little-endian native).
    // Bytes 0/1 should be ff d8 (SOI).
    let w0 = read_u32_le(p, 0);
    if byte_at(w0, 0) != 0xff || byte_at(w0, 1) != 0xd8 {
        return 0;
    }

    // Walk markers. Each marker is ff <code>; if `code` is
    // 0xC0..=0xFE (excluding standalone markers like 0xD8/0xD9)
    // it carries a 2-byte BE length follow.
    //
    // The fixture's layout makes this a one-iteration walk — APP0 at
    // offset 2 (length 16 → next at 2+2+16 = 20), then SOF0 at 20.
    let mut off: usize = 2;
    // Cap the loop so a malformed input can't run forever; 16 markers
    // is plenty for SOF0 to appear in a real header. The bound here
    // doubles as the loop's upper iteration count for the byte-chain
    // legalize cost estimate.
    let mut iter: u32 = 0;
    while iter < 16 {
        // Read the marker (4 bytes starting at off): ff, code, len_hi, len_lo
        let mw = read_u32_le(p, off);
        let marker_ff = byte_at(mw, 0);
        let code      = byte_at(mw, 1);
        if marker_ff != 0xff {
            return 0;
        }
        if code == 0xc0 {
            // SOF0 found. Length is at off+2..off+4 (BE); height at
            // off+5..off+7 (BE). The whole 8-byte block fits in two
            // u32 reads starting at off and off+4.
            let payload_w = read_u32_le(p, off + 4);
            // payload bytes in payload_w (LE-ordered native):
            //   lane 0 = precision
            //   lane 1 = height hi
            //   lane 2 = height lo
            //   lane 3 = width hi
            let height_hi = byte_at(payload_w, 1);
            let height_lo = byte_at(payload_w, 2);
            let height = (height_hi << 8) | height_lo;
            return (height & 0xff) as i32;
        }
        // Length-bearing marker (everything in C0..=FE except the
        // standalone 0xD0..=0xD9 set). Read 2-byte BE length at off+2.
        let lw = mw >> 16;            // top half of mw = bytes [off+2, off+3]
        let len_be_hi = lw & 0xff;
        let len_be_lo = (lw >> 8) & 0xff;
        let len = (len_be_hi << 8) | len_be_lo;
        off = off + 2 + len as usize;
        iter = iter + 1;
    }
    0
}
