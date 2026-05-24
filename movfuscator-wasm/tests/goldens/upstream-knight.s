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

.data
# export 'dx'
.globl dx
.type dx,@object
dx:  # <LCS>
.long -2
.long -2
.long -1
.long 1
.long 2
.long 2
.long 1
.long -1
.size dx,32
# export 'dy'
.globl dy
.type dy,@object
dy:  # <LCS>
.long -1
.long 1
.long 2
.long 2
.long 1
.long -1
.long -2
.long -2
.size dy,32
# export 'init_board'
.globl init_board

.text
.type init_board,@function
init_board:  # <LCI>
# label
movl (target), %eax
movl $init_board-0x80000000, %edx
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
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
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
# emit/mov>addrfp4(w)

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

# emit/mov>indiri4(addrfp4(w))

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

# emit/mov>cnsti4(4)
movl $4, (R2)
# emit/mov>addi4(indiri4(addrfp4(w)),cnsti4(4))

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

# emit/mov>asgni4(addrlp4(p),addi4(indiri4(addrfp4(w)),cnsti4(4)))

# emit asgni

# (ADDRL)
# (offset -28)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
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

# emit/mov>addrfp4(h)

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

# emit/mov>indiri4(addrfp4(h))

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

# emit/mov>cnsti4(4)
movl $4, (R2)
# emit/mov>addi4(indiri4(addrfp4(h)),cnsti4(4))

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

# emit/mov>asgni4(addrlp4(q),addi4(indiri4(addrfp4(h)),cnsti4(4)))

# emit asgni

# (ADDRL)
# (offset -24)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
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

# emit/mov>addrfp4(a)

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

# emit/mov>indirp4(addrfp4(a))

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

# emit/mov>asgnp4(vregp(1),indirp4(addrfp4(a)))

# emit asgnp


# (emit vreg asgn)


# end emit asgnp

# emit/mov>indirp4(vregp(1))

# emit/mov>addrlp4(q)

# emit addrlp

# (offset -24)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R2)

# end emit addrlp

# emit/mov>indiri4(addrlp4(q))

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
# emit/mov>lshi4(indiri4(addrlp4(q)),cnsti4(2))

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

# emit/mov>indirp4(vregp(1))

# emit/mov>addp4(lshi4(indiri4(addrlp4(q)),cnsti4(2)),indirp4(vregp(1)))

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
movl %eax, (R2)

# end emit addp

# emit/mov>asgnp4(indirp4(vregp(1)),addp4(lshi4(indiri4(addrlp4(q)),cnsti4(2)),indirp4(vregp(1))))

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

# emit/mov>addrfp4(b)

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

# emit/mov>indirp4(addrfp4(b))

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

# emit/mov>addrfp4(a)

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

# emit/mov>indirp4(addrfp4(a))

# emit indirp

movl (R2), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R2)

# end emit indirp

# emit/mov>indirp4(indirp4(addrfp4(a)))

# emit indirp

movl (R2), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R2)

# end emit indirp

# emit/mov>cnsti4(2)
movl $2, (R1)
# emit/mov>addp4(indirp4(indirp4(addrfp4(a))),cnsti4(2))

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

# emit/mov>asgnp4(indirp4(addrfp4(b)),addp4(indirp4(indirp4(addrfp4(a))),cnsti4(2)))

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

# emit/mov>cnsti4(1)
movl $1, (R3)
# emit/mov>asgni4(addrlp4(i),cnsti4(1))

# emit asgni

# (ADDRL)
# (offset -12)
movl (fp), %eax
movl push(%eax), %eax
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

# emit/mov>jumpv(addrgp4(13))

# emit jumpv

# (direct jump)
movl $.LCI13-0x80000000, %eax
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

# emit/mov>addrlp4(i)

# emit addrlp

# (offset -12)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indiri4(addrlp4(i))

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
# emit/mov>lshi4(indiri4(addrlp4(i)),cnsti4(2))

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

# emit/mov>asgni4(vregp(2),lshi4(indiri4(addrlp4(i)),cnsti4(2)))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>addrfp4(a)

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

# emit/mov>indirp4(addrfp4(a))

# emit indirp

movl (R2), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R2)

# end emit indirp

# emit/mov>asgnp4(vregp(3),indirp4(addrfp4(a)))

# emit asgnp


# (emit vreg asgn)


# end emit asgnp

# emit/mov>indiri4(vregp(2))

# emit/mov>indirp4(vregp(3))

# emit/mov>addp4(indiri4(vregp(2)),indirp4(vregp(3)))

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
movl %eax, (R1)

# end emit addp

# emit/mov>indirp4(vregp((R1)))

# emit/mov>asgnp4(addrlp4(14),indirp4(vregp((R1))))

# emit asgnp

# (ADDRL)
# (offset -32)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (R1), %edx
movl %edx, (%eax)

# end emit asgnp

# emit/mov>addrlp4(p)

# emit addrlp

# (offset -28)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R0)

# end emit addrlp

# emit/mov>indiri4(addrlp4(p))

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

# emit/mov>cnsti4(4)
movl $4, (R1)
# emit/mov>subi4(indiri4(vregp(2)),cnsti4(4))

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

# emit/mov>indirp4(vregp(3))

# emit/mov>addp4(subi4(indiri4(vregp(2)),cnsti4(4)),indirp4(vregp(3)))

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

# emit/mov>indirp4(addp4(subi4(indiri4(vregp(2)),cnsti4(4)),indirp4(vregp(3))))

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

# emit/mov>addp4(indiri4(addrlp4(p)),indirp4(addp4(subi4(indiri4(vregp(2)),cnsti4(4)),indirp4(vregp(3)))))

# emit addp

movl (R0), %eax
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

# emit/mov>addrlp4(14)

# emit addrlp

# (offset -32)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R2)

# end emit addrlp

# emit/mov>indirp4(addrlp4(14))

# emit indirp

movl (R2), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R2)

# end emit indirp

# emit/mov>asgnp4(indirp4(addrlp4(14)),addp4(indiri4(addrlp4(p)),indirp4(addp4(subi4(indiri4(vregp(2)),cnsti4(4)),indirp4(vregp(3))))))

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

# emit/mov>cnsti4(2)
movl $2, (R3)
# emit/mov>asgni4(vregp(4),cnsti4(2))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>addrlp4(i)

# emit addrlp

# (offset -12)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R2)

# end emit addrlp

# emit/mov>indiri4(addrlp4(i))

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

# emit/mov>indiri4(vregp(4))

# emit/mov>lshi4(indiri4(addrlp4(i)),indiri4(vregp(4)))

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

# emit/mov>asgni4(vregp(5),lshi4(indiri4(addrlp4(i)),indiri4(vregp(4))))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>indiri4(vregp(5))

# emit/mov>addrfp4(b)

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
movl %eax, (R1)

# end emit addrfp

# emit/mov>indirp4(addrfp4(b))

# emit indirp

movl (R1), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R1)

# end emit indirp

# emit/mov>addp4(indiri4(vregp(5)),indirp4(addrfp4(b)))

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
movl %eax, (R1)

# end emit addp

# emit/mov>indiri4(vregp(5))

# emit/mov>addrfp4(a)

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

# emit/mov>indirp4(addrfp4(a))

# emit indirp

movl (R0), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R0)

# end emit indirp

# emit/mov>addp4(indiri4(vregp(5)),indirp4(addrfp4(a)))

# emit addp

movl (R2), %eax
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
movl %eax, (R2)

# end emit addp

# emit/mov>indirp4(addp4(indiri4(vregp(5)),indirp4(addrfp4(a))))

# emit indirp

movl (R2), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R2)

# end emit indirp

# emit/mov>indiri4(vregp(4))

# emit/mov>addp4(indirp4(addp4(indiri4(vregp(5)),indirp4(addrfp4(a)))),indiri4(vregp(4)))

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

# emit/mov>asgnp4(addp4(indiri4(vregp(5)),indirp4(addrfp4(b))),addp4(indirp4(addp4(indiri4(vregp(5)),indirp4(addrfp4(a)))),indiri4(vregp(4))))

# emit asgnp

# (!ADDRL)
movl (R1), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (R3), %edx
movl %edx, (%eax)

# end emit asgnp

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

# emit/mov>addrlp4(i)

# emit addrlp

# (offset -12)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indiri4(addrlp4(i))

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
# emit/mov>addi4(indiri4(addrlp4(i)),cnsti4(1))

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

# emit/mov>asgni4(addrlp4(i),addi4(indiri4(addrlp4(i)),cnsti4(1)))

# emit asgni

# (ADDRL)
# (offset -12)
movl (fp), %eax
movl push(%eax), %eax
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

# emit/mov>addrlp4(i)

# emit addrlp

# (offset -12)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indiri4(addrlp4(i))

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

# emit/mov>addrlp4(q)

# emit addrlp

# (offset -24)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R2)

# end emit addrlp

# emit/mov>indiri4(addrlp4(q))

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

# emit/mov>lti4(indiri4(addrlp4(i)),indiri4(addrlp4(q)))

# emit lti

movl (R3), %eax
movl (R2), %edx
movl $.LCI10-0x80000000, %ecx
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

# emit/mov>addrlp4(p)

# emit addrlp

# (offset -28)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indiri4(addrlp4(p))

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

# emit/mov>addrlp4(q)

# emit addrlp

# (offset -24)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R2)

# end emit addrlp

# emit/mov>indiri4(addrlp4(q))

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

# emit/mov>muli4(indiri4(addrlp4(p)),indiri4(addrlp4(q)))

# emit muli

movl (R3), %eax
movl (R2), %edx
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
movl %eax, (R3)

# end emit muli

# emit/mov>load(muli4(indiri4(addrlp4(p)),indiri4(addrlp4(q))))

# emit loadu

movl (R3), %eax
movl %eax, (R3)

# end emit loadu

# emit/mov>argu4(load(muli4(indiri4(addrlp4(p)),indiri4(addrlp4(q)))))

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

# emit/mov>cnsti4(255)
movl $255, (R3)
# emit/mov>argi4(cnsti4(255))

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

# emit/mov>addrfp4(a)

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

# emit/mov>indirp4(addrfp4(a))

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

