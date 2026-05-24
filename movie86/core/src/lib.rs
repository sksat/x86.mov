#![no_std]

extern crate alloc;

pub mod mem;

pub use mem::{FlatMemory, Memory};

/// Reasons emulation can stop in a way the caller needs to handle.
///
/// Kept narrow on purpose — each variant should correspond to a distinct
/// recovery path. Don't add a variant unless a caller wants to branch on it.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Fault {
    /// Memory access to an address not covered by any mapped region.
    Unmapped(u32),
}
