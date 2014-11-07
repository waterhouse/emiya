

        mov rax, 0xfffefafd

        ;; is "jmp reg" faster or slower than "jmp <offset>"?


        call startstart
        db "startstart"
startstart:
        mov rdx, [rsp]
        mov rcx, [rsp]
        mov r8, [rsp]
        add rdx, 59
        add rcx, 68
        add r8, 78
        add rsp, 8

        cmp rsi, 0
        je start
        cmp rsi, 1
        je start2

start:
        jmp rdx
        db "place_a"
place_a:
        jmp rcx
        db "place_b"
place_b:
        jmp r8                  ;note that since r8 is an extra GPR, there is an
        db "place_c"            ;extra 41 prefix byte, so [place_c - place_b] is 10
place_c:                        ;while [place_b - place_a] is 9.
        dec rdi
        jnz start
        mov rax, 23
        ret

start2:
        jmp place_a2
        db "place_a"
place_a2:
        jmp place_b2
        db "place_b"
place_b2:
        jmp place_c2
        db "place_c"
place_c2:
;;         jmp place_d2
;;         db "place_d2"
;; place_d2:       
        dec rdi
        jnz start2
        mov rax, 69
        ret