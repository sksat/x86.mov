//! mov-only ABI page dispatch.
//!
//! The mov-only ABI lets a guest request host services using only the
//! `mov` instruction — no `int` involved. The runner / Vm reserves a
//! 4 KiB unmapped page at [`ABI_BASE`], and any guest write into that
//! page is interpreted as a host call:
//!
//! - dst offset within the page = call number,
//! - written value              = call argument.
//!
//! Two host calls are defined today:
//!
//! - [`CALL_SET_VIDEO_MODE`] (`0x010`) — emit a "set video mode" event,
//!   replaces `int 0x10 / AH=0 / AL=mode`.
//! - [`CALL_MMAP_REQUEST`]   (`0x020`) — ask for an RWX mapping of a
//!   page-aligned range. The packed argument is
//!   `addr | (pages - 1)` (`addr` page-aligned, low 12 bits encode
//!   page count − 1, range 1..4096 pages).
//!
//! The constants here are the cross-engine contract: turbo86's runner
//! (Go side) and movie86's wasm/CLI hosts (Rust side) both target them
//! byte-for-byte. Don't renumber without coordinating both sides.

use crate::{Fault, Memory};

/// Base of the mov-only ABI page. Picked to sit between movie86's typical
/// load base (~`0x08048000`) and turbo86's stack mmap (`0x70000000`), so
/// it never collides with code, data, or stack in either engine.
pub const ABI_BASE: u32 = 0x1FFE_0000;

/// Size of the ABI page. Call numbers must fit in `[0, ABI_PAGE_SIZE)`.
pub const ABI_PAGE_SIZE: u32 = 0x1000;

/// `mov [ABI_BASE + 0x010], al` — emit a `set_video_mode` event with `al`.
pub const CALL_SET_VIDEO_MODE: u16 = 0x010;

/// `mov [ABI_BASE + 0x020], eax` — request RWX mapping of a page-aligned
/// range. Packing: `eax = addr | (pages - 1)`.
pub const CALL_MMAP_REQUEST: u16 = 0x020;

/// `mov [ABI_BASE + 0x0FE], eax` — terminate the session with `eax` as
/// the exit code. The host returns [`Fault::Exit`] (mov-only equivalent
/// of `mov eax, 1; mov ebx, code; int 0x80`).
pub const CALL_EXIT: u16 = 0x0FE;

/// Returns `true` if `addr` falls inside the ABI page. CPU uses this on
/// every mov-to-memory to decide whether to route through [`AbiHost`]
/// instead of the underlying `Memory`.
#[must_use]
pub const fn is_abi_addr(addr: u32) -> bool {
    addr >= ABI_BASE && addr < ABI_BASE + ABI_PAGE_SIZE
}

/// Unpack [`CALL_MMAP_REQUEST`]'s packed argument.
///
/// Returns `(addr, size_bytes)`.
#[must_use]
pub const fn unpack_mmap_request(packed: u32) -> (u32, u32) {
    let addr = packed & 0xFFFF_F000;
    let pages = (packed & 0xFFF) + 1;
    (addr, pages << 12)
}

/// Host-side dispatcher for guest mov-only ABI calls.
///
/// The default impl traps with [`Fault::UnsupportedAbiCall`] so hosts
/// that don't care about the ABI can write `impl AbiHost for MyHost {}`
/// and get a loud failure on use.
pub trait AbiHost {
    /// Handle a mov-only ABI invocation.
    ///
    /// `call_num` is the offset within the ABI page (`0..ABI_PAGE_SIZE`);
    /// `value` is what the guest wrote (zero-extended from `al` for the
    /// `mov [imm32], al` form, full 32-bit for `mov [imm32], eax`).
    /// `mem` is provided in case the call needs to allocate or read back
    /// guest memory (e.g. `mmap_request` growing the address space).
    ///
    /// # Errors
    /// Faults propagate to the CPU and end the run.
    fn abi_call(&mut self, call_num: u16, _value: u32, _mem: &mut dyn Memory) -> Result<(), Fault> {
        Err(Fault::UnsupportedAbiCall(call_num))
    }
}
