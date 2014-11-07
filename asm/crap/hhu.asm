section .data
filename: db "file.file", 0
nums:	db "0123456789", 0
	
section .bss

str:	resb 100
s01:	resb 200	;very curiously, it seems I need to allocate 50 things to print a 25-char string.

section .text

global start
start:

	;; Calling convention:
	;; syscall number in rax
	;; arguments in rdi, rsi, rdx, rcx, r8, r9
	;; then "0/error code" in rax, 

	;; mov rax, 0x2000005 	;open
	;; mov rdi, filename
	;; mov rsi, 2
	;; syscall
	;; ;; now rax = fd

	;; ;; mmap(address, len, permissions, flags, fd, offset)
	;; mov r8, rax
	;; mov rax, 0x20000c5	;mmap
	;; mov rdi, 0		;try mmapping to NULL
	;; mov rsi, 1048576	;len=1M
	;; mov rdx, 3		;perm=RW
	;; mov rcx, 1
	;; mov r9, 0
	;; syscall
	;; JESUS FUCKING CHRIST THAT HASN'T BEEN WORKING

	mov rax, 0x20000c5
	mov rdi, 0
	mov rsi, 1048576
	mov rdx, 3
	mov rcx, 0x1001		;anon, shared
	mov r8, -1
	mov r9, 0
	syscall
	
	;; now rax should contain the address.
	;; mov rax, r12
	;; jmp print_rax
	cmp rax, 0
	jl fucking_error
	
	;; now rax is our address...
	;; rax is a pointer into the file.
	;; munmap? that is 73.
	;; jmp done
	;; mov rax, rdx
	;; jmp print_rax
copying:
	mov rcx, 7
	mov [rax], rcx
	;; FUCKING GOD NOW THIS DOES WORK
	jmp done

print:	
	;; write(fd, string, transfer_size)
	mov rsi, str
	mov rax, 0x2000004
	mov rdi, 1		;stdout
	;; mov rsi, str
	mov rdx, 100
	syscall

done:	
	;; exit(0)
	mov rax, 0x2000001
	mov rdi, 0
	syscall

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


fucking_error:
	mov rdi, rax
	mov rax, 0x2000001	;exit
	syscall

	

	

	
	