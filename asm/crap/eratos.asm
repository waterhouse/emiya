


        ;; do I use C calling convention?  or completely ignore?
        ;; it seems to have worked to clobber everything...
        ;; I think I'll be conservative and will save registers to follow
        ;; the calling convention.

        ;; note that accessing original registers (not r8-r15) probably carries
        ;; some benefit if I can avoid the REX prefix. ... eh.


        ;; buf, n in rdi rsi

        ;; first, since we use base 2, we handle it.
        ;; iterate over 8-byte chunks, then handle remaining bytes indiv.'lly.
        ;; I would consider using "move string", and using the same tactic from
        ;; gzip: e.g. write 8 bytes to x, then copy 200 bytes from x to x+8.
        ;; that is equivalent to writing 25 copies of that 8-byte.
        ;; but I wonder if that blows a cache or a pipeline or invalidates prefetching
        ;; or something.


        ;; I might test shit, but to start with, I'll just mov.
        ;; Eh...

        mov rax, 0xfffefafd

        ;; SAVING EVERYTHING BUT RAX, RSP
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
        
        cmp rdx, 1
        je movs

        cmp rdx, 0
        je mov

        cmp rdx, 2
        je mov_unrolled

        cmp rdx, 3
        je movsb

        cmp rdx, 4
        je stosq
        cmp rdx, 5
        je stosb

mov:                            ;dumb, doesn't handle the odd bytes at the end
        mov rax, rdi
        
        ;; buf, n, mode, integer, index
        sub rsi, 8
        jl mov_done
mov2:
        mov [rdi], rcx
        add rdi, 8
        sub rsi, 8
        jnl mov2

mov_done:
        add rax, r8
        mov rax, [rax]
        jmp return


        ;; buf, n, mode, extra args in rdi, rsi, rdx, ...


movs:
        ;; rcx = number to skip
        ;; r8  = integer
        ;; r9  = index

        ;; ensure "# words to skip" <= "# words in buf"
        shl rcx, 3
        cmp rcx, rsi
        cmova rax, rcx
        ja return
        shr rcx, 3

        mov r10, rcx
        mov rax, rdi
movs_loop:      
        mov [rdi], r8
        add rdi, 8
        dec r10
        jnz movs_loop

        mov r10, rcx
        shl r10, 3              ;# bytes skipped

        mov rcx, rsi            ;n
        sub rcx, r10            ;bytes further to copy
        shr rcx, 3              ;copying words

        mov rsi, rdi
        sub rsi, r10            ;rsi -> rdi
        

        cld
        rep movsq

        add rax, r9
        mov rax, [rax]
        jmp return

movsb:
        ;; rcx = number to skip
        ;; r8  = integer
        ;; r9  = index

        ;; ensure "# words to skip" <= "# words in buf"
        shl rcx, 3
        cmp rcx, rsi
        cmova rax, rcx
        ja return
        shr rcx, 3

        mov r10, rcx
        mov rax, rdi
movsb_loop:      
        mov [rdi], r8
        add rdi, 8
        dec r10
        jnz movsb_loop

        mov r10, rcx
        shl r10, 3              ;# bytes skipped

        mov rcx, rsi            ;n
        sub rcx, r10            ;bytes further to copy
        ;; shr rcx, 3              ;copying words

        mov rsi, rdi
        sub rsi, r10            ;rsi -> rdi
        

        cld
        rep movsb

        add rax, r9
        mov rax, [rax]
        jmp return




        ;; All right, testing (on Tau) shows:
        ;; mode 0 (mov): 47 msec to fill 400,000,000 bytes.
        ;; mode 1 (movs):
        ;; - 92 msec when skipping 1 word
        ;; - 57-58 msec when skipping 2 words
        ;; - 50 msec when skipping 3 words
        ;; - 49 msec when skipping 4 words
        ;; - 46-47 msec when skipping 8 words, and 16, and 32.

        ;; Seems mov with a loop is tied for best, and simplest.
        ;; WAIT NO

        ;; - 34-37 msec when skipping 8000 words.  Jesus.
        ;; 35-37 at 16k
        ;; 38 at 160k
        ;; up to 56 msec at 1.6m (probably it blows a cache of some sort)

        ;; 25 msec at 1600
        ;; 23-24 at 1000, 500
        ;; 23-25 at 100

        ;; OH FUCK
        ;; I FORGOT TO TRY UNROLLING EL LOOPO