# emit/mov>indirp4(indirp4(addrfp4(a)))

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

# emit/mov>argp4(indirp4(indirp4(addrfp4(a))))

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

# emit/mov>callp4(addrgp4(memset))

# emit callp

# call 'memset'
# (direct call)
# memset is external
# push return
movl $.LCE31-0x80000000, %eax
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
movl $memset, (external)
movl (on), %eax
movl fault(,%eax,4), %eax
movl (%eax), %eax
.LCE31:
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

# end emit callp

# emit/mov>cnsti4(0)
movl $0, (R3)
# emit/mov>asgni4(addrlp4(i),cnsti4(0))

# emit asgni

# (ADDRL)
# (offset -12)
movl (fp), %eax
movl push(%eax), %eax
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

# emit/mov>jumpv(addrgp4(17))

# emit jumpv

# (direct jump)
movl $.LCI17-0x80000000, %eax
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

# emit/mov>cnsti4(0)
movl $0, (R3)
# emit/mov>asgni4(addrlp4(j),cnsti4(0))

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

# emit/mov>jumpv(addrgp4(21))

# emit jumpv

# (direct jump)
movl $.LCI21-0x80000000, %eax
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

# emit/mov>labelv(18)

# emit labelv

.LCI18:
movl (target), %eax
movl $.LCI18-0x80000000, %edx
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

# emit/mov>cnsti4(0)
movl $0, (R3)
# emit/mov>asgni4(addrlp4(k),cnsti4(0))

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

# emit/mov>addrlp4(j)

# emit addrlp

# (offset -8)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indiri4(addrlp4(j))

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

# emit/mov>indiri4(vregp((R3)))

# emit/mov>asgni4(addrlp4(15),indiri4(vregp((R3))))

# emit asgni

# (ADDRL)
# (offset -32)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
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

# emit/mov>asgni4(vregp(6),indiri4(addrlp4(j)))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>cnsti4(2)
movl $2, (R2)
# emit/mov>asgni4(vregp(7),cnsti4(2))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>addrlp4(k)

# emit addrlp

# (offset -4)
movl (fp), %eax
movl push(%eax), %eax
movl %eax, (R1)

# end emit addrlp

# emit/mov>indiri4(addrlp4(k))

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

# emit/mov>indiri4(vregp(7))

# emit/mov>lshi4(indiri4(addrlp4(k)),indiri4(vregp(7)))

# emit lshi

movl (R1), %eax
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
movl %eax, (R1)

# end emit lshi

# emit/mov>asgni4(vregp(8),lshi4(indiri4(addrlp4(k)),indiri4(vregp(7))))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>indiri4(vregp(6))

# emit/mov>indiri4(vregp(8))

# emit/mov>addrgp4(dx)

# emit addrgp

movl $dx, %eax
movl %eax, (R0)

# end emit addrgp

# emit/mov>addp4(indiri4(vregp(8)),addrgp4(dx))

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
movl %eax, (R0)

# end emit addp

# emit/mov>indiri4(addp4(indiri4(vregp(8)),addrgp4(dx)))

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

# emit/mov>addi4(indiri4(vregp(6)),indiri4(addp4(indiri4(vregp(8)),addrgp4(dx))))

# emit addi

movl (R3), %eax
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
movl %eax, (R0)

# end emit addi

# emit/mov>asgni4(addrlp4(x),addi4(indiri4(vregp(6)),indiri4(addp4(indiri4(vregp(8)),addrgp4(dx)))))

# emit asgni

# (ADDRL)
# (offset -16)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (R0), %edx
movl %edx, (%eax)

# end emit asgni

# emit/mov>addrlp4(i)

# emit addrlp

# (offset -12)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R0)

# end emit addrlp

# emit/mov>indiri4(addrlp4(i))

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

# emit/mov>asgni4(vregp(9),indiri4(addrlp4(i)))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>indiri4(vregp(9))

# emit/mov>indiri4(vregp(8))

# emit/mov>addrgp4(dy)

# emit addrgp

movl $dy, %eax
movl %eax, (R3)

# end emit addrgp

# emit/mov>addp4(indiri4(vregp(8)),addrgp4(dy))

# emit addp

movl (R1), %eax
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

# emit/mov>indiri4(addp4(indiri4(vregp(8)),addrgp4(dy)))

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

# emit/mov>addi4(indiri4(vregp(9)),indiri4(addp4(indiri4(vregp(8)),addrgp4(dy))))

# emit addi

movl (R0), %eax
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

# emit/mov>asgni4(addrlp4(y),addi4(indiri4(vregp(9)),indiri4(addp4(indiri4(vregp(8)),addrgp4(dy)))))

# emit asgni

# (ADDRL)
# (offset -20)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
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

# emit/mov>indiri4(vregp(6))

# emit/mov>indiri4(vregp(9))

# emit/mov>indiri4(vregp(7))

# emit/mov>lshi4(indiri4(vregp(9)),indiri4(vregp(7)))

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
movl %eax, (R3)

# end emit lshi

# emit/mov>cnsti4(8)
movl $8, (R2)
# emit/mov>addi4(lshi4(indiri4(vregp(9)),indiri4(vregp(7))),cnsti4(8))

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

# emit/mov>addrfp4(b)

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
movl %eax, (R2)

# end emit addrfp

# emit/mov>indirp4(addrfp4(b))

# emit indirp

movl (R2), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R2)

# end emit indirp

# emit/mov>addp4(addi4(lshi4(indiri4(vregp(9)),indiri4(vregp(7))),cnsti4(8)),indirp4(addrfp4(b)))

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

# emit/mov>indirp4(addp4(addi4(lshi4(indiri4(vregp(9)),indiri4(vregp(7))),cnsti4(8)),indirp4(addrfp4(b))))

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

# emit/mov>addrlp4(15)

# emit addrlp

# (offset -32)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R2)

# end emit addrlp

# emit/mov>indiri4(addrlp4(15))

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

# emit/mov>addp4(indiri4(addrlp4(15)),indirp4(addp4(addi4(lshi4(indiri4(vregp(9)),indiri4(vregp(7))),cnsti4(8)),indirp4(addrfp4(b)))))

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

# emit/mov>indiru1(addp4(indiri4(addrlp4(15)),indirp4(addp4(addi4(lshi4(indiri4(vregp(9)),indiri4(vregp(7))),cnsti4(8)),indirp4(addrfp4(b))))))

# emit indiru

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl $0, %edx
movb (%eax), %dl
movl %edx, (R0)

# end emit indiru

# emit/mov>cvui4(indiru1(addp4(indiri4(addrlp4(15)),indirp4(addp4(addi4(lshi4(indiri4(vregp(9)),indiri4(vregp(7))),cnsti4(8)),indirp4(addrfp4(b)))))))

# emit cvui

# (zero extend)

movl $0, %edx
movb (R0), %dl
movl %edx, (R3)

# end emit cvui

# emit/mov>cnsti4(255)
movl $255, (R2)
# emit/mov>nei4(cvui4(indiru1(addp4(indiri4(addrlp4(15)),indirp4(addp4(addi4(lshi4(indiri4(vregp(9)),indiri4(vregp(7))),cnsti4(8)),indirp4(addrfp4(b))))))),cnsti4(255))

# emit nei

movl (R3), %eax
movl (R2), %edx
movl $.LCI26-0x80000000, %ecx
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

# emit/mov>addrlp4(j)

# emit addrlp

# (offset -8)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indiri4(addrlp4(j))

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

# emit/mov>addrlp4(i)

# emit addrlp

# (offset -12)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R2)

# end emit addrlp

# emit/mov>indiri4(addrlp4(i))

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
# emit/mov>lshi4(indiri4(addrlp4(i)),cnsti4(2))

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

# emit/mov>cnsti4(8)
movl $8, (R1)
# emit/mov>addi4(lshi4(indiri4(addrlp4(i)),cnsti4(2)),cnsti4(8))

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

# emit/mov>addrfp4(b)

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
movl %eax, (R1)

# end emit addrfp

# emit/mov>indirp4(addrfp4(b))

# emit indirp

movl (R1), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R1)

# end emit indirp

# emit/mov>addp4(addi4(lshi4(indiri4(addrlp4(i)),cnsti4(2)),cnsti4(8)),indirp4(addrfp4(b)))

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

# emit/mov>indirp4(addp4(addi4(lshi4(indiri4(addrlp4(i)),cnsti4(2)),cnsti4(8)),indirp4(addrfp4(b))))

# emit indirp

movl (R2), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R2)

# end emit indirp

# emit/mov>addp4(indiri4(addrlp4(j)),indirp4(addp4(addi4(lshi4(indiri4(addrlp4(i)),cnsti4(2)),cnsti4(8)),indirp4(addrfp4(b)))))

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

# emit/mov>cnstu1(0)
movl $0, (R0)
# emit/mov>asgnu1(addp4(indiri4(addrlp4(j)),indirp4(addp4(addi4(lshi4(indiri4(addrlp4(i)),cnsti4(2)),cnsti4(8)),indirp4(addrfp4(b))))),cnstu1(0))

# emit asgnu

# (!ADDRL)
movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movb (R0), %dl
movb %dl, (%eax)

# end emit asgnu

# emit/mov>labelv(26)

# emit labelv

.LCI26:
movl (target), %eax
movl $.LCI26-0x80000000, %edx
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

# (offset -16)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
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

# emit/mov>asgni4(vregp(10),indiri4(addrlp4(x)))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>cnsti4(0)
movl $0, (R2)
# emit/mov>asgni4(vregp(11),cnsti4(0))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>indiri4(vregp(10))

# emit/mov>indiri4(vregp(11))

# emit/mov>lti4(indiri4(vregp(10)),indiri4(vregp(11)))

# emit lti

movl (R3), %eax
movl (R2), %edx
movl $.LCI29-0x80000000, %ecx
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

# emit/mov>indiri4(vregp(10))

# emit/mov>addrfp4(w)

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

# emit/mov>indiri4(addrfp4(w))

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

# emit/mov>gei4(indiri4(vregp(10)),indiri4(addrfp4(w)))

# emit gei

