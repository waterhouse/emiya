	.cstring
LC0:
	.ascii "file.file\0"
LC1:
	.ascii "open(%s,%d)\12\0"
LC2:
	.ascii "mmap(%p, %d, %d, %d, %d, %d)\12\0"
LC3:
	.ascii "%p, %p\12\0"
LC4:
	.ascii "mmap\0"
	.align 3
LC5:
	.ascii "mmap returned %p, which seems readable and writable\12\0"
	.text
.globl _main
_main:
LFB6:
	pushq	%rbp
LCFI0:
	movq	%rsp, %rbp
LCFI1:
	subq	$48, %rsp
LCFI2:
	movl	$1048576, -4(%rbp)
	leaq	LC0(%rip), %rax
	movq	%rax, -16(%rbp)
	movq	-16(%rbp), %rdi
	movl	$69, %edx
	movl	$2, %esi
	movl	$0, %eax
	call	_open
	movl	%eax, -8(%rbp)
	movq	-16(%rbp), %rsi
	movl	$2, %edx
	leaq	LC1(%rip), %rdi
	movl	$0, %eax
	call	_printf
	movl	-4(%rbp), %eax
	movslq	%eax,%rsi
	movl	-8(%rbp), %eax
	movl	$0, %r9d
	movl	%eax, %r8d
	movl	$1, %ecx
	movl	$3, %edx
	movl	$0, %edi
	call	_mmap
	movq	%rax, -24(%rbp)
	movl	-8(%rbp), %eax
	movl	-4(%rbp), %edx
	movl	$0, (%rsp)
	movl	%eax, %r9d
	movl	$1, %r8d
	movl	$3, %ecx
	movl	$0, %esi
	leaq	LC2(%rip), %rdi
	movl	$0, %eax
	call	_printf
	movq	-24(%rbp), %rax
	movq	%rax, -32(%rbp)
	movq	-32(%rbp), %rdx
	movq	-24(%rbp), %rsi
	leaq	LC3(%rip), %rdi
	movl	$0, %eax
	call	_printf
	cmpq	$-1, -24(%rbp)
	jne	L2
	leaq	LC4(%rip), %rdi
	call	_perror
	movl	$1, %edi
	call	_exit
L2:
	movq	-32(%rbp), %rax
	addq	$12, %rax
	movl	$8, (%rax)
	movq	-32(%rbp), %rdx
	addq	$8, %rdx
	movq	-32(%rbp), %rax
	addq	$12, %rax
	movl	(%rax), %eax
	movl	%eax, (%rdx)
	movq	-24(%rbp), %rsi
	leaq	LC5(%rip), %rdi
	movl	$0, %eax
	call	_printf
	movl	-4(%rbp), %eax
	movslq	%eax,%rsi
	movq	-24(%rbp), %rdi
	call	_munmap
	movl	$0, %eax
	leave
	ret
LFE6:
	.section __TEXT,__eh_frame,coalesced,no_toc+strip_static_syms+live_support
EH_frame1:
	.set L$set$0,LECIE1-LSCIE1
	.long L$set$0
LSCIE1:
	.long	0x0
	.byte	0x1
	.ascii "zR\0"
	.byte	0x1
	.byte	0x78
	.byte	0x10
	.byte	0x1
	.byte	0x10
	.byte	0xc
	.byte	0x7
	.byte	0x8
	.byte	0x90
	.byte	0x1
	.align 3
LECIE1:
.globl _main.eh
_main.eh:
LSFDE1:
	.set L$set$1,LEFDE1-LASFDE1
	.long L$set$1
LASFDE1:
	.long	LASFDE1-EH_frame1
	.quad	LFB6-.
	.set L$set$2,LFE6-LFB6
	.quad L$set$2
	.byte	0x0
	.byte	0x4
	.set L$set$3,LCFI0-LFB6
	.long L$set$3
	.byte	0xe
	.byte	0x10
	.byte	0x86
	.byte	0x2
	.byte	0x4
	.set L$set$4,LCFI1-LCFI0
	.long L$set$4
	.byte	0xd
	.byte	0x6
	.align 3
LEFDE1:
	.subsections_via_symbols
