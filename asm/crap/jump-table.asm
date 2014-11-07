
        DEFAULT REL

        mov rax, 0xfffefafd

        ;; We test the speed of jump tables versus the speed of laz0r tables.
        ;; By the latter I mean conditional jumps.

        default rel

        ;; setup
        mov rax, 0
        ;; the table, we shall set up either way

        lea rcx, [mod_zero]
        mov [jt], rcx
        lea rcx, [mod_one]
        mov [jt + 8], rcx
        lea rcx, [mod_two]
        mov [jt + 16], rcx
        lea rcx, [mod_three]
        mov [jt + 24], rcx
        lea rcx, [mod_four]
        mov [jt + 32], rcx
        lea rcx, [mod_five]
        mov [jt + 40], rcx
        lea rcx, [mod_six]
        mov [jt + 48], rcx
        lea rcx, [mod_seven]
        mov [jt + 56], rcx
        
        ;; mode = rdi
        ;; index = rsi
        ;; reps = rdx


        cmp rdx, 0
        je done

        cmp rdi, 0
        je loop_jt
        jmp loop_cond
        
loop_jt:
        mov ecx, esi
        and cl, 7
        ;; ass
        ;; dick
        ;; SIB shit doesn't consider RIP a chooseable register
        ;; call [jt + 8*rcx]
        lea rdi, [jt]
        call [rdi + 8*rcx]
        dec rdx
        jnz loop_jt
        ret

jt:
        resq 8


        ;; ...
        ;; fuck
        ;; it's different...
        ;; what will happen in practice are jumps, and here I'm testing calls
        ;; oh well, this may be useful anyway
        ;; [I guess hashing would use calls]
        
loop_cond:      
        mov ecx, esi
        and cl, 7
        cmp cl, 0
        jne loop_cond1
        call mod_zero
        dec rdx
        jnz loop_cond
        ret
loop_cond1:
        cmp cl, 1
        jne loop_cond2
        call mod_one
        dec rdx
        jnz loop_cond
        ret
loop_cond2:
        cmp cl, 2
        jne loop_cond3
        call mod_two
        dec rdx
        jnz loop_cond
        ret
loop_cond3:
        cmp cl, 3
        jne loop_cond4
        call mod_three
        dec rdx
        jnz loop_cond
        ret
loop_cond4:
        cmp cl, 4
        jne loop_cond5
        call mod_four
        dec rdx
        jnz loop_cond
        ret
loop_cond5:
        cmp cl, 5
        jne loop_cond6
        call mod_five
        dec rdx
        jnz loop_cond
        ret
loop_cond6:
        cmp cl, 6
        jne loop_cond7
        call mod_six
        dec rdx
        jnz loop_cond
        ret
loop_cond7:     
        call mod_seven
        dec rdx
        jnz loop_cond
        ret


mod_zero:
        add rax, 1
        ret
mod_one:
        add rax, 2
        ret
mod_two:
        add rax, 3
        ret
mod_three:
        add rax, 4
        ret
mod_four:
        add rax, 5
        ret
mod_five:
        add rax, 6
        ret
mod_six:
        add rax, 7
        ret
mod_seven:
        add rax, 8
        ret



done:
        ret
        
