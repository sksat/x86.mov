#       ___     ___            ___    ___     ___     ___     ___          ___     ___      
#      /\  \   /\  \    ___   /\__\  /\  \   /\__\   /\__\   /\  \        /\  \   /\  \    .
#     |::\  \ /::\  \  /\  \ /:/ _/_ \:\  \ /:/ _/_ /:/  /  /::\  \  ___ /::\  \ /::\  \   .
#     |:::\  \:/\:\  \ \:\  \:/ /\__\ \:\  \:/ /\  \:/  /  /:/\:\  \/\__\:/\:\  \:/\:\__\  .
#   __|:|\:\  \  \:\  \ \:\  \ /:/  /  \:\  \ /::\  \  /  _:/ /::\  \/  //  \:\  \ /:/  /   
#  /::::|_\:\__\/ \:\__\ \:\__\:/  / \  \:\__\:/\:\__\/  /\__\:/\:\__\_//__/ \:\__\:/__/___ 
#  \:\~~\  \/__/\ /:/  / |:|  |/  /\  \ /:/  // /:/  /\ /:/  //  \/__/ \\  \ /:/  /::::/  / 
#   \:\  \  \:\  /:/  / \|:|  |__/\:\  /:/  // /:/  /  /:/  //__/:/\:\  \\  /:/  //~~/~~~~  
#    \:\  \  \:\/:/  /\__|:|__|  \ \:\/:/  //_/:/  /:\/:/  /:\  \/__\:\  \\/:/  /:\~~\     .
#     \:\__\  \::/  /\::::/__/:\__\ \::/  /  /:/  / \::/  / \:\__\   \:\__\:/  / \:\__\    .
#      \/__/   \/__/  ~~~~    \/__/  \/__/   \/__/   \/__/   \/__/    \/__/ __/   \/__/    2
#                                                                                           
#
# M/o/Vfuscator2
#
# github.com/xoreaxeaxeax/movfuscator
# chris domas           @xoreaxeaxeax
#


.text
# export 'new_tower'
.globl new_tower
.type new_tower,@function
new_tower:  # <LCI>
# label
movl (target), %eax
movl $new_tower-0x80000000, %edx
# alu_eq
movl %eax, (alu_x)
movl %edx, (alu_y)
movl $0, %eax
movl $0, %ecx
movl $0, %edx
movb (alu_x+0), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+0), %dl
movb (%ecx,%edx), %dl
movl %edx, (b0)
movb (alu_x+1), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+1), %dl
movb (%ecx,%edx), %dl
movl %edx, (b1)
movb (alu_x+2), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+2), %dl
movb (%ecx,%edx), %dl
movl %edx, (b2)
movb (alu_x+3), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+3), %dl
movb (%ecx,%edx), %dl
movl %edx, (b3)
# alu_bool
movl (b0), %eax
movl (b1), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b2), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b3), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
movl (b0), %eax
movl %eax, (b0)
# end alu_eq
# load jmp regs (b0)
movl (b0), %ecx
movl $R0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r0), %edx
movl %edx, (%eax)
movl $R1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r1), %edx
movl %edx, (%eax)
movl $R2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r2), %edx
movl %edx, (%eax)
movl $R3, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r3), %edx
movl %edx, (%eax)
movl $F0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f0), %edx
movl %edx, (%eax)
movl $F1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f1), %edx
movl %edx, (%eax)
movl $F2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f2), %edx
movl %edx, (%eax)
movl $D0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d0), %edx
movl %edx, (%eax)
movl (jmp_d0+4), %edx
movl %edx, 4(%eax)
movl $D1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d1), %edx
movl %edx, (%eax)
movl (jmp_d1+4), %edx
movl %edx, 4(%eax)
movl $D2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d2), %edx
movl %edx, (%eax)
movl (jmp_d2+4), %edx
movl %edx, 4(%eax)
# end load jmp regs
# execute on (b0)
movl (b0), %eax
movl sel_on(,%eax,4), %eax
movl $1, (%eax)
# end execute on
# end label
# prologue
# push (fp)
movl (fp), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# push (R1)
movl (R1), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# push (R2)
movl (R2), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# push (R3)
movl (R3), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# push (F1)
movl (F1), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# push (F2)
movl (F2), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# push D1
movl (D1), %eax
movl %eax, (stack_temp)
movl (D1+4), %eax
movl %eax, (stack_temp+4)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
movl (stack_temp+4), %edx
movl %edx, 4(%eax)
# end push
# push D2
movl (D2), %eax
movl %eax, (stack_temp)
movl (D2+4), %eax
movl %eax, (stack_temp+4)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
movl (stack_temp+4), %edx
movl %edx, 4(%eax)
# end push
# mov %esp, %ebp
movl $fp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl %edx, (%eax)
# end mov %esp, %ebp
# frame
movl (sp), %eax
movl push(%eax), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
#end frame
# emit/mov>addrfp4(cap)

# emit addrfp

# (offset 44)
movl (fp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (R3)

# end emit addrfp

# emit/mov>indiri4(addrfp4(cap))

# emit indiri

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indiri

# emit/mov>load(indiri4(addrfp4(cap)))

# emit loadu

movl (R3), %eax
movl %eax, (R3)

# end emit loadu

# emit/mov>cnsti4(2)
movl $2, (R2)
# emit/mov>lshu4(load(indiri4(addrfp4(cap))),cnsti4(2))

# emit lshu

movl (R3), %eax
movl (R2), %edx
# alu_lshu
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_clamp32
movl (alu_y), %eax
movl %eax, (alu_sx)
movl $0, (alu_sc)
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_sc+0), %al
movb (alu_sx+1+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_sc+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_sc+0), %al
movb (alu_sx+2+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_sc+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_sc+0), %al
movb (alu_sx+3+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_sc+0)
# end alu_bor8
movl (alu_sc), %eax
movb alu_true(%eax), %al
movl $0, (alu_sc)
movb %al, (alu_sc+1)
movb (alu_sx+0), %al
movb %al, (alu_sc+0)
movl (alu_sc), %eax
movl alu_clamp32(,%eax,4), %eax
movl %eax, (alu_y)
# end alu_clamp32
# alu_lshu32
movl $0, %eax
movl $0, (alu_s0)
movl $0, (alu_s1)
movl $0, (alu_s2)
movl $0, (alu_s3)
movl (alu_y), %edx
movl alu_lshu8(,%edx,4), %edx
movb (alu_x+0), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s0+0)
movb (alu_x+1), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s1+1)
movb (alu_x+2), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s2+2)
movb (alu_x+3), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s3+3)
# alu_bor32
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+0), %al
movb (alu_s1+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+1), %al
movb (alu_s1+1), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+1)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+2), %al
movb (alu_s1+2), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+2)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+3), %al
movb (alu_s1+3), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+3)
# end alu_bor8
# end alu_bor32
# alu_bor32
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+0), %al
movb (alu_s2+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+1), %al
movb (alu_s2+1), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+1)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+2), %al
movb (alu_s2+2), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+2)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+3), %al
movb (alu_s2+3), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+3)
# end alu_bor8
# end alu_bor32
# alu_bor32
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+0), %al
movb (alu_s3+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+1), %al
movb (alu_s3+1), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+1)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+2), %al
movb (alu_s3+2), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+2)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+3), %al
movb (alu_s3+3), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+3)
# end alu_bor8
# end alu_bor32
# end alu_lshu32
movl (alu_s), %eax
# end alu_lshu
movl %eax, (R3)

# end emit lshu

# emit/mov>cnstu4(8)
movl $8, (R2)
# emit/mov>addu4(lshu4(load(indiri4(addrfp4(cap))),cnsti4(2)),cnstu4(8))

# emit addu

movl (R3), %eax
movl (R2), %edx
# alu_add
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_add32
movl $0, %eax
movl $0, %ecx
movl $0, (alu_c)
# alu_add16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c)
# end alu_add16_fast
# alu_add16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c)
# end alu_add16_fast
# end alu_add32
movl (alu_s), %eax
# end alu_add
movl %eax, (R3)

# end emit addu

# emit/mov>argu4(addu4(lshu4(load(indiri4(addrfp4(cap))),cnsti4(2)),cnstu4(8)))

# emit argu

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argu

# emit/mov>cnstu4(1)
movl $1, (R3)
# emit/mov>argu4(cnstu4(1))

# emit argu

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argu

# emit/mov>callp4(addrgp4(calloc))

# emit callp

# call 'calloc'
# (direct call)
# calloc is external
# push return
movl $.LCE11-0x80000000, %eax
# alu_add
movl %eax, (alu_x)
movl $0x80000000, (alu_y)
# alu_add32
movl $0, %eax
movl $0, %ecx
movl $0, (alu_c)
# alu_add16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c)
# end alu_add16_fast
# alu_add16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c)
# end alu_add16_fast
# end alu_add32
movl (alu_s), %eax
# end alu_add
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# end push return

# (external call)
movl (sp), %esp  # <REQ>
movl $calloc, (external)
movl (on), %eax
movl fault(,%eax,4), %eax
movl (%eax), %eax
.LCE11:
# fix ret conv
movl %eax, (R0)  # <REQ>
# pop %eax
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl (stack_temp), %edx
movl %edx, %eax
# end pop
# end fix ret conv
# pop args (8)
movl (sp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop args

# end emit callp

# emit/mov>load(callp4(addrgp4(calloc)))

# emit loadp

movl (R0), %eax
movl %eax, (R3)

# end emit loadp

# emit/mov>asgnp4(vregp(1),load(callp4(addrgp4(calloc))))

# emit asgnp


# (emit vreg asgn)


# end emit asgnp

# emit/mov>indirp4(vregp(1))

# emit/mov>asgnp4(addrlp4(t),indirp4(vregp(1)))

# emit asgnp

# (ADDRL)
# (offset -4)
movl (fp), %eax
movl push(%eax), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (R3), %edx
movl %edx, (%eax)

# end emit asgnp

# emit/mov>addrlp4(t)

# emit addrlp

# (offset -4)
movl (fp), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indirp4(addrlp4(t))

# emit indirp

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indirp

# emit/mov>asgnp4(vregp(2),indirp4(addrlp4(t)))

# emit asgnp


# (emit vreg asgn)


# end emit asgnp

# emit/mov>indirp4(vregp(2))

# emit/mov>indirp4(vregp(2))

# emit/mov>cnsti4(8)
movl $8, (R2)
# emit/mov>addp4(indirp4(vregp(2)),cnsti4(8))

# emit addp

movl (R3), %eax
movl (R2), %edx
# alu_add
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_add32
movl $0, %eax
movl $0, %ecx
movl $0, (alu_c)
# alu_add16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c)
# end alu_add16_fast
# alu_add16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c)
# end alu_add16_fast
# end alu_add32
movl (alu_s), %eax
# end alu_add
movl %eax, (R2)

# end emit addp

# emit/mov>asgnp4(indirp4(vregp(2)),addp4(indirp4(vregp(2)),cnsti4(8)))

# emit asgnp

# (!ADDRL)
movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (R2), %edx
movl %edx, (%eax)

# end emit asgnp

# emit/mov>addrlp4(t)

# emit addrlp

# (offset -4)
movl (fp), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indirp4(addrlp4(t))

# emit indirp

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R0)

# end emit indirp

# emit/mov>retp4(indirp4(addrlp4(t)))

# emit retp


# end emit retp

# emit/mov>labelv(10)

# emit labelv

.LCI10:
movl (target), %eax
movl $.LCI10-0x80000000, %edx
# alu_eq
movl %eax, (alu_x)
movl %edx, (alu_y)
movl $0, %eax
movl $0, %ecx
movl $0, %edx
movb (alu_x+0), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+0), %dl
movb (%ecx,%edx), %dl
movl %edx, (b0)
movb (alu_x+1), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+1), %dl
movb (%ecx,%edx), %dl
movl %edx, (b1)
movb (alu_x+2), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+2), %dl
movb (%ecx,%edx), %dl
movl %edx, (b2)
movb (alu_x+3), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+3), %dl
movb (%ecx,%edx), %dl
movl %edx, (b3)
# alu_bool
movl (b0), %eax
movl (b1), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b2), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b3), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
movl (b0), %eax
movl %eax, (b0)
# end alu_eq
# load jmp regs (b0)
movl (b0), %ecx
movl $R0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r0), %edx
movl %edx, (%eax)
movl $R1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r1), %edx
movl %edx, (%eax)
movl $R2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r2), %edx
movl %edx, (%eax)
movl $R3, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r3), %edx
movl %edx, (%eax)
movl $F0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f0), %edx
movl %edx, (%eax)
movl $F1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f1), %edx
movl %edx, (%eax)
movl $F2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f2), %edx
movl %edx, (%eax)
movl $D0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d0), %edx
movl %edx, (%eax)
movl (jmp_d0+4), %edx
movl %edx, 4(%eax)
movl $D1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d1), %edx
movl %edx, (%eax)
movl (jmp_d1+4), %edx
movl %edx, 4(%eax)
movl $D2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d2), %edx
movl %edx, (%eax)
movl (jmp_d2+4), %edx
movl %edx, 4(%eax)
# end load jmp regs
# execute on (b0)
movl (b0), %eax
movl sel_on(,%eax,4), %eax
movl $1, (%eax)
# end execute on

# end emit labelv

# epilogue
# movl %ebp, %esp
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (fp), %edx
movl %edx, (%eax)
# end movl %ebp, %esp
# pop8 D2
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl 4(%eax), %edx
movl %edx, (stack_temp+4)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $D2, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
movl (stack_temp+4), %edx
movl %edx, 4(%eax)
# end pop8
# pop8 D1
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl 4(%eax), %edx
movl %edx, (stack_temp+4)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $D1, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
movl (stack_temp+4), %edx
movl %edx, 4(%eax)
# end pop8
# pop F2
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $F2, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop
# pop F1
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $F1, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop
# pop R3
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $R3, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop
# pop R2
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $R2, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop
# pop R1
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $R1, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop
# pop fp
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $fp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop
# ret
# pop %eax
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl (stack_temp), %edx
movl %edx, %eax
# end pop
# jmp_jumpv
movl %eax, (branch_temp)
# store target (branch_temp) (on)
movl (on), %eax
movl sel_target(,%eax,4), %eax
movl (branch_temp), %edx
movl %edx, (%eax)
# end store target
# store jmp regs (on)
movl (on), %ecx
movl $jmp_r0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (R0), %edx
movl %edx, 0(%eax)
movl (R1), %edx
movl %edx, 4(%eax)
movl (R2), %edx
movl %edx, 8(%eax)
movl (R3), %edx
movl %edx, 12(%eax)
movl $jmp_f0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (F0), %edx
movl %edx, 0(%eax)
movl (F1), %edx
movl %edx, 4(%eax)
movl (F2), %edx
movl %edx, 8(%eax)
movl $jmp_d0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (D0), %edx
movl %edx, 0(%eax)
movl (D0+4), %edx
movl %edx, 4(%eax)
movl (D1), %edx
movl %edx, 8(%eax)
movl (D1+4), %edx
movl %edx, 12(%eax)
movl (D2), %edx
movl %edx, 16(%eax)
movl (D2+4), %edx
movl %edx, 20(%eax)
# end store jmp regs
# execute off (on)
movl (on), %eax
movl sel_on(,%eax,4), %eax
movl $0, (%eax)
# end execute off
# end jmp_jumpv
# end ret
.Lf12:
.size new_tower,.Lf12-new_tower

# export 'text'
.globl text
.type text,@function
text:  # <LCI>
# label
movl (target), %eax
movl $text-0x80000000, %edx
# alu_eq
movl %eax, (alu_x)
movl %edx, (alu_y)
movl $0, %eax
movl $0, %ecx
movl $0, %edx
movb (alu_x+0), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+0), %dl
movb (%ecx,%edx), %dl
movl %edx, (b0)
movb (alu_x+1), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+1), %dl
movb (%ecx,%edx), %dl
movl %edx, (b1)
movb (alu_x+2), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+2), %dl
movb (%ecx,%edx), %dl
movl %edx, (b2)
movb (alu_x+3), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+3), %dl
movb (%ecx,%edx), %dl
movl %edx, (b3)
# alu_bool
movl (b0), %eax
movl (b1), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b2), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b3), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
movl (b0), %eax
movl %eax, (b0)
# end alu_eq
# load jmp regs (b0)
movl (b0), %ecx
movl $R0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r0), %edx
movl %edx, (%eax)
movl $R1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r1), %edx
movl %edx, (%eax)
movl $R2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r2), %edx
movl %edx, (%eax)
movl $R3, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r3), %edx
movl %edx, (%eax)
movl $F0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f0), %edx
movl %edx, (%eax)
movl $F1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f1), %edx
movl %edx, (%eax)
movl $F2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f2), %edx
movl %edx, (%eax)
movl $D0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d0), %edx
movl %edx, (%eax)
movl (jmp_d0+4), %edx
movl %edx, 4(%eax)
movl $D1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d1), %edx
movl %edx, (%eax)
movl (jmp_d1+4), %edx
movl %edx, 4(%eax)
movl $D2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d2), %edx
movl %edx, (%eax)
movl (jmp_d2+4), %edx
movl %edx, 4(%eax)
# end load jmp regs
# execute on (b0)
movl (b0), %eax
movl sel_on(,%eax,4), %eax
movl $1, (%eax)
# end execute on
# end label
# prologue
# push (fp)
movl (fp), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# push (R1)
movl (R1), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# push (R2)
movl (R2), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# push (R3)
movl (R3), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# push (F1)
movl (F1), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# push (F2)
movl (F2), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# push D1
movl (D1), %eax
movl %eax, (stack_temp)
movl (D1+4), %eax
movl %eax, (stack_temp+4)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
movl (stack_temp+4), %edx
movl %edx, 4(%eax)
# end push
# push D2
movl (D2), %eax
movl %eax, (stack_temp)
movl (D2+4), %eax
movl %eax, (stack_temp+4)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
movl (stack_temp+4), %edx
movl %edx, 4(%eax)
# end push
# mov %esp, %ebp
movl $fp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl %edx, (%eax)
# end mov %esp, %ebp
# emit/mov>addrgp4(height)

# emit addrgp

movl $height, %eax
movl %eax, (R3)

# end emit addrgp

# emit/mov>indiri4(addrgp4(height))

# emit indiri

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indiri

# emit/mov>asgni4(vregp(1),indiri4(addrgp4(height)))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>cnsti4(1)
movl $1, (R2)
# emit/mov>asgni4(vregp(2),cnsti4(1))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>indiri4(vregp(1))

# emit/mov>indiri4(vregp(2))

# emit/mov>addi4(indiri4(vregp(1)),indiri4(vregp(2)))

# emit addi

movl (R3), %eax
movl (R2), %edx
# alu_add
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_add32
movl $0, %eax
movl $0, %ecx
movl $0, (alu_c)
# alu_add16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c)
# end alu_add16_fast
# alu_add16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c)
# end alu_add16_fast
# end alu_add32
movl (alu_s), %eax
# end alu_add
movl %eax, (R1)

# end emit addi

# emit/mov>addrfp4(i)

# emit addrfp

# (offset 48)
movl (fp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (R0)

# end emit addrfp

# emit/mov>indiri4(addrfp4(i))

# emit indiri

movl (R0), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R0)

# end emit indiri

# emit/mov>indiri4(vregp(2))

# emit/mov>lshi4(indiri4(addrfp4(i)),indiri4(vregp(2)))

# emit lshi

movl (R0), %eax
movl (R2), %edx
# alu_lshu
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_clamp32
movl (alu_y), %eax
movl %eax, (alu_sx)
movl $0, (alu_sc)
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_sc+0), %al
movb (alu_sx+1+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_sc+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_sc+0), %al
movb (alu_sx+2+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_sc+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_sc+0), %al
movb (alu_sx+3+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_sc+0)
# end alu_bor8
movl (alu_sc), %eax
movb alu_true(%eax), %al
movl $0, (alu_sc)
movb %al, (alu_sc+1)
movb (alu_sx+0), %al
movb %al, (alu_sc+0)
movl (alu_sc), %eax
movl alu_clamp32(,%eax,4), %eax
movl %eax, (alu_y)
# end alu_clamp32
# alu_lshu32
movl $0, %eax
movl $0, (alu_s0)
movl $0, (alu_s1)
movl $0, (alu_s2)
movl $0, (alu_s3)
movl (alu_y), %edx
movl alu_lshu8(,%edx,4), %edx
movb (alu_x+0), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s0+0)
movb (alu_x+1), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s1+1)
movb (alu_x+2), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s2+2)
movb (alu_x+3), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s3+3)
# alu_bor32
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+0), %al
movb (alu_s1+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+1), %al
movb (alu_s1+1), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+1)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+2), %al
movb (alu_s1+2), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+2)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+3), %al
movb (alu_s1+3), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+3)
# end alu_bor8
# end alu_bor32
# alu_bor32
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+0), %al
movb (alu_s2+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+1), %al
movb (alu_s2+1), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+1)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+2), %al
movb (alu_s2+2), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+2)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+3), %al
movb (alu_s2+3), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+3)
# end alu_bor8
# end alu_bor32
# alu_bor32
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+0), %al
movb (alu_s3+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+1), %al
movb (alu_s3+1), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+1)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+2), %al
movb (alu_s3+2), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+2)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+3), %al
movb (alu_s3+3), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+3)
# end alu_bor8
# end alu_bor32
# end alu_lshu32
movl (alu_s), %eax
# end alu_lshu
movl %eax, (R0)

# end emit lshi

# emit/mov>indiri4(vregp(2))

# emit/mov>addi4(lshi4(indiri4(addrfp4(i)),indiri4(vregp(2))),indiri4(vregp(2)))

# emit addi

movl (R0), %eax
movl (R2), %edx
# alu_add
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_add32
movl $0, %eax
movl $0, %ecx
movl $0, (alu_c)
# alu_add16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c)
# end alu_add16_fast
# alu_add16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c)
# end alu_add16_fast
# end alu_add32
movl (alu_s), %eax
# end alu_add
movl %eax, (R0)

# end emit addi

# emit/mov>muli4(addi4(indiri4(vregp(1)),indiri4(vregp(2))),addi4(lshi4(indiri4(addrfp4(i)),indiri4(vregp(2))),indiri4(vregp(2))))

# emit muli

