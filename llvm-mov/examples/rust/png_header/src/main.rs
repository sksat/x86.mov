//! Tiny PNG-header parser. Pure no_std, no_alloc, no byte-by-byte
//! reads — everything is `read_unaligned::<u32>` so the generated IR
//! is `load i32, align 1` + bitshift/mask only. With stage 6d3a
//! (`allowsMisalignedMemoryAccesses` returning true) these compile
//! through llvm-mov-llc as plain MOV32rm + AND32ri / SHR32ri.
//!
//! Layout we care about:
//!   * 8-byte PNG signature: `89 50 4e 47  0d 0a 1a 0a`
//!   * IHDR chunk: 4-byte length (=13), 4-byte type ("IHDR"),
//!     13-byte payload (width u32 BE, height u32 BE, depth u8,
//!     colour-type u8, compression u8, filter u8, interlace u8),
//!     4-byte CRC.
//!
//! `png_header_main` returns the parsed IHDR width modulo 256 if the
//! signature / IHDR-type match the spec, otherwise 0. The fixture
//! is a 8x8 image so the expected exit code is 8.

#![no_std]
#![no_main]

#[panic_handler]
fn panic(_: &core::panic::PanicInfo) -> ! { loop {} }

use core::ptr;

// Hand-built 33-byte prefix of a real 8x8 grayscale PNG file:
// signature (8) + IHDR length+type (8) + IHDR data (13) + CRC (4).
// Byte values are the spec — width=8, height=8, depth=8, colour=0
// (grayscale), compression=0, filter=0, interlace=0.
#[unsafe(no_mangle)]
pub static PNG_FIXTURE: [u8; 33] = [
    // PNG signature
    0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
    // IHDR length (13 BE) + chunk type "IHDR"
    0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
    // Width (8 BE), height (8 BE)
    0x00, 0x00, 0x00, 0x08, 0x00, 0x00, 0x00, 0x08,
    // depth, colour-type, compression, filter, interlace
    0x08, 0x00, 0x00, 0x00, 0x00,
    // CRC (placeholder)
    0xa1, 0xa3, 0x40, 0x67,
];

#[inline(always)]
fn read_u32_le(p: *const u8, off: usize) -> u32 {
    unsafe { ptr::read_unaligned(p.add(off) as *const u32) }
}

#[inline(always)]
fn bswap32(x: u32) -> u32 {
    // Manual byte-swap. `u32::swap_bytes` works too but lowers to the
    // same shift/or chain at -O0; spell it out so the IR stays
    // predictable for the bench reader.
    let a = (x >> 24) & 0xff;
    let b = (x >> 8)  & 0xff_00;
    let c = (x << 8)  & 0xff_0000;
    let d = (x << 24) & 0xff_00_0000;
    a | b | c | d
}

#[unsafe(no_mangle)]
pub extern "C" fn png_header_main() -> i32 {
    let p = (&raw const PNG_FIXTURE) as *const u8;

    // Word 0/1 of the signature, compared as little-endian native.
    let sig0 = read_u32_le(p, 0);   // 47 4e 50 89  (LE)
    let sig1 = read_u32_le(p, 4);   // 0a 1a 0a 0d  (LE)
    if sig0 != 0x474e5089 || sig1 != 0x0a1a0a0d {
        return 0;
    }

    // IHDR chunk type, offset 12. "IHDR" as LE u32 = 0x52444849.
    let chunk_type = read_u32_le(p, 12);
    if chunk_type != 0x52444849 {
        return 0;
    }

    // Width is at offset 16, big-endian. Read as LE u32 then byteswap.
    let width_be_raw = read_u32_le(p, 16);
    let width = bswap32(width_be_raw);

    (width & 0xff) as i32
}
