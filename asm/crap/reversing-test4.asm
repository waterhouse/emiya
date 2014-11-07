        ;; [semispaces.asm]

        %include "semispaces3.asm"

        ;; We are going to stupidly push some shit onto the stack.
        ;; This will motivate us to 


        ;; So, at this point.
        ;; "return" is a label we can jump to, which restores stack shit.
        ;; In the meantime, we've consumed rdi, rsi, and rdx,
        ;; which contain mem, mem-len, and page-size,
        ;; and we have room for three more arguments.
        ;; rcx = mode.
        ;; r8 = x
        ;; r9 = y

        ;; Ok, current program:
        ;; Make a list of length x, reverse it y times.
        ;; Fuckin' ass.

        ;; Partially redundant, but:
        ;; ... shall I have all registers, including rsp,
        ;; which it doesn't seem it would make sense to trace?
        ;; Sure, whatever.        
        

        jmp actual_code

        ;; Library shit...

        %include "gc-system5.asm"

        

        ;; Definitions for BS crap will appear here.
        ;; 'Cause macros need to be defined before you use them.


        
actual_code:

        gc_header





        ;;First, cons up the initial list...

        ;;a = r8, b = r9

        ;; r8 = count
        shl r8, 3               ;tag

        ;; Testing:
        ;; neg r8

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


        
        
        
