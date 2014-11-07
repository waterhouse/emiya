

        mov rax, 0xfffefafd

        mov qword [rsp - 8], 1

        fldl2e
        ;; fld1
        fimul dword [rsp - 8]

        fstp qword [rsp - 8]

        mov rax, [rsp -8]
        ret

        