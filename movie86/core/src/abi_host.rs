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

use alloc::collections::VecDeque;

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

/// `mov [ABI_BASE + 0x080], eax` — write a buffer to a host file
/// descriptor. Arguments live in the GPR file (matching the int 0x80
/// `SYS_write` ABI byte-for-byte so the only change for guests is the
/// final mov):
///
/// - `ebx` = fd (1 = stdout, 2 = stderr)
/// - `ecx` = buf address
/// - `edx` = length in bytes
///
/// The handler may set `eax` to the number of bytes written / errno-
/// style negative on failure (same convention as the Linux `write(2)`
/// syscall). Hosts that don't write back to eax leave the guest's
/// trigger value in place.
pub const CALL_WRITE: u16 = 0x080;

/// `mov [ABI_BASE + 0x040], al` — poll for one pending input event.
///
/// This is the only *input* call: the guest triggers it like any other
/// (a `mov` into the page; the written value is ignored), and the host
/// pops one generic key code off its [`InputQueue`] and returns it in
/// `eax` (zero-extended), exactly the way [`CALL_WRITE`] returns its
/// byte count. An empty queue yields [`KEY_NONE`] (`0`), so a guest can
/// busy-poll each frame without blocking the engine's step loop.
///
/// The encoding is deliberately *generic* — movie86 is a general mov
/// emulator, not a slideshow player — so a guest sees raw key codes,
/// not application verbs. Higher layers (e.g. `simd`) map `KEY_RIGHT` →
/// "next slide" themselves. Printable keys pass through as their ASCII
/// byte; non-printable keys use the [`KEY_LEFT`]..[`KEY_END`] block.
pub const CALL_POLL_INPUT: u16 = 0x040;

/// `mov [ABI_BASE + 0x0FE], eax` — terminate the session with `eax` as
/// the exit code. The host returns [`Fault::Exit`] (mov-only equivalent
/// of `mov eax, 1; mov ebx, code; int 0x80`).
pub const CALL_EXIT: u16 = 0x0FE;

// ---------------------------------------------------------------------
// Generic input key codes (the [`CALL_POLL_INPUT`] alphabet).
//
// These are part of the cross-engine contract: turbo86 enqueues the
// same byte for the same physical key so a guest behaves identically
// under both engines. Printable keys (Space, letters, digits, …) are
// delivered as their ASCII byte (`0x20..=0x7E`) and need no constant;
// the named constants below cover the control + navigation keys a
// guest can't spell as a printable character.
// ---------------------------------------------------------------------

/// No event pending — [`InputQueue::pop`] returns this when empty, and
/// [`CALL_POLL_INPUT`] hands it back in `eax` so the guest can tell
/// "nothing happened" from a real key without a separate flag.
pub const KEY_NONE: u8 = 0x00;

/// Backspace (ASCII BS).
pub const KEY_BACKSPACE: u8 = 0x08;
/// Enter / Return (ASCII CR).
pub const KEY_ENTER: u8 = 0x0D;
/// Escape (ASCII ESC).
pub const KEY_ESC: u8 = 0x1B;
/// Space bar (ASCII space) — named for symmetry; equals `b' '`.
pub const KEY_SPACE: u8 = 0x20;

// Non-printable navigation keys live in a `0x80+` block so they never
// collide with a printable ASCII byte passed through verbatim.
/// Left arrow.
pub const KEY_LEFT: u8 = 0x80;
/// Right arrow.
pub const KEY_RIGHT: u8 = 0x81;
/// Up arrow.
pub const KEY_UP: u8 = 0x82;
/// Down arrow.
pub const KEY_DOWN: u8 = 0x83;
/// Page Up.
pub const KEY_PAGE_UP: u8 = 0x84;
/// Page Down.
pub const KEY_PAGE_DOWN: u8 = 0x85;
/// Home.
pub const KEY_HOME: u8 = 0x86;
/// End.
pub const KEY_END: u8 = 0x87;

/// FIFO of pending input key codes feeding [`CALL_POLL_INPUT`].
///
/// A host (the wasm `WasmHost`, the CLI test host, …) owns one of these
/// and `push`es a code on every keydown; the guest drains it one event
/// per poll. Edge events, not level state: each physical keypress is
/// exactly one entry, so a guest that polls many times per frame can't
/// accidentally act on the same press twice (the bug the slide layer
/// would otherwise hit — one tap skipping a dozen slides).
#[derive(Debug, Default, Clone)]
pub struct InputQueue {
    events: VecDeque<u8>,
}

impl InputQueue {
    /// A new, empty queue.
    #[must_use]
    pub fn new() -> Self {
        Self::default()
    }

    /// Enqueue one key code (the host's keydown handler calls this).
    pub fn push(&mut self, code: u8) {
        self.events.push_back(code);
    }

    /// Pop the oldest pending key code, or [`KEY_NONE`] if empty.
    pub fn pop(&mut self) -> u8 {
        self.events.pop_front().unwrap_or(KEY_NONE)
    }

    /// `true` when no events are pending.
    #[must_use]
    pub fn is_empty(&self) -> bool {
        self.events.is_empty()
    }
}

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
    /// - `call_num` — offset within the ABI page (`0..ABI_PAGE_SIZE`).
    /// - `value` — what the guest wrote (zero-extended from `al` for the
    ///   `mov [imm32], al` form, full 32-bit for `mov [imm32], eax`).
    /// - `regs` — mutable view of the eight i386 GPRs indexed by
    ///   [`crate::insn::Reg32`]. Calls like [`CALL_WRITE`] read args
    ///   from `ebx` / `ecx` / `edx` and can return a value by writing
    ///   `eax`. Calls like [`CALL_SET_VIDEO_MODE`] / [`CALL_EXIT`] /
    ///   [`CALL_MMAP_REQUEST`] don't touch it.
    /// - `mem` — guest memory; calls like [`CALL_WRITE`] read from it
    ///   (the buffer) and [`CALL_MMAP_REQUEST`] can grow it.
    ///
    /// # Errors
    /// Faults propagate to the CPU and end the run.
    fn abi_call(
        &mut self,
        call_num: u16,
        _value: u32,
        _regs: &mut [u32; 8],
        _mem: &mut dyn Memory,
    ) -> Result<(), Fault> {
        Err(Fault::UnsupportedAbiCall(call_num))
    }
}

#[cfg(test)]
mod tests {
    use super::{InputQueue, KEY_NONE, KEY_RIGHT};

    #[test]
    fn input_queue_is_fifo_and_returns_none_when_empty() {
        let mut q = InputQueue::new();
        assert_eq!(q.pop(), KEY_NONE, "empty queue yields KEY_NONE");

        q.push(KEY_RIGHT);
        q.push(b'a');
        assert_eq!(q.pop(), KEY_RIGHT, "first in, first out");
        assert_eq!(q.pop(), b'a');
        assert_eq!(q.pop(), KEY_NONE, "drained queue yields KEY_NONE again");
    }
}
