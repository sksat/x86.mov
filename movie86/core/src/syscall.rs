//! Syscall ABI bridge.
//!
//! The CPU executes `int 0x80` by gathering the Linux i386 syscall
//! argument registers and handing them to a host [`SysHost`]. The host
//! is responsible for whatever side-effect the syscall implies (writing
//! to stdout, exiting, etc.) and returns either a value for EAX or
//! `Exit(status)` to halt the emulator.
//!
//! Unsupported syscall numbers are expected to be reported by the host
//! returning [`Fault::UnknownSyscall`] — there is **no** default no-op
//! handler. Silent success would hide bugs.

use crate::insn::Reg32;
use crate::{Fault, Memory};

/// Linux i386 syscall argument registers.
#[derive(Debug, Clone, Copy)]
pub struct SyscallArgs {
    pub eax: u32, // syscall number
    pub ebx: u32, // arg 1
    pub ecx: u32, // arg 2
    pub edx: u32, // arg 3
    pub esi: u32, // arg 4
    pub edi: u32, // arg 5
    pub ebp: u32, // arg 6
}

impl SyscallArgs {
    /// Snapshot the syscall registers from a CPU register file.
    #[must_use]
    pub fn from_regs(regs: &[u32; 8]) -> Self {
        Self {
            eax: regs[Reg32::Eax as usize],
            ebx: regs[Reg32::Ebx as usize],
            ecx: regs[Reg32::Ecx as usize],
            edx: regs[Reg32::Edx as usize],
            esi: regs[Reg32::Esi as usize],
            edi: regs[Reg32::Edi as usize],
            ebp: regs[Reg32::Ebp as usize],
        }
    }
}

/// What the host wants the CPU to do after the syscall.
#[derive(Debug, Clone, Copy)]
pub enum SyscallResult {
    /// Normal return. The value is placed in EAX and execution continues.
    Return(u32),
}

/// Host-side syscall dispatcher.
///
/// `mem` is the guest address space so the host can read input buffers
/// (e.g. the `buf` of a `write(2)`) and write output buffers.
pub trait SysHost {
    fn syscall(&mut self, args: &SyscallArgs, mem: &mut dyn Memory)
        -> Result<SyscallResult, Fault>;
}