movl (R3), %eax
movl (R1), %edx
movl $.LCI29-0x80000000, %ecx
# jmp_gei
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
movl xnor(,%eax,4), %eax
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
# end jmp_gei

# end emit gei

# emit/mov>addrlp4(y)

# emit addrlp

# (offset -20)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indiri4(addrlp4(y))

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

# emit/mov>asgni4(vregp(12),indiri4(addrlp4(y)))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>indiri4(vregp(12))

# emit/mov>indiri4(vregp(11))

# emit/mov>lti4(indiri4(vregp(12)),indiri4(vregp(11)))

# emit lti

movl (R3), %eax
movl (R2), %edx
movl $.LCI29-0x80000000, %ecx
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

# emit/mov>indiri4(vregp(12))

# emit/mov>addrfp4(h)

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

# emit/mov>indiri4(addrfp4(h))

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

# emit/mov>gei4(indiri4(vregp(12)),indiri4(addrfp4(h)))

# emit gei

movl (R3), %eax
movl (R2), %edx
movl $.LCI29-0x80000000, %ecx
# jmp_gei
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
movl xnor(,%eax,4), %eax
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
# end jmp_gei

# end emit gei

# emit/mov>cnsti4(1)
movl $1, (R3)
# emit/mov>asgni4(addrlp4(28),cnsti4(1))

# emit asgni

# (ADDRL)
# (offset -36)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
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

# emit/mov>jumpv(addrgp4(30))

# emit jumpv

# (direct jump)
movl $.LCI30-0x80000000, %eax
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

# emit/mov>labelv(29)

# emit labelv

.LCI29:
movl (target), %eax
movl $.LCI29-0x80000000, %edx
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

# emit/mov>cnsti4(0)
movl $0, (R3)
# emit/mov>asgni4(addrlp4(28),cnsti4(0))

# emit asgni

# (ADDRL)
# (offset -36)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
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

# emit/mov>labelv(30)

# emit labelv

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

# end emit labelv

# emit/mov>addrlp4(j)

# emit addrlp

# (offset -8)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indiri4(addrlp4(j))

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

# emit/mov>addrlp4(i)

# emit addrlp

# (offset -12)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R2)

# end emit addrlp

# emit/mov>indiri4(addrlp4(i))

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
# emit/mov>lshi4(indiri4(addrlp4(i)),cnsti4(2))

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

# emit/mov>cnsti4(8)
movl $8, (R1)
# emit/mov>addi4(lshi4(indiri4(addrlp4(i)),cnsti4(2)),cnsti4(8))

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

# emit/mov>addrfp4(b)

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
movl %eax, (R1)

# end emit addrfp

# emit/mov>indirp4(addrfp4(b))

# emit indirp

movl (R1), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R1)

# end emit indirp

# emit/mov>addp4(addi4(lshi4(indiri4(addrlp4(i)),cnsti4(2)),cnsti4(8)),indirp4(addrfp4(b)))

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

# emit/mov>indirp4(addp4(addi4(lshi4(indiri4(addrlp4(i)),cnsti4(2)),cnsti4(8)),indirp4(addrfp4(b))))

# emit indirp

movl (R2), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R2)

# end emit indirp

# emit/mov>addp4(indiri4(addrlp4(j)),indirp4(addp4(addi4(lshi4(indiri4(addrlp4(i)),cnsti4(2)),cnsti4(8)),indirp4(addrfp4(b)))))

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

# emit/mov>asgnp4(vregp(13),addp4(indiri4(addrlp4(j)),indirp4(addp4(addi4(lshi4(indiri4(addrlp4(i)),cnsti4(2)),cnsti4(8)),indirp4(addrfp4(b))))))

# emit asgnp


# (emit vreg asgn)


# end emit asgnp

# emit/mov>indirp4(vregp(13))

# emit/mov>indirp4(vregp(13))

# emit/mov>indiru1(indirp4(vregp(13)))

# emit indiru

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl $0, %edx
movb (%eax), %dl
movl %edx, (R0)

# end emit indiru

# emit/mov>cvui4(indiru1(indirp4(vregp(13))))

# emit cvui

# (zero extend)

movl $0, %edx
movb (R0), %dl
movl %edx, (R2)

# end emit cvui

# emit/mov>addrlp4(28)

# emit addrlp

# (offset -36)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R1)

# end emit addrlp

# emit/mov>indiri4(addrlp4(28))

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

# emit/mov>addi4(cvui4(indiru1(indirp4(vregp(13)))),indiri4(addrlp4(28)))

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

# emit/mov>load(addi4(cvui4(indiru1(indirp4(vregp(13)))),indiri4(addrlp4(28))))

# emit loadu

movl (R2), %eax
movl %eax, (R2)

# end emit loadu

# emit/mov>load(load(addi4(cvui4(indiru1(indirp4(vregp(13)))),indiri4(addrlp4(28)))))

# emit loadu

movl (R2), %eax
movl %eax, (R0)

# end emit loadu

# emit/mov>asgnu1(indirp4(vregp(13)),load(load(addi4(cvui4(indiru1(indirp4(vregp(13)))),indiri4(addrlp4(28))))))

# emit asgnu

# (!ADDRL)
movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movb (R0), %dl
movb %dl, (%eax)

# end emit asgnu

# emit/mov>labelv(23)

# emit labelv

.LCI23:
movl (target), %eax
movl $.LCI23-0x80000000, %edx
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

# emit/mov>addrlp4(k)

# emit addrlp

# (offset -4)
movl (fp), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indiri4(addrlp4(k))

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
# emit/mov>addi4(indiri4(addrlp4(k)),cnsti4(1))

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

# emit/mov>asgni4(addrlp4(k),addi4(indiri4(addrlp4(k)),cnsti4(1)))

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

# emit/mov>addrlp4(k)

# emit addrlp

# (offset -4)
movl (fp), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indiri4(addrlp4(k))

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

# emit/mov>cnsti4(8)
movl $8, (R2)
# emit/mov>lti4(indiri4(addrlp4(k)),cnsti4(8))

# emit lti

movl (R3), %eax
movl (R2), %edx
movl $.LCI22-0x80000000, %ecx
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

# emit/mov>labelv(19)

# emit labelv

.LCI19:
movl (target), %eax
movl $.LCI19-0x80000000, %edx
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

# emit/mov>addrlp4(j)

# emit addrlp

# (offset -8)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indiri4(addrlp4(j))

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
# emit/mov>addi4(indiri4(addrlp4(j)),cnsti4(1))

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

# emit/mov>asgni4(addrlp4(j),addi4(indiri4(addrlp4(j)),cnsti4(1)))

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

# emit/mov>labelv(21)

# emit labelv

.LCI21:
movl (target), %eax
movl $.LCI21-0x80000000, %edx
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

# emit/mov>addrlp4(j)

# emit addrlp

# (offset -8)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indiri4(addrlp4(j))

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

# emit/mov>addrfp4(w)

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

# emit/mov>indiri4(addrfp4(w))

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

# emit/mov>lti4(indiri4(addrlp4(j)),indiri4(addrfp4(w)))

# emit lti

movl (R3), %eax
movl (R2), %edx
movl $.LCI18-0x80000000, %ecx
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

# emit/mov>addrlp4(i)

# emit addrlp

# (offset -12)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indiri4(addrlp4(i))

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
# emit/mov>addi4(indiri4(addrlp4(i)),cnsti4(1))

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

# emit/mov>asgni4(addrlp4(i),addi4(indiri4(addrlp4(i)),cnsti4(1)))

# emit asgni

# (ADDRL)
# (offset -12)
movl (fp), %eax
movl push(%eax), %eax
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

# emit/mov>labelv(17)

# emit labelv

.LCI17:
movl (target), %eax
movl $.LCI17-0x80000000, %edx
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

# emit/mov>addrlp4(i)

# emit addrlp

# (offset -12)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indiri4(addrlp4(i))

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

# emit/mov>addrfp4(h)

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

# emit/mov>indiri4(addrfp4(h))

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

# emit/mov>lti4(indiri4(addrlp4(i)),indiri4(addrfp4(h)))

# emit lti

movl (R3), %eax
movl (R2), %edx
movl $.LCI14-0x80000000, %ecx
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
.Lf32:
.size init_board,.Lf32-init_board

# export 'walk_board'
.globl walk_board
.type walk_board,@function
walk_board:  # <LCI>
# label
movl (target), %eax
movl $walk_board-0x80000000, %edx
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
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
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
# emit/mov>cnsti4(0)
movl $0, (R3)
# emit/mov>asgni4(addrlp4(steps),cnsti4(0))

# emit asgni

# (ADDRL)
# (offset -20)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
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

# emit/mov>cnsti4(1)
movl $1, (R3)
# emit/mov>asgni4(vregp(1),cnsti4(1))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>addrfp4(x)

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

# emit/mov>indiri4(addrfp4(x))

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

# emit/mov>indiri4(vregp(1))

# emit/mov>lshi4(indiri4(addrfp4(x)),indiri4(vregp(1)))

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

# emit/mov>indiri4(vregp(1))

# emit/mov>addi4(lshi4(indiri4(addrfp4(x)),indiri4(vregp(1))),indiri4(vregp(1)))

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
movl %eax, (R2)

# end emit addi

# emit/mov>argi4(addi4(lshi4(indiri4(addrfp4(x)),indiri4(vregp(1))),indiri4(vregp(1))))

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

# emit/mov>addrfp4(y)

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
movl %eax, (R2)

# end emit addrfp

# emit/mov>indiri4(addrfp4(y))

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

# emit/mov>indiri4(vregp(1))

# emit/mov>addi4(indiri4(addrfp4(y)),indiri4(vregp(1)))

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

# emit/mov>argi4(addi4(indiri4(addrfp4(y)),indiri4(vregp(1))))

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

# emit/mov>addrgp4(34)

# emit addrgp

movl $.LCS34, %eax
movl %eax, (R3)

# end emit addrgp

# emit/mov>argp4(addrgp4(34))

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
movl $.LCE58-0x80000000, %eax
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
.LCE58:
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

# emit/mov>jumpv(addrgp4(36))

# emit jumpv

# (direct jump)
movl $.LCI36-0x80000000, %eax
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

