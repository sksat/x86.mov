; Stage-6f fixture: i16 and i1 ext-loads.
;
; i8 has had a Custom lowering since 6d3b (aligned-down i32 load + shift +
; mask); i16 and i1 were left on Expand with the note "rare in Rust IR,
; and adding the same Custom path is mechanical when the time comes".
; Real C says otherwise: `short` fields and `_Bool` globals are ordinary,
; and 11 of lcc's 32 translation units fail on exactly this. Two different
; symptoms, one gap — some shapes stop with `Cannot select`, others send
; the legalizer into a spin (an `Expand`ed i16 SEXTLOAD whose result feeds
; a `sext i16 to i32` has no terminating rewrite).
;
; `@s16` is **negative** on purpose: with a positive value a broken
; sign-extension would zero-extend to the same 32-bit result and the test
; would pass anyway.
;
; narrow_load(0) → sext(@s16) + zext(@u16) + zext(@flag) − zext(@pad[1])
;                  + zext(unaligned i16 at @odd+1) + 46
;                = (−8) + 1 + 1 − 7 + 9 + 46 = 42.
; The `− @pad[1] + 55` pair is there to make the GEP-offset i16 load
; observable in the result: get that load wrong and the answer moves.

target triple = "mov-unknown-linux-gnu"

@s16   = global i16 -8                ; signed short — negative, so sext ≠ zext
@u16   = global i16 1                 ; unsigned short
@flag  = global i8 1                  ; a C `_Bool` in disguise
@pad   = global [4 x i16] [i16 0, i16 7, i16 0, i16 0]
@odd   = global [4 x i8]  [i8 0, i8 9, i8 0, i8 0]   ; i16 at offset 1 = 9

define i32 @narrow_load(i32 %n) {
entry:
  ; sign-extending i16 load
  %a = load i16, ptr @s16, align 2
  %as = sext i16 %a to i32

  ; zero-extending i16 load
  %b = load i16, ptr @u16, align 2
  %bz = zext i16 %b to i32

  ; i1 load out of a byte-sized global (what `load i1` from a `bool`
  ; global lowers to — memory VT i1, anyext to i32)
  %f8 = load i8, ptr @flag, align 1
  %f1 = trunc i8 %f8 to i1
  %fz = zext i1 %f1 to i32

  ; i16 load at a non-zero, still 2-aligned offset inside an array —
  ; exercises the shift path rather than the offset-0 fast case
  %g  = getelementptr inbounds i16, ptr @pad, i32 1
  %c  = load i16, ptr %g, align 2
  %cz = zext i16 %c to i32

  ; under-aligned i16: the two bytes may sit in different 4-byte words, so
  ; this takes the split-into-two-byte-loads path rather than one word read
  %u  = getelementptr inbounds i8, ptr @odd, i32 1
  %uv = load i16, ptr %u, align 1
  %uz = zext i16 %uv to i32

  %t1 = add i32 %as, %bz
  %t2 = add i32 %t1, %fz
  %t3 = sub i32 %t2, %cz
  %t4 = add i32 %t3, %uz
  %r  = add i32 %t4, 46
  ret i32 %r
}
