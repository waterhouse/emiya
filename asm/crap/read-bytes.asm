

        mov rax, 0xfffefafd

        ;; ... goddammit, I need the system's "read" or else "dlopen"
        ;; ... ... ... eh...
        ;; nah

        ;; rdi = buf
        ;; rsi = n

        mov rdx, rsi            ;n
        mov rsi, rdi            ;buf
        mov rax, 0x2000003      ;oh man read
        xor edi, edi            ;fildes = stdin = 0
        syscall
        ret


        ;; ok, so, neither "fromstring" (as in "(fromstring "nerfnerf" (read))")
        ;; nor reading on the same line (as in "arc> (read)nerfnerf")
        ;; works in the same way as Racket "read".

        ;; mmm...
        ;; if I want to play around, then...
        ;; first, I'll have to figure out a way to pass dlopen and dlsym to asm stuff.
        ;; probably would do that with C.
        ;; second, memory... could use malloc crap, could use dicks passed in.
        ;; let's start with latter for Racket usability.
        ;; could kind of combine the two:
        ;; store addr/size pairs from malloc into a dick passed in, for Racket to free later
        ;; if desired.
        ;; mmm.
        ;; meanwhile... serializing, deserializing, stuff.
        ;; that should be "fun".
        ;; ... oh man, tracing.
        ;; hash table crap?
        ;; or "dump-lisp-and-die"? (overwriting seen dicks)
        ;; god. 'fraid it's gonna be the latter.
        ;; well.
        ;; seems like it is inherently a single-threaded
        ;; operation, tracing a graph of objects.
        ;; so I'll call this acceptable.
        ;; (still would be nice to un-die)
        ;; (probably pretty easily doable)