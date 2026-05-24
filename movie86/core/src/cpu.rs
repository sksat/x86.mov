//! Architectural CPU state and the fetch / decode / execute loop.
//!
//! `step()` does one instruction at a time: it fetches bytes via the
//! [`Memory`] trait, hands them to [`decode`], advances `eip`, and dispatches
//! to a per-instruction executor. Decoding stays in `decode.rs` so the same
//! decoder remains usable by tracing / disassembly callers.

use crate::decode::decode;
use crate::insn::{EffectiveAddress, Insn, Operand, Reg32};
use crate::{Fault, Memory};

/// Maximum length of any x86 instruction. Fetches read up to this many
/// bytes per step.
const MAX_INSN_LEN: usize = 15;

/// Architectural state of the guest CPU.
#[derive(Debug, Clone)]
pub struct Cpu {
    /// General-purpose registers, indexed by [`Reg32`] as `usize`.
    pub regs: [u32; 8],
    pub eip: u32,
}

impl Cpu {
    /// Construct a CPU with `entry` as the initial `eip` and all GPRs zeroed.
    #[must_use]
    pub fn new(entry: u32) -> Self {
        Self {
            regs: [0; 8],
            eip: entry,
        }
    }

    #[must_use]
    pub fn reg(&self, r: Reg32) -> u32 {
        self.regs[r as usize]
    }

    pub fn set_reg(&mut self, r: Reg32, v: u32) {
        self.regs[r as usize] = v;
    }

    /// Fetch one instruction at `eip`, decode and execute it, and advance
    /// `eip` by the instruction's encoded length.
    pub fn step<M: Memory>(&mut self, mem: &mut M) -> Result<(), Fault> {
        let mut buf = [0u8; MAX_INSN_LEN];
        let n = fetch(mem, self.eip, &mut buf)?;
        let (insn, len) = decode(&buf[..n])?;
        self.execute(insn, mem)?;
        self.eip = self.eip.wrapping_add(u32::from(len));
        Ok(())
    }

    fn execute<M: Memory>(&mut self, insn: Insn, mem: &mut M) -> Result<(), Fault> {
        match insn {
            Insn::Mov { dst, src } => self.exec_mov(dst, src, mem),
        }
    }

    /// Execute a `mov dst, src`. The decoder guarantees `dst` and `src`
    /// have matching widths.
    fn exec_mov<M: Memory>(
        &mut self,
        dst: Operand,
        src: Operand,
        mem: &mut M,
    ) -> Result<(), Fault> {
        let val = self.read_operand_u32(src, mem)?;
        self.write_operand_u32(dst, val, mem)
    }

    /// Read a 32-bit-wide source operand. Unsupported widths trap.
    fn read_operand_u32<M: Memory>(&self, op: Operand, mem: &M) -> Result<u32, Fault> {
        match op {
            Operand::Reg32(r) => Ok(self.reg(r)),
            Operand::Imm32(v) => Ok(v),
            Operand::Mem32(ea) => mem.read_u32(self.compute_ea(ea)),
            _ => Err(Fault::UnimplementedMov),
        }
    }

    /// Write to a 32-bit-wide destination operand. Unsupported widths trap.
    fn write_operand_u32<M: Memory>(
        &mut self,
        op: Operand,
        val: u32,
        mem: &mut M,
    ) -> Result<(), Fault> {
        match op {
            Operand::Reg32(r) => {
                self.set_reg(r, val);
                Ok(())
            }
            Operand::Mem32(ea) => mem.write_u32(self.compute_ea(ea), val),
            _ => Err(Fault::UnimplementedMov),
        }
    }

    /// `base + index * scale + disp`, all modular over u32. `disp` is
    /// reinterpreted as the matching bit pattern so a negative displacement
    /// performs the right wrap.
    fn compute_ea(&self, ea: EffectiveAddress) -> u32 {
        let base = ea.base.map_or(0, |r| self.reg(r));
        let index = ea.index.map_or(0, |r| self.reg(r));
        // Reinterpret the signed displacement as the matching u32 bit
        // pattern so a negative disp wraps the address correctly.
        let disp_bits = u32::from_ne_bytes(ea.disp.to_ne_bytes());
        base.wrapping_add(index.wrapping_mul(u32::from(ea.scale)))
            .wrapping_add(disp_bits)
    }
}

