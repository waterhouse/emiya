section .data
	;; initialized data
filename: db "file.file", 0
succ:	db "Success", 10, 0
fail:	db "Failure", 10, 0
cock:	db "cuheoucrhoecruh eocruhcreohucroehucr eocurheocruh ceorhu creohucreo ucheorcu eocruhc roehu crohu rcohcuhoec uhoecrhu croehu croeh cohurcoh urcohu croeh ucrohucou rcohc uocru hoecuhor hrocuh orc uhcr"
	
nums:	db "0123456789"

	
section .bss
	;; uninitialized data
str:	resb 100

	
s01:	 resb 50		;very curiously, it seems I need to allocate 50 things to print a 25-char string.


	;; program
section .text

global start
start:

	;; Calling convention:
	;; syscall number in rax
	;; arguments in rdi, rsi, rdx, rcx, r8, r9
	;; then "0/error code" in rax, 

	;; mov rax, 0x2000004      ; System call write = 4
	;; mov rdi, 1              ; Write to standard out = 1
	;; mov rsi, hello_world    ; The address of hello_world string

	mov rax, 0x2000005 	;open
	mov rdi, filename
	mov rsi, 2
	syscall
	;; now rax = fd

	;; method 1: pick a buffer size and periodically tell the system to read a chunk of the file
	;; into the buffer.
	;; method 2: use the random mmap crap.  that would be more fun.
	;; now how do I do that.

	;; mmap(address, len, permissions, flags, fd, offset)
	;; the "address" thing is funky. I think it'll try to put the memory starting there,
	;; and if it's not available, then put it starting somewhere after that.
	;; hmm, this is probably "virtual memory". interesting...
	;; I can probably specify "null" as the address.  or, if not, then specify anything from
	;; this program, like str. let's try null.
	mov r12, rax
	mov r8, rax
	mov rax, 0x20000c5	;mmap
	mov rdi, str		;try mmapping to NULL
	mov rsi, 100
	mov rdx, 1
	mov rcx, 0
	mov r9, 0
	syscall

	;; mov r8, r12
	;; mov rax, 0x20000c5	;mmap
	;; mov rdi, 0		;try mmapping to NULL
	;; mov rsi, 100
	;; mov rdx, 7
	;; mov rcx, 0
	;; mov r9, 0
	;; syscall

	;; HELLA SUCCESS
	;; now rax should contain the address.
	;; i suppose we can check.

	;; now the return value, presumably rax, is the thing
	;; mov rax, r12
	;; jmp print_rax
	cmp rax, 0
	jl fucking_error
	
	;; now rax is our address...
	;; rax is a pointer into the file.
	;; munmap? that is 73.
	
	mov rbx, str
copying:
	mov cx, [rax]
;; 	inc rax
;; 	mov [rbx], rcx
;; 	inc rbx
;; 	cmp rcx, 0
;; 	jne copying
	

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
	jmp done


fucking_error:
	mov rdi, rax
	mov rax, 0x2000001	;exit
	syscall

	

	

	
	