# emit/mov>labelv(35)

# emit labelv

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

# end emit labelv

# emit/mov>addrfp4(x)

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

# emit/mov>indiri4(addrfp4(x))

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

# emit/mov>addrfp4(y)

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
movl %eax, (R2)

# end emit addrfp

# emit/mov>indiri4(addrfp4(y))

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
# emit/mov>lshi4(indiri4(addrfp4(y)),cnsti4(2))

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

# emit/mov>addrfp4(b)

# emit addrfp

# (offset 60)
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
movl pop(%eax), %eax
movl %eax, (R1)

# end emit addrfp

# emit/mov>indirp4(addrfp4(b))

# emit indirp

movl (R1), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R1)

# end emit indirp

# emit/mov>addp4(lshi4(indiri4(addrfp4(y)),cnsti4(2)),indirp4(addrfp4(b)))

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

# emit/mov>indirp4(addp4(lshi4(indiri4(addrfp4(y)),cnsti4(2)),indirp4(addrfp4(b))))

# emit indirp

movl (R2), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R2)

# end emit indirp

# emit/mov>addp4(indiri4(addrfp4(x)),indirp4(addp4(lshi4(indiri4(addrfp4(y)),cnsti4(2)),indirp4(addrfp4(b)))))

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

# emit/mov>cnstu1(255)
movl $255, (R0)
# emit/mov>asgnu1(addp4(indiri4(addrfp4(x)),indirp4(addp4(lshi4(indiri4(addrfp4(y)),cnsti4(2)),indirp4(addrfp4(b))))),cnstu1(255))

# emit asgnu

# (!ADDRL)
movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movb (R0), %dl
movb %dl, (%eax)

# end emit asgnu

# emit/mov>cnsti4(0)
movl $0, (R3)
# emit/mov>asgni4(addrlp4(i),cnsti4(0))

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

# emit/mov>labelv(38)

# emit labelv

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

# end emit labelv

# emit/mov>cnsti4(2)
movl $2, (R3)
# emit/mov>asgni4(vregp(2),cnsti4(2))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>addrlp4(i)

# emit addrlp

# (offset -4)
movl (fp), %eax
movl push(%eax), %eax
movl %eax, (R2)

# end emit addrlp

# emit/mov>indiri4(addrlp4(i))

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

# emit/mov>indiri4(vregp(2))

# emit/mov>lshi4(indiri4(addrlp4(i)),indiri4(vregp(2)))

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

# emit/mov>asgni4(vregp(3),lshi4(indiri4(addrlp4(i)),indiri4(vregp(2))))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>addrfp4(x)

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
movl %eax, (R1)

# end emit addrfp

# emit/mov>indiri4(addrfp4(x))

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

# emit/mov>addrgp4(dx)

# emit addrgp

movl $dx, %eax
movl %eax, (R0)

# end emit addrgp

# emit/mov>addp4(indiri4(vregp(3)),addrgp4(dx))

# emit addp

movl (R2), %eax
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
movl %eax, (R0)

# end emit addp

# emit/mov>indiri4(addp4(indiri4(vregp(3)),addrgp4(dx)))

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

# emit/mov>addi4(indiri4(addrfp4(x)),indiri4(addp4(indiri4(vregp(3)),addrgp4(dx))))

# emit addi

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

# end emit addi

# emit/mov>indiri4(vregp((R1)))

# emit/mov>asgni4(addrlp4(12),indiri4(vregp((R1))))

# emit asgni

# (ADDRL)
# (offset -24)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (R1), %edx
movl %edx, (%eax)

# end emit asgni

# emit/mov>addrfp4(y)

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
movl %eax, (R0)

# end emit addrfp

# emit/mov>indiri4(addrfp4(y))

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

# emit/mov>indiri4(vregp(3))

# emit/mov>addrgp4(dy)

# emit addrgp

movl $dy, %eax
movl %eax, (R1)

# end emit addrgp

# emit/mov>addp4(indiri4(vregp(3)),addrgp4(dy))

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

# emit/mov>indiri4(addp4(indiri4(vregp(3)),addrgp4(dy)))

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

# emit/mov>addi4(indiri4(addrfp4(y)),indiri4(addp4(indiri4(vregp(3)),addrgp4(dy))))

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
movl %eax, (R2)

# end emit addi

# emit/mov>indiri4(vregp(2))

# emit/mov>lshi4(addi4(indiri4(addrfp4(y)),indiri4(addp4(indiri4(vregp(3)),addrgp4(dy)))),indiri4(vregp(2)))

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
movl %eax, (R3)

# end emit lshi

# emit/mov>addrfp4(b)

# emit addrfp

# (offset 60)
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
movl pop(%eax), %eax
movl %eax, (R2)

# end emit addrfp

# emit/mov>indirp4(addrfp4(b))

# emit indirp

movl (R2), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R2)

# end emit indirp

# emit/mov>addp4(lshi4(addi4(indiri4(addrfp4(y)),indiri4(addp4(indiri4(vregp(3)),addrgp4(dy)))),indiri4(vregp(2))),indirp4(addrfp4(b)))

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

# emit/mov>indirp4(addp4(lshi4(addi4(indiri4(addrfp4(y)),indiri4(addp4(indiri4(vregp(3)),addrgp4(dy)))),indiri4(vregp(2))),indirp4(addrfp4(b))))

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

# emit/mov>addrlp4(12)

# emit addrlp

# (offset -24)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R2)

# end emit addrlp

# emit/mov>indiri4(addrlp4(12))

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

# emit/mov>addp4(indiri4(addrlp4(12)),indirp4(addp4(lshi4(addi4(indiri4(addrfp4(y)),indiri4(addp4(indiri4(vregp(3)),addrgp4(dy)))),indiri4(vregp(2))),indirp4(addrfp4(b)))))

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

# emit/mov>asgnp4(vregp(4),addp4(indiri4(addrlp4(12)),indirp4(addp4(lshi4(addi4(indiri4(addrfp4(y)),indiri4(addp4(indiri4(vregp(3)),addrgp4(dy)))),indiri4(vregp(2))),indirp4(addrfp4(b))))))

# emit asgnp


# (emit vreg asgn)


# end emit asgnp

# emit/mov>indirp4(vregp(4))

# emit/mov>indirp4(vregp(4))

# emit/mov>indiru1(indirp4(vregp(4)))

# emit indiru

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl $0, %edx
movb (%eax), %dl
movl %edx, (R0)

# end emit indiru

# emit/mov>cvui4(indiru1(indirp4(vregp(4))))

# emit cvui

# (zero extend)

movl $0, %edx
movb (R0), %dl
movl %edx, (R2)

# end emit cvui

# emit/mov>cnsti4(1)
movl $1, (R1)
# emit/mov>subi4(cvui4(indiru1(indirp4(vregp(4)))),cnsti4(1))

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

# emit/mov>load(subi4(cvui4(indiru1(indirp4(vregp(4)))),cnsti4(1)))

# emit loadu

movl (R2), %eax
movl %eax, (R2)

# end emit loadu

# emit/mov>load(load(subi4(cvui4(indiru1(indirp4(vregp(4)))),cnsti4(1))))

# emit loadu

movl (R2), %eax
movl %eax, (R0)

# end emit loadu

# emit/mov>asgnu1(indirp4(vregp(4)),load(load(subi4(cvui4(indiru1(indirp4(vregp(4)))),cnsti4(1)))))

# emit asgnu

# (!ADDRL)
movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movb (R0), %dl
movb %dl, (%eax)

# end emit asgnu

# emit/mov>labelv(39)

# emit labelv

.LCI39:
movl (target), %eax
movl $.LCI39-0x80000000, %edx
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

# emit/mov>addrlp4(i)

# emit addrlp

# (offset -4)
movl (fp), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indiri4(addrlp4(i))

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
# emit/mov>addi4(indiri4(addrlp4(i)),cnsti4(1))

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

# emit/mov>asgni4(addrlp4(i),addi4(indiri4(addrlp4(i)),cnsti4(1)))

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

# emit/mov>addrlp4(i)

# emit addrlp

# (offset -4)
movl (fp), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indiri4(addrlp4(i))

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

# emit/mov>cnsti4(8)
movl $8, (R2)
# emit/mov>lti4(indiri4(addrlp4(i)),cnsti4(8))

# emit lti

movl (R3), %eax
movl (R2), %edx
movl $.LCI38-0x80000000, %ecx
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

# emit/mov>cnsti4(255)
movl $255, (R3)
# emit/mov>asgni4(addrlp4(least),cnsti4(255))

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

# emit/mov>cnsti4(0)
movl $0, (R3)
# emit/mov>asgni4(addrlp4(i),cnsti4(0))

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

# emit/mov>cnsti4(2)
movl $2, (R3)
# emit/mov>asgni4(vregp(5),cnsti4(2))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>addrlp4(i)

# emit addrlp

# (offset -4)
movl (fp), %eax
movl push(%eax), %eax
movl %eax, (R2)

# end emit addrlp

# emit/mov>indiri4(addrlp4(i))

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

# emit/mov>indiri4(vregp(5))

# emit/mov>lshi4(indiri4(addrlp4(i)),indiri4(vregp(5)))

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

# emit/mov>asgni4(vregp(6),lshi4(indiri4(addrlp4(i)),indiri4(vregp(5))))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>addrfp4(x)

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
movl %eax, (R1)

# end emit addrfp

# emit/mov>indiri4(addrfp4(x))

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

# emit/mov>addrgp4(dx)

# emit addrgp

movl $dx, %eax
movl %eax, (R0)

# end emit addrgp

# emit/mov>addp4(indiri4(vregp(6)),addrgp4(dx))

# emit addp

movl (R2), %eax
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
movl %eax, (R0)

# end emit addp

# emit/mov>indiri4(addp4(indiri4(vregp(6)),addrgp4(dx)))

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

# emit/mov>addi4(indiri4(addrfp4(x)),indiri4(addp4(indiri4(vregp(6)),addrgp4(dx))))

# emit addi

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

# end emit addi

# emit/mov>indiri4(vregp((R1)))

# emit/mov>asgni4(addrlp4(13),indiri4(vregp((R1))))

