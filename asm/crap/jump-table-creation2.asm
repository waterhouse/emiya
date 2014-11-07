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
        
        %macro jump_table 2
        %assign jump_table_count jump_table_count+1

        %define jump_table_%[jump_table_count]_name %1
        %define jump_table_%[jump_table_count]_size %2
        
        %endmacro

        
        %macro case 2
        ;; let's find out if the below works
        ;; if not, I think I can kludge around it
        %define jump_table_%[jump_table_count]_%1 %2
        %endmacro

        ;; lea rax, [dickass]
        ;; ret
        ;; db 99, 99, 99

        call startup

        ;; ret

        and rdi, 3

        ;; ret
        
        lea rax, [dickass]
        ;; mov rax, [rax + 8*rdi]
        ;; lea rcx, [rax + 8*rdi]
        ret
        ;; ret
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


startup:
        

        %define i 0
        %rep jump_table_count
        %assign i i+1

        %define j 0
        %rep jump_table_%[i]_size
        ;; j is used in a 0-indexed way; incr. at bottom
        lea rax, [jump_table_%[i]_%[j]]
        mov [jump_table_%[i]_name + ((j-1)*8)], rax
        %assign j j+1
        %endrep

        %endrep

        ret
        

        