movl (R1), %eax
movl (R0), %edx
# alu_mul
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_mul32
movl $0, (alu_z0)
movl $0, (alu_z1)
movl $0, (alu_z2)
movl $0, (alu_z3)
movl $0, (alu_c)
# alu_mul8
movl $0, %eax
movl $0, %ebx
movl $0, %ecx
movl $0, %edx
movb (alu_x+0), %al
movb (alu_y+0), %dl
movl alu_mul_mul8l(,%eax,4), %ebx
movb (%ebx,%edx), %cl
movl alu_mul_mul8h(,%eax,4), %ebx
movb (%ebx,%edx), %al
movl $0, %ebx
movb (alu_c), %dl
movb alu_mul_sum8l(%ecx,%edx), %dl
movb %dl, (alu_z0+0)
movb (alu_c), %dl
movb alu_mul_sum8h(%ecx,%edx), %dl
movb alu_mul_sum8l(%edx,%eax), %dl
movb %dl, (alu_c)
# end alu_mul8
# alu_mul8
movl $0, %eax
movl $0, %ebx
movl $0, %ecx
movl $0, %edx
movb (alu_x+1), %al
movb (alu_y+0), %dl
movl alu_mul_mul8l(,%eax,4), %ebx
movb (%ebx,%edx), %cl
movl alu_mul_mul8h(,%eax,4), %ebx
movb (%ebx,%edx), %al
movl $0, %ebx
movb (alu_c), %dl
movb alu_mul_sum8l(%ecx,%edx), %dl
movb %dl, (alu_z0+1)
movb (alu_c), %dl
movb alu_mul_sum8h(%ecx,%edx), %dl
movb alu_mul_sum8l(%edx,%eax), %dl
movb %dl, (alu_c)
# end alu_mul8
# alu_mul8
movl $0, %eax
movl $0, %ebx
movl $0, %ecx
movl $0, %edx
movb (alu_x+2), %al
movb (alu_y+0), %dl
movl alu_mul_mul8l(,%eax,4), %ebx
movb (%ebx,%edx), %cl
movl alu_mul_mul8h(,%eax,4), %ebx
movb (%ebx,%edx), %al
movl $0, %ebx
movb (alu_c), %dl
movb alu_mul_sum8l(%ecx,%edx), %dl
movb %dl, (alu_z0+2)
movb (alu_c), %dl
movb alu_mul_sum8h(%ecx,%edx), %dl
movb alu_mul_sum8l(%edx,%eax), %dl
movb %dl, (alu_c)
# end alu_mul8
# alu_mul8
movl $0, %eax
movl $0, %ebx
movl $0, %ecx
movl $0, %edx
movb (alu_x+3), %al
movb (alu_y+0), %dl
movl alu_mul_mul8l(,%eax,4), %ebx
movb (%ebx,%edx), %cl
movl alu_mul_mul8h(,%eax,4), %ebx
movb (%ebx,%edx), %al
movl $0, %ebx
movb (alu_c), %dl
movb alu_mul_sum8l(%ecx,%edx), %dl
movb %dl, (alu_z0+3)
movb (alu_c), %dl
movb alu_mul_sum8h(%ecx,%edx), %dl
movb alu_mul_sum8l(%edx,%eax), %dl
movb %dl, (alu_c)
# end alu_mul8
movl $0, (alu_c)
# alu_mul8
movl $0, %eax
movl $0, %ebx
movl $0, %ecx
movl $0, %edx
movb (alu_x+0), %al
movb (alu_y+1), %dl
movl alu_mul_mul8l(,%eax,4), %ebx
movb (%ebx,%edx), %cl
movl alu_mul_mul8h(,%eax,4), %ebx
movb (%ebx,%edx), %al
movl $0, %ebx
movb (alu_c), %dl
movb alu_mul_sum8l(%ecx,%edx), %dl
movb %dl, (alu_z1+1)
movb (alu_c), %dl
movb alu_mul_sum8h(%ecx,%edx), %dl
movb alu_mul_sum8l(%edx,%eax), %dl
movb %dl, (alu_c)
# end alu_mul8
# alu_mul8
movl $0, %eax
movl $0, %ebx
movl $0, %ecx
movl $0, %edx
movb (alu_x+1), %al
movb (alu_y+1), %dl
movl alu_mul_mul8l(,%eax,4), %ebx
movb (%ebx,%edx), %cl
movl alu_mul_mul8h(,%eax,4), %ebx
movb (%ebx,%edx), %al
movl $0, %ebx
movb (alu_c), %dl
movb alu_mul_sum8l(%ecx,%edx), %dl
movb %dl, (alu_z1+2)
movb (alu_c), %dl
movb alu_mul_sum8h(%ecx,%edx), %dl
movb alu_mul_sum8l(%edx,%eax), %dl
movb %dl, (alu_c)
# end alu_mul8
# alu_mul8
movl $0, %eax
movl $0, %ebx
movl $0, %ecx
movl $0, %edx
movb (alu_x+2), %al
movb (alu_y+1), %dl
movl alu_mul_mul8l(,%eax,4), %ebx
movb (%ebx,%edx), %cl
movl alu_mul_mul8h(,%eax,4), %ebx
movb (%ebx,%edx), %al
movl $0, %ebx
movb (alu_c), %dl
movb alu_mul_sum8l(%ecx,%edx), %dl
movb %dl, (alu_z1+3)
movb (alu_c), %dl
movb alu_mul_sum8h(%ecx,%edx), %dl
movb alu_mul_sum8l(%edx,%eax), %dl
movb %dl, (alu_c)
# end alu_mul8
movl $0, (alu_c)
# alu_mul8
movl $0, %eax
movl $0, %ebx
movl $0, %ecx
movl $0, %edx
movb (alu_x+0), %al
movb (alu_y+2), %dl
movl alu_mul_mul8l(,%eax,4), %ebx
movb (%ebx,%edx), %cl
movl alu_mul_mul8h(,%eax,4), %ebx
movb (%ebx,%edx), %al
movl $0, %ebx
movb (alu_c), %dl
movb alu_mul_sum8l(%ecx,%edx), %dl
movb %dl, (alu_z2+2)
movb (alu_c), %dl
movb alu_mul_sum8h(%ecx,%edx), %dl
movb alu_mul_sum8l(%edx,%eax), %dl
movb %dl, (alu_c)
# end alu_mul8
# alu_mul8
movl $0, %eax
movl $0, %ebx
movl $0, %ecx
movl $0, %edx
movb (alu_x+1), %al
movb (alu_y+2), %dl
movl alu_mul_mul8l(,%eax,4), %ebx
movb (%ebx,%edx), %cl
movl alu_mul_mul8h(,%eax,4), %ebx
movb (%ebx,%edx), %al
movl $0, %ebx
movb (alu_c), %dl
movb alu_mul_sum8l(%ecx,%edx), %dl
movb %dl, (alu_z2+3)
movb (alu_c), %dl
movb alu_mul_sum8h(%ecx,%edx), %dl
movb alu_mul_sum8l(%edx,%eax), %dl
movb %dl, (alu_c)
# end alu_mul8
movl $0, (alu_c)
# alu_mul8
movl $0, %eax
movl $0, %ebx
movl $0, %ecx
movl $0, %edx
movb (alu_x+0), %al
movb (alu_y+3), %dl
movl alu_mul_mul8l(,%eax,4), %ebx
movb (%ebx,%edx), %cl
movl alu_mul_mul8h(,%eax,4), %ebx
movb (%ebx,%edx), %al
movl $0, %ebx
movb (alu_c), %dl
movb alu_mul_sum8l(%ecx,%edx), %dl
movb %dl, (alu_z3+3)
movb (alu_c), %dl
movb alu_mul_sum8h(%ecx,%edx), %dl
movb alu_mul_sum8l(%edx,%eax), %dl
movb %dl, (alu_c)
# end alu_mul8
movl $0, (alu_c)
# alu_add8n
movl $0, %ebx
movl $0, %edx
movl $0, %eax
movb (alu_z0+0), %al
movb (alu_c+0), %dl
movl alu_mul_shl2(,%eax,4), %eax
movl alu_mul_shl2(,%edx,4), %edx
movl alu_mul_sums(%eax,%edx), %edx
movb %dl, (alu_s+0)
movb %dh, (alu_c)
# end alu_add8n
# alu_add8n
movl $0, %ebx
movl $0, %edx
movl $0, %eax
movb (alu_z0+1), %al
movb (alu_z1+1), %dl
movl alu_mul_shl2(,%eax,4), %eax
movl alu_mul_shl2(,%edx,4), %edx
movl alu_mul_sums(%eax,%edx), %edx
movl $0, %eax
movb (alu_c+0), %al
movl alu_mul_shl2(,%edx,4), %edx
movl alu_mul_shl2(,%eax,4), %eax
movl alu_mul_sums(%eax,%edx), %edx
movb %dl, (alu_s+1)
movb %dh, (alu_c)
# end alu_add8n
# alu_add8n
movl $0, %ebx
movl $0, %edx
movl $0, %eax
movb (alu_z0+2), %al
movb (alu_z1+2), %dl
movl alu_mul_shl2(,%eax,4), %eax
movl alu_mul_shl2(,%edx,4), %edx
movl alu_mul_sums(%eax,%edx), %edx
movl $0, %eax
movb (alu_z2+2), %al
movl alu_mul_shl2(,%edx,4), %edx
movl alu_mul_shl2(,%eax,4), %eax
movl alu_mul_sums(%eax,%edx), %edx
movl $0, %eax
movb (alu_c+0), %al
movl alu_mul_shl2(,%edx,4), %edx
movl alu_mul_shl2(,%eax,4), %eax
movl alu_mul_sums(%eax,%edx), %edx
movb %dl, (alu_s+2)
movb %dh, (alu_c)
# end alu_add8n
# alu_add8n
movl $0, %ebx
movl $0, %edx
movl $0, %eax
movb (alu_z0+3), %al
movb (alu_z1+3), %dl
movl alu_mul_shl2(,%eax,4), %eax
movl alu_mul_shl2(,%edx,4), %edx
movl alu_mul_sums(%eax,%edx), %edx
movl $0, %eax
movb (alu_z2+3), %al
movl alu_mul_shl2(,%edx,4), %edx
movl alu_mul_shl2(,%eax,4), %eax
movl alu_mul_sums(%eax,%edx), %edx
movl $0, %eax
movb (alu_z3+3), %al
movl alu_mul_shl2(,%edx,4), %edx
movl alu_mul_shl2(,%eax,4), %eax
movl alu_mul_sums(%eax,%edx), %edx
movl $0, %eax
movb (alu_c+0), %al
movl alu_mul_shl2(,%edx,4), %edx
movl alu_mul_shl2(,%eax,4), %eax
movl alu_mul_sums(%eax,%edx), %edx
movb %dl, (alu_s+3)
movb %dh, (alu_c)
# end alu_add8n
# end alu_mul32
movl (alu_s), %eax
# end alu_mul
movl %eax, (R1)

# end emit muli

# emit/mov>addrfp4(d)

# emit addrfp

# (offset 52)
movl (fp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (R0)

# end emit addrfp

# emit/mov>indiri4(addrfp4(d))

# emit indiri

movl (R0), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R0)

# end emit indiri

# emit/mov>subi4(muli4(addi4(indiri4(vregp(1)),indiri4(vregp(2))),addi4(lshi4(indiri4(addrfp4(i)),indiri4(vregp(2))),indiri4(vregp(2)))),indiri4(addrfp4(d)))

# emit subi

movl (R1), %eax
movl (R0), %edx
# alu_sub
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_sub32
movl $0, %eax
movl $0, %ecx
movl $0x1, (alu_c)
# alu_sub16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movw alu_inv16(,%ecx,2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movl alu_add16(,%edx,4), %edx
movl (alu_c), %ecx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# alu_sub16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movw alu_inv16(,%ecx,2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movl alu_add16(,%edx,4), %edx
movl (alu_c), %ecx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_s), %eax
# end alu_sub
movl %eax, (R1)

# end emit subi

# emit/mov>argi4(subi4(muli4(addi4(indiri4(vregp(1)),indiri4(vregp(2))),addi4(lshi4(indiri4(addrfp4(i)),indiri4(vregp(2))),indiri4(vregp(2)))),indiri4(addrfp4(d))))

# emit argi

movl (R1), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argi

# emit/mov>indiri4(vregp(1))

# emit/mov>addrfp4(y)

# emit addrfp

# (offset 44)
movl (fp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (R1)

# end emit addrfp

# emit/mov>indiri4(addrfp4(y))

# emit indiri

movl (R1), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R1)

# end emit indiri

# emit/mov>subi4(indiri4(vregp(1)),indiri4(addrfp4(y)))

# emit subi

movl (R3), %eax
movl (R1), %edx
# alu_sub
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_sub32
movl $0, %eax
movl $0, %ecx
movl $0x1, (alu_c)
# alu_sub16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movw alu_inv16(,%ecx,2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movl alu_add16(,%edx,4), %edx
movl (alu_c), %ecx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# alu_sub16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movw alu_inv16(,%ecx,2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movl alu_add16(,%edx,4), %edx
movl (alu_c), %ecx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_s), %eax
# end alu_sub
movl %eax, (R3)

# end emit subi

# emit/mov>indiri4(vregp(2))

# emit/mov>addi4(subi4(indiri4(vregp(1)),indiri4(addrfp4(y))),indiri4(vregp(2)))

# emit addi

movl (R3), %eax
movl (R2), %edx
# alu_add
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_add32
movl $0, %eax
movl $0, %ecx
movl $0, (alu_c)
# alu_add16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c)
# end alu_add16_fast
# alu_add16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c)
# end alu_add16_fast
# end alu_add32
movl (alu_s), %eax
# end alu_add
movl %eax, (R3)

# end emit addi

# emit/mov>argi4(addi4(subi4(indiri4(vregp(1)),indiri4(addrfp4(y))),indiri4(vregp(2))))

# emit argi

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argi

# emit/mov>addrgp4(14)

# emit addrgp

movl $.LCS14, %eax
movl %eax, (R3)

# end emit addrgp

# emit/mov>argp4(addrgp4(14))

# emit argp

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argp

# emit/mov>calli4(addrgp4(printf))

# emit calli

# call 'printf'
# (direct call)
# printf is external
# push return
movl $.LCE19-0x80000000, %eax
# alu_add
movl %eax, (alu_x)
movl $0x80000000, (alu_y)
# alu_add32
movl $0, %eax
movl $0, %ecx
movl $0, (alu_c)
# alu_add16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c)
# end alu_add16_fast
# alu_add16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c)
# end alu_add16_fast
# end alu_add32
movl (alu_s), %eax
# end alu_add
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# end push return

# (external call)
movl (sp), %esp  # <REQ>
movl $printf, (external)
movl (on), %eax
movl fault(,%eax,4), %eax
movl (%eax), %eax
.LCE19:
# fix ret conv
movl %eax, (R0)  # <REQ>
# pop %eax
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl (stack_temp), %edx
movl %edx, %eax
# end pop
# end fix ret conv
# pop args (12)
movl (sp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop args

# end emit calli

# emit/mov>jumpv(addrgp4(16))

# emit jumpv

# (direct jump)
movl $.LCI16-0x80000000, %eax
# jmp_jumpv
movl %eax, (branch_temp)
# store target (branch_temp) (on)
movl (on), %eax
movl sel_target(,%eax,4), %eax
movl (branch_temp), %edx
movl %edx, (%eax)
# end store target
# store jmp regs (on)
movl (on), %ecx
movl $jmp_r0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (R0), %edx
movl %edx, 0(%eax)
movl (R1), %edx
movl %edx, 4(%eax)
movl (R2), %edx
movl %edx, 8(%eax)
movl (R3), %edx
movl %edx, 12(%eax)
movl $jmp_f0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (F0), %edx
movl %edx, 0(%eax)
movl (F1), %edx
movl %edx, 4(%eax)
movl (F2), %edx
movl %edx, 8(%eax)
movl $jmp_d0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (D0), %edx
movl %edx, 0(%eax)
movl (D0+4), %edx
movl %edx, 4(%eax)
movl (D1), %edx
movl %edx, 8(%eax)
movl (D1+4), %edx
movl %edx, 12(%eax)
movl (D2), %edx
movl %edx, 16(%eax)
movl (D2+4), %edx
movl %edx, 20(%eax)
# end store jmp regs
# execute off (on)
movl (on), %eax
movl sel_on(,%eax,4), %eax
movl $0, (%eax)
# end execute off
# end jmp_jumpv

# end emit jumpv

# emit/mov>labelv(15)

# emit labelv

.LCI15:
movl (target), %eax
movl $.LCI15-0x80000000, %edx
# alu_eq
movl %eax, (alu_x)
movl %edx, (alu_y)
movl $0, %eax
movl $0, %ecx
movl $0, %edx
movb (alu_x+0), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+0), %dl
movb (%ecx,%edx), %dl
movl %edx, (b0)
movb (alu_x+1), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+1), %dl
movb (%ecx,%edx), %dl
movl %edx, (b1)
movb (alu_x+2), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+2), %dl
movb (%ecx,%edx), %dl
movl %edx, (b2)
movb (alu_x+3), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+3), %dl
movb (%ecx,%edx), %dl
movl %edx, (b3)
# alu_bool
movl (b0), %eax
movl (b1), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b2), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b3), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
movl (b0), %eax
movl %eax, (b0)
# end alu_eq
# load jmp regs (b0)
movl (b0), %ecx
movl $R0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r0), %edx
movl %edx, (%eax)
movl $R1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r1), %edx
movl %edx, (%eax)
movl $R2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r2), %edx
movl %edx, (%eax)
movl $R3, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r3), %edx
movl %edx, (%eax)
movl $F0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f0), %edx
movl %edx, (%eax)
movl $F1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f1), %edx
movl %edx, (%eax)
movl $F2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f2), %edx
movl %edx, (%eax)
movl $D0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d0), %edx
movl %edx, (%eax)
movl (jmp_d0+4), %edx
movl %edx, 4(%eax)
movl $D1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d1), %edx
movl %edx, (%eax)
movl (jmp_d1+4), %edx
movl %edx, 4(%eax)
movl $D2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d2), %edx
movl %edx, (%eax)
movl (jmp_d2+4), %edx
movl %edx, 4(%eax)
# end load jmp regs
# execute on (b0)
movl (b0), %eax
movl sel_on(,%eax,4), %eax
movl $1, (%eax)
# end execute on

# end emit labelv

# emit/mov>addrfp4(s)

# emit addrfp

# (offset 56)
movl (fp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (R3)

# end emit addrfp

# emit/mov>indirp4(addrfp4(s))

# emit indirp

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indirp

# emit/mov>argp4(indirp4(addrfp4(s)))

# emit argp

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argp

# emit/mov>addrgp4(18)

# emit addrgp

movl $.LCS18, %eax
movl %eax, (R3)

# end emit addrgp

# emit/mov>argp4(addrgp4(18))

# emit argp

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argp

# emit/mov>calli4(addrgp4(printf))

# emit calli

# call 'printf'
# (direct call)
# printf is external
# push return
movl $.LCE20-0x80000000, %eax
# alu_add
movl %eax, (alu_x)
movl $0x80000000, (alu_y)
# alu_add32
movl $0, %eax
movl $0, %ecx
movl $0, (alu_c)
# alu_add16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c)
# end alu_add16_fast
# alu_add16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c)
# end alu_add16_fast
# end alu_add32
movl (alu_s), %eax
# end alu_add
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# end push return

# (external call)
movl (sp), %esp  # <REQ>
movl $printf, (external)
movl (on), %eax
movl fault(,%eax,4), %eax
movl (%eax), %eax
.LCE20:
# fix ret conv
movl %eax, (R0)  # <REQ>
# pop %eax
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl (stack_temp), %edx
movl %edx, %eax
# end pop
# end fix ret conv
# pop args (8)
movl (sp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop args

# end emit calli

# emit/mov>labelv(16)

# emit labelv

.LCI16:
movl (target), %eax
movl $.LCI16-0x80000000, %edx
# alu_eq
movl %eax, (alu_x)
movl %edx, (alu_y)
movl $0, %eax
movl $0, %ecx
movl $0, %edx
movb (alu_x+0), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+0), %dl
movb (%ecx,%edx), %dl
movl %edx, (b0)
movb (alu_x+1), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+1), %dl
movb (%ecx,%edx), %dl
movl %edx, (b1)
movb (alu_x+2), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+2), %dl
movb (%ecx,%edx), %dl
movl %edx, (b2)
movb (alu_x+3), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+3), %dl
movb (%ecx,%edx), %dl
movl %edx, (b3)
# alu_bool
movl (b0), %eax
movl (b1), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b2), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b3), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
movl (b0), %eax
movl %eax, (b0)
# end alu_eq
# load jmp regs (b0)
movl (b0), %ecx
movl $R0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r0), %edx
movl %edx, (%eax)
movl $R1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r1), %edx
movl %edx, (%eax)
movl $R2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r2), %edx
movl %edx, (%eax)
movl $R3, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r3), %edx
movl %edx, (%eax)
movl $F0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f0), %edx
movl %edx, (%eax)
movl $F1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f1), %edx
movl %edx, (%eax)
movl $F2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f2), %edx
movl %edx, (%eax)
movl $D0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d0), %edx
movl %edx, (%eax)
movl (jmp_d0+4), %edx
movl %edx, 4(%eax)
movl $D1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d1), %edx
movl %edx, (%eax)
movl (jmp_d1+4), %edx
movl %edx, 4(%eax)
movl $D2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d2), %edx
movl %edx, (%eax)
movl (jmp_d2+4), %edx
movl %edx, 4(%eax)
# end load jmp regs
# execute on (b0)
movl (b0), %eax
movl sel_on(,%eax,4), %eax
movl $1, (%eax)
# end execute on

# end emit labelv

# emit/mov>addrfp4(d)

# emit addrfp

# (offset 52)
movl (fp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (R3)

# end emit addrfp

# emit/mov>indiri4(addrfp4(d))

# emit indiri

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indiri

# emit/mov>asgni4(vregp(3),indiri4(addrfp4(d)))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>addrfp4(d)

# emit addrfp

# (offset 52)
movl (fp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (R2)

# end emit addrfp

# emit/mov>indiri4(vregp(3))

# emit/mov>cnsti4(1)
movl $1, (R1)
# emit/mov>subi4(indiri4(vregp(3)),cnsti4(1))

# emit subi

movl (R3), %eax
movl (R1), %edx
# alu_sub
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_sub32
movl $0, %eax
movl $0, %ecx
movl $0x1, (alu_c)
# alu_sub16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movw alu_inv16(,%ecx,2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movl alu_add16(,%edx,4), %edx
movl (alu_c), %ecx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# alu_sub16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movw alu_inv16(,%ecx,2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movl alu_add16(,%edx,4), %edx
movl (alu_c), %ecx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_s), %eax
# end alu_sub
movl %eax, (R1)

# end emit subi

# emit/mov>asgni4(addrfp4(d),subi4(indiri4(vregp(3)),cnsti4(1)))

# emit asgni

# (!ADDRL)
movl (R2), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (R1), %edx
movl %edx, (%eax)

# end emit asgni

# emit/mov>indiri4(vregp(3))

# emit/mov>cnsti4(0)
movl $0, (R2)
# emit/mov>nei4(indiri4(vregp(3)),cnsti4(0))

# emit nei

movl (R3), %eax
movl (R2), %edx
movl $.LCI15-0x80000000, %ecx
# jmp_nei
movl %ecx, (branch_temp)
# alu_cmp
movl %eax, (alu_x)
movl %edx, (alu_y)
movl %edx, (alu_t)
# alu_sub32
movl $0, %eax
movl $0, %ecx
movl $0x1, (alu_c)
# alu_sub16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movw alu_inv16(,%ecx,2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movl alu_add16(,%edx,4), %edx
movl (alu_c), %ecx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# alu_sub16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movw alu_inv16(,%ecx,2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movl alu_add16(,%edx,4), %edx
movl (alu_c), %ecx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_t), %eax
movl %eax, (alu_y)
movl $0, %eax
movb (alu_c), %al
movb alu_false(%eax), %al
movb %al, (cf)
movb (alu_s+3), %al
movl alu_b7(,%eax,4), %eax
movb %al, (sf)
movl $0, %eax
movl $0, %edx
movb (alu_s+0), %dl
movb alu_true(%edx,%eax), %al
movb (alu_s+1), %dl
movb alu_true(%edx,%eax), %al
movb (alu_s+2), %dl
movb alu_true(%edx,%eax), %al
movb (alu_s+3), %dl
movb alu_true(%edx,%eax), %al
movb alu_false(%eax), %al
movb %al, (zf)
movl $alu_cmp_of, %edx
movb (alu_x+3), %al
movl alu_b7(,%eax,4), %eax
movl (%edx,%eax,4), %edx
movb (alu_y+3), %al
movl alu_b7(,%eax,4), %eax
movl (%edx,%eax,4), %edx
movb (alu_s+3), %al
movl alu_b7(,%eax,4), %eax
movl (%edx,%eax,4), %edx
movl (%edx), %edx
movb %dl, (of)
# end alu_cmp
# alu_not
movl (zf), %eax
movl alu_false(,%eax,4), %eax
movl %eax, (b0)
# end alu_not
# alu_bool
movl (b0), %eax
movl (on), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# store target (branch_temp) (b0)
movl (b0), %eax
movl sel_target(,%eax,4), %eax
movl (branch_temp), %edx
movl %edx, (%eax)
# end store target
# store jmp regs (b0)
movl (b0), %ecx
movl $jmp_r0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (R0), %edx
movl %edx, 0(%eax)
movl (R1), %edx
movl %edx, 4(%eax)
movl (R2), %edx
movl %edx, 8(%eax)
movl (R3), %edx
movl %edx, 12(%eax)
movl $jmp_f0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (F0), %edx
movl %edx, 0(%eax)
movl (F1), %edx
movl %edx, 4(%eax)
movl (F2), %edx
movl %edx, 8(%eax)
movl $jmp_d0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (D0), %edx
movl %edx, 0(%eax)
movl (D0+4), %edx
movl %edx, 4(%eax)
movl (D1), %edx
movl %edx, 8(%eax)
movl (D1+4), %edx
movl %edx, 12(%eax)
movl (D2), %edx
movl %edx, 16(%eax)
movl (D2+4), %edx
movl %edx, 20(%eax)
# end store jmp regs
# execute off (b0)
movl (b0), %eax
movl sel_on(,%eax,4), %eax
movl $0, (%eax)
# end execute off
# end jmp_nei

# end emit nei

# emit/mov>labelv(13)

# emit labelv

.LCI13:
movl (target), %eax
movl $.LCI13-0x80000000, %edx
# alu_eq
movl %eax, (alu_x)
movl %edx, (alu_y)
movl $0, %eax
movl $0, %ecx
movl $0, %edx
movb (alu_x+0), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+0), %dl
movb (%ecx,%edx), %dl
movl %edx, (b0)
movb (alu_x+1), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+1), %dl
movb (%ecx,%edx), %dl
movl %edx, (b1)
movb (alu_x+2), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+2), %dl
movb (%ecx,%edx), %dl
movl %edx, (b2)
movb (alu_x+3), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+3), %dl
movb (%ecx,%edx), %dl
movl %edx, (b3)
# alu_bool
movl (b0), %eax
movl (b1), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b2), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b3), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
movl (b0), %eax
movl %eax, (b0)
# end alu_eq
# load jmp regs (b0)
movl (b0), %ecx
movl $R0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r0), %edx
movl %edx, (%eax)
movl $R1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r1), %edx
movl %edx, (%eax)
movl $R2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r2), %edx
movl %edx, (%eax)
movl $R3, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r3), %edx
movl %edx, (%eax)
movl $F0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f0), %edx
movl %edx, (%eax)
movl $F1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f1), %edx
movl %edx, (%eax)
movl $F2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f2), %edx
movl %edx, (%eax)
movl $D0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d0), %edx
movl %edx, (%eax)
movl (jmp_d0+4), %edx
movl %edx, 4(%eax)
movl $D1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d1), %edx
movl %edx, (%eax)
movl (jmp_d1+4), %edx
movl %edx, 4(%eax)
movl $D2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d2), %edx
movl %edx, (%eax)
movl (jmp_d2+4), %edx
movl %edx, 4(%eax)
# end load jmp regs
# execute on (b0)
movl (b0), %eax
movl sel_on(,%eax,4), %eax
movl $1, (%eax)
# end execute on

# end emit labelv

# epilogue
# movl %ebp, %esp
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (fp), %edx
movl %edx, (%eax)
# end movl %ebp, %esp
# pop8 D2
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl 4(%eax), %edx
movl %edx, (stack_temp+4)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $D2, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
movl (stack_temp+4), %edx
movl %edx, 4(%eax)
# end pop8
# pop8 D1
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl 4(%eax), %edx
movl %edx, (stack_temp+4)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $D1, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
movl (stack_temp+4), %edx
movl %edx, 4(%eax)
# end pop8
# pop F2
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $F2, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop
# pop F1
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $F1, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop
# pop R3
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $R3, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop
# pop R2
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $R2, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop
# pop R1
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $R1, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop
# pop fp
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $fp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop
# ret
# pop %eax
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl (stack_temp), %edx
movl %edx, %eax
# end pop
# jmp_jumpv
movl %eax, (branch_temp)
# store target (branch_temp) (on)
movl (on), %eax
movl sel_target(,%eax,4), %eax
movl (branch_temp), %edx
movl %edx, (%eax)
# end store target
# store jmp regs (on)
movl (on), %ecx
movl $jmp_r0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (R0), %edx
movl %edx, 0(%eax)
movl (R1), %edx
movl %edx, 4(%eax)
movl (R2), %edx
movl %edx, 8(%eax)
movl (R3), %edx
movl %edx, 12(%eax)
movl $jmp_f0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (F0), %edx
movl %edx, 0(%eax)
movl (F1), %edx
movl %edx, 4(%eax)
movl (F2), %edx
movl %edx, 8(%eax)
movl $jmp_d0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (D0), %edx
movl %edx, 0(%eax)
movl (D0+4), %edx
movl %edx, 4(%eax)
movl (D1), %edx
movl %edx, 8(%eax)
movl (D1+4), %edx
movl %edx, 12(%eax)
movl (D2), %edx
movl %edx, 16(%eax)
movl (D2+4), %edx
movl %edx, 20(%eax)
# end store jmp regs
# execute off (on)
movl (on), %eax
movl sel_on(,%eax,4), %eax
movl $0, (%eax)
# end execute off
# end jmp_jumpv
# end ret
.Lf21:
.size text,.Lf21-text

