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
; `store i8`s get merged into one by DAGCombine. So the fixture pins the
; observable behaviour of several shapes rather than one spelling.
;
; narrow_store(0) → 0x2A written and read back through three routes = 42.

target triple = "mov-unknown-linux-gnu"

@buf16 = global [4 x i16] [i16 0, i16 0, i16 0, i16 0]
@buf24 = global [2 x i32] [i32 0, i32 0]
@pair  = global [4 x i8]  [i8 0, i8 0, i8 0, i8 0]

define i32 @narrow_store(i32 %n) {
entry:
  ; plain i16 truncating store, then read back
  %p16 = getelementptr inbounds i16, ptr @buf16, i32 1
  store i16 20, ptr %p16, align 2
  %a16 = load i16, ptr %p16, align 2
  %a   = zext i16 %a16 to i32

  ; i24: legalizes into a 16-bit piece plus a byte
  store i24 20, ptr @buf24, align 4
  %b24 = load i8, ptr @buf24, align 1
  %b   = zext i8 %b24 to i32

  ; two adjacent i8 stores — DAGCombine merges these into one 16-bit
  ; truncating store, which is why an IR-level grep can't find the trigger
  store i8 1, ptr @pair, align 1
  %p1 = getelementptr inbounds i8, ptr @pair, i32 1
  store i8 1, ptr %p1, align 1
  %c0 = load i8, ptr @pair, align 1
  %c1 = load i8, ptr %p1, align 1
  %c0z = zext i8 %c0 to i32
  %c1z = zext i8 %c1 to i32
  %c  = add i32 %c0z, %c1z

  %s = add i32 %a, %b
  %r = add i32 %s, %c
  ret i32 %r
}
