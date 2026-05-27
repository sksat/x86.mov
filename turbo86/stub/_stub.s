# turbo86 child stub — static i386 Linux ELF.
#
# Spawned once per session by the host (turbo86 main process). Its only
# job is to (1) opt into ptrace, (2) reserve the guest's address space,
# and (3) stop itself so the host can stream guest code in via
# /proc/PID/mem and redirect EIP via PTRACE_SETREGS to begin execution.
#
# This file never returns from the kill(SIGSTOP). The parent rewrites
# EIP before resuming, so the `ud2` is a belt-and-suspenders trap.
#
# Build: as --32 stub.s -o stub.o
#        ld -m elf_i386 -static -e _start stub.o -o stub
#        strip stub

	.section .text
	.global _start
_start:
	# ptrace(PTRACE_TRACEME=0, 0, NULL, NULL)  --  __NR_ptrace = 26
	mov	$26, %eax
	xor	%ebx, %ebx
	xor	%ecx, %ecx
	xor	%edx, %edx
	xor	%esi, %esi
	int	$0x80

	# Guest code/data region: 16 MiB at 0x08048000 (conventional i386
	# ELF base). PROT_READ|WRITE|EXEC, MAP_PRIVATE|ANON|FIXED, fd=-1.
	# mmap2 syscall (__NR_mmap2 = 192). pgoff in ebp = 0.
	mov	$192, %eax
	mov	$0x08048000, %ebx
	mov	$0x01000000, %ecx
	mov	$7, %edx
	mov	$0x32, %esi
	mov	$-1, %edi
	xor	%ebp, %ebp
	int	$0x80

	# Guest stack region: 2 MiB at 0x70000000..0x70200000. Kept well
	# clear of the stub's own kernel-allocated stack (lives ~0xBFFF*).
	# PROT_READ|WRITE, MAP_PRIVATE|ANON|FIXED, fd=-1.
	mov	$192, %eax
	mov	$0x70000000, %ebx
	mov	$0x00200000, %ecx
	mov	$3, %edx
	mov	$0x32, %esi
	mov	$-1, %edi
	xor	%ebp, %ebp
	int	$0x80

	# getpid → eax  (__NR_getpid = 20)
	mov	$20, %eax
	int	$0x80

	# kill(pid, SIGSTOP=19)  (__NR_kill = 37)
	mov	%eax, %ebx
	mov	$19, %ecx
	mov	$37, %eax
	int	$0x80

	# Parent has by now overwritten EIP/ESP via PTRACE_SETREGS and will
	# resume execution at the guest entry. Never reached in normal flow.
	ud2
