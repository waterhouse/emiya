


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
        dq 25

wtvr:
        add rax, 3
        jmp achtung

meh2:
        dq 33

achtung:
        xor eax, eax
        add rax, 3
        jmp nerf

meh3:
        dq 41

nerf:
        ret
        

        ;; Ok, so, the conclusion is, dq does not get aligned to 8 bytes.
        ;; The code output of this includes "meh" and "meh2" being separated
        ;; by 6 bytes (their beginnings separated by 14 bytes), which implies
        ;; it is absolutely impossible to map this to a portion of memory
        ;; where they are both aligned ta multiple of 8.
        

        