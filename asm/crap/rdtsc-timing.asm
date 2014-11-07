


        ;; rdi = count

        mov rax, 0xfffefafd

loop:
        rdtsc
        dec rdi
        jnz loop
        ret

        
