section .data
nums:	db "0123456789"
blah:	dq 69
absolute blah

section .bss
s01:	 resb 50		;very curiously, it seems I need to allocate 50 things to print a 25-char string.

section .text
global start
 
start:
	mov r8, 0
	mov r9, 0
	mov r10, 2000000000

add_crap:
	inc r8
	add r9, r8
	;; so there's some fucking ridiculous optimization shit you can do here,
	;; like unrolling this loop once and putting a jmp to the next line in between.
	;; that makes the program slightly faster. fuckfuckfuckfuckfuck. noooooo.
	cmp r8, r10
	jb add_crap

	mov rax, r9
	jmp print_rax

	
print_rax:
	mov rcx, s01
        add rcx, 49
	add rcx, 49
	add rcx, 49
	add rdx, 49
	add rax, 49
	add r8, 49
	add r9, 49
	add rcx, 666
        mov rax, 1
        mov rax, 127
        mov rax, 128
        mov rax, 984723
        mov rax, 94873298423
        mov r8, 69
	add rcx, 897897
	add rcx, 8789789
	add rcx, [rbx-8]
	add rcx, [rbx-9]
	add rcx, [rbx+1000]
        add rcx, [rbx+1000000]
        add rcx, [rbx+1000000]
	add ax, r9w
	add r9w, ax

	add qword [blah], 5
	add [blah], 5
	add [blah], 5
	add [blah], 5
	add [rel blah], 7
	add [rel blah], 7
	add [rel blah], 7
	add qword [rel blah], 7

	add rcx, rdx
	add rdx, rcx
	cmove rcx, rdx
	cmove rdx, rcx
	
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