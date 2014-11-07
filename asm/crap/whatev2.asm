

        align 8
        dq 21
        nop
        align 8
        dq 37
        nop
        nop
        align 8
        dq 49

        mov rax, 0xfffefafd

        jmp dick
        align 8
lel:
        
        dq 55
        nop
        nop
dick:   
        mov rax, [rel lel]
        ret


        
