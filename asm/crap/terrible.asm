

	mov rax, 0xfffefafd

	;; Time to imitate that fucker exactly.

	push rbp
	mov rbp, rsp
	mov [rbp-8], rdi
	mov [rbp-16], rsi
	mov rax, [rbp-16]
	mov rdx, [rbp-8]
	add rax, rdx
	pop rbp
	ret

	;; WAT?  It modifies rsp permanently.
	;; It would appear that the calling convention
	;; expects that or something for some reason.
	;; --NVM
	;; And nvm again. There are drawbacks to copying one thing
	;; from two different sources.

	;; Ok so I have the feeling that on Linux,
	;; racket-allocated byte strings are not executable.
	;; I feel pretty sure of this.