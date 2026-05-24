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
# frame
movl (sp), %eax
movl $-36048, %edx
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
# emit/mov>cnsti4(9009)
movl $9009, (R3)
# emit/mov>asgni4(addrlp4(N),cnsti4(9009))

# emit asgni

# (ADDRL)
# (offset -36048)
movl (fp), %eax
movl $-36048, %edx
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
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (R3), %edx
movl %edx, (%eax)

# end emit asgni

# emit/mov>addrlp4(N)

# emit addrlp

# (offset -36048)
movl (fp), %eax
movl $-36048, %edx
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

# end emit addrlp

# emit/mov>indiri4(addrlp4(N))

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

# emit/mov>asgni4(addrlp4(n),indiri4(addrlp4(N)))

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

# emit/mov>jumpv(addrgp4(6))

# emit jumpv

# (direct jump)
movl $.LCI6-0x80000000, %eax
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

# emit/mov>labelv(5)

# emit labelv

.LCI5:
movl (target), %eax
movl $.LCI5-0x80000000, %edx
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

# emit/mov>addrlp4(n)

# emit addrlp

# (offset -4)
movl (fp), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indiri4(addrlp4(n))

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

# emit/mov>asgni4(vregp(1),indiri4(addrlp4(n)))

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

# emit/mov>cnsti4(2)
movl $2, (R1)
# emit/mov>lshi4(indiri4(vregp(1)),cnsti4(2))

# emit lshi

movl (R3), %eax
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
movl %eax, (R1)

# end emit lshi

# emit/mov>addrlp4(a)

# emit addrlp

# (offset -36044)
movl (fp), %eax
movl $-36044, %edx
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

# end emit addrlp

# emit/mov>addp4(lshi4(indiri4(vregp(1)),cnsti4(2)),addrlp4(a))

# emit addp

movl (R1), %eax
movl (R0), %edx
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

# end emit addp

# emit/mov>indiri4(vregp(2))

# emit/mov>indiri4(vregp(1))

# emit/mov>divi4(indiri4(vregp(2)),indiri4(vregp(1)))

# emit divi

