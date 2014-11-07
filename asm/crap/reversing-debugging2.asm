        ;; [semispaces.asm]

        %include "semispaces3.asm"

        ;; Now we will actually use a "nil".
        ;; Just for benchmarking purposes.
        ;; Also to get just a little idea of whether shit works properly.


        ;; So, at this point.
        ;; "return" is a label we can jump to, which restores stack shit.
        ;; In the meantime, we've consumed rdi, rsi, and rdx,
        ;; which contain mem, mem-len, and page-size,
        ;; and we have room for three more arguments.
        ;; rcx = mode.
        ;; r8 = x
        ;; r9 = y

        ;; Actually, now we take:
        ;; rcx = [handle][dlsym]
        ;; r8 = x
        ;; r9 = y

        ;; Ok, current program:
        ;; Make a list of length x, reverse it y times.

        ;; Partially redundant, but:
        ;; ... shall I have all registers, including rsp,
        ;; which it doesn't seem it would make sense to trace?
        ;; Sure, whatever.        
        

        jmp actual_code

        ;; Library shit...

        %include "gc-system8.asm"

        

        ;; Definitions for BS crap will appear here.
        ;; 'Cause macros need to be defined before you use them.

        VAR nil

handle: dq 0
dlsym:  dq 0

x:      dq 0
y:      dq 0

;; puts:   dq 0
;; puts_str:       db "puts", 0
        
actual_code:

        gc_header

        mov [x], r8
        mov [y], r9

        ;; We will use a narcissistic cons cell as nil.

        saving 0
        cons rdi
        scar rdi, rdi
        scdr rdi, rdi
        mov [nil], rdi


        mov rdi, [rcx]
        mov [handle], rdi
        mov rdi, [rcx + 8]
        mov [dlsym], rdi
        

        ;; Grab some functions.
        %macro sysfunc 1
        mov rdi, [handle]
        lea rsi, [%1_str]
        call [dlsym]
        mov [%1], rax
        jmp %%end               ;murderously terrible code organization, but oh well
        align 8
%1_str:
        %defstr %%nerf %1
        db %%nerf, 0
%1:     dq 0
%%end:
        %endmacro

        ;; It looks like we'll have to be careful to save r8 and r9 for the below.
        ;; [Or store them and use them somewhere else, but I'm not doing that.]

        ;; ... geez, everything?
        ;; I see
        ;; push rdi
        ;; push rsi
        ;; push rdx
        ;; push rcx
        push r8
        push r9

        ;; C calls destroy r10 and r11.
        ;; Currently r11 is FROMSPACEMASK.
        ;; So.

        ;; mov rdi, [handle]
        ;; lea rsi, [puts_str]
        ;; call [dlysm]
        ;; xor eax, eax
        ;; xor r10, r10
        ;; xor r11, r11
        ;; mov [puts], rax
        ;; jmp return

        ;; mov rax, [puts_str]
        ;; call [dlsym]
        ;; mov [puts], rax

        sysfunc puts
        sysfunc printf
        sysfunc getchar
        sysfunc putchar

        %ifnidn FROMSPACEMASK, [fromspace_mask]
        mov FROMSPACEMASK, [fromspace_mask]
        %endif

        pop r9
        pop r8
        ;; pop rcx
        ;; pop rdx
        ;; pop rsi
        ;; pop rdi

        ;; jmp return

        ;; xor edx, edx            ;in case...


        ;;First, cons up the initial list...

        ;;a = r8, b = r9

        ;; r8 = count
        shl r8, 3               ;tag

        ;; Testing:
        ;; neg r8

        ;; Will have: rdx = xs, rcx = ys
        mov rcx, [nil]

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

        ;; Let's also store that list in a place we won't touch till the end.
        push rcx


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

        push rcx

        ;; As I've discovered before: printf wants rax = 0.
        ;; ("al" = number of "vector" arguments, whatever the fuck -- System V ABI)
        
        lea rdi, [thing]
        mov rsi, [gc_flip_count]
        mov rdx, [moved_count]
        mov rcx, [bytes_moved]
        mov r8, [bytes_traced]
        mov r9, [work_count]
        push ALLOCPTR
        ;; xor eax, eax
        mov rax, 0
        call [printf]
        ;; not sure how to call more than 6 args; a naive attempt leads to segfault
        pop ALLOCPTR

        mov rdi, [tospace_top]
        sub rdi, [tospace_bottom]

        mov rax, [y]
        mov rcx, 16             ;conses are this big
        mul rcx
        mul qword [x]
        div rdi
        mov rsi, rax
        lea rdi, [dick]
        mov rax, 0
        call [printf]

        
        
        
        
        ;; mov rdi, 66
        ;; call [putchar]
        ;; mov rdi, 10
        ;; call [putchar]
        ;; lea rdi, [whatever]
        ;; sub rsp, 8
        ;; call [puts]
        ;; mov rax, 2
        
        ;; lea rdi, [thing]
        ;; mov rsi, 3
        ;; mov rdx, 5
        ;; mov rax, 0
        ;; call [printf]
        ;; ^ proper printf model
        
        ;; add rsp, 8
        

        pop rcx
        
        ;; ass
        cheap_cdr rax, rcx
        cheap_car rax, rax

        pop rdi
        cheap_car rsi, rdi
        add rax, rsi
        ;; mov rax, 999
        ;; mov rax, 932
        ;; mov rax, [memory_top]
        ;; sub rax, ALLOCPTR
        ;; mov rax, ALLOCPTR
        ;; sub rax, [tospace_bottom]
        
        jmp return

thing:  db "flips: %ld moved: %ld mbytes: %ld tbytes: %ld trace-ops: %ld alloc: %ld", 10, 0
thing2: db "alloc: %ld", 10, 0
whatever:       db "nerf", 10, 0
dick:   db "achtung %ld", 10, 0
        
        
        ;; Arg in rcx, dest in rdx, I suppose.
        ;; Garbage ftw.
        ;; No continuations.
        ;; Assume nonempty.
        ;; ... Use r8 as scratch, eh?
        ;; Ah, this runs into barrs.
        ;; ... Also must initialize rdx to 0, I suppose.
        ;; Might as well make it proper reverse.
reverse:
        mov rdx, [nil]
        cmp rcx, [nil]
        je plain_ret
reverse_loop:        
        ;; mov r8, [rcx - CONS_TAG] ;accualy is car, must operationalize...
        car r8, rcx
        saving RCX_MASK | RDX_MASK
        ;; saving 0
        ;; Now, for purposes of fucking shit up, we actually don't rely on that.
        ;; push rcx
        ;; push rdx
        cons rdi
        ;; pop rdx
        ;; pop rcx
        ;; jesus christ that slows down the program

        ;; unfortunately I don't see proof that this works, but...

        scar rdi, r8
        scdr rdi, rdx
        mov rdx, rdi

        ;; can I do this?
        ;; not in some places
        ;; cdr rcx, rcx
        ;; mov r13, rcx
        ;; cdr rcx, r13
        mov r10, rcx
        cdr rcx, r10
        
        cmp rcx, [nil]
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


        
        
        
