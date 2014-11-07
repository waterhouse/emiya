

        mov rax, 0xfffefafd

        %define FAKE_RAX rax
        
        %macro QUADRUPLE_RAX 0
        add FAKE_RAX, FAKE_RAX
        add FAKE_RAX, FAKE_RAX
        %endmacro
        



        mov rax, rdi
        QUADRUPLE_RAX
        ret
        