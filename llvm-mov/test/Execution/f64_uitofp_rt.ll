; Stage 7h3 — uitofp + fptoui round-trip. Tests the unsigned
; conversion path. Use a value > INT_MAX to exercise the bit 31 set
; case (sitofp would treat this as negative; uitofp keeps it
; positive).
;
;   3000000000 (= 0xB2D05E00) — fits in u32, not in i32
;   uitofp → 3000000000.0
;   fptoui → 3000000000
;   low byte = 0xB2D05E00 & 0xFF = 0x00

target triple = "mov-unknown-linux-gnu"

define i32 @rt(i32 %i) {
  %d = uitofp i32 %i to double
  %r = fptoui double %d to i32
  ret i32 %r
}
