
        ;; Results: 315-320 msec for 1b repetitions on Tau for by_four
        ;; and 622-631 msec for by_n.
        
        mov rax, 0xfffefafd

        ;; rdi, rsi are dicks
        ;; rdx = mode
        ;; rcx = repetitions
        ;; r8 = amount to shift by, if mode 2

        cmp rcx, 0
        je return

        cmp rdx, 1
        je by_four
        cmp rdx, 2
        je by_n

by_four:
        shrd rdi, rsi, 4
        dec rcx
        jnz by_four
        jmp return

by_n:
        mov rdx, rcx
        mov rcx, r8
by_n_loop:
        shrd rdi, rsi, cl
        dec rdx
        jnz by_n_loop
        jmp return
        










return:
        mov rax, rdi
        xor rax, rsi
        ret