; Stage-7a1 PoC fixture — the first function whose ADD lowers to a
; pure mov-only byte-chain rewrite.
;
; `add i32 %x, 42` is exactly the shape MovOnlyLegalize::legalizeADD32ri
; handles: a 2-address-tied ADD32ri with a constant immediate. The
; objdump gate (test/MovOnly/run.sh) checks that the disassembly of
; this function contains only mov-family opcodes — plus the four
; non-mov mnemonics still owned by FrameLowering/PEI (push, pop, sub,
; ret), which are listed in `add42.expect` until stage 7d legalises
; them too.

target triple = "mov-unknown-linux-gnu"

define i32 @add42(i32 %x) {
  %r = add i32 %x, 42
  ret i32 %r
}
