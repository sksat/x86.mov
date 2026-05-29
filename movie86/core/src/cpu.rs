//! Architectural CPU state and the fetch / decode / execute loop.
//!
//! `step()` does one instruction at a time: it fetches bytes via the
//! [`Memory`] trait, hands them to [`decode`], advances `eip`, and dispatches
//! to a per-instruction executor. Decoding stays in `decode.rs` so the same
//! decoder remains usable by tracing / disassembly callers.

use crate::abi_host::{is_abi_addr, AbiHost, ABI_BASE};
use crate::bios_host::{BiosArgs, BiosHost, BiosResult};
use crate::decode::decode;
use crate::insn::{EffectiveAddress, Insn, Operand, Reg16, Reg32, Reg8};
use crate::libc_host::{LibcCall, LibcHost, LibcResult};
use crate::syscall::{SysHost, SyscallArgs, SyscallResult};
use crate::{Fault, Memory};

/// Maximum length of any x86 instruction. Fetches read up to this many
/// bytes per step.
const MAX_INSN_LEN: usize = 15;

/// Linux signal numbers that the emulator can model. Real Linux has
/// many more; we only model the ones movfuscator actually installs
/// handlers for via `sigaction` (SIGSEGV for the dispatch trick,
/// SIGILL for the alternate dispatch via `master_loop`).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Signal {
    Segv = 11,
    Ill = 4,
}

/// Architectural state of the guest CPU.
#[derive(Debug, Clone)]
pub struct Cpu {
    /// General-purpose registers, indexed by [`Reg32`] as `usize`.
    pub regs: [u32; 8],
    pub eip: u32,
    /// Handler address for SIGSEGV (`mov cs, ax` dispatch trick).
    /// `None` means no handler registered — the trick traps with
    /// [`Fault::SignalHandlerUnregistered`].
    sigsegv_handler: Option<u32>,
    /// Handler address for SIGILL — the alternate dispatch movfuscator
    /// registers (`master_loop`).
    sigill_handler: Option<u32>,
}

impl Cpu {
    /// Construct a CPU with `entry` as the initial `eip` and all GPRs zeroed.
    #[must_use]
    pub fn new(entry: u32) -> Self {
        Self {
            regs: [0; 8],
            eip: entry,
            sigsegv_handler: None,
            sigill_handler: None,
        }
    }

    #[must_use]
    pub fn reg(&self, r: Reg32) -> u32 {
        self.regs[r as usize]
    }

    pub fn set_reg(&mut self, r: Reg32, v: u32) {
        self.regs[r as usize] = v;
    }

    /// Register a guest function to invoke when `sig` fires. Called by
    /// the loader once it knows where movfuscator's `dispatch` /
    /// `master_loop` symbols landed.
    pub fn set_signal_handler(&mut self, sig: Signal, handler: u32) {
        match sig {
            Signal::Segv => self.sigsegv_handler = Some(handler),
            Signal::Ill => self.sigill_handler = Some(handler),
        }
    }

    #[must_use]
    pub fn signal_handler(&self, sig: Signal) -> Option<u32> {
        match sig {
            Signal::Segv => self.sigsegv_handler,
            Signal::Ill => self.sigill_handler,
        }
    }

    /// Fetch one instruction at `eip`, decode and execute it, and update
    /// `eip` either by the instruction's encoded length (sequential
    /// instructions) or to a jump/branch target (control-flow instructions).
    pub fn step<M, H>(&mut self, mem: &mut M, host: &mut H) -> Result<(), Fault>
    where
        M: Memory,
        H: SysHost + LibcHost + BiosHost + AbiHost,
    {
        let mut buf = [0u8; MAX_INSN_LEN];
        let (n, partial_fault) = fetch(mem, self.eip, &mut buf)?;
        let (insn, len) = match decode(&buf[..n]) {
            Ok(p) => p,
            Err(Fault::DecodeTruncated) => {
                // If the decoder ran out of bytes and we know fetch
                // was also halted by an unmapped byte, surface that as
                // the real cause — instruction-spans-unmapped is a
                // memory fault, not a malformed instruction stream.
                if let Some(fault) = partial_fault {
                    return Err(fault);
                }
                return Err(Fault::DecodeTruncated);
            }
            Err(e) => return Err(e),
        };
        let next_eip_default = self.eip.wrapping_add(u32::from(len));
        match self.execute(insn, mem, host, next_eip_default) {
            Ok(new_eip) => {
                self.eip = new_eip;
                Ok(())
            }
            Err(e) => {
                // movfuscator's deliberate NULL-deref SIGSEGV trigger
                // (`movl (%eax), %eax` with eax=0) is emitted by
                // `jmp_extern` (movfuscator.c:2397) before each external
                // libc call. We narrow the redirect to **address 0
                // specifically** so other unmapped accesses (stack
                // underflow, wild pointer, etc.) still surface as
                // emulator faults instead of being masked by the
                // dispatch handler.
                if let (Fault::Unmapped(0), Some(handler)) = (e, self.sigsegv_handler) {
                    self.eip = handler;
                    Ok(())
                } else {
                    Err(e)
                }
            }
        }
    }

