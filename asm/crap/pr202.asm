section .data
nums:	db "0123456789"

section .bss
s01:	 resb 50		;very curiously, it seems I need to allocate 50 things to print a 25-char string.


	
section .text
global start

start:	

	mov rax, 0
	mov rbx, 2
	mov rdx, 6008819575

	mov r8, 2
	mov r9, 2
	mov r10, 2
	mov r11, 2
	mov r12, 2
	mov r13, 2
	mov r14, 2
	mov r15, 2

loop:
	mov rcx, 1
	add rbx, 3
	
	add r8, 3
	add r9, 3
	add r10, 3
	add r11, 3
	add r12, 3
	add r13, 3
	add r14, 3
	add r15, 3
five:	
	cmp r8, 5
	jb eleven
	sub r8, 5
	jnz eleven
	xor rcx, rcx
eleven:	
	cmp r9, 11
	jb seventeen
	sub r9, 11
	jnz seventeen
	xor rcx, rcx
seventeen:
	cmp r10, 17
	jb twentythree
	sub r10, 17
	jnz twentythree
	xor rcx, rcx
twentythree:
	cmp r11, 23
	jb twentynine
	sub r11, 23
	jnz twentynine
	xor rcx, rcx
twentynine:
	cmp r12, 29
	jb fortyone
	sub r12, 29
	jnz fortyone
	xor rcx, rcx
fortyone:
	cmp r13, 41
	jb fortyseven
	sub r13, 41
	jnz fortyseven
	xor rcx, rcx
fortyseven:
	cmp r14, 47
	jb endloop
	sub r14, 47
	jnz endloop
	xor rcx, rcx
endloop:
	add rax, rcx
	cmp rbx, rdx
	jle loop



	jmp print_rax

	
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

return:	
	
	mov rax, 0x2000001      ; System call number for exit = 1
	mov rdi, 0              ; Exit success = 0
	syscall                 ; Invoke the kernel

	;; nasm -f macho64 mac2.asm; ld mac2.o; ./a.out