

        mov rax, 0xfffefafd

        xor rax, rax
        bt [rdi], rsi
        setc al
        ret