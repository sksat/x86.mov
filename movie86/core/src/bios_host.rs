//! BIOS interrupt vector (`int 0x10`) dispatch.
//!
//! Real-mode x86 BIOS multiplexes its video services through `int 0x10`,
//! with the function selected by `AH` and arguments in the other
//! registers. movie86 uses the same convention so guests can request
//! a video mode the way they would on real hardware (`AH=0, AL=mode`)
//! — the host implements the side effect (in the wasm demo, "make
//! that mode's canvas the active one"). The CPU just forwards the
//! call; whether anything happens depends on whether the host's
//! [`BiosHost::bios_call`] handles the requested function or returns
//! the default trap.
//!
//! Kept symmetric with [`crate::syscall::SysHost`] /
//! [`crate::libc_host::LibcHost`]: each interrupt vector with a real
//! host-side meaning gets its own trait, so a host can opt into the
//! ones it cares about and leave the rest defaulting to a trap.

use crate::insn::Reg32;
use crate::{Fault, Memory};

/// Register snapshot passed to [`BiosHost::bios_call`]. The function
/// number lives in `AH` (top byte of `EAX`) and sub-arguments in
/// `AL` / `BX` / etc., per BIOS convention.
#[derive(Debug, Clone, Copy)]
pub struct BiosArgs {
    pub eax: u32,
    pub ebx: u32,
    pub ecx: u32,
    pub edx: u32,
    pub esi: u32,
    pub edi: u32,
    pub ebp: u32,
}

impl BiosArgs {
    /// Snapshot the registers at the `int 0x10` trap.
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

    /// `AH` — function number per BIOS video-services convention.
    #[must_use]
    pub fn ah(&self) -> u8 {
        ((self.eax >> 8) & 0xff) as u8
    }

    /// `AL` — sub-argument (e.g. mode number for `AH=0`).
    #[must_use]
    pub fn al(&self) -> u8 {
        (self.eax & 0xff) as u8
    }
}

/// What the host wants the CPU to do after the BIOS call.
#[derive(Debug, Clone, Copy)]
pub enum BiosResult {
    /// Normal return — the value goes into `EAX` and execution
    /// resumes at the instruction after `int 0x10`.
    Return(u32),
}

/// Host-side dispatcher for guest `int 0x10` BIOS calls.
///
/// The default impl traps with [`Fault::UnsupportedInterrupt(0x10)`]
/// so hosts that don't care about BIOS calls can write
/// `impl BiosHost for MyHost {}` and get the right behavior.
pub trait BiosHost {
    /// Handle the BIOS call. `args.ah()` is the function selector.
    ///
    /// # Errors
    /// Faults propagate to the CPU and end the run.
    fn bios_call(&mut self, _args: &BiosArgs, _mem: &mut dyn Memory) -> Result<BiosResult, Fault> {
        Err(Fault::UnsupportedInterrupt(0x10))
    }
}
