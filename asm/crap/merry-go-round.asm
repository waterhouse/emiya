

        mov rax, 0xfffefafd

        ;; xchg will certainly use fewer registers. (one fewer with no tricks.)
        ;; I expect it to be faster at least for swapping two.
        ;; I expect it to screw up a pipeline somewhat
        ;; (though not too much in "Ivy Bridge"+, where apparently
        ;;  they implement register-register MOVs by renaming registers
        ;;  or something)
        ;; when swapping a bunch.

        ;; see whether two tmp regs helps for this (movs)
        ;; see whether using RAX makes a difference


        ;; rdi = n
        ;; rsi = mode
        ;; rdx rcx r8 r9 are values to fuck with


        cmp rsi, 0
        je two_xchg
        cmp rsi, 1
        je two_xchg_rax
        cmp rsi, 2
        je two_mov
        cmp rsi, 3
        je two_mov_rax

two_xchg:
        xchg rdx, rcx
        dec rdi
        jnz two_xchg
return_rdx:
        mov rax, rdx
        ret

two_xchg_rax:
        mov rax, rdx
        mov rdx, rcx            ;oh man
two_xchg_rax_loop:
        xchg rax, rdx
        dec rdi
        jnz two_xchg_rax_loop
        ret

two_mov:
        mov rsi, rdx
        mov rdx, rcx
        mov rcx, rsi
        dec rdi
        jnz two_mov
        jmp return_rdx

two_mov_rax:
        mov rax, rdx
        mov rdx, rcx
two_mov_rax_loop:
        mov rsi, rax
        mov rax, rdx
        mov rdx, rsi
        dec rdi
        jnz two_mov_rax_loop
        ret

        ;; ok, the fuckers are absolutely all indistinguishable.
        ;; (_maybe_ the difference between 552 and 555 msec for 10^9 iters.)
        ;; I guess that is not surprising for two registers:
        ;; the majority of the problem is with decrementing the crap.
        ;; will test four, then will test twelve or so.

        