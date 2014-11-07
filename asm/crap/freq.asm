	;; byte freqs.


	section .data

	section .bss

tab:	resq 256

section .text

extern _printf
extern _read

	;; arg: bufsize.

	;; rsp -> [argc] [&arg0] [&arg1]

	;; mov rax, [rsp]
	mov r10, 4096
	cmp [rsp], 2
	jl picked_bufsize

	mov rax, 1
	call read_intarg
	mov r10, rax

picked_bufsize:	
	
	








parse_int:
	;; arg, result in rax
	;; destroys... rbx, rcx
	xor rcx, rcx
	xor rbx, rbx
pi_loop:	
	mov cl, [rax]
	cmp cl, 0
	je pi_ret
	
	sub cl, 48
	imul rbx, rbx, 10
	jc big_err
	add rbx, rcx
	jc big_err
	inc rax
	jmp pi_loop
pi_ret:
	mov rax, rbx
	ret

read_intarg:
	;; n in rax
	;; rsp in... rbp? yeah.
	;; [argc] [&arg0] [&arg1] ...
	shl rax, 3
	add rax, rbp
	mov rax, [rax+8]

	;; call parse_int
	;; ret
	jmp parse_int


exit:
	mov rax, 0x2000001
	mov rdi, 0
	syscall