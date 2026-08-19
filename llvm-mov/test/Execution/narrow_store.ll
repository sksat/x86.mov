; Stage-6f fixture: truncating stores whose memory type is i16.
;
; Before this landed, *any* store that reached LegalizeDAG with a memory VT of
; i16 hung the compiler and allocated until the machine ran out — not a big
; peak, an unbounded one: peak RSS tracked whatever RAM you granted and wall
; time was linear in it. A four-line module was enough:
;
;   define void @f(ptr %p, i24 %v) { store i24 %v, ptr %p, align 1  ret void }
;
; i16 is not a legal type here (i32 is the only register class), and
; `setTruncStoreAction(MVT::i32, MVT::i16, Expand)` sent LegalizeDAG down the
; "in-memory type isn't legal" arm, which truncates the value to the promote
; type (i32 — a no-op here) and rebuilds a truncstore with the *same* memory
; VT. CSE hands back the very node being legalized, `ReplaceNode(N, N)` drops
; it from the legalized set, and the worklist loop starts over. Same family as
; the `SELECT` ↔ `SELECT_CC` cycle and the i16 SEXTLOAD one: an `Expand`
; action that reproduces its own input.
;
; The trigger is the memory VT after legalization, not anything visible in the
; IR — `store i24` and `store i48` split into a 16-bit piece, and two adjacent
; `store i8`s get merged into one by DAGCombine. So the fixture pins several
; shapes rather than one spelling.
;
; Every value below has a **non-zero high byte**, and one store is placed so
; its two bytes land in *different* 4-byte words (`ptr & 3 == 3`). Both matter:
; the lowering splits an i16 into two byte stores, each of which becomes a
; read-modify-write of its enclosing word, so a fixture with a zero high byte
; or without a word crossing would still pass if the high half were dropped.
; The bytes either side of the crossing store are read back as sentinels — a
; read-modify-write that wrote back a stale word would disturb them.
;
; narrow_store(0) → 3 + 7 + 6 + 11 + 15 = 42.

target triple = "mov-unknown-linux-gnu"

@al16  = global [2 x i16] [i16 0, i16 0]                       ; 2-aligned i16
@cross = global [8 x i8]  [i8 0, i8 0, i8 0, i8 0,
                           i8 0, i8 0, i8 0, i8 0]             ; store at +3
@b24   = global [2 x i32] [i32 0, i32 0]
@pair  = global [4 x i8]  [i8 0, i8 0, i8 0, i8 0]

define i32 @narrow_store(i32 %n) {
entry:
  ; (1) plain 2-aligned i16, high byte non-zero: 0x0102
  store i16 258, ptr @al16, align 2
  %a0 = load i8, ptr @al16, align 1
  %a1p = getelementptr inbounds i8, ptr @al16, i32 1
  %a1 = load i8, ptr %a1p, align 1
  %a0z = zext i8 %a0 to i32                                    ; 0x02
  %a1z = zext i8 %a1 to i32                                    ; 0x01
  %a = add i32 %a0z, %a1z                                      ; 3

  ; (2) align-1 i16 at offset 3 — the two bytes land in different words
  %cp = getelementptr inbounds i8, ptr @cross, i32 3
  store i16 772, ptr %cp, align 1                              ; 0x0304
  %s2p = getelementptr inbounds i8, ptr @cross, i32 2
  %s5p = getelementptr inbounds i8, ptr @cross, i32 5
  %c4p = getelementptr inbounds i8, ptr @cross, i32 4
  %s2 = load i8, ptr %s2p, align 1                             ; sentinel, 0
  %c3 = load i8, ptr %cp,   align 1                            ; 0x04
  %c4 = load i8, ptr %c4p,  align 1                            ; 0x03
  %s5 = load i8, ptr %s5p,  align 1                            ; sentinel, 0
  %s2z = zext i8 %s2 to i32
  %c3z = zext i8 %c3 to i32
  %c4z = zext i8 %c4 to i32
  %s5z = zext i8 %s5 to i32
  %b0 = add i32 %s2z, %c3z
  %b1 = add i32 %b0, %c4z
  %b  = add i32 %b1, %s5z                                      ; 7

  ; (3) i24 — legalizes into a 16-bit piece plus a byte: 0x010203
  store i24 66051, ptr @b24, align 4
  %d0 = load i8, ptr @b24, align 1
  %d1p = getelementptr inbounds i8, ptr @b24, i32 1
  %d2p = getelementptr inbounds i8, ptr @b24, i32 2
  %d1 = load i8, ptr %d1p, align 1
  %d2 = load i8, ptr %d2p, align 1
  %d0z = zext i8 %d0 to i32                                    ; 0x03
  %d1z = zext i8 %d1 to i32                                    ; 0x02
  %d2z = zext i8 %d2 to i32                                    ; 0x01
  %e0 = add i32 %d0z, %d1z
  %d  = add i32 %e0, %d2z                                      ; 6

  ; (4) two adjacent i8 stores — DAGCombine merges these into one 16-bit
  ; truncating store, which is why an IR-level grep can't find the trigger
  store i8 5, ptr @pair, align 1
  %p1 = getelementptr inbounds i8, ptr @pair, i32 1
  store i8 6, ptr %p1, align 1
  %f0 = load i8, ptr @pair, align 1
  %f1 = load i8, ptr %p1, align 1
  %f0z = zext i8 %f0 to i32
  %f1z = zext i8 %f1 to i32
  %f  = add i32 %f0z, %f1z                                     ; 11

  %t0 = add i32 %a, %b
  %t1 = add i32 %t0, %d
  %t2 = add i32 %t1, %f
  %r  = add i32 %t2, 15
  ret i32 %r
}
