section .data
num_str:	db "Thing is %ld", 10, 0
uthing:	db 0
thing:	dq 0

cock:	dq 5
nub:	dq 0xff00ff0000000000

section .text
extern _printf
extern _exit

global start
start:

	;; push rbp
	;; mov rbp, rsp

	add qword [rel uthing], 5
	;; FUCKING FUCKING FUCK FUCK FUCK FUCKDICULOUS FUCKER
	mov rax, [rel thing]
	call print_rax
	cmp qword [rel uthing], 5
	setz al
	call print_rax
	cmp qword [rel uthing], 5
	setz al
	call print_rax
	add qword [rel uthing], 5
	mov rax, [rel thing]
	call print_rax
	mov rax, 0
	mov rax, [rel cock]
	imul rax, [rel thing]
	cmovnz rax, [rel thing]
	;; mov rax, [rel thing]
	call print_rax
	mov rax, [rel nub]
	call print_rax
	call exit

print_rax:
	mov rbp, rsp
	mov rsi, rax
	mov rdi, num_str
	and sp, 0xfff0
	xor rax, rax
	call _printf
	mov rsp, rbp
	ret

exit:	
	mov rdi, 0
	xor rax, rax
	call _exit