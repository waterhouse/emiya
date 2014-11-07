

        mov rax, 0xfffefafd

        ;; ... How can shit get passed as "an argument"?
        ;; Shit being "a place to save the regs".
        ;; Likely an array of 16-20 words.
        ;; The problem is that all the registers should be used by the user code.
        ;; Can't really pass arguments in there.
        ;; It seems I should go for RIP-relative dick.
        ;; In a full program, I might go for global variables of some kind.
        ;; Which are RIP-relative.
        ;; Here... just whatever crap.
        ;; Actually, I don't need a pointer to an array.  I can just have 20 extra words.
        ;; Wootz.

        ;; Model.
        ;; mov [teh_end + 8], rbx

        ;; arc> (pbcopy:tostring:on x '(rax rbx rcx rdx rdi rsi rbp rsp r8 r9 r10 r11 r12 r13 r14 r15) (prn "        " "mov [rel teh_end + " (* index 8) "], " x))

        mov rax, 0xfeed

        mov [rel teh_end + 0], rax
        mov [rel teh_end + 8], rbx
        mov [rel teh_end + 16], rcx
        mov [rel teh_end + 24], rdx
        mov [rel teh_end + 32], rdi
        mov [rel teh_end + 40], rsi
        mov [rel teh_end + 48], rbp
        mov [rel teh_end + 56], rsp
        mov [rel teh_end + 64], r8
        mov [rel teh_end + 72], r9
        mov [rel teh_end + 80], r10
        mov [rel teh_end + 88], r11
        mov [rel teh_end + 96], r12
        mov [rel teh_end + 104], r13
        mov [rel teh_end + 112], r14
        mov [rel teh_end + 120], r15

        ret

        ;; align 8

        ;; this has the absurd result
        ;; that there are 123 bytes ... oh.
        ;; it's probably aligned ... lolz.
        ;; [aligned to the "mov rax, 0xfffefafd" at the start]
        ;; terrible.
        ;; ok, time for manual alignment.
        ret
        ret
        

teh_end:
        ;; oh god alignment issues...

        mov rax, 0xdeefdeef