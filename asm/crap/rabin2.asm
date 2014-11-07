section .data
nums:	db "0123456789"
prm:	db "Prime", 0x0a
compos:	db "Composite", 0x0a

section .bss
s01:	 resb 50		;very curiously, it seems I need to allocate 50 things to print a 25-char string.

section .text
global start
 
start:
	;; write p-1 as s*2^d, compute a^s mod p, then square it d times or until you get 1 or -1.
	;; expected: [rsp] -> [argc] [arg0] [arg1] ...
	;; where arg1 = p and arg2 = a
	mov rax, [rsp+16]
	mov rdi, red_prime

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
	jc return
	add rax, rbx
	jc return		;must I really do this redundancy?
	inc rsi
	jmp bloop

bloop_done:
	jmp rdi

red_prime:
	mov r10, rax

	mov r14, [rsp]
	sub r14, 2
	add rsp, 24		;effectively popping three arguments (argc, cmd, prime)

testing_as:
	cmp r14, 0
	jz prime
	pop rax			;pointer to arg_n
	dec r14
	mov rdi, red_a
	jmp read_rax

red_a:
	mov r8, rax
	;; expects r8 = a, r10 = p
	mov r9, r10
	dec r9			;p-1
	bsf rcx, r9		;d
	shr r9, cl		;s
	
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
	cmp r11, 1
	je testing_as

	;; mov rax, rcx
	;; jmp print_rax

	mov r13, r10
	dec r13			;p-1

squaring:			;square tt=r11 d=rcx times
	cmp r11, 1
	je composite
	cmp rcx, 0
	je composite
	cmp r11, r13
	je testing_as
	
	mov rax, r11
	mul r11
	div r10
	mov r11, rdx 		;remainder
	dec rcx

	jmp squaring

prime:

	mov rax, 0x2000004      ; System call write = 4
	mov rdi, 1              ; Write to standard out = 1
	mov rsi, prm		; address of string
	mov rdx, 6		; size to write
	syscall                 ; Invoke the kernel
	jmp return

composite:

	mov rax, 0x2000004      ; System call write = 4
	mov rdi, 1              ; Write to standard out = 1
	mov rsi, compos		; address of string
	mov rdx, 10		; size to write
	syscall                 ; Invoke the kernel
	jmp return
	
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