# export 'add_disk'
.globl add_disk
.type add_disk,@function
add_disk:  # <LCI>
# label
movl (target), %eax
movl $add_disk-0x80000000, %edx
# alu_eq
movl %eax, (alu_x)
movl %edx, (alu_y)
movl $0, %eax
movl $0, %ecx
movl $0, %edx
movb (alu_x+0), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+0), %dl
movb (%ecx,%edx), %dl
movl %edx, (b0)
movb (alu_x+1), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+1), %dl
movb (%ecx,%edx), %dl
movl %edx, (b1)
movb (alu_x+2), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+2), %dl
movb (%ecx,%edx), %dl
movl %edx, (b2)
movb (alu_x+3), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+3), %dl
movb (%ecx,%edx), %dl
movl %edx, (b3)
# alu_bool
movl (b0), %eax
movl (b1), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b2), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b3), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
movl (b0), %eax
movl %eax, (b0)
# end alu_eq
# load jmp regs (b0)
movl (b0), %ecx
movl $R0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r0), %edx
movl %edx, (%eax)
movl $R1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r1), %edx
movl %edx, (%eax)
movl $R2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r2), %edx
movl %edx, (%eax)
movl $R3, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r3), %edx
movl %edx, (%eax)
movl $F0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f0), %edx
movl %edx, (%eax)
movl $F1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f1), %edx
movl %edx, (%eax)
movl $F2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f2), %edx
movl %edx, (%eax)
movl $D0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d0), %edx
movl %edx, (%eax)
movl (jmp_d0+4), %edx
movl %edx, 4(%eax)
movl $D1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d1), %edx
movl %edx, (%eax)
movl (jmp_d1+4), %edx
movl %edx, 4(%eax)
movl $D2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d2), %edx
movl %edx, (%eax)
movl (jmp_d2+4), %edx
movl %edx, 4(%eax)
# end load jmp regs
# execute on (b0)
movl (b0), %eax
movl sel_on(,%eax,4), %eax
movl $1, (%eax)
# end execute on
# end label
# prologue
# push (fp)
movl (fp), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# push (R1)
movl (R1), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# push (R2)
movl (R2), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# push (R3)
movl (R3), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# push (F1)
movl (F1), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# push (F2)
movl (F2), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# push D1
movl (D1), %eax
movl %eax, (stack_temp)
movl (D1+4), %eax
movl %eax, (stack_temp+4)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
movl (stack_temp+4), %edx
movl %edx, 4(%eax)
# end push
# push D2
movl (D2), %eax
movl %eax, (stack_temp)
movl (D2+4), %eax
movl %eax, (stack_temp+4)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
movl (stack_temp+4), %edx
movl %edx, 4(%eax)
# end push
# mov %esp, %ebp
movl $fp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl %edx, (%eax)
# end mov %esp, %ebp
# emit/mov>addrfp4(i)

# emit addrfp

# (offset 44)
movl (fp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (R3)

# end emit addrfp

# emit/mov>indiri4(addrfp4(i))

# emit indiri

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indiri

# emit/mov>cnsti4(2)
movl $2, (R2)
# emit/mov>lshi4(indiri4(addrfp4(i)),cnsti4(2))

# emit lshi

movl (R3), %eax
movl (R2), %edx
# alu_lshu
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_clamp32
movl (alu_y), %eax
movl %eax, (alu_sx)
movl $0, (alu_sc)
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_sc+0), %al
movb (alu_sx+1+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_sc+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_sc+0), %al
movb (alu_sx+2+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_sc+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_sc+0), %al
movb (alu_sx+3+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_sc+0)
# end alu_bor8
movl (alu_sc), %eax
movb alu_true(%eax), %al
movl $0, (alu_sc)
movb %al, (alu_sc+1)
movb (alu_sx+0), %al
movb %al, (alu_sc+0)
movl (alu_sc), %eax
movl alu_clamp32(,%eax,4), %eax
movl %eax, (alu_y)
# end alu_clamp32
# alu_lshu32
movl $0, %eax
movl $0, (alu_s0)
movl $0, (alu_s1)
movl $0, (alu_s2)
movl $0, (alu_s3)
movl (alu_y), %edx
movl alu_lshu8(,%edx,4), %edx
movb (alu_x+0), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s0+0)
movb (alu_x+1), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s1+1)
movb (alu_x+2), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s2+2)
movb (alu_x+3), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s3+3)
# alu_bor32
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+0), %al
movb (alu_s1+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+1), %al
movb (alu_s1+1), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+1)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+2), %al
movb (alu_s1+2), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+2)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+3), %al
movb (alu_s1+3), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+3)
# end alu_bor8
# end alu_bor32
# alu_bor32
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+0), %al
movb (alu_s2+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+1), %al
movb (alu_s2+1), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+1)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+2), %al
movb (alu_s2+2), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+2)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+3), %al
movb (alu_s2+3), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+3)
# end alu_bor8
# end alu_bor32
# alu_bor32
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+0), %al
movb (alu_s3+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+1), %al
movb (alu_s3+1), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+1)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+2), %al
movb (alu_s3+2), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+2)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+3), %al
movb (alu_s3+3), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+3)
# end alu_bor8
# end alu_bor32
# end alu_lshu32
movl (alu_s), %eax
# end alu_lshu
movl %eax, (R3)

# end emit lshi

# emit/mov>addrgp4(t)

# emit addrgp

movl $t, %eax
movl %eax, (R2)

# end emit addrgp

# emit/mov>addp4(lshi4(indiri4(addrfp4(i)),cnsti4(2)),addrgp4(t))

# emit addp

movl (R3), %eax
movl (R2), %edx
# alu_add
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_add32
movl $0, %eax
movl $0, %ecx
movl $0, (alu_c)
# alu_add16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c)
# end alu_add16_fast
# alu_add16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c)
# end alu_add16_fast
# end alu_add32
movl (alu_s), %eax
# end alu_add
movl %eax, (R3)

# end emit addp

# emit/mov>indirp4(addp4(lshi4(indiri4(addrfp4(i)),cnsti4(2)),addrgp4(t)))

# emit indirp

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indirp

# emit/mov>cnsti4(4)
movl $4, (R2)
# emit/mov>addp4(indirp4(addp4(lshi4(indiri4(addrfp4(i)),cnsti4(2)),addrgp4(t))),cnsti4(4))

# emit addp

movl (R3), %eax
movl (R2), %edx
# alu_add
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_add32
movl $0, %eax
movl $0, %ecx
movl $0, (alu_c)
# alu_add16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c)
# end alu_add16_fast
# alu_add16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c)
# end alu_add16_fast
# end alu_add32
movl (alu_s), %eax
# end alu_add
movl %eax, (R3)

# end emit addp

# emit/mov>asgnp4(vregp(1),addp4(indirp4(addp4(lshi4(indiri4(addrfp4(i)),cnsti4(2)),addrgp4(t))),cnsti4(4)))

# emit asgnp


# (emit vreg asgn)


# end emit asgnp

# emit/mov>indirp4(vregp(1))

# emit/mov>indiri4(indirp4(vregp(1)))

# emit indiri

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R2)

# end emit indiri

# emit/mov>asgni4(vregp(2),indiri4(indirp4(vregp(1))))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>indirp4(vregp(1))

# emit/mov>indiri4(vregp(2))

# emit/mov>cnsti4(1)
movl $1, (R1)
# emit/mov>addi4(indiri4(vregp(2)),cnsti4(1))

# emit addi

movl (R2), %eax
movl (R1), %edx
# alu_add
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_add32
movl $0, %eax
movl $0, %ecx
movl $0, (alu_c)
# alu_add16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c)
# end alu_add16_fast
# alu_add16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c)
# end alu_add16_fast
# end alu_add32
movl (alu_s), %eax
# end alu_add
movl %eax, (R1)

# end emit addi

# emit/mov>asgni4(indirp4(vregp(1)),addi4(indiri4(vregp(2)),cnsti4(1)))

# emit asgni

# (!ADDRL)
movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (R1), %edx
movl %edx, (%eax)

# end emit asgni

# emit/mov>cnsti4(2)
movl $2, (R3)
# emit/mov>asgni4(vregp(3),cnsti4(2))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>indiri4(vregp(2))

# emit/mov>indiri4(vregp(3))

# emit/mov>lshi4(indiri4(vregp(2)),indiri4(vregp(3)))

# emit lshi

movl (R2), %eax
movl (R3), %edx
# alu_lshu
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_clamp32
movl (alu_y), %eax
movl %eax, (alu_sx)
movl $0, (alu_sc)
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_sc+0), %al
movb (alu_sx+1+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_sc+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_sc+0), %al
movb (alu_sx+2+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_sc+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_sc+0), %al
movb (alu_sx+3+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_sc+0)
# end alu_bor8
movl (alu_sc), %eax
movb alu_true(%eax), %al
movl $0, (alu_sc)
movb %al, (alu_sc+1)
movb (alu_sx+0), %al
movb %al, (alu_sc+0)
movl (alu_sc), %eax
movl alu_clamp32(,%eax,4), %eax
movl %eax, (alu_y)
# end alu_clamp32
# alu_lshu32
movl $0, %eax
movl $0, (alu_s0)
movl $0, (alu_s1)
movl $0, (alu_s2)
movl $0, (alu_s3)
movl (alu_y), %edx
movl alu_lshu8(,%edx,4), %edx
movb (alu_x+0), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s0+0)
movb (alu_x+1), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s1+1)
movb (alu_x+2), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s2+2)
movb (alu_x+3), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s3+3)
# alu_bor32
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+0), %al
movb (alu_s1+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+1), %al
movb (alu_s1+1), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+1)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+2), %al
movb (alu_s1+2), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+2)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+3), %al
movb (alu_s1+3), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+3)
# end alu_bor8
# end alu_bor32
# alu_bor32
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+0), %al
movb (alu_s2+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+1), %al
movb (alu_s2+1), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+1)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+2), %al
movb (alu_s2+2), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+2)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+3), %al
movb (alu_s2+3), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+3)
# end alu_bor8
# end alu_bor32
# alu_bor32
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+0), %al
movb (alu_s3+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+1), %al
movb (alu_s3+1), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+1)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+2), %al
movb (alu_s3+2), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+2)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+3), %al
movb (alu_s3+3), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+3)
# end alu_bor8
# end alu_bor32
# end alu_lshu32
movl (alu_s), %eax
# end alu_lshu
movl %eax, (R2)

# end emit lshi

# emit/mov>addrfp4(i)

# emit addrfp

# (offset 44)
movl (fp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (R1)

# end emit addrfp

# emit/mov>indiri4(addrfp4(i))

# emit indiri

movl (R1), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R1)

# end emit indiri

# emit/mov>indiri4(vregp(3))

# emit/mov>lshi4(indiri4(addrfp4(i)),indiri4(vregp(3)))

# emit lshi

movl (R1), %eax
movl (R3), %edx
# alu_lshu
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_clamp32
movl (alu_y), %eax
movl %eax, (alu_sx)
movl $0, (alu_sc)
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_sc+0), %al
movb (alu_sx+1+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_sc+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_sc+0), %al
movb (alu_sx+2+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_sc+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_sc+0), %al
movb (alu_sx+3+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_sc+0)
# end alu_bor8
movl (alu_sc), %eax
movb alu_true(%eax), %al
movl $0, (alu_sc)
movb %al, (alu_sc+1)
movb (alu_sx+0), %al
movb %al, (alu_sc+0)
movl (alu_sc), %eax
movl alu_clamp32(,%eax,4), %eax
movl %eax, (alu_y)
# end alu_clamp32
# alu_lshu32
movl $0, %eax
movl $0, (alu_s0)
movl $0, (alu_s1)
movl $0, (alu_s2)
movl $0, (alu_s3)
movl (alu_y), %edx
movl alu_lshu8(,%edx,4), %edx
movb (alu_x+0), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s0+0)
movb (alu_x+1), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s1+1)
movb (alu_x+2), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s2+2)
movb (alu_x+3), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s3+3)
# alu_bor32
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+0), %al
movb (alu_s1+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+1), %al
movb (alu_s1+1), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+1)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+2), %al
movb (alu_s1+2), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+2)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+3), %al
movb (alu_s1+3), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+3)
# end alu_bor8
# end alu_bor32
# alu_bor32
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+0), %al
movb (alu_s2+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+1), %al
movb (alu_s2+1), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+1)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+2), %al
movb (alu_s2+2), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+2)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+3), %al
movb (alu_s2+3), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+3)
# end alu_bor8
# end alu_bor32
# alu_bor32
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+0), %al
movb (alu_s3+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+1), %al
movb (alu_s3+1), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+1)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+2), %al
movb (alu_s3+2), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+2)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+3), %al
movb (alu_s3+3), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+3)
# end alu_bor8
# end alu_bor32
# end alu_lshu32
movl (alu_s), %eax
# end alu_lshu
movl %eax, (R3)

# end emit lshi

# emit/mov>addrgp4(t)

# emit addrgp

movl $t, %eax
movl %eax, (R1)

# end emit addrgp

# emit/mov>addp4(lshi4(indiri4(addrfp4(i)),indiri4(vregp(3))),addrgp4(t))

# emit addp

movl (R3), %eax
movl (R1), %edx
# alu_add
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_add32
movl $0, %eax
movl $0, %ecx
movl $0, (alu_c)
# alu_add16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c)
# end alu_add16_fast
# alu_add16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c)
# end alu_add16_fast
# end alu_add32
movl (alu_s), %eax
# end alu_add
movl %eax, (R3)

# end emit addp

# emit/mov>indirp4(addp4(lshi4(indiri4(addrfp4(i)),indiri4(vregp(3))),addrgp4(t)))

# emit indirp

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indirp

# emit/mov>indirp4(indirp4(addp4(lshi4(indiri4(addrfp4(i)),indiri4(vregp(3))),addrgp4(t))))

# emit indirp

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indirp

# emit/mov>addp4(lshi4(indiri4(vregp(2)),indiri4(vregp(3))),indirp4(indirp4(addp4(lshi4(indiri4(addrfp4(i)),indiri4(vregp(3))),addrgp4(t)))))

# emit addp

movl (R2), %eax
movl (R3), %edx
# alu_add
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_add32
movl $0, %eax
movl $0, %ecx
movl $0, (alu_c)
# alu_add16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c)
# end alu_add16_fast
# alu_add16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c)
# end alu_add16_fast
# end alu_add32
movl (alu_s), %eax
# end alu_add
movl %eax, (R3)

# end emit addp

# emit/mov>addrfp4(d)

# emit addrfp

# (offset 48)
movl (fp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (R2)

# end emit addrfp

# emit/mov>indiri4(addrfp4(d))

# emit indiri

movl (R2), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R2)

# end emit indiri

# emit/mov>asgni4(addp4(lshi4(indiri4(vregp(2)),indiri4(vregp(3))),indirp4(indirp4(addp4(lshi4(indiri4(addrfp4(i)),indiri4(vregp(3))),addrgp4(t))))),indiri4(addrfp4(d)))

# emit asgni

# (!ADDRL)
movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (R2), %edx
movl %edx, (%eax)

# end emit asgni

# emit/mov>addrgp4(23)

# emit addrgp

movl $.LCS23, %eax
movl %eax, (R3)

# end emit addrgp

# emit/mov>argp4(addrgp4(23))

# emit argp

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argp

# emit/mov>addrfp4(d)

# emit addrfp

# (offset 48)
movl (fp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (R3)

# end emit addrfp

# emit/mov>indiri4(addrfp4(d))

# emit indiri

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indiri

# emit/mov>argi4(indiri4(addrfp4(d)))

# emit argi

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argi

# emit/mov>addrfp4(i)

# emit addrfp

# (offset 44)
movl (fp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (R3)

# end emit addrfp

# emit/mov>indiri4(addrfp4(i))

# emit indiri

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indiri

# emit/mov>asgni4(vregp(4),indiri4(addrfp4(i)))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>indiri4(vregp(4))

# emit/mov>argi4(indiri4(vregp(4)))

# emit argi

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argi

# emit/mov>indiri4(vregp(4))

# emit/mov>cnsti4(2)
movl $2, (R2)
# emit/mov>lshi4(indiri4(vregp(4)),cnsti4(2))

# emit lshi

movl (R3), %eax
movl (R2), %edx
# alu_lshu
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_clamp32
movl (alu_y), %eax
movl %eax, (alu_sx)
movl $0, (alu_sc)
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_sc+0), %al
movb (alu_sx+1+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_sc+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_sc+0), %al
movb (alu_sx+2+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_sc+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_sc+0), %al
movb (alu_sx+3+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_sc+0)
# end alu_bor8
movl (alu_sc), %eax
movb alu_true(%eax), %al
movl $0, (alu_sc)
movb %al, (alu_sc+1)
movb (alu_sx+0), %al
movb %al, (alu_sc+0)
movl (alu_sc), %eax
movl alu_clamp32(,%eax,4), %eax
movl %eax, (alu_y)
# end alu_clamp32
# alu_lshu32
movl $0, %eax
movl $0, (alu_s0)
movl $0, (alu_s1)
movl $0, (alu_s2)
movl $0, (alu_s3)
movl (alu_y), %edx
movl alu_lshu8(,%edx,4), %edx
movb (alu_x+0), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s0+0)
movb (alu_x+1), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s1+1)
movb (alu_x+2), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s2+2)
movb (alu_x+3), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s3+3)
# alu_bor32
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+0), %al
movb (alu_s1+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+1), %al
movb (alu_s1+1), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+1)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+2), %al
movb (alu_s1+2), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+2)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+3), %al
movb (alu_s1+3), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+3)
# end alu_bor8
# end alu_bor32
# alu_bor32
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+0), %al
movb (alu_s2+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+1), %al
movb (alu_s2+1), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+1)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+2), %al
movb (alu_s2+2), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+2)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+3), %al
movb (alu_s2+3), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+3)
# end alu_bor8
# end alu_bor32
# alu_bor32
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+0), %al
movb (alu_s3+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+1), %al
movb (alu_s3+1), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+1)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+2), %al
movb (alu_s3+2), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+2)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+3), %al
movb (alu_s3+3), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+3)
# end alu_bor8
# end alu_bor32
# end alu_lshu32
movl (alu_s), %eax
# end alu_lshu
movl %eax, (R3)

# end emit lshi

# emit/mov>addrgp4(t)

# emit addrgp

movl $t, %eax
movl %eax, (R2)

# end emit addrgp

# emit/mov>addp4(lshi4(indiri4(vregp(4)),cnsti4(2)),addrgp4(t))

# emit addp

movl (R3), %eax
movl (R2), %edx
# alu_add
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_add32
movl $0, %eax
movl $0, %ecx
movl $0, (alu_c)
# alu_add16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c)
# end alu_add16_fast
# alu_add16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c)
# end alu_add16_fast
# end alu_add32
movl (alu_s), %eax
# end alu_add
movl %eax, (R3)

# end emit addp

# emit/mov>indirp4(addp4(lshi4(indiri4(vregp(4)),cnsti4(2)),addrgp4(t)))

# emit indirp

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indirp

# emit/mov>cnsti4(4)
movl $4, (R2)
# emit/mov>addp4(indirp4(addp4(lshi4(indiri4(vregp(4)),cnsti4(2)),addrgp4(t))),cnsti4(4))

# emit addp

movl (R3), %eax
movl (R2), %edx
# alu_add
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_add32
movl $0, %eax
movl $0, %ecx
movl $0, (alu_c)
# alu_add16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c)
# end alu_add16_fast
# alu_add16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c)
# end alu_add16_fast
# end alu_add32
movl (alu_s), %eax
# end alu_add
movl %eax, (R3)

# end emit addp

# emit/mov>indiri4(addp4(indirp4(addp4(lshi4(indiri4(vregp(4)),cnsti4(2)),addrgp4(t))),cnsti4(4)))

# emit indiri

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indiri

# emit/mov>argi4(indiri4(addp4(indirp4(addp4(lshi4(indiri4(vregp(4)),cnsti4(2)),addrgp4(t))),cnsti4(4))))

# emit argi

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argi

# emit/mov>callv(addrgp4(text))

# emit callv

# call 'text'
# (direct call)
# text is internal
# push return
movl $.LCI24-0x80000000, %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# end push return

movl $text-0x80000000, %eax
# jmp_jumpv
movl %eax, (branch_temp)
# store target (branch_temp) (on)
movl (on), %eax
movl sel_target(,%eax,4), %eax
movl (branch_temp), %edx
movl %edx, (%eax)
# end store target
# store jmp regs (on)
movl (on), %ecx
movl $jmp_r0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (R0), %edx
movl %edx, 0(%eax)
movl (R1), %edx
movl %edx, 4(%eax)
movl (R2), %edx
movl %edx, 8(%eax)
movl (R3), %edx
movl %edx, 12(%eax)
movl $jmp_f0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (F0), %edx
movl %edx, 0(%eax)
movl (F1), %edx
movl %edx, 4(%eax)
movl (F2), %edx
movl %edx, 8(%eax)
movl $jmp_d0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (D0), %edx
movl %edx, 0(%eax)
movl (D0+4), %edx
movl %edx, 4(%eax)
movl (D1), %edx
movl %edx, 8(%eax)
movl (D1+4), %edx
movl %edx, 12(%eax)
movl (D2), %edx
movl %edx, 16(%eax)
movl (D2+4), %edx
movl %edx, 20(%eax)
# end store jmp regs
# execute off (on)
movl (on), %eax
movl sel_on(,%eax,4), %eax
movl $0, (%eax)
# end execute off
# end jmp_jumpv
.LCI24:
movl (target), %eax
movl $.LCI24-0x80000000, %edx
# alu_eq
movl %eax, (alu_x)
movl %edx, (alu_y)
movl $0, %eax
movl $0, %ecx
movl $0, %edx
movb (alu_x+0), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+0), %dl
movb (%ecx,%edx), %dl
movl %edx, (b0)
movb (alu_x+1), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+1), %dl
movb (%ecx,%edx), %dl
movl %edx, (b1)
movb (alu_x+2), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+2), %dl
movb (%ecx,%edx), %dl
movl %edx, (b2)
movb (alu_x+3), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+3), %dl
movb (%ecx,%edx), %dl
movl %edx, (b3)
# alu_bool
movl (b0), %eax
movl (b1), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b2), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b3), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
movl (b0), %eax
movl %eax, (b0)
# end alu_eq
# load jmp regs (b0)
movl (b0), %ecx
movl $R0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r0), %edx
movl %edx, (%eax)
movl $R1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r1), %edx
movl %edx, (%eax)
movl $R2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r2), %edx
movl %edx, (%eax)
movl $R3, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r3), %edx
movl %edx, (%eax)
movl $F0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f0), %edx
movl %edx, (%eax)
movl $F1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f1), %edx
movl %edx, (%eax)
movl $F2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f2), %edx
movl %edx, (%eax)
movl $D0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d0), %edx
movl %edx, (%eax)
movl (jmp_d0+4), %edx
movl %edx, 4(%eax)
movl $D1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d1), %edx
movl %edx, (%eax)
movl (jmp_d1+4), %edx
movl %edx, 4(%eax)
movl $D2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d2), %edx
movl %edx, (%eax)
movl (jmp_d2+4), %edx
movl %edx, 4(%eax)
# end load jmp regs
# execute on (b0)
movl (b0), %eax
movl sel_on(,%eax,4), %eax
movl $1, (%eax)
# end execute on
# pop args (16)
movl (sp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop args

# end emit callv

# emit/mov>cnsti4(100000)
movl $100000, (R3)
# emit/mov>argi4(cnsti4(100000))

# emit argi

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argi

# emit/mov>calli4(addrgp4(usleep))

# emit calli

# call 'usleep'
# (direct call)
# usleep is external
# push return
movl $.LCE25-0x80000000, %eax
# alu_add
movl %eax, (alu_x)
movl $0x80000000, (alu_y)
# alu_add32
movl $0, %eax
movl $0, %ecx
movl $0, (alu_c)
# alu_add16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c)
# end alu_add16_fast
# alu_add16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c)
# end alu_add16_fast
# end alu_add32
movl (alu_s), %eax
# end alu_add
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# end push return

# (external call)
movl (sp), %esp  # <REQ>
movl $usleep, (external)
movl (on), %eax
movl fault(,%eax,4), %eax
movl (%eax), %eax
.LCE25:
# fix ret conv
movl %eax, (R0)  # <REQ>
# pop %eax
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl (stack_temp), %edx
movl %edx, %eax
# end pop
# end fix ret conv
# pop args (4)
movl (sp), %eax
movl pop(%eax), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop args

# end emit calli

# emit/mov>addrgp4(stdout)

# emit addrgp

movl $stdout, %eax
movl %eax, (R3)

# end emit addrgp

# emit/mov>indirp4(addrgp4(stdout))

# emit indirp

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indirp

# emit/mov>argp4(indirp4(addrgp4(stdout)))

# emit argp

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argp

# emit/mov>calli4(addrgp4(fflush))

# emit calli

# call 'fflush'
# (direct call)
# fflush is external
# push return
movl $.LCE26-0x80000000, %eax
# alu_add
movl %eax, (alu_x)
movl $0x80000000, (alu_y)
# alu_add32
movl $0, %eax
movl $0, %ecx
movl $0, (alu_c)
# alu_add16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c)
# end alu_add16_fast
# alu_add16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c)
# end alu_add16_fast
# end alu_add32
movl (alu_s), %eax
# end alu_add
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# end push return

# (external call)
movl (sp), %esp  # <REQ>
movl $fflush, (external)
movl (on), %eax
movl fault(,%eax,4), %eax
movl (%eax), %eax
.LCE26:
# fix ret conv
movl %eax, (R0)  # <REQ>
# pop %eax
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl (stack_temp), %edx
movl %edx, %eax
# end pop
# end fix ret conv
# pop args (4)
movl (sp), %eax
movl pop(%eax), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop args

# end emit calli

# emit/mov>labelv(22)

# emit labelv

.LCI22:
movl (target), %eax
movl $.LCI22-0x80000000, %edx
# alu_eq
movl %eax, (alu_x)
movl %edx, (alu_y)
movl $0, %eax
movl $0, %ecx
movl $0, %edx
movb (alu_x+0), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+0), %dl
movb (%ecx,%edx), %dl
movl %edx, (b0)
movb (alu_x+1), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+1), %dl
movb (%ecx,%edx), %dl
movl %edx, (b1)
movb (alu_x+2), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+2), %dl
movb (%ecx,%edx), %dl
movl %edx, (b2)
movb (alu_x+3), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+3), %dl
movb (%ecx,%edx), %dl
movl %edx, (b3)
# alu_bool
movl (b0), %eax
movl (b1), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b2), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b3), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
movl (b0), %eax
movl %eax, (b0)
# end alu_eq
# load jmp regs (b0)
movl (b0), %ecx
movl $R0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r0), %edx
movl %edx, (%eax)
movl $R1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r1), %edx
movl %edx, (%eax)
movl $R2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r2), %edx
movl %edx, (%eax)
movl $R3, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r3), %edx
movl %edx, (%eax)
movl $F0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f0), %edx
movl %edx, (%eax)
movl $F1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f1), %edx
movl %edx, (%eax)
movl $F2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f2), %edx
movl %edx, (%eax)
movl $D0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d0), %edx
movl %edx, (%eax)
movl (jmp_d0+4), %edx
movl %edx, 4(%eax)
movl $D1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d1), %edx
movl %edx, (%eax)
movl (jmp_d1+4), %edx
movl %edx, 4(%eax)
movl $D2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d2), %edx
movl %edx, (%eax)
movl (jmp_d2+4), %edx
movl %edx, 4(%eax)
# end load jmp regs
# execute on (b0)
movl (b0), %eax
movl sel_on(,%eax,4), %eax
movl $1, (%eax)
# end execute on

# end emit labelv

