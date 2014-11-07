section .data
nums:	db "0123456789"

section .bss
s01:	 resb 50		;very curiously, it seems I need to allocate 50 things to print a 25-char string.

section .text
global start
 
start:
	mov r8, 2		;a
	mov r9, 5325		;n
	mov r10, 10000000019	;m
	mov r11, 1		;tt
mod_expt:
	;; jrcxz done
	cmp r9, 0
	je done
	test r9, 1
	jz even

	dec r9
	mov rax, r8
	mul r11 		;result in rdx:rax
	div r10			;qt rax, rd rdx
	mov r11, rdx
even:				;heh, a trick; if it's odd, then I sub1 and go directly to even case.
	shr r9, 1
	mov rax, r8
	mul r8
	div r10
	mov r8, rdx

	jmp mod_expt

done:	
	mov rax, r11
	
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