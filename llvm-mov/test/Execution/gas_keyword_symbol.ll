; Stage-6f fixture: globals whose names are GAS Intel-syntax reserved words.
;
; `MOV32ri` prints its operand as `mov $dst, offset $src`, because in Intel
; syntax a bare `mov reg, sym` means *load from* sym. That is correct until
; the symbol is itself one of GAS's Intel-syntax reserved words, at which
; point `mov esi, offset offset` is rejected with `invalid expression` —
; the parser reads the second `offset` as the operator again.
;
; The colliding set, measured against binutils 2.47, is
;
;   offset mod short flat st and or not xor shl shr
;
; and several of those are perfectly ordinary C identifiers. lcc's
; `bytecode.c` has a global called `offset`, which is how this surfaced.
;
; The keywords are also **case-insensitive** — `OFFSET`, `Offset` and
; `oFFsEt` collide exactly as `offset` does — so the fixture pins a
; capitalised one too.
;
; gas_keyword_symbol(0) → 40 + 2 + 0 = 42.

target triple = "mov-unknown-linux-gnu"

@offset = global i32 40
@and    = global i32 2
@Flat   = global i32 0        ; capitalised: same keyword, different spelling

define i32 @gas_keyword_symbol(i32 %n) {
entry:
  %a = load i32, ptr @offset, align 4
  %b = load i32, ptr @and, align 4
  %c = load i32, ptr @Flat, align 4
  %s = add i32 %a, %b
  %r = add i32 %s, %c
  ret i32 %r
}
