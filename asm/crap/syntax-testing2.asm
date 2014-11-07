

        ;; nasm -E shows macroexpanded output. useful.

        ;; now we abuse the system thoroughly.

        %define n 1

        %macro using 1
        %define dick %1_%[n]
        %assign n n+1
        %endmacro

        using rbx
        using rbp

        %macro dickify 1
        %define meh_%[n] mov [rel storage_%[n]], %[dick]
        mov rax, %1
        mov rax, 3

        %undef dick
        %endmacro



        using rcx
        dickify rdx
        using rsi
        dickify rdi
        


        %define i 1
        %rep n
        storage_%[i]: dq 0
        %assign i i+1
        %endrep


        %define i 1
        %rep n
        meh_%[i]
        

        %assign i i+1
        %endrep
        
        



        