mov_unrolled:                            ;dumb, doesn't handle the odd bytes at the end
        mov rax, rdi
        
        ;; buf, n, mode, integer, index

        mov r9, rsi
        shr r9, 3
        and r9, 3

        cmp r9, 0
        je unroll_0
        sub rdi, 8
        cmp r9, 1
        je unroll_1
        sub rdi, 8
        cmp r9, 2
        je unroll_2
        sub rdi, 8
        cmp r9, 3
        je unroll_3
        jmp mov_unrolled_done   ;lolwut, never can happen
unroll_0:
        mov [rdi], rcx
unroll_1:       
        mov [rdi+8], rcx
unroll_2:
        mov [rdi+16], rcx
unroll_3:
        mov [rdi+24], rcx
        add rdi, 32
        sub rsi, 32
        jnl unroll_0

mov_unrolled_done:
        add rax, r8
        mov rax, [rax]
        jmp return

        ;; buf n mode integer index crap
stosq:
        mov rax, rcx
        mov rcx, rsi
        shr rcx, 3
        cld
        rep stosq

        jmp return

stosb:
        mov rax, rcx
        mov rcx, rsi
        cld
        rep stosb

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

        ;; TURNS OUT THAT UNROLLING LOOP BY 4 TAKES ~EXACTLY AS LONG AS NOT UNROLLING
        ;; CLEARLY IT IS MEMORY-OPERATION-BOUND
        ;; AND CLEARLY MOVE STRING CHEATS SOMEHOW
        ;; WELL.  MOVE STRING IT IS THEN.


        ;; OH MY GOD TURNS OUT THERE'S A STORE STRING OPERATION
        ;; THAT HAS TO BEAT EVERYTHING COMPLETELY
        ;; JESUS CHRIST

        

