section .data
	;; initialized data
filename: db "file.file", 0
nums:	db "0123456789", 0
	
section .bss
	;; uninitialized data
str:	resb 100
s01:	resb 200

	;; program
section .text

global start
start:

	;; Calling convention:
	;; syscall number in rax
	;; arguments in rdi, rsi, rdx, rcx, r8, r9
	;; then "return value/error code" in rax

	;; mov rax, 0x2000004      ; System call write = 4
	;; mov rdi, 1              ; Write to standard out = 1
	;; mov rsi, hello_world    ; The address of hello_world string

	mov r12, [rsp-4]
	
	mov rax, 0x2000005 	;open
	mov rdi, filename
	mov rsi, 0b0000000
	syscall

	mov rax, 0x2000004
	mov rdi, 0
	mov rsi, 0
	mov rdx, 44
	syscall

	;; cmp rax, 0
	;; jl done

	pushf
	;; mov rax, [rsp]
	;; pop rax
	;; mov rax, r12

	jmp print_rax

	;; now rax is probably... a "file descriptor"?
	;; read(fd, string_buffer, transfer_size)
	mov rdi, rax
	mov rax, 0x2000003
	mov rsi, str
	mov rdx, 100
	syscall
	;; incidentally, the IN/OUT instructions aren't usable for this sort of thing.
	;; probably deal with "I/O from peripherals" or whatever crap.

	
	;; write(fd, string, transfer_size)
	mov rax, 0x2000004
	mov rdi, 1
	mov rsi, str
	mov rdx, 100
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


done:
	mov rdi, rax
	mov rax, 0x2000001	;exit
	syscall
	

	;; exit(0)
	mov rax, 0x2000001
	mov rdi, 0
	syscall


	
	

	

	
	