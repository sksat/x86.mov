# cycle — print "1 2 3 4 5" forever via five `call`s + `jmp _start`.
#
# Each `pN` function writes a 2-byte slice of the shared `msg` string
# (`"1 ".."5 "`) and `ret`s. `_start` calls them in sequence, then
# unconditionally jumps back to the top — there's no termination
# (Step / Run with the Stop button is how the demo halts it).
#
# Exercises call/ret repeatedly in a tight loop, which is the dominant
# control-flow shape in real movfuscator output.
.intel_syntax noprefix
.text
.global _start
_start:
    call p1
    call p2
    call p3
    call p4
    call p5
    jmp _start

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
