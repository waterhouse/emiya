




        %ifdef LINUX
        mov rax, 3
        %elifdef DARWIN
        mov rax, 4
        %else                   ;POSIX
        mov rax, 2
        %endif

        






        