# emit asgni

# (ADDRL)
# (offset -28)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (R1), %edx
movl %edx, (%eax)

# end emit asgni

# emit/mov>addrfp4(y)

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
movl %eax, (R0)

# end emit addrfp

# emit/mov>indiri4(addrfp4(y))

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

# emit/mov>indiri4(vregp(6))

# emit/mov>addrgp4(dy)

# emit addrgp

movl $dy, %eax
movl %eax, (R1)

# end emit addrgp

# emit/mov>addp4(indiri4(vregp(6)),addrgp4(dy))

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

# emit/mov>indiri4(addp4(indiri4(vregp(6)),addrgp4(dy)))

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

# emit/mov>addi4(indiri4(addrfp4(y)),indiri4(addp4(indiri4(vregp(6)),addrgp4(dy))))

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
movl %eax, (R2)

# end emit addi

# emit/mov>indiri4(vregp(5))

# emit/mov>lshi4(addi4(indiri4(addrfp4(y)),indiri4(addp4(indiri4(vregp(6)),addrgp4(dy)))),indiri4(vregp(5)))

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
movl %eax, (R3)

# end emit lshi

# emit/mov>addrfp4(b)

# emit addrfp

# (offset 60)
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
movl pop(%eax), %eax
movl %eax, (R2)

# end emit addrfp

# emit/mov>indirp4(addrfp4(b))

# emit indirp

movl (R2), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R2)

# end emit indirp

# emit/mov>addp4(lshi4(addi4(indiri4(addrfp4(y)),indiri4(addp4(indiri4(vregp(6)),addrgp4(dy)))),indiri4(vregp(5))),indirp4(addrfp4(b)))

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

# emit/mov>indirp4(addp4(lshi4(addi4(indiri4(addrfp4(y)),indiri4(addp4(indiri4(vregp(6)),addrgp4(dy)))),indiri4(vregp(5))),indirp4(addrfp4(b))))

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

# emit/mov>addrlp4(13)

# emit addrlp

# (offset -28)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R2)

# end emit addrlp

# emit/mov>indiri4(addrlp4(13))

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

# emit/mov>addp4(indiri4(addrlp4(13)),indirp4(addp4(lshi4(addi4(indiri4(addrfp4(y)),indiri4(addp4(indiri4(vregp(6)),addrgp4(dy)))),indiri4(vregp(5))),indirp4(addrfp4(b)))))

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

# emit/mov>indiru1(addp4(indiri4(addrlp4(13)),indirp4(addp4(lshi4(addi4(indiri4(addrfp4(y)),indiri4(addp4(indiri4(vregp(6)),addrgp4(dy)))),indiri4(vregp(5))),indirp4(addrfp4(b))))))

# emit indiru

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl $0, %edx
movb (%eax), %dl
movl %edx, (R0)

# end emit indiru

# emit/mov>cvui4(indiru1(addp4(indiri4(addrlp4(13)),indirp4(addp4(lshi4(addi4(indiri4(addrfp4(y)),indiri4(addp4(indiri4(vregp(6)),addrgp4(dy)))),indiri4(vregp(5))),indirp4(addrfp4(b)))))))

# emit cvui

# (zero extend)

movl $0, %edx
movb (R0), %dl
movl %edx, (R3)

# end emit cvui

# emit/mov>addrlp4(least)

# emit addrlp

# (offset -8)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R2)

# end emit addrlp

# emit/mov>indiri4(addrlp4(least))

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

# emit/mov>gei4(cvui4(indiru1(addp4(indiri4(addrlp4(13)),indirp4(addp4(lshi4(addi4(indiri4(addrfp4(y)),indiri4(addp4(indiri4(vregp(6)),addrgp4(dy)))),indiri4(vregp(5))),indirp4(addrfp4(b))))))),indiri4(addrlp4(least)))

# emit gei

movl (R3), %eax
movl (R2), %edx
movl $.LCI46-0x80000000, %ecx
# jmp_gei
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
movl xnor(,%eax,4), %eax
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
# end jmp_gei

# end emit gei

# emit/mov>cnsti4(2)
movl $2, (R3)
# emit/mov>asgni4(vregp(7),cnsti4(2))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>addrlp4(i)

# emit addrlp

# (offset -4)
movl (fp), %eax
movl push(%eax), %eax
movl %eax, (R2)

# end emit addrlp

# emit/mov>indiri4(addrlp4(i))

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

# emit/mov>indiri4(vregp(7))

# emit/mov>lshi4(indiri4(addrlp4(i)),indiri4(vregp(7)))

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

# emit/mov>asgni4(vregp(8),lshi4(indiri4(addrlp4(i)),indiri4(vregp(7))))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>addrfp4(x)

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
movl %eax, (R1)

# end emit addrfp

# emit/mov>indiri4(addrfp4(x))

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

# emit/mov>indiri4(vregp(8))

# emit/mov>addrgp4(dx)

# emit addrgp

movl $dx, %eax
movl %eax, (R0)

# end emit addrgp

# emit/mov>addp4(indiri4(vregp(8)),addrgp4(dx))

# emit addp

movl (R2), %eax
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
movl %eax, (R0)

# end emit addp

# emit/mov>indiri4(addp4(indiri4(vregp(8)),addrgp4(dx)))

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

# emit/mov>addi4(indiri4(addrfp4(x)),indiri4(addp4(indiri4(vregp(8)),addrgp4(dx))))

# emit addi

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

# end emit addi

# emit/mov>asgni4(addrlp4(nx),addi4(indiri4(addrfp4(x)),indiri4(addp4(indiri4(vregp(8)),addrgp4(dx)))))

# emit asgni

# (ADDRL)
# (offset -12)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (R1), %edx
movl %edx, (%eax)

# end emit asgni

# emit/mov>addrfp4(y)

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

# emit/mov>indiri4(vregp(8))

# emit/mov>addrgp4(dy)

# emit addrgp

movl $dy, %eax
movl %eax, (R0)

# end emit addrgp

# emit/mov>addp4(indiri4(vregp(8)),addrgp4(dy))

# emit addp

movl (R2), %eax
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
movl %eax, (R2)

# end emit addp

# emit/mov>indiri4(addp4(indiri4(vregp(8)),addrgp4(dy)))

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

# emit/mov>addi4(indiri4(addrfp4(y)),indiri4(addp4(indiri4(vregp(8)),addrgp4(dy))))

# emit addi

movl (R1), %eax
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

# end emit addi

# emit/mov>asgni4(addrlp4(ny),addi4(indiri4(addrfp4(y)),indiri4(addp4(indiri4(vregp(8)),addrgp4(dy)))))

# emit asgni

# (ADDRL)
# (offset -16)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (R2), %edx
movl %edx, (%eax)

# end emit asgni

# emit/mov>addrlp4(nx)

# emit addrlp

# (offset -12)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R2)

# end emit addrlp

# emit/mov>indiri4(addrlp4(nx))

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

# emit/mov>addrlp4(ny)

# emit addrlp

# (offset -16)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R1)

# end emit addrlp

# emit/mov>indiri4(addrlp4(ny))

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

# emit/mov>indiri4(vregp(7))

# emit/mov>lshi4(indiri4(addrlp4(ny)),indiri4(vregp(7)))

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

# emit/mov>addrfp4(b)

# emit addrfp

# (offset 60)
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
movl pop(%eax), %eax
movl %eax, (R1)

# end emit addrfp

# emit/mov>indirp4(addrfp4(b))

# emit indirp

movl (R1), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (%eax), %eax
movl %eax, (R1)

# end emit indirp

# emit/mov>addp4(lshi4(indiri4(addrlp4(ny)),indiri4(vregp(7))),indirp4(addrfp4(b)))

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

# emit/mov>indirp4(addp4(lshi4(indiri4(addrlp4(ny)),indiri4(vregp(7))),indirp4(addrfp4(b))))

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

# emit/mov>addp4(indiri4(addrlp4(nx)),indirp4(addp4(lshi4(indiri4(addrlp4(ny)),indiri4(vregp(7))),indirp4(addrfp4(b)))))

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

# emit/mov>indiru1(addp4(indiri4(addrlp4(nx)),indirp4(addp4(lshi4(indiri4(addrlp4(ny)),indiri4(vregp(7))),indirp4(addrfp4(b))))))

# emit indiru

movl (R3), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl $0, %edx
movb (%eax), %dl
movl %edx, (R0)

# end emit indiru

# emit/mov>cvui4(indiru1(addp4(indiri4(addrlp4(nx)),indirp4(addp4(lshi4(indiri4(addrlp4(ny)),indiri4(vregp(7))),indirp4(addrfp4(b)))))))

# emit cvui

# (zero extend)

movl $0, %edx
movb (R0), %dl
movl %edx, (R3)

# end emit cvui

# emit/mov>asgni4(addrlp4(least),cvui4(indiru1(addp4(indiri4(addrlp4(nx)),indirp4(addp4(lshi4(indiri4(addrlp4(ny)),indiri4(vregp(7))),indirp4(addrfp4(b))))))))

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

# emit/mov>labelv(43)

# emit labelv

.LCI43:
movl (target), %eax
movl $.LCI43-0x80000000, %edx
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

# emit/mov>addrlp4(i)

# emit addrlp

# (offset -4)
movl (fp), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indiri4(addrlp4(i))

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
# emit/mov>addi4(indiri4(addrlp4(i)),cnsti4(1))

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

# emit/mov>asgni4(addrlp4(i),addi4(indiri4(addrlp4(i)),cnsti4(1)))

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

# emit/mov>addrlp4(i)

# emit addrlp

# (offset -4)
movl (fp), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indiri4(addrlp4(i))

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

# emit/mov>cnsti4(8)
movl $8, (R2)
# emit/mov>lti4(indiri4(addrlp4(i)),cnsti4(8))

# emit lti

movl (R3), %eax
movl (R2), %edx
movl $.LCI42-0x80000000, %ecx
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

# emit/mov>addrlp4(least)

# emit addrlp

# (offset -8)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indiri4(addrlp4(least))

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

# emit/mov>cnsti4(7)
movl $7, (R2)
# emit/mov>lei4(indiri4(addrlp4(least)),cnsti4(7))

