

        mov rax, 0xfffefafd

        ;; ... sigh...

        mov rdi, rsp
        ;; sanity value...
        mov rcx, 10000

search:
        add rdi, 8
        dec rcx
        jz failure
        cmp qword [rdi], 9001
        jne search
        cmp qword [rdi+16], 9001
        jne search
success:
        mov qword [rdi+8], 42
        mov rax, 10000
        sub rax, rcx
        ret


failure:
        mov rax, 1336
        ret


        ;; looks like either Racket uses some weird-ass fixnum tagging system
        ;; that isn't multiplying by 1, 2, 4, 8, or 16,
        ;; or it runs its foreign calls with a way separate stack.
        ;; the latter seems most plausible (given that it seems to do weird
        ;; other shit with the stack).