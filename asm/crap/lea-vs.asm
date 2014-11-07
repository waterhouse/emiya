

        mov rax, 0xfffefafd

        nop
        nop
        nop
        nop
        lea rdi, [rax + 1]      ;4 bytes
        nop
        nop
        nop
        nop
        lea r12, [rax + 1]      ;4 bytes
        nop
        nop
        nop
        nop
        mov rdi, rax            ;3 bytes +
        inc rdi                 ;3 bytes
        nop
        nop
        nop
        nop
        mov rdi, rax            ;3 bytes +
        add rdi, 1              ;4 bytes
        nop
        nop
        nop
        nop
        mov rdi, rax            ;3 bytes +
        add dil, 1              ;4 bytes
        nop
        nop
        nop
        nop
        


        