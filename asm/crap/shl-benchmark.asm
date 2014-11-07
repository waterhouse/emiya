
        ;; Results: 316-319 msec for 1b repetitions on Tau for by_four,
        ;; 314-322 msec for by_one,
        ;; and 625-632 msec for by_n.

	;; On Alvin, 380-390 msec for all.
        
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
        shl rdi, 1
        dec rcx
        jnz by_one
        jmp return

by_four:
        shl rdi, 4
        dec rcx
        jnz by_four
        jmp return

by_n:
        mov rdx, rcx
        mov rcx, r8
by_n_loop:
        shl rdi, cl
        dec rdx
        jnz by_n_loop
        jmp return
        










return:
        mov rax, rdi
        xor rax, rsi
        ret
