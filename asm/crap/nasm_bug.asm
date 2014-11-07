section .data
num_str:	db "Thing is %ld", 10, 0
thing:	dq 0

section .text
extern _printf
extern _exit

global start
start:

	;; push rbp
	;; mov rbp, rsp

	add qword [rel thing], 5
	mov rax, [rel thing]
	
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