movl (R2), %eax
movl (R3), %edx
# alu_idiv
movl %eax, (alu_n)
movl %edx, (alu_d)
movl $0, %eax
movb (alu_n+3), %al
movl alu_b7(,%eax,4), %eax
movl %eax, (alu_ns)
movl $0, %eax
movb (alu_d+3), %al
movl alu_b7(,%eax,4), %eax
movl %eax, (alu_ds)
# alu_bxor8
movl $0, %eax
movl $0, %edx
movb (alu_ns+0), %al
movb (alu_ds+0), %dl
movl alu_bxor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_qs+0)
# end alu_bxor8
movl (alu_n), %ecx
# alu_neg
movl %ecx, (alu_y)
movl $0, (alu_x)
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
movl (alu_s), %ecx
# end alu_neg
movl $alu_n, %eax
movl (alu_ns), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl %ecx, (%eax)
movl (alu_d), %ecx
# alu_neg
movl %ecx, (alu_y)
movl $0, (alu_x)
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
movl (alu_s), %ecx
# end alu_neg
movl $alu_d, %eax
movl (alu_ds), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl %ecx, (%eax)
movl (alu_n), %eax
movl (alu_d), %edx
# alu_divrem
movl %eax, (alu_n)
movl %edx, (alu_d)
movl $0, (alu_q)
movl $0, (alu_r)
# alu_bit
movl $0, %edx
movb (alu_n+3), %dl
movl alu_b7(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+3), %al
movb alu_b_s_7(%eax), %al
movb %al, (alu_sq+3)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+3), %dl
movl alu_b6(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+3), %al
movb alu_b_s_6(%eax), %al
movb %al, (alu_sq+3)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+3), %dl
movl alu_b5(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+3), %al
movb alu_b_s_5(%eax), %al
movb %al, (alu_sq+3)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+3), %dl
movl alu_b4(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+3), %al
movb alu_b_s_4(%eax), %al
movb %al, (alu_sq+3)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+3), %dl
movl alu_b3(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+3), %al
movb alu_b_s_3(%eax), %al
movb %al, (alu_sq+3)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+3), %dl
movl alu_b2(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+3), %al
movb alu_b_s_2(%eax), %al
movb %al, (alu_sq+3)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+3), %dl
movl alu_b1(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+3), %al
movb alu_b_s_1(%eax), %al
movb %al, (alu_sq+3)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+3), %dl
movl alu_b0(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+3), %al
movb alu_b_s_0(%eax), %al
movb %al, (alu_sq+3)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+2), %dl
movl alu_b7(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+2), %al
movb alu_b_s_7(%eax), %al
movb %al, (alu_sq+2)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+2), %dl
movl alu_b6(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+2), %al
movb alu_b_s_6(%eax), %al
movb %al, (alu_sq+2)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+2), %dl
movl alu_b5(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+2), %al
movb alu_b_s_5(%eax), %al
movb %al, (alu_sq+2)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+2), %dl
movl alu_b4(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+2), %al
movb alu_b_s_4(%eax), %al
movb %al, (alu_sq+2)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+2), %dl
movl alu_b3(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+2), %al
movb alu_b_s_3(%eax), %al
movb %al, (alu_sq+2)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+2), %dl
movl alu_b2(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+2), %al
movb alu_b_s_2(%eax), %al
movb %al, (alu_sq+2)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+2), %dl
movl alu_b1(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+2), %al
movb alu_b_s_1(%eax), %al
movb %al, (alu_sq+2)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+2), %dl
movl alu_b0(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+2), %al
movb alu_b_s_0(%eax), %al
movb %al, (alu_sq+2)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+1), %dl
movl alu_b7(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+1), %al
movb alu_b_s_7(%eax), %al
movb %al, (alu_sq+1)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+1), %dl
movl alu_b6(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+1), %al
movb alu_b_s_6(%eax), %al
movb %al, (alu_sq+1)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+1), %dl
movl alu_b5(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+1), %al
movb alu_b_s_5(%eax), %al
movb %al, (alu_sq+1)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+1), %dl
movl alu_b4(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+1), %al
movb alu_b_s_4(%eax), %al
movb %al, (alu_sq+1)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+1), %dl
movl alu_b3(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+1), %al
movb alu_b_s_3(%eax), %al
movb %al, (alu_sq+1)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+1), %dl
movl alu_b2(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+1), %al
movb alu_b_s_2(%eax), %al
movb %al, (alu_sq+1)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+1), %dl
movl alu_b1(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+1), %al
movb alu_b_s_1(%eax), %al
movb %al, (alu_sq+1)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+1), %dl
movl alu_b0(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+1), %al
movb alu_b_s_0(%eax), %al
movb %al, (alu_sq+1)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+0), %dl
movl alu_b7(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+0), %al
movb alu_b_s_7(%eax), %al
movb %al, (alu_sq+0)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+0), %dl
movl alu_b6(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+0), %al
movb alu_b_s_6(%eax), %al
movb %al, (alu_sq+0)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+0), %dl
movl alu_b5(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+0), %al
movb alu_b_s_5(%eax), %al
movb %al, (alu_sq+0)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+0), %dl
movl alu_b4(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+0), %al
movb alu_b_s_4(%eax), %al
movb %al, (alu_sq+0)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+0), %dl
movl alu_b3(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+0), %al
movb alu_b_s_3(%eax), %al
movb %al, (alu_sq+0)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+0), %dl
movl alu_b2(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+0), %al
movb alu_b_s_2(%eax), %al
movb %al, (alu_sq+0)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+0), %dl
movl alu_b1(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+0), %al
movb alu_b_s_1(%eax), %al
movb %al, (alu_sq+0)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+0), %dl
movl alu_b0(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+0), %al
movb alu_b_s_0(%eax), %al
movb %al, (alu_sq+0)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# end alu_divrem
movl (alu_q), %ecx
# alu_neg
movl %ecx, (alu_y)
movl $0, (alu_x)
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
movl (alu_s), %ecx
# end alu_neg
movl $alu_q, %eax
movl (alu_qs), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl %ecx, (%eax)
movl (alu_q), %eax
# end alu_idiv
movl %eax, (R3)

