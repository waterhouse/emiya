



        mov rax, 0xfffefafd


        ;; call rdi
        ;; mov rax, rdi

        default rel

        push r15
        
        push rbp
        mov rbp, rsp

        mov r15, rsi
        
        mov r10, rdi
        lea rdi, [the_path]
        mov rsi, 0
        call r10

        ;; rax is handle

        mov rdi, rax
        lea rsi, [the_puts]
        call r15
        ;; rax is puts
        lea rdi, [the_string]
        call rax

        
        

        mov rsp, rbp
        pop rbp

        pop r15
        
        ret


the_path:
        db "/usr/lib/libSystem.dylib", 0

the_puts:
        db "puts", 0

the_string:     
        db "nerble", 0
        
        