# emit lei

movl (R3), %eax
movl (R2), %edx
movl $.LCI48-0x80000000, %ecx
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

# emit/mov>addrfp4(h)

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

# emit/mov>indiri4(addrfp4(h))

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
# emit/mov>addi4(indiri4(addrfp4(h)),cnsti4(2))

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

# emit/mov>argi4(addi4(indiri4(addrfp4(h)),cnsti4(2)))

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

# emit/mov>addrgp4(50)

# emit addrgp

movl $.LCS50, %eax
movl %eax, (R3)

# end emit addrgp

# emit/mov>argp4(addrgp4(50))

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
movl $.LCE59-0x80000000, %eax
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
.LCE59:
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

# emit/mov>addrlp4(steps)

# emit addrlp

# (offset -20)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indiri4(addrlp4(steps))

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

# emit/mov>addrfp4(w)

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

# emit/mov>indiri4(addrfp4(w))

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

# emit/mov>addrfp4(h)

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
movl %eax, (R1)

# end emit addrfp

# emit/mov>indiri4(addrfp4(h))

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

# emit/mov>muli4(indiri4(addrfp4(w)),indiri4(addrfp4(h)))

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

# emit/mov>cnsti4(1)
movl $1, (R1)
# emit/mov>subi4(muli4(indiri4(addrfp4(w)),indiri4(addrfp4(h))),cnsti4(1))

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

# emit/mov>nei4(indiri4(addrlp4(steps)),subi4(muli4(indiri4(addrfp4(w)),indiri4(addrfp4(h))),cnsti4(1)))

# emit nei

movl (R3), %eax
movl (R2), %edx
movl $.LCI52-0x80000000, %ecx
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
# emit/mov>asgni4(addrlp4(51),cnsti4(1))

# emit asgni

# (ADDRL)
# (offset -28)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
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

# emit/mov>jumpv(addrgp4(53))

# emit jumpv

# (direct jump)
movl $.LCI53-0x80000000, %eax
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

# emit/mov>cnsti4(0)
movl $0, (R3)
# emit/mov>asgni4(addrlp4(51),cnsti4(0))

# emit asgni

# (ADDRL)
# (offset -28)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
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

# emit/mov>labelv(53)

# emit labelv

.LCI53:
movl (target), %eax
movl $.LCI53-0x80000000, %edx
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

# emit/mov>addrlp4(51)

# emit addrlp

# (offset -28)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indiri4(addrlp4(51))

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

# emit/mov>reti4(indiri4(addrlp4(51)))

# emit reti


# end emit reti

# emit/mov>jumpv(addrgp4(33))

# emit jumpv

# (direct jump)
movl $.LCI33-0x80000000, %eax
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

# emit/mov>labelv(48)

# emit labelv

.LCI48:
movl (target), %eax
movl $.LCI48-0x80000000, %edx
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

# emit/mov>addrlp4(steps)

# emit addrlp

# (offset -20)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indiri4(addrlp4(steps))

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

# emit/mov>asgni4(vregp(9),indiri4(addrlp4(steps)))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>indiri4(vregp(9))

# emit/mov>cnsti4(1)
movl $1, (R2)
# emit/mov>addi4(indiri4(vregp(9)),cnsti4(1))

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
movl %eax, (R2)

# end emit addi

# emit/mov>asgni4(addrlp4(steps),addi4(indiri4(vregp(9)),cnsti4(1)))

# emit asgni

# (ADDRL)
# (offset -20)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (R2), %edx
movl %edx, (%eax)

# end emit asgni

# emit/mov>indiri4(vregp(9))

# emit/mov>cnsti4(0)
movl $0, (R2)
# emit/mov>eqi4(indiri4(vregp(9)),cnsti4(0))

# emit eqi

movl (R3), %eax
movl (R2), %edx
movl $.LCI54-0x80000000, %ecx
# jmp_eqi
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
movl (zf), %eax
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
# end jmp_eqi

# end emit eqi

# emit/mov>cnsti4(1)
movl $1, (R3)
# emit/mov>asgni4(vregp(10),cnsti4(1))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>addrfp4(x)

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

# emit/mov>indiri4(addrfp4(x))

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

# emit/mov>indiri4(vregp(10))

# emit/mov>lshi4(indiri4(addrfp4(x)),indiri4(vregp(10)))

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

# emit/mov>indiri4(vregp(10))

# emit/mov>addi4(lshi4(indiri4(addrfp4(x)),indiri4(vregp(10))),indiri4(vregp(10)))

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
movl %eax, (R2)

# end emit addi

# emit/mov>argi4(addi4(lshi4(indiri4(addrfp4(x)),indiri4(vregp(10))),indiri4(vregp(10))))

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

# emit/mov>addrfp4(y)

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
movl %eax, (R2)

# end emit addrfp

# emit/mov>indiri4(addrfp4(y))

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

# emit/mov>indiri4(vregp(10))

# emit/mov>addi4(indiri4(addrfp4(y)),indiri4(vregp(10)))

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

# emit/mov>argi4(addi4(indiri4(addrfp4(y)),indiri4(vregp(10))))

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

# emit/mov>addrgp4(56)

# emit addrgp

movl $.LCS56, %eax
movl %eax, (R3)

# end emit addrgp

# emit/mov>argp4(addrgp4(56))

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
movl $.LCE60-0x80000000, %eax
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
.LCE60:
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

# emit/mov>labelv(54)

# emit labelv

.LCI54:
movl (target), %eax
movl $.LCI54-0x80000000, %edx
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

# emit/mov>addrfp4(x)

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

# emit/mov>addrlp4(nx)

# emit addrlp

# (offset -12)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R2)

# end emit addrlp

# emit/mov>indiri4(addrlp4(nx))

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

# emit/mov>asgni4(addrfp4(x),indiri4(addrlp4(nx)))

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

# emit/mov>addrfp4(y)

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

# emit/mov>addrlp4(ny)

# emit addrlp

# (offset -16)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R2)

# end emit addrlp

# emit/mov>indiri4(addrlp4(ny))

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

# emit/mov>asgni4(addrfp4(y),indiri4(addrlp4(ny)))

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

# emit/mov>cnsti4(1)
movl $1, (R3)
# emit/mov>asgni4(vregp(11),cnsti4(1))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>addrfp4(x)

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

# emit/mov>indiri4(addrfp4(x))

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

# emit/mov>indiri4(vregp(11))

# emit/mov>lshi4(indiri4(addrfp4(x)),indiri4(vregp(11)))

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

# emit/mov>indiri4(vregp(11))

# emit/mov>addi4(lshi4(indiri4(addrfp4(x)),indiri4(vregp(11))),indiri4(vregp(11)))

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
movl %eax, (R2)

# end emit addi

# emit/mov>argi4(addi4(lshi4(indiri4(addrfp4(x)),indiri4(vregp(11))),indiri4(vregp(11))))

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

# emit/mov>addrfp4(y)

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
movl %eax, (R2)

# end emit addrfp

# emit/mov>indiri4(addrfp4(y))

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

# emit/mov>indiri4(vregp(11))

# emit/mov>addi4(indiri4(addrfp4(y)),indiri4(vregp(11)))

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

# emit/mov>argi4(addi4(indiri4(addrfp4(y)),indiri4(vregp(11))))

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

# emit/mov>addrgp4(57)

# emit addrgp

movl $.LCS57, %eax
movl %eax, (R3)

# end emit addrgp

# emit/mov>argp4(addrgp4(57))

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
movl $.LCE61-0x80000000, %eax
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
.LCE61:
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
movl $.LCE62-0x80000000, %eax
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
.LCE62:
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

# emit/mov>cnsti4(120000)
movl $120000, (R3)
# emit/mov>argi4(cnsti4(120000))

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
movl $.LCE63-0x80000000, %eax
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
.LCE63:
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

# emit/mov>labelv(36)

# emit labelv

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

# end emit labelv

# emit/mov>jumpv(addrgp4(35))

# emit jumpv

# (direct jump)
movl $.LCI35-0x80000000, %eax
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

# emit/mov>cnsti4(0)
movl $0, (R0)
# emit/mov>reti4(cnsti4(0))

# emit reti


# end emit reti

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
.Lf64:
.size walk_board,.Lf64-walk_board

# export 'solve'
.globl solve
.type solve,@function
solve:  # <LCI>
# label
movl (target), %eax
movl $solve-0x80000000, %edx
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
movl push(%eax), %eax
movl push(%eax), %eax
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
# emit/mov>cnsti4(0)
movl $0, (R3)
# emit/mov>asgni4(addrlp4(x),cnsti4(0))

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

# emit/mov>cnsti4(0)
movl $0, (R3)
# emit/mov>asgni4(addrlp4(y),cnsti4(0))

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

# emit/mov>cnsti4(4)
movl $4, (R3)
# emit/mov>asgni4(vregp(1),cnsti4(4))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>addrfp4(h)

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

# emit/mov>indiri4(addrfp4(h))

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

# emit/mov>indiri4(vregp(1))

# emit/mov>addi4(indiri4(addrfp4(h)),indiri4(vregp(1)))

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
movl %eax, (R2)

# end emit addi

# emit/mov>asgni4(vregp(2),addi4(indiri4(addrfp4(h)),indiri4(vregp(1))))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>addrfp4(w)

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

# emit/mov>indiri4(addrfp4(w))

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

# emit/mov>indiri4(vregp(1))

# emit/mov>addi4(indiri4(addrfp4(w)),indiri4(vregp(1)))

# emit addi

movl (R1), %eax
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

# emit/mov>indiri4(vregp(2))

# emit/mov>muli4(addi4(indiri4(addrfp4(w)),indiri4(vregp(1))),indiri4(vregp(2)))

# emit muli

movl (R3), %eax
movl (R2), %edx
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
movl %eax, (R3)

# end emit muli

# emit/mov>load(muli4(addi4(indiri4(addrfp4(w)),indiri4(vregp(1))),indiri4(vregp(2))))

# emit loadu

movl (R3), %eax
movl %eax, (R3)

# end emit loadu

# emit/mov>indiri4(vregp(2))

