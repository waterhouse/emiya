        ;; [semispaces.asm]

        %include "semispaces2.asm"


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

        %include "gc-system3.asm"

        
plain_ret:      ret


        ;; Definitions for BS crap will appear here.
        ;; 'Cause macros need to be defined before you use them.







        
actual_code:




        ;; For the moment, car and cdr will just be noobish.
        %macro cheap_car 2
        mov %1, [%2 - CONS_TAG]
        %endmacro
        %macro cheap_cdr 2
        mov %1, [%2 - CONS_TAG + 8]
        %endmacro




        ;; Give names to the parameters.
        %define name lea
        ;; %define cons_rdi %2
        ;; %define car %3
        ;; %define cdr %4
        ;; Separate car and cdr?  Whatever.

name:   

        ;;First, cons up the initial list...

        ;;a = r8, b = r9

        ;; r8 = count
        shl r8, 3               ;tag

        ;; Testing:
        ;; neg r8

        ;; Will have: rdx = xs, rcx = ys
        mov rcx, 0

%[name]_loop:

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
        jnz %[name]_loop


        ;; rcx = list
        ;; now that's in reverse...
        ;; oh well, it ... shall it always be in reverse?
        ;; neh, let us reverse it.


        ;; Ok, so, this will simply reverse it a bunch of times.
        ;; r9 = reps
        cmp r9, 0
        je %[name]_done
%[name]_reversing_loop:
        call %[name]_reverse
        mov rcx, rdx
        dec r9
        jnz %[name]_reversing_loop
        ;; now return something at least vaguely meaningful
%[name]_done:
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
%[name]_reverse:
        mov rdx, 0
        cmp rcx, 0
        je plain_ret
%[name]_reverse_loop:        
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
        jne %[name]_reverse_loop
        ret


        

        ;; cmp rcx, 0
        ;; je lea_car4
        ;; cmp rcx, 2
        ;; je aside_car4
        ;; cmp rcx, 3
        ;; je aside_car5


        mov rax, 77
        jmp return



        ;; the_program lea, lea_cons_rdi, cheap_car, cheap_cdr
        ;; the_program subrout, subrout_cons_rdi, cheap_car, cheap_cdr
        ;; the_program aside, aside_cons_rdi, cheap_car, cheap_cdr
        
        ;; the_program noob, reckless_cons_rdi, cheap_car, cheap_cdr

        ;; the_program lea_1, lea_cons_rdi, car_barr_tck, cdr_barr_tck
        ;; the_program lea_2, lea_cons_rdi, car_barr_tck_2, cdr_barr_tck_2

        ;; the_program aside_1, aside_cons_rdi, car_barr_tck, cdr_barr_tck
        ;; the_program aside_2, aside_cons_rdi, car_barr_tck_2, cdr_barr_tck_2

        ;; arc> (pbcopy:tostring:each x '(lea aside) (for i 1 9 (prn "        the_program " x "_car" i ", " x "_cons_rdi, car_" i ", cdr_" i)))

        ;; the_program lea_car4, lea_cons_rdi, car_4, cdr_4

        ;; the_program aside_car4, aside_cons_rdi, car_4, cdr_4
        ;; the_program aside_car5, aside_cons_rdi, car_5, cdr_5


        ;; Ok, that seemed to work.
        ;; Moar.


rejected:
        mov rax, 981
        jmp return


        ;; Testing with:
;; arc> (do (ga full-malloc-testing5 6) (each h (join ([mappend list _ _] (range 4 25)) (range 8 25)) (gc) (sleep .5) (withs f (fn (x y z m u v) (pr (pad h 2) " ") (call-asm full-malloc-testing5 x y z m u v)) n (* 1000 (expt 2 20)) b make-bytes.n (time:do (pr (f b n 4096 h 1000 200000) " ")))))
        ;; Also try diff. memory sizes.
        ;; Currently, 11 is the winner, 12 and 20 are nearly as good, 15 is a bit better than both, 24 and 8 are next, then 16 and 21 and 25,
        ;; then 13 and 17, then 22, then then 10 and 23, and 9 and 14 and 18 and 19 are suck.
        ;; Test Alvin next.

        ;; Well, that's a surprise.
        ;; On Alvin, they all took about 1750 msec for the 400 MB setup and about 1940 msec (+/- 20 or so) for
        ;; the 20 MB setup.
        ;; I gather that it's memory-bound on Alvin...

        ;; And, with negative numbers, 15, 16, 24, and 25 get destroyed.
        ;; Other rankings are probably similar.
        ;; In particular, 11 remains the winner.
        ;; So.
        ;; Regarding 11.
        ;; I don't really like the fact that you'll need a bunch of stubs for car and cdr barriers.
        ;; On the other hand, pluses are that it doesn't use many registers,
        ;; and that the destination can be rax [I think].
        ;; Dest and src have to be different, though (or else the barrier doesn't work).
        ;; Meanwhile... As mentioned, 12 is nearly as good, so I could use that if necessary.
        ;; Also, the "aside" aspect... eh.
        ;; Meanwhile, I can easily write a macro that can do "cdr x, x" things that tests
        ;; whether %1 = %2, and if so, cdrs into something else and stores it back into x.
        ;; The something else ... rax?  --Yes, I think that would work...

        





        


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


        
        
        