# epilogue
# movl %ebp, %esp
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (fp), %edx
movl %edx, (%eax)
# end movl %ebp, %esp
# pop8 D2
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl 4(%eax), %edx
movl %edx, (stack_temp+4)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $D2, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
movl (stack_temp+4), %edx
movl %edx, 4(%eax)
# end pop8
# pop8 D1
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl 4(%eax), %edx
movl %edx, (stack_temp+4)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $D1, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
movl (stack_temp+4), %edx
movl %edx, 4(%eax)
# end pop8
# pop F2
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $F2, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop
# pop F1
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $F1, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop
# pop R3
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $R3, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop
# pop R2
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $R2, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop
# pop R1
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $R1, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop
# pop fp
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $fp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop
# ret
# pop %eax
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl (stack_temp), %edx
movl %edx, %eax
# end pop
# jmp_jumpv
movl %eax, (branch_temp)
# store target (branch_temp) (on)
movl (on), %eax
movl sel_target(,%eax,4), %eax
movl (branch_temp), %edx
movl %edx, (%eax)
# end store target
# store jmp regs (on)
movl (on), %ecx
movl $jmp_r0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (R0), %edx
movl %edx, 0(%eax)
movl (R1), %edx
movl %edx, 4(%eax)
movl (R2), %edx
movl %edx, 8(%eax)
movl (R3), %edx
movl %edx, 12(%eax)
movl $jmp_f0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (F0), %edx
movl %edx, 0(%eax)
movl (F1), %edx
movl %edx, 4(%eax)
movl (F2), %edx
movl %edx, 8(%eax)
movl $jmp_d0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (D0), %edx
movl %edx, 0(%eax)
movl (D0+4), %edx
movl %edx, 4(%eax)
movl (D1), %edx
movl %edx, 8(%eax)
movl (D1+4), %edx
movl %edx, 12(%eax)
movl (D2), %edx
movl %edx, 16(%eax)
movl (D2+4), %edx
movl %edx, 20(%eax)
# end store jmp regs
# execute off (on)
movl (on), %eax
movl sel_on(,%eax,4), %eax
movl $0, (%eax)
# end execute off
# end jmp_jumpv
# end ret
.Lf27:
.size add_disk,.Lf27-add_disk

# export 'remove_disk'
.globl remove_disk
.type remove_disk,@function
remove_disk:  # <LCI>
# label
movl (target), %eax
movl $remove_disk-0x80000000, %edx
# alu_eq
movl %eax, (alu_x)
movl %edx, (alu_y)
movl $0, %eax
movl $0, %ecx
movl $0, %edx
movb (alu_x+0), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+0), %dl
movb (%ecx,%edx), %dl
movl %edx, (b0)
movb (alu_x+1), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+1), %dl
movb (%ecx,%edx), %dl
movl %edx, (b1)
movb (alu_x+2), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+2), %dl
movb (%ecx,%edx), %dl
movl %edx, (b2)
movb (alu_x+3), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+3), %dl
movb (%ecx,%edx), %dl
movl %edx, (b3)
# alu_bool
movl (b0), %eax
movl (b1), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b2), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b3), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
movl (b0), %eax
movl %eax, (b0)
# end alu_eq
# load jmp regs (b0)
movl (b0), %ecx
movl $R0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r0), %edx
movl %edx, (%eax)
movl $R1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r1), %edx
movl %edx, (%eax)
movl $R2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r2), %edx
movl %edx, (%eax)
movl $R3, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r3), %edx
movl %edx, (%eax)
movl $F0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f0), %edx
movl %edx, (%eax)
movl $F1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f1), %edx
movl %edx, (%eax)
movl $F2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f2), %edx
movl %edx, (%eax)
movl $D0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d0), %edx
movl %edx, (%eax)
movl (jmp_d0+4), %edx
movl %edx, 4(%eax)
movl $D1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d1), %edx
movl %edx, (%eax)
movl (jmp_d1+4), %edx
movl %edx, 4(%eax)
movl $D2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d2), %edx
movl %edx, (%eax)
movl (jmp_d2+4), %edx
movl %edx, 4(%eax)
# end load jmp regs
# execute on (b0)
movl (b0), %eax
movl sel_on(,%eax,4), %eax
movl $1, (%eax)
# end execute on
# end label
# prologue
# push (fp)
movl (fp), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# push (R1)
movl (R1), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# push (R2)
movl (R2), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# push (R3)
movl (R3), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# push (F1)
movl (F1), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# push (F2)
movl (F2), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# push D1
movl (D1), %eax
movl %eax, (stack_temp)
movl (D1+4), %eax
movl %eax, (stack_temp+4)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
movl (stack_temp+4), %edx
movl %edx, 4(%eax)
# end push
# push D2
movl (D2), %eax
movl %eax, (stack_temp)
movl (D2+4), %eax
movl %eax, (stack_temp+4)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
movl (stack_temp+4), %edx
movl %edx, 4(%eax)
# end push
# mov %esp, %ebp
movl $fp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl %edx, (%eax)
# end mov %esp, %ebp
# frame
movl (sp), %eax
movl push(%eax), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
#end frame
# emit/mov>addrfp4(i)

# emit addrfp

# (offset 44)
movl (fp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (R3)

# end emit addrfp

# emit/mov>indiri4(addrfp4(i))

# emit indiri

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indiri

# emit/mov>cnsti4(2)
movl $2, (R2)
# emit/mov>lshi4(indiri4(addrfp4(i)),cnsti4(2))

# emit lshi

movl (R3), %eax
movl (R2), %edx
# alu_lshu
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_clamp32
movl (alu_y), %eax
movl %eax, (alu_sx)
movl $0, (alu_sc)
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_sc+0), %al
movb (alu_sx+1+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_sc+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_sc+0), %al
movb (alu_sx+2+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_sc+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_sc+0), %al
movb (alu_sx+3+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_sc+0)
# end alu_bor8
movl (alu_sc), %eax
movb alu_true(%eax), %al
movl $0, (alu_sc)
movb %al, (alu_sc+1)
movb (alu_sx+0), %al
movb %al, (alu_sc+0)
movl (alu_sc), %eax
movl alu_clamp32(,%eax,4), %eax
movl %eax, (alu_y)
# end alu_clamp32
# alu_lshu32
movl $0, %eax
movl $0, (alu_s0)
movl $0, (alu_s1)
movl $0, (alu_s2)
movl $0, (alu_s3)
movl (alu_y), %edx
movl alu_lshu8(,%edx,4), %edx
movb (alu_x+0), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s0+0)
movb (alu_x+1), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s1+1)
movb (alu_x+2), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s2+2)
movb (alu_x+3), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s3+3)
# alu_bor32
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+0), %al
movb (alu_s1+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+1), %al
movb (alu_s1+1), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+1)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+2), %al
movb (alu_s1+2), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+2)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+3), %al
movb (alu_s1+3), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+3)
# end alu_bor8
# end alu_bor32
# alu_bor32
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+0), %al
movb (alu_s2+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+1), %al
movb (alu_s2+1), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+1)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+2), %al
movb (alu_s2+2), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+2)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+3), %al
movb (alu_s2+3), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+3)
# end alu_bor8
# end alu_bor32
# alu_bor32
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+0), %al
movb (alu_s3+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+1), %al
movb (alu_s3+1), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+1)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+2), %al
movb (alu_s3+2), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+2)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+3), %al
movb (alu_s3+3), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+3)
# end alu_bor8
# end alu_bor32
# end alu_lshu32
movl (alu_s), %eax
# end alu_lshu
movl %eax, (R3)

# end emit lshi

# emit/mov>addrgp4(t)

# emit addrgp

movl $t, %eax
movl %eax, (R2)

# end emit addrgp

# emit/mov>addp4(lshi4(indiri4(addrfp4(i)),cnsti4(2)),addrgp4(t))

# emit addp

movl (R3), %eax
movl (R2), %edx
# alu_add
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_add32
movl $0, %eax
movl $0, %ecx
movl $0, (alu_c)
# alu_add16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c)
# end alu_add16_fast
# alu_add16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c)
# end alu_add16_fast
# end alu_add32
movl (alu_s), %eax
# end alu_add
movl %eax, (R3)

# end emit addp

# emit/mov>indirp4(addp4(lshi4(indiri4(addrfp4(i)),cnsti4(2)),addrgp4(t)))

# emit indirp

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indirp

# emit/mov>cnsti4(4)
movl $4, (R2)
# emit/mov>addp4(indirp4(addp4(lshi4(indiri4(addrfp4(i)),cnsti4(2)),addrgp4(t))),cnsti4(4))

# emit addp

movl (R3), %eax
movl (R2), %edx
# alu_add
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_add32
movl $0, %eax
movl $0, %ecx
movl $0, (alu_c)
# alu_add16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c)
# end alu_add16_fast
# alu_add16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c)
# end alu_add16_fast
# end alu_add32
movl (alu_s), %eax
# end alu_add
movl %eax, (R3)

# end emit addp

# emit/mov>asgnp4(vregp(1),addp4(indirp4(addp4(lshi4(indiri4(addrfp4(i)),cnsti4(2)),addrgp4(t))),cnsti4(4)))

# emit asgnp


# (emit vreg asgn)


# end emit asgnp

# emit/mov>indirp4(vregp(1))

# emit/mov>indiri4(indirp4(vregp(1)))

# emit indiri

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R2)

# end emit indiri

# emit/mov>cnsti4(1)
movl $1, (R1)
# emit/mov>subi4(indiri4(indirp4(vregp(1))),cnsti4(1))

# emit subi

movl (R2), %eax
movl (R1), %edx
# alu_sub
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_sub32
movl $0, %eax
movl $0, %ecx
movl $0x1, (alu_c)
# alu_sub16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movw alu_inv16(,%ecx,2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movl alu_add16(,%edx,4), %edx
movl (alu_c), %ecx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# alu_sub16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movw alu_inv16(,%ecx,2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movl alu_add16(,%edx,4), %edx
movl (alu_c), %ecx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_s), %eax
# end alu_sub
movl %eax, (R2)

# end emit subi

# emit/mov>asgni4(vregp(2),subi4(indiri4(indirp4(vregp(1))),cnsti4(1)))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>indirp4(vregp(1))

# emit/mov>indiri4(vregp(2))

# emit/mov>asgni4(indirp4(vregp(1)),indiri4(vregp(2)))

# emit asgni

# (!ADDRL)
movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (R2), %edx
movl %edx, (%eax)

# end emit asgni

# emit/mov>cnsti4(2)
movl $2, (R3)
# emit/mov>asgni4(vregp(3),cnsti4(2))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>indiri4(vregp(2))

# emit/mov>indiri4(vregp(3))

# emit/mov>lshi4(indiri4(vregp(2)),indiri4(vregp(3)))

# emit lshi

movl (R2), %eax
movl (R3), %edx
# alu_lshu
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_clamp32
movl (alu_y), %eax
movl %eax, (alu_sx)
movl $0, (alu_sc)
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_sc+0), %al
movb (alu_sx+1+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_sc+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_sc+0), %al
movb (alu_sx+2+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_sc+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_sc+0), %al
movb (alu_sx+3+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_sc+0)
# end alu_bor8
movl (alu_sc), %eax
movb alu_true(%eax), %al
movl $0, (alu_sc)
movb %al, (alu_sc+1)
movb (alu_sx+0), %al
movb %al, (alu_sc+0)
movl (alu_sc), %eax
movl alu_clamp32(,%eax,4), %eax
movl %eax, (alu_y)
# end alu_clamp32
# alu_lshu32
movl $0, %eax
movl $0, (alu_s0)
movl $0, (alu_s1)
movl $0, (alu_s2)
movl $0, (alu_s3)
movl (alu_y), %edx
movl alu_lshu8(,%edx,4), %edx
movb (alu_x+0), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s0+0)
movb (alu_x+1), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s1+1)
movb (alu_x+2), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s2+2)
movb (alu_x+3), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s3+3)
# alu_bor32
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+0), %al
movb (alu_s1+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+1), %al
movb (alu_s1+1), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+1)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+2), %al
movb (alu_s1+2), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+2)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+3), %al
movb (alu_s1+3), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+3)
# end alu_bor8
# end alu_bor32
# alu_bor32
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+0), %al
movb (alu_s2+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+1), %al
movb (alu_s2+1), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+1)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+2), %al
movb (alu_s2+2), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+2)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+3), %al
movb (alu_s2+3), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+3)
# end alu_bor8
# end alu_bor32
# alu_bor32
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+0), %al
movb (alu_s3+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+1), %al
movb (alu_s3+1), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+1)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+2), %al
movb (alu_s3+2), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+2)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+3), %al
movb (alu_s3+3), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+3)
# end alu_bor8
# end alu_bor32
# end alu_lshu32
movl (alu_s), %eax
# end alu_lshu
movl %eax, (R2)

# end emit lshi

# emit/mov>addrfp4(i)

# emit addrfp

# (offset 44)
movl (fp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (R1)

# end emit addrfp

# emit/mov>indiri4(addrfp4(i))

# emit indiri

movl (R1), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R1)

# end emit indiri

# emit/mov>indiri4(vregp(3))

# emit/mov>lshi4(indiri4(addrfp4(i)),indiri4(vregp(3)))

# emit lshi

movl (R1), %eax
movl (R3), %edx
# alu_lshu
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_clamp32
movl (alu_y), %eax
movl %eax, (alu_sx)
movl $0, (alu_sc)
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_sc+0), %al
movb (alu_sx+1+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_sc+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_sc+0), %al
movb (alu_sx+2+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_sc+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_sc+0), %al
movb (alu_sx+3+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_sc+0)
# end alu_bor8
movl (alu_sc), %eax
movb alu_true(%eax), %al
movl $0, (alu_sc)
movb %al, (alu_sc+1)
movb (alu_sx+0), %al
movb %al, (alu_sc+0)
movl (alu_sc), %eax
movl alu_clamp32(,%eax,4), %eax
movl %eax, (alu_y)
# end alu_clamp32
# alu_lshu32
movl $0, %eax
movl $0, (alu_s0)
movl $0, (alu_s1)
movl $0, (alu_s2)
movl $0, (alu_s3)
movl (alu_y), %edx
movl alu_lshu8(,%edx,4), %edx
movb (alu_x+0), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s0+0)
movb (alu_x+1), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s1+1)
movb (alu_x+2), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s2+2)
movb (alu_x+3), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s3+3)
# alu_bor32
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+0), %al
movb (alu_s1+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+1), %al
movb (alu_s1+1), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+1)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+2), %al
movb (alu_s1+2), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+2)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+3), %al
movb (alu_s1+3), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+3)
# end alu_bor8
# end alu_bor32
# alu_bor32
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+0), %al
movb (alu_s2+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+1), %al
movb (alu_s2+1), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+1)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+2), %al
movb (alu_s2+2), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+2)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+3), %al
movb (alu_s2+3), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+3)
# end alu_bor8
# end alu_bor32
# alu_bor32
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+0), %al
movb (alu_s3+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+1), %al
movb (alu_s3+1), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+1)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+2), %al
movb (alu_s3+2), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+2)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+3), %al
movb (alu_s3+3), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+3)
# end alu_bor8
# end alu_bor32
# end alu_lshu32
movl (alu_s), %eax
# end alu_lshu
movl %eax, (R3)

# end emit lshi

# emit/mov>addrgp4(t)

# emit addrgp

movl $t, %eax
movl %eax, (R1)

# end emit addrgp

# emit/mov>addp4(lshi4(indiri4(addrfp4(i)),indiri4(vregp(3))),addrgp4(t))

# emit addp

movl (R3), %eax
movl (R1), %edx
# alu_add
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_add32
movl $0, %eax
movl $0, %ecx
movl $0, (alu_c)
# alu_add16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c)
# end alu_add16_fast
# alu_add16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c)
# end alu_add16_fast
# end alu_add32
movl (alu_s), %eax
# end alu_add
movl %eax, (R3)

# end emit addp

# emit/mov>indirp4(addp4(lshi4(indiri4(addrfp4(i)),indiri4(vregp(3))),addrgp4(t)))

# emit indirp

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indirp

# emit/mov>indirp4(indirp4(addp4(lshi4(indiri4(addrfp4(i)),indiri4(vregp(3))),addrgp4(t))))

# emit indirp

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indirp

# emit/mov>addp4(lshi4(indiri4(vregp(2)),indiri4(vregp(3))),indirp4(indirp4(addp4(lshi4(indiri4(addrfp4(i)),indiri4(vregp(3))),addrgp4(t)))))

# emit addp

movl (R2), %eax
movl (R3), %edx
# alu_add
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_add32
movl $0, %eax
movl $0, %ecx
movl $0, (alu_c)
# alu_add16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c)
# end alu_add16_fast
# alu_add16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c)
# end alu_add16_fast
# end alu_add32
movl (alu_s), %eax
# end alu_add
movl %eax, (R3)

# end emit addp

# emit/mov>indiri4(addp4(lshi4(indiri4(vregp(2)),indiri4(vregp(3))),indirp4(indirp4(addp4(lshi4(indiri4(addrfp4(i)),indiri4(vregp(3))),addrgp4(t))))))

# emit indiri

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indiri

# emit/mov>asgni4(addrlp4(d),indiri4(addp4(lshi4(indiri4(vregp(2)),indiri4(vregp(3))),indirp4(indirp4(addp4(lshi4(indiri4(addrfp4(i)),indiri4(vregp(3))),addrgp4(t)))))))

# emit asgni

# (ADDRL)
# (offset -4)
movl (fp), %eax
movl push(%eax), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (R3), %edx
movl %edx, (%eax)

# end emit asgni

# emit/mov>addrgp4(29)

# emit addrgp

movl $.LCS29, %eax
movl %eax, (R3)

# end emit addrgp

# emit/mov>argp4(addrgp4(29))

# emit argp

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argp

# emit/mov>addrlp4(d)

# emit addrlp

# (offset -4)
movl (fp), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indiri4(addrlp4(d))

# emit indiri

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indiri

# emit/mov>argi4(indiri4(addrlp4(d)))

# emit argi

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argi

# emit/mov>addrfp4(i)

# emit addrfp

# (offset 44)
movl (fp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (R3)

# end emit addrfp

# emit/mov>indiri4(addrfp4(i))

# emit indiri

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indiri

# emit/mov>asgni4(vregp(4),indiri4(addrfp4(i)))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>indiri4(vregp(4))

# emit/mov>argi4(indiri4(vregp(4)))

# emit argi

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argi

# emit/mov>indiri4(vregp(4))

# emit/mov>cnsti4(2)
movl $2, (R2)
# emit/mov>lshi4(indiri4(vregp(4)),cnsti4(2))

# emit lshi

movl (R3), %eax
movl (R2), %edx
# alu_lshu
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_clamp32
movl (alu_y), %eax
movl %eax, (alu_sx)
movl $0, (alu_sc)
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_sc+0), %al
movb (alu_sx+1+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_sc+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_sc+0), %al
movb (alu_sx+2+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_sc+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_sc+0), %al
movb (alu_sx+3+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_sc+0)
# end alu_bor8
movl (alu_sc), %eax
movb alu_true(%eax), %al
movl $0, (alu_sc)
movb %al, (alu_sc+1)
movb (alu_sx+0), %al
movb %al, (alu_sc+0)
movl (alu_sc), %eax
movl alu_clamp32(,%eax,4), %eax
movl %eax, (alu_y)
# end alu_clamp32
# alu_lshu32
movl $0, %eax
movl $0, (alu_s0)
movl $0, (alu_s1)
movl $0, (alu_s2)
movl $0, (alu_s3)
movl (alu_y), %edx
movl alu_lshu8(,%edx,4), %edx
movb (alu_x+0), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s0+0)
movb (alu_x+1), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s1+1)
movb (alu_x+2), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s2+2)
movb (alu_x+3), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s3+3)
# alu_bor32
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+0), %al
movb (alu_s1+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+1), %al
movb (alu_s1+1), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+1)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+2), %al
movb (alu_s1+2), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+2)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+3), %al
movb (alu_s1+3), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+3)
# end alu_bor8
# end alu_bor32
# alu_bor32
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+0), %al
movb (alu_s2+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+1), %al
movb (alu_s2+1), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+1)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+2), %al
movb (alu_s2+2), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+2)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+3), %al
movb (alu_s2+3), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+3)
# end alu_bor8
# end alu_bor32
# alu_bor32
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+0), %al
movb (alu_s3+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+1), %al
movb (alu_s3+1), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+1)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+2), %al
movb (alu_s3+2), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+2)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+3), %al
movb (alu_s3+3), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+3)
# end alu_bor8
# end alu_bor32
# end alu_lshu32
movl (alu_s), %eax
# end alu_lshu
movl %eax, (R3)

# end emit lshi

# emit/mov>addrgp4(t)

# emit addrgp

movl $t, %eax
movl %eax, (R2)

# end emit addrgp

# emit/mov>addp4(lshi4(indiri4(vregp(4)),cnsti4(2)),addrgp4(t))

# emit addp

movl (R3), %eax
movl (R2), %edx
# alu_add
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_add32
movl $0, %eax
movl $0, %ecx
movl $0, (alu_c)
# alu_add16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c)
# end alu_add16_fast
# alu_add16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c)
# end alu_add16_fast
# end alu_add32
movl (alu_s), %eax
# end alu_add
movl %eax, (R3)

# end emit addp

# emit/mov>indirp4(addp4(lshi4(indiri4(vregp(4)),cnsti4(2)),addrgp4(t)))

# emit indirp

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indirp

# emit/mov>cnsti4(4)
movl $4, (R2)
# emit/mov>addp4(indirp4(addp4(lshi4(indiri4(vregp(4)),cnsti4(2)),addrgp4(t))),cnsti4(4))

# emit addp

movl (R3), %eax
movl (R2), %edx
# alu_add
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_add32
movl $0, %eax
movl $0, %ecx
movl $0, (alu_c)
# alu_add16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c)
# end alu_add16_fast
# alu_add16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c)
# end alu_add16_fast
# end alu_add32
movl (alu_s), %eax
# end alu_add
movl %eax, (R3)

# end emit addp

# emit/mov>indiri4(addp4(indirp4(addp4(lshi4(indiri4(vregp(4)),cnsti4(2)),addrgp4(t))),cnsti4(4)))

# emit indiri

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indiri

# emit/mov>cnsti4(1)
movl $1, (R2)
# emit/mov>addi4(indiri4(addp4(indirp4(addp4(lshi4(indiri4(vregp(4)),cnsti4(2)),addrgp4(t))),cnsti4(4))),cnsti4(1))

# emit addi

movl (R3), %eax
movl (R2), %edx
# alu_add
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_add32
movl $0, %eax
movl $0, %ecx
movl $0, (alu_c)
# alu_add16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c)
# end alu_add16_fast
# alu_add16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c)
# end alu_add16_fast
# end alu_add32
movl (alu_s), %eax
# end alu_add
movl %eax, (R3)

# end emit addi

# emit/mov>argi4(addi4(indiri4(addp4(indirp4(addp4(lshi4(indiri4(vregp(4)),cnsti4(2)),addrgp4(t))),cnsti4(4))),cnsti4(1)))

# emit argi

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argi

# emit/mov>callv(addrgp4(text))

# emit callv

# call 'text'
# (direct call)
# text is internal
# push return
movl $.LCI30-0x80000000, %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# end push return

movl $text-0x80000000, %eax
# jmp_jumpv
movl %eax, (branch_temp)
# store target (branch_temp) (on)
movl (on), %eax
movl sel_target(,%eax,4), %eax
movl (branch_temp), %edx
movl %edx, (%eax)
# end store target
# store jmp regs (on)
movl (on), %ecx
movl $jmp_r0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (R0), %edx
movl %edx, 0(%eax)
movl (R1), %edx
movl %edx, 4(%eax)
movl (R2), %edx
movl %edx, 8(%eax)
movl (R3), %edx
movl %edx, 12(%eax)
movl $jmp_f0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (F0), %edx
movl %edx, 0(%eax)
movl (F1), %edx
movl %edx, 4(%eax)
movl (F2), %edx
movl %edx, 8(%eax)
movl $jmp_d0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (D0), %edx
movl %edx, 0(%eax)
movl (D0+4), %edx
movl %edx, 4(%eax)
movl (D1), %edx
movl %edx, 8(%eax)
movl (D1+4), %edx
movl %edx, 12(%eax)
movl (D2), %edx
movl %edx, 16(%eax)
movl (D2+4), %edx
movl %edx, 20(%eax)
# end store jmp regs
# execute off (on)
movl (on), %eax
movl sel_on(,%eax,4), %eax
movl $0, (%eax)
# end execute off
# end jmp_jumpv
.LCI30:
movl (target), %eax
movl $.LCI30-0x80000000, %edx
# alu_eq
movl %eax, (alu_x)
movl %edx, (alu_y)
movl $0, %eax
movl $0, %ecx
movl $0, %edx
movb (alu_x+0), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+0), %dl
movb (%ecx,%edx), %dl
movl %edx, (b0)
movb (alu_x+1), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+1), %dl
movb (%ecx,%edx), %dl
movl %edx, (b1)
movb (alu_x+2), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+2), %dl
movb (%ecx,%edx), %dl
movl %edx, (b2)
movb (alu_x+3), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+3), %dl
movb (%ecx,%edx), %dl
movl %edx, (b3)
# alu_bool
movl (b0), %eax
movl (b1), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b2), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b3), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
movl (b0), %eax
movl %eax, (b0)
# end alu_eq
# load jmp regs (b0)
movl (b0), %ecx
movl $R0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r0), %edx
movl %edx, (%eax)
movl $R1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r1), %edx
movl %edx, (%eax)
movl $R2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r2), %edx
movl %edx, (%eax)
movl $R3, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r3), %edx
movl %edx, (%eax)
movl $F0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f0), %edx
movl %edx, (%eax)
movl $F1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f1), %edx
movl %edx, (%eax)
movl $F2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f2), %edx
movl %edx, (%eax)
movl $D0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d0), %edx
movl %edx, (%eax)
movl (jmp_d0+4), %edx
movl %edx, 4(%eax)
movl $D1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d1), %edx
movl %edx, (%eax)
movl (jmp_d1+4), %edx
movl %edx, 4(%eax)
movl $D2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d2), %edx
movl %edx, (%eax)
movl (jmp_d2+4), %edx
movl %edx, 4(%eax)
# end load jmp regs
# execute on (b0)
movl (b0), %eax
movl sel_on(,%eax,4), %eax
movl $1, (%eax)
# end execute on
# pop args (16)
movl (sp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop args

# end emit callv

# emit/mov>addrlp4(d)

# emit addrlp

# (offset -4)
movl (fp), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indiri4(addrlp4(d))

# emit indiri

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R0)

# end emit indiri

# emit/mov>reti4(indiri4(addrlp4(d)))

# emit reti


# end emit reti

# emit/mov>labelv(28)

# emit labelv

