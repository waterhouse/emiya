

        mov rax, 0xfffefafd

        ;; rdi = n
        cmp rdi, 0
        je return

loop:
        dec rdi
        jnz loop


return:
        ret