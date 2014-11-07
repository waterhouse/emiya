
        DEFAULT REL

        mov rax, 0xfffefafd

        ;; We test the speed of jump tables versus the speed of laz0r tables.
        ;; By the latter I mean conditional jumps.

        ;; Well, the prev. was calls.
        ;; Jump tables decidedly win at case 1 onwards, and it depends on imponderables
        ;; which wins at case 0.
        ;; [One could be more clever, with binary crap, but.]
        ;; However, the cond approach was kind of owned for other reasons.
        ;; So.
        ;; Here, we shall have two completely independent experiments...

        ;; And.
        ;; Looks like ... again, comparable at case 0, jt is superior at case >=1.
        ;; Welp.
        ;; Very well then.
        ;; [case 7 is only 3 times slower than case 0 in cond, though]
        

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
        jmp [rdi + 8*rcx]
loop_jt_back:   
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

loop_cond_back:                 ;moving around for conv.
        dec rdx
        jnz loop_cond
        ret
        
loop_cond:      
        mov ecx, esi
        and cl, 7
        cmp cl, 0
        je mod_zero_cond
        cmp cl, 1
        je mod_one_cond
        cmp cl, 2
        je mod_two_cond
        cmp cl, 3
        je mod_three_cond
        cmp cl, 4
        je mod_four_cond
        cmp cl, 5
        je mod_five_cond
        cmp cl, 6
        je mod_six_cond
        jmp mod_seven_cond


mod_zero:
        add rax, 1
        jmp loop_jt_back
mod_one:
        add rax, 2
        jmp loop_jt_back
mod_two:
        add rax, 3
        jmp loop_jt_back
mod_three:
        add rax, 4
        jmp loop_jt_back
mod_four:
        add rax, 5
        jmp loop_jt_back
mod_five:
        add rax, 6
        jmp loop_jt_back
mod_six:
        add rax, 7
        jmp loop_jt_back
mod_seven:
        add rax, 8
        jmp loop_jt_back


mod_zero_cond:  
        add rax, 1
        jmp loop_cond_back
mod_one_cond:   
        add rax, 2
        jmp loop_cond_back
mod_two_cond:   
        add rax, 3
        jmp loop_cond_back
mod_three_cond: 
        add rax, 4
        jmp loop_cond_back
mod_four_cond:  
        add rax, 5
        jmp loop_cond_back
mod_five_cond:  
        add rax, 6
        jmp loop_cond_back
mod_six_cond:   
        add rax, 7
        jmp loop_cond_back
mod_seven_cond: 
        add rax, 8
        jmp loop_cond_back        
        



done:
        ret
        
