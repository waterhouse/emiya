

        mov rax, 0xfffefafd


        pushfq
        push rbx
        push rcx
        push rdx
        push rdi
        push rsi
        push rbp
        push r8
        push r9
        push r10
        push r11
        push r12
        push r13
        push r14
        push r15




movs:
        ;; rdi = buf
        ;; rsi = n
        ;; rdx = mode
        ;; rcx = number to skip
        ;; r8  = integer
        ;; r9  = index

        mov r8, rsi
        shl rcx, 3
        mov rsi, rdi            ;src
        add rdi, rcx            ;dest
        neg rcx
        add rcx, r8
        shr rcx, 3

        ;; mov rax, rdi
        ;; sub rax, rsi
        ;; jmp return


        cld
        rep movsq

        ;; add rax, r9
        ;; mov rax, [rax]
        jmp return



return:
        pop r15
        pop r14
        pop r13
        pop r12
        pop r11
        pop r10
        pop r9
        pop r8
        pop rbp
        pop rsi
        pop rdi
        pop rdx
        pop rcx
        pop rbx
        popfq

        ret