
section .data
hello:	db "Fuck you%d", 10, 0

section .text

extern _puts
extern _printf
global _main

_main:	
	push rbp
	mov rbp, rsp
	mov rdi, hello
	call _puts

	push rbp
	mov rbp, rsp
	mov rax, 0
	mov rdi, hello
	mov rsi, 69
	call _printf

	
	;; mov rax, 0
	;; leave
	;; ret

	mov rax, 0x2000001
	mov rdi, 0
	syscall
	