# emit/mov>load(indiri4(vregp(2)))

# emit loadu

movl (R2), %eax
movl %eax, (R2)

# end emit loadu

# emit/mov>cnsti4(2)
movl $2, (R1)
# emit/mov>lshu4(load(indiri4(vregp(2))),cnsti4(2))

# emit lshu

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

# end emit lshu

# emit/mov>addu4(load(muli4(addi4(indiri4(addrfp4(w)),indiri4(vregp(1))),indiri4(vregp(2)))),lshu4(load(indiri4(vregp(2))),cnsti4(2)))

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

# emit/mov>argu4(addu4(load(muli4(addi4(indiri4(addrfp4(w)),indiri4(vregp(1))),indiri4(vregp(2)))),lshu4(load(indiri4(vregp(2))),cnsti4(2))))

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

# emit/mov>callp4(addrgp4(malloc))

# emit callp

# call 'malloc'
# (direct call)
# malloc is external
# push return
movl $.LCE78-0x80000000, %eax
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
movl $malloc, (external)
movl (on), %eax
movl fault(,%eax,4), %eax
movl (%eax), %eax
.LCE78:
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

# end emit callp

# emit/mov>load(callp4(addrgp4(malloc)))

# emit loadp

movl (R0), %eax
movl %eax, (R3)

# end emit loadp

# emit/mov>asgnp4(vregp(3),load(callp4(addrgp4(malloc))))

# emit asgnp


# (emit vreg asgn)


# end emit asgnp

# emit/mov>indirp4(vregp(3))

# emit/mov>asgnp4(addrlp4(a),indirp4(vregp(3)))

# emit asgnp

# (ADDRL)
# (offset -16)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (R3), %edx
movl %edx, (%eax)

# end emit asgnp

# emit/mov>addrfp4(h)

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

# emit/mov>indiri4(addrfp4(h))

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

# emit/mov>cnsti4(4)
movl $4, (R2)
# emit/mov>addi4(indiri4(addrfp4(h)),cnsti4(4))

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

# emit/mov>load(addi4(indiri4(addrfp4(h)),cnsti4(4)))

# emit loadu

movl (R3), %eax
movl %eax, (R3)

# end emit loadu

# emit/mov>cnsti4(2)
movl $2, (R2)
# emit/mov>lshu4(load(addi4(indiri4(addrfp4(h)),cnsti4(4))),cnsti4(2))

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

# emit/mov>argu4(lshu4(load(addi4(indiri4(addrfp4(h)),cnsti4(4))),cnsti4(2)))

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

# emit/mov>callp4(addrgp4(malloc))

# emit callp

# call 'malloc'
# (direct call)
# malloc is external
# push return
movl $.LCE79-0x80000000, %eax
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
movl $malloc, (external)
movl (on), %eax
movl fault(,%eax,4), %eax
movl (%eax), %eax
.LCE79:
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

# end emit callp

# emit/mov>load(callp4(addrgp4(malloc)))

# emit loadp

movl (R0), %eax
movl %eax, (R3)

# end emit loadp

# emit/mov>asgnp4(vregp(4),load(callp4(addrgp4(malloc))))

# emit asgnp


# (emit vreg asgn)


# end emit asgnp

# emit/mov>indirp4(vregp(4))

# emit/mov>asgnp4(addrlp4(b),indirp4(vregp(4)))

# emit asgnp

# (ADDRL)
# (offset -12)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl (on), %edx
# select data %eax %edx
movl %eax, (data_p)
movl sel_data(,%edx,4), %eax
# end select data
movl (R3), %edx
movl %edx, (%eax)

# end emit asgnp

# emit/mov>jumpv(addrgp4(67))

# emit jumpv

# (direct jump)
movl $.LCI67-0x80000000, %eax
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

# emit/mov>labelv(66)

# emit labelv

.LCI66:
movl (target), %eax
movl $.LCI66-0x80000000, %edx
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

# emit/mov>addrlp4(b)

# emit addrlp

# (offset -12)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indirp4(addrlp4(b))

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

# emit/mov>argp4(indirp4(addrlp4(b)))

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

# emit/mov>addrlp4(a)

# emit addrlp

# (offset -16)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indirp4(addrlp4(a))

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

# emit/mov>argp4(indirp4(addrlp4(a)))

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

# emit/mov>addrfp4(h)

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

# emit/mov>indiri4(addrfp4(h))

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

# emit/mov>argi4(indiri4(addrfp4(h)))

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

# emit/mov>addrfp4(w)

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

# emit/mov>indiri4(addrfp4(w))

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

# emit/mov>argi4(indiri4(addrfp4(w)))

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

# emit/mov>callv(addrgp4(init_board))

# emit callv

# call 'init_board'
# (direct call)
# init_board is internal
# push return
movl $.LCI80-0x80000000, %eax
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

movl $init_board-0x80000000, %eax
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
.LCI80:
movl (target), %eax
movl $.LCI80-0x80000000, %edx
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

# emit/mov>addrlp4(b)

# emit addrlp

# (offset -12)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indirp4(addrlp4(b))

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

# emit/mov>cnsti4(8)
movl $8, (R2)
# emit/mov>addp4(indirp4(addrlp4(b)),cnsti4(8))

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

# emit/mov>argp4(addp4(indirp4(addrlp4(b)),cnsti4(8)))

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

# emit/mov>addrlp4(y)

# emit addrlp

# (offset -8)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indiri4(addrlp4(y))

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

# emit/mov>argi4(indiri4(addrlp4(y)))

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

# emit/mov>addrlp4(x)

# emit addrlp

# (offset -4)
movl (fp), %eax
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

# emit/mov>addrfp4(h)

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

# emit/mov>indiri4(addrfp4(h))

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

# emit/mov>argi4(indiri4(addrfp4(h)))

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

# emit/mov>addrfp4(w)

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

# emit/mov>indiri4(addrfp4(w))

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

# emit/mov>argi4(indiri4(addrfp4(w)))

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

# emit/mov>calli4(addrgp4(walk_board))

# emit calli

# call 'walk_board'
# (direct call)
# walk_board is internal
# push return
movl $.LCI81-0x80000000, %eax
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

movl $walk_board-0x80000000, %eax
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
.LCI81:
movl (target), %eax
movl $.LCI81-0x80000000, %edx
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
# pop args (20)
movl (sp), %eax
movl pop(%eax), %eax
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

# end emit calli

# emit/mov>load(calli4(addrgp4(walk_board)))

# emit loadi

movl (R0), %eax
movl %eax, (R3)

# end emit loadi

# emit/mov>asgni4(vregp(5),load(calli4(addrgp4(walk_board))))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>indiri4(vregp(5))

# emit/mov>cnsti4(0)
movl $0, (R2)
# emit/mov>eqi4(indiri4(vregp(5)),cnsti4(0))

# emit eqi

movl (R3), %eax
movl (R2), %edx
movl $.LCI69-0x80000000, %ecx
# jmp_eqi
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
movl (zf), %eax
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
# end jmp_eqi

# end emit eqi

# emit/mov>addrgp4(71)

# emit addrgp

movl $.LCS71, %eax
movl %eax, (R3)

# end emit addrgp

# emit/mov>argp4(addrgp4(71))

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
movl $.LCE82-0x80000000, %eax
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
.LCE82:
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

# emit/mov>cnsti4(1)
movl $1, (R0)
# emit/mov>reti4(cnsti4(1))

# emit reti


# end emit reti

# emit/mov>jumpv(addrgp4(65))

# emit jumpv

# (direct jump)
movl $.LCI65-0x80000000, %eax
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

# emit/mov>labelv(69)

# emit labelv

.LCI69:
movl (target), %eax
movl $.LCI69-0x80000000, %edx
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

# (offset -4)
movl (fp), %eax
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

# emit/mov>cnsti4(1)
movl $1, (R2)
# emit/mov>addi4(indiri4(addrlp4(x)),cnsti4(1))

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

# emit/mov>asgni4(vregp(6),addi4(indiri4(addrlp4(x)),cnsti4(1)))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>indiri4(vregp(6))

# emit/mov>asgni4(addrlp4(x),indiri4(vregp(6)))

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

# emit/mov>indiri4(vregp(6))

# emit/mov>addrfp4(w)

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

# emit/mov>indiri4(addrfp4(w))

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

# emit/mov>lti4(indiri4(vregp(6)),indiri4(addrfp4(w)))

# emit lti

movl (R3), %eax
movl (R2), %edx
movl $.LCI72-0x80000000, %ecx
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

# emit/mov>cnsti4(0)
movl $0, (R3)
# emit/mov>asgni4(addrlp4(x),cnsti4(0))

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

# emit/mov>addrlp4(y)

# emit addrlp

# (offset -8)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indiri4(addrlp4(y))

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
# emit/mov>addi4(indiri4(addrlp4(y)),cnsti4(1))

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

# emit/mov>asgni4(addrlp4(y),addi4(indiri4(addrlp4(y)),cnsti4(1)))

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

# emit/mov>labelv(72)

# emit labelv

.LCI72:
movl (target), %eax
movl $.LCI72-0x80000000, %edx
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

# emit/mov>addrlp4(y)

# emit addrlp

# (offset -8)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indiri4(addrlp4(y))

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

# emit/mov>addrfp4(h)

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

# emit/mov>indiri4(addrfp4(h))

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

# emit/mov>lti4(indiri4(addrlp4(y)),indiri4(addrfp4(h)))

# emit lti

movl (R3), %eax
movl (R2), %edx
movl $.LCI74-0x80000000, %ecx
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

# emit/mov>addrgp4(76)

# emit addrgp

movl $.LCS76, %eax
movl %eax, (R3)

# end emit addrgp

# emit/mov>argp4(addrgp4(76))

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
movl $.LCE83-0x80000000, %eax
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
.LCE83:
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

# emit/mov>cnsti4(0)
movl $0, (R0)
# emit/mov>reti4(cnsti4(0))

# emit reti


# end emit reti

# emit/mov>jumpv(addrgp4(65))

# emit jumpv

# (direct jump)
movl $.LCI65-0x80000000, %eax
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

# emit/mov>labelv(74)

# emit labelv

