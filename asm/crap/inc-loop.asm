
        ;; On Tau, 2.34 seconds to do 1 billion iterations.

        mov rax, 0xfffefafd

        ;; rdi = int ptr
        ;; rsi = n
        ;; ... fucking goddammit
        ;; rdx = printf
        ;; rcx = string

        cmp rsi, 0
        je return
loop:
        ;; mfence
        ;; lock inc qword [rdi]
        mfence
        mov rax, [rdi]
        mfence
        add rax, 1
        mov [rdi], rax
        mfence
        
        dec rsi
        jnz loop

        ;; need rdi = string, rsi = nptr, rdx = n, and rcx = printf
        
        mov rax, rdx
        mov rdx, [rdi]
        mov rsi, rdi
        mov rdi, rcx
        mov rcx, rax
        mov rax, 4
        push rsi
        
        push rbp
        mov rbp, rsp
        and rsp, -16
        call rcx
        mov rsp, rbp
        pop rbp
        pop rdi

        


return:
        mov rax, rax
        ret
