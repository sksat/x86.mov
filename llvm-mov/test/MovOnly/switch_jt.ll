; Stage 7i / issue #11 — mov-only check for a dense `switch` jump table.
; LLVM forms a jump table (br_jt); MovISelLowering marks BR_JT Expand so
; it becomes `index*4 + jumptable_base → load → brind`. The address
; arithmetic (SHL/ADD) lowers through the stage-7a/7b byte-chain
; legalize, the range-check `Jcc` through the 7c2 dispatcher rewrite,
; and the only non-mov mnemonics that survive are `jmp` — the JMP32r
; jump-table dispatch and the 7c1 dispatcher's `jmp dword ptr [...]`,
; both mov-equivalent indirect jumps (see switch_jt.expect).

target triple = "mov-unknown-linux-gnu"

define i32 @switch_jt(i32 %x) {
entry:
  switch i32 %x, label %default [
    i32 0, label %c0
    i32 1, label %c1
    i32 2, label %c2
    i32 3, label %c3
    i32 4, label %c4
  ]
c0:
  ret i32 10
c1:
  ret i32 11
c2:
  ret i32 20
c3:
  ret i32 30
c4:
  ret i32 40
default:
  ret i32 99
}
