

        mov rax, 0xfffefafd

        ;; xor rax, rax
loop:
        rol rax, 8
        dec rdi
        jnz loop

        ret