# end emit divi

# emit/mov>indiri4(vregp(2))

# emit/mov>addi4(divi4(indiri4(vregp(2)),indiri4(vregp(1))),indiri4(vregp(2)))

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

# emit/mov>asgni4(addp4(lshi4(indiri4(vregp(1)),cnsti4(2)),addrlp4(a)),addi4(divi4(indiri4(vregp(2)),indiri4(vregp(1))),indiri4(vregp(2))))

# emit asgni

# (!ADDRL)
movl (R1), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (R3), %edx
movl %edx, (%eax)

# end emit asgni

# emit/mov>labelv(6)

# emit labelv

.LCI6:
movl (target), %eax
movl $.LCI6-0x80000000, %edx
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

# emit/mov>addrlp4(n)

# emit addrlp

# (offset -4)
movl (fp), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indiri4(addrlp4(n))

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
# emit/mov>subi4(indiri4(addrlp4(n)),cnsti4(1))

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

# emit/mov>asgni4(vregp(3),subi4(indiri4(addrlp4(n)),cnsti4(1)))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>indiri4(vregp(3))

# emit/mov>asgni4(addrlp4(n),indiri4(vregp(3)))

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

# emit/mov>indiri4(vregp(3))

# emit/mov>cnsti4(0)
movl $0, (R2)
# emit/mov>nei4(indiri4(vregp(3)),cnsti4(0))

# emit nei

movl (R3), %eax
movl (R2), %edx
movl $.LCI5-0x80000000, %ecx
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

# emit/mov>jumpv(addrgp4(11))

# emit jumpv

# (direct jump)
movl $.LCI11-0x80000000, %eax
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

# emit/mov>labelv(8)

# emit labelv

.LCI8:
movl (target), %eax
movl $.LCI8-0x80000000, %edx
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

# emit/mov>addrlp4(N)

# emit addrlp

# (offset -36048)
movl (fp), %eax
movl $-36048, %edx
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

# end emit addrlp

# emit/mov>indiri4(addrlp4(N))

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

# emit/mov>asgni4(vregp(4),indiri4(addrlp4(N)))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>indiri4(vregp(4))

# emit/mov>cnsti4(1)
movl $1, (R2)
# emit/mov>subi4(indiri4(vregp(4)),cnsti4(1))

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
movl %eax, (R2)

# end emit subi

# emit/mov>asgni4(addrlp4(N),subi4(indiri4(vregp(4)),cnsti4(1)))

# emit asgni

# (ADDRL)
# (offset -36048)
movl (fp), %eax
movl $-36048, %edx
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
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (R2), %edx
movl %edx, (%eax)

# end emit asgni

# emit/mov>indiri4(vregp(4))

# emit/mov>asgni4(addrlp4(n),indiri4(vregp(4)))

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

# emit/mov>labelv(14)

# emit labelv

.LCI14:
movl (target), %eax
movl $.LCI14-0x80000000, %edx
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

# emit/mov>addrlp4(n)

# emit addrlp

# (offset -4)
movl (fp), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indiri4(addrlp4(n))

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

# emit/mov>asgni4(vregp(5),indiri4(addrlp4(n)))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>indiri4(vregp(5))

# emit/mov>cnsti4(2)
movl $2, (R2)
# emit/mov>lshi4(indiri4(vregp(5)),cnsti4(2))

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
movl %eax, (R2)

# end emit lshi

# emit/mov>addrlp4(a)

# emit addrlp

# (offset -36044)
movl (fp), %eax
movl $-36044, %edx
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

# end emit addrlp

# emit/mov>addp4(lshi4(indiri4(vregp(5)),cnsti4(2)),addrlp4(a))

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

