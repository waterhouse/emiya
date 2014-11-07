

        mov rax, 0xfffefafd

        jmp lel


move_rax:
        mov rax, 23
        ret

move_rbx:
        mov rax, 69
        ret
        

        %macro meh 1
        call move_%1
        %endmacro


lel:
        cmp rdi, 1
        jne lel2

        meh rax
        ret

lel2:
        meh rbx
        ret
        
        