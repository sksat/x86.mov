# cycle — print "1 2 3 4 5" forever via five `call`s + `jmp _start`.
#
# Each `pN` function writes a 2-byte slice of the shared `msg` string
# (`"1 ".."5 "`) and `ret`s. `_start` calls them in sequence, then
# unconditionally jumps back to the top — there's no termination
# (Step / Run with the Stop button is how the demo halts it).
#
# Exercises call/ret repeatedly in a tight loop, which is the dominant
# control-flow shape in real movfuscator output.
#
# JMP-encoding note: gas in Intel syntax assembles `jmp _start` to
# the 2-byte short form `EB rel8` when the target is in range
# (always, for a backward jump from the bottom of this file). The
# movie86 decoder only knows the 5-byte `E9 rel32` form (see
# `core/src/decode.rs` — `Insn::JmpRel32`), so a short jmp would
# UnknownOpcode at runtime. Encode it by hand as `E9` + a 32-bit
# relative offset. `. + 4` is the address of the byte after the
# offset field, which is the rel32-relative origin (Intel SDM
# Vol. 2A Table 3-32).
.intel_syntax noprefix
.text
.global _start
_start:
    call p1
    call p2
    call p3
    call p4
    call p5
    .byte 0xE9              # jmp rel32 _start (forced 5-byte form)
    .long _start - (. + 4)

# write(1, msg+offset, 2); ret
.macro PRINT off
    mov edx, 2
    mov ecx, OFFSET msg + \off
    mov ebx, 1
    mov eax, 4
    int 0x80
    ret
.endm

p1: PRINT 0
p2: PRINT 2
p3: PRINT 4
p4: PRINT 6
p5: PRINT 8

msg:
    .ascii "1 2 3 4 5\n"
