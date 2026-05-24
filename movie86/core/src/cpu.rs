//! Architectural CPU state and the fetch / decode / execute loop.
//!
//! `step()` does one instruction at a time: it fetches bytes via the
//! [`Memory`] trait, hands them to [`decode`], advances `eip`, and dispatches
//! to a per-instruction executor. Decoding stays in `decode.rs` so the same
//! decoder remains usable by tracing / disassembly callers.

use crate::decode::decode;
use crate::insn::{Insn, Operand, Reg32};
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
        let n = fetch(mem, self.eip, &mut buf);
        let (insn, len) = decode(&buf[..n])?;
        self.execute(insn, mem)?;
        self.eip = self.eip.wrapping_add(u32::from(len));
        Ok(())
    }

    fn execute<M: Memory>(&mut self, insn: Insn, _mem: &mut M) -> Result<(), Fault> {
        match insn {
            Insn::Mov { dst, src } => self.exec_mov(dst, src),
        }
    }

    /// Execute a `mov dst, src`. The decoder guarantees `dst` and `src`
    /// have matching widths; we trap with `Fault::WidthMismatch` if not.
    fn exec_mov(&mut self, dst: Operand, src: Operand) -> Result<(), Fault> {
        match (dst, src) {
            (Operand::Reg32(d), Operand::Imm32(v)) => {
                self.set_reg(d, v);
                Ok(())
            }
            _ => Err(Fault::UnimplementedMov),
        }
    }
}

/// Greedy fetch: copy up to `buf.len()` bytes starting at `addr`, stopping
/// at the first byte that faults. Used so an instruction near the end of a
/// mapped region still decodes if enough bytes are available.
fn fetch<M: Memory>(mem: &M, addr: u32, buf: &mut [u8]) -> usize {
    for (i, slot) in buf.iter_mut().enumerate() {
        // MAX_INSN_LEN is 15 so `i` always fits in u32.
        let off = u32::try_from(i).unwrap_or(u32::MAX);
        match mem.read_u8(addr.wrapping_add(off)) {
            Ok(b) => *slot = b,
            Err(_) => return i,
        }
    }
    buf.len()
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
    }
}
