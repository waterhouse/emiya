


        mov rax, 0xfffefafd

        ;; The question is, what kinds of addressing are allowed?
        ;; Apparently you can use 32-bit addresses.

        mov rax, [rsp]
        mov rax, [esp]
        mov eax, [rsp]
        mov eax, [esp]

        mov rdi, 0
        
        mov rax, [rsp + rdi]
        mov rax, [esp + edi]
        mov eax, [rsp + rdi]
        mov eax, [esp + edi]

        ;; I'm not even gonna try "[reg64 + reg32]", that seems obviously stupid.

        ret

        ;; Turns out all the above are legal.  Welp.


        
