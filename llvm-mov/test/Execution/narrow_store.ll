; Stage-6f fixture: truncating stores of i8.
;
; This path (stage 6d3b) had **no test at all** — `grep -rl "store i8" test/`
; was empty before this file — which is how it kept a live machine-verifier
; error (`MOV32mr $ebp, -20, $edx` using an undefined physical register) and
; the soundness problem described below.
;
; Each store here goes to a *different* 4-byte word. That restriction is the
; point: the lowering turns a narrow store into a read-modify-write of the
; enclosing word, and two such RMWs in one word are only correct if something
; orders them. Nothing does — see the `MVT::i16` decline in
; `MovISelLowering.cpp` for the measured failure and why it cannot be fixed
; from inside that hook. Until narrow stores become real byte stores, one
; narrow store per word is the sound subset, and this fixture stays inside it.
;
; i16 / i24 stores are declined outright (`Cannot select`), which is a
; deliberate step *up* from what they used to do: `Expand` on an i16
; truncstore did not terminate, and the compiler allocated until the machine
; died. Terminating with a diagnostic is the improvement; a correct lowering
; is separate work.
;
; narrow_store(0) → 7 + 20 + 15 = 42.

target triple = "mov-unknown-linux-gnu"

@w0 = global [4 x i8] [i8 0, i8 0, i8 0, i8 0]
@w1 = global [4 x i8] [i8 0, i8 0, i8 0, i8 0]
@w2 = global [4 x i8] [i8 9, i8 9, i8 9, i8 9]

define i32 @narrow_store(i32 %n) {
entry:
  ; byte at offset 0 of its word
  store i8 7, ptr @w0, align 1
  %a = load i8, ptr @w0, align 1
  %az = zext i8 %a to i32                       ; 7

  ; byte at offset 2 of a different word — exercises the shift path, and
  ; the neighbours must survive the read-modify-write
  %p2 = getelementptr inbounds i8, ptr @w1, i32 2
  store i8 20, ptr %p2, align 1
  %b = load i8, ptr %p2, align 1
  %bz = zext i8 %b to i32                       ; 20
  %n0 = load i8, ptr @w1, align 1
  %n0z = zext i8 %n0 to i32                     ; 0, untouched
  %p3 = getelementptr inbounds i8, ptr @w1, i32 3
  %n3 = load i8, ptr %p3, align 1
  %n3z = zext i8 %n3 to i32                     ; 0, untouched

  ; a word that starts non-zero: the RMW must preserve the other three bytes
  %q1 = getelementptr inbounds i8, ptr @w2, i32 1
  store i8 0, ptr %q1, align 1
  %c0 = load i8, ptr @w2, align 1
  %c1 = load i8, ptr %q1, align 1
  %c0z = zext i8 %c0 to i32                     ; 9, preserved
  %c1z = zext i8 %c1 to i32                     ; 0, just written

  %s0 = add i32 %az, %bz
  %s1 = add i32 %s0, %n0z
  %s2 = add i32 %s1, %n3z
  %s3 = add i32 %s2, %c0z
  %s4 = add i32 %s3, %c1z
  %r  = add i32 %s4, 6
  ret i32 %r
}
