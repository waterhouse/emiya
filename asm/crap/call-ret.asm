
        

        mov rax, 0xfffefafd



;; arc> (each i '(0 0 1 1 0 1) (pr i " ") (time:call-ret-thing call-ret i 100000000))
;; 0 time: 555 cpu: 556 gc: 0 mem: 0
;; 0 time: 551 cpu: 551 gc: 0 mem: 0
;; 1 time: 581 cpu: 581 gc: 0 mem: 0
;; 1 time: 586 cpu: 587 gc: 0 mem: 0
;; 0 time: 553 cpu: 554 gc: 0 mem: 0
;; 1 time: 588 cpu: 588 gc: 0 mem: 0
;; nil
        ;; Verdict: call_ret is mildly faster.
        ;; Meanwhile, both are blown out of the water by inlined.
        ;; On Tau, that is.

;; arc> (each i '(0 0 1 1 2 2 0 1 2) (pr i " ") (time:call-ret-thing call-ret i 100000000))
;; 0 time: 568 cpu: 567 gc: 0 mem: 2480
;; 0 time: 563 cpu: 563 gc: 0 mem: 0
;; 1 time: 601 cpu: 601 gc: 0 mem: 0
;; 1 time: 612 cpu: 611 gc: 0 mem: 0
;; 2 time: 132 cpu: 132 gc: 0 mem: 0
;; 2 time: 129 cpu: 130 gc: 0 mem: 0
;; 0 time: 561 cpu: 561 gc: 0 mem: 0
;; 1 time: 595 cpu: 595 gc: 0 mem: 0
;; 2 time: 127 cpu: 126 gc: 0 mem: 0
        

        ;; rdi = mode
        ;; rsi = n

        mov rdx, 1
        mov rcx, 0

        %macro maybe_load 2
        lea rax, [rel %2]
        cmp rdi, %1
        cmove r8, rax
        %endmacro

        maybe_load 0, call_ret
        maybe_load 1, lea_jmp
        maybe_load 2, inlined
        maybe_load 3, fake_check
        maybe_load 4, fake_check_skip

        jmp r8

        ;; cmp rdi, 0
        ;; je call_ret
        ;; cmp rdi, 1
        ;; je lea_jmp
        ;; cmp rdi, 2
        ;; je inlined
        ;; cmp rdi, 3
        ;; je fake_check
        ;; cmp rdi, 4
        ;; je fake_check_skip


call_ret:
        call call_ret_dick
        call call_ret_dick
        call call_ret_dick
        call call_ret_dick
        dec rsi
        jnz call_ret
        mov rax, rcx
        ret

call_ret_dick:
        add rcx, rdx
        inc rdx
        ret


        %macro lea_call 1
        lea rax, [rel %%the_ret]
        jmp %1
%%the_ret:
        %endmacro
        
lea_jmp:
        lea_call lea_jmp_dick
        lea_call lea_jmp_dick
        lea_call lea_jmp_dick
        lea_call lea_jmp_dick
        dec rsi
        jnz lea_jmp
        mov rax, rcx
        ret

lea_jmp_dick:
        add rcx, rdx
        inc rdx
        jmp rax

        ;; just for comparison
inlined:        
        add rcx, rdx
        inc rdx
        add rcx, rdx
        inc rdx
        add rcx, rdx
        inc rdx
        add rcx, rdx
        inc rdx
        dec rsi
        jnz inlined
        mov rax, rcx
        ret

fake_check:        
        add rcx, rdx
        inc rdx
        cmp rcx, 0
        jl epic_failure
        add rcx, rdx
        inc rdx
        cmp rcx, 0
        jl epic_failure
        add rcx, rdx
        inc rdx
        cmp rcx, 0
        jl epic_failure
        add rcx, rdx
        inc rdx
        cmp rcx, 0
        jl epic_failure
        dec rsi
        jnz fake_check
        mov rax, rcx
        ret

        
        %macro dumb_fake_check 1
        cmp rcx, 0
        jnl %%proceed
        call %1
%%proceed:
        %endmacro
        
fake_check_skip:
        add rcx, rdx
        inc rdx
        dumb_fake_check epic_failure_2
        add rcx, rdx
        inc rdx
        dumb_fake_check epic_failure_2
        add rcx, rdx
        inc rdx
        dumb_fake_check epic_failure_2
        add rcx, rdx
        inc rdx
        dumb_fake_check epic_failure_2
        dec rsi
        jnz fake_check_skip
        mov rax, rcx
        ret
        



epic_failure:
        mov rax, 69
        ret
        
epic_failure_2:
        mov rax, 69
        add rsp, 8
        ret


        ;; this shit is bizarre
;; arc> (each i '(0 0 1 1 2 2 3 3 4 4 0 1 2 3 4) (pr i " ") (time:call-ret-thing call-ret i 100000000))
;; 0 time: 719 cpu: 719 gc: 0 mem: 2320
;; 0 time: 707 cpu: 708 gc: 0 mem: 0
;; 1 time: 602 cpu: 602 gc: 0 mem: 0
;; 1 time: 604 cpu: 603 gc: 0 mem: 0
;; 2 time: 128 cpu: 128 gc: 0 mem: 0
;; 2 time: 127 cpu: 127 gc: 0 mem: 0
;; 3 time: 203 cpu: 203 gc: 0 mem: 0
;; 3 time: 203 cpu: 202 gc: 0 mem: 0
;; 4 time: 190 cpu: 190 gc: 0 mem: 0
;; 4 time: 183 cpu: 183 gc: 0 mem: 0
;; 0 time: 706 cpu: 707 gc: 0 mem: 0
;; 1 time: 605 cpu: 606 gc: 0 mem: 0
;; 2 time: 127 cpu: 127 gc: 0 mem: 0
;; 3 time: 203 cpu: 203 gc: 0 mem: 0
;; 4 time: 188 cpu: 187 gc: 0 mem: 0
;; nil
;; arc> (time:gc)
;; time: 101 cpu: 101 gc: 100 mem: -15102168
;; #<void>
;; arc> (each i '(0 0 1 1 2 2 3 3 4 4 0 1 2 3 4) (pr i " ") (time:call-ret-thing call-ret i 100000000))
;; 0 time: 602 cpu: 602 gc: 0 mem: 0
;; 0 time: 603 cpu: 604 gc: 0 mem: 0
;; 1 time: 597 cpu: 598 gc: 0 mem: 0
;; 1 time: 597 cpu: 597 gc: 0 mem: 0
;; 2 time: 126 cpu: 127 gc: 0 mem: 0
;; 2 time: 126 cpu: 126 gc: 0 mem: 0
;; 3 time: 182 cpu: 183 gc: 0 mem: 0
;; 3 time: 186 cpu: 186 gc: 0 mem: 0
;; 4 time: 181 cpu: 180 gc: 0 mem: 0
;; 4 time: 185 cpu: 186 gc: 0 mem: 0
;; 0 time: 599 cpu: 598 gc: 0 mem: 0
;; 1 time: 597 cpu: 597 gc: 0 mem: 0
;; 2 time: 126 cpu: 127 gc: 0 mem: 0
;; 3 time: 183 cpu: 183 gc: 0 mem: 0
;; 4 time: 182 cpu: 182 gc: 0 mem: 0

        ;; oh well
        
        
