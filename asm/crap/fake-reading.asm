        ;; [semispaces.asm]

        %include "semispaces3.asm"

        jmp actual_code

        ;; Library shit...

        %include "gc-system4.asm"

        ;; Conveniently, I can use a buffer that's outside the GC...
        ;; [for now, I'm being completely terrible]
buf:    dq 0
buflen: dq 0        

handle: dq 0
dlsym:  dq 0
read:   dq 0
write:  dq 0
getchar: dq 0
putchar:     dq 0   


read_str:       db "read", 0
write_str:      db "write", 0
getchar_str:    db "getchar", 0
putchar_str:    db "putchar", 0

        
actual_code:
        gc_header
        
        ;; Ok, so, semispaces expects rdi = buffer, rsi = buflen, rdx = pagelen.
        ;; Which means...
        ;; I can have the handle-dlsym buffer be rcx,
        ;; and the reading buffer-len pair in r8 and r9.

        ;; It appears that Unix guarantees that EOF is an "int" (32-bit) that
        ;; is negative.
        ;; I'm just going to assume that getchar always returns something nonnegative
        ;; if it's not EOF.


        mov [buf], r8
        mov [buflen], r9
        mov rax, [rcx]
        mov [handle], rax
        mov rax, [rcx + 8]
        mov [dlsym], rax

        ;; could write macro for these
        mov rdi, [handle]
        lea rsi, [read_str]
        call [dlsym]
        mov [read], rax
        
        mov rdi, [handle]
        lea rsi, [write_str]
        call [dlsym]
        mov [write], rax

        mov rdi, [handle]
        lea rsi, [getchar_str]
        call [dlsym]
        mov [getchar], rax

        mov rdi, [handle]
        lea rsi, [putchar_str]
        call [dlsym]
        mov [putchar], rax        



        ;; Ok, so.
        ;; We will read some 




        ;; Will have: rdx = xs, rcx = ys
        mov rcx, 0

loop:

        saving RCX_MASK | RDX_MASK
        cons rdi

        ;; cons_rdi                ;may kill rax
        ;; mov [rdi - CONS_TAG], r8 ;scar
        ;; mov [rdi - CONS_TAG + 8], rcx ;scdr
        scar rdi, r8
        scdr rdi, rcx
        mov rcx, rdi
        

        ;; inc r8
        ;; cmp r8, r9
        ;; jb %[name]_loop

        ;; dec r8
        sub r8, 8
        ;; add r8, 8
        jnz loop


        ;; rcx = list
        ;; now that's in reverse...
        ;; oh well, it ... shall it always be in reverse?
        ;; neh, let us reverse it.


        ;; Ok, so, this will simply reverse it a bunch of times.
        ;; r9 = reps
        cmp r9, 0
        je done
reversing_loop:
        call reverse
        mov rcx, rdx
        dec r9
        jnz reversing_loop
        ;; now return something at least vaguely meaningful
done:
        ;; ass
        cheap_cdr rax, rcx
        cheap_car rax, rax
        ;; mov rax, 999
        ;; mov rax, 932
        ;; mov rax, [memory_top]
        ;; sub rax, ALLOCPTR
        ;; mov rax, ALLOCPTR
        ;; sub rax, [tospace_bottom]
        
        jmp return
        
        
        ;; Arg in rcx, dest in rdx, I suppose.
        ;; Garbage ftw.
        ;; No continuations.
        ;; Assume nonempty.
        ;; ... Use r8 as scratch, eh?
        ;; Ah, this runs into barrs.
        ;; ... Also must initialize rdx to 0, I suppose.
        ;; Might as well make it proper reverse.
reverse:
        mov rdx, 0
        cmp rcx, 0
        je plain_ret
reverse_loop:        
        ;; mov r8, [rcx - CONS_TAG] ;accualy is car, must operationalize...
        car r8, rcx
        saving RCX_MASK | RDX_MASK
        cons rdi
        ;; cons_rdi
        ;; imul r8, r8
        scar rdi, r8
        scdr rdi, rdx
        mov rdx, rdi

        ;; can I do this?
        ;; not in some places
        ;; cdr rcx, rcx
        mov r13, rcx
        cdr rcx, r13
        
        cmp rcx, 0
        jne reverse_loop
        ret


        



        mov rax, 77
        jmp return




        ;; Ok, that seemed to work.
        ;; Moar.


rejected:
        mov rax, 981
        jmp return



        

        ;; BELOW IS UNRELATED SHIT


        ;; Optimizations:
        ;; - 8-bit registers
        ;; -

        ;; Probably requires a scratch register.
        ;; Let's have dest be first argument, src be second.
        ;; ... Issues ...
        ;; Fuck, whatever.
        ;; ... Can have a "skip over" jump thing,
        ;; or can require a stub,
        ;; or can use "lea rax" shit.
        ;; Since already probably destroying rax as a scratch...
        ;; (Could make some dicks that use ... k.)

        

        
        ;; that'll demand up to sixteen little stubs.
        ;; but that's ok
        ;; ['cause the balance of power's maintained that way]
        ;; could insert a check ("%ifidn") for shit being rax.
        ;; could drop the "lea rax" if I was willing to have up to 15*14 little stubs.
        ;; (though most wouldn't be used)
        ;; actually, I have an idea for automatically generating stubs, involving heavy use of macros
        ;; (generate a bunch of macros that are either "do nothing" or "ifidn x y, do nothing, else do z"
        ;;  and then have things that use the stub either redefine the macro or redefine x to something new
        ;;  and have the "do z" part define the stub, and auto-execute all those macros at the end)
        

        gc_footer


        
        
        
