

        %include "semispaces4.asm"

        jmp actual_code

        %include "gc-system13.asm"

        ;; So, at this point.
        ;; "return" is a label we can jump to, which restores stack shit.
        ;; In the meantime, we've consumed rdi, rsi, rdx, and rcx,
        ;; which contain mem, mem-len, page-size, and [handle][dlsym],
        ;; and we have room for two more arguments.
        ;; r8 = x
        ;; r9 = y
        
        VAR nil


x:      dq 0
y:      dq 0
errno_addr:  dq 0

        %define DUMB_BUFFER_SIZE 256

dumb_buffer:
        %rep DUMB_BUFFER_SIZE
        db 0
        %endrep
dumb_ptr:
        dq 0
dumb_limit:
        dq 0
        ;; these things are totally not multithreaded

fake_getchar:
        mov rdi, [dumb_ptr]
        cmp rdi, [dumb_limit]
        je fake_getchar_more
        ;; return in rax
        xor eax, eax
        mov al, [rdi]
        add qword [dumb_ptr], 1
        ret
        
        
fake_getchar_more:
        lea rsi, [dumb_buffer]
        mov [dumb_ptr], rsi
        mov [dumb_limit], rsi
        mov rdi, 0              ;stdin
        mov rdx, DUMB_BUFFER_SIZE
        call [read]
        ;; len or error in rax
        cmp rax, 0
        jle fake_getchar_eof
        add [dumb_limit], rax
        xor eax, eax
        mov rdi, [dumb_ptr]
        mov al, [rdi]
        add qword [dumb_ptr], 1
        ret

fake_getchar_eof:
        ;; for compatibility, return -1
        mov rax, -1
        ret
        
        

        NONGC_VAR letters
        NONGC_VAR words
        
actual_code:

        gc_header

        

        lea rax, [dumb_buffer]
        mov [dumb_ptr], rax
        mov [dumb_limit], rax

        mov [x], r8
        mov [y], r9

        sysfunc __error
        sysfunc read

        call [__error]
        mov [errno_addr], rax

        ;; We will use a narcissistic cons cell as nil.

        saving 0
        cons rdi
        scar rdi, rdi
        scdr rdi, rdi
        mov [nil], rdi


        ;; Geez, this isn't working.
        ;; Time to just dick things around.
        ;; Oh, wait.
        ;; They're still tagged chars.
        ;; Need to untag them.

;;         mov rbp, [nil]
;; loop:

        ;; Let's print a newline before starting.
        mov rdi, `\n`
        call [putchar]

        ;; Ok, I don't know what the fuck is happening, so.

        ;; %rep 10
        ;; ;; call [getchar]
        ;; call fake_getchar
        ;; lea rdi, [number]
        ;; mov rsi, rax
        ;; mov rax, 0
        ;; call [printf]
        ;; %endrep

        ;; lea rdi, [number]
        ;; mov rsi, [errno_addr]
        ;; mov rsi, [rsi]
        ;; mov rax, 0
        ;; call [printf]
        
        ;; mov rax, 1717
        ;; jmp return

        ;; Ok, that works exactly as it should.
        ;; Welp.

        ;; Ok, test moar.

        %macro char 2
        mov %1, %2
        shl %1, 3
        add %1, CHAR_TAG
        %endmacro

        saving 0
        cons rdi
        mov rsi, [nil]
        scdr rdi, rsi
        char rax, 'a'
        scar rdi, rax
        
        saving RDI_MASK
        cons rsi
        scdr rsi, rdi
        char rax, 'b'
        scar rsi, rax
        saving RSI_MASK
        cons rdi
        scdr rdi, rsi
        char rax, 'c'
        scar rdi, rax

        ;; mov rbp, rdi

        ;; call print_sym

        ;; mov rdi, `\n`
        ;; call [putchar]
        ;; jmp return

        ;; That works, now...
        

        ;; saving RDI_MASK
        ;; cons rsi
        ;; mov rax, [nil]
        ;; scdr rsi, rax
        ;; scar rsi, rdi

        ;; mov rbp, rsi
        ;; push rbp
        ;; call done
        ;; jmp return              ;probably won't happen

        ;; Doesn't work.
        ;; So.
        ;; Perhaps the reverse is wrong.
        ;; mov rbp, rdi
        ;; call reverse_rbp
        ;; mov rbp, rcx
        ;; call print_sym
        ;; mov rdi, `\n`
        ;; call [putchar]
        ;; jmp return
        ;; Indeed, it is wrong.
        ;; Well, let's see.

        ;; Ok, probably fixed now.

        ;; Ok, now the initial test is always delivering EOFs.
        ;; Why?
        ;; Maybe 'cause I'd ^D'd earlier?
        ;; This really shouldn't happen.
        ;; I'll see what I can do.

        ;; Ok, it appears that getchar, after it gets one ^D/EOF, returns EOF
        ;; ever thereafter.
        ;; This doesn't appear to be rlwrap's fault; it happens without rlwrap.
        ;; In that case, I should probably use my own getchar and whatever.
        ;; Implement it using read and a buffer.
        ;; Sigh, probably don't want to bother implementing byte-buffers in the GC system yet...
        ;; So.
        ;; Probably regular data.

        ;; Ok, it seems to work now.
        ;; Back to actual shit.

        ;; OH MAN BRETTY GOOD NOW
        ;; next I guess we can convert to a fake symbol representation
        


        ;; Ok, so.
        ;; We read a space-separated list of words, terminated by a newline.
        ;; Then we print it out.
        ;; Um, we represent words as fake symbols...
        ;; 

        ;; mov rcx, [nil]

        ;; We shall use ... rbp to hold the whole list,
        ;; and .........
        ;; r12 still used for PAGELIMIT.... eh...
        ;; fine.
        ;; shall use rbp to hold the character lists,
        ;; and a thing on the stack to hold the things.

        ;; I could use the XLAT instruction with rbx, but that's currently ALLOCPTR.
        ;; So screw that.

        ;; --geez, it turns I can push memory operands.
        ;; bretty good.

        push qword [nil]

