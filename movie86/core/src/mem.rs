//! Guest physical/virtual memory abstraction.
//!
//! Everything in the emulator that touches guest memory goes through the
//! [`Memory`] trait so the loader, the CPU, and (eventually) syscalls can
//! share one access model. The first concrete implementation is
//! [`FlatMemory`]: a single contiguous region. Multi-region / paged
//! variants can replace it later without changing the rest of the core.

use alloc::vec;
use alloc::vec::Vec;

use crate::Fault;

/// 32-bit little-endian guest memory.
pub trait Memory {
    fn read_u8(&self, addr: u32) -> Result<u8, Fault>;
    fn read_u16(&self, addr: u32) -> Result<u16, Fault>;
    fn read_u32(&self, addr: u32) -> Result<u32, Fault>;
    fn write_u8(&mut self, addr: u32, val: u8) -> Result<(), Fault>;
    fn write_u16(&mut self, addr: u32, val: u16) -> Result<(), Fault>;
    fn write_u32(&mut self, addr: u32, val: u32) -> Result<(), Fault>;

    /// Bulk read into `dst`. Returns the fault of the first unmapped byte
    /// rather than performing a partial read.
    fn read_bytes(&self, addr: u32, dst: &mut [u8]) -> Result<(), Fault>;

    /// Bulk write. Used by the ELF loader for `PT_LOAD` segments.
    fn write_bytes(&mut self, addr: u32, src: &[u8]) -> Result<(), Fault>;
}

/// A single contiguous region of guest memory mapped at `base`.
#[derive(Debug, Clone)]
pub struct FlatMemory {
    base: u32,
    bytes: Vec<u8>,
}

impl FlatMemory {
    /// Allocate `size` zero bytes mapped at `base`.
    #[must_use]
    pub fn new_zeroed(base: u32, size: usize) -> Self {
        Self {
            base,
            bytes: vec![0u8; size],
        }
    }

    #[must_use]
    pub fn base(&self) -> u32 {
        self.base
    }

    #[must_use]
    pub fn len(&self) -> usize {
        self.bytes.len()
    }

    #[must_use]
    pub fn is_empty(&self) -> bool {
        self.bytes.is_empty()
    }

    /// Translate a guest address + access length into a slice offset, or
    /// fault if the access falls outside the mapped region (including
    /// overflow of `addr + len`).
    fn offset(&self, addr: u32, len: usize) -> Result<usize, Fault> {
        if addr < self.base {
            return Err(Fault::Unmapped(addr));
        }
        let off = (addr - self.base) as usize;
        let end = off.checked_add(len).ok_or(Fault::Unmapped(addr))?;
        if end > self.bytes.len() {
            return Err(Fault::Unmapped(addr));
        }
        Ok(off)
    }
}

impl Memory for FlatMemory {
    fn read_u8(&self, addr: u32) -> Result<u8, Fault> {
        let off = self.offset(addr, 1)?;
        Ok(self.bytes[off])
    }

    fn read_u16(&self, addr: u32) -> Result<u16, Fault> {
        let off = self.offset(addr, 2)?;
        let b = &self.bytes[off..off + 2];
        Ok(u16::from_le_bytes([b[0], b[1]]))
    }

    fn read_u32(&self, addr: u32) -> Result<u32, Fault> {
        let off = self.offset(addr, 4)?;
        let b = &self.bytes[off..off + 4];
        Ok(u32::from_le_bytes([b[0], b[1], b[2], b[3]]))
    }

    fn write_u8(&mut self, addr: u32, val: u8) -> Result<(), Fault> {
        let off = self.offset(addr, 1)?;
        self.bytes[off] = val;
        Ok(())
    }

    fn write_u16(&mut self, addr: u32, val: u16) -> Result<(), Fault> {
        let off = self.offset(addr, 2)?;
        self.bytes[off..off + 2].copy_from_slice(&val.to_le_bytes());
        Ok(())
    }

    fn write_u32(&mut self, addr: u32, val: u32) -> Result<(), Fault> {
        let off = self.offset(addr, 4)?;
        self.bytes[off..off + 4].copy_from_slice(&val.to_le_bytes());
        Ok(())
    }

    fn read_bytes(&self, addr: u32, dst: &mut [u8]) -> Result<(), Fault> {
        let off = self.offset(addr, dst.len())?;
        dst.copy_from_slice(&self.bytes[off..off + dst.len()]);
        Ok(())
    }

    fn write_bytes(&mut self, addr: u32, src: &[u8]) -> Result<(), Fault> {
        let off = self.offset(addr, src.len())?;
        self.bytes[off..off + src.len()].copy_from_slice(src);
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn read_write_u8() {
        let mut m = FlatMemory::new_zeroed(0x1000, 16);
        m.write_u8(0x1000, 0xab).unwrap();
        m.write_u8(0x100f, 0xcd).unwrap();
        assert_eq!(m.read_u8(0x1000).unwrap(), 0xab);
        assert_eq!(m.read_u8(0x100f).unwrap(), 0xcd);
    }

    #[test]
    fn u16_is_little_endian() {
        let mut m = FlatMemory::new_zeroed(0, 4);
        m.write_u16(0, 0x1234).unwrap();
        assert_eq!(m.read_u8(0).unwrap(), 0x34);
        assert_eq!(m.read_u8(1).unwrap(), 0x12);
        assert_eq!(m.read_u16(0).unwrap(), 0x1234);
    }

    #[test]
    fn u32_is_little_endian() {
        let mut m = FlatMemory::new_zeroed(0, 4);
        m.write_u32(0, 0xdead_beef).unwrap();
        assert_eq!(m.read_u8(0).unwrap(), 0xef);
        assert_eq!(m.read_u8(3).unwrap(), 0xde);
        assert_eq!(m.read_u32(0).unwrap(), 0xdead_beef);
    }

    #[test]
    fn below_base_is_unmapped() {
        let m = FlatMemory::new_zeroed(0x1000, 16);
        assert_eq!(m.read_u8(0x0fff).unwrap_err(), Fault::Unmapped(0x0fff));
    }

    #[test]
    fn past_end_is_unmapped() {
        let m = FlatMemory::new_zeroed(0x1000, 16);
        // Region covers 0x1000..0x1010. A u32 starting at 0x100d would
        // need bytes 0x100d..0x1011.
        assert_eq!(m.read_u32(0x100d).unwrap_err(), Fault::Unmapped(0x100d));
    }

    #[test]
    fn address_length_overflow_is_unmapped() {
        // Region covers the very top of the address space; a u32 starting
        // two bytes from the end must fault rather than wrap.
        let m = FlatMemory::new_zeroed(0xffff_fff0, 16);
        assert_eq!(
            m.read_u32(0xffff_fffe).unwrap_err(),
            Fault::Unmapped(0xffff_fffe)
        );
    }

    #[test]
    fn bulk_roundtrip() {
        let mut m = FlatMemory::new_zeroed(0x2000, 8);
        m.write_bytes(0x2000, &[1, 2, 3, 4, 5, 6, 7, 8]).unwrap();
        let mut buf = [0u8; 8];
        m.read_bytes(0x2000, &mut buf).unwrap();
        assert_eq!(buf, [1, 2, 3, 4, 5, 6, 7, 8]);
    }

    #[test]
    fn bulk_write_past_end_is_unmapped() {
        let mut m = FlatMemory::new_zeroed(0x3000, 4);
        assert!(m.write_bytes(0x3002, &[1, 2, 3]).is_err());
    }
}
