
section .data
loop_str:	db "loop", 10, 0
str_str:	db "%s", 10, 0
num_str:	db "%ld", 10, 0	;seems it's the C preprocessor or wtvr that makes \n into newline...
big_err:	db "I don't know who I am anymore!", 10, 0
section .bss
buf:	resb 32
	
section .text

extern _printf
extern _read


global start
start:

	;; OH FUCK ME
	;; r11 belongs to the calling procedure.

	;; ALL RIGHT, REGARDING I/O.
	;; If input is from, say, a terminal, it may
	;; choose to flush output after, say, every newline or something.
	;; However, I suspect it is the case that output will never be
	;; flushed after 0 characters; in that case, if 0 characters are read,
	;; then that means EOF.
	;; It seems that, when typing into a terminal, ^D (i.e. EOF) makes a difference
	;; only when no characters were typed before it, because the terminal only
	;; does crap based on newlines. However, ^D^D is probably taken to mean "flush
	;; input, then EOF".
	;; ACTUALLY NO ^D DOES FLUSH INPUT AND FOR LISPS THAT DOESN'T TERMINATE A TOKEN (DUH)

	;; So. If you want to read a single line that's less than the buffer length,
	;; and if the source happens to submit it all at once, then a single "read"
	;; may suffice. Else, you will have to just keep re-reading.
	mov rbp, rsp
	and sp, 0xfff0

	cmp qword [rbp], 2
	jl done

	mov rax, 1
	call read_intarg
	mov r12, rax

	xor rax, rax
	mov rdi, num_str
	mov rsi, r12
	call _printf

loop:
	xor rax, rax
	mov rdi, loop_str
	call _printf

	;; xor rax, rax
	;; mov rdi, num_str
	;; mov rsi, r12
	;; call _printf
	
	xor rax, rax
	mov rdi, 0
	mov rsi, buf
	mov rdx, 32
	call _read

	mov r10, rax

	xor rax, rax
	mov rdi, num_str
	mov rsi, r10
	call _printf

	xor rax, rax
	mov rdi, str_str
	mov rsi, buf
	call _printf

	dec r12
	jnz loop

	jmp done


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


exit:
	mov rax, 0x2000001
	mov rdi, 0
	syscall



done:
	mov rax, 0x2000001
	mov rdi, 0
	syscall