

        mov rax, 0xfffefafd


        %define MEH 0b1000
        %define ACHTUNG 0b100000

        mov rax, MEH | ACHTUNG
        ret

        