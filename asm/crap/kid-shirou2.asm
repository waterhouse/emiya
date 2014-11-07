

        ;; Drill.
        ;; We practice having a C program find us, load us into an
        ;; executable (and writable--I'll need that) region of memory,
        ;; and pass us dlopen and dlsym.

        mov rax, 0xfffefafd

        DEFAULT REL

        ;; rdi = dlopen
        ;; rsi = dlsym

        mov [dlopen_place], rdi
        mov [dlsym_place], rsi

        ;; dlopen(path, mode).
        ;; the "mode" should be ...
        ;; probably should be RTLD_LAZY and RTLD_GLOBAL,
        ;; but at least on OS X, those are default,
        ;; so


        lea rdi, [libsystem_path]
        xor esi, esi
        ;; xor eax, eax            ;I think you sorta have to do this to say "no vec
        call [dlopen_place]        ; arguments on stack"... at least for n-ary funcs.
                                   ;Which this is not. Mmmph. Ok, nvm. 

        ;; now rax = a stupid handle
        mov [handle_place], rax

        ;; now we want to dlsym ... getchar and printf.
        
        mov rdi, rax
        lea rsi, [printf_name]
        call [dlsym_place]

        mov [printf_place], rax

        mov rdi, [handle_place]
        lea rsi, [getchar_name]
        call [dlsym_place]

        ;; ...
        ;; at this point we don't need dlopen anymore (actually earlier),
        ;; so let us overwrite it.
        ;; [Can't be bothered to store this crap in memory.]
        ;; Actually are now storing this crap in memory.  Not on stack.

        mov [getchar_place], rax

        mov rbx, 10

loop:
        call [getchar_place]
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
        call [printf_place]
        dec rbx
        jnz loop
        ret


dlopen_place:   resq 1
dlsym_place:    resq 1
handle_place:   resq 1
printf_place:   resq 1
getchar_place:  resq 1

        ;; ok, the fuckin' assembler warns that the above things
        ;; are uninitialized.
        ;; yep, that be the point.
        ;; I suppose I could "dq 0" instead...


libsystem_path:
        db "/usr/lib/libSystem.dylib", 0

printf_name:
        db "printf", 0

getchar_name:
        db "getchar", 0

printf_string:
        db "Lelz that character is %c or %d or %x", 10, 0
        

        
        







        