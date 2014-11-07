        default rel

        ;; How do I ensure alignment?
        ;; Right.
        
        align 8
        nop
        nop
        nop
        mov rax, 0xfffefafd
        align 8                 ;Should code for nothing.

        
        %define jump_table_count 0

        ;; name, size, default.
        %macro jump_table 2-3
        %assign jump_table_count jump_table_count+1

        %define jump_table_%[jump_table_count]_name %1
        %define jump_table_%[jump_table_count]_size %2
        ;; if default is unspecified, all cases must be specified or you'll get an
        ;; assembly-time error.
        %if %0 > 2
        %define j 0
        %rep %2
        %define jump_table_%[jump_table_count]_%[j] %3
        %assign j j+1
        %endrep
        %endif
        
        %endmacro

        %macro case 2
        %define jump_table_%[jump_table_count]_%1 %2
        %endmacro

        call startup

        and rdi, 3
        lea rax, [dickass]
        jmp [rax + 8*rdi]

        ;; You idiot, you'd been making unintentionally self-modifying code.
        
        ;; Let's see.
        ;; It's possible--likely--that I'll define a table in one place
        ;; and use it in multiple other places.
        ;;

        %define ACCUALY_ONE 1

        ;; Oh, right, you need commas...

        jump_table dickass, 4
        case ACCUALY_ONE, fuck
        case 0, jerk
        case 2, idiot
        case 3, suck

        jump_table nerf, 4, jerk
        case 0, fuck
        case 1, fuck

        
        align 8
the_tables:

        %define i 0
        %rep jump_table_count
        %assign i i+1
jump_table_%[i]_name:
        %rep jump_table_%[i]_size
        dq 0
        %endrep
        %endrep

        ;; there really should be a big aligned section of the program
        ;; anyway


fuck:
        mov rax, 33
        ret
jerk:
        mov rax, 66
        ret
idiot:
        mov rax, 99
        ret
suck:
        mov rax, 9001
        ret


jump_table_unspecified:
        mov rax, 883344
        ;; jmp return ;in other places
        ret


startup:
        

        %define i 0
        %rep jump_table_count
        %assign i i+1

        %define j 0
        %rep jump_table_%[i]_size
        ;; j is used in a 0-indexed way; incr. at bottom
        lea rax, [jump_table_%[i]_%[j]]
        mov [jump_table_%[i]_name + (j*8)], rax
        %assign j j+1
        %endrep

        %endrep

        ret
        

        