.LCI28:
movl (target), %eax
movl $.LCI28-0x80000000, %edx
# alu_eq
movl %eax, (alu_x)
movl %edx, (alu_y)
movl $0, %eax
movl $0, %ecx
movl $0, %edx
movb (alu_x+0), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+0), %dl
movb (%ecx,%edx), %dl
movl %edx, (b0)
movb (alu_x+1), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+1), %dl
movb (%ecx,%edx), %dl
movl %edx, (b1)
movb (alu_x+2), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+2), %dl
movb (%ecx,%edx), %dl
movl %edx, (b2)
movb (alu_x+3), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+3), %dl
movb (%ecx,%edx), %dl
movl %edx, (b3)
# alu_bool
movl (b0), %eax
movl (b1), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b2), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b3), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
movl (b0), %eax
movl %eax, (b0)
# end alu_eq
# load jmp regs (b0)
movl (b0), %ecx
movl $R0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r0), %edx
movl %edx, (%eax)
movl $R1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r1), %edx
movl %edx, (%eax)
movl $R2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r2), %edx
movl %edx, (%eax)
movl $R3, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r3), %edx
movl %edx, (%eax)
movl $F0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f0), %edx
movl %edx, (%eax)
movl $F1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f1), %edx
movl %edx, (%eax)
movl $F2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f2), %edx
movl %edx, (%eax)
movl $D0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d0), %edx
movl %edx, (%eax)
movl (jmp_d0+4), %edx
movl %edx, 4(%eax)
movl $D1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d1), %edx
movl %edx, (%eax)
movl (jmp_d1+4), %edx
movl %edx, 4(%eax)
movl $D2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d2), %edx
movl %edx, (%eax)
movl (jmp_d2+4), %edx
movl %edx, 4(%eax)
# end load jmp regs
# execute on (b0)
movl (b0), %eax
movl sel_on(,%eax,4), %eax
movl $1, (%eax)
# end execute on

# end emit labelv

# epilogue
# movl %ebp, %esp
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (fp), %edx
movl %edx, (%eax)
# end movl %ebp, %esp
# pop8 D2
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl 4(%eax), %edx
movl %edx, (stack_temp+4)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $D2, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
movl (stack_temp+4), %edx
movl %edx, 4(%eax)
# end pop8
# pop8 D1
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl 4(%eax), %edx
movl %edx, (stack_temp+4)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $D1, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
movl (stack_temp+4), %edx
movl %edx, 4(%eax)
# end pop8
# pop F2
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $F2, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop
# pop F1
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $F1, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop
# pop R3
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $R3, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop
# pop R2
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $R2, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop
# pop R1
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $R1, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop
# pop fp
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $fp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop
# ret
# pop %eax
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl (stack_temp), %edx
movl %edx, %eax
# end pop
# jmp_jumpv
movl %eax, (branch_temp)
# store target (branch_temp) (on)
movl (on), %eax
movl sel_target(,%eax,4), %eax
movl (branch_temp), %edx
movl %edx, (%eax)
# end store target
# store jmp regs (on)
movl (on), %ecx
movl $jmp_r0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (R0), %edx
movl %edx, 0(%eax)
movl (R1), %edx
movl %edx, 4(%eax)
movl (R2), %edx
movl %edx, 8(%eax)
movl (R3), %edx
movl %edx, 12(%eax)
movl $jmp_f0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (F0), %edx
movl %edx, 0(%eax)
movl (F1), %edx
movl %edx, 4(%eax)
movl (F2), %edx
movl %edx, 8(%eax)
movl $jmp_d0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (D0), %edx
movl %edx, 0(%eax)
movl (D0+4), %edx
movl %edx, 4(%eax)
movl (D1), %edx
movl %edx, 8(%eax)
movl (D1+4), %edx
movl %edx, 12(%eax)
movl (D2), %edx
movl %edx, 16(%eax)
movl (D2+4), %edx
movl %edx, 20(%eax)
# end store jmp regs
# execute off (on)
movl (on), %eax
movl sel_on(,%eax,4), %eax
movl $0, (%eax)
# end execute off
# end jmp_jumpv
# end ret
.Lf31:
.size remove_disk,.Lf31-remove_disk

# export 'move'
.globl move
.type move,@function
move:  # <LCI>
# label
movl (target), %eax
movl $move-0x80000000, %edx
# alu_eq
movl %eax, (alu_x)
movl %edx, (alu_y)
movl $0, %eax
movl $0, %ecx
movl $0, %edx
movb (alu_x+0), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+0), %dl
movb (%ecx,%edx), %dl
movl %edx, (b0)
movb (alu_x+1), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+1), %dl
movb (%ecx,%edx), %dl
movl %edx, (b1)
movb (alu_x+2), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+2), %dl
movb (%ecx,%edx), %dl
movl %edx, (b2)
movb (alu_x+3), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+3), %dl
movb (%ecx,%edx), %dl
movl %edx, (b3)
# alu_bool
movl (b0), %eax
movl (b1), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b2), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b3), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
movl (b0), %eax
movl %eax, (b0)
# end alu_eq
# load jmp regs (b0)
movl (b0), %ecx
movl $R0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r0), %edx
movl %edx, (%eax)
movl $R1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r1), %edx
movl %edx, (%eax)
movl $R2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r2), %edx
movl %edx, (%eax)
movl $R3, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r3), %edx
movl %edx, (%eax)
movl $F0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f0), %edx
movl %edx, (%eax)
movl $F1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f1), %edx
movl %edx, (%eax)
movl $F2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f2), %edx
movl %edx, (%eax)
movl $D0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d0), %edx
movl %edx, (%eax)
movl (jmp_d0+4), %edx
movl %edx, 4(%eax)
movl $D1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d1), %edx
movl %edx, (%eax)
movl (jmp_d1+4), %edx
movl %edx, 4(%eax)
movl $D2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d2), %edx
movl %edx, (%eax)
movl (jmp_d2+4), %edx
movl %edx, 4(%eax)
# end load jmp regs
# execute on (b0)
movl (b0), %eax
movl sel_on(,%eax,4), %eax
movl $1, (%eax)
# end execute on
# end label
# prologue
# push (fp)
movl (fp), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# push (R1)
movl (R1), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# push (R2)
movl (R2), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# push (R3)
movl (R3), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# push (F1)
movl (F1), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# push (F2)
movl (F2), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# push D1
movl (D1), %eax
movl %eax, (stack_temp)
movl (D1+4), %eax
movl %eax, (stack_temp+4)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
movl (stack_temp+4), %edx
movl %edx, 4(%eax)
# end push
# push D2
movl (D2), %eax
movl %eax, (stack_temp)
movl (D2+4), %eax
movl %eax, (stack_temp+4)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
movl (stack_temp+4), %edx
movl %edx, 4(%eax)
# end push
# mov %esp, %ebp
movl $fp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl %edx, (%eax)
# end mov %esp, %ebp
# emit/mov>addrfp4(n)

# emit addrfp

# (offset 44)
movl (fp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (R3)

# end emit addrfp

# emit/mov>indiri4(addrfp4(n))

# emit indiri

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indiri

# emit/mov>cnsti4(0)
movl $0, (R2)
# emit/mov>nei4(indiri4(addrfp4(n)),cnsti4(0))

# emit nei

movl (R3), %eax
movl (R2), %edx
movl $.LCI33-0x80000000, %ecx
# jmp_nei
movl %ecx, (branch_temp)
# alu_cmp
movl %eax, (alu_x)
movl %edx, (alu_y)
movl %edx, (alu_t)
# alu_sub32
movl $0, %eax
movl $0, %ecx
movl $0x1, (alu_c)
# alu_sub16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movw alu_inv16(,%ecx,2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movl alu_add16(,%edx,4), %edx
movl (alu_c), %ecx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# alu_sub16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movw alu_inv16(,%ecx,2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movl alu_add16(,%edx,4), %edx
movl (alu_c), %ecx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_t), %eax
movl %eax, (alu_y)
movl $0, %eax
movb (alu_c), %al
movb alu_false(%eax), %al
movb %al, (cf)
movb (alu_s+3), %al
movl alu_b7(,%eax,4), %eax
movb %al, (sf)
movl $0, %eax
movl $0, %edx
movb (alu_s+0), %dl
movb alu_true(%edx,%eax), %al
movb (alu_s+1), %dl
movb alu_true(%edx,%eax), %al
movb (alu_s+2), %dl
movb alu_true(%edx,%eax), %al
movb (alu_s+3), %dl
movb alu_true(%edx,%eax), %al
movb alu_false(%eax), %al
movb %al, (zf)
movl $alu_cmp_of, %edx
movb (alu_x+3), %al
movl alu_b7(,%eax,4), %eax
movl (%edx,%eax,4), %edx
movb (alu_y+3), %al
movl alu_b7(,%eax,4), %eax
movl (%edx,%eax,4), %edx
movb (alu_s+3), %al
movl alu_b7(,%eax,4), %eax
movl (%edx,%eax,4), %edx
movl (%edx), %edx
movb %dl, (of)
# end alu_cmp
# alu_not
movl (zf), %eax
movl alu_false(,%eax,4), %eax
movl %eax, (b0)
# end alu_not
# alu_bool
movl (b0), %eax
movl (on), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# store target (branch_temp) (b0)
movl (b0), %eax
movl sel_target(,%eax,4), %eax
movl (branch_temp), %edx
movl %edx, (%eax)
# end store target
# store jmp regs (b0)
movl (b0), %ecx
movl $jmp_r0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (R0), %edx
movl %edx, 0(%eax)
movl (R1), %edx
movl %edx, 4(%eax)
movl (R2), %edx
movl %edx, 8(%eax)
movl (R3), %edx
movl %edx, 12(%eax)
movl $jmp_f0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (F0), %edx
movl %edx, 0(%eax)
movl (F1), %edx
movl %edx, 4(%eax)
movl (F2), %edx
movl %edx, 8(%eax)
movl $jmp_d0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (D0), %edx
movl %edx, 0(%eax)
movl (D0+4), %edx
movl %edx, 4(%eax)
movl (D1), %edx
movl %edx, 8(%eax)
movl (D1+4), %edx
movl %edx, 12(%eax)
movl (D2), %edx
movl %edx, 16(%eax)
movl (D2+4), %edx
movl %edx, 20(%eax)
# end store jmp regs
# execute off (b0)
movl (b0), %eax
movl sel_on(,%eax,4), %eax
movl $0, (%eax)
# end execute off
# end jmp_nei

# end emit nei

# emit/mov>jumpv(addrgp4(32))

# emit jumpv

# (direct jump)
movl $.LCI32-0x80000000, %eax
# jmp_jumpv
movl %eax, (branch_temp)
# store target (branch_temp) (on)
movl (on), %eax
movl sel_target(,%eax,4), %eax
movl (branch_temp), %edx
movl %edx, (%eax)
# end store target
# store jmp regs (on)
movl (on), %ecx
movl $jmp_r0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (R0), %edx
movl %edx, 0(%eax)
movl (R1), %edx
movl %edx, 4(%eax)
movl (R2), %edx
movl %edx, 8(%eax)
movl (R3), %edx
movl %edx, 12(%eax)
movl $jmp_f0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (F0), %edx
movl %edx, 0(%eax)
movl (F1), %edx
movl %edx, 4(%eax)
movl (F2), %edx
movl %edx, 8(%eax)
movl $jmp_d0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (D0), %edx
movl %edx, 0(%eax)
movl (D0+4), %edx
movl %edx, 4(%eax)
movl (D1), %edx
movl %edx, 8(%eax)
movl (D1+4), %edx
movl %edx, 12(%eax)
movl (D2), %edx
movl %edx, 16(%eax)
movl (D2+4), %edx
movl %edx, 20(%eax)
# end store jmp regs
# execute off (on)
movl (on), %eax
movl sel_on(,%eax,4), %eax
movl $0, (%eax)
# end execute off
# end jmp_jumpv

# end emit jumpv

# emit/mov>labelv(33)

# emit labelv

.LCI33:
movl (target), %eax
movl $.LCI33-0x80000000, %edx
# alu_eq
movl %eax, (alu_x)
movl %edx, (alu_y)
movl $0, %eax
movl $0, %ecx
movl $0, %edx
movb (alu_x+0), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+0), %dl
movb (%ecx,%edx), %dl
movl %edx, (b0)
movb (alu_x+1), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+1), %dl
movb (%ecx,%edx), %dl
movl %edx, (b1)
movb (alu_x+2), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+2), %dl
movb (%ecx,%edx), %dl
movl %edx, (b2)
movb (alu_x+3), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+3), %dl
movb (%ecx,%edx), %dl
movl %edx, (b3)
# alu_bool
movl (b0), %eax
movl (b1), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b2), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b3), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
movl (b0), %eax
movl %eax, (b0)
# end alu_eq
# load jmp regs (b0)
movl (b0), %ecx
movl $R0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r0), %edx
movl %edx, (%eax)
movl $R1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r1), %edx
movl %edx, (%eax)
movl $R2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r2), %edx
movl %edx, (%eax)
movl $R3, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r3), %edx
movl %edx, (%eax)
movl $F0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f0), %edx
movl %edx, (%eax)
movl $F1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f1), %edx
movl %edx, (%eax)
movl $F2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f2), %edx
movl %edx, (%eax)
movl $D0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d0), %edx
movl %edx, (%eax)
movl (jmp_d0+4), %edx
movl %edx, 4(%eax)
movl $D1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d1), %edx
movl %edx, (%eax)
movl (jmp_d1+4), %edx
movl %edx, 4(%eax)
movl $D2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d2), %edx
movl %edx, (%eax)
movl (jmp_d2+4), %edx
movl %edx, 4(%eax)
# end load jmp regs
# execute on (b0)
movl (b0), %eax
movl sel_on(,%eax,4), %eax
movl $1, (%eax)
# end execute on

# end emit labelv

# emit/mov>addrfp4(to)

# emit addrfp

# (offset 52)
movl (fp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (R3)

# end emit addrfp

# emit/mov>indiri4(addrfp4(to))

# emit indiri

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indiri

# emit/mov>argi4(indiri4(addrfp4(to)))

# emit argi

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argi

# emit/mov>addrfp4(via)

# emit addrfp

# (offset 56)
movl (fp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (R3)

# end emit addrfp

# emit/mov>indiri4(addrfp4(via))

# emit indiri

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indiri

# emit/mov>argi4(indiri4(addrfp4(via)))

# emit argi

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argi

# emit/mov>addrfp4(from)

# emit addrfp

# (offset 48)
movl (fp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (R3)

# end emit addrfp

# emit/mov>indiri4(addrfp4(from))

# emit indiri

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indiri

# emit/mov>argi4(indiri4(addrfp4(from)))

# emit argi

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argi

# emit/mov>addrfp4(n)

# emit addrfp

# (offset 44)
movl (fp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (R3)

# end emit addrfp

# emit/mov>indiri4(addrfp4(n))

# emit indiri

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indiri

# emit/mov>cnsti4(1)
movl $1, (R2)
# emit/mov>subi4(indiri4(addrfp4(n)),cnsti4(1))

# emit subi

movl (R3), %eax
movl (R2), %edx
# alu_sub
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_sub32
movl $0, %eax
movl $0, %ecx
movl $0x1, (alu_c)
# alu_sub16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movw alu_inv16(,%ecx,2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movl alu_add16(,%edx,4), %edx
movl (alu_c), %ecx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# alu_sub16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movw alu_inv16(,%ecx,2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movl alu_add16(,%edx,4), %edx
movl (alu_c), %ecx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_s), %eax
# end alu_sub
movl %eax, (R3)

# end emit subi

# emit/mov>argi4(subi4(indiri4(addrfp4(n)),cnsti4(1)))

# emit argi

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argi

# emit/mov>callv(addrgp4(move))

# emit callv

# call 'move'
# (direct call)
# move is internal
# push return
movl $.LCI35-0x80000000, %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# end push return

movl $move-0x80000000, %eax
# jmp_jumpv
movl %eax, (branch_temp)
# store target (branch_temp) (on)
movl (on), %eax
movl sel_target(,%eax,4), %eax
movl (branch_temp), %edx
movl %edx, (%eax)
# end store target
# store jmp regs (on)
movl (on), %ecx
movl $jmp_r0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (R0), %edx
movl %edx, 0(%eax)
movl (R1), %edx
movl %edx, 4(%eax)
movl (R2), %edx
movl %edx, 8(%eax)
movl (R3), %edx
movl %edx, 12(%eax)
movl $jmp_f0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (F0), %edx
movl %edx, 0(%eax)
movl (F1), %edx
movl %edx, 4(%eax)
movl (F2), %edx
movl %edx, 8(%eax)
movl $jmp_d0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (D0), %edx
movl %edx, 0(%eax)
movl (D0+4), %edx
movl %edx, 4(%eax)
movl (D1), %edx
movl %edx, 8(%eax)
movl (D1+4), %edx
movl %edx, 12(%eax)
movl (D2), %edx
movl %edx, 16(%eax)
movl (D2+4), %edx
movl %edx, 20(%eax)
# end store jmp regs
# execute off (on)
movl (on), %eax
movl sel_on(,%eax,4), %eax
movl $0, (%eax)
# end execute off
# end jmp_jumpv
.LCI35:
movl (target), %eax
movl $.LCI35-0x80000000, %edx
# alu_eq
movl %eax, (alu_x)
movl %edx, (alu_y)
movl $0, %eax
movl $0, %ecx
movl $0, %edx
movb (alu_x+0), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+0), %dl
movb (%ecx,%edx), %dl
movl %edx, (b0)
movb (alu_x+1), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+1), %dl
movb (%ecx,%edx), %dl
movl %edx, (b1)
movb (alu_x+2), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+2), %dl
movb (%ecx,%edx), %dl
movl %edx, (b2)
movb (alu_x+3), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+3), %dl
movb (%ecx,%edx), %dl
movl %edx, (b3)
# alu_bool
movl (b0), %eax
movl (b1), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b2), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b3), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
movl (b0), %eax
movl %eax, (b0)
# end alu_eq
# load jmp regs (b0)
movl (b0), %ecx
movl $R0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r0), %edx
movl %edx, (%eax)
movl $R1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r1), %edx
movl %edx, (%eax)
movl $R2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r2), %edx
movl %edx, (%eax)
movl $R3, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r3), %edx
movl %edx, (%eax)
movl $F0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f0), %edx
movl %edx, (%eax)
movl $F1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f1), %edx
movl %edx, (%eax)
movl $F2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f2), %edx
movl %edx, (%eax)
movl $D0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d0), %edx
movl %edx, (%eax)
movl (jmp_d0+4), %edx
movl %edx, 4(%eax)
movl $D1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d1), %edx
movl %edx, (%eax)
movl (jmp_d1+4), %edx
movl %edx, 4(%eax)
movl $D2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d2), %edx
movl %edx, (%eax)
movl (jmp_d2+4), %edx
movl %edx, 4(%eax)
# end load jmp regs
# execute on (b0)
movl (b0), %eax
movl sel_on(,%eax,4), %eax
movl $1, (%eax)
# end execute on
# pop args (16)
movl (sp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop args

# end emit callv

# emit/mov>addrfp4(from)

# emit addrfp

# (offset 48)
movl (fp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (R3)

# end emit addrfp

# emit/mov>indiri4(addrfp4(from))

# emit indiri

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indiri

# emit/mov>argi4(indiri4(addrfp4(from)))

# emit argi

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argi

# emit/mov>calli4(addrgp4(remove_disk))

# emit calli

# call 'remove_disk'
# (direct call)
# remove_disk is internal
# push return
movl $.LCI36-0x80000000, %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# end push return

movl $remove_disk-0x80000000, %eax
# jmp_jumpv
movl %eax, (branch_temp)
# store target (branch_temp) (on)
movl (on), %eax
movl sel_target(,%eax,4), %eax
movl (branch_temp), %edx
movl %edx, (%eax)
# end store target
# store jmp regs (on)
movl (on), %ecx
movl $jmp_r0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (R0), %edx
movl %edx, 0(%eax)
movl (R1), %edx
movl %edx, 4(%eax)
movl (R2), %edx
movl %edx, 8(%eax)
movl (R3), %edx
movl %edx, 12(%eax)
movl $jmp_f0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (F0), %edx
movl %edx, 0(%eax)
movl (F1), %edx
movl %edx, 4(%eax)
movl (F2), %edx
movl %edx, 8(%eax)
movl $jmp_d0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (D0), %edx
movl %edx, 0(%eax)
movl (D0+4), %edx
movl %edx, 4(%eax)
movl (D1), %edx
movl %edx, 8(%eax)
movl (D1+4), %edx
movl %edx, 12(%eax)
movl (D2), %edx
movl %edx, 16(%eax)
movl (D2+4), %edx
movl %edx, 20(%eax)
# end store jmp regs
# execute off (on)
movl (on), %eax
movl sel_on(,%eax,4), %eax
movl $0, (%eax)
# end execute off
# end jmp_jumpv
.LCI36:
movl (target), %eax
movl $.LCI36-0x80000000, %edx
# alu_eq
movl %eax, (alu_x)
movl %edx, (alu_y)
movl $0, %eax
movl $0, %ecx
movl $0, %edx
movb (alu_x+0), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+0), %dl
movb (%ecx,%edx), %dl
movl %edx, (b0)
movb (alu_x+1), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+1), %dl
movb (%ecx,%edx), %dl
movl %edx, (b1)
movb (alu_x+2), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+2), %dl
movb (%ecx,%edx), %dl
movl %edx, (b2)
movb (alu_x+3), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+3), %dl
movb (%ecx,%edx), %dl
movl %edx, (b3)
# alu_bool
movl (b0), %eax
movl (b1), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b2), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b3), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
movl (b0), %eax
movl %eax, (b0)
# end alu_eq
# load jmp regs (b0)
movl (b0), %ecx
movl $R0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r0), %edx
movl %edx, (%eax)
movl $R1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r1), %edx
movl %edx, (%eax)
movl $R2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r2), %edx
movl %edx, (%eax)
movl $R3, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r3), %edx
movl %edx, (%eax)
movl $F0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f0), %edx
movl %edx, (%eax)
movl $F1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f1), %edx
movl %edx, (%eax)
movl $F2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f2), %edx
movl %edx, (%eax)
movl $D0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d0), %edx
movl %edx, (%eax)
movl (jmp_d0+4), %edx
movl %edx, 4(%eax)
movl $D1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d1), %edx
movl %edx, (%eax)
movl (jmp_d1+4), %edx
movl %edx, 4(%eax)
movl $D2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d2), %edx
movl %edx, (%eax)
movl (jmp_d2+4), %edx
movl %edx, 4(%eax)
# end load jmp regs
# execute on (b0)
movl (b0), %eax
movl sel_on(,%eax,4), %eax
movl $1, (%eax)
# end execute on
# pop args (4)
movl (sp), %eax
movl pop(%eax), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop args

# end emit calli

# emit/mov>load(calli4(addrgp4(remove_disk)))

# emit loadi

movl (R0), %eax
movl %eax, (R3)

# end emit loadi

# emit/mov>asgni4(vregp(1),load(calli4(addrgp4(remove_disk))))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>indiri4(vregp(1))

# emit/mov>argi4(indiri4(vregp(1)))

# emit argi

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argi

# emit/mov>addrfp4(to)

# emit addrfp

