


        mov rax, 0xfffefafd

        mov rax, 100
        mov rsi, 1
        mov rdi, 3

        lea rdi, [rax + 8*rsi]
        lea rcx, [rax + 8*rdi]

        mov rax, rcx

        ret

        ;; nope, these all work...
        


        
