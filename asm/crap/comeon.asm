section .data
str:	db "open(%s,%d)",10,0
file:	db "file.file",0

section .text

extern _printf
global _main

_main:

	push rbp
	mov rbp, rsp
	
	mov rax, 0
	mov rdi, str
	mov rsi, file
	mov rdx, 2

	call _printf


	push rbp
	mov rbp, rsp
	
	mov rax, 0
	mov rdi, str
	mov rsi, file
	mov rdx, 2

	call _printf

	push rbp
	mov rbp, rsp
	
	mov rax, 0
	mov rdi, str
	mov rsi, file
	mov rdx, 2

	call _printf

	push rbp
	mov rbp, rsp
	
	mov rax, 0
	mov rdi, str
	mov rsi, file
	mov rdx, 2

	call _printf

	mov rax, 0x2000001
	mov rdi, 0
	syscall