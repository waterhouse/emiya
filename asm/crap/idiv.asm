

        mov rax, 0xfffefafd

        ;; number, divisor
        mov rax, rdi
        xor edx, edx
        idiv rsi
        ret

        ;; Racket goes into infinite loop if you divide by zero
        