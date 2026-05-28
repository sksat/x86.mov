; Stage-3 fixture: SAR32ri (immediate arithmetic-right shift). 168 >>s 2 = 42.
; The high bit stays clear here, so this run can't tell SAR from SHR;
; future stage-7-prep fixtures with negative values will.

target triple = "mov-unknown-linux-gnu"

define i32 @sar_two(i32 %x) {
  %r = ashr i32 %x, 2
  ret i32 %r
}
