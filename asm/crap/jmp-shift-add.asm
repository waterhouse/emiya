


        ;; It has come to my attention that a couple of equivalent instruction sequences
        ;; appear to have drastically, drastically different execution times,
        ;; or conceivably to have drastic effects on pipelining of adjacent instructions
        ;; or something.
        ;; Let's hope it's the first item and that we can test it.

        ;; Hmmph, no difference.
        ;; Welp.

        default rel

        align 8
        nop
        nop
        nop
        mov rax, 0xfffefafd

        ;; rdi = mode, rsi = count

        lea rax, [return_five]
        mov [table], rax
        mov [table + 24], rax
        lea rax, [return_two]
        mov [table + 8], rax
        mov [table + 16], rax
        

        push rcx
        mov rdx, 0
        
        cmp rdi, 0
        je loop_a
        cmp rdi, 1
        je loop_b
        


        
loop_a:
        mov rcx, [rsp]
        lea r8, [table]
        and ecx, 3
        call [r8 + 8*rcx]
        add rdx, rax
        sub rsi, 1
        jg loop_a
        mov rax, rdx
        pop rcx
        ret

loop_b: 
        mov rcx, [rsp]
        lea r8, [table]
        and ecx, 3
        shl cl, 3
        call [r8 + rcx]
        add rdx, rax
        sub rsi, 1
        jg loop_b
        mov rax, rdx
        pop rcx
        ret
        

        align 8
table:
        dq 0
        dq 0
        dq 0
        dq 0
        


return:
        ret


return_five:
        mov rax, 5
        ret

return_two:
        mov rax, 2
        ret
        


        

        