# (offset 52)
movl (fp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (R3)

# end emit addrfp

# emit/mov>indiri4(addrfp4(to))

# emit indiri

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indiri

# emit/mov>argi4(indiri4(addrfp4(to)))

# emit argi

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argi

# emit/mov>callv(addrgp4(add_disk))

# emit callv

# call 'add_disk'
# (direct call)
# add_disk is internal
# push return
movl $.LCI37-0x80000000, %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# end push return

movl $add_disk-0x80000000, %eax
# jmp_jumpv
movl %eax, (branch_temp)
# store target (branch_temp) (on)
movl (on), %eax
movl sel_target(,%eax,4), %eax
movl (branch_temp), %edx
movl %edx, (%eax)
# end store target
# store jmp regs (on)
movl (on), %ecx
movl $jmp_r0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (R0), %edx
movl %edx, 0(%eax)
movl (R1), %edx
movl %edx, 4(%eax)
movl (R2), %edx
movl %edx, 8(%eax)
movl (R3), %edx
movl %edx, 12(%eax)
movl $jmp_f0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (F0), %edx
movl %edx, 0(%eax)
movl (F1), %edx
movl %edx, 4(%eax)
movl (F2), %edx
movl %edx, 8(%eax)
movl $jmp_d0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (D0), %edx
movl %edx, 0(%eax)
movl (D0+4), %edx
movl %edx, 4(%eax)
movl (D1), %edx
movl %edx, 8(%eax)
movl (D1+4), %edx
movl %edx, 12(%eax)
movl (D2), %edx
movl %edx, 16(%eax)
movl (D2+4), %edx
movl %edx, 20(%eax)
# end store jmp regs
# execute off (on)
movl (on), %eax
movl sel_on(,%eax,4), %eax
movl $0, (%eax)
# end execute off
# end jmp_jumpv
.LCI37:
movl (target), %eax
movl $.LCI37-0x80000000, %edx
# alu_eq
movl %eax, (alu_x)
movl %edx, (alu_y)
movl $0, %eax
movl $0, %ecx
movl $0, %edx
movb (alu_x+0), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+0), %dl
movb (%ecx,%edx), %dl
movl %edx, (b0)
movb (alu_x+1), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+1), %dl
movb (%ecx,%edx), %dl
movl %edx, (b1)
movb (alu_x+2), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+2), %dl
movb (%ecx,%edx), %dl
movl %edx, (b2)
movb (alu_x+3), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+3), %dl
movb (%ecx,%edx), %dl
movl %edx, (b3)
# alu_bool
movl (b0), %eax
movl (b1), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b2), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b3), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
movl (b0), %eax
movl %eax, (b0)
# end alu_eq
# load jmp regs (b0)
movl (b0), %ecx
movl $R0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r0), %edx
movl %edx, (%eax)
movl $R1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r1), %edx
movl %edx, (%eax)
movl $R2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r2), %edx
movl %edx, (%eax)
movl $R3, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r3), %edx
movl %edx, (%eax)
movl $F0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f0), %edx
movl %edx, (%eax)
movl $F1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f1), %edx
movl %edx, (%eax)
movl $F2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f2), %edx
movl %edx, (%eax)
movl $D0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d0), %edx
movl %edx, (%eax)
movl (jmp_d0+4), %edx
movl %edx, 4(%eax)
movl $D1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d1), %edx
movl %edx, (%eax)
movl (jmp_d1+4), %edx
movl %edx, 4(%eax)
movl $D2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d2), %edx
movl %edx, (%eax)
movl (jmp_d2+4), %edx
movl %edx, 4(%eax)
# end load jmp regs
# execute on (b0)
movl (b0), %eax
movl sel_on(,%eax,4), %eax
movl $1, (%eax)
# end execute on
# pop args (8)
movl (sp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop args

# end emit callv

# emit/mov>addrfp4(from)

# emit addrfp

# (offset 48)
movl (fp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (R3)

# end emit addrfp

# emit/mov>indiri4(addrfp4(from))

# emit indiri

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indiri

# emit/mov>argi4(indiri4(addrfp4(from)))

# emit argi

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argi

# emit/mov>addrfp4(to)

# emit addrfp

# (offset 52)
movl (fp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (R3)

# end emit addrfp

# emit/mov>indiri4(addrfp4(to))

# emit indiri

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indiri

# emit/mov>argi4(indiri4(addrfp4(to)))

# emit argi

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argi

# emit/mov>addrfp4(via)

# emit addrfp

# (offset 56)
movl (fp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (R3)

# end emit addrfp

# emit/mov>indiri4(addrfp4(via))

# emit indiri

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indiri

# emit/mov>argi4(indiri4(addrfp4(via)))

# emit argi

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argi

# emit/mov>addrfp4(n)

# emit addrfp

# (offset 44)
movl (fp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (R3)

# end emit addrfp

# emit/mov>indiri4(addrfp4(n))

# emit indiri

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indiri

# emit/mov>cnsti4(1)
movl $1, (R2)
# emit/mov>subi4(indiri4(addrfp4(n)),cnsti4(1))

# emit subi

movl (R3), %eax
movl (R2), %edx
# alu_sub
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_sub32
movl $0, %eax
movl $0, %ecx
movl $0x1, (alu_c)
# alu_sub16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movw alu_inv16(,%ecx,2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movl alu_add16(,%edx,4), %edx
movl (alu_c), %ecx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# alu_sub16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movw alu_inv16(,%ecx,2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movl alu_add16(,%edx,4), %edx
movl (alu_c), %ecx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_s), %eax
# end alu_sub
movl %eax, (R3)

# end emit subi

# emit/mov>argi4(subi4(indiri4(addrfp4(n)),cnsti4(1)))

# emit argi

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argi

# emit/mov>callv(addrgp4(move))

# emit callv

# call 'move'
# (direct call)
# move is internal
# push return
movl $.LCI38-0x80000000, %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# end push return

movl $move-0x80000000, %eax
# jmp_jumpv
movl %eax, (branch_temp)
# store target (branch_temp) (on)
movl (on), %eax
movl sel_target(,%eax,4), %eax
movl (branch_temp), %edx
movl %edx, (%eax)
# end store target
# store jmp regs (on)
movl (on), %ecx
movl $jmp_r0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (R0), %edx
movl %edx, 0(%eax)
movl (R1), %edx
movl %edx, 4(%eax)
movl (R2), %edx
movl %edx, 8(%eax)
movl (R3), %edx
movl %edx, 12(%eax)
movl $jmp_f0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (F0), %edx
movl %edx, 0(%eax)
movl (F1), %edx
movl %edx, 4(%eax)
movl (F2), %edx
movl %edx, 8(%eax)
movl $jmp_d0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (D0), %edx
movl %edx, 0(%eax)
movl (D0+4), %edx
movl %edx, 4(%eax)
movl (D1), %edx
movl %edx, 8(%eax)
movl (D1+4), %edx
movl %edx, 12(%eax)
movl (D2), %edx
movl %edx, 16(%eax)
movl (D2+4), %edx
movl %edx, 20(%eax)
# end store jmp regs
# execute off (on)
movl (on), %eax
movl sel_on(,%eax,4), %eax
movl $0, (%eax)
# end execute off
# end jmp_jumpv
.LCI38:
movl (target), %eax
movl $.LCI38-0x80000000, %edx
# alu_eq
movl %eax, (alu_x)
movl %edx, (alu_y)
movl $0, %eax
movl $0, %ecx
movl $0, %edx
movb (alu_x+0), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+0), %dl
movb (%ecx,%edx), %dl
movl %edx, (b0)
movb (alu_x+1), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+1), %dl
movb (%ecx,%edx), %dl
movl %edx, (b1)
movb (alu_x+2), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+2), %dl
movb (%ecx,%edx), %dl
movl %edx, (b2)
movb (alu_x+3), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+3), %dl
movb (%ecx,%edx), %dl
movl %edx, (b3)
# alu_bool
movl (b0), %eax
movl (b1), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b2), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b3), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
movl (b0), %eax
movl %eax, (b0)
# end alu_eq
# load jmp regs (b0)
movl (b0), %ecx
movl $R0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r0), %edx
movl %edx, (%eax)
movl $R1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r1), %edx
movl %edx, (%eax)
movl $R2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r2), %edx
movl %edx, (%eax)
movl $R3, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r3), %edx
movl %edx, (%eax)
movl $F0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f0), %edx
movl %edx, (%eax)
movl $F1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f1), %edx
movl %edx, (%eax)
movl $F2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f2), %edx
movl %edx, (%eax)
movl $D0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d0), %edx
movl %edx, (%eax)
movl (jmp_d0+4), %edx
movl %edx, 4(%eax)
movl $D1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d1), %edx
movl %edx, (%eax)
movl (jmp_d1+4), %edx
movl %edx, 4(%eax)
movl $D2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d2), %edx
movl %edx, (%eax)
movl (jmp_d2+4), %edx
movl %edx, 4(%eax)
# end load jmp regs
# execute on (b0)
movl (b0), %eax
movl sel_on(,%eax,4), %eax
movl $1, (%eax)
# end execute on
# pop args (16)
movl (sp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop args

# end emit callv

# emit/mov>labelv(32)

# emit labelv

.LCI32:
movl (target), %eax
movl $.LCI32-0x80000000, %edx
# alu_eq
movl %eax, (alu_x)
movl %edx, (alu_y)
movl $0, %eax
movl $0, %ecx
movl $0, %edx
movb (alu_x+0), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+0), %dl
movb (%ecx,%edx), %dl
movl %edx, (b0)
movb (alu_x+1), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+1), %dl
movb (%ecx,%edx), %dl
movl %edx, (b1)
movb (alu_x+2), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+2), %dl
movb (%ecx,%edx), %dl
movl %edx, (b2)
movb (alu_x+3), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+3), %dl
movb (%ecx,%edx), %dl
movl %edx, (b3)
# alu_bool
movl (b0), %eax
movl (b1), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b2), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b3), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
movl (b0), %eax
movl %eax, (b0)
# end alu_eq
# load jmp regs (b0)
movl (b0), %ecx
movl $R0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r0), %edx
movl %edx, (%eax)
movl $R1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r1), %edx
movl %edx, (%eax)
movl $R2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r2), %edx
movl %edx, (%eax)
movl $R3, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r3), %edx
movl %edx, (%eax)
movl $F0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f0), %edx
movl %edx, (%eax)
movl $F1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f1), %edx
movl %edx, (%eax)
movl $F2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f2), %edx
movl %edx, (%eax)
movl $D0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d0), %edx
movl %edx, (%eax)
movl (jmp_d0+4), %edx
movl %edx, 4(%eax)
movl $D1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d1), %edx
movl %edx, (%eax)
movl (jmp_d1+4), %edx
movl %edx, 4(%eax)
movl $D2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d2), %edx
movl %edx, (%eax)
movl (jmp_d2+4), %edx
movl %edx, 4(%eax)
# end load jmp regs
# execute on (b0)
movl (b0), %eax
movl sel_on(,%eax,4), %eax
movl $1, (%eax)
# end execute on

# end emit labelv

# epilogue
# movl %ebp, %esp
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (fp), %edx
movl %edx, (%eax)
# end movl %ebp, %esp
# pop8 D2
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl 4(%eax), %edx
movl %edx, (stack_temp+4)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $D2, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
movl (stack_temp+4), %edx
movl %edx, 4(%eax)
# end pop8
# pop8 D1
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl 4(%eax), %edx
movl %edx, (stack_temp+4)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $D1, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
movl (stack_temp+4), %edx
movl %edx, 4(%eax)
# end pop8
# pop F2
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $F2, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop
# pop F1
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $F1, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop
# pop R3
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $R3, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop
# pop R2
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $R2, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop
# pop R1
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $R1, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop
# pop fp
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $fp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop
# ret
# pop %eax
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl (stack_temp), %edx
movl %edx, %eax
# end pop
# jmp_jumpv
movl %eax, (branch_temp)
# store target (branch_temp) (on)
movl (on), %eax
movl sel_target(,%eax,4), %eax
movl (branch_temp), %edx
movl %edx, (%eax)
# end store target
# store jmp regs (on)
movl (on), %ecx
movl $jmp_r0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (R0), %edx
movl %edx, 0(%eax)
movl (R1), %edx
movl %edx, 4(%eax)
movl (R2), %edx
movl %edx, 8(%eax)
movl (R3), %edx
movl %edx, 12(%eax)
movl $jmp_f0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (F0), %edx
movl %edx, 0(%eax)
movl (F1), %edx
movl %edx, 4(%eax)
movl (F2), %edx
movl %edx, 8(%eax)
movl $jmp_d0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (D0), %edx
movl %edx, 0(%eax)
movl (D0+4), %edx
movl %edx, 4(%eax)
movl (D1), %edx
movl %edx, 8(%eax)
movl (D1+4), %edx
movl %edx, 12(%eax)
movl (D2), %edx
movl %edx, 16(%eax)
movl (D2+4), %edx
movl %edx, 20(%eax)
# end store jmp regs
# execute off (on)
movl (on), %eax
movl sel_on(,%eax,4), %eax
movl $0, (%eax)
# end execute off
# end jmp_jumpv
# end ret
.Lf39:
.size move,.Lf39-move

# export 'main'
.globl main
.type main,@function
main:  # <LCI>
# label
movl (target), %eax
movl $main-0x80000000, %edx
# alu_eq
movl %eax, (alu_x)
movl %edx, (alu_y)
movl $0, %eax
movl $0, %ecx
movl $0, %edx
movb (alu_x+0), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+0), %dl
movb (%ecx,%edx), %dl
movl %edx, (b0)
movb (alu_x+1), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+1), %dl
movb (%ecx,%edx), %dl
movl %edx, (b1)
movb (alu_x+2), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+2), %dl
movb (%ecx,%edx), %dl
movl %edx, (b2)
movb (alu_x+3), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+3), %dl
movb (%ecx,%edx), %dl
movl %edx, (b3)
# alu_bool
movl (b0), %eax
movl (b1), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b2), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b3), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
movl (b0), %eax
movl %eax, (b0)
# end alu_eq
# load jmp regs (b0)
movl (b0), %ecx
movl $R0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r0), %edx
movl %edx, (%eax)
movl $R1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r1), %edx
movl %edx, (%eax)
movl $R2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r2), %edx
movl %edx, (%eax)
movl $R3, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r3), %edx
movl %edx, (%eax)
movl $F0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f0), %edx
movl %edx, (%eax)
movl $F1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f1), %edx
movl %edx, (%eax)
movl $F2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f2), %edx
movl %edx, (%eax)
movl $D0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d0), %edx
movl %edx, (%eax)
movl (jmp_d0+4), %edx
movl %edx, 4(%eax)
movl $D1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d1), %edx
movl %edx, (%eax)
movl (jmp_d1+4), %edx
movl %edx, 4(%eax)
movl $D2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d2), %edx
movl %edx, (%eax)
movl (jmp_d2+4), %edx
movl %edx, 4(%eax)
# end load jmp regs
# execute on (b0)
movl (b0), %eax
movl sel_on(,%eax,4), %eax
movl $1, (%eax)
# end execute on
# end label
# prologue
# push (fp)
movl (fp), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# push (R1)
movl (R1), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# push (R2)
movl (R2), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# push (R3)
movl (R3), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# push (F1)
movl (F1), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# push (F2)
movl (F2), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# push D1
movl (D1), %eax
movl %eax, (stack_temp)
movl (D1+4), %eax
movl %eax, (stack_temp+4)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
movl (stack_temp+4), %edx
movl %edx, 4(%eax)
# end push
# push D2
movl (D2), %eax
movl %eax, (stack_temp)
movl (D2+4), %eax
movl %eax, (stack_temp+4)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
movl (stack_temp+4), %edx
movl %edx, 4(%eax)
# end push
# mov %esp, %ebp
movl $fp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl %edx, (%eax)
# end mov %esp, %ebp
# emit/mov>addrgp4(41)

# emit addrgp

movl $.LCS41, %eax
movl %eax, (R3)

# end emit addrgp

# emit/mov>argp4(addrgp4(41))

# emit argp

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argp

# emit/mov>calli4(addrgp4(puts))

# emit calli

# call 'puts'
# (direct call)
# puts is external
# push return
movl $.LCE54-0x80000000, %eax
# alu_add
movl %eax, (alu_x)
movl $0x80000000, (alu_y)
# alu_add32
movl $0, %eax
movl $0, %ecx
movl $0, (alu_c)
# alu_add16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c)
# end alu_add16_fast
# alu_add16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c)
# end alu_add16_fast
# end alu_add32
movl (alu_s), %eax
# end alu_add
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# end push return

# (external call)
movl (sp), %esp  # <REQ>
movl $puts, (external)
movl (on), %eax
movl fault(,%eax,4), %eax
movl (%eax), %eax
.LCE54:
# fix ret conv
movl %eax, (R0)  # <REQ>
# pop %eax
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl (stack_temp), %edx
movl %edx, %eax
# end pop
# end fix ret conv
# pop args (4)
movl (sp), %eax
movl pop(%eax), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop args

# end emit calli

# emit/mov>addrfp4(c)

# emit addrfp

# (offset 44)
movl (fp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (R3)

# end emit addrfp

# emit/mov>indiri4(addrfp4(c))

# emit indiri

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indiri

# emit/mov>cnsti4(1)
movl $1, (R2)
# emit/mov>lei4(indiri4(addrfp4(c)),cnsti4(1))

# emit lei

movl (R3), %eax
movl (R2), %edx
movl $.LCI44-0x80000000, %ecx
# jmp_lei
movl %ecx, (branch_temp)
# alu_cmp
movl %eax, (alu_x)
movl %edx, (alu_y)
movl %edx, (alu_t)
# alu_sub32
movl $0, %eax
movl $0, %ecx
movl $0x1, (alu_c)
# alu_sub16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movw alu_inv16(,%ecx,2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movl alu_add16(,%edx,4), %edx
movl (alu_c), %ecx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# alu_sub16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movw alu_inv16(,%ecx,2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movl alu_add16(,%edx,4), %edx
movl (alu_c), %ecx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_t), %eax
movl %eax, (alu_y)
movl $0, %eax
movb (alu_c), %al
movb alu_false(%eax), %al
movb %al, (cf)
movb (alu_s+3), %al
movl alu_b7(,%eax,4), %eax
movb %al, (sf)
movl $0, %eax
movl $0, %edx
movb (alu_s+0), %dl
movb alu_true(%edx,%eax), %al
movb (alu_s+1), %dl
movb alu_true(%edx,%eax), %al
movb (alu_s+2), %dl
movb alu_true(%edx,%eax), %al
movb (alu_s+3), %dl
movb alu_true(%edx,%eax), %al
movb alu_false(%eax), %al
movb %al, (zf)
movl $alu_cmp_of, %edx
movb (alu_x+3), %al
movl alu_b7(,%eax,4), %eax
movl (%edx,%eax,4), %edx
movb (alu_y+3), %al
movl alu_b7(,%eax,4), %eax
movl (%edx,%eax,4), %edx
movb (alu_s+3), %al
movl alu_b7(,%eax,4), %eax
movl (%edx,%eax,4), %edx
movl (%edx), %edx
movb %dl, (of)
# end alu_cmp
# alu_bool
movl (sf), %eax
movl (of), %edx
movl xor(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (zf), %edx
movl or(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (on), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# store target (branch_temp) (b0)
movl (b0), %eax
movl sel_target(,%eax,4), %eax
movl (branch_temp), %edx
movl %edx, (%eax)
# end store target
# store jmp regs (b0)
movl (b0), %ecx
movl $jmp_r0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (R0), %edx
movl %edx, 0(%eax)
movl (R1), %edx
movl %edx, 4(%eax)
movl (R2), %edx
movl %edx, 8(%eax)
movl (R3), %edx
movl %edx, 12(%eax)
movl $jmp_f0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (F0), %edx
movl %edx, 0(%eax)
movl (F1), %edx
movl %edx, 4(%eax)
movl (F2), %edx
movl %edx, 8(%eax)
movl $jmp_d0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (D0), %edx
movl %edx, 0(%eax)
movl (D0+4), %edx
movl %edx, 4(%eax)
movl (D1), %edx
movl %edx, 8(%eax)
movl (D1+4), %edx
movl %edx, 12(%eax)
movl (D2), %edx
movl %edx, 16(%eax)
movl (D2+4), %edx
movl %edx, 20(%eax)
# end store jmp regs
# execute off (b0)
movl (b0), %eax
movl sel_on(,%eax,4), %eax
movl $0, (%eax)
# end execute off
# end jmp_lei

# end emit lei

# emit/mov>addrfp4(v)

# emit addrfp

# (offset 48)
movl (fp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (R3)

# end emit addrfp

# emit/mov>indirp4(addrfp4(v))

# emit indirp

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indirp

# emit/mov>cnsti4(4)
movl $4, (R2)
# emit/mov>addp4(indirp4(addrfp4(v)),cnsti4(4))

# emit addp

movl (R3), %eax
movl (R2), %edx
# alu_add
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_add32
movl $0, %eax
movl $0, %ecx
movl $0, (alu_c)
# alu_add16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c)
# end alu_add16_fast
# alu_add16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c)
# end alu_add16_fast
# end alu_add32
movl (alu_s), %eax
# end alu_add
movl %eax, (R3)

# end emit addp

# emit/mov>indirp4(addp4(indirp4(addrfp4(v)),cnsti4(4)))

# emit indirp

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indirp

# emit/mov>argp4(indirp4(addp4(indirp4(addrfp4(v)),cnsti4(4))))

# emit argp

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argp

# emit/mov>calli4(addrgp4(atoi))

# emit calli

# call 'atoi'
# (direct call)
# atoi is external
# push return
movl $.LCE55-0x80000000, %eax
# alu_add
movl %eax, (alu_x)
movl $0x80000000, (alu_y)
# alu_add32
movl $0, %eax
movl $0, %ecx
movl $0, (alu_c)
# alu_add16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c)
# end alu_add16_fast
# alu_add16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c)
# end alu_add16_fast
# end alu_add32
movl (alu_s), %eax
# end alu_add
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# end push return

# (external call)
movl (sp), %esp  # <REQ>
movl $atoi, (external)
movl (on), %eax
movl fault(,%eax,4), %eax
movl (%eax), %eax
.LCE55:
# fix ret conv
movl %eax, (R0)  # <REQ>
# pop %eax
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl (stack_temp), %edx
movl %edx, %eax
# end pop
# end fix ret conv
# pop args (4)
movl (sp), %eax
movl pop(%eax), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop args

# end emit calli

# emit/mov>load(calli4(addrgp4(atoi)))

# emit loadi

movl (R0), %eax
movl %eax, (R3)

# end emit loadi

# emit/mov>asgni4(vregp(1),load(calli4(addrgp4(atoi))))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>addrgp4(height)

# emit addrgp

movl $height, %eax
movl %eax, (R2)

# end emit addrgp

# emit/mov>indiri4(vregp(1))

# emit/mov>asgni4(addrgp4(height),indiri4(vregp(1)))

# emit asgni

# (!ADDRL)
movl (R2), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (R3), %edx
movl %edx, (%eax)

# end emit asgni

# emit/mov>indiri4(vregp(1))

# emit/mov>cnsti4(0)
movl $0, (R2)
# emit/mov>gti4(indiri4(vregp(1)),cnsti4(0))

# emit gti

movl (R3), %eax
movl (R2), %edx
movl $.LCI42-0x80000000, %ecx
# jmp_gti
movl %ecx, (branch_temp)
# alu_cmp
movl %eax, (alu_x)
movl %edx, (alu_y)
movl %edx, (alu_t)
# alu_sub32
movl $0, %eax
movl $0, %ecx
movl $0x1, (alu_c)
# alu_sub16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movw alu_inv16(,%ecx,2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movl alu_add16(,%edx,4), %edx
movl (alu_c), %ecx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# alu_sub16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movw alu_inv16(,%ecx,2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movl alu_add16(,%edx,4), %edx
movl (alu_c), %ecx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_t), %eax
movl %eax, (alu_y)
movl $0, %eax
movb (alu_c), %al
movb alu_false(%eax), %al
movb %al, (cf)
movb (alu_s+3), %al
movl alu_b7(,%eax,4), %eax
movb %al, (sf)
movl $0, %eax
movl $0, %edx
movb (alu_s+0), %dl
movb alu_true(%edx,%eax), %al
movb (alu_s+1), %dl
movb alu_true(%edx,%eax), %al
movb (alu_s+2), %dl
movb alu_true(%edx,%eax), %al
movb (alu_s+3), %dl
movb alu_true(%edx,%eax), %al
movb alu_false(%eax), %al
movb %al, (zf)
movl $alu_cmp_of, %edx
movb (alu_x+3), %al
movl alu_b7(,%eax,4), %eax
movl (%edx,%eax,4), %edx
movb (alu_y+3), %al
movl alu_b7(,%eax,4), %eax
movl (%edx,%eax,4), %edx
movb (alu_s+3), %al
movl alu_b7(,%eax,4), %eax
movl (%edx,%eax,4), %edx
movl (%edx), %edx
movb %dl, (of)
# end alu_cmp
# alu_not
movl (zf), %eax
movl alu_false(,%eax,4), %eax
movl %eax, (b0)
# end alu_not
# alu_bool
movl (sf), %eax
movl (of), %edx
movl xnor(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b1)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b1), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (on), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# store target (branch_temp) (b0)
movl (b0), %eax
movl sel_target(,%eax,4), %eax
movl (branch_temp), %edx
movl %edx, (%eax)
# end store target
# store jmp regs (b0)
movl (b0), %ecx
movl $jmp_r0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (R0), %edx
movl %edx, 0(%eax)
movl (R1), %edx
movl %edx, 4(%eax)
movl (R2), %edx
movl %edx, 8(%eax)
movl (R3), %edx
movl %edx, 12(%eax)
movl $jmp_f0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (F0), %edx
movl %edx, 0(%eax)
movl (F1), %edx
movl %edx, 4(%eax)
movl (F2), %edx
movl %edx, 8(%eax)
movl $jmp_d0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (D0), %edx
movl %edx, 0(%eax)
movl (D0+4), %edx
movl %edx, 4(%eax)
movl (D1), %edx
movl %edx, 8(%eax)
movl (D1+4), %edx
movl %edx, 12(%eax)
movl (D2), %edx
movl %edx, 16(%eax)
movl (D2+4), %edx
movl %edx, 20(%eax)
# end store jmp regs
# execute off (b0)
movl (b0), %eax
movl sel_on(,%eax,4), %eax
movl $0, (%eax)
# end execute off
# end jmp_gti

# end emit gti

# emit/mov>labelv(44)

# emit labelv

.LCI44:
movl (target), %eax
movl $.LCI44-0x80000000, %edx
# alu_eq
movl %eax, (alu_x)
movl %edx, (alu_y)
movl $0, %eax
movl $0, %ecx
movl $0, %edx
movb (alu_x+0), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+0), %dl
movb (%ecx,%edx), %dl
movl %edx, (b0)
movb (alu_x+1), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+1), %dl
movb (%ecx,%edx), %dl
movl %edx, (b1)
movb (alu_x+2), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+2), %dl
movb (%ecx,%edx), %dl
movl %edx, (b2)
movb (alu_x+3), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+3), %dl
movb (%ecx,%edx), %dl
movl %edx, (b3)
# alu_bool
movl (b0), %eax
movl (b1), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b2), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b3), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
movl (b0), %eax
movl %eax, (b0)
# end alu_eq
# load jmp regs (b0)
movl (b0), %ecx
movl $R0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r0), %edx
movl %edx, (%eax)
movl $R1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r1), %edx
movl %edx, (%eax)
movl $R2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r2), %edx
movl %edx, (%eax)
movl $R3, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r3), %edx
movl %edx, (%eax)
movl $F0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f0), %edx
movl %edx, (%eax)
movl $F1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f1), %edx
movl %edx, (%eax)
movl $F2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f2), %edx
movl %edx, (%eax)
movl $D0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d0), %edx
movl %edx, (%eax)
movl (jmp_d0+4), %edx
movl %edx, 4(%eax)
movl $D1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d1), %edx
movl %edx, (%eax)
movl (jmp_d1+4), %edx
movl %edx, 4(%eax)
movl $D2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d2), %edx
movl %edx, (%eax)
movl (jmp_d2+4), %edx
movl %edx, 4(%eax)
# end load jmp regs
# execute on (b0)
movl (b0), %eax
movl sel_on(,%eax,4), %eax
movl $1, (%eax)
# end execute on

# end emit labelv

# emit/mov>addrgp4(height)

# emit addrgp

movl $height, %eax
movl %eax, (R3)

# end emit addrgp

# emit/mov>cnsti4(8)
movl $8, (R2)
# emit/mov>asgni4(addrgp4(height),cnsti4(8))

# emit asgni

# (!ADDRL)
movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (R2), %edx
movl %edx, (%eax)

# end emit asgni

# emit/mov>labelv(42)

# emit labelv

.LCI42:
movl (target), %eax
movl $.LCI42-0x80000000, %edx
# alu_eq
movl %eax, (alu_x)
movl %edx, (alu_y)
movl $0, %eax
movl $0, %ecx
movl $0, %edx
movb (alu_x+0), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+0), %dl
movb (%ecx,%edx), %dl
movl %edx, (b0)
movb (alu_x+1), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+1), %dl
movb (%ecx,%edx), %dl
movl %edx, (b1)
movb (alu_x+2), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+2), %dl
movb (%ecx,%edx), %dl
movl %edx, (b2)
movb (alu_x+3), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+3), %dl
movb (%ecx,%edx), %dl
movl %edx, (b3)
# alu_bool
movl (b0), %eax
movl (b1), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b2), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b3), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
movl (b0), %eax
movl %eax, (b0)
# end alu_eq
# load jmp regs (b0)
movl (b0), %ecx
movl $R0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r0), %edx
movl %edx, (%eax)
movl $R1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r1), %edx
movl %edx, (%eax)
movl $R2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r2), %edx
movl %edx, (%eax)
movl $R3, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r3), %edx
movl %edx, (%eax)
movl $F0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f0), %edx
movl %edx, (%eax)
movl $F1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f1), %edx
movl %edx, (%eax)
movl $F2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f2), %edx
movl %edx, (%eax)
movl $D0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d0), %edx
movl %edx, (%eax)
movl (jmp_d0+4), %edx
movl %edx, 4(%eax)
movl $D1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d1), %edx
movl %edx, (%eax)
movl (jmp_d1+4), %edx
movl %edx, 4(%eax)
movl $D2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d2), %edx
movl %edx, (%eax)
movl (jmp_d2+4), %edx
movl %edx, 4(%eax)
# end load jmp regs
# execute on (b0)
movl (b0), %eax
movl sel_on(,%eax,4), %eax
movl $1, (%eax)
# end execute on

# end emit labelv

# emit/mov>addrfp4(c)

# emit addrfp

