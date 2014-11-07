


        nop
        nop
        nop
        mov rax, 0xfffefafd
        ;; The above takes exactly eight bytes.
        ;; Now...

        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        ;; lelz

        jmp wtvr


meh:
        resq 1

wtvr:
        add rax, 3
        jmp achtung

meh2:
        resq 1

achtung:
        xor eax, eax
        add rax, 3
        jmp nerf

meh3:
        resq 1

nerf:
        ret
        

        ;; Ok, so, the conclusion is, dq does not get aligned to 8 bytes.
        ;; The code output of this includes "meh" and "meh2" being separated
        ;; by 6 bytes (their beginnings separated by 14 bytes), which implies
        ;; it is absolutely impossible to map this to a portion of memory
        ;; where they are both aligned ta multiple of 8.

        ;; And the story is the same with resq.
        ;; Interesting.
        ;; I take it I will need to .align crap myself if I want it aligned, then.

        