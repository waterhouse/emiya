

        mov rax, 0xfffefafd

        ;; Actually this is more like the signal handler.
        ;; But oh well.

head:
        mov qword [rel head - 8], 69
        mov qword [rel head - 8], 69
        mov qword [rel head - 8], 69

        ret

tail:
        mov rax, 0xffeeffee