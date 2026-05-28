; Stage-6c+ indirect-call fixture (PR follow-up to #6).
;
; caller(x) loads a function pointer from a global slot, then calls it
; with x. The callee adds 25 and returns. With x = 17 this exits 42.
;
; The volatile load defeats any constant-folding of the global into a
; direct call — SDAG sees an indirect Callee (the load result, not a
; GlobalAddress), which today trips
;   `report_fatal_error("indirect calls not yet supported")`
; in MovISelLowering::LowerCall. This fixture flips green when CALL32r
; lands.

target triple = "mov-unknown-linux-gnu"

define internal i32 @add25(i32 %x) {
  %r = add i32 %x, 25
  ret i32 %r
}

@indirect_target = global ptr @add25

define i32 @caller(i32 %x) {
  %fp = load volatile ptr, ptr @indirect_target
  %r = call i32 %fp(i32 %x)
  ret i32 %r
}
