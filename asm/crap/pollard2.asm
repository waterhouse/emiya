section .data
nums:	db "0123456789"

section .bss
s01:	 resb 50		;very curiously, it seems I need to allocate 50 things to print a 25-char string.

section .text
global start
 
start:
	;; write p-1 as s*2^d, compute a^s mod p, then square it d times or until you get 1 or -1.
	;; expected: [rsp] -> [argc] [arg0] [arg1] ...
	;; where arg1 = p and arg2 = a
	mov rax, [rsp+16]
	mov rdi, red_prime

read_rax:
	mov rsi, rax
	mov rax, 0
	mov rcx, 10
bloop:
	mov bl, [rsi]
	cmp bl, 0
	jz bloop_done
	sub bl, 48 		;e.g. #\2 = 50 ascii
	mul rcx
	jc return
	add rax, rbx
	jc return		;must I really do this redundancy?
	inc rsi
	jmp bloop

bloop_done:
	jmp rdi

red_prime:

	mov rbx, rax
	mov rcx, 1
	mov r8, 2
	mov r9, 2
	mov r10, 2
	mov r11, 4

	;; now here we use "brent's cycle-finding algorithm".
	;; we store, say, x4. compute x5, x6, x7, x8 and check each for eq(x4).
	;; if none, then we dump x4, store x8, and look at x9-x16.
	;; and so on.

	;; FUCK it's the GCD that costs so much.

	;; shall have tortoise = r8, hare = r9, tort_index = r10, power = r11.
	;; c = rcx, p = rbx

step:
	;; now for this carrying crap...
	;; it happens that squares are 0 1 4 9 mod 16, so there's no way
	;; that having c = anything < 7 would make the addition in
	;; "rdx:rax + c" require a carry from rax to rdx.
	mov rax, r9
	xor rdx, rdx
	mul r9
	add rax, rcx
	div rbx			;qt rax, rd rdx
	mov r9, rdx

	;; now we find gcd(x-y, p)
	;; must I worry about sign?
	;; might as well abs-ify the x-y.
	;; now someone suggests a clever way to do abs.
	mov rax, r8
	sub rax, r9
	jz return		;fail
	cqo			;sign-extend into RDX
	xor rax, rdx
	sub rax, rdx		;now rax = |x-y|

	mov rdi, rax		;now rdi = |x-y|
	mov rax, rbx		;and rax = p


gcd:				;rdi, rax
	;; ;; binary gcd. assume p isn't even. also p >= |x-y|.
	;; ;; now what we do is... make heavy use
	;; ;; of the parity flag and all the x86 goodness.
	;; ;; this is probably the exact application of it.
	;; ;; rdx >= rax:
	;; sub rdx, rax		;now PF = 1 means rdx-rax is even means |x-y| was odd
	;; j
	
	;; OH FUCK THIS
	;; EUCLIDEAN GCD FOR NOW
	xor rdx, rdx
	div rdi			;qt rax, rd rdx
	mov rax, rdi
	mov rdi, rdx
	cmp rdx, 0
	jnz gcd

	;; now rax = gcd

	cmp rax, 1
	jne done

	dec r10
	jnz step
	mov r8, r9
	mov r10, r11
	add r11, r11
	jmp step

done:		
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


return:	
	
	mov rax, 0x2000001      ; System call number for exit = 1
	mov rdi, 0              ; Exit success = 0
	syscall                 ; Invoke the kernel


just_print_rax:
	mov rcx, s01
	add rcx, 49
	mov byte [rcx], 0
	dec rcx
	mov byte [rcx], 0x0a
	dec rcx
	mov rdx, 0
	
	mov rdi, 10 		;base
	
jwrite_chars:
	
	div rdi			;rax=quot, rdx=rem
	mov rbx, nums
	add rbx, rdx
	mov bl, [rbx]
	mov [rcx], bl
	dec rcx
	xor rdx, rdx

	cmp rax, 0
	jne jwrite_chars

	mov rax, 0x2000004      ; System call write = 4
	mov rdi, 1              ; Write to standard out = 1
	mov rsi, rcx		; address of string
	mov rdx, rcx
	mov rbx, s01
	sub rdx, rbx		; size to write
	syscall                 ; Invoke the kernel

	ret

	;; nasm -f macho64 mac2.asm; ld mac2.o; ./a.out