# emit/mov>addrlp4(x)

# emit addrlp

# (offset -8)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R1)

# end emit addrlp

# emit/mov>indiri4(addrlp4(x))

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

# emit/mov>indiri4(vregp(5))

# emit/mov>modi4(indiri4(addrlp4(x)),indiri4(vregp(5)))

# emit modi

movl (R1), %eax
movl (R3), %edx
# alu_imod
movl %eax, (alu_n)
movl %edx, (alu_d)
movl $0, %eax
movb (alu_n+3), %al
movl alu_b7(,%eax,4), %eax
movl %eax, (alu_ns)
movl $0, %eax
movb (alu_d+3), %al
movl alu_b7(,%eax,4), %eax
movl %eax, (alu_ds)
movl (alu_ns), %eax
movl %eax, (alu_rs)
movl (alu_n), %ecx
# alu_neg
movl %ecx, (alu_y)
movl $0, (alu_x)
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
movl (alu_s), %ecx
# end alu_neg
movl $alu_n, %eax
movl (alu_ns), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl %ecx, (%eax)
movl (alu_d), %ecx
# alu_neg
movl %ecx, (alu_y)
movl $0, (alu_x)
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
movl (alu_s), %ecx
# end alu_neg
movl $alu_d, %eax
movl (alu_ds), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl %ecx, (%eax)
movl (alu_n), %eax
movl (alu_d), %edx
# alu_divrem
movl %eax, (alu_n)
movl %edx, (alu_d)
movl $0, (alu_q)
movl $0, (alu_r)
# alu_bit
movl $0, %edx
movb (alu_n+3), %dl
movl alu_b7(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+3), %al
movb alu_b_s_7(%eax), %al
movb %al, (alu_sq+3)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+3), %dl
movl alu_b6(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+3), %al
movb alu_b_s_6(%eax), %al
movb %al, (alu_sq+3)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+3), %dl
movl alu_b5(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+3), %al
movb alu_b_s_5(%eax), %al
movb %al, (alu_sq+3)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+3), %dl
movl alu_b4(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+3), %al
movb alu_b_s_4(%eax), %al
movb %al, (alu_sq+3)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+3), %dl
movl alu_b3(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+3), %al
movb alu_b_s_3(%eax), %al
movb %al, (alu_sq+3)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+3), %dl
movl alu_b2(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+3), %al
movb alu_b_s_2(%eax), %al
movb %al, (alu_sq+3)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+3), %dl
movl alu_b1(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+3), %al
movb alu_b_s_1(%eax), %al
movb %al, (alu_sq+3)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+3), %dl
movl alu_b0(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+3), %al
movb alu_b_s_0(%eax), %al
movb %al, (alu_sq+3)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+2), %dl
movl alu_b7(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+2), %al
movb alu_b_s_7(%eax), %al
movb %al, (alu_sq+2)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+2), %dl
movl alu_b6(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+2), %al
movb alu_b_s_6(%eax), %al
movb %al, (alu_sq+2)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+2), %dl
movl alu_b5(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+2), %al
movb alu_b_s_5(%eax), %al
movb %al, (alu_sq+2)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+2), %dl
movl alu_b4(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+2), %al
movb alu_b_s_4(%eax), %al
movb %al, (alu_sq+2)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+2), %dl
movl alu_b3(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+2), %al
movb alu_b_s_3(%eax), %al
movb %al, (alu_sq+2)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+2), %dl
movl alu_b2(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+2), %al
movb alu_b_s_2(%eax), %al
movb %al, (alu_sq+2)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+2), %dl
movl alu_b1(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+2), %al
movb alu_b_s_1(%eax), %al
movb %al, (alu_sq+2)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+2), %dl
movl alu_b0(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+2), %al
movb alu_b_s_0(%eax), %al
movb %al, (alu_sq+2)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+1), %dl
movl alu_b7(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+1), %al
movb alu_b_s_7(%eax), %al
movb %al, (alu_sq+1)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+1), %dl
movl alu_b6(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+1), %al
movb alu_b_s_6(%eax), %al
movb %al, (alu_sq+1)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+1), %dl
movl alu_b5(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+1), %al
movb alu_b_s_5(%eax), %al
movb %al, (alu_sq+1)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+1), %dl
movl alu_b4(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+1), %al
movb alu_b_s_4(%eax), %al
movb %al, (alu_sq+1)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+1), %dl
movl alu_b3(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+1), %al
movb alu_b_s_3(%eax), %al
movb %al, (alu_sq+1)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+1), %dl
movl alu_b2(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+1), %al
movb alu_b_s_2(%eax), %al
movb %al, (alu_sq+1)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+1), %dl
movl alu_b1(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+1), %al
movb alu_b_s_1(%eax), %al
movb %al, (alu_sq+1)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+1), %dl
movl alu_b0(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+1), %al
movb alu_b_s_0(%eax), %al
movb %al, (alu_sq+1)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+0), %dl
movl alu_b7(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+0), %al
movb alu_b_s_7(%eax), %al
movb %al, (alu_sq+0)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+0), %dl
movl alu_b6(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+0), %al
movb alu_b_s_6(%eax), %al
movb %al, (alu_sq+0)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+0), %dl
movl alu_b5(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+0), %al
movb alu_b_s_5(%eax), %al
movb %al, (alu_sq+0)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+0), %dl
movl alu_b4(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+0), %al
movb alu_b_s_4(%eax), %al
movb %al, (alu_sq+0)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+0), %dl
movl alu_b3(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+0), %al
movb alu_b_s_3(%eax), %al
movb %al, (alu_sq+0)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+0), %dl
movl alu_b2(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+0), %al
movb alu_b_s_2(%eax), %al
movb %al, (alu_sq+0)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+0), %dl
movl alu_b1(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+0), %al
movb alu_b_s_1(%eax), %al
movb %al, (alu_sq+0)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+0), %dl
movl alu_b0(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+0), %al
movb alu_b_s_0(%eax), %al
movb %al, (alu_sq+0)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# end alu_divrem
movl (alu_r), %ecx
# alu_neg
movl %ecx, (alu_y)
movl $0, (alu_x)
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
movl (alu_s), %ecx
# end alu_neg
movl $alu_r, %eax
movl (alu_rs), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl %ecx, (%eax)
movl (alu_r), %eax
# end alu_imod
movl %eax, (R3)

# end emit modi

# emit/mov>asgni4(addp4(lshi4(indiri4(vregp(5)),cnsti4(2)),addrlp4(a)),modi4(indiri4(addrlp4(x)),indiri4(vregp(5))))

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

# emit/mov>addrlp4(n)

# emit addrlp

# (offset -4)
movl (fp), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indiri4(addrlp4(n))

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

# emit/mov>asgni4(vregp(6),indiri4(addrlp4(n)))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>cnsti4(10)
movl $10, (R2)
# emit/mov>indiri4(vregp(6))

# emit/mov>cnsti4(2)
movl $2, (R1)
# emit/mov>lshi4(indiri4(vregp(6)),cnsti4(2))

# emit lshi

movl (R3), %eax
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
movl %eax, (R1)

# end emit lshi

# emit/mov>addrlp4(17)

# emit addrlp

# (offset -36048)
movl (fp), %eax
movl $-36048, %edx
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

# end emit addrlp

# emit/mov>addp4(lshi4(indiri4(vregp(6)),cnsti4(2)),addrlp4(17))

# emit addp

movl (R1), %eax
movl (R0), %edx
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

# end emit addp

# emit/mov>indiri4(addp4(lshi4(indiri4(vregp(6)),cnsti4(2)),addrlp4(17)))

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

# emit/mov>muli4(cnsti4(10),indiri4(addp4(lshi4(indiri4(vregp(6)),cnsti4(2)),addrlp4(17))))

# emit muli

movl (R2), %eax
movl (R1), %edx
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
movl %eax, (R2)

# end emit muli

# emit/mov>addrlp4(x)

# emit addrlp

# (offset -8)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R1)

# end emit addrlp

# emit/mov>indiri4(addrlp4(x))

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

# emit/mov>indiri4(vregp(6))

# emit/mov>divi4(indiri4(addrlp4(x)),indiri4(vregp(6)))

# emit divi

movl (R1), %eax
movl (R3), %edx
# alu_idiv
movl %eax, (alu_n)
movl %edx, (alu_d)
movl $0, %eax
movb (alu_n+3), %al
movl alu_b7(,%eax,4), %eax
movl %eax, (alu_ns)
movl $0, %eax
movb (alu_d+3), %al
movl alu_b7(,%eax,4), %eax
movl %eax, (alu_ds)
# alu_bxor8
movl $0, %eax
movl $0, %edx
movb (alu_ns+0), %al
movb (alu_ds+0), %dl
movl alu_bxor8(,%eax,4), %eax
movb (%eax,%edx), %al
movb %al, (alu_qs+0)
# end alu_bxor8
movl (alu_n), %ecx
# alu_neg
movl %ecx, (alu_y)
movl $0, (alu_x)
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
movl (alu_s), %ecx
# end alu_neg
movl $alu_n, %eax
movl (alu_ns), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl %ecx, (%eax)
movl (alu_d), %ecx
# alu_neg
movl %ecx, (alu_y)
movl $0, (alu_x)
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
movl (alu_s), %ecx
# end alu_neg
movl $alu_d, %eax
movl (alu_ds), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl %ecx, (%eax)
movl (alu_n), %eax
movl (alu_d), %edx
# alu_divrem
movl %eax, (alu_n)
movl %edx, (alu_d)
movl $0, (alu_q)
movl $0, (alu_r)
# alu_bit
movl $0, %edx
movb (alu_n+3), %dl
movl alu_b7(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+3), %al
movb alu_b_s_7(%eax), %al
movb %al, (alu_sq+3)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+3), %dl
movl alu_b6(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+3), %al
movb alu_b_s_6(%eax), %al
movb %al, (alu_sq+3)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+3), %dl
movl alu_b5(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+3), %al
movb alu_b_s_5(%eax), %al
movb %al, (alu_sq+3)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+3), %dl
movl alu_b4(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+3), %al
movb alu_b_s_4(%eax), %al
movb %al, (alu_sq+3)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+3), %dl
movl alu_b3(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+3), %al
movb alu_b_s_3(%eax), %al
movb %al, (alu_sq+3)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+3), %dl
movl alu_b2(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+3), %al
movb alu_b_s_2(%eax), %al
movb %al, (alu_sq+3)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+3), %dl
movl alu_b1(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+3), %al
movb alu_b_s_1(%eax), %al
movb %al, (alu_sq+3)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+3), %dl
movl alu_b0(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+3), %al
movb alu_b_s_0(%eax), %al
movb %al, (alu_sq+3)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+2), %dl
movl alu_b7(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+2), %al
movb alu_b_s_7(%eax), %al
movb %al, (alu_sq+2)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+2), %dl
movl alu_b6(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+2), %al
movb alu_b_s_6(%eax), %al
movb %al, (alu_sq+2)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+2), %dl
movl alu_b5(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+2), %al
movb alu_b_s_5(%eax), %al
movb %al, (alu_sq+2)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+2), %dl
movl alu_b4(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+2), %al
movb alu_b_s_4(%eax), %al
movb %al, (alu_sq+2)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+2), %dl
movl alu_b3(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+2), %al
movb alu_b_s_3(%eax), %al
movb %al, (alu_sq+2)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+2), %dl
movl alu_b2(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+2), %al
movb alu_b_s_2(%eax), %al
movb %al, (alu_sq+2)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+2), %dl
movl alu_b1(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+2), %al
movb alu_b_s_1(%eax), %al
movb %al, (alu_sq+2)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+2), %dl
movl alu_b0(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+2), %al
movb alu_b_s_0(%eax), %al
movb %al, (alu_sq+2)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+1), %dl
movl alu_b7(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+1), %al
movb alu_b_s_7(%eax), %al
movb %al, (alu_sq+1)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+1), %dl
movl alu_b6(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+1), %al
movb alu_b_s_6(%eax), %al
movb %al, (alu_sq+1)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+1), %dl
movl alu_b5(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+1), %al
movb alu_b_s_5(%eax), %al
movb %al, (alu_sq+1)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+1), %dl
movl alu_b4(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+1), %al
movb alu_b_s_4(%eax), %al
movb %al, (alu_sq+1)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+1), %dl
movl alu_b3(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+1), %al
movb alu_b_s_3(%eax), %al
movb %al, (alu_sq+1)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+1), %dl
movl alu_b2(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+1), %al
movb alu_b_s_2(%eax), %al
movb %al, (alu_sq+1)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+1), %dl
movl alu_b1(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+1), %al
movb alu_b_s_1(%eax), %al
movb %al, (alu_sq+1)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+1), %dl
movl alu_b0(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+1), %al
movb alu_b_s_0(%eax), %al
movb %al, (alu_sq+1)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+0), %dl
movl alu_b7(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+0), %al
movb alu_b_s_7(%eax), %al
movb %al, (alu_sq+0)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+0), %dl
movl alu_b6(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+0), %al
movb alu_b_s_6(%eax), %al
movb %al, (alu_sq+0)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+0), %dl
movl alu_b5(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+0), %al
movb alu_b_s_5(%eax), %al
movb %al, (alu_sq+0)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+0), %dl
movl alu_b4(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+0), %al
movb alu_b_s_4(%eax), %al
movb %al, (alu_sq+0)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+0), %dl
movl alu_b3(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+0), %al
movb alu_b_s_3(%eax), %al
movb %al, (alu_sq+0)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+0), %dl
movl alu_b2(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+0), %al
movb alu_b_s_2(%eax), %al
movb %al, (alu_sq+0)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+0), %dl
movl alu_b1(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+0), %al
movb alu_b_s_1(%eax), %al
movb %al, (alu_sq+0)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# alu_bit
movl $0, %edx
movb (alu_n+0), %dl
movl alu_b0(,%edx,4), %eax
movl %eax, (alu_c)
# end alu_bit
# alu_div_shl1_32_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+0), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+0)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+1), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+1)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+2), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+2)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# alu_div_shl1_8_c
movl $0, %eax
movl $0, %edx
movb (alu_r+3), %al
movb (alu_c), %dl
movl alu_div_shl3_8_d(,%eax,4), %eax
movl alu_div_shl1_8_c_d(%eax,%edx,4), %eax
movb %al, (alu_r+3)
movb %ah, (alu_c)
# end alu_div_shl1_8_c
# end alu_div_shl1_32_c
# alu_div_gte32
movl $0, (alu_c)
movl (alu_r), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_t+0)
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
movw %dx, (alu_t+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl $0, %eax
movb (alu_c), %al
movb alu_true(%eax), %al
movl %eax, (alu_t)
# end alu_div_gte32
movl (alu_t), %eax
movl alu_sel_r(,%eax,4), %edx
movl %edx, (alu_psel_r)
movl alu_sel_q(,%eax,4), %edx
movl %edx, (alu_psel_q)
movl (alu_psel_r), %eax
movl (%eax), %eax
movl %eax, (alu_sr)
movl (alu_sr), %eax
movl %eax, (alu_x)
movl (alu_d), %eax
movl %eax, (alu_y)
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
movw %dx, (alu_sr+0)
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
movw %dx, (alu_sr+2)
movl %edx, (alu_c-2)
# end alu_sub16_fast
# end alu_sub32
movl (alu_psel_r), %eax
movl (alu_sr), %edx
movl %edx, (%eax)
movl (alu_psel_q), %eax
movl (%eax), %eax
movl %eax, (alu_sq)
# alu_div_setb32
movl $0, %eax
movb (alu_sq+0), %al
movb alu_b_s_0(%eax), %al
movb %al, (alu_sq+0)
# end alu_div_setb32
movl (alu_psel_q), %eax
movl (alu_sq), %edx
movl %edx, (%eax)
# end alu_divrem
movl (alu_q), %ecx
# alu_neg
movl %ecx, (alu_y)
movl $0, (alu_x)
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
movl (alu_s), %ecx
# end alu_neg
movl $alu_q, %eax
movl (alu_qs), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl %ecx, (%eax)
movl (alu_q), %eax
# end alu_idiv
movl %eax, (R3)

# end emit divi

# emit/mov>addi4(muli4(cnsti4(10),indiri4(addp4(lshi4(indiri4(vregp(6)),cnsti4(2)),addrlp4(17)))),divi4(indiri4(addrlp4(x)),indiri4(vregp(6))))

# emit addi

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

# end emit addi

# emit/mov>asgni4(addrlp4(x),addi4(muli4(cnsti4(10),indiri4(addp4(lshi4(indiri4(vregp(6)),cnsti4(2)),addrlp4(17)))),divi4(indiri4(addrlp4(x)),indiri4(vregp(6)))))

# emit asgni

# (ADDRL)
# (offset -8)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (R3), %edx
movl %edx, (%eax)

# end emit asgni

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

# emit/mov>addrlp4(n)

# emit addrlp

# (offset -4)
movl (fp), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indiri4(addrlp4(n))

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
# emit/mov>subi4(indiri4(addrlp4(n)),cnsti4(1))

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

# emit/mov>asgni4(vregp(7),subi4(indiri4(addrlp4(n)),cnsti4(1)))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>indiri4(vregp(7))

# emit/mov>asgni4(addrlp4(n),indiri4(vregp(7)))

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

# emit/mov>indiri4(vregp(7))

# emit/mov>cnsti4(0)
movl $0, (R2)
# emit/mov>nei4(indiri4(vregp(7)),cnsti4(0))

# emit nei

movl (R3), %eax
movl (R2), %edx
movl $.LCI13-0x80000000, %ecx
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

# emit/mov>labelv(9)

# emit labelv

.LCI9:
movl (target), %eax
movl $.LCI9-0x80000000, %edx
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

# emit/mov>addrlp4(x)

# emit addrlp

# (offset -8)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indiri4(addrlp4(x))

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

# emit/mov>argi4(indiri4(addrlp4(x)))

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

# emit/mov>addrgp4(12)

# emit addrgp

movl $.LCS12, %eax
movl %eax, (R3)

# end emit addrgp

# emit/mov>argp4(addrgp4(12))

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
movl $.LCE18-0x80000000, %eax
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
.LCE18:
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

# emit/mov>labelv(11)

# emit labelv

.LCI11:
movl (target), %eax
movl $.LCI11-0x80000000, %edx
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

# emit/mov>addrlp4(N)

# emit addrlp

# (offset -36048)
movl (fp), %eax
movl $-36048, %edx
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

# end emit addrlp

# emit/mov>indiri4(addrlp4(N))

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

# emit/mov>cnsti4(9)
movl $9, (R2)
# emit/mov>gti4(indiri4(addrlp4(N)),cnsti4(9))

# emit gti

movl (R3), %eax
movl (R2), %edx
movl $.LCI8-0x80000000, %ecx
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

# emit/mov>cnsti4(0)
movl $0, (R0)
# emit/mov>reti4(cnsti4(0))

# emit reti


# end emit reti

# emit/mov>labelv(4)

# emit labelv

.LCI4:
movl (target), %eax
movl $.LCI4-0x80000000, %edx
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
.Lf19:
.size main,.Lf19-main

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

.bss
.type __va_arg_tmp,@object
.size __va_arg_tmp,4
.lcomm __va_arg_tmp,4

.section .plt

.data
.LCS12:  # <LCS>
.byte 0x25
.byte 0x64
.byte 0xa
.byte 0x0

.text