nonword:
        call fake_getchar
        ;; EOF known to be a negative int

        ;; push rax
        ;; lea rdi, [number]
        ;; mov rsi, rax
        ;; mov rax, 0
        ;; call [printf]
        ;; pop rax
        
        cmp eax, 0
        jl fuck_eof
        cmp al, `\n`
        je done
        cmp al, ' '
        je nonword
        ;; otherwise it's part of a word
        inc qword [letters]
        mov rbp, [nil]
        ;; cons onto rbp
        ;; oh, you idiot, cons may destroy rax.
        ;; --actually, it probably doesn't until shit has been alloced.
add_to_word:      
        saving RBP_MASK
        cons rdi
        shl rax, 3
        add rax, CHAR_TAG       ;could be "or al"
        scar rdi, rax
        scdr rdi, rbp
        mov rbp, rdi
midword:
        call fake_getchar
        cmp eax, 0
        jl fuck_eof
        cmp al, ' '
        je midword_dick
        cmp al, `\n`
        je last_word
        inc qword [letters]
        
        ;; cons onto the thing
        ;; actually I can avoid duplicating code
        jmp add_to_word
                
midword_dick:   
        ;; we've completed a word.
        inc qword [words]
        ;; now we make a "symbol" out of it, and put it onto the [rsp] list.
        ;; first:
        call reverse_rbp        ;returns value in rcx
        ;; now push onto list
        saving RCX_MASK
        cons rdi
        mov rax, [rsp]
        scar rdi, rcx
        scdr rdi, rax
        mov [rsp], rdi
        jmp nonword

last_word:
        ;; similar to above
        inc qword [words]
        call reverse_rbp        ;value in rcx
        ;; push onto list
        saving RCX_MASK
        cons rdi
        ;; we'll go through the effort of putting it onto the stack
        ;; so that someone else can jump directly to "done"
        mov rax, [rsp]
        scdr rdi, rax
        ;; scar rdi, rbp ;dumb idiot
        scar rdi, rcx
        ;; mov [rsp], rax
        mov [rsp], rdi
done:
        lea rdi, [two]
        mov rsi, [letters]
        mov rdx, [words]
        mov rax, 0
        call [printf]
        
        ;; ;; mov rax, [rsp]
        ;; pop rax                 ;nicer
        ;; scar rdi, rcx
        ;; scdr rdi, rax
        ;; and now, the list of symbols is actually in reverse order

        pop rbp
        call reverse_rbp        ;value in rcx
        ;; now we print it out
        ;; let's put the list into a saved register
        mov rbp, rcx

        mov rdi, '('
        call [putchar]
printing:
        lea rdi, [two]
        mov rsi, rbp
        mov rdx, [nil]
        mov rax, 0
        ;; call [printf]

        
        cmp rbp, [nil]
        je printing_done
        ;; print_sym will use rbp
        cdr rdi, rbp
        push rdi
        car rbp, rbp            ;beheheh
        call print_sym
        pop rbp
        
        lea rdi, [two]
        mov rsi, rbp
        mov rdx, [nil]
        mov rax, 0
        ;; call [printf]

        
        ;; and now... heh, there's a point in duplicate testing code
        cmp rbp, [nil]
        je printing_done
        mov rdi, ' '
        call [putchar]
        ;; we'll lazily not create another label and cause the test to be run twice
        jmp printing

buec:   db "print_sym %ld", 10, 0
        
print_sym:
        lea rdi, [buec]
        mov rsi, rbp
        mov rax, 0
        ;; call [printf]
        
        cmp rbp, [nil]
        je plain_ret
        car rdi, rbp
        ;; now remember it's a tagged char; we need to untag it.
        shr rdi, 3
        call [putchar]
        ;; just to be sure
        lea rdi, [number]
        car rsi, rbp
        shr rsi, 3
        mov rax, 0
        ;; call [printf]
        
        cdr rbp, rbp
        jmp print_sym           ;nice and terse ;wait

printing_done:
        mov rdi, ')'
        call [putchar]
        mov rdi, `\n`
        call [putchar]
        jmp return


reverse_rbp:
        mov rcx, [nil]
        cmp rbp, [nil]
        je plain_ret
reverse_rbp_loop:       
        car rsi, rbp
        cdr rbp, rbp            ;newly supported behavior
        saving RBP_MASK | RSI_MASK | RCX_MASK ;though rsi should always hold a char
        cons rdi
        ;; scdr rdi, rsi ;YOU FUCKING IDIOT, IT'S CAR
        scar rdi, rsi
        scdr rdi, rcx
        mov rcx, rdi
        cmp rbp, [nil]
        jne reverse_rbp_loop
        ret

number: db "%ld", 10, 0
two:    db "%ld %ld", 10, 0

bad_input:
        mov rax, 7343
        jmp return

fuck_eof:
        mov rax, 999
        jmp return



        gc_footer

        





        
        

        
