

        mov rax, 0xfffefafd

        ;; copy from A+a to B+b, n words, words are m bytes.
        ;; A a B b n m
        ;; rdi rsi rdx rcx r8 r9
        ;; base, offset A, offset B, number of units to copy, mode (1 2 4 8)

        ;; All right, confusion resolved.
        ;; If the difference between src and dest is of the form
        ;; 4096n +- {1..63}
        ;; then shit is slowed down.
        ;; I was confused for a while because this is bytes (critical 4096 +- 1-63),
        ;; while the original was words (critical 512 +- 1-7).

        ;; movs: rsi -> rdi.

        add rdi, rsi
        add rdx, rcx
        mov rsi, rdi
        mov rdi, rdx
        mov rcx, r8

        cld                     ;I think it's cleared by default but be sure
        cmp r9, 1
        je movsb
        cmp r9, 2
        je movsw
        cmp r9, 4
        je movsd
        cmp r9, 8
        je movsq
        ret

movsb:  rep movsb
        ret
movsw:  rep movsw
        ret
movsd:  rep movsd
        ret
movsq:

        ;; mov rax, rdi
        ;; sub rax, rsi
        ;; ret

        rep movsq
        ret