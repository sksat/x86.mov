//! Host-side libc-wrapper ABI.
//!
//! When a guest program calls a libc-style function (`printf`, `exit`,
//! `sigaction`, …) we don't run the function's mov-only body inside the
//! emulator. Instead the linked binary contains a sentinel stub
//!
//! ```text
//! printf:
//!     int $0x81    ; CD 81 — trap to LibcHost
//!     ret          ; C3    — pop the cdecl retaddr
//! ```
//!
//! The CPU traps on `int 0x81` and hands control to [`LibcHost`], which
//! reads cdecl args from `[esp+4..]`, performs the work using host
//! facilities (writing to stdout, recording the sigaction handler,
//! exiting, …) and returns a value for `EAX`. The guest's `ret` then
//! pops the return address normally.
//!
//! Kept separate from [`crate::syscall::SysHost`] because the two ABIs
//! are different: Linux i386 syscalls pass args in registers, libc
//! follows cdecl on the stack. Smart-friend's review pinned mixing the
//! two as the wrong boundary.
//!
//! Designed for wasm portability: the host owns the trap-address →
//! function table, the core only knows the ABI. A future wasm host
//! plugs the same trait in.

use crate::insn::Reg32;
use crate::{Fault, Memory};

/// Argument view passed to a [`LibcHost`]. Read individual cdecl
/// arguments via [`Self::arg_u32`] — index 0 is `[esp+4]`, index 1 is
/// `[esp+8]`, and so on. `[esp+0]` is the return address and is
/// reachable as [`Self::retaddr`].
///
/// `Debug` is intentionally not derived: `mem` is a `&mut dyn Memory`,
/// which doesn't implement `Debug`. Tests that want to print should
/// log `trap_addr` and any read-out args themselves.
#[allow(missing_debug_implementations)]
pub struct LibcCall<'a> {
    /// Address of the `int 0x81` instruction that traped. Use as the
    /// key into the host's "which function is this stub?" table.
    pub trap_addr: u32,
    /// Snapshot of the guest's general-purpose registers at trap entry.
    pub regs: &'a [u32; 8],
    /// Guest memory. Argument reads go through here.
    pub mem: &'a mut dyn Memory,
}

impl LibcCall<'_> {
    /// Read the cdecl return address (`[esp+0]`).
    ///
    /// # Errors
    /// Returns [`Fault::Unmapped`] if `esp` is outside any mapped region.
    pub fn retaddr(&self) -> Result<u32, Fault> {
        let esp = self.regs[Reg32::Esp as usize];
        self.mem.read_u32(esp)
    }

    /// Read cdecl arg `i` (0-based) as a `u32`. `i=0` is `[esp+4]`.
    ///
    /// # Errors
    /// Returns [`Fault::Unmapped`] if `[esp+4+i*4]` is outside any
    /// mapped region.
    pub fn arg_u32(&self, i: usize) -> Result<u32, Fault> {
        let esp = self.regs[Reg32::Esp as usize];
        // cdecl arg slot stride. `i` is host-side index — truncating
        // at u32::MAX wraps to a guest address that almost certainly
        // faults on read, which is the right outcome.
        let i_u32 = u32::try_from(i).unwrap_or(u32::MAX);
        let off = 4u32.wrapping_add(i_u32.wrapping_mul(4));
        let addr = esp.wrapping_add(off);
        self.mem.read_u32(addr)
    }
}

/// What the host wants the CPU to do after the libc call returns.
#[derive(Debug, Clone, Copy)]
pub enum LibcResult {
    /// Normal return — the value goes into `EAX` and execution
    /// resumes at the instruction after the `int 0x81` trap (the
    /// stub's own `ret`, which will pop the cdecl retaddr).
    Return(u32),
}

/// Host-side dispatcher for guest libc-style calls.
///
/// Implementations typically own a `BTreeMap<u32, LibcFn>` populated
/// from the ELF symbol table at startup; the trap address tells them
/// which function fired. Returning [`Fault::Exit`] terminates the run
/// (used by `exit`).
///
/// The default impl traps with [`Fault::UnsupportedInterrupt(0x81)`]
/// so that a test host that doesn't care about libc calls can write
/// `impl LibcHost for MyHost {}` and get the right behavior.
pub trait LibcHost {
    /// Handle the libc call. `call.trap_addr` identifies which stub
    /// fired; the host is responsible for the trap-addr → function
    /// mapping.
    ///
    /// # Errors
    /// Faults propagate to the CPU and end the run.
    fn libc_call(&mut self, _call: &mut LibcCall<'_>) -> Result<LibcResult, Fault> {
        Err(Fault::UnsupportedInterrupt(0x81))
    }
}
