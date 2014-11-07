
        
        mov rax, 0xfffefafd
        cld
loop:   
        mov rax, rsp
        xor [rax], rax
        xor [rax], rax
        sub rax, 8
        sub rsi, 1              ;arg in rsi for consist.
        jg loop

        ;; TURNS OUT THAT OBEYING THE C CALLING CONVENTION DOES MAKE A DIFFERENCE
        ;; HOWEVER, THERE IS A LOT OF ROOM ON THE STACK IN GENERAL
        ;; (HOW CAN I TEST FOR THAT OR ENSURE IT?)

        ;; mov rbx, rsp
        ;; add rbx, 1
        ;; mov rcx, rbx
        ;; mov rdx, rbx
        ;; mov rdi, rbx
        ;; mov rsi, rbx
        ;; mov rbp, rbx
        ;; mov r8, rbx
        ;; mov r9, rbx
        ;; mov r10, rbx
        ;; mov r11, rbx
        ;; mov r12, rbx
        ;; mov r13, rbx
        ;; mov r14, rbx
        ;; mov r15, rbx
done:
        ret

        