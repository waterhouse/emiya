section .data
nums:	db "0123456789"
big_err:	db "Number's too fuckin' big.", 10, 0
dumb_string:	db "Nub", 10, 0
rsp_str:	db "rsp: %ld", 10, 0

section .bss
s01:	 resb 200		;very curiously, it seems I need to allocate 50 things to print a 25-char string.

section .text

extern _puts
extern _printf
extern _mmap

global start

start:

	;; now crap is weird
	;; [rsp+40] = pointer to arg2
	;; [rsp+32] = pointer to arg1
	;; [rsp+24] = pointer to... arg0.
	;; [rsp+16] = argc UNTIL... crap.

	;; ok now it seems
	;; [rbp+8] = argc
	;; [rbp+16] = pointer to arg0
	;; [rbp+24] = pointer to arg1

	;; the above crap is from including the horrible file
	;; crt1.10.6.o
	;; don't fucking do that

	;; so rbp = 0 at start. I think that's not a guarantee, but it is true.

	mov r15, rsp
	
	call print_rsp

	;; mov rax, [rsp]
	;; jmp print_rax


	mov rbp, rsp
	push rbp
	and sp, 0xfff0
	mov [rsp], rbp
	mov rdi, dumb_string
	;; mov r13, rsp
	call _puts		;rsp is preserved by this... not sure whether that's guaranteed
	;; mov r14, rsp
	pop rsp
	
	;; mov rax, [rsp]
	;; jmp print_rax

	call print_rsp		;good, this works
	call print_rsp		;good, this works
	call print_rsp		;good, this works

	;; rsp -> [argc] [arg0] [arg1] [arg2] ...

	;; mov rax, [rbp+8]
	;; mov rax, [rbp+8]
	;; mov rax, [rsp]
	;; mov rax, [r15]
	;; mov rax, [rax]
	;; mov rax, 9000
	;; jmp print_rax

	mov rax, r15
	add rax, 8
	call print_rsp

	;; mov rax, 2
	;; call read_intarg
	;; jmp print_rax

	push rbp
	mov rbp, rsp
	mov rdi, r15
	add rdi, 8
	mov rdi, [rdi]
	and sp, 0xfff0
	call _puts
	mov rsp, rbp
	pop rbp
	;; mov rax, r15

	;; jmp print_rax

	;; now we probably don't care about the stack... meh, meh.
	;; might as well save it.
	;; mov rbp, rsp
	call print_rsp

	and sp, 0xfff0
	
	;; mmap(addr, len, prot, flags, fd, offset)
	mov rdi, 0
	mov rsi, 268435456
	
	mov rdx, 3
	mov rcx, 0x1001
	
	mov r8, 0
	mov r9, 0
	xor rax, rax
	call _mmap

	;; seems like a) rax specifies number of "floating-point args on stack" or smthg in general
	;; and b) rax is used to indicate number of "overflow" registers.

	mov rsp, rax
	add rsp, 268435456
	sub rsp, 32
	and sp, 0xfff0
	push rsp
	call print_rsp

	mov rax, 2
	call read_intarg
	;; mov rsp, rbp
	call dicksum		;so all this does work
	jmp print_rax

	;; only funky thing is the exact amount of memory allocated...
	;; aha. originally I have 16.7 million bytes (16 MB).
	;; then I allocate a bunch more. it happens to append it directly to the end of thingy.
	;; I wonder how to catch stack overflow...
	;; 17301501 is the precise thing I can do when allocating 256 extra MB. don't know why... wtvr.
	;; predicted thing is 17825792.
	;; predicted thing with no count of initial stack is 16777176.
	;; wtvr.

	

forever:
	jmp forever

	jmp print_rax
	;; hmm, so I _think_ the called function doesn't care what rbp is...

print_rsp:			;oh dear
	;; this must be an informed function
	push rsi
	mov rsi, rsp
	add rsi, 16		;account for [rsi] [rbp] having been pushed
	push rbp
	push rax
	push rdi

	mov rbp, rsp
	and sp, 0xfff0
	mov rdi, rsp_str
	;; mov rsi, rsp
	xor rax, rax		;is needed; I think this specifies varargs; could test that
	call _printf
	mov rsp, rbp
	
	pop rdi
	pop rax
	pop rbp
	pop rsi
	;; add rsp, 8
	ret
	
	



parse_int:
	;; arg, result in rax
	;; destroys... rbx, rcx
	xor rcx, rcx
	xor rbx, rbx
pi_loop:	
	mov cl, [rax]
	cmp cl, 0
	je pi_ret
	
	sub cl, 48
	imul rbx, rbx, 10
	jc big_err
	add rbx, rcx
	jc big_err
	inc rax
	jmp pi_loop
pi_ret:
	mov rax, rbx
	ret

read_intarg:
	;; n in rax
	;; rsp in... rbp? yeah.
	;; [argc] [&arg0] [&arg1] ...
	shl rax, 3
	add rax, rbp
	mov rax, [rax+8]

	;; call parse_int
	;; ret
	jmp parse_int

dicksum:
	cmp rax, 0
	je dickreturn

	push rax
	dec rax
	call dicksum
	add rax, 1
	add rsp, 8

dickreturn:
	ret




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


exit:	
	
	mov rax, 0x2000001      ; System call number for exit = 1
	mov rdi, 0              ; Exit success = 0
	syscall                 ; Invoke the kernel