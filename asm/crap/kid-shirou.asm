

        ;; Drill.
        ;; We practice having a C program find us, load us into an
        ;; executable (and writable--I'll need that) region of memory,
        ;; and pass us dlopen and dlsym.

        mov rax, 0xfffefafd


        ;; rdi = dlopen
        ;; rsi = dlsym

        mov r15, rsi
        mov r14, rdi

        ;; dlopen(path, mode).
        ;; the "mode" should be ...
        ;; probably should be RTLD_LAZY and RTLD_GLOBAL,
        ;; but at least on OS X, those are default,
        ;; so

        DEFAULT REL

        lea rdi, [libsystem_path]
        xor esi, esi
        ;; xor eax, eax            ;I think you sorta have to do this to say "no vec
        call r14                ; arguments on stack"... at least for n-ary funcs.
                                ;Which this is not. Mmmph. Ok, nvm. 

        ;; now rax = a stupid handle
        mov r13, rax

        ;; now we want to dlsym ... getchar and printf.
        
        mov rdi, rax
        lea rsi, [printf_name]
        call r15

        mov r12, rax

        mov rdi, r13
        lea rsi, [getchar_name]
        call r15

        ;; ...
        ;; at this point we don't need dlopen anymore (actually earlier),
        ;; so let us overwrite it.
        ;; [Can't be bothered to store this crap in memory.]

        mov r14, rax

        ;; so: r12 = printf, r14 = getchar

        mov rbx, 10

loop:
        call r14
        lea rdi, [printf_string]
        mov rsi, rax
        mov rdx, rax
        mov rcx, rax
        xor eax, eax            ;printf will object to ass
        ;; ... do I need to align the stack or something?
        ;; me don't really think so.
        ;; at any rate I haven't changed the stack, though.
        ;; and it was probably aligned at the start.
        ;; so.
        call r12
        dec rbx
        jnz loop
        ret

        
        
        







libsystem_path:
        db "/usr/lib/libSystem.dylib", 0

printf_name:
        db "printf", 0

getchar_name:
        db "getchar", 0

printf_string:
        db "Lelz that character is %c or %d or %x", 10, 0
        

        
        







        