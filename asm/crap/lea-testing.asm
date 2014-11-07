

        mov rax, 0xfffefafd

cock:   

        nop
        lea rax, [rax + rax]    ;4 bytes
        nop
        lea rax, [rax + rbx]    ;4 bytes
        nop
        lea rax, [rax + 8*rax]  ;4 bytes
        nop
        lea rax, [rax + 8*rbx]  ;4 bytes
        nop
        lea rax, [rel cock]     ;7 bytes
        nop
        lea rax, [rel cock + 20] ;7 bytes
        nop
        ;; lea rax, [rel cock + rbx] ;doesn't work, indeed
        lea rax, [rbx + 20]     ;4 bytes
        nop
        lea rax, [8*rbx + 20]   ;8 bytes
        nop

        mov eax, [ebx*2+ecx+23] ;aw fuck, that's actually legal ;5 bytes
        nop
        lea rax, [rbx*2+rcx+23] ;5 bytes
        nop

        ;; Interesting.
        ;; There isn't such a thing as rip + disp8.
        ;; Also, there is reg + disp8, but not 8*reg + disp8.
        ;; In both of the above cases, you instead must use a disp32.

        ;; Btw, while I'm at it (lel terrible organization)

        mov rcx, 3              ;5 bytes
        nop
        mov ecx, 3              ;5 bytes
        nop

        ;; Ok, the above two produce the same code, the former with no REX prefix.
        ;; That is good.
        ;; Otherwise I'd be hella annoyed.

        mov cl, 7               ;2 bytes
        nop
        xor ecx, ecx            ;2 bytes
        nop

        mov eax, [rax + rbx]    ;hoho ;3 bytes
        nop
        ;; mov eax, [rax + eax]    ;doesn't work


        
        