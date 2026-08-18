; Stage-6f fixture: `select` on **pointer** operands.
;
; The driver rewrites i32 (and helper-safe i64) SELECTs into a branchless
; bit-blend precisely because the default SDAG Expand path ping-pongs
; between ISD::SELECT and ISD::SELECT_CC forever with this target's action
; table. Pointer-typed selects were left on that default path — and a
; pointer is exactly what C code selects most often. Half of lcc's
; translation units hang the compiler on this shape (see `GAP-MATRIX.md`);
; the reduced case was
;
;   %c = icmp sgt i32 %n, 0
;   %g = getelementptr i8, ptr %p, i32 %n
;   %s = select i1 %c, ptr %g, ptr %p
;
; This fixture pins both the plain-global and the GEP-arm forms. Without
; the rewrite it does not fail — it never terminates.
;
; ptr_select(3) → buf[3] + (x + y) = 30 + (10 + 2) = 42.

target triple = "mov-unknown-linux-gnu"

@x   = global i32 10
@y   = global i32 2
@buf = global [4 x i32] [i32 0, i32 0, i32 0, i32 30]

define i32 @ptr_select(i32 %n) {
entry:
  %c = icmp sgt i32 %n, 0

  ; both arms are plain globals
  %p = select i1 %c, ptr @x, ptr @y
  %q = select i1 %c, ptr @y, ptr @x
  %a = load i32, ptr %p, align 4
  %b = load i32, ptr %q, align 4
  %ab = add i32 %a, %b

  ; one arm is a GEP off a runtime index — the shape llvm-reduce landed on
  %g = getelementptr inbounds i32, ptr @buf, i32 %n
  %r = select i1 %c, ptr %g, ptr @buf
  %v = load i32, ptr %r, align 4

  %sum = add i32 %ab, %v
  ret i32 %sum
}
