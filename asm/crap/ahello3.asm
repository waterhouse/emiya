
	;; nasm -f macho64 ahello.asm
	;; ld -macosx_version_min 10.6.8 -o ahello -lcrt1.10.6.o ahello.o -lSystem
	;; gcc uses a "-dynamic" option as well. ... no effect on this file.
	;; other than that, those are the only essential options.

	;; -lSystem probably leads to /usr/lib/libSystem.dylib, the big-ass system library.
	;; which I think is a hard link to libSystem.dylib.B or something.
	;; -lcrt1.10.6.o appears to lead to /usr/lib/crt1.10.6.o.
	;; this appears to contain just a few things. i might even be able to understand it.
	;; let's go do that, shall we?
section .data
hello:	db "Fuck you %d", 10, 0
dick:	db "FUCK ASS DICK GOD", 0
cock:

section .text

extern _puts
extern _printf
;; global _main

;; _main:

	global start
start:	

	;; All right, so.  Turns out:
	;; 1. You do need to push rbp for any of these calls to work. Saving rsp
	;; with mov rbp, rsp isn't necessary (but would be useful if I actually used it).
	;; 2. puts demands the stack to be 16-byte aligned. But printf doesn't, for
	;; some reason.

	mov r15, [rsp+8]
	mov rbp, rsp

	push rbp
	and sp, 0xfff0
	mov rsi, rsp
	mov rdi, hello
	mov rax, 0
	call _printf

	push rbp
	and sp, 0xfff0
	mov rbp, rsp
	mov rsi, rsp
	mov rdi, hello
	mov rax, 0
	call _puts
	
	push rbp
	mov rbp, rsp
	mov rdi, hello
	mov rax, 0
	call _puts

	push rbp
	mov rbp, rsp
	mov rdi, hello
	mov rax, 0
	call _printf



	
	;; mov rax, 0
	;; leave
	;; ret

	mov rax, 0x2000001
	mov rdi, 0
	syscall
	