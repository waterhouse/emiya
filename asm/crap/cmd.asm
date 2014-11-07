section .data
nums:	db "0123456789"

section .bss
s01:	 resb 200		;very curiously, it seems I need to allocate 50 things to print a 25-char string.



section .text
global start

	;; given C's "int main(int argc, char **argv)"
	;; and given the calling convention rdi rsi rdx rcx r8 r9
	;; I imagine rdi = argc, rsi = argv at the start.

start:	

	mov rax, [rsp+24]
	mov rax, [rax]

print_rax:
	mov rcx, s01
	add rcx, 199
	mov byte [rcx], 0
	dec rcx
	mov byte [rcx], 0x0a
	dec rcx
	mov rdx, 0
	
	mov rdi, 2 		;base
	
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
