


        ;; We should be passed the function "dlsym" as well as
        ;; a "handle" for the system library, in a bytevector that
        ;; should be rdi.

        ;; Never mind, it's easier to get dlopen and dlsym, and we can have the
        ;; string "/usr/lib/libSystem.dylib".
        
        mov rax, 0xfffefafd

        default rel

        ;; mov rax, 3
        ;; call [rdi]
        ;; ret


        mov r10, [rdi]          ;dlopen
        mov r11, [rdi + 8]      ;dlsym


        

        push rdi
        ;; sub rsp, 8              ;alignment to whatever, in case
        push r11

        ;; ;; fuck this shit
        ;; push rbp
        ;; mov rbp, rsp

        ;; and rsp, -16

        lea rdi, [the_path]
        mov rsi, 0
        mov rax, 0
        call r10
        ;; result is a handle

        ;; mov rsp, rbp
        ;; pop rbp

        ;; add rsp, 16
        ;; ret

        mov rdi, rax
        lea rsi, [the_puts]
        call [rsp]              ;lel
        ;; we should now have puts in rax
        lea rdi, [the_string]
        call rax

        add rsp, 16
        ret
        

the_path:
        db "/usr/lib/libSystem.dylib", 0

the_puts:
        db "puts", 0

the_string:
        db "Achtung", 0
        

        