;; arc> (time:for i 1 100 (pr i " ") (time:ee dest 400000000 1 i #xfeed 16))
;; 1 time: 93 cpu: 93 gc: 0 mem: 416
;; 2 time: 54 cpu: 54 gc: 0 mem: 416
;; 3 time: 48 cpu: 48 gc: 0 mem: 416
;; 4 time: 48 cpu: 48 gc: 0 mem: 416
;; 5 time: 47 cpu: 48 gc: 0 mem: 416
;; 6 time: 48 cpu: 47 gc: 0 mem: 416
;; 7 time: 48 cpu: 48 gc: 0 mem: 416
;; 8 time: 46 cpu: 46 gc: 0 mem: 416
;; 9 time: 50 cpu: 50 gc: 0 mem: 416
;; 10 time: 45 cpu: 46 gc: 0 mem: 416
;; 11 time: 47 cpu: 47 gc: 0 mem: 416
;; 12 time: 46 cpu: 46 gc: 0 mem: 416
;; 13 time: 47 cpu: 47 gc: 0 mem: 416
;; 14 time: 46 cpu: 46 gc: 0 mem: 416
;; 15 time: 46 cpu: 46 gc: 0 mem: 416
;; 16 time: 46 cpu: 46 gc: 0 mem: 416
;; 17 time: 46 cpu: 46 gc: 0 mem: 416
;; 18 time: 46 cpu: 46 gc: 0 mem: 416
;; 19 time: 46 cpu: 47 gc: 0 mem: 416
;; 20 time: 45 cpu: 45 gc: 0 mem: 416
;; 21 time: 46 cpu: 47 gc: 0 mem: 416
;; 22 time: 47 cpu: 46 gc: 0 mem: 416
;; 23 time: 46 cpu: 46 gc: 0 mem: 416
;; 24 time: 46 cpu: 46 gc: 0 mem: 416
;; 25 time: 46 cpu: 46 gc: 0 mem: 416
;; 26 time: 46 cpu: 47 gc: 0 mem: 416
;; 27 time: 46 cpu: 46 gc: 0 mem: 416
;; 28 time: 46 cpu: 46 gc: 0 mem: 416
;; 29 time: 46 cpu: 46 gc: 0 mem: 416
;; 30 time: 47 cpu: 46 gc: 0 mem: 416
;; 31 time: 46 cpu: 47 gc: 0 mem: 416
;; 32 time: 47 cpu: 46 gc: 0 mem: 416
;; 33 time: 47 cpu: 47 gc: 0 mem: 416
;; 34 time: 46 cpu: 47 gc: 0 mem: 416
;; 35 time: 47 cpu: 47 gc: 0 mem: 416
;; 36 time: 47 cpu: 47 gc: 0 mem: 416
;; 37 time: 47 cpu: 47 gc: 0 mem: 416
;; 38 time: 47 cpu: 48 gc: 0 mem: 416
;; 39 time: 47 cpu: 47 gc: 0 mem: 416
;; 40 time: 49 cpu: 49 gc: 0 mem: 416
;; 41 time: 49 cpu: 49 gc: 0 mem: 416
;; 42 time: 47 cpu: 47 gc: 0 mem: 416
;; 43 time: 48 cpu: 48 gc: 0 mem: 416
;; 44 time: 48 cpu: 48 gc: 0 mem: 416
;; 45 time: 48 cpu: 48 gc: 0 mem: 416
;; 46 time: 48 cpu: 48 gc: 0 mem: 416
;; 47 time: 49 cpu: 49 gc: 0 mem: 416
;; 48 time: 48 cpu: 49 gc: 0 mem: 416
;; 49 time: 49 cpu: 49 gc: 0 mem: 416
;; 50 time: 48 cpu: 49 gc: 0 mem: 416
;; 51 time: 49 cpu: 50 gc: 0 mem: 416
;; 52 time: 49 cpu: 49 gc: 0 mem: 416
;; 53 time: 51 cpu: 50 gc: 0 mem: 416
;; 54 time: 49 cpu: 50 gc: 0 mem: 416
;; 55 time: 51 cpu: 51 gc: 0 mem: 416
;; 56 time: 50 cpu: 50 gc: 0 mem: 416
;; 57 time: 52 cpu: 52 gc: 0 mem: 416
;; 58 time: 50 cpu: 50 gc: 0 mem: 416
;; 59 time: 52 cpu: 51 gc: 0 mem: 416
;; 60 time: 49 cpu: 50 gc: 0 mem: 416
;; 61 time: 51 cpu: 51 gc: 0 mem: 416
;; 62 time: 49 cpu: 49 gc: 0 mem: 416
;; 63 time: 47 cpu: 47 gc: 0 mem: 416
;; 64 time: 43 cpu: 43 gc: 0 mem: 416
;; 65 time: 42 cpu: 41 gc: 0 mem: 416
;; 66 time: 39 cpu: 39 gc: 0 mem: 416
;; 67 time: 38 cpu: 38 gc: 0 mem: 416
;; 68 time: 35 cpu: 35 gc: 0 mem: 416
;; 69 time: 32 cpu: 32 gc: 0 mem: 416
;; 70 time: 29 cpu: 29 gc: 0 mem: 416
;; 71 time: 26 cpu: 26 gc: 0 mem: 416
;; 72 time: 27 cpu: 27 gc: 0 mem: 416
;; 73 time: 25 cpu: 25 gc: 0 mem: 416
;; 74 time: 23 cpu: 24 gc: 0 mem: 416
;; 75 time: 23 cpu: 22 gc: 0 mem: 416
;; 76 time: 22 cpu: 22 gc: 0 mem: 448
;; 77 time: 22 cpu: 22 gc: 0 mem: 416
;; 78 time: 22 cpu: 22 gc: 0 mem: 416
;; 79 time: 22 cpu: 21 gc: 0 mem: 416
;; 80 time: 22 cpu: 23 gc: 0 mem: 416
;; 81 time: 21 cpu: 21 gc: 0 mem: 416
;; 82 time: 22 cpu: 21 gc: 0 mem: 416
;; 83 time: 21 cpu: 21 gc: 0 mem: 416
;; 84 time: 21 cpu: 22 gc: 0 mem: 416
;; 85 time: 21 cpu: 21 gc: 0 mem: 416
;; 86 time: 21 cpu: 21 gc: 0 mem: 416
;; 87 time: 21 cpu: 21 gc: 0 mem: 416
;; 88 time: 21 cpu: 21 gc: 0 mem: 416
;; 89 time: 20 cpu: 21 gc: 0 mem: 416
;; 90 time: 22 cpu: 22 gc: 0 mem: 416
;; 91 time: 21 cpu: 21 gc: 0 mem: 448
;; 92 time: 21 cpu: 21 gc: 0 mem: 416
;; 93 time: 21 cpu: 21 gc: 0 mem: 416
;; 94 time: 21 cpu: 21 gc: 0 mem: 416
;; 95 time: 22 cpu: 22 gc: 0 mem: 416
;; 96 time: 22 cpu: 22 gc: 0 mem: 416
;; 97 time: 22 cpu: 22 gc: 0 mem: 416
;; 98 time: 23 cpu: 23 gc: 0 mem: 416
;; 99 time: 22 cpu: 22 gc: 0 mem: 416
;; 100 time: 23 cpu: 23 gc: 0 mem: 416
;; time: 3979 cpu: 3984 gc: 0 mem: 218928
;; nil
;; rlwrap: warning: arc killed by SIGSEGV.
;; rlwrap has not crashed, but for transparency,
;; it will now kill itself (without dumping core)with the same signal

;; Segmentation fault


       ;; And now more, comparing movs to movsb.  They seem comparable in the optimal area.  Though movsb is
       ;; consistently the slower one in general.
        ;; From 2048 to 2049 there's a big gap, from "23 22" to "50 154". Jethuth chritht.
        ;; ... Inexplicable spike at 2049-2055, then back down at 2056 (2048 + 8).
        ;; Wonder...

        ;; Looks like: (see movs-testing.txt)
        ;; For maximum performance, don't go above 2048; 2048 is good;
        ;; stuff between 1-7 away from a power of 2 is quite bad; stuff above 2048 is baddish.
        ;; baddish = 1.5x, quite bad = 2x for MOVSQ and 6x for MOVSB.
        ;; ... Fuck.
        ;; ... And on my desktop, the same things are quite bad, though quite bad = maybe 1.3x and 2x for MOVS{Q,B} resp.
        ;; ... Well.

       ;; arc> (grid:map (fn (x) (cons x (map [let u (tostring:time:e-thing eratos dest 400000000 _ x #xfeed 17) (read:cut u (pos digit u))] '(1 3)))) (join (range 1 1) (mappend (fn (siz) (map [* siz _] '(2 3 4 6 8 10))) (mapn [expt 10 _] 0 7))))
       ;;         1 92 148
       ;;         2 55 152
       ;;         3 47 153
       ;;         4 47 148
       ;;         6 47 143
       ;;         8 45  46
       ;;        10 45  45
       ;;        20 46  45
       ;;        30 46  46
       ;;        40 47  47
       ;;        60 49  50
       ;;        80 21  23
       ;;       100 21  21
       ;;       200 20  21
       ;;       300 21  20
       ;;       400 21  21
       ;;       600 21  20
       ;;       800 21  21
       ;;      1000 21  21
       ;;      2000 20  21
       ;;      3000 31  35
       ;;      4000 33  35
       ;;      6000 34  35
       ;;      8000 33  36
       ;;     10000 32  35
       ;;     20000 32  35
       ;;     30000 32  35
       ;;     40000 32  34
       ;;     60000 32  36
       ;;     80000 32  35
       ;;    100000 31  35
       ;;    200000 34  37
       ;;    300000 40  42
       ;;    400000 47  51
       ;;    600000 51  56
       ;;    800000 52  56
       ;;   1000000 53  55
       ;;   2000000 52  56
       ;;   3000000 53  56
       ;;   4000000 52  56
       ;;   6000000 52  56
       ;;   8000000 51  53
       ;;  10000000 53  54
       ;;  20000000 49  51
       ;;  30000000 48  49
       ;;  40000000 46  48
       ;;  60000000  0   0
       ;;  80000000  0   0
       ;; 100000000  0   0
