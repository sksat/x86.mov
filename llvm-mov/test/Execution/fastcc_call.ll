; Stage-6f fixture: `fastcc` calls.
;
; This is not an exotic IR shape — clang at -O1 and above rewrites every
; `internal` function it can prove has no address-taken uses to `fastcc`
; (GlobalOpt's calling-convention promotion). So the *first* real C file
; compiled with optimisation hits it: 14 of the calls in lcc's `tree.c`
; are fastcc. Rejecting it made "compile real C with -O1" impossible.
;
; The Mov backend has exactly one argument-passing table (CC_Mov, all
; stack, caller-cleaned), and both the caller and the callee of a fastcc
; call go through it, so accepting fastcc is purely a matter of not
; rejecting it — there is no second ABI to implement.
;
; caller(20) → double_it(20) + 2 → 42.

target triple = "mov-unknown-linux-gnu"

define internal fastcc i32 @double_it(i32 %x) {
  %r = add i32 %x, %x
  ret i32 %r
}

define i32 @caller(i32 %x) {
  %d = call fastcc i32 @double_it(i32 %x)
  %r = add i32 %d, 2
  ret i32 %r
}
