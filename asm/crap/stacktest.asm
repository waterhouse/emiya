section .data
nums:	db "0123456789"
big_err:	db "Number's too fuckin' big.", 10, 0

section .bss
s01:	 resb 200		;very curiously, it seems I need to allocate 50 things to print a 25-char string.

section .text

	;; I think "-lcrt1.10.6.o" FUCKING SUCKS and seems to screw up the stack
	;; and seems to be unnecessary.
	;; yes, both are confirmed.

global start
start:
	;; this DOESN'T fucking screw up my stack

	;; ;; now crap is weird
	;; ;; [rsp+40] = pointer to arg2
	;; ;; [rsp+32] = pointer to arg1
	;; ;; [rsp+24] = pointer to... arg0.
	;; ;; [rsp+16] = argc UNTIL... crap.

	;; ;; mov rax, [rbp+8]
	;; ;; mov rbx, 120000

	;; so now:
	;; rsp -> [argc] [*arg0] [*arg1] [*arg2] ...
	mov rax, [rsp]	;now THIS is for some reason the butt
	;; mov rax, [rax]
	jmp print_rax

	
;; extern _mmap
	call parse_int

	mov r15, rax

	mov rbp, 0
	push rbp
	and sp, 0xfff0
	
	;; mmap(addr, len, prot, flags, fd, offset)
	mov rdi, 0
	mov rsi, 4096
	
	mov rdx, 3
	mov rcx, 0x1001
	
	mov r8, 0
	mov r9, 0
	;; call _mmap

	jmp print_rax



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
	add rcx, 199
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