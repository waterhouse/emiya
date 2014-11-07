;; extern _printf

section .data
hello:	db "Fuck.",10,0
nums:	db "0123456789"

section .bss
s01:	 resb 200		;very curiously, it seems I need to allocate 50 things to print a 25-char string.

section .text

	;; Fuck gcc wants main rather than start.

global start
start:
	mov rax, hello
	mov rdi, hello
	;; call _printf

	mov r10, 0x7fff86fb4f3a
	mov rax, [r10]

	mov rax, 0xdeadbeefdeadbeef
	and ax, 0xff


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


	mov rax, 0x2000001
	mov rdi, 0
	syscall

	