/// Greedy fetch: copy up to `buf.len()` bytes starting at `addr`, stopping
/// at the first byte that faults. Used so an instruction near the end of a
/// mapped region still decodes if enough bytes are available.
///
/// Returns the original fault if even the **first** byte is unmapped —
/// otherwise an unmapped `eip` would degenerate into `DecodeTruncated`
/// and hide a bad-PC bug.
fn fetch<M: Memory>(mem: &M, addr: u32, buf: &mut [u8]) -> Result<usize, Fault> {
    for (i, slot) in buf.iter_mut().enumerate() {
        // MAX_INSN_LEN is 15 so `i` always fits in u32.
        let off = u32::try_from(i).unwrap_or(u32::MAX);
        match mem.read_u8(addr.wrapping_add(off)) {
            Ok(b) => *slot = b,
            Err(e) if i == 0 => return Err(e),
            Err(_) => return Ok(i),
        }
    }
    Ok(buf.len())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::FlatMemory;
    use proptest::prelude::*;

    /// Build a memory region and encode `mov r32, imm32` at its base.
    fn make_mov_r32_imm32(reg_idx: u8, imm: u32, base: u32) -> FlatMemory {
        let mut mem = FlatMemory::new_zeroed(base, 16);
        mem.write_u8(base, 0xB8 + reg_idx).unwrap();
        mem.write_u32(base + 1, imm).unwrap();
        mem
    }

    /// Place `bytes` at `base` in a freshly-zeroed region of `size` bytes.
    fn region_with_program(base: u32, size: usize, bytes: &[u8]) -> FlatMemory {
        let mut mem = FlatMemory::new_zeroed(base, size);
        mem.write_bytes(base, bytes).unwrap();
        mem
    }

    #[test]
    fn step_mov_eax_42() {
        let mut mem = make_mov_r32_imm32(0, 42, 0x1000);
        let mut cpu = Cpu::new(0x1000);
        cpu.step(&mut mem).unwrap();
        assert_eq!(cpu.reg(Reg32::Eax), 42);
        assert_eq!(cpu.eip, 0x1005);
    }

    #[test]
    fn step_reports_decode_fault() {
        let mut mem = FlatMemory::new_zeroed(0x1000, 16);
        mem.write_u8(0x1000, 0x00).unwrap(); // unknown opcode
        let mut cpu = Cpu::new(0x1000);
        assert_eq!(cpu.step(&mut mem).unwrap_err(), Fault::UnknownOpcode(0x00));
    }

    #[test]
    fn step_mov_r32_r32_copies_value() {
        // 8b c1 → mov eax, ecx ; reg=000 r/m=001 mod=11
        let mut mem = region_with_program(0x1000, 16, &[0x8b, 0xc1]);
        let mut cpu = Cpu::new(0x1000);
        cpu.set_reg(Reg32::Ecx, 0xdead_beef);
        cpu.step(&mut mem).unwrap();
        assert_eq!(cpu.reg(Reg32::Eax), 0xdead_beef);
        assert_eq!(cpu.reg(Reg32::Ecx), 0xdead_beef, "src should be unchanged");
        assert_eq!(cpu.eip, 0x1002);
    }

    #[test]
    fn step_mov_r32_disp32_reads_memory() {
        // 8b 0d 00 20 00 00 → mov ecx, ds:0x2000  (reg=001, mod=00, r/m=101)
        // Two regions: code at 0x1000, data at 0x2000.
        // FlatMemory is single-region, so use one big region covering both.
        let mut mem = FlatMemory::new_zeroed(0x1000, 0x2000); // covers 0x1000..0x3000
        mem.write_bytes(0x1000, &[0x8b, 0x0d, 0x00, 0x20, 0x00, 0x00])
            .unwrap();
        mem.write_u32(0x2000, 0xcafe_d00d).unwrap();
        let mut cpu = Cpu::new(0x1000);
        cpu.step(&mut mem).unwrap();
        assert_eq!(cpu.reg(Reg32::Ecx), 0xcafe_d00d);
        assert_eq!(cpu.eip, 0x1006);
    }

    #[test]
    fn step_mov_disp32_r32_writes_memory() {
        // 89 05 00 20 00 00 → mov ds:0x2000, eax  (reg=000)
        let mut mem = FlatMemory::new_zeroed(0x1000, 0x2000);
        mem.write_bytes(0x1000, &[0x89, 0x05, 0x00, 0x20, 0x00, 0x00])
            .unwrap();
        let mut cpu = Cpu::new(0x1000);
        cpu.set_reg(Reg32::Eax, 0x1234_5678);
        cpu.step(&mut mem).unwrap();
        assert_eq!(mem.read_u32(0x2000).unwrap(), 0x1234_5678);
        assert_eq!(cpu.eip, 0x1006);
    }

    #[test]
    fn step_mov_r32_base_plus_disp8_handles_negative_disp() {
        // 8b 41 ff → mov eax, [ecx - 1]  (reg=000, mod=01, r/m=001, disp8=0xff)
        let mut mem = FlatMemory::new_zeroed(0x1000, 0x2000);
        mem.write_bytes(0x1000, &[0x8b, 0x41, 0xff]).unwrap();
        mem.write_u32(0x2000, 0xabcd_ef01).unwrap();
        let mut cpu = Cpu::new(0x1000);
        cpu.set_reg(Reg32::Ecx, 0x2001); // so [ecx - 1] = 0x2000
        cpu.step(&mut mem).unwrap();
        assert_eq!(cpu.reg(Reg32::Eax), 0xabcd_ef01);
    }

    #[test]
    fn step_mov_via_sib_table_lookup() {
        // 8b 0c 85 00 20 00 00 → mov ecx, [eax*4 + 0x2000]
        // Mimics the table-dispatch pattern movfuscator emits everywhere.
        let mut mem = FlatMemory::new_zeroed(0x1000, 0x2000);
        mem.write_bytes(0x1000, &[0x8b, 0x0c, 0x85, 0x00, 0x20, 0x00, 0x00])
            .unwrap();
        // Table[3] = 0xfeedface at 0x2000 + 3*4 = 0x200c
        mem.write_u32(0x200c, 0xfeed_face).unwrap();
        let mut cpu = Cpu::new(0x1000);
        cpu.set_reg(Reg32::Eax, 3);
        cpu.step(&mut mem).unwrap();
        assert_eq!(cpu.reg(Reg32::Ecx), 0xfeed_face);
        assert_eq!(cpu.eip, 0x1007);
    }

    #[test]
    fn step_with_unmapped_eip_reports_unmapped_not_truncated() {
        // Region at 0x1000, but eip points at 0x2000 — fetch can't even
        // read byte 0. We must see Unmapped(0x2000), not DecodeTruncated.
        let mut mem = FlatMemory::new_zeroed(0x1000, 16);
        let mut cpu = Cpu::new(0x2000);
        assert_eq!(cpu.step(&mut mem).unwrap_err(), Fault::Unmapped(0x2000));
    }

    #[test]
    fn step_mov_r32_to_unmapped_memory_faults() {
        // mov [0x9000], eax — 0x9000 is outside our region
        let mut mem = FlatMemory::new_zeroed(0x1000, 0x100);
        mem.write_bytes(0x1000, &[0x89, 0x05, 0x00, 0x90, 0x00, 0x00])
            .unwrap();
        let mut cpu = Cpu::new(0x1000);
        cpu.set_reg(Reg32::Eax, 42);
        assert_eq!(cpu.step(&mut mem).unwrap_err(), Fault::Unmapped(0x9000));
    }

    proptest! {
        /// For every encoding of `mov r32, imm32`:
        /// - the named register receives `imm`,
        /// - every other register is unchanged from its initial value,
        /// - `eip` advances by exactly 5.
        #[test]
        fn pbt_mov_r32_imm32_writes_dst_leaves_others(
            reg_idx in 0u8..8,
            imm: u32,
        ) {
            let base = 0x1000u32;
            let mut mem = make_mov_r32_imm32(reg_idx, imm, base);
            let mut cpu = Cpu::new(base);
            // Seed each register with a distinguishable sentinel so an
            // overwrite of the wrong slot is detectable.
            for i in 0u32..8 {
                cpu.regs[i as usize] = 0xDEAD_0000 + i;
            }
            let initial = cpu.regs;
            cpu.step(&mut mem).unwrap();
            let dst = Reg32::from_index(reg_idx);
            prop_assert_eq!(cpu.reg(dst), imm);
            for i in 0..8u8 {
                if i != reg_idx {
                    prop_assert_eq!(
                        cpu.regs[i as usize],
                        initial[i as usize],
                        "register {} clobbered", i,
                    );
                }
            }
            prop_assert_eq!(cpu.eip, base + 5);
        }

        /// For every (dst, src) pair: 8B with mod=11 copies src→dst and
        /// leaves every other register at its initial sentinel.
        #[test]
        fn pbt_mov_r32_r32_copies_src_to_dst(
            dst_idx in 0u8..8,
            src_idx in 0u8..8,
        ) {
            let base = 0x1000u32;
            // ModR/M = mod(11) reg(dst_idx) r/m(src_idx)
            let modrm = 0xC0 | (dst_idx << 3) | src_idx;
            let mut mem = region_with_program(base, 16, &[0x8b, modrm]);
            let mut cpu = Cpu::new(base);
            for i in 0u32..8 {
                cpu.regs[i as usize] = 0xBEEF_0000 + i;
            }
            let initial = cpu.regs;
            cpu.step(&mut mem).unwrap();
            let dst = Reg32::from_index(dst_idx);
            let src = Reg32::from_index(src_idx);
            // src always still holds its initial value (no write happened
            // to src itself, and even when dst == src that's identity).
            prop_assert_eq!(cpu.reg(dst), initial[src as usize]);
            // All other registers untouched.
            for i in 0u8..8 {
                if i != dst_idx {
                    prop_assert_eq!(cpu.regs[i as usize], initial[i as usize]);
                }
            }
            prop_assert_eq!(cpu.eip, base + 2);
        }
    }
}
