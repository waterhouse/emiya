section .data

fname:	db "file.dick", 0
nums:	db "0123456789"

section .bss

str:	resb 100
s01:	resb 200


section .text

global start
start:

	;; open(file, flags[, mode])
	mov rax, 0x2000005
	mov rdi, fname
	mov rsi, 2
	syscall

	jc syscall_error

	mov r12, rax 		;fd

	;; arguments in rdi, rsi, rdx, rcx, r8, r9
	
	;; mmap(addr, len, prot, flags, fd, offset)
	mov rax, 0x00000c5
	mov rdi, 0
	mov rsi, 4096
	
	mov rdx, 3
	mov rcx, 1
	
	mov r8, r12
	mov r9, 0
	syscall

	jc syscall_error

	jmp done






syscall_error:
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
	jmp done


done:
	mov rdi, rax
	mov rax, 0x2000001	;exit
	syscall
	