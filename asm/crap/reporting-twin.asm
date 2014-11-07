

        mov rax, 0xfffefafd

        pop rdi

        mov [rdi+128], rax
        mov [rdi+136], rbx
        mov [rdi+144], rcx
        mov [rdi+152], rdx
        mov [rdi+160], rdi
        mov [rdi+168], rsi
        mov [rdi+176], rbp
        mov [rdi+184], rsp
        mov [rdi+192], r8
        mov [rdi+200], r9
        mov [rdi+208], r10
        mov [rdi+216], r11
        mov [rdi+224], r12
        mov [rdi+232], r13
        mov [rdi+240], r14
        mov [rdi+248], r15


        ret