; Stage-7d0 PoC fixture — the first function whose SUB32ri lowers to a
; pure mov-only byte-chain rewrite.
;
; `sub i32 %x, 42` is exactly the shape MovOnlyLegalize::legalizeSUB32ri
; handles: a 2-address-tied SUB32ri with a constant immediate. The
; objdump gate (test/MovOnly/run.sh) checks that the disassembly of
; this function contains only mov-family opcodes — plus the three
; non-mov mnemonics still owned by FrameLowering/PEI at this stage
; (push, pop, ret), which are listed in `sub42.expect` until later
; 7d stages legalise them too.

target triple = "mov-unknown-linux-gnu"

define i32 @sub42(i32 %x) {
  %r = sub i32 %x, 42
  ret i32 %r
}
