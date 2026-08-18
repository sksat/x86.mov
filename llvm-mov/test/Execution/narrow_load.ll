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
; narrow_load(0) → 40 (s16 sext) + 1 (i1) + 1 (u16 zext, 0x10000 wraps to
; 1 after the mask) = 42.

target triple = "mov-unknown-linux-gnu"

@s16   = global i16 40                ; signed short, naturally aligned
@u16   = global i16 1                 ; unsigned short
@flag  = global i8 1                  ; a C `_Bool` in disguise
@pad   = global [4 x i16] [i16 0, i16 7, i16 0, i16 0]

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

  %t1 = add i32 %as, %bz
  %t2 = add i32 %t1, %fz
  %t3 = sub i32 %t2, %cz
  %r  = add i32 %t3, 7
  ret i32 %r
}