    fn execute<M, H>(
        &mut self,
        insn: Insn,
        mem: &mut M,
        host: &mut H,
        next_eip_default: u32,
    ) -> Result<u32, Fault>
    where
        M: Memory,
        H: SysHost + LibcHost + BiosHost + AbiHost,
    {
        match insn {
            Insn::Mov { dst, src } => {
                self.exec_mov(dst, src, mem, host)?;
                Ok(next_eip_default)
            }
            Insn::JmpRel32(off) => {
                // The displacement is relative to the *next* instruction,
                // i.e. the address right after the 5-byte jmp.
                let off_bits = u32::from_ne_bytes(off.to_ne_bytes());
                Ok(next_eip_default.wrapping_add(off_bits))
            }
            Insn::Int(0x80) => {
                let args = SyscallArgs::from_regs(&self.regs);
                match host.syscall(&args, mem)? {
                    SyscallResult::Return(v) => {
                        self.set_reg(Reg32::Eax, v);
                        Ok(next_eip_default)
                    }
                }
            }
            Insn::Int(0x10) => {
                // BIOS video services. The host implements whichever
                // function it cares about (typically `AH=0` mode-set);
                // unknown subfunctions trap through `bios_call`'s
                // default impl as `UnsupportedInterrupt(0x10)`.
                let args = BiosArgs::from_regs(&self.regs);
                match host.bios_call(&args, mem)? {
                    BiosResult::Return(v) => {
                        self.set_reg(Reg32::Eax, v);
                        Ok(next_eip_default)
                    }
                }
            }
            Insn::Int(0x81) => {
                // Host-side libc-wrapper ABI. The stub at `self.eip`
                // is `CD 81 C3` (`int 0x81; ret`); on trap, the host
                // reads cdecl args from `[esp+4..]`, performs the work,
                // and returns a value for EAX. The guest's own `ret`
                // (next instruction) pops the cdecl return address.
                let trap_addr = self.eip;
                // Snapshot registers up front so the immutable borrow
                // ends before we call `set_reg`. Matches the
                // `SyscallArgs::from_regs` pattern just above.
                let regs_snapshot = self.regs;
                let result = {
                    let mut call = LibcCall {
                        trap_addr,
                        regs: &regs_snapshot,
                        mem,
                    };
                    host.libc_call(&mut call)?
                };
                match result {
                    LibcResult::Return(v) => {
                        self.set_reg(Reg32::Eax, v);
                        Ok(next_eip_default)
                    }
                }
            }
            Insn::Int(n) => Err(Fault::UnsupportedInterrupt(n)),
            Insn::PushR32(r) => {
                // Read the value BEFORE moving ESP — for `push esp`,
                // the pushed value must be the original ESP (Intel
                // SDM: post-8086 behavior).
                let val = self.reg(r);
                let new_esp = self.reg(Reg32::Esp).wrapping_sub(4);
                mem.write_u32(new_esp, val)?;
                self.set_reg(Reg32::Esp, new_esp);
                Ok(next_eip_default)
            }
            Insn::PopR32(r) => {
                let esp = self.reg(Reg32::Esp);
                let val = mem.read_u32(esp)?;
                // Increment ESP first, then write the destination. If
                // r == Esp, the final write to ESP wins — so the new
                // ESP is the popped value, matching Intel SDM "pop esp".
                self.set_reg(Reg32::Esp, esp.wrapping_add(4));
                self.set_reg(r, val);
                Ok(next_eip_default)
            }
            Insn::CallRel32(off) => {
                // Push the return address (the address of the
                // instruction right after the call), then jump.
                let new_esp = self.reg(Reg32::Esp).wrapping_sub(4);
                mem.write_u32(new_esp, next_eip_default)?;
                self.set_reg(Reg32::Esp, new_esp);
                let off_bits = u32::from_ne_bytes(off.to_ne_bytes());
                Ok(next_eip_default.wrapping_add(off_bits))
            }
            Insn::Ret => {
                let esp = self.reg(Reg32::Esp);
                let target = mem.read_u32(esp)?;
                self.set_reg(Reg32::Esp, esp.wrapping_add(4));
                Ok(target)
            }
            Insn::MovfuscatorDispatchJump(_src) => {
                // `mov cs, ax` (8e c8) is movfuscator's deliberate **SIGILL**
                // trigger — emitted by `progend()` (movfuscator.c:3091)
                // with `mov_loop`. The runtime registers SIGILL → master_loop
                // via sigaction (movfuscator.c:2832), so the kernel invokes
                // master_loop here on real Linux.
                //
                // The other dispatch (NULL deref → SIGSEGV → dispatch) is
                // for external libc calls — a separate trigger we handle
                // in the unmapped-read path, not here.
                self.signal_handler(Signal::Ill)
                    .ok_or(Fault::SignalHandlerUnregistered(Signal::Ill as u32))
            }
            Insn::MovToOtherSegReg => {
                // No-op in flat 32-bit mode.
                Ok(next_eip_default)
            }
            Insn::JmpIndirectMem32(ea) => {
                let target = mem.read_u32(self.compute_ea(ea))?;
                Ok(target)
            }
            Insn::JmpReg32(r) => Ok(self.reg(r)),
        }
    }

    /// Execute a `mov dst, src`. The decoder guarantees `dst` and `src`
    /// have matching widths. We dispatch on the *destination* width and
    /// fault if `src` doesn't agree.
    fn exec_mov<M, H>(
        &mut self,
        dst: Operand,
        src: Operand,
        mem: &mut M,
        host: &mut H,
    ) -> Result<(), Fault>
    where
        M: Memory,
        H: AbiHost,
    {
        // mov-only ABI gate: writes whose computed destination falls in
        // the ABI page get routed through AbiHost.abi_call instead of
        // the underlying Memory. The store doesn't actually land; it's
        // entirely host-mediated. Matches turbo86's SIGSEGV-driven
        // dispatch byte-for-byte (same ABI_BASE / call numbers) so
        // ELFs are portable across the two engines without re-binding.
        if let Operand::Mem32(ea) = dst {
            let addr = self.compute_ea(ea);
            if is_abi_addr(addr) {
                let v = self.read_operand_u32(src, mem)?;
                // ABI_PAGE_SIZE = 0x1000 < u16::MAX, so the offset
                // within the page always fits.
                let call = u16::try_from(addr - ABI_BASE).expect("ABI page offset fits in u16");
                return host.abi_call(call, v, &mut self.regs, mem);
            }
        }
        if let Operand::Mem8(ea) = dst {
            let addr = self.compute_ea(ea);
            if is_abi_addr(addr) {
                let v = self.read_operand_u8(src, mem)?;
                let call = u16::try_from(addr - ABI_BASE).expect("ABI page offset fits in u16");
                return host.abi_call(call, u32::from(v), &mut self.regs, mem);
            }
        }
        match dst {
            Operand::Reg32(_) | Operand::Mem32(_) => {
                let v = self.read_operand_u32(src, mem)?;
                self.write_operand_u32(dst, v, mem)
            }
            Operand::Reg16(_) | Operand::Mem16(_) => {
                let v = self.read_operand_u16(src, mem)?;
                self.write_operand_u16(dst, v, mem)
            }
            Operand::Reg8(_) | Operand::Mem8(_) => {
                let v = self.read_operand_u8(src, mem)?;
                self.write_operand_u8(dst, v, mem)
            }
            _ => Err(Fault::UnimplementedMov),
        }
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

    /// Read a 16-bit source operand.
    fn read_operand_u16<M: Memory>(&self, op: Operand, mem: &M) -> Result<u16, Fault> {
        match op {
            Operand::Reg16(r) => Ok(self.read_reg16(r)),
            Operand::Imm16(v) => Ok(v),
            Operand::Mem16(ea) => mem.read_u16(self.compute_ea(ea)),
            _ => Err(Fault::UnimplementedMov),
        }
    }

    /// Write to a 16-bit destination operand.
    fn write_operand_u16<M: Memory>(
        &mut self,
        op: Operand,
        val: u16,
        mem: &mut M,
    ) -> Result<(), Fault> {
        match op {
            Operand::Reg16(r) => {
                self.write_reg16(r, val);
                Ok(())
            }
            Operand::Mem16(ea) => mem.write_u16(self.compute_ea(ea), val),
            _ => Err(Fault::UnimplementedMov),
        }
    }

    /// Read the low 16 bits of the parent 32-bit register.
    fn read_reg16(&self, r: Reg16) -> u16 {
        (self.reg(r.parent()) & 0xffff) as u16
    }

    /// Write the low 16 bits, preserving the upper 16 bits.
    fn write_reg16(&mut self, r: Reg16, val: u16) {
        let parent = r.parent();
        let new = (self.reg(parent) & 0xffff_0000) | u32::from(val);
        self.set_reg(parent, new);
    }

    /// Read an 8-bit source operand.
    fn read_operand_u8<M: Memory>(&self, op: Operand, mem: &M) -> Result<u8, Fault> {
        match op {
            Operand::Reg8(r) => Ok(self.read_reg8(r)),
            Operand::Imm8(v) => Ok(v),
            Operand::Mem8(ea) => mem.read_u8(self.compute_ea(ea)),
            _ => Err(Fault::UnimplementedMov),
        }
    }

    /// Write to an 8-bit destination operand.
    fn write_operand_u8<M: Memory>(
        &mut self,
        op: Operand,
        val: u8,
        mem: &mut M,
    ) -> Result<(), Fault> {
        match op {
            Operand::Reg8(r) => {
                self.write_reg8(r, val);
                Ok(())
            }
            Operand::Mem8(ea) => mem.write_u8(self.compute_ea(ea), val),
            _ => Err(Fault::UnimplementedMov),
        }
    }

    /// Read an 8-bit GPR. AH/CH/DH/BH alias the high byte of EAX/ECX/EDX/EBX;
    /// AL/CL/DL/BL alias the low byte of the same registers.
    fn read_reg8(&self, r: Reg8) -> u8 {
        let (parent, shift) = r.parent();
        ((self.reg(parent) >> shift) & 0xff) as u8
    }

    /// Write an 8-bit GPR, preserving the surrounding 24 bits of the
    /// aliasing 32-bit register.
    fn write_reg8(&mut self, r: Reg8, val: u8) {
        let (parent, shift) = r.parent();
        let mask = !(0xffu32 << shift);
        let new = (self.reg(parent) & mask) | (u32::from(val) << shift);
        self.set_reg(parent, new);
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
/// Returns:
/// - `Err(fault)` if even the **first** byte is unmapped (so a bad PC
///   surfaces as `Unmapped(eip)` instead of degenerating into
///   `DecodeTruncated`).
/// - `Ok((n, Some(fault)))` if we got `n` bytes (`1..MAX_INSN_LEN`) but
///   then hit an unmapped byte — caller can promote the fault if the
///   short prefix doesn't decode to a valid instruction.
/// - `Ok((n, None))` if the full `buf.len()` bytes were readable.
fn fetch<M: Memory>(mem: &M, addr: u32, buf: &mut [u8]) -> Result<(usize, Option<Fault>), Fault> {
    for (i, slot) in buf.iter_mut().enumerate() {
        // MAX_INSN_LEN is 15 so `i` always fits in u32.
        let off = u32::try_from(i).unwrap_or(u32::MAX);
        match mem.read_u8(addr.wrapping_add(off)) {
            Ok(b) => *slot = b,
            Err(e) if i == 0 => return Err(e),
            Err(e) => return Ok((i, Some(e))),
        }
    }
    Ok((buf.len(), None))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::FlatMemory;
    use proptest::prelude::*;

    /// Test host that refuses every syscall. Use for tests that aren't
    /// supposed to issue one — keeps us honest if the CPU spuriously
    /// invokes the host path. The empty `LibcHost` impl picks up the
    /// trait's default trap, so `int 0x81` faults too.
    struct PanicHost;
    impl SysHost for PanicHost {
        fn syscall(
            &mut self,
            args: &SyscallArgs,
            _mem: &mut dyn Memory,
        ) -> Result<SyscallResult, Fault> {
            panic!("unexpected syscall {:#x}", args.eax);
        }
    }
    impl LibcHost for PanicHost {}
    impl BiosHost for PanicHost {}
    impl AbiHost for PanicHost {}

    /// Test host that records the last syscall and returns a fixed value.
    struct RecordingHost {
        last: Option<SyscallArgs>,
        return_value: u32,
    }
    impl RecordingHost {
        fn new(return_value: u32) -> Self {
            Self {
                last: None,
                return_value,
            }
        }
    }
    impl SysHost for RecordingHost {
        fn syscall(
            &mut self,
            args: &SyscallArgs,
            _mem: &mut dyn Memory,
        ) -> Result<SyscallResult, Fault> {
            self.last = Some(*args);
            Ok(SyscallResult::Return(self.return_value))
        }
    }
    impl LibcHost for RecordingHost {}
    impl BiosHost for RecordingHost {}
    impl AbiHost for RecordingHost {}

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
        cpu.step(&mut mem, &mut PanicHost).unwrap();
        assert_eq!(cpu.reg(Reg32::Eax), 42);
        assert_eq!(cpu.eip, 0x1005);
    }

    #[test]
    fn step_reports_decode_fault() {
        let mut mem = FlatMemory::new_zeroed(0x1000, 16);
        mem.write_u8(0x1000, 0x00).unwrap(); // unknown opcode
        let mut cpu = Cpu::new(0x1000);
        assert_eq!(
            cpu.step(&mut mem, &mut PanicHost).unwrap_err(),
            Fault::UnknownOpcode(0x00)
        );
    }

    #[test]
    fn step_mov_r32_r32_copies_value() {
        // 8b c1 → mov eax, ecx ; reg=000 r/m=001 mod=11
        let mut mem = region_with_program(0x1000, 16, &[0x8b, 0xc1]);
        let mut cpu = Cpu::new(0x1000);
        cpu.set_reg(Reg32::Ecx, 0xdead_beef);
        cpu.step(&mut mem, &mut PanicHost).unwrap();
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
        cpu.step(&mut mem, &mut PanicHost).unwrap();
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
        cpu.step(&mut mem, &mut PanicHost).unwrap();
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
        cpu.step(&mut mem, &mut PanicHost).unwrap();
        assert_eq!(cpu.reg(Reg32::Eax), 0xabcd_ef01);
    }

    // --- 8-bit mov ---

    // --- 16-bit mov (66 prefix) ---

    #[test]
    fn step_movw_mem_to_ax_preserves_upper_16_bits_of_eax() {
        // 66 8b 05 00 20 00 00 → mov ax, word [0x2000]
        let mut mem = FlatMemory::new_zeroed(0x1000, 0x2000);
        mem.write_bytes(0x1000, &[0x66, 0x8b, 0x05, 0x00, 0x20, 0x00, 0x00])
            .unwrap();
        mem.write_u16(0x2000, 0xabcd).unwrap();
        let mut cpu = Cpu::new(0x1000);
        cpu.set_reg(Reg32::Eax, 0xdead_0000);
        cpu.step(&mut mem, &mut PanicHost).unwrap();
        assert_eq!(cpu.reg(Reg32::Eax), 0xdead_abcd);
        assert_eq!(cpu.eip, 0x1007);
    }

    #[test]
    fn step_movw_ax_to_memory_writes_low_word_only() {
        // 66 89 05 00 20 00 00 → mov word [0x2000], ax
        let mut mem = FlatMemory::new_zeroed(0x1000, 0x2000);
        mem.write_bytes(0x1000, &[0x66, 0x89, 0x05, 0x00, 0x20, 0x00, 0x00])
            .unwrap();
        mem.write_u32(0x2000, 0xdead_beef).unwrap();
        let mut cpu = Cpu::new(0x1000);
        cpu.set_reg(Reg32::Eax, 0x1234_5678);
        cpu.step(&mut mem, &mut PanicHost).unwrap();
        // Bytes 0,1 at 0x2000 should be 0x78, 0x56 (low word of EAX, LE).
        // Upper word at 0x2002..0x2004 untouched.
        assert_eq!(mem.read_u32(0x2000).unwrap(), 0xdead_5678);
    }

    #[test]
    fn step_mov_al_to_memory_writes_low_byte_only() {
        // 88 05 00 20 00 00 → mov byte [0x2000], al
        let mut mem = FlatMemory::new_zeroed(0x1000, 0x2000);
        mem.write_bytes(0x1000, &[0x88, 0x05, 0x00, 0x20, 0x00, 0x00])
            .unwrap();
        mem.write_u32(0x2000, 0xdead_beef).unwrap();
        let mut cpu = Cpu::new(0x1000);
        cpu.set_reg(Reg32::Eax, 0x1234_56aa);
        cpu.step(&mut mem, &mut PanicHost).unwrap();
        // Only byte 0 of 0x2000 should change; the surrounding 3 bytes
        // are untouched.
        assert_eq!(mem.read_u32(0x2000).unwrap(), 0xdead_beaa);
    }

    #[test]
    fn step_mov_mem_to_al_preserves_upper_24_bits_of_eax() {
        // 8a 05 00 20 00 00 → mov al, byte [0x2000]
        let mut mem = FlatMemory::new_zeroed(0x1000, 0x2000);
        mem.write_bytes(0x1000, &[0x8a, 0x05, 0x00, 0x20, 0x00, 0x00])
            .unwrap();
        mem.write_u8(0x2000, 0x77).unwrap();
        let mut cpu = Cpu::new(0x1000);
        cpu.set_reg(Reg32::Eax, 0x1234_5600);
        cpu.step(&mut mem, &mut PanicHost).unwrap();
        assert_eq!(cpu.reg(Reg32::Eax), 0x1234_5677);
    }

    #[test]
    fn mov_ah_writes_bits_15_8_not_low_byte() {
        // 8a 25 00 20 00 00 → mov ah, byte [0x2000]
        // ModR/M reg=4 (AH), mod=00, r/m=101 (disp32)
        let mut mem = FlatMemory::new_zeroed(0x1000, 0x2000);
        mem.write_bytes(0x1000, &[0x8a, 0x25, 0x00, 0x20, 0x00, 0x00])
            .unwrap();
        mem.write_u8(0x2000, 0xbb).unwrap();
        let mut cpu = Cpu::new(0x1000);
        cpu.set_reg(Reg32::Eax, 0x1234_5677);
        cpu.step(&mut mem, &mut PanicHost).unwrap();
        assert_eq!(
            cpu.reg(Reg32::Eax),
            0x1234_bb77,
            "AH should touch bits 15:8 only"
        );
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
        cpu.step(&mut mem, &mut PanicHost).unwrap();
        assert_eq!(cpu.reg(Reg32::Ecx), 0xfeed_face);
        assert_eq!(cpu.eip, 0x1007);
    }

    #[test]
    fn step_with_unmapped_eip_reports_unmapped_not_truncated() {
        // Region at 0x1000, but eip points at 0x2000 — fetch can't even
        // read byte 0. We must see Unmapped(0x2000), not DecodeTruncated.
        let mut mem = FlatMemory::new_zeroed(0x1000, 16);
        let mut cpu = Cpu::new(0x2000);
        assert_eq!(
            cpu.step(&mut mem, &mut PanicHost).unwrap_err(),
            Fault::Unmapped(0x2000)
        );
    }

    #[test]
    fn step_with_partial_fetch_reports_unmapped_at_missing_byte() {
        // Allocate exactly 2 bytes — enough for fetch to read 2 bytes
        // of a `mov eax, imm32` (5 bytes), but not the immediate. Plain
        // decode would say DecodeTruncated; we want the underlying
        // Unmapped at the missing byte's address surfaced instead.
        let mut mem = FlatMemory::new_zeroed(0x1000, 2);
        mem.write_bytes(0x1000, &[0xb8, 0x42]).unwrap();
        let mut cpu = Cpu::new(0x1000);
        assert_eq!(
            cpu.step(&mut mem, &mut PanicHost).unwrap_err(),
            Fault::Unmapped(0x1002),
            "missing instruction byte should surface as Unmapped, not DecodeTruncated"
        );
    }

    #[test]
    fn step_mov_r32_to_unmapped_memory_faults() {
        // mov [0x9000], eax — 0x9000 is outside our region
        let mut mem = FlatMemory::new_zeroed(0x1000, 0x100);
        mem.write_bytes(0x1000, &[0x89, 0x05, 0x00, 0x90, 0x00, 0x00])
            .unwrap();
        let mut cpu = Cpu::new(0x1000);
        cpu.set_reg(Reg32::Eax, 42);
        assert_eq!(
            cpu.step(&mut mem, &mut PanicHost).unwrap_err(),
            Fault::Unmapped(0x9000)
        );
    }

    // --- push / pop ---

    /// Place an instruction sequence at `entry`, allocate a stack
    /// adjacent to it, and seed ESP at the top.
    fn cpu_with_stack(entry: u32, program: &[u8], stack_size: u32) -> (Cpu, FlatMemory) {
        let total = u32::try_from(program.len()).unwrap() + stack_size;
        let mut mem = FlatMemory::new_zeroed(entry, total as usize);
        mem.write_bytes(entry, program).unwrap();
        let mut cpu = Cpu::new(entry);
        cpu.set_reg(Reg32::Esp, entry + total);
        (cpu, mem)
    }

    #[test]
    fn step_push_pop_roundtrip_preserves_value_and_esp() {
        // 50 → push eax ; 5b → pop ebx
        let (mut cpu, mut mem) = cpu_with_stack(0x1000, &[0x50, 0x5b], 64);
        let initial_esp = cpu.reg(Reg32::Esp);
        cpu.set_reg(Reg32::Eax, 0xdead_beef);
        cpu.step(&mut mem, &mut PanicHost).unwrap();
        assert_eq!(cpu.reg(Reg32::Esp), initial_esp - 4);
        assert_eq!(mem.read_u32(initial_esp - 4).unwrap(), 0xdead_beef);
        cpu.step(&mut mem, &mut PanicHost).unwrap();
        assert_eq!(cpu.reg(Reg32::Ebx), 0xdead_beef);
        assert_eq!(cpu.reg(Reg32::Esp), initial_esp);
    }

    #[test]
    fn push_esp_stores_original_esp() {
        // 54 → push esp ; the value pushed is the ORIGINAL esp,
        // not the post-decrement esp (Intel SDM, post-8086 behavior).
        let (mut cpu, mut mem) = cpu_with_stack(0x1000, &[0x54], 64);
        let initial_esp = cpu.reg(Reg32::Esp);
        cpu.step(&mut mem, &mut PanicHost).unwrap();
        assert_eq!(mem.read_u32(initial_esp - 4).unwrap(), initial_esp);
        assert_eq!(cpu.reg(Reg32::Esp), initial_esp - 4);
    }

    #[test]
    fn pop_esp_replaces_esp_with_popped_value() {
        // 5c → pop esp ; final esp is the popped value, not old + 4.
        // Manually shift ESP to simulate a prior push, then plant the
        // value that pop will read at the new top of stack.
        let (mut cpu, mut mem) = cpu_with_stack(0x1000, &[0x5c], 64);
        let top = cpu.reg(Reg32::Esp);
        let pushed_addr = top - 4;
        cpu.set_reg(Reg32::Esp, pushed_addr);
        mem.write_u32(pushed_addr, 0xcafe_d00d).unwrap();
        cpu.step(&mut mem, &mut PanicHost).unwrap();
        assert_eq!(cpu.reg(Reg32::Esp), 0xcafe_d00d);
    }

    // --- movfuscator dispatch trick + indirect jmp ---

    #[test]
    fn movfuscator_dispatch_jump_invokes_registered_sigill_handler() {
        // 8e c8 → mov cs, ax. movfuscator emits this as a deliberate
        // SIGILL trigger (movfuscator.c:3091, inside the `mov_loop`
        // branch of progend). With a SIGILL handler registered the
        // dispatch jumps there (matching kernel signal delivery).
        let (mut cpu, mut mem) = cpu_with_stack(0x1000, &[0x8e, 0xc8], 64);
        cpu.set_signal_handler(Signal::Ill, 0xdead_beef);
        cpu.set_reg(Reg32::Eax, 0x4242); // intentionally NOT the target
        cpu.step(&mut mem, &mut PanicHost).unwrap();
        assert_eq!(cpu.eip, 0xdead_beef);
    }

    #[test]
    fn movfuscator_dispatch_jump_with_no_handler_traps() {
        let (mut cpu, mut mem) = cpu_with_stack(0x1000, &[0x8e, 0xc8], 64);
        cpu.set_reg(Reg32::Eax, 0x4242);
        assert_eq!(
            cpu.step(&mut mem, &mut PanicHost).unwrap_err(),
            Fault::SignalHandlerUnregistered(Signal::Ill as u32),
        );
    }

    #[test]
    fn mov_to_other_seg_reg_is_noop_and_advances_eip() {
        // 8e d8 → mov ds, ax  (no-op in flat 32-bit mode)
        let (mut cpu, mut mem) = cpu_with_stack(0x1000, &[0x8e, 0xd8], 64);
        cpu.set_reg(Reg32::Eax, 0x1234);
        cpu.step(&mut mem, &mut PanicHost).unwrap();
        assert_eq!(cpu.eip, 0x1002, "should advance past the 2-byte insn");
        assert_eq!(cpu.reg(Reg32::Eax), 0x1234, "eax unchanged");
    }

    #[test]
    fn jmp_indirect_mem32_reads_target_from_memory() {
        // ff 25 00 20 00 00 → jmp DWORD PTR ds:0x2000
        let mut mem = FlatMemory::new_zeroed(0x1000, 0x2000);
        mem.write_bytes(0x1000, &[0xff, 0x25, 0x00, 0x20, 0x00, 0x00])
            .unwrap();
        mem.write_u32(0x2000, 0xcafe_d00d).unwrap();
        let mut cpu = Cpu::new(0x1000);
        cpu.step(&mut mem, &mut PanicHost).unwrap();
        assert_eq!(cpu.eip, 0xcafe_d00d);
    }

    // --- call + ret ---

    #[test]
    fn step_call_pushes_return_address_and_jumps() {
        // 1000: e8 0a 00 00 00   → call +10
        // Next-insn address (= return address) is 0x1005;
        // target is 0x1005 + 10 = 0x100f.
        let (mut cpu, mut mem) = cpu_with_stack(0x1000, &[0xe8, 0x0a, 0x00, 0x00, 0x00], 64);
        let initial_esp = cpu.reg(Reg32::Esp);
        cpu.step(&mut mem, &mut PanicHost).unwrap();
        assert_eq!(cpu.eip, 0x100f, "EIP should jump to target");
        assert_eq!(
            cpu.reg(Reg32::Esp),
            initial_esp - 4,
            "call should push 4 bytes"
        );
        assert_eq!(
            mem.read_u32(initial_esp - 4).unwrap(),
            0x1005,
            "pushed return address must be the addr of the insn AFTER the call"
        );
    }

    #[test]
    fn step_ret_pops_and_jumps_to_top_of_stack() {
        // c3 → ret. Plant a return address at the top of the stack.
        let (mut cpu, mut mem) = cpu_with_stack(0x1000, &[0xc3], 64);
        let top = cpu.reg(Reg32::Esp);
        let pushed_addr = top - 4;
        cpu.set_reg(Reg32::Esp, pushed_addr);
        mem.write_u32(pushed_addr, 0x2000).unwrap();
        cpu.step(&mut mem, &mut PanicHost).unwrap();
        assert_eq!(cpu.eip, 0x2000);
        assert_eq!(cpu.reg(Reg32::Esp), top, "esp should be restored after ret");
    }

    #[test]
    fn call_then_ret_returns_to_instruction_after_call() {
        // Layout (entry = 0x1000):
        //   0x1000: e8 02 00 00 00       call +2   ;  → 0x1007
        //   0x1005: cd 80                int 0x80  (would exit; never reached)
        //   0x1007: c3                   ret
        // After call: eip=0x1007, return addr 0x1005 on stack.
        // After ret:  eip=0x1005, esp restored.
        let (mut cpu, mut mem) = cpu_with_stack(
            0x1000,
            &[
                0xe8, 0x02, 0x00, 0x00, 0x00, // call +2
                0xcd, 0x80, //                  int 0x80 (return target)
                0xc3, //                        ret
            ],
            64,
        );
        let initial_esp = cpu.reg(Reg32::Esp);
        cpu.step(&mut mem, &mut PanicHost).unwrap();
        assert_eq!(cpu.eip, 0x1007);
        cpu.step(&mut mem, &mut PanicHost).unwrap();
        assert_eq!(cpu.eip, 0x1005);
        assert_eq!(cpu.reg(Reg32::Esp), initial_esp);
    }

    // --- jmp + int ---

    #[test]
    fn step_jmp_rel32_targets_eip_relative_to_next_insn() {
        // 1000: e9 0a 00 00 00   → jmp +10
        // Next-insn address is 0x1005; target is 0x1005 + 10 = 0x100f.
        let mut mem = FlatMemory::new_zeroed(0x1000, 0x100);
        mem.write_bytes(0x1000, &[0xe9, 0x0a, 0x00, 0x00, 0x00])
            .unwrap();
        let mut cpu = Cpu::new(0x1000);
        cpu.step(&mut mem, &mut PanicHost).unwrap();
        assert_eq!(cpu.eip, 0x100f);
    }

    #[test]
    fn step_jmp_rel32_negative_loops_back() {
        // 1005: e9 f6 ff ff ff  → jmp -10  (next-insn is 0x100a; target 0x1000)
        let mut mem = FlatMemory::new_zeroed(0x1000, 0x100);
        mem.write_bytes(0x1005, &[0xe9, 0xf6, 0xff, 0xff, 0xff])
            .unwrap();
        let mut cpu = Cpu::new(0x1005);
        cpu.step(&mut mem, &mut PanicHost).unwrap();
        assert_eq!(cpu.eip, 0x1000);
    }

    #[test]
    fn step_int_0x80_invokes_host_with_register_snapshot() {
        // cd 80 → int 0x80
        let mut mem = FlatMemory::new_zeroed(0x1000, 16);
        mem.write_bytes(0x1000, &[0xcd, 0x80]).unwrap();
        let mut cpu = Cpu::new(0x1000);
        cpu.set_reg(Reg32::Eax, 4); // pretend write
        cpu.set_reg(Reg32::Ebx, 1);
        cpu.set_reg(Reg32::Ecx, 0x2000);
        cpu.set_reg(Reg32::Edx, 5);
        let mut host = RecordingHost::new(/* return = */ 5);
        cpu.step(&mut mem, &mut host).unwrap();
        let args = host.last.expect("host saw the syscall");
        assert_eq!(args.eax, 4);
        assert_eq!(args.ebx, 1);
        assert_eq!(args.ecx, 0x2000);
        assert_eq!(args.edx, 5);
        assert_eq!(
            cpu.reg(Reg32::Eax),
            5,
            "host return value should land in EAX"
        );
        assert_eq!(cpu.eip, 0x1002);
    }

    #[test]
    fn step_int_0x10_invokes_bios_host_with_register_snapshot() {
        // cd 10 → int 0x10 (BIOS video services)
        struct RecordingBios {
            last: Option<BiosArgs>,
            return_value: u32,
        }
        impl SysHost for RecordingBios {
            fn syscall(
                &mut self,
                args: &SyscallArgs,
                _mem: &mut dyn Memory,
            ) -> Result<SyscallResult, Fault> {
                panic!("unexpected syscall {:#x}", args.eax);
            }
        }
        impl LibcHost for RecordingBios {}
        impl AbiHost for RecordingBios {}
        impl BiosHost for RecordingBios {
            fn bios_call(
                &mut self,
                args: &BiosArgs,
                _mem: &mut dyn Memory,
            ) -> Result<BiosResult, Fault> {
                self.last = Some(*args);
                Ok(BiosResult::Return(self.return_value))
            }
        }
        let mut mem = FlatMemory::new_zeroed(0x1000, 16);
        mem.write_bytes(0x1000, &[0xcd, 0x10]).unwrap();
        let mut cpu = Cpu::new(0x1000);
        // AH=0 (set mode), AL=0x13 (mode 13h) → eax = 0x00000013.
        cpu.set_reg(Reg32::Eax, 0x0000_0013);
        let mut host = RecordingBios {
            last: None,
            return_value: 0xdead_beef,
        };
        cpu.step(&mut mem, &mut host).unwrap();
        let args = host.last.expect("host saw the BIOS call");
        assert_eq!(args.eax, 0x0000_0013);
        assert_eq!(args.ah(), 0);
        assert_eq!(args.al(), 0x13);
        assert_eq!(
            cpu.reg(Reg32::Eax),
            0xdead_beef,
            "BIOS return value should land in EAX",
        );
        assert_eq!(cpu.eip, 0x1002);
    }

    #[test]
    fn step_mov_to_abi_page_routes_through_abi_host() {
        // `mov [0x1FFE_0010], al` (A2 imm32) — set_video_mode.
        // The store must NOT land in memory (the page is unmapped by
        // design); instead AbiHost::abi_call should see the call.
        struct RecordingAbi {
            last: Option<(u16, u32)>,
        }
        impl SysHost for RecordingAbi {
            fn syscall(
                &mut self,
                args: &SyscallArgs,
                _mem: &mut dyn Memory,
            ) -> Result<SyscallResult, Fault> {
                panic!("unexpected syscall {:#x}", args.eax);
            }
        }
        impl LibcHost for RecordingAbi {}
        impl BiosHost for RecordingAbi {}
        impl AbiHost for RecordingAbi {
            fn abi_call(
                &mut self,
                call_num: u16,
                value: u32,
                _regs: &mut [u32; 8],
                _mem: &mut dyn Memory,
            ) -> Result<(), Fault> {
                self.last = Some((call_num, value));
                Ok(())
            }
        }
        // mov al, 0x13 ; mov [0x1FFE_0010], al
        let bytes = [0xB0, 0x13, 0xA2, 0x10, 0x00, 0xFE, 0x1F];
        let mut mem = FlatMemory::new_zeroed(0x1000, 16);
        mem.write_bytes(0x1000, &bytes).unwrap();
        let mut cpu = Cpu::new(0x1000);
        let mut host = RecordingAbi { last: None };
        cpu.step(&mut mem, &mut host).unwrap(); // mov al, 0x13
        assert_eq!(cpu.reg(Reg32::Eax) & 0xFF, 0x13);
        cpu.step(&mut mem, &mut host).unwrap(); // mov [0x1FFE_0010], al
        let (call, val) = host.last.expect("AbiHost saw the call");
        assert_eq!(call, 0x010);
        assert_eq!(val, 0x13);
        // EIP must be past the A2 instruction (entry + 7 bytes total).
        assert_eq!(cpu.eip, 0x1007);
    }

    #[test]
    fn step_mov32_to_abi_page_routes_through_abi_host() {
        // `mov [0x1FFE_0020], eax` (A3 imm32) — mmap_request packed arg.
        struct RecordingAbi {
            last: Option<(u16, u32)>,
        }
        impl SysHost for RecordingAbi {
            fn syscall(
                &mut self,
                args: &SyscallArgs,
                _mem: &mut dyn Memory,
            ) -> Result<SyscallResult, Fault> {
                panic!("unexpected syscall {:#x}", args.eax);
            }
        }
        impl LibcHost for RecordingAbi {}
        impl BiosHost for RecordingAbi {}
        impl AbiHost for RecordingAbi {
            fn abi_call(
                &mut self,
                call_num: u16,
                value: u32,
                _regs: &mut [u32; 8],
                _mem: &mut dyn Memory,
            ) -> Result<(), Fault> {
                self.last = Some((call_num, value));
                Ok(())
            }
        }
        // mov eax, 0x00100003 ; mov [0x1FFE_0020], eax
        let bytes = [0xB8, 0x03, 0x00, 0x10, 0x00, 0xA3, 0x20, 0x00, 0xFE, 0x1F];
        let mut mem = FlatMemory::new_zeroed(0x1000, 16);
        mem.write_bytes(0x1000, &bytes).unwrap();
        let mut cpu = Cpu::new(0x1000);
        let mut host = RecordingAbi { last: None };
        cpu.step(&mut mem, &mut host).unwrap(); // mov eax, …
        cpu.step(&mut mem, &mut host).unwrap(); // mov [0x1FFE_0020], eax
        let (call, val) = host.last.expect("AbiHost saw the call");
        assert_eq!(call, 0x020);
        assert_eq!(val, 0x0010_0003);
    }

    #[test]
    fn step_int_non_syscall_vector_traps() {
        let mut mem = FlatMemory::new_zeroed(0x1000, 16);
        mem.write_bytes(0x1000, &[0xcd, 0x03]).unwrap();
        let mut cpu = Cpu::new(0x1000);
        assert_eq!(
            cpu.step(&mut mem, &mut PanicHost).unwrap_err(),
            Fault::UnsupportedInterrupt(0x03),
        );
    }

    /// Test host for the libc-wrapper ABI. Records what it saw and
    /// returns a fixed value for EAX.
    struct RecordingLibcHost {
        last_trap: Option<u32>,
        last_args: [Option<u32>; 4],
        return_value: u32,
    }
    impl RecordingLibcHost {
        fn new(return_value: u32) -> Self {
            Self {
                last_trap: None,
                last_args: [None; 4],
                return_value,
            }
        }
    }
    impl SysHost for RecordingLibcHost {
        fn syscall(
            &mut self,
            args: &SyscallArgs,
            _mem: &mut dyn Memory,
        ) -> Result<SyscallResult, Fault> {
            panic!("unexpected syscall {:#x}", args.eax);
        }
    }
    impl LibcHost for RecordingLibcHost {
        fn libc_call(&mut self, call: &mut LibcCall<'_>) -> Result<LibcResult, Fault> {
            self.last_trap = Some(call.trap_addr);
            for (i, slot) in self.last_args.iter_mut().enumerate() {
                *slot = call.arg_u32(i).ok();
            }
            Ok(LibcResult::Return(self.return_value))
        }
    }
    impl BiosHost for RecordingLibcHost {}
    impl AbiHost for RecordingLibcHost {}

    #[test]
    fn step_int_0x81_invokes_libc_host_with_trap_addr_and_cdecl_args() {
        // Layout: int 0x81 stub at 0x1000, a guest stack at 0x2000.
        // Pre-stage `[esp+0]=retaddr, [esp+4]=arg0, [esp+8]=arg1` so
        // the host can read them via `LibcCall::arg_u32`.
        let mut mem = FlatMemory::new_zeroed(0x1000, 0x2000);
        mem.write_bytes(0x1000, &[0xcd, 0x81]).unwrap(); // int 0x81
        mem.write_u32(0x2000, 0xdead_beef).unwrap(); // [esp+0] retaddr
        mem.write_u32(0x2004, 42).unwrap(); // [esp+4] arg0
        mem.write_u32(0x2008, 0x1234_5678).unwrap(); // [esp+8] arg1
        let mut cpu = Cpu::new(0x1000);
        cpu.set_reg(Reg32::Esp, 0x2000);
        let mut host = RecordingLibcHost::new(/* return = */ 99);
        cpu.step(&mut mem, &mut host).unwrap();
        assert_eq!(
            host.last_trap,
            Some(0x1000),
            "trap_addr should be the eip of the int 0x81 instruction"
        );
        assert_eq!(host.last_args[0], Some(42), "[esp+4] = arg0");
        assert_eq!(host.last_args[1], Some(0x1234_5678), "[esp+8] = arg1");
        assert_eq!(
            cpu.reg(Reg32::Eax),
            99,
            "host's LibcResult::Return value should land in EAX"
        );
        assert_eq!(
            cpu.eip, 0x1002,
            "eip should advance past the CD 81 bytes — the stub's own `ret` runs next"
        );
        assert_eq!(
            cpu.reg(Reg32::Esp),
            0x2000,
            "esp must not move — the stub's `ret` will pop the cdecl retaddr"
        );
    }

    #[test]
    fn step_int_0x81_traps_when_no_libc_host_impl() {
        // PanicHost has the default LibcHost impl, which traps with
        // Fault::UnsupportedInterrupt(0x81). Verify the routing fires.
        let mut mem = FlatMemory::new_zeroed(0x1000, 16);
        mem.write_bytes(0x1000, &[0xcd, 0x81]).unwrap();
        let mut cpu = Cpu::new(0x1000);
        cpu.set_reg(Reg32::Esp, 0x100c);
        assert_eq!(
            cpu.step(&mut mem, &mut PanicHost).unwrap_err(),
            Fault::UnsupportedInterrupt(0x81),
        );
    }

    proptest! {
        /// For every signed displacement, call followed by ret comes
        /// back to the address right after the call, with esp restored.
        /// The displacement is bounded so the call target stays inside
        /// the mapped region (we don't fetch from it — just verify EIP).
        #[test]
        fn pbt_call_ret_returns_to_after_call(disp in -1024i32..=1024) {
            // 5-byte call at entry, then `ret` immediately so the
            // call's "next instruction" address survives one ret cycle.
            // We skip the body between call target and ret — the ret
            // instruction is placed at the call's target.
            let entry = 0x4000u32;
            let return_addr = entry + 5;
            // Place the `ret` at (entry + 5 + disp), which is the call's
            // target. To make that legal we constrain disp so the target
            // sits inside our region.
            let target = return_addr.wrapping_add(u32::from_ne_bytes(disp.to_ne_bytes()));
            // Skip cases where the target would overlap the call bytes
            // or the ret would land where we don't want it.
            prop_assume!(target >= entry + 5 && target < entry + 0x2000 - 1);
            let mut bytes = alloc::vec![0u8; 0x2000];
            let d = disp.to_le_bytes();
            bytes[0..5].copy_from_slice(&[0xe8, d[0], d[1], d[2], d[3]]); // call disp
            bytes[(target - entry) as usize] = 0xc3; // ret at target
            let mut mem = FlatMemory::new_zeroed(entry, 0x2000 + 64);
            mem.write_bytes(entry, &bytes).unwrap();
            let mut cpu = Cpu::new(entry);
            cpu.set_reg(Reg32::Esp, entry + 0x2000 + 64);
            let initial_esp = cpu.reg(Reg32::Esp);
            cpu.step(&mut mem, &mut PanicHost).unwrap(); // call
            prop_assert_eq!(cpu.eip, target);
            cpu.step(&mut mem, &mut PanicHost).unwrap(); // ret
            prop_assert_eq!(cpu.eip, return_addr);
            prop_assert_eq!(cpu.reg(Reg32::Esp), initial_esp);
        }

        /// For every (push reg, pop reg) pair (excluding ESP, which has
        /// special-case semantics tested separately): pushing X then
        /// popping recovers X and ESP nets out to its starting value.
        #[test]
        fn pbt_push_pop_roundtrip(src_idx in 0u8..8, dst_idx in 0u8..8, val: u32) {
            let src = Reg32::from_index(src_idx);
            let dst = Reg32::from_index(dst_idx);
            prop_assume!(src != Reg32::Esp && dst != Reg32::Esp);
            let push = 0x50 + src_idx;
            let pop = 0x58 + dst_idx;
            let (mut cpu, mut mem) = cpu_with_stack(0x1000, &[push, pop], 64);
            let initial_esp = cpu.reg(Reg32::Esp);
            cpu.set_reg(src, val);
            cpu.step(&mut mem, &mut PanicHost).unwrap();
            cpu.step(&mut mem, &mut PanicHost).unwrap();
            prop_assert_eq!(cpu.reg(dst), val);
            prop_assert_eq!(cpu.reg(Reg32::Esp), initial_esp);
        }

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
            cpu.step(&mut mem, &mut PanicHost).unwrap();
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
            cpu.step(&mut mem, &mut PanicHost).unwrap();
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
