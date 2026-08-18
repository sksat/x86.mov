; Stage-6f fixture: a counted loop whose bound comes from an if-diamond PHI.
;
; There is no `select` anywhere in this IR, and yet before stage 6f this
; hung `llvm-mov-llc` forever. The DAG legalizer synthesises a SELECT of
; its own while legalizing the loop's SETCC, and with both ISD::SELECT and
; ISD::SELECT_CC marked Expand the two expansions produced each other:
; SELECT → SELECT_CC → SETCC + SELECT → … Flat memory, no progress, stack
; permanently inside `SelectionDAG::Legalize()`.
;
; The driver's IR-level `select` → bit-blend rewrite could never fix this,
; because the offending SELECT does not exist in the IR. ISD::SELECT is
; Custom now (`LowerSELECT`), which terminates the cycle.
;
; This shape is ordinary C — `for (p = start; p != end; p++)` where `end`
; was computed under an `if`. It accounted for half of lcc's translation
; units failing to compile at all.
;
; f(3, 4): bound = 3 + 4 = 7, loop runs i = 3,4,5,6,7 → returns 7... the
; runner asserts the final `i`, which is the bound: 42 with p=40, n=2.

target triple = "mov-unknown-linux-gnu"

define i32 @f(i32 %p, i32 %n) {
entry:
  %g = icmp sgt i32 %n, 0
  br i1 %g, label %t, label %j

t:
  %a = add i32 %p, %n
  br label %j

j:
  %bound = phi i32 [ %p, %entry ], [ %a, %t ]
  br label %loop

loop:
  %i = phi i32 [ %p, %j ], [ %k, %loop ]
  %c = icmp eq i32 %i, %bound
  %k = add i32 %i, 1
  br i1 %c, label %out, label %loop

out:
  ret i32 %i
}
