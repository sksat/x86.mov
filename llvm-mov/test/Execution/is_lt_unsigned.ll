; Stage-5c fixture: codex's stage-5 design note flagged that one unsigned
; predicate fixture is worth keeping to catch JB/JA-vs-JL/JG mapping
; mistakes early. `icmp ult i32 %x, 100` → JB.
;
; Caller passes 0xFFFFFFFE (= -2 signed, = 4294967294 unsigned). Under
; signed comparison that's less than 100 — under unsigned it's WAY
; greater. The expected exit code 0 (false branch) catches the bug if
; we ever conflate signed/unsigned.

target triple = "mov-unknown-linux-gnu"

define i32 @lt_unsigned(i32 %x) {
  %c = icmp ult i32 %x, 100
  br i1 %c, label %lt, label %ge
lt:
  ret i32 1
ge:
  ret i32 0
}
