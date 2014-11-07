section .data
nums:	db "0123456789"
too_big:	db "Number's too fuckin' big.", 10, 0


section .text
global start

        mov rax, 0xfffefafd

c_args:
        test rdi, 1             ;testing for evenness now
        jnz do_actual_work
        
        mov rax, 2
        jmp return

do_actual_work: 
        
        mov rbx, rdi
        mov rsi, 1
        jmp begin

red_prime:

	mov rbx, rax		;p
	mov rsi, 1		;c
begin:	
	mov r8, 2
	mov r9, 2
	mov r10, 0		;tortoise_index
	mov r11, 4		;steps till check ass
	mov r12, 4		;power of 2
	mov r14, 40		;consecutive butts before GCD
	mov r15, 1		;product of |x-y|

	;; now here we use "brent's cycle-finding algorithm".
	;; we store, say, x4. compute x5, x6, x7, x8 and check each for eq(x4).
	;; if none, then we dump x4, store x8, and look at x9-x16.
	;; and so on.
	
	;; so now we have binary GCD, Brent's thing, and now Pollard and Brent's
	;; improvement, in which, instead of doing GCD(|x-y|,p) on every step, we
	;; mul together a bunch of |x-y| and then handle crap at the end.

	;; shall have tortoise = r8, hare = r9, tort_index = r10, power = r11.
	;; c = rsi, p = rbx

step:
	;; now for this carrying crap...
	;; it happens that squares are 0 1 4 9 mod 16, so there's no way
	;; that having c = anything < 7 would make the addition in
	;; "rdx:rax + c" require a carry from rax to rdx.
	mov rax, r9
	xor rdx, rdx
	mul r9
	add rax, rsi
	div rbx			;qt rax, rd rdx
	mov r9, rdx
	;; compute |x-y|, mul into r15
	mov rax, r8
	sub rax, r9
	jz backtrack		;maybe fail
	cqo			;sign-extend into RDX
	xor rax, rdx
	sub rax, rdx		;now rax = |x-y|
	;; now mul into ass
	mul r15
	div rbx
	mov r15, rdx
	;; now think about ass
	dec r11
	jnz step
	;; now handle ass
	;; first compute gcd
	bsf rcx, rdx		;rdx = product(|x-y|)
	shr rdx, cl
	mov rax, rbx		;and rax = p
	cmp rax, rdx		;ech, this is a bit ugly to do
	je backtrack

				;rdx, rax
	;; binary gcd. assume p isn't even. also p >= |x-y|.
	;; we make use of "bit scan forward", not any weird parity flag crap.

gcd1:	
	sub rax, rdx
	bsf rcx, rax
	shr rax, cl

	cmp rax, rdx
	ja gcd1
	jz gcd_done

gcd2:
	sub rdx, rax
	bsf rcx, rdx
	shr rdx, cl
	
	cmp rax, rdx
	jb gcd2
	ja gcd1

gcd_done:

	;; now rax = gcd
	cmp rax, 1
	jne done

	add r10, r14
	cmp r10, r12
	jb dont_adjust_power


	mov r10, r12
	add r12, r12
	mov r8, r9
dont_adjust_power:
	mov r11, r12
	sub r11, r10
	cmp r11, r14
	cmova r11, r14
	mov r15, 1
	jmp step

sucks:
	;; get here when failed to find ass.
	;; we'll try a larger c that's less than 7.
	inc rsi
	cmp rsi, 7
	je return		;total fail
	jmp begin

big_err:
	mov rax, 0x2000004
	mov rdi, 1
	mov rsi, too_big
	mov rdx, 50
	syscall
	jmp return

backtrack:
	;; here... r8 = tortoise. ... will NOT need to jump back to top.
	mov r9, r8

bstep:
	;; it happens that squares are 0 1 4 9 mod 16, so there's no way
	;; that having c = anything < 7 would make the addition in
	;; "rdx:rax + c" require a carry from rax to rdx.
	mov rax, r9
	xor rdx, rdx
	mul r9
	add rax, rsi
	div rbx			;qt rax, rd rdx
	mov r9, rdx

	;; now we find gcd(x-y, p)
	;; must I worry about sign?
	;; might as well abs-ify the x-y.
	;; now someone suggests a clever way to do abs.
	mov rax, r8
	sub rax, r9
	jz sucks		;fail
	cqo			;sign-extend into RDX
	xor rax, rdx
	sub rax, rdx		;now rax = |x-y|
	bsf rcx, rax
	shr rax, cl
	mov rdx, rbx		;and rdx = p

				;rdx, rax
	;; binary gcd. assume p isn't even. also p >= |x-y|.
	;; we make use of "bit scan forward", not any weird parity flag crap.
bgcd2:
	sub rdx, rax
	bsf rcx, rdx
	shr rdx, cl
	
	cmp rax, rdx
	jb bgcd2
	je bgcd_done
	
bgcd1:	
	sub rax, rdx
	bsf rcx, rax
	shr rax, cl

	cmp rax, rdx
	ja bgcd1
	jb bgcd2

bgcd_done:

	;; now rax = gcd
	cmp rax, 1
	jne done

	jmp bstep

done:
        ret
	


return:

        ret