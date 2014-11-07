

        mov rax, 0xfffefafd

        mov rax, rdi
        neg rdi
        cmovns rax, rdi

        ;; so that's move if sign
        ;; I'm guessing sign = 1 iff negative.
        ;; in other words the title is not misleading.
        ;; and...
        ret
        ;; right.
        ;; unfortunately my Arc interface to this crap deals with uint64s.
        ;; but I think I verified this works as intended.