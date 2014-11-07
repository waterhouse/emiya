
        ;; Results: 472-474 msec for 1b repetitions on Tau for by_one,
        ;; 473-475 msec for by_four,
        ;; and 625-632 msec for by_n.

	;; On Alvin, [nothing yet]
        
        mov rax, 0xfffefafd

        ;; rdi, rsi are dicks (rsi is useless; I'm lazy)
        ;; rdx = mode
        ;; rcx = repetitions
        ;; r8 = amount to shift by, if mode 2

        cmp rcx, 0
        je return

        cmp rdx, 0
        je by_one
        cmp rdx, 1
        je by_four
        cmp rdx, 2
        je by_n

by_one:
        rol rdi, 1
        dec rcx
        jnz by_one
        jmp return

by_four:
        rol rdi, 4
        dec rcx
        jnz by_four
        jmp return

by_n:
        mov rdx, rcx
        mov rcx, r8
by_n_loop:
        rol rdi, cl
        dec rdx
        jnz by_n_loop
        jmp return
        










return:
        mov rax, rdi
        xor rax, rsi
        ret
