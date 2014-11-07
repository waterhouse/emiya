

        ;; rdi = buf1 (src)
        ;; rsi = buf2 (dest)
        ;; rdx = len (words)
        ;; rcx = offset into buf2
        ;; r8 = mode

        mov rax, 0xfffefafd

        pushfq
        push rbx
        push rcx
        push rdx
        push rdi
        push rsi
        push rbp
        push r8
        push r9
        push r10
        push r11
        push r12
        push r13
        push r14
        push r15

        add rsi, rcx            ;now it's pure copying

        cmp r8, 0
        je mov
        cmp r8, 1
        je mov_unrolled
        cmp r8, 2
        je movsq
        cmp r8, 3
        je movsb


mov:
        cmp rdx, 0
        jng return
mov_loop:
        mov rax, [rdi]
        mov [rsi], rax
        add rsi, 8
        add rdi, 8
        dec rdx
        jnz mov_loop

        jmp return

mov_unrolled:
        ;; rdi to rsi, len rdx

        mov r9, rdx
        and r9, 3

        cmp r9, 0
        je unroll_0
        sub rdi, 8
        sub rsi, 8
        
        cmp r9, 1
        je unroll_1
        sub rdi, 8
        sub rsi, 8

        cmp r9, 2
        je unroll_2
        sub rdi, 8
        sub rsi, 8
        
        cmp r9, 3
        je unroll_3
        jmp return   ;lolwut, never can happen
unroll_0:
        mov rax, [rdi]
        mov [rsi], rax
unroll_1:
        mov rcx, [rdi+8]
        mov [rsi+8], rcx
unroll_2:
        mov rbx, [rdi+16]
        mov [rsi+16], rbx
unroll_3:
        mov r8, [rdi+24]
        mov [rsi+24], r8
        
        add rdi, 32
        add rsi, 32
        sub rdx, 4
        jnl unroll_0
        jmp return

movsq:
        xchg rsi, rdi           ;rsi -> rdi
        cld
        mov rcx, rdx
        rep movsq
        jmp return

movsb:
        xchg rsi, rdi
        cld
        mov rcx, rdx
        shl rcx, 3
        rep movsb
        jmp return









return:

        
        pop r15
        pop r14
        pop r13
        pop r12
        pop r11
        pop r10
        pop r9
        pop r8
        pop rbp
        pop rsi
        pop rdi
        pop rdx
        pop rcx
        pop rbx
        popfq

        ret

        ;; Results:
        ;; For 400 MB blocks, so 50M words (on laptop):

        ;; A -> B:
        ;; 72 msec for mov, mov_unrolled (after shit been loaded into cache)
        ;; 60-61 msec for movsq, 61-62 msec for movsb

        ;; A -> A + n*8:
        ;; Fairly consistent performance from mov, except when n=1 or 2; down to 51 msec by n=3,
        ;;  manages 43 msec by n=36 (on one test), and doesn't go below 43. Up to 50 msec by n=3000,
        ;;  up to 60 msec by n=300,000. No significant spikes at strange numbers.
        ;; From movsq: goes as low as 21-25 msec, up to 34-37 by n=3000 and 42 msec by n=300,000.
        ;;  Spikes up to 51-52 msec at "unlucky" numbers that are 512m ± 1-7.  Even at m=3000 (so
        ;;  the offset is about 1.5M words), that makes a difference: 51 -> 70. WTF?
        ;; From movsb: similar (perhaps a tad worse), but the spikes are 3x-2x worse: 156-159 msec around
        ;;  n=512ish, and 168-173 msec at m=3000.
        ;; These spikes happen even when I copy from A to B.
        ;; Therefore, they have to do with alignment.  I suppose it's likely that ... ?
        ;; Seems in racket, all byte-strings larger than 16K are allocated to a certain kind of byte-
        ;; boundary.  Seems like 8 + 4096n. ... Hmmph.  Whatever. Nothing I can fix right now...