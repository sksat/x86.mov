//! Smallest possible body for the deps-mov fixture: one cross-crate
//! function that does an i32 add and returns. `#[inline(never)]`
//! keeps the call edge from being optimised away cross-crate even
//! when rustc gets aggressive about MIR inlining; the dep object
//! must contain a real `triv_add` function for the test to mean
//! anything (otherwise the dep `.o` would be empty and there'd be
//! nothing for llvm-mov-llc to lower).

#![no_std]

#[inline(never)]
pub fn triv_add(a: u32, b: u32) -> u32 {
    a + b
}
