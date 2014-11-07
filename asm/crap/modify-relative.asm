

	mov rax, 0xfffefafd

	default rel

	mov [dick], rdi
	add [dick], rsi
	mov rax, [dick]
	ret


dick:	dq 0


	