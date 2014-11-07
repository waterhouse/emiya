

        mov rax, 0xfffefafd

        %define raxd eax
        %define rdid edi

        ;; mov rax, dword rdi ;ignored
        ;; mov raxd, rdid          ;works

        %macro meh 2
        mov %1d, %{2}d        ;don't need the braces but that's how it works
        %endmacro

        nop
        meh rax, rdi            ;2 bytes
        nop
        and rax, 7              ;4 bytes
        nop
        and eax, 7              ;3 bytes--nasm be idiot in prev. case, as these are eqv
        nop
        mov rax, 2 << 40
        and eax, 7
        ;; right, that works.

        ;; extension...

        %define FAKE_RDI rdi
        %define FAKE_RAX rax

        nop
        meh FAKE_RAX, FAKE_RDI
        nop
        ;; wow, ok, so that works...
        ;; excellent.
        
        ret
        