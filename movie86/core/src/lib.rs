#![no_std]

extern crate alloc;

pub mod cpu;
pub mod decode;
pub mod insn;
pub mod mem;
pub mod syscall;

pub use cpu::Cpu;
pub use decode::decode;
pub use insn::{EffectiveAddress, Insn, Operand, Reg16, Reg32, Reg8};
pub use mem::{FlatMemory, Memory};
pub use syscall::{SyscallArgs, SyscallResult, SysHost};

/// Reasons emulation can stop in a way the caller needs to handle.
///
/// Kept narrow on purpose — each variant should correspond to a distinct
/// recovery path. Don't add a variant unless a caller wants to branch on it.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Fault {
    /// Memory access to an address not covered by any mapped region.
    Unmapped(u32),
    /// Ran out of bytes before a full instruction could be decoded.
    DecodeTruncated,
    /// First opcode byte is not in the supported set.
    UnknownOpcode(u8),
    /// `Mov` form that the executor doesn't yet know how to evaluate.
    /// Distinct from `UnknownOpcode` because the decoder already accepted it.
    UnimplementedMov,
    /// Guest requested exit via a syscall. Carries the requested status code.
    Exit(i32),
    /// `int n` with `n` other than 0x80. Only the Linux syscall vector
    /// is wired up.
    UnsupportedInterrupt(u8),
    /// `int 0x80` with a syscall number the host doesn't implement.
    UnknownSyscall(u32),
}