.LCI74:
movl (target), %eax
movl $.LCI74-0x80000000, %edx
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

# emit/mov>addrgp4(77)

# emit addrgp

movl $.LCS77, %eax
movl %eax, (R3)

# end emit addrgp

# emit/mov>argp4(addrgp4(77))

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
movl $.LCE84-0x80000000, %eax
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
.LCE84:
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

# emit/mov>calli4(addrgp4(getchar))

# emit calli

# call 'getchar'
# (direct call)
# getchar is external
# push return
movl $.LCE85-0x80000000, %eax
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
movl $getchar, (external)
movl (on), %eax
movl fault(,%eax,4), %eax
movl (%eax), %eax
.LCE85:
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
# pop args (0)
movl (sp), %eax
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

# emit/mov>labelv(67)

# emit labelv

.LCI67:
movl (target), %eax
movl $.LCI67-0x80000000, %edx
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

# emit/mov>jumpv(addrgp4(66))

# emit jumpv

# (direct jump)
movl $.LCI66-0x80000000, %eax
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

# emit/mov>cnsti4(0)
movl $0, (R0)
# emit/mov>reti4(cnsti4(0))

# emit reti


# end emit reti

# emit/mov>labelv(65)

# emit labelv

.LCI65:
movl (target), %eax
movl $.LCI65-0x80000000, %edx
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
.Lf86:
.size solve,.Lf86-solve

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
movl push(%eax), %eax
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

# emit/mov>cnsti4(2)
movl $2, (R2)
# emit/mov>lti4(indiri4(addrfp4(c)),cnsti4(2))

# emit lti

movl (R3), %eax
movl (R2), %edx
movl $.LCI90-0x80000000, %ecx
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
movl $.LCE94-0x80000000, %eax
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
.LCE94:
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

# emit/mov>indiri4(vregp(1))

# emit/mov>asgni4(addrlp4(w),indiri4(vregp(1)))

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

# emit/mov>indiri4(vregp(1))

# emit/mov>cnsti4(0)
movl $0, (R2)
# emit/mov>gti4(indiri4(vregp(1)),cnsti4(0))

# emit gti

movl (R3), %eax
movl (R2), %edx
movl $.LCI88-0x80000000, %ecx
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

# emit/mov>labelv(90)

# emit labelv

.LCI90:
movl (target), %eax
movl $.LCI90-0x80000000, %edx
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

# emit/mov>cnsti4(8)
movl $8, (R3)
# emit/mov>asgni4(addrlp4(w),cnsti4(8))

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

# emit/mov>labelv(88)

# emit labelv

.LCI88:
movl (target), %eax
movl $.LCI88-0x80000000, %edx
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

# emit/mov>cnsti4(3)
movl $3, (R2)
# emit/mov>lti4(indiri4(addrfp4(c)),cnsti4(3))

# emit lti

movl (R3), %eax
movl (R2), %edx
movl $.LCI93-0x80000000, %ecx
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

# emit/mov>cnsti4(8)
movl $8, (R2)
# emit/mov>addp4(indirp4(addrfp4(v)),cnsti4(8))

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

# emit/mov>indirp4(addp4(indirp4(addrfp4(v)),cnsti4(8)))

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

# emit/mov>argp4(indirp4(addp4(indirp4(addrfp4(v)),cnsti4(8))))

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
movl $.LCE95-0x80000000, %eax
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
.LCE95:
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

# emit/mov>asgni4(vregp(2),load(calli4(addrgp4(atoi))))

# emit asgni


# (emit vreg asgn)


# end emit asgni

# emit/mov>indiri4(vregp(2))

# emit/mov>asgni4(addrlp4(h),indiri4(vregp(2)))

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

# emit/mov>indiri4(vregp(2))

# emit/mov>cnsti4(0)
movl $0, (R2)
# emit/mov>gti4(indiri4(vregp(2)),cnsti4(0))

# emit gti

movl (R3), %eax
movl (R2), %edx
movl $.LCI91-0x80000000, %ecx
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

# emit/mov>labelv(93)

# emit labelv

.LCI93:
movl (target), %eax
movl $.LCI93-0x80000000, %edx
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

# emit/mov>addrlp4(w)

# emit addrlp

# (offset -4)
movl (fp), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indiri4(addrlp4(w))

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

# emit/mov>asgni4(addrlp4(h),indiri4(addrlp4(w)))

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

# emit/mov>labelv(91)

# emit labelv

.LCI91:
movl (target), %eax
movl $.LCI91-0x80000000, %edx
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

# emit/mov>addrlp4(h)

# emit addrlp

# (offset -8)
movl (fp), %eax
movl push(%eax), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indiri4(addrlp4(h))

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

# emit/mov>argi4(indiri4(addrlp4(h)))

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

# emit/mov>addrlp4(w)

# emit addrlp

# (offset -4)
movl (fp), %eax
movl push(%eax), %eax
movl %eax, (R3)

# end emit addrlp

# emit/mov>indiri4(addrlp4(w))

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

# emit/mov>argi4(indiri4(addrlp4(w)))

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

# emit/mov>calli4(addrgp4(solve))

# emit calli

# call 'solve'
# (direct call)
# solve is internal
# push return
movl $.LCI96-0x80000000, %eax
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

movl $solve-0x80000000, %eax
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
.LCI96:
movl (target), %eax
movl $.LCI96-0x80000000, %edx
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

# end emit calli

# emit/mov>cnsti4(0)
movl $0, (R0)
# emit/mov>reti4(cnsti4(0))

# emit reti


# end emit reti

# emit/mov>labelv(87)

# emit labelv

.LCI87:
movl (target), %eax
movl $.LCI87-0x80000000, %edx
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
.Lf97:
.size main,.Lf97-main

# import 'usleep'
.extern 'usleep'
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
# import 'strerror'
.extern 'strerror'
# import 'strlen'
.extern 'strlen'
# import 'strtok_r'
.extern 'strtok_r'
# import '__strtok_r'
.extern '__strtok_r'
# import 'strtok'
.extern 'strtok'
# import 'strstr'
.extern 'strstr'
# import 'strpbrk'
.extern 'strpbrk'
# import 'strspn'
.extern 'strspn'
# import 'strcspn'
.extern 'strcspn'
# import 'strrchr'
.extern 'strrchr'
# import 'strchr'
.extern 'strchr'
# import 'strxfrm'
.extern 'strxfrm'
# import 'strcoll'
.extern 'strcoll'
# import 'strncmp'
.extern 'strncmp'
# import 'strcmp'
.extern 'strcmp'
# import 'strncat'
.extern 'strncat'
# import 'strcat'
.extern 'strcat'
# import 'strncpy'
.extern 'strncpy'
# import 'strcpy'
.extern 'strcpy'
# import 'memchr'
.extern 'memchr'
# import '__memcmpeq'
.extern '__memcmpeq'
# import 'memcmp'
.extern 'memcmp'
# import 'memset'
.extern 'memset'
# import 'memmove'
.extern 'memmove'
# import 'memcpy'
.extern 'memcpy'
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

.bss
.type __va_arg_tmp,@object
.size __va_arg_tmp,4
.lcomm __va_arg_tmp,4

.section .plt

.data
.LCS77:  # <LCS>
.byte 0x41
.byte 0x6e
.byte 0x79
.byte 0x20
.byte 0x6b
.byte 0x65
.byte 0x79
.byte 0x20
.byte 0x74
.byte 0x6f
.byte 0x20
.byte 0x74
.byte 0x72
.byte 0x79
.byte 0x20
.byte 0x6e
.byte 0x65
.byte 0x78
.byte 0x74
.byte 0x20
.byte 0x73
.byte 0x74
.byte 0x61
.byte 0x72
.byte 0x74
.byte 0x20
.byte 0x70
.byte 0x6f
.byte 0x73
.byte 0x69
.byte 0x74
.byte 0x69
.byte 0x6f
.byte 0x6e
.byte 0x0
.LCS76:  # <LCS>
.byte 0x46
.byte 0x61
.byte 0x69
.byte 0x6c
.byte 0x65
.byte 0x64
.byte 0x20
.byte 0x74
.byte 0x6f
.byte 0x20
.byte 0x66
.byte 0x69
.byte 0x6e
.byte 0x64
.byte 0x20
.byte 0x61
.byte 0x20
.byte 0x73
.byte 0x6f
.byte 0x6c
.byte 0x75
.byte 0x74
.byte 0x69
.byte 0x6f
.byte 0x6e
.byte 0xa
.byte 0x0
.LCS71:  # <LCS>
.byte 0x53
.byte 0x75
.byte 0x63
.byte 0x63
.byte 0x65
.byte 0x73
.byte 0x73
.byte 0x21
.byte 0xa
.byte 0x0
.LCS57:  # <LCS>
.byte 0x1b
.byte 0x5b
.byte 0x25
.byte 0x64
.byte 0x3b
.byte 0x25
.byte 0x64
.byte 0x48
.byte 0x1b
.byte 0x5b
.byte 0x33
.byte 0x31
.byte 0x6d
.byte 0x5b
.byte 0x5d
.byte 0x1b
.byte 0x5b
.byte 0x6d
.byte 0x0
.LCS56:  # <LCS>
.byte 0x1b
.byte 0x5b
.byte 0x25
.byte 0x64
.byte 0x3b
.byte 0x25
.byte 0x64
.byte 0x48
.byte 0x5b
.byte 0x5d
.byte 0x0
.LCS50:  # <LCS>
.byte 0x1b
.byte 0x5b
.byte 0x25
.byte 0x64
.byte 0x48
.byte 0x0
.LCS34:  # <LCS>
.byte 0x1b
.byte 0x5b
.byte 0x48
.byte 0x1b
.byte 0x5b
.byte 0x4a
.byte 0x1b
.byte 0x5b
.byte 0x25
.byte 0x64
.byte 0x3b
.byte 0x25
.byte 0x64
.byte 0x48
.byte 0x1b
.byte 0x5b
.byte 0x33
.byte 0x32
.byte 0x6d
.byte 0x5b
.byte 0x5d
.byte 0x1b
.byte 0x5b
.byte 0x6d
.byte 0x0

.text
