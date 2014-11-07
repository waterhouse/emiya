

        mov rax, 0xfffefafd

        ;; rdi = buf, rsi = n, rdx = dick

        cmp rsi, 0
        jng return
loop:
        and [rdi], rdx
        add rdi, 8
        sub rsi, 8
        jg loop

return:
        ret