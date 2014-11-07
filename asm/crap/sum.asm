section .data
nums:	db "0123456789"
big_err:	db "Number's too fuckin' big.", 10, 0

section .bss
s01:	 resb 50		;very curiously, it seems I need to allocate 50 things to print a 25-char string.

section .text
global start
 
start:
	;; expected: [rsp] -> [argc] [arg0] [arg1] ...
	;; where arg1 = p and arg2 = a
	mov rax, [rsp+16]
	call parse_int
	jmp red_arg
	;; mov rdi, red_arg

read_rax:
	mov rsi, rax
	mov rax, 0
	mov rcx, 10
bloop:
	mov bl, [rsi]
	cmp bl, 0
	jz bloop_done
	sub bl, 48 		;e.g. #\2 = 50 ascii
	mul rcx
	jc big_err
	add rax, rbx
	jc big_err		;must I really do this redundancy?
	inc rsi
	jmp bloop

bloop_done:
	jmp rdi

red_arg:
	;; mov rax, rsp
	;; jmp print_rax

	call raw_dicksum
	jmp print_rax

raw_sum:
	mov rbx, 1
	mov rcx, 0
raw_sum_loop:	
	cmp rax, 0
	je raw_sum_ret
	add rcx, rbx
	xchg rcx, rbx
	dec rax
	jmp raw_sum_loop

raw_sum_ret:
	mov rax, rcx
	ret

sum:
	;; argument in rax; return result in rax
	cmp rax, 2
	jl return

	dec rax
	push rax
	dec rax
	call sum
	xchg rax, [rsp]
	call sum
	add rax, [rsp]
	add rsp, 8

return:
	ret

dicksum:
	cmp rax, 0
	je dickreturn

	push rax
	dec rax
	call dicksum
	add rax, 1
	add rsp, 8

dickreturn:
	ret

raw_dicksum:
	xor rbx, rbx
raw_dicksum_loop:
	inc rbx
	dec rax
	jg raw_dicksum_loop
	xchg rbx, rax
	ret

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

	

print_rax:

	mov rcx, s01
	add rcx, 49
	mov byte [rcx], 0
	dec rcx
	mov byte [rcx], 0x0a
	dec rcx
	mov rdx, 0
	
	mov rdi, 10 		;base
	
write_chars:
	
	div rdi			;rax=quot, rdx=rem
	mov rbx, nums
	add rbx, rdx
	mov bl, [rbx]
	mov [rcx], bl
	dec rcx
	xor rdx, rdx

	cmp rax, 0
	jne write_chars

	mov rax, 0x2000004      ; System call write = 4
	mov rdi, 1              ; Write to standard out = 1
	mov rsi, rcx		; address of string
	mov rdx, rcx
	mov rbx, s01
	sub rdx, rbx		; size to write
	syscall                 ; Invoke the kernel


exit:	
	
	mov rax, 0x2000001      ; System call number for exit = 1
	mov rdi, 0              ; Exit success = 0
	syscall                 ; Invoke the kernel