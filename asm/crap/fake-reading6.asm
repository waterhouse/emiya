

        %include "semispaces4.asm"

        jmp actual_code

        %include "gc-system14.asm" ;now we save things differently

        ;; So, at this point.
        ;; "return" is a label we can jump to, which restores stack shit.
        ;; In the meantime, we've consumed rdi, rsi, rdx, and rcx,
        ;; which contain mem, mem-len, page-size, and [handle][dlsym],
        ;; and we have room for two more arguments.
        ;; r8 = x
        ;; r9 = y

        ;; cleanup [kind of]
        
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
        ;; This should soon become making a sym.

        saving 0
        cons rdi
        scar rdi, rdi
        scdr rdi, rdi
        mov [nil], rdi


  
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
        
        ;; mov rax, 1717
        ;; jmp return

        %macro char 2
        mov %1, %2
        shl %1, 3
        add %1, CHAR_TAG
        %endmacro

        ;; Ok, it appears that getchar, after it gets one ^D/EOF, returns EOF
        ;; ever thereafter.
        ;; This doesn't appear to be rlwrap's fault; it happens without rlwrap.
        ;; In that case, I should probably use my own getchar and whatever.
        ;; Implement it using read and a buffer.
        ;; Sigh, probably don't want to bother implementing byte-buffers in the GC system yet...
        ;; So.
        ;; Probably regular data.

        ;; certain dicks will take args and produce results in rbp


        ;; Ok, so.
        ;; We read a space-separated list of words, terminated by a newline.
        ;; Then we print it out.
        ;; Um, we represent words as fake symbols...
        ;; 


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
        saving rbp
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
        call rev_chars_to_sym
        ;; that takes arg in rbp and returns in rbp
        
        ;; now push onto list
        saving rbp
        cons rdi
        mov rax, [rsp]
        scar rdi, rbp
        scdr rdi, rax
        mov [rsp], rdi
        jmp nonword

last_word:
        ;; similar to above
        inc qword [words]
        ;; now we have a subroutine
        call rev_chars_to_sym   ;value in rbp
        
        saving rbp
        cons rdi
        ;; we'll go through the effort of putting it onto the stack
        ;; so that someone else can jump directly to "done"
        mov rax, [rsp]
        scdr rdi, rax
        scar rdi, rbp
        mov [rsp], rdi
done:
        lea rdi, [two]
        mov rsi, [letters]
        mov rdx, [words]
        mov rax, 0
        call [printf]
        
        pop rbp
        call reverse_rbp
        ;; now we print it out

        mov rdi, '('
        call [putchar]
printing:
        
        cmp rbp, [nil]
        je printing_done
        ;; print_sym will use rbp
        cdr rdi, rbp
        push rdi
        car rbp, rbp            ;beheheh
        call print_sym
        pop rbp
        

        
        ;; and now... heh, there's a point in duplicate testing code
        cmp rbp, [nil]
        je printing_done
        mov rdi, ' '
        call [putchar]
        ;; we'll lazily not create another label and cause the test to be run twice
        jmp printing

print_sym:
        sym_name rbp, rbp
        
print_sym_loop: 
        cmp rbp, [nil]
        je plain_ret
        car rdi, rbp

        ;; now remember it's a tagged char; we need to untag it.
        shr rdi, 3
        call [putchar]
        
        cdr rbp, rbp
        jmp print_sym_loop           ;nice and terse ;wait ;not quite anymore

printing_done:
        mov rdi, ')'
        call [putchar]
        mov rdi, `\n`
        call [putchar]
        jmp return

        ;; arg in rbp
        ;; ret in rbp
rev_chars_to_sym:
        call reverse_rbp
        ;; arg in rbp
chars_to_sym:
        saving rbp
        sym rsi
        mov qword [rsi - SYM_TAG], 0 ;value
        mov [rsi - SYM_TAG + 8], rbp ;name
        mov qword [rsi - SYM_TAG + 16], 0  ;hash
        ;; ret in rbp
        mov rbp, rsi
        ret


reverse_rbp:
        mov rcx, [nil]
        cmp rbp, [nil]
        je plain_ret
reverse_rbp_loop:       
        car rsi, rbp
        cdr rbp, rbp            ;supported behavior
        saving rbp, rsi, rcx
        cons rdi
        scar rdi, rsi
        scdr rdi, rcx
        mov rcx, rdi
        cmp rbp, [nil]
        jne reverse_rbp_loop
        mov rbp, rcx
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

        





        
        

        
