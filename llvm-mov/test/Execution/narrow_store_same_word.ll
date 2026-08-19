; Stage-6f fixture: two *independent* narrow stores into one 4-byte word.
;
; This is the shape the old word-read-modify-write lowering could not get
; right, and the reason `store i16` was declined outright for a while.
;
; `store i24` splits into disjoint byte ranges, so the IR chains nothing —
; the pieces are genuinely independent. Rewriting each into a whole-word RMW
; made them overlap after the fact, and with nothing ordering them one RMW
; read the word before its neighbour's store and wrote back over it. The
; third byte came back as zero (measured against a native i386 build with
; `llvm-reduce`); the emitted MIR showed the interleave:
;
;     %29 = MOV32rm %28, 0     ; RMW #3 reads the word
;     MOV32mr %17, 0, %22      ; RMW #2 writes it
;     MOV32mr %28, 0, %33      ; RMW #3 writes back its stale copy
;
; A real byte store has no such hazard: there is nothing to read, so two of
; them into one word cannot lose each other's update regardless of order.
;
; The unrelated load from a second global is not decoration — it was what
; perturbed scheduling enough to expose the race.
;
; narrow_store_same_word(0) → 3 + 2 + 1 + 0 + 36 = 42.

target triple = "mov-unknown-linux-gnu"

@other = global [2 x i16] zeroinitializer
@word  = global [2 x i32] zeroinitializer, align 4

define i32 @narrow_store_same_word(i32 %n) {
entry:
  ; three bytes into one word, as one i24 store: 0x010203
  store i24 66051, ptr @word, align 4

  %b0 = load i8, ptr @word, align 1
  %p1 = getelementptr inbounds i8, ptr @word, i32 1
  %p2 = getelementptr inbounds i8, ptr @word, i32 2
  %p3 = getelementptr inbounds i8, ptr @word, i32 3
  %b1 = load i8, ptr %p1, align 1
  %b2 = load i8, ptr %p2, align 1
  %b3 = load i8, ptr %p3, align 1

  ; the load that perturbs scheduling
  %q1 = getelementptr inbounds i8, ptr @other, i32 1
  %o1 = load i8, ptr %q1, align 1

  %z0 = zext i8 %b0 to i32                 ; 0x03
  %z1 = zext i8 %b1 to i32                 ; 0x02
  %z2 = zext i8 %b2 to i32                 ; 0x01  ← the byte that went missing
  %z3 = zext i8 %b3 to i32                 ; 0x00, untouched
  %zo = zext i8 %o1 to i32                 ; 0x00, never written

  %s0 = add i32 %z0, %z1
  %s1 = add i32 %s0, %z2
  %s2 = add i32 %s1, %z3
  %s3 = add i32 %s2, %zo
  %r  = add i32 %s3, 36
  ret i32 %r
}