# (offset 44)
movl (fp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (R3)

# end emit addrfp

# emit/mov>cnsti4(0)
movl $0, (R2)
# emit/mov>asgni4(addrfp4(c),cnsti4(0))

# emit asgni

# (!ADDRL)
movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (R2), %edx
movl %edx, (%eax)

# end emit asgni

# emit/mov>labelv(45)

# emit labelv

.LCI45:
movl (target), %eax
movl $.LCI45-0x80000000, %edx
# alu_eq
movl %eax, (alu_x)
movl %edx, (alu_y)
movl $0, %eax
movl $0, %ecx
movl $0, %edx
movb (alu_x+0), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+0), %dl
movb (%ecx,%edx), %dl
movl %edx, (b0)
movb (alu_x+1), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+1), %dl
movb (%ecx,%edx), %dl
movl %edx, (b1)
movb (alu_x+2), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+2), %dl
movb (%ecx,%edx), %dl
movl %edx, (b2)
movb (alu_x+3), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+3), %dl
movb (%ecx,%edx), %dl
movl %edx, (b3)
# alu_bool
movl (b0), %eax
movl (b1), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b2), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b3), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
movl (b0), %eax
movl %eax, (b0)
# end alu_eq
# load jmp regs (b0)
movl (b0), %ecx
movl $R0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r0), %edx
movl %edx, (%eax)
movl $R1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r1), %edx
movl %edx, (%eax)
movl $R2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r2), %edx
movl %edx, (%eax)
movl $R3, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r3), %edx
movl %edx, (%eax)
movl $F0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f0), %edx
movl %edx, (%eax)
movl $F1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f1), %edx
movl %edx, (%eax)
movl $F2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f2), %edx
movl %edx, (%eax)
movl $D0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d0), %edx
movl %edx, (%eax)
movl (jmp_d0+4), %edx
movl %edx, 4(%eax)
movl $D1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d1), %edx
movl %edx, (%eax)
movl (jmp_d1+4), %edx
movl %edx, 4(%eax)
movl $D2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d2), %edx
movl %edx, (%eax)
movl (jmp_d2+4), %edx
movl %edx, 4(%eax)
# end load jmp regs
# execute on (b0)
movl (b0), %eax
movl sel_on(,%eax,4), %eax
movl $1, (%eax)
# end execute on

# end emit labelv

# emit/mov>addrgp4(height)

# emit addrgp

movl $height, %eax
movl %eax, (R3)

# end emit addrgp

# emit/mov>indiri4(addrgp4(height))

# emit indiri

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indiri

# emit/mov>argi4(indiri4(addrgp4(height)))

# emit argi

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argi

# emit/mov>callp4(addrgp4(new_tower))

# emit callp

# call 'new_tower'
# (direct call)
# new_tower is internal
# push return
movl $.LCI56-0x80000000, %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# end push return

movl $new_tower-0x80000000, %eax
# jmp_jumpv
movl %eax, (branch_temp)
# store target (branch_temp) (on)
movl (on), %eax
movl sel_target(,%eax,4), %eax
movl (branch_temp), %edx
movl %edx, (%eax)
# end store target
# store jmp regs (on)
movl (on), %ecx
movl $jmp_r0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (R0), %edx
movl %edx, 0(%eax)
movl (R1), %edx
movl %edx, 4(%eax)
movl (R2), %edx
movl %edx, 8(%eax)
movl (R3), %edx
movl %edx, 12(%eax)
movl $jmp_f0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (F0), %edx
movl %edx, 0(%eax)
movl (F1), %edx
movl %edx, 4(%eax)
movl (F2), %edx
movl %edx, 8(%eax)
movl $jmp_d0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (D0), %edx
movl %edx, 0(%eax)
movl (D0+4), %edx
movl %edx, 4(%eax)
movl (D1), %edx
movl %edx, 8(%eax)
movl (D1+4), %edx
movl %edx, 12(%eax)
movl (D2), %edx
movl %edx, 16(%eax)
movl (D2+4), %edx
movl %edx, 20(%eax)
# end store jmp regs
# execute off (on)
movl (on), %eax
movl sel_on(,%eax,4), %eax
movl $0, (%eax)
# end execute off
# end jmp_jumpv
.LCI56:
movl (target), %eax
movl $.LCI56-0x80000000, %edx
# alu_eq
movl %eax, (alu_x)
movl %edx, (alu_y)
movl $0, %eax
movl $0, %ecx
movl $0, %edx
movb (alu_x+0), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+0), %dl
movb (%ecx,%edx), %dl
movl %edx, (b0)
movb (alu_x+1), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+1), %dl
movb (%ecx,%edx), %dl
movl %edx, (b1)
movb (alu_x+2), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+2), %dl
movb (%ecx,%edx), %dl
movl %edx, (b2)
movb (alu_x+3), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+3), %dl
movb (%ecx,%edx), %dl
movl %edx, (b3)
# alu_bool
movl (b0), %eax
movl (b1), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b2), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b3), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
movl (b0), %eax
movl %eax, (b0)
# end alu_eq
# load jmp regs (b0)
movl (b0), %ecx
movl $R0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r0), %edx
movl %edx, (%eax)
movl $R1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r1), %edx
movl %edx, (%eax)
movl $R2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r2), %edx
movl %edx, (%eax)
movl $R3, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r3), %edx
movl %edx, (%eax)
movl $F0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f0), %edx
movl %edx, (%eax)
movl $F1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f1), %edx
movl %edx, (%eax)
movl $F2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f2), %edx
movl %edx, (%eax)
movl $D0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d0), %edx
movl %edx, (%eax)
movl (jmp_d0+4), %edx
movl %edx, 4(%eax)
movl $D1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d1), %edx
movl %edx, (%eax)
movl (jmp_d1+4), %edx
movl %edx, 4(%eax)
movl $D2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d2), %edx
movl %edx, (%eax)
movl (jmp_d2+4), %edx
movl %edx, 4(%eax)
# end load jmp regs
# execute on (b0)
movl (b0), %eax
movl sel_on(,%eax,4), %eax
movl $1, (%eax)
# end execute on
# pop args (4)
movl (sp), %eax
movl pop(%eax), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop args

# end emit callp

# emit/mov>load(callp4(addrgp4(new_tower)))

# emit loadp

movl (R0), %eax
movl %eax, (R3)

# end emit loadp

# emit/mov>asgnp4(vregp(2),load(callp4(addrgp4(new_tower))))

# emit asgnp


# (emit vreg asgn)


# end emit asgnp

# emit/mov>addrfp4(c)

# emit addrfp

# (offset 44)
movl (fp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (R2)

# end emit addrfp

# emit/mov>indiri4(addrfp4(c))

# emit indiri

movl (R2), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R2)

# end emit indiri

# emit/mov>cnsti4(2)
movl $2, (R1)
# emit/mov>lshi4(indiri4(addrfp4(c)),cnsti4(2))

# emit lshi

movl (R2), %eax
movl (R1), %edx
# alu_lshu
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_clamp32
movl (alu_y), %eax
movl %eax, (alu_sx)
movl $0, (alu_sc)
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_sc+0), %al
movb (alu_sx+1+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_sc+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_sc+0), %al
movb (alu_sx+2+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_sc+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_sc+0), %al
movb (alu_sx+3+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_sc+0)
# end alu_bor8
movl (alu_sc), %eax
movb alu_true(%eax), %al
movl $0, (alu_sc)
movb %al, (alu_sc+1)
movb (alu_sx+0), %al
movb %al, (alu_sc+0)
movl (alu_sc), %eax
movl alu_clamp32(,%eax,4), %eax
movl %eax, (alu_y)
# end alu_clamp32
# alu_lshu32
movl $0, %eax
movl $0, (alu_s0)
movl $0, (alu_s1)
movl $0, (alu_s2)
movl $0, (alu_s3)
movl (alu_y), %edx
movl alu_lshu8(,%edx,4), %edx
movb (alu_x+0), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s0+0)
movb (alu_x+1), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s1+1)
movb (alu_x+2), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s2+2)
movb (alu_x+3), %al
movl (%edx,%eax,4), %ecx
movl %ecx, (alu_s3+3)
# alu_bor32
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+0), %al
movb (alu_s1+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+1), %al
movb (alu_s1+1), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+1)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+2), %al
movb (alu_s1+2), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+2)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s0+3), %al
movb (alu_s1+3), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+3)
# end alu_bor8
# end alu_bor32
# alu_bor32
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+0), %al
movb (alu_s2+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+1), %al
movb (alu_s2+1), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+1)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+2), %al
movb (alu_s2+2), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+2)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+3), %al
movb (alu_s2+3), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+3)
# end alu_bor8
# end alu_bor32
# alu_bor32
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+0), %al
movb (alu_s3+0), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+0)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+1), %al
movb (alu_s3+1), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+1)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+2), %al
movb (alu_s3+2), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+2)
# end alu_bor8
# alu_bor8
movl $0, %eax
movl $0, %edx
movb (alu_s+3), %al
movb (alu_s3+3), %dl
movl alu_bor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_s+3)
# end alu_bor8
# end alu_bor32
# end alu_lshu32
movl (alu_s), %eax
# end alu_lshu
movl %eax, (R2)

# end emit lshi

# emit/mov>addrgp4(t)

# emit addrgp

movl $t, %eax
movl %eax, (R1)

# end emit addrgp

# emit/mov>addp4(lshi4(indiri4(addrfp4(c)),cnsti4(2)),addrgp4(t))

# emit addp

movl (R2), %eax
movl (R1), %edx
# alu_add
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_add32
movl $0, %eax
movl $0, %ecx
movl $0, (alu_c)
# alu_add16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c)
# end alu_add16_fast
# alu_add16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c)
# end alu_add16_fast
# end alu_add32
movl (alu_s), %eax
# end alu_add
movl %eax, (R2)

# end emit addp

# emit/mov>indirp4(vregp(2))

# emit/mov>asgnp4(addp4(lshi4(indiri4(addrfp4(c)),cnsti4(2)),addrgp4(t)),indirp4(vregp(2)))

# emit asgnp

# (!ADDRL)
movl (R2), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (R3), %edx
movl %edx, (%eax)

# end emit asgnp

# emit/mov>labelv(46)

# emit labelv

.LCI46:
movl (target), %eax
movl $.LCI46-0x80000000, %edx
# alu_eq
movl %eax, (alu_x)
movl %edx, (alu_y)
movl $0, %eax
movl $0, %ecx
movl $0, %edx
movb (alu_x+0), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+0), %dl
movb (%ecx,%edx), %dl
movl %edx, (b0)
movb (alu_x+1), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+1), %dl
movb (%ecx,%edx), %dl
movl %edx, (b1)
movb (alu_x+2), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+2), %dl
movb (%ecx,%edx), %dl
movl %edx, (b2)
movb (alu_x+3), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+3), %dl
movb (%ecx,%edx), %dl
movl %edx, (b3)
# alu_bool
movl (b0), %eax
movl (b1), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b2), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b3), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
movl (b0), %eax
movl %eax, (b0)
# end alu_eq
# load jmp regs (b0)
movl (b0), %ecx
movl $R0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r0), %edx
movl %edx, (%eax)
movl $R1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r1), %edx
movl %edx, (%eax)
movl $R2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r2), %edx
movl %edx, (%eax)
movl $R3, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r3), %edx
movl %edx, (%eax)
movl $F0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f0), %edx
movl %edx, (%eax)
movl $F1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f1), %edx
movl %edx, (%eax)
movl $F2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f2), %edx
movl %edx, (%eax)
movl $D0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d0), %edx
movl %edx, (%eax)
movl (jmp_d0+4), %edx
movl %edx, 4(%eax)
movl $D1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d1), %edx
movl %edx, (%eax)
movl (jmp_d1+4), %edx
movl %edx, 4(%eax)
movl $D2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d2), %edx
movl %edx, (%eax)
movl (jmp_d2+4), %edx
movl %edx, 4(%eax)
# end load jmp regs
# execute on (b0)
movl (b0), %eax
movl sel_on(,%eax,4), %eax
movl $1, (%eax)
# end execute on

# end emit labelv

# emit/mov>addrfp4(c)

# emit addrfp

# (offset 44)
movl (fp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (R3)

# end emit addrfp

# emit/mov>addrfp4(c)

# emit addrfp

# (offset 44)
movl (fp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (R2)

# end emit addrfp

# emit/mov>indiri4(addrfp4(c))

# emit indiri

movl (R2), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R2)

# end emit indiri

# emit/mov>cnsti4(1)
movl $1, (R1)
# emit/mov>addi4(indiri4(addrfp4(c)),cnsti4(1))

# emit addi

movl (R2), %eax
movl (R1), %edx
# alu_add
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_add32
movl $0, %eax
movl $0, %ecx
movl $0, (alu_c)
# alu_add16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c)
# end alu_add16_fast
# alu_add16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movw (alu_c+2), %cx
movl alu_add16(,%edx,4), %edx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c)
# end alu_add16_fast
# end alu_add32
movl (alu_s), %eax
# end alu_add
movl %eax, (R2)

# end emit addi

# emit/mov>asgni4(addrfp4(c),addi4(indiri4(addrfp4(c)),cnsti4(1)))

# emit asgni

# (!ADDRL)
movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (R2), %edx
movl %edx, (%eax)

# end emit asgni

# emit/mov>addrfp4(c)

# emit addrfp

# (offset 44)
movl (fp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (R3)

# end emit addrfp

# emit/mov>indiri4(addrfp4(c))

# emit indiri

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indiri

# emit/mov>cnsti4(3)
movl $3, (R2)
# emit/mov>lti4(indiri4(addrfp4(c)),cnsti4(3))

# emit lti

movl (R3), %eax
movl (R2), %edx
movl $.LCI45-0x80000000, %ecx
# jmp_lti
movl %ecx, (branch_temp)
# alu_cmp
movl %eax, (alu_x)
movl %edx, (alu_y)
movl %edx, (alu_t)
# alu_sub32
movl $0, %eax
movl $0, %ecx
movl $0x1, (alu_c)
# alu_sub16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movw alu_inv16(,%ecx,2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movl alu_add16(,%edx,4), %edx
movl (alu_c), %ecx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# alu_sub16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movw alu_inv16(,%ecx,2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movl alu_add16(,%edx,4), %edx
movl (alu_c), %ecx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_t), %eax
movl %eax, (alu_y)
movl $0, %eax
movb (alu_c), %al
movb alu_false(%eax), %al
movb %al, (cf)
movb (alu_s+3), %al
movl alu_b7(,%eax,4), %eax
movb %al, (sf)
movl $0, %eax
movl $0, %edx
movb (alu_s+0), %dl
movb alu_true(%edx,%eax), %al
movb (alu_s+1), %dl
movb alu_true(%edx,%eax), %al
movb (alu_s+2), %dl
movb alu_true(%edx,%eax), %al
movb (alu_s+3), %dl
movb alu_true(%edx,%eax), %al
movb alu_false(%eax), %al
movb %al, (zf)
movl $alu_cmp_of, %edx
movb (alu_x+3), %al
movl alu_b7(,%eax,4), %eax
movl (%edx,%eax,4), %edx
movb (alu_y+3), %al
movl alu_b7(,%eax,4), %eax
movl (%edx,%eax,4), %edx
movb (alu_s+3), %al
movl alu_b7(,%eax,4), %eax
movl (%edx,%eax,4), %edx
movl (%edx), %edx
movb %dl, (of)
# end alu_cmp
# alu_bool
movl (sf), %eax
movl (of), %edx
movl xor(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (on), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# store target (branch_temp) (b0)
movl (b0), %eax
movl sel_target(,%eax,4), %eax
movl (branch_temp), %edx
movl %edx, (%eax)
# end store target
# store jmp regs (b0)
movl (b0), %ecx
movl $jmp_r0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (R0), %edx
movl %edx, 0(%eax)
movl (R1), %edx
movl %edx, 4(%eax)
movl (R2), %edx
movl %edx, 8(%eax)
movl (R3), %edx
movl %edx, 12(%eax)
movl $jmp_f0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (F0), %edx
movl %edx, 0(%eax)
movl (F1), %edx
movl %edx, 4(%eax)
movl (F2), %edx
movl %edx, 8(%eax)
movl $jmp_d0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (D0), %edx
movl %edx, 0(%eax)
movl (D0+4), %edx
movl %edx, 4(%eax)
movl (D1), %edx
movl %edx, 8(%eax)
movl (D1+4), %edx
movl %edx, 12(%eax)
movl (D2), %edx
movl %edx, 16(%eax)
movl (D2+4), %edx
movl %edx, 20(%eax)
# end store jmp regs
# execute off (b0)
movl (b0), %eax
movl sel_on(,%eax,4), %eax
movl $0, (%eax)
# end execute off
# end jmp_lti

# end emit lti

# emit/mov>addrfp4(c)

# emit addrfp

# (offset 44)
movl (fp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (R3)

# end emit addrfp

# emit/mov>addrgp4(height)

# emit addrgp

movl $height, %eax
movl %eax, (R2)

# end emit addrgp

# emit/mov>indiri4(addrgp4(height))

# emit indiri

movl (R2), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R2)

# end emit indiri

# emit/mov>asgni4(addrfp4(c),indiri4(addrgp4(height)))

# emit asgni

# (!ADDRL)
movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (R2), %edx
movl %edx, (%eax)

# end emit asgni

# emit/mov>jumpv(addrgp4(52))

# emit jumpv

# (direct jump)
movl $.LCI52-0x80000000, %eax
# jmp_jumpv
movl %eax, (branch_temp)
# store target (branch_temp) (on)
movl (on), %eax
movl sel_target(,%eax,4), %eax
movl (branch_temp), %edx
movl %edx, (%eax)
# end store target
# store jmp regs (on)
movl (on), %ecx
movl $jmp_r0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (R0), %edx
movl %edx, 0(%eax)
movl (R1), %edx
movl %edx, 4(%eax)
movl (R2), %edx
movl %edx, 8(%eax)
movl (R3), %edx
movl %edx, 12(%eax)
movl $jmp_f0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (F0), %edx
movl %edx, 0(%eax)
movl (F1), %edx
movl %edx, 4(%eax)
movl (F2), %edx
movl %edx, 8(%eax)
movl $jmp_d0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (D0), %edx
movl %edx, 0(%eax)
movl (D0+4), %edx
movl %edx, 4(%eax)
movl (D1), %edx
movl %edx, 8(%eax)
movl (D1+4), %edx
movl %edx, 12(%eax)
movl (D2), %edx
movl %edx, 16(%eax)
movl (D2+4), %edx
movl %edx, 20(%eax)
# end store jmp regs
# execute off (on)
movl (on), %eax
movl sel_on(,%eax,4), %eax
movl $0, (%eax)
# end execute off
# end jmp_jumpv

# end emit jumpv

# emit/mov>labelv(49)

# emit labelv

.LCI49:
movl (target), %eax
movl $.LCI49-0x80000000, %edx
# alu_eq
movl %eax, (alu_x)
movl %edx, (alu_y)
movl $0, %eax
movl $0, %ecx
movl $0, %edx
movb (alu_x+0), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+0), %dl
movb (%ecx,%edx), %dl
movl %edx, (b0)
movb (alu_x+1), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+1), %dl
movb (%ecx,%edx), %dl
movl %edx, (b1)
movb (alu_x+2), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+2), %dl
movb (%ecx,%edx), %dl
movl %edx, (b2)
movb (alu_x+3), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+3), %dl
movb (%ecx,%edx), %dl
movl %edx, (b3)
# alu_bool
movl (b0), %eax
movl (b1), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b2), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b3), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
movl (b0), %eax
movl %eax, (b0)
# end alu_eq
# load jmp regs (b0)
movl (b0), %ecx
movl $R0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r0), %edx
movl %edx, (%eax)
movl $R1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r1), %edx
movl %edx, (%eax)
movl $R2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r2), %edx
movl %edx, (%eax)
movl $R3, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r3), %edx
movl %edx, (%eax)
movl $F0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f0), %edx
movl %edx, (%eax)
movl $F1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f1), %edx
movl %edx, (%eax)
movl $F2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f2), %edx
movl %edx, (%eax)
movl $D0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d0), %edx
movl %edx, (%eax)
movl (jmp_d0+4), %edx
movl %edx, 4(%eax)
movl $D1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d1), %edx
movl %edx, (%eax)
movl (jmp_d1+4), %edx
movl %edx, 4(%eax)
movl $D2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d2), %edx
movl %edx, (%eax)
movl (jmp_d2+4), %edx
movl %edx, 4(%eax)
# end load jmp regs
# execute on (b0)
movl (b0), %eax
movl sel_on(,%eax,4), %eax
movl $1, (%eax)
# end execute on

# end emit labelv

# emit/mov>addrfp4(c)

# emit addrfp

# (offset 44)
movl (fp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (R3)

# end emit addrfp

# emit/mov>indiri4(addrfp4(c))

# emit indiri

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indiri

# emit/mov>argi4(indiri4(addrfp4(c)))

# emit argi

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argi

# emit/mov>cnsti4(0)
movl $0, (R3)
# emit/mov>argi4(cnsti4(0))

# emit argi

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argi

# emit/mov>callv(addrgp4(add_disk))

# emit callv

# call 'add_disk'
# (direct call)
# add_disk is internal
# push return
movl $.LCI57-0x80000000, %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# end push return

movl $add_disk-0x80000000, %eax
# jmp_jumpv
movl %eax, (branch_temp)
# store target (branch_temp) (on)
movl (on), %eax
movl sel_target(,%eax,4), %eax
movl (branch_temp), %edx
movl %edx, (%eax)
# end store target
# store jmp regs (on)
movl (on), %ecx
movl $jmp_r0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (R0), %edx
movl %edx, 0(%eax)
movl (R1), %edx
movl %edx, 4(%eax)
movl (R2), %edx
movl %edx, 8(%eax)
movl (R3), %edx
movl %edx, 12(%eax)
movl $jmp_f0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (F0), %edx
movl %edx, 0(%eax)
movl (F1), %edx
movl %edx, 4(%eax)
movl (F2), %edx
movl %edx, 8(%eax)
movl $jmp_d0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (D0), %edx
movl %edx, 0(%eax)
movl (D0+4), %edx
movl %edx, 4(%eax)
movl (D1), %edx
movl %edx, 8(%eax)
movl (D1+4), %edx
movl %edx, 12(%eax)
movl (D2), %edx
movl %edx, 16(%eax)
movl (D2+4), %edx
movl %edx, 20(%eax)
# end store jmp regs
# execute off (on)
movl (on), %eax
movl sel_on(,%eax,4), %eax
movl $0, (%eax)
# end execute off
# end jmp_jumpv
.LCI57:
movl (target), %eax
movl $.LCI57-0x80000000, %edx
# alu_eq
movl %eax, (alu_x)
movl %edx, (alu_y)
movl $0, %eax
movl $0, %ecx
movl $0, %edx
movb (alu_x+0), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+0), %dl
movb (%ecx,%edx), %dl
movl %edx, (b0)
movb (alu_x+1), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+1), %dl
movb (%ecx,%edx), %dl
movl %edx, (b1)
movb (alu_x+2), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+2), %dl
movb (%ecx,%edx), %dl
movl %edx, (b2)
movb (alu_x+3), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+3), %dl
movb (%ecx,%edx), %dl
movl %edx, (b3)
# alu_bool
movl (b0), %eax
movl (b1), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b2), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b3), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
movl (b0), %eax
movl %eax, (b0)
# end alu_eq
# load jmp regs (b0)
movl (b0), %ecx
movl $R0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r0), %edx
movl %edx, (%eax)
movl $R1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r1), %edx
movl %edx, (%eax)
movl $R2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r2), %edx
movl %edx, (%eax)
movl $R3, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r3), %edx
movl %edx, (%eax)
movl $F0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f0), %edx
movl %edx, (%eax)
movl $F1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f1), %edx
movl %edx, (%eax)
movl $F2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f2), %edx
movl %edx, (%eax)
movl $D0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d0), %edx
movl %edx, (%eax)
movl (jmp_d0+4), %edx
movl %edx, 4(%eax)
movl $D1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d1), %edx
movl %edx, (%eax)
movl (jmp_d1+4), %edx
movl %edx, 4(%eax)
movl $D2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d2), %edx
movl %edx, (%eax)
movl (jmp_d2+4), %edx
movl %edx, 4(%eax)
# end load jmp regs
# execute on (b0)
movl (b0), %eax
movl sel_on(,%eax,4), %eax
movl $1, (%eax)
# end execute on
# pop args (8)
movl (sp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop args

# end emit callv

# emit/mov>labelv(50)

# emit labelv

.LCI50:
movl (target), %eax
movl $.LCI50-0x80000000, %edx
# alu_eq
movl %eax, (alu_x)
movl %edx, (alu_y)
movl $0, %eax
movl $0, %ecx
movl $0, %edx
movb (alu_x+0), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+0), %dl
movb (%ecx,%edx), %dl
movl %edx, (b0)
movb (alu_x+1), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+1), %dl
movb (%ecx,%edx), %dl
movl %edx, (b1)
movb (alu_x+2), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+2), %dl
movb (%ecx,%edx), %dl
movl %edx, (b2)
movb (alu_x+3), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+3), %dl
movb (%ecx,%edx), %dl
movl %edx, (b3)
# alu_bool
movl (b0), %eax
movl (b1), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b2), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b3), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
movl (b0), %eax
movl %eax, (b0)
# end alu_eq
# load jmp regs (b0)
movl (b0), %ecx
movl $R0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r0), %edx
movl %edx, (%eax)
movl $R1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r1), %edx
movl %edx, (%eax)
movl $R2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r2), %edx
movl %edx, (%eax)
movl $R3, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r3), %edx
movl %edx, (%eax)
movl $F0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f0), %edx
movl %edx, (%eax)
movl $F1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f1), %edx
movl %edx, (%eax)
movl $F2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f2), %edx
movl %edx, (%eax)
movl $D0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d0), %edx
movl %edx, (%eax)
movl (jmp_d0+4), %edx
movl %edx, 4(%eax)
movl $D1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d1), %edx
movl %edx, (%eax)
movl (jmp_d1+4), %edx
movl %edx, 4(%eax)
movl $D2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d2), %edx
movl %edx, (%eax)
movl (jmp_d2+4), %edx
movl %edx, 4(%eax)
# end load jmp regs
# execute on (b0)
movl (b0), %eax
movl sel_on(,%eax,4), %eax
movl $1, (%eax)
# end execute on

# end emit labelv

# emit/mov>addrfp4(c)

# emit addrfp

# (offset 44)
movl (fp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (R3)

# end emit addrfp

# emit/mov>addrfp4(c)

# emit addrfp

# (offset 44)
movl (fp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (R2)

# end emit addrfp

# emit/mov>indiri4(addrfp4(c))

# emit indiri

movl (R2), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R2)

# end emit indiri

# emit/mov>cnsti4(1)
movl $1, (R1)
# emit/mov>subi4(indiri4(addrfp4(c)),cnsti4(1))

# emit subi

movl (R2), %eax
movl (R1), %edx
# alu_sub
movl %eax, (alu_x)
movl %edx, (alu_y)
# alu_sub32
movl $0, %eax
movl $0, %ecx
movl $0x1, (alu_c)
# alu_sub16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movw alu_inv16(,%ecx,2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movl alu_add16(,%edx,4), %edx
movl (alu_c), %ecx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# alu_sub16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movw alu_inv16(,%ecx,2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movl alu_add16(,%edx,4), %edx
movl (alu_c), %ecx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_s), %eax
# end alu_sub
movl %eax, (R2)

