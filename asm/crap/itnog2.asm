section .data
hello:	db "Kyrie eleison.", 10, 0
syslib:	db "/usr/lib/libSystem.dylib", 0
puts_name:	db "puts", 0
str:	db "puts = %ld", 10, 0
str_str:	db "%s", 10, 0

section .bss

puts_place:	resb 8

section .text

	extern _dlopen
	extern _dlsym
	extern _printf
	extern _dlerror

	;; global _main
;; _main:

	global start
start:	

	;; wtf, it turns out _printf actually does expect something in RAX.
	;; or rather that it matters.
	;; probably that indicates number of arguments on the stack.
	;; and probably functions without varargs don't bother with RAX.

	;; we need to push rbp, probably...
	;; and we need to align the stack.
	;; pushing decrements rsp, so we might decrement it further.
	;; this is what AND is good for.
	;; now we just want to adjust the lowest couple of bits.
	;; when you operate on a 32-bit register, the result is
	;; sign-extended to the whole thing, but with 16- and 8-,
	;; it only modifies the low 16 or 8 bits.
	push rbp
	and sp, 0b11110000	;16-byte alignment
	mov rbp, rsp		;don't really know about necessity of this

	;; dlopen(const char *path, int mode)
	;; mode=0 probably works.
	mov rdi, syslib
	mov rsi, 0
	call _dlopen

	;; now rax should have return value, which will be 0 if error.
	mov r15, rax
	cmp rax, 0
	je fuck_me


	push rbp
	and sp, 0b11110000	;16-byte alignment
	mov rbp, rsp		;don't really know about necessity of this

	;; dlsym(void *handle, const char *symbol)
	mov rdi, rax
	mov rsi, puts_name
	call _dlsym

	cmp rax, 0
	jne no_error

	push rbp
	and sp, 0b11110000	;16-byte alignment
	mov rbp, rsp		;don't really know about necessity of this
	mov rax, 0
	call _dlerror

	push rbp
	and sp, 0b11110000	;16-byte alignment
	mov rbp, rsp		;don't really know about necessity of this

	mov rdi, str_str
	mov rsi, rax
	mov rax, 0
	call _printf

	jmp fuck_me

no_error:	

print_rax:	

	;; now rax should... be... a pointer to puts.
	;; let's test that.
	mov r12, rax		;safe keeping
	;; mov rax, r15
	mov rdi, str
	mov rsi, rax
	
	push rbp
	and sp, 0b11110000	;16-byte alignment
	mov rbp, rsp		;don't really know about necessity of this
	mov rax, 0
	call _printf

	mov rbx, puts_place
	mov [rbx], r12

	push rbp
	and sp, 0b11110000	;16-byte alignment
	mov rbp, rsp		;don't really know about necessity of this
	mov rdi, str
	call r12




fuck_me:
	mov rax, 0x2000001
	mov rdi, 0
	syscall