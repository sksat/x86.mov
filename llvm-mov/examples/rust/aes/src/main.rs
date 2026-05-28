//! AES-128 ECB single-block encrypt via the `aes` crate, no_std.
//!
//! Encrypts a fixed plaintext block N times with a fixed key. The
//! return value is the XOR of the resulting ciphertext bytes so the
//! Rust optimiser can't fold the loop into a constant. The exit code
//! depends on N — for the bench we pick something compute-bound.
//!
//! Build constraints (same as the other `examples/rust/*` crates):
//!   - `panic = "abort"`, `overflow-checks = false`
//!   - no_std, no `#[global_allocator]` — the `aes` crate's encrypt
//!     path stays heap-free (everything lives in the GenericArray
//!     value on the stack).
//!
//! Tested entry: `aes_main()` returns the XOR sum modulo 256 of the
//! ciphertext bytes after `N_ROUNDS` encrypts.
//!
//! Current backend status (stage 6d1 — 2026-05):
//!
//!   * `llvm.memset.p0.i32` is inlined (stage 6c —
//!     MaxStoresPerMemset = 64).
//!   * `<16 x i8>` load/store/phi are scalarised pre-codegen by
//!     the LLVM Scalarizer pass (stage 6d1 — driver IRPM in
//!     tools/llvm-mov-llc/main.cpp).
//!   * `llvm.vector.reduce.xor.v16i8` is *not* yet handled cleanly:
//!     LLVM's `expand-reductions` pass rewrites it into a
//!     shufflevector + vector-XOR tree that re-introduces vector
//!     ops after the Scalarizer ran. Stage 6d2 (custom reduction
//!     expander) is required to land it.
//!   * The fundamental missing piece is i8-promote-to-i32: with
//!     i8 left as a non-register-class type, the resulting DAG of
//!     thousands of scalar i8 ops + a vector.reduce tail makes
//!     DAG-ISel either crash (sub_8bit-less GR8 vregs) or balloon
//!     to multi-minute compile times. Stage 6d3 (i8 Custom
//!     lowering — keep GR8 vregs out of MIR entirely) is the
//!     planned fix; see codex review on 825044a + d842da3 for
//!     the rationale.
//!
//! The example is committed so the backend can ship and the
//! blockers stay visible. Use `--example=fib` for a working
//! compute-bound bench fixture in the meantime.

#![no_std]
#![no_main]

#[panic_handler]
fn panic(_: &core::panic::PanicInfo) -> ! { loop {} }

// The `aes::soft::fixslice` code that Cargo pulls in as a precompiled
// rlib references `memset` / `memcpy` from libc. Our standalone
// runtime doesn't link a libc, so provide trivial Rust implementations
// here. They get compiled through llvm-mov-llc the same as the rest
// of the user crate (byte loop + i8 store, both lower fine thanks to
// stage 6d3b).
#[unsafe(no_mangle)]
pub unsafe extern "C" fn memset(dst: *mut u8, c: i32, n: usize) -> *mut u8 {
    let mut i: usize = 0;
    while i < n {
        unsafe { *dst.add(i) = c as u8; }
        i = i + 1;
    }
    dst
}
#[unsafe(no_mangle)]
pub unsafe extern "C" fn memcpy(dst: *mut u8, src: *const u8, n: usize) -> *mut u8 {
    let mut i: usize = 0;
    while i < n {
        unsafe { *dst.add(i) = *src.add(i); }
        i = i + 1;
    }
    dst
}

use aes::Aes128;
use aes::cipher::{BlockEncrypt, KeyInit};
use aes::cipher::generic_array::GenericArray;

const N_ROUNDS: u32 = 256;

#[unsafe(no_mangle)]
pub extern "C" fn aes_main() -> i32 {
    // Fixed 128-bit key + plaintext from the AES known-answer test
    // vectors (NIST AES specification Appendix C.1, AES-128).
    let key = GenericArray::from([
        0x2bu8, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6,
        0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c,
    ]);
    let cipher = Aes128::new(&key);

    let mut block = GenericArray::from([
        0x6bu8, 0xc1, 0xbe, 0xe2, 0x2e, 0x40, 0x9f, 0x96,
        0xe9, 0x3d, 0x7e, 0x11, 0x73, 0x93, 0x17, 0x2a,
    ]);

    // Repeat the encrypt so wall-clock time dominates exec()
    // startup. AES-128 ECB by spec maps every (key, block) to a
    // deterministic output, so feeding the ciphertext back as next
    // round's plaintext walks an effectively random orbit through
    // the state space and prevents the optimiser from collapsing
    // the loop.
    let mut i: u32 = 0;
    while i < N_ROUNDS {
        cipher.encrypt_block(&mut block);
        i = i + 1;
    }

    // Reduce the 16-byte ciphertext to a single i32 the exit code
    // can carry. XOR is fine — every byte's contribution survives.
    let mut acc: u8 = 0;
    let mut j: usize = 0;
    while j < 16 {
        acc = acc ^ block[j];
        j = j + 1;
    }
    acc as i32
}
