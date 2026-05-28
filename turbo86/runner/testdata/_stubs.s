# Minimal libc-stub layer for static movfuscator binaries running under
# turbo86. Provides what crt0_cf.o needs from libc:
#   - sigaction: translates the userspace struct sigaction (140 bytes
#     on i386 glibc) to the kernel k_sigaction (20 bytes) and issues
#     rt_sigaction. SA_RESTORER + our own trampoline are always set so
#     handler returns don't crash, even though movfuscator's handlers
#     mostly don't return.
#   - exit: SYS_exit.
#
# Leading underscore (_stubs.s) keeps Go's package build from picking
# this file up; the testdata Makefile assembles it explicitly.

	.section .text

	.global sigaction
	.type sigaction, @function
sigaction:
	push	%ebp
	mov	%esp, %ebp
	push	%ebx
	push	%esi
	# 20-byte k_sigaction on stack (8 extra for alignment).
	sub	$28, %esp

	# k_sigaction.sa_handler = userspace_act->sa_handler  (first 4 bytes)
	mov	12(%ebp), %eax        # act
	mov	(%eax), %ecx           # *(uint32_t *)act
	mov	%ecx, (%esp)

	# k_sigaction.sa_flags = user's sa_flags | SA_RESTORER
	# Userspace struct sigaction layout (i386, glibc-compatible):
	#   off 0:   sa_handler   (4)
	#   off 4:   sa_mask      (128)
	#   off 132: sa_flags     (4)   ← we read this
	#   off 136: sa_restorer  (4)
	# Preserving the user's flags is load-bearing for movfuscator:
	# SA_NODEFER (0x40000000) lets the handler re-trigger its own
	# signal, which is exactly what the master_loop pattern needs.
	mov	132(%eax), %ecx
	or	$0x04000000, %ecx     # force-set SA_RESTORER (the kernel needs one)
	mov	%ecx, 4(%esp)

	# k_sigaction.sa_restorer = &sigaction_restorer
	movl	$sigaction_restorer, 8(%esp)

	# k_sigaction.sa_mask[0..1] = 0
	movl	$0, 12(%esp)
	movl	$0, 16(%esp)

	# rt_sigaction(signum, &kact, NULL, 8)
	mov	$174, %eax            # __NR_rt_sigaction
	mov	8(%ebp), %ebx         # signum
	mov	%esp, %ecx            # &kact
	xor	%edx, %edx            # oldact = NULL
	mov	$8, %esi              # sigsetsize
	int	$0x80

	add	$28, %esp
	pop	%esi
	pop	%ebx
	pop	%ebp
	ret

	.global sigaction_restorer
	.type sigaction_restorer, @function
sigaction_restorer:
	mov	$173, %eax            # __NR_rt_sigreturn
	int	$0x80

	.global exit
	.type exit, @function
exit:
	mov	4(%esp), %ebx         # status
	mov	$1, %eax              # __NR_exit
	int	$0x80
	# does not return
