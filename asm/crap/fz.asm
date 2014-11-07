section .data

big_err:	db "Number's too fuckin' big.", 10, 0
num_str:	db "%ld", 10, 0
nofile_str:	db "The file %s doesn't exist.", 10, 0
fz_str:	db "%ld, len %ld", 10, 0

fz_default:	dq 32

section .bss


section .text

extern _puts
extern _printf
extern _mmap
extern _open
extern _close
extern _madvise
extern _munmap

	;; from filesize.o:
extern _filesize
	
global start
start:	

	mov rbp, rsp

	;; [argc] [&arg0] [&arg1] ...
	
	cmp qword [rbp], 3
	jl default_len
	
	mov rax, 2
	call read_intarg
	mov rbx, rax
	jmp picked_len
	
default_len:
	mov rbx, [rel fz_default] ;oh man; the rel means nasm will make it be [rip + smthg].

picked_len:

	mov r13, [rbp+16]

	and sp, 0xfff0

	mov rdi, r13
	xor rax, rax
	call _puts
	;; so any function that returns with RET must by necessity restore rsp.
	;; now I can stop screwing with that.

	;; open(char *path, int oflag, [int mode])
	mov rdi, r13
	mov rsi, 0		;read only, no magic
	;; no mode; not creating a file
	call _open

	cmp rax, -1
	je no_file
	mov r14, rax

	
	mov rdi, num_str
	mov rsi, r14
	xor rax, rax
	call _printf

	mov rdi, r14
	call _filesize		;oh man the file length
	mov r12, rax
	mov rdi, num_str
	mov rsi, rax
	xor rax, rax
	call _printf


	mov rdi, r13
	xor rax, rax
	call _puts

	;; mmap(addr, len, prot, flags, fd, offset)
	mov rdi, 0
	mov rsi, r12
	
	mov rdx, 1		;readonly
	mov rcx, 0x0001		;shared, file
	
	mov r8, r14
	mov r9, 0
	xor rax, rax
	call _mmap

	mov r15, rax

	;; so I have success. r15 is now the file in memory.

	;; now I'm going to go through the file...
	;; there are a bunch of ways to do it.
	;; one is to repeatedly "read" from the file into a buffer.
	;; otherwise I can use mmap, which is what I'm currently doing.
	;; if I use mmap, then I have some choices.
	;; one is to repeatedly mmap small portions of the file.
	;; another is to just mmap the whole file, and use madvise on the OS
	;; to tell it that I'll follow a "touch each thing once, moving forward" pattern.
	;; I think this last is most elegant and the Right Thing for all parties.

	;; madvise(void *addr, int len, int advice)
	mov rdi, r15
	mov rsi, r12	;should I start to use macros or something? actually could just get file len
	mov rdx, 2		;MADV_SEQUENTIAL
	call _madvise

	;; mov rdi, r15
	;; xor rax, rax
	;; call _puts    ;prints contents of file up to first NUL character...




	;; now we look for chunks of consecutive zeros >= rbx in the crap from mem address r15 through length r12.
	;; we'll want to keep r14 for later...
	;; have rax, rcx, rdx for this stuff, for whatever reason.
	;; nah. use r13, r14.
	push rbp
	push r13
	push r14
	push r12
	mov rbp, rsp


	;; rax = counter
	mov r13, r15		;index
	add r12, r15		;max
	xor r14, r14		;counter

	jmp fz

fz_top:	
	inc r13
fz:
	;; mov rdi, num_str
	;; mov rsi, r13
	;; xor rax, rax
	;; call _printf
	cmp r13, r12
	je fz_done

	cmp byte [r13], 0
	jne fz_top
	xor r14, r14

fnz:
	inc r13
	inc r14	
	;; mov rdi, num_str
	;; mov rsi, r13
	;; xor rax, rax
	;; call _printf
	
	cmp r13, r12
	je prnz
	cmp byte [r13], 0
	je fnz

prnz:
	cmp r14, rbx
	jl fz
	mov rdi, fz_str
	mov rsi, r13
	sub rsi, r15
	sub rsi, r14
	mov rdx, r14
	xor rax, rax
	call _printf
	jmp fz			;possible inefficiency... dunno

fz_done:
	;; jmp exit

	mov rsp, rbp
	pop r12
	pop r14
	pop r13
	pop rbp

	mov rdi, r15
	mov rsi, r12
	call _munmap		;make a difference? let's find out.

	;; close that file.
	mov rdi, r14
	call _close

	jmp exit

no_file:
	mov rdi, nofile_str
	mov rsi, [rbp+16]
	xor rax, rax
	call _printf
	jmp exit
	


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
	