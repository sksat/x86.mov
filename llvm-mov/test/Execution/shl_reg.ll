; Stage-3.5 fixture: variable shift amount (`shl i32, i32`). x86 requires
; the amount in CL; this exercises the CL-constraint plumbing
; (singleton CCR class + CopyToReg in MovISelDAGToDAG).
;
; shl_reg(21, 1) = 42 — same exit code as shl_imm so a regression in
; the constant-shift path is easy to spot side-by-side.

target triple = "mov-unknown-linux-gnu"

define i32 @shl_reg(i32 %x, i32 %n) {
  %r = shl i32 %x, %n
  ret i32 %r
}
