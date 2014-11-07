section .data
num_str:	db "Regg has %ld", 10, 0

thing0:	dq 0
	db 0, 0, 0
thing:	dq 0
thing2:	dq 0


section .text
extern _printf
extern _exit

global start
start:

	push rbp
	mov rbp, rsp

	mov rcx, 1
	mov rdx, 2
	mov rax, [rel thing]
	cmp qword [rel thing], 0
	;; ja put_rdx

	add qword [rel thing], 5
	mov rax, [rel thing]
	call print_rax
	add qword [rel thing], 5
	mov rax, [rel thing]
	call print_rax
	add qword [rel thing], 5
	mov rax, [rel thing]
	call print_rax
	mov qword [rel thing], 23
	mov rax, [rel thing]
	call print_rax
	add qword [rel thing], 5
	mov rax, [rel thing]
	call print_rax
	add qword [rel thing], 69
	mov rax, [rel thing]
	call print_rax
	add qword [rel thing], 69
	mov rax, [rel thing]
	call print_rax
	add qword [rel thing], 69
	mov rax, [rel thing]
	call print_rax
	add qword [rel thing], 69
	mov rax, [rel thing]
	call print_rax

	add qword [rel thing2], 5
	mov rax, [rel thing2]
	call print_rax
	add qword [rel thing2], qword 5
	mov rax, [rel thing2]
	call print_rax
	mov rax, 5
	add [rel thing2], rax
	mov rax, [rel thing2]
	call print_rax
	call exit


put_rcx:
	mov rax, rcx
	jmp print_rax
put_rdx:
	mov rax, rdx
	;; jmp print_rax

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