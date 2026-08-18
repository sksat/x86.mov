; Stage-6f fixture: i386 SysV varargs — definition side (`va_start`) and
; call side (a call through a `(i32, ...)` function type).
;
; i386 SysV `va_list` is just a `char *` pointing at the first unnamed
; argument's stack slot, so `va_start` is a single store of that address
; and `va_arg` is a load + pointer bump — clang expands the latter in the
; front end, which is why this fixture reads the slots by hand instead of
; using the `va_arg` instruction (that is the IR shape a real C source
; produces; see the survey in `linux-mov/LLVM-MOV-GAP.md`).
;
; caller(12) → vsum3(3, 10, 12, 20) → 42.

target triple = "mov-unknown-linux-gnu"

declare void @llvm.va_start.p0(ptr)
declare void @llvm.va_end.p0(ptr)

define internal i32 @vsum3(i32 %n, ...) {
entry:
  %ap = alloca ptr, align 4
  call void @llvm.va_start.p0(ptr %ap)
  %p0 = load ptr, ptr %ap, align 4
  %v0 = load i32, ptr %p0, align 4
  %p1 = getelementptr inbounds i8, ptr %p0, i32 4
  %v1 = load i32, ptr %p1, align 4
  %p2 = getelementptr inbounds i8, ptr %p1, i32 4
  %v2 = load i32, ptr %p2, align 4
  %p3 = getelementptr inbounds i8, ptr %p2, i32 4
  store ptr %p3, ptr %ap, align 4
  call void @llvm.va_end.p0(ptr %ap)
  %s1 = add i32 %v0, %v1
  %s2 = add i32 %s1, %v2
  ret i32 %s2
}

define i32 @caller(i32 %a) {
  %r = call i32 (i32, ...) @vsum3(i32 3, i32 10, i32 %a, i32 20)
  ret i32 %r
}
