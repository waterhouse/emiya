

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
        cmp rsi, 4
        je four_xchg
        cmp rsi, 5
        je four_mov
        cmp rsi, 6
        je four_mov_two
        cmp rsi, 7
        je twelve_xchg
        cmp rsi, 8
        je twelve_mov

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

        ;; rdx <- rcx
        ;; rcx <- r8
        ;; r8 <- r9
        ;; r9 <- rdx
        
four_xchg:
        xchg rdx, rcx
        xchg rcx, r8
        xchg r8, r9
        dec rdi
        jnz four_xchg
        jmp return_rdx

four_mov:
        mov rsi, rdx
        mov rdx, rcx
        mov rcx, r8
        mov r8, r9
        mov r9, rsi
        dec rdi
        jnz four_mov
        jmp return_rdx

four_mov_two:                   ;hmm... even number is useful.
        mov rsi, rdx
        mov rax, r8
        mov rdx, rcx
        mov r8, r9
        mov r9, rsi
        mov rcx, rax
        dec rdi
        jnz four_mov_two
        jmp return_rdx

        ;; very well... four_xchg might be the tiniest bit faster. maybe by 0.2%.
        ;; not even sure of that much.
        ;; ok.
        ;; all expense of mov'ing seems to be dwarfed by the loop, anyway.
        ;; (like, two is the same as four, cost-wise)

        ;; time for twelve.


        ;; we'll take whatever runtime values are there.
        ;; who fucking cares.
        ;; um... should save dicks.
        ;; ... or should ensure I give it a multiple of twelve.
        ;; that sounds much better.
        ;; omg so terrible/good

        ;; don't touch the stacks
        ;; and don't touch rdi
        ;; I guess rsi is scratch or not

        ;; arc> (pbcopy:tostring:let xs '(rax rbx rcx rdx r8 r9 r10 r11 r12 r13 r14 r15) (on x xs (prn "        xchg " x ", " (xs:mod inc.index len.xs))))
        ;; ^ is the idea _BUT_ you should delete the last one because it screws things up
        
twelve_xchg:
        xchg rax, rbx
        xchg rbx, rcx
        xchg rcx, rdx
        xchg rdx, r8
        xchg r8, r9
        xchg r9, r10
        xchg r10, r11
        xchg r11, r12
        xchg r12, r13
        xchg r13, r14
        xchg r14, r15

        dec rdi
        jnz twelve_xchg
        jmp return_rdx


        ;; likewise must tweak this
twelve_mov:
        mov rsi, rax
        
        mov rax, rbx
        mov rbx, rcx
        mov rcx, rdx
        mov rdx, r8
        mov r8, r9
        mov r9, r10
        mov r10, r11
        mov r11, r12
        mov r12, r13
        mov r13, r14
        mov r14, r15
        
        mov r15, rsi

        dec rdi
        jnz twelve_mov
        jmp return_rdx

        ;; even after all this:
        ;; 1. It's not clear which is faster.
        ;; 2. Moving twelve things is apparently no slower than moving two.

        ;; Maybe the problem is absolutely trivial.
        ;; But maybe it would make a difference if I actually made
        ;; some shit happen.
        ;; Bwahaha, wonderful idea...



        