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
//! Current backend status (stage 6c — 2026-05): the example builds
//! cleanly through `cargo rustc --emit=llvm-ir` but `llvm-mov-llc`
//! does NOT yet lower it to assembly. Two outstanding blockers
//! visible in `aes_main`'s IR at opt-level=3:
//!
//!   1. **SIMD vector types.** rustc emits `<16 x i8>` for the
//!      block constants (`store <16 x i8>`, `phi <16 x i8>`,
//!      `load <16 x i8>`) and a `llvm.vector.reduce.xor.v16i8`
//!      intrinsic for the final XOR reduction. The Mov backend
//!      only registers i32 (+ i8 for narrow memory at stage 6c).
//!      The type legalizer hits "Don't know how to split the
//!      result of this operator" trying to lower the v16i8 ops.
//!
//!   2. **`llvm.memset.p0.i32` intrinsic.** Lowering needs either
//!      a libcall to `memset` (we don't link libc) or an inline
//!      byte-write loop expansion.
//!
//! The example is committed so the backend can ship and the
//! blockers stay visible for the next stage. Use `--example=fib`
//! for a working compute-bound bench fixture in the meantime.

#![no_std]

#[panic_handler]
fn panic(_: &core::panic::PanicInfo) -> ! { loop {} }

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
