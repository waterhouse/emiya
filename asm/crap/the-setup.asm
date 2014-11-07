

        ;; Redundant files because I suck.

        mov rax, 0xfffefafd

        push 9001
        push 2
        push 9001

        ;; rdi = n
        ;; ... I guess I can both dec rdi and check if dick is changed.
        ;; (Another approach is for the payoff to modify the loop variable,
        ;; though that would mean each iteration would read from memory,
        ;; which would suck. Could unroll the loop, but feh.)

loop:
        cmp qword [rsp + 8], 2
        jne done
        dec rdi
        jnz loop



done:
        pop rdi
        pop rax
        pop rdi
        ret