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
# emit/mov>cnsti4(22)
movl $22, (R3)
# emit/mov>argi4(cnsti4(22))

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

# emit/mov>cnsti4(20)
movl $20, (R3)
# emit/mov>argi4(cnsti4(20))

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

# emit/mov>calli4(addrgp4(add))

# emit calli

# call 'add'
# (direct call)
# add is external
# push return
movl $.LCE2-0x80000000, %eax
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
movl $add, (external)
movl (on), %eax
movl fault(,%eax,4), %eax
movl (%eax), %eax
.LCE2:
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

# emit/mov>load(calli4(addrgp4(add)))

# emit loadi

movl (R0), %eax
movl %eax, (R3)

# end emit loadi

# emit/mov>asgni4(vregp(1),load(calli4(addrgp4(add))))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>indiri4(vregp(1))

# emit/mov>load(indiri4(vregp(1)))

# emit loadi

movl (R3), %eax
movl %eax, (R0)

# end emit loadi

# emit/mov>reti4(load(indiri4(vregp(1))))

# emit reti


# end emit reti

# emit/mov>labelv(1)

# emit labelv

.LCI1:
movl (target), %eax
movl $.LCI1-0x80000000, %edx
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
.Lf3:
.size main,.Lf3-main

# import 'add'
.extern 'add'