# end emit subi

# emit/mov>asgni4(addrfp4(c),subi4(indiri4(addrfp4(c)),cnsti4(1)))

# emit asgni

# (!ADDRL)
movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (R2), %edx
movl %edx, (%eax)

# end emit asgni

# emit/mov>labelv(52)

# emit labelv

.LCI52:
movl (target), %eax
movl $.LCI52-0x80000000, %edx
# alu_eq
movl %eax, (alu_x)
movl %edx, (alu_y)
movl $0, %eax
movl $0, %ecx
movl $0, %edx
movb (alu_x+0), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+0), %dl
movb (%ecx,%edx), %dl
movl %edx, (b0)
movb (alu_x+1), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+1), %dl
movb (%ecx,%edx), %dl
movl %edx, (b1)
movb (alu_x+2), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+2), %dl
movb (%ecx,%edx), %dl
movl %edx, (b2)
movb (alu_x+3), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+3), %dl
movb (%ecx,%edx), %dl
movl %edx, (b3)
# alu_bool
movl (b0), %eax
movl (b1), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b2), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b3), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
movl (b0), %eax
movl %eax, (b0)
# end alu_eq
# load jmp regs (b0)
movl (b0), %ecx
movl $R0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r0), %edx
movl %edx, (%eax)
movl $R1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r1), %edx
movl %edx, (%eax)
movl $R2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r2), %edx
movl %edx, (%eax)
movl $R3, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r3), %edx
movl %edx, (%eax)
movl $F0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f0), %edx
movl %edx, (%eax)
movl $F1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f1), %edx
movl %edx, (%eax)
movl $F2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f2), %edx
movl %edx, (%eax)
movl $D0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d0), %edx
movl %edx, (%eax)
movl (jmp_d0+4), %edx
movl %edx, 4(%eax)
movl $D1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d1), %edx
movl %edx, (%eax)
movl (jmp_d1+4), %edx
movl %edx, 4(%eax)
movl $D2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d2), %edx
movl %edx, (%eax)
movl (jmp_d2+4), %edx
movl %edx, 4(%eax)
# end load jmp regs
# execute on (b0)
movl (b0), %eax
movl sel_on(,%eax,4), %eax
movl $1, (%eax)
# end execute on

# end emit labelv

# emit/mov>addrfp4(c)

# emit addrfp

# (offset 44)
movl (fp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (R3)

# end emit addrfp

# emit/mov>indiri4(addrfp4(c))

# emit indiri

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indiri

# emit/mov>cnsti4(0)
movl $0, (R2)
# emit/mov>nei4(indiri4(addrfp4(c)),cnsti4(0))

# emit nei

movl (R3), %eax
movl (R2), %edx
movl $.LCI49-0x80000000, %ecx
# jmp_nei
movl %ecx, (branch_temp)
# alu_cmp
movl %eax, (alu_x)
movl %edx, (alu_y)
movl %edx, (alu_t)
# alu_sub32
movl $0, %eax
movl $0, %ecx
movl $0x1, (alu_c)
# alu_sub16_fast
movw (alu_x+0), %ax
movw (alu_y+0), %cx
movw alu_inv16(,%ecx,2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movl alu_add16(,%edx,4), %edx
movl (alu_c), %ecx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+0)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# alu_sub16_fast
movw (alu_x+2), %ax
movw (alu_y+2), %cx
movw alu_inv16(,%ecx,2), %cx
movl alu_add16(,%eax,4), %edx
movl (%edx,%ecx,4), %edx
movl alu_add16(,%edx,4), %edx
movl (alu_c), %ecx
movl (%edx,%ecx,4), %edx
movw %dx, (alu_s+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_t), %eax
movl %eax, (alu_y)
movl $0, %eax
movb (alu_c), %al
movb alu_false(%eax), %al
movb %al, (cf)
movb (alu_s+3), %al
movl alu_b7(,%eax,4), %eax
movb %al, (sf)
movl $0, %eax
movl $0, %edx
movb (alu_s+0), %dl
movb alu_true(%edx,%eax), %al
movb (alu_s+1), %dl
movb alu_true(%edx,%eax), %al
movb (alu_s+2), %dl
movb alu_true(%edx,%eax), %al
movb (alu_s+3), %dl
movb alu_true(%edx,%eax), %al
movb alu_false(%eax), %al
movb %al, (zf)
movl $alu_cmp_of, %edx
movb (alu_x+3), %al
movl alu_b7(,%eax,4), %eax
movl (%edx,%eax,4), %edx
movb (alu_y+3), %al
movl alu_b7(,%eax,4), %eax
movl (%edx,%eax,4), %edx
movb (alu_s+3), %al
movl alu_b7(,%eax,4), %eax
movl (%edx,%eax,4), %edx
movl (%edx), %edx
movb %dl, (of)
# end alu_cmp
# alu_not
movl (zf), %eax
movl alu_false(,%eax,4), %eax
movl %eax, (b0)
# end alu_not
# alu_bool
movl (b0), %eax
movl (on), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# store target (branch_temp) (b0)
movl (b0), %eax
movl sel_target(,%eax,4), %eax
movl (branch_temp), %edx
movl %edx, (%eax)
# end store target
# store jmp regs (b0)
movl (b0), %ecx
movl $jmp_r0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (R0), %edx
movl %edx, 0(%eax)
movl (R1), %edx
movl %edx, 4(%eax)
movl (R2), %edx
movl %edx, 8(%eax)
movl (R3), %edx
movl %edx, 12(%eax)
movl $jmp_f0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (F0), %edx
movl %edx, 0(%eax)
movl (F1), %edx
movl %edx, 4(%eax)
movl (F2), %edx
movl %edx, 8(%eax)
movl $jmp_d0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (D0), %edx
movl %edx, 0(%eax)
movl (D0+4), %edx
movl %edx, 4(%eax)
movl (D1), %edx
movl %edx, 8(%eax)
movl (D1+4), %edx
movl %edx, 12(%eax)
movl (D2), %edx
movl %edx, 16(%eax)
movl (D2+4), %edx
movl %edx, 20(%eax)
# end store jmp regs
# execute off (b0)
movl (b0), %eax
movl sel_on(,%eax,4), %eax
movl $0, (%eax)
# end execute off
# end jmp_nei

# end emit nei

# emit/mov>cnsti4(1)
movl $1, (R3)
# emit/mov>argi4(cnsti4(1))

# emit argi

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argi

# emit/mov>cnsti4(2)
movl $2, (R3)
# emit/mov>argi4(cnsti4(2))

# emit argi

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argi

# emit/mov>cnsti4(0)
movl $0, (R3)
# emit/mov>argi4(cnsti4(0))

# emit argi

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argi

# emit/mov>addrgp4(height)

# emit addrgp

movl $height, %eax
movl %eax, (R3)

# end emit addrgp

# emit/mov>indiri4(addrgp4(height))

# emit indiri

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R3)

# end emit indiri

# emit/mov>argi4(indiri4(addrgp4(height)))

# emit argi

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argi

# emit/mov>callv(addrgp4(move))

# emit callv

# call 'move'
# (direct call)
# move is internal
# push return
movl $.LCI58-0x80000000, %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# end push return

movl $move-0x80000000, %eax
# jmp_jumpv
movl %eax, (branch_temp)
# store target (branch_temp) (on)
movl (on), %eax
movl sel_target(,%eax,4), %eax
movl (branch_temp), %edx
movl %edx, (%eax)
# end store target
# store jmp regs (on)
movl (on), %ecx
movl $jmp_r0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (R0), %edx
movl %edx, 0(%eax)
movl (R1), %edx
movl %edx, 4(%eax)
movl (R2), %edx
movl %edx, 8(%eax)
movl (R3), %edx
movl %edx, 12(%eax)
movl $jmp_f0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (F0), %edx
movl %edx, 0(%eax)
movl (F1), %edx
movl %edx, 4(%eax)
movl (F2), %edx
movl %edx, 8(%eax)
movl $jmp_d0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (D0), %edx
movl %edx, 0(%eax)
movl (D0+4), %edx
movl %edx, 4(%eax)
movl (D1), %edx
movl %edx, 8(%eax)
movl (D1+4), %edx
movl %edx, 12(%eax)
movl (D2), %edx
movl %edx, 16(%eax)
movl (D2+4), %edx
movl %edx, 20(%eax)
# end store jmp regs
# execute off (on)
movl (on), %eax
movl sel_on(,%eax,4), %eax
movl $0, (%eax)
# end execute off
# end jmp_jumpv
.LCI58:
movl (target), %eax
movl $.LCI58-0x80000000, %edx
# alu_eq
movl %eax, (alu_x)
movl %edx, (alu_y)
movl $0, %eax
movl $0, %ecx
movl $0, %edx
movb (alu_x+0), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+0), %dl
movb (%ecx,%edx), %dl
movl %edx, (b0)
movb (alu_x+1), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+1), %dl
movb (%ecx,%edx), %dl
movl %edx, (b1)
movb (alu_x+2), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+2), %dl
movb (%ecx,%edx), %dl
movl %edx, (b2)
movb (alu_x+3), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+3), %dl
movb (%ecx,%edx), %dl
movl %edx, (b3)
# alu_bool
movl (b0), %eax
movl (b1), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b2), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b3), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
movl (b0), %eax
movl %eax, (b0)
# end alu_eq
# load jmp regs (b0)
movl (b0), %ecx
movl $R0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r0), %edx
movl %edx, (%eax)
movl $R1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r1), %edx
movl %edx, (%eax)
movl $R2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r2), %edx
movl %edx, (%eax)
movl $R3, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r3), %edx
movl %edx, (%eax)
movl $F0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f0), %edx
movl %edx, (%eax)
movl $F1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f1), %edx
movl %edx, (%eax)
movl $F2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f2), %edx
movl %edx, (%eax)
movl $D0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d0), %edx
movl %edx, (%eax)
movl (jmp_d0+4), %edx
movl %edx, 4(%eax)
movl $D1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d1), %edx
movl %edx, (%eax)
movl (jmp_d1+4), %edx
movl %edx, 4(%eax)
movl $D2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d2), %edx
movl %edx, (%eax)
movl (jmp_d2+4), %edx
movl %edx, 4(%eax)
# end load jmp regs
# execute on (b0)
movl (b0), %eax
movl sel_on(,%eax,4), %eax
movl $1, (%eax)
# end execute on
# pop args (16)
movl (sp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop args

# end emit callv

# emit/mov>addrgp4(53)

# emit addrgp

movl $.LCS53, %eax
movl %eax, (R3)

# end emit addrgp

# emit/mov>argp4(addrgp4(53))

# emit argp

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argp

# emit/mov>cnsti4(1)
movl $1, (R3)
# emit/mov>asgni4(vregp(3),cnsti4(1))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>indiri4(vregp(3))

# emit/mov>argi4(indiri4(vregp(3)))

# emit argi

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argi

# emit/mov>cnsti4(0)
movl $0, (R2)
# emit/mov>argi4(cnsti4(0))

# emit argi

movl (R2), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argi

# emit/mov>indiri4(vregp(3))

# emit/mov>argi4(indiri4(vregp(3)))

# emit argi

movl (R3), %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push

# end emit argi

# emit/mov>callv(addrgp4(text))

# emit callv

# call 'text'
# (direct call)
# text is internal
# push return
movl $.LCI59-0x80000000, %eax
# push %eax
movl %eax, %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl push(%edx), %edx
movl %edx, (%eax)
movl (sp), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end push
# end push return

movl $text-0x80000000, %eax
# jmp_jumpv
movl %eax, (branch_temp)
# store target (branch_temp) (on)
movl (on), %eax
movl sel_target(,%eax,4), %eax
movl (branch_temp), %edx
movl %edx, (%eax)
# end store target
# store jmp regs (on)
movl (on), %ecx
movl $jmp_r0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (R0), %edx
movl %edx, 0(%eax)
movl (R1), %edx
movl %edx, 4(%eax)
movl (R2), %edx
movl %edx, 8(%eax)
movl (R3), %edx
movl %edx, 12(%eax)
movl $jmp_f0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (F0), %edx
movl %edx, 0(%eax)
movl (F1), %edx
movl %edx, 4(%eax)
movl (F2), %edx
movl %edx, 8(%eax)
movl $jmp_d0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (D0), %edx
movl %edx, 0(%eax)
movl (D0+4), %edx
movl %edx, 4(%eax)
movl (D1), %edx
movl %edx, 8(%eax)
movl (D1+4), %edx
movl %edx, 12(%eax)
movl (D2), %edx
movl %edx, 16(%eax)
movl (D2+4), %edx
movl %edx, 20(%eax)
# end store jmp regs
# execute off (on)
movl (on), %eax
movl sel_on(,%eax,4), %eax
movl $0, (%eax)
# end execute off
# end jmp_jumpv
.LCI59:
movl (target), %eax
movl $.LCI59-0x80000000, %edx
# alu_eq
movl %eax, (alu_x)
movl %edx, (alu_y)
movl $0, %eax
movl $0, %ecx
movl $0, %edx
movb (alu_x+0), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+0), %dl
movb (%ecx,%edx), %dl
movl %edx, (b0)
movb (alu_x+1), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+1), %dl
movb (%ecx,%edx), %dl
movl %edx, (b1)
movb (alu_x+2), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+2), %dl
movb (%ecx,%edx), %dl
movl %edx, (b2)
movb (alu_x+3), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+3), %dl
movb (%ecx,%edx), %dl
movl %edx, (b3)
# alu_bool
movl (b0), %eax
movl (b1), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b2), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b3), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
movl (b0), %eax
movl %eax, (b0)
# end alu_eq
# load jmp regs (b0)
movl (b0), %ecx
movl $R0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r0), %edx
movl %edx, (%eax)
movl $R1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r1), %edx
movl %edx, (%eax)
movl $R2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r2), %edx
movl %edx, (%eax)
movl $R3, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r3), %edx
movl %edx, (%eax)
movl $F0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f0), %edx
movl %edx, (%eax)
movl $F1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f1), %edx
movl %edx, (%eax)
movl $F2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f2), %edx
movl %edx, (%eax)
movl $D0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d0), %edx
movl %edx, (%eax)
movl (jmp_d0+4), %edx
movl %edx, 4(%eax)
movl $D1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d1), %edx
movl %edx, (%eax)
movl (jmp_d1+4), %edx
movl %edx, 4(%eax)
movl $D2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d2), %edx
movl %edx, (%eax)
movl (jmp_d2+4), %edx
movl %edx, 4(%eax)
# end load jmp regs
# execute on (b0)
movl (b0), %eax
movl sel_on(,%eax,4), %eax
movl $1, (%eax)
# end execute on
# pop args (16)
movl (sp), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl pop(%eax), %eax
movl %eax, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop args

# end emit callv

# emit/mov>cnsti4(0)
movl $0, (R0)
# emit/mov>reti4(cnsti4(0))

# emit reti


# end emit reti

# emit/mov>labelv(40)

# emit labelv

.LCI40:
movl (target), %eax
movl $.LCI40-0x80000000, %edx
# alu_eq
movl %eax, (alu_x)
movl %edx, (alu_y)
movl $0, %eax
movl $0, %ecx
movl $0, %edx
movb (alu_x+0), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+0), %dl
movb (%ecx,%edx), %dl
movl %edx, (b0)
movb (alu_x+1), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+1), %dl
movb (%ecx,%edx), %dl
movl %edx, (b1)
movb (alu_x+2), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+2), %dl
movb (%ecx,%edx), %dl
movl %edx, (b2)
movb (alu_x+3), %al
movl alu_eq(,%eax,4), %ecx
movb (alu_y+3), %dl
movb (%ecx,%edx), %dl
movl %edx, (b3)
# alu_bool
movl (b0), %eax
movl (b1), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b2), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
# alu_bool
movl (b0), %eax
movl (b3), %edx
movl and(,%eax,4), %eax
movl (%eax,%edx,4), %eax
movl %eax, (b0)
# end alu_bool
movl (b0), %eax
movl %eax, (b0)
# end alu_eq
# load jmp regs (b0)
movl (b0), %ecx
movl $R0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r0), %edx
movl %edx, (%eax)
movl $R1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r1), %edx
movl %edx, (%eax)
movl $R2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r2), %edx
movl %edx, (%eax)
movl $R3, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_r3), %edx
movl %edx, (%eax)
movl $F0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f0), %edx
movl %edx, (%eax)
movl $F1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f1), %edx
movl %edx, (%eax)
movl $F2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_f2), %edx
movl %edx, (%eax)
movl $D0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d0), %edx
movl %edx, (%eax)
movl (jmp_d0+4), %edx
movl %edx, 4(%eax)
movl $D1, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d1), %edx
movl %edx, (%eax)
movl (jmp_d1+4), %edx
movl %edx, 4(%eax)
movl $D2, (data_p)
movl sel_data(,%ecx,4), %eax
movl (jmp_d2), %edx
movl %edx, (%eax)
movl (jmp_d2+4), %edx
movl %edx, 4(%eax)
# end load jmp regs
# execute on (b0)
movl (b0), %eax
movl sel_on(,%eax,4), %eax
movl $1, (%eax)
# end execute on

# end emit labelv

# epilogue
# movl %ebp, %esp
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (fp), %edx
movl %edx, (%eax)
# end movl %ebp, %esp
# pop8 D2
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl 4(%eax), %edx
movl %edx, (stack_temp+4)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $D2, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
movl (stack_temp+4), %edx
movl %edx, 4(%eax)
# end pop8
# pop8 D1
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl 4(%eax), %edx
movl %edx, (stack_temp+4)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $D1, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
movl (stack_temp+4), %edx
movl %edx, 4(%eax)
# end pop8
# pop F2
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $F2, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop
# pop F1
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $F1, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop
# pop R3
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $R3, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop
# pop R2
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $R2, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop
# pop R1
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $R1, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop
# pop fp
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl $fp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (stack_temp), %edx
movl %edx, (%eax)
# end pop
# ret
# pop %eax
movl (sp), %eax
movl (%eax), %edx
movl %edx, (stack_temp)
movl $sp, %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (sp), %edx
movl pop(%edx), %edx
movl %edx, (%eax)
movl (stack_temp), %edx
movl %edx, %eax
# end pop
# jmp_jumpv
movl %eax, (branch_temp)
# store target (branch_temp) (on)
movl (on), %eax
movl sel_target(,%eax,4), %eax
movl (branch_temp), %edx
movl %edx, (%eax)
# end store target
# store jmp regs (on)
movl (on), %ecx
movl $jmp_r0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (R0), %edx
movl %edx, 0(%eax)
movl (R1), %edx
movl %edx, 4(%eax)
movl (R2), %edx
movl %edx, 8(%eax)
movl (R3), %edx
movl %edx, 12(%eax)
movl $jmp_f0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (F0), %edx
movl %edx, 0(%eax)
movl (F1), %edx
movl %edx, 4(%eax)
movl (F2), %edx
movl %edx, 8(%eax)
movl $jmp_d0, (data_p)
movl sel_data(,%ecx,4), %eax
movl (D0), %edx
movl %edx, 0(%eax)
movl (D0+4), %edx
movl %edx, 4(%eax)
movl (D1), %edx
movl %edx, 8(%eax)
movl (D1+4), %edx
movl %edx, 12(%eax)
movl (D2), %edx
movl %edx, 16(%eax)
movl (D2+4), %edx
movl %edx, 20(%eax)
# end store jmp regs
# execute off (on)
movl (on), %eax
movl sel_on(,%eax,4), %eax
movl $0, (%eax)
# end execute off
# end jmp_jumpv
# end ret
.Lf60:
.size main,.Lf60-main

# import 'usleep'
.extern 'usleep'

.bss
# export 'height'
.globl height
.type height,@object
.size height,4
.comm height,4
# export 't'
.globl t
.type t,@object
.size t,12
.comm t,12
# import 'fsync'
.extern 'fsync'
# import 'getlogin'
.extern 'getlogin'
# import 'tcsetpgrp'
.extern 'tcsetpgrp'
# import 'tcgetpgrp'
.extern 'tcgetpgrp'
# import 'rmdir'
.extern 'rmdir'
# import 'unlink'
.extern 'unlink'
# import 'link'
.extern 'link'
# import 'isatty'
.extern 'isatty'
# import 'ttyname_r'
.extern 'ttyname_r'
# import 'ttyname'
.extern 'ttyname'
# import 'fork'
.extern 'fork'
# import 'setgid'
.extern 'setgid'
# import 'setuid'
.extern 'setuid'
# import 'getgroups'
.extern 'getgroups'
# import 'getegid'
.extern 'getegid'
# import 'getgid'
.extern 'getgid'
# import 'geteuid'
.extern 'geteuid'
# import 'getuid'
.extern 'getuid'
# import 'setsid'
.extern 'setsid'
# import 'setpgid'
.extern 'setpgid'
# import '__getpgid'
.extern '__getpgid'
# import 'getpgrp'
.extern 'getpgrp'
# import 'getppid'
.extern 'getppid'
# import 'getpid'
.extern 'getpid'
# import 'sysconf'
.extern 'sysconf'
# import 'fpathconf'
.extern 'fpathconf'
# import 'pathconf'
.extern 'pathconf'
# import '_exit'
.extern '_exit'
# import 'execlp'
.extern 'execlp'
# import 'execvp'
.extern 'execvp'
# import 'execl'
.extern 'execl'
# import 'execle'
.extern 'execle'
# import 'execv'
.extern 'execv'
# import 'execve'
.extern 'execve'
# import '__environ'
.extern '__environ'
# import 'dup2'
.extern 'dup2'
# import 'dup'
.extern 'dup'
# import 'getcwd'
.extern 'getcwd'
# import 'chdir'
.extern 'chdir'
# import 'chown'
.extern 'chown'
# import 'pause'
.extern 'pause'
# import 'sleep'
.extern 'sleep'
# import 'alarm'
.extern 'alarm'
# import 'pipe'
.extern 'pipe'
# import 'write'
.extern 'write'
# import 'read'
.extern 'read'
# import 'close'
.extern 'close'
# import 'lseek'
.extern 'lseek'
# import 'access'
.extern 'access'
# import 'wcstombs'
.extern 'wcstombs'
# import 'mbstowcs'
.extern 'mbstowcs'
# import 'wctomb'
.extern 'wctomb'
# import 'mbtowc'
.extern 'mbtowc'
# import 'mblen'
.extern 'mblen'
# import 'ldiv'
.extern 'ldiv'
# import 'div'
.extern 'div'
# import 'labs'
.extern 'labs'
# import 'abs'
.extern 'abs'
# import 'qsort'
.extern 'qsort'
# import 'bsearch'
.extern 'bsearch'
# import 'system'
.extern 'system'
# import 'getenv'
.extern 'getenv'
# import 'exit'
.extern 'exit'
# import 'atexit'
.extern 'atexit'
# import 'abort'
.extern 'abort'
# import 'free'
.extern 'free'
# import 'realloc'
.extern 'realloc'
# import 'calloc'
.extern 'calloc'
# import 'malloc'
.extern 'malloc'
# import 'srand'
.extern 'srand'
# import 'rand'
.extern 'rand'
# import 'strtoul'
.extern 'strtoul'
# import 'strtol'
.extern 'strtol'
# import 'strtod'
.extern 'strtod'
# import 'atol'
.extern 'atol'
# import 'atoi'
.extern 'atoi'
# import 'atof'
.extern 'atof'
# import '__ctype_get_mb_cur_max'
.extern '__ctype_get_mb_cur_max'
# import '__overflow'
.extern '__overflow'
# import '__uflow'
.extern '__uflow'
# import 'ctermid'
.extern 'ctermid'
# import 'fileno'
.extern 'fileno'
# import 'perror'
.extern 'perror'
# import 'ferror'
.extern 'ferror'
# import 'feof'
.extern 'feof'
# import 'clearerr'
.extern 'clearerr'
# import 'fsetpos'
.extern 'fsetpos'
# import 'fgetpos'
.extern 'fgetpos'
# import 'rewind'
.extern 'rewind'
# import 'ftell'
.extern 'ftell'
# import 'fseek'
.extern 'fseek'
# import 'fwrite'
.extern 'fwrite'
# import 'fread'
.extern 'fread'
# import 'ungetc'
.extern 'ungetc'
# import 'puts'
.extern 'puts'
# import 'fputs'
.extern 'fputs'
# import 'gets'
.extern 'gets'
# import 'fgets'
.extern 'fgets'
# import 'putchar'
.extern 'putchar'
# import 'putc'
.extern 'putc'
# import 'fputc'
.extern 'fputc'
# import 'getchar'
.extern 'getchar'
# import 'getc'
.extern 'getc'
# import 'fgetc'
.extern 'fgetc'
# import '__isoc99_sscanf'
.extern '__isoc99_sscanf'
# import '__isoc99_scanf'
.extern '__isoc99_scanf'
# import '__isoc99_fscanf'
.extern '__isoc99_fscanf'
# import 'sscanf'
.extern 'sscanf'
# import 'scanf'
.extern 'scanf'
# import 'fscanf'
.extern 'fscanf'
# import 'vsprintf'
.extern 'vsprintf'
# import 'vprintf'
.extern 'vprintf'
# import 'vfprintf'
.extern 'vfprintf'
# import 'sprintf'
.extern 'sprintf'
# import 'printf'
.extern 'printf'
# import 'fprintf'
.extern 'fprintf'
# import 'setvbuf'
.extern 'setvbuf'
# import 'setbuf'
.extern 'setbuf'
# import 'fdopen'
.extern 'fdopen'
# import 'freopen'
.extern 'freopen'
# import 'fopen'
.extern 'fopen'
# import 'fflush'
.extern 'fflush'
# import 'tmpnam'
.extern 'tmpnam'
# import 'tmpfile'
.extern 'tmpfile'
# import 'fclose'
.extern 'fclose'
# import 'rename'
.extern 'rename'
# import 'remove'
.extern 'remove'
# import 'stderr'
.extern 'stderr'
# import 'stdout'
.extern 'stdout'
# import 'stdin'
.extern 'stdin'
.type __va_arg_tmp,@object
.size __va_arg_tmp,4
.lcomm __va_arg_tmp,4

.section .plt

.data
.LCS53:  # <LCS>
.byte 0xa
.byte 0x0
.LCS41:  # <LCS>
.byte 0x1b
.byte 0x5b
.byte 0x48
.byte 0x1b
.byte 0x5b
.byte 0x4a
.byte 0x0
.LCS29:  # <LCS>
.byte 0x20
.byte 0x20
.byte 0x0
.LCS23:  # <LCS>
.byte 0x3d
.byte 0x3d
.byte 0x0
.LCS18:  # <LCS>
.byte 0x25
.byte 0x73
.byte 0x0
.LCS14:  # <LCS>
.byte 0x1b
.byte 0x5b
.byte 0x25
.byte 0x64
.byte 0x3b
.byte 0x25
.byte 0x64
.byte 0x48
.byte 0x0

.text
