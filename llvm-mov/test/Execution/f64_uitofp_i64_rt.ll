; Stage 7h9 — uitofp u64→f64 + fptoui f64→u64 round-trip via
; __floatundidf + __fixunsdfdi. Use a value > INT64_MAX (bit 63 set
; in unsigned interpretation) to exercise the unsigned path: u64
; high half = 0x80000000 (= bit 63), low half = 0. Value is 2^63;
; exactly representable in f64.
;
;   2^63 = 0x8000000000000000 → low byte 0

target triple = "mov-unknown-linux-gnu"

define i32 @rt(i64 %v) {
  %d = uitofp i64 %v to double
  %r = fptoui double %d to i64
  %lo = trunc i64 %r to i32
  %x = and i32 %lo, 255
  ret i32 %x
}
