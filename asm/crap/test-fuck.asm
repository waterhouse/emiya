
        mov rax, 0xfffefafd


        jmp dick2
dick:
        mov rax, dick
        ret

        ;; NOPE
        ;; this is "mov rax, 0 0 0 0 0 0 0 0".
        ;;

        ;; is CALL really the only way to get the current address at runtime?
        ;; can't...
        ;; let's try the obvious.

dick2:
        ;; mov rax, rip ;nope, symbol 'rip' undefined
        ;; how about this LEA crap?
fuck:   
        ;; lea rax, [rip] ;nope, again, symbol 'rip' undefined.
        ;; the internets tell me this should be legal.
        ;; mov rax, $ ;nope
        lea rax, [rel fuck]     ;FINALLY, THERE WE GO
        ;; AND IT SUCKS TERRIBLY. NEED A SYMBOL EVERY TIME I WANT TO LOAD RIP.
        ;; OH WELL.

        dec rdi
        jnz dick2
        ret