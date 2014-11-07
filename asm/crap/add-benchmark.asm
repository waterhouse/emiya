
        ;; Results: 316-320 msec for 1b repetitions on Tau.

        mov rax, 0xfffefafd

        ;; rdi, rsi = dicks
        ;; rdx = n

        cmp rdx, 0
        je return
        
loop:
        add rdi, rsi
        dec rdx
        jnz loop
        jmp return



return:
        mov rax, rdi
        add rax, rsi
        ret