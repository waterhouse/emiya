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

        

        jmp actual_code
plain_ret:      ret


        ;; Definitions for BS crap will appear here.
        ;; 'Cause macros need to be defined before you use them.


        ;; DESTROYS RAX
        %macro lea_cons_rdi 0
        lea rdi, [ALLOCPTR + CONS_TAG]
        add ALLOCPTR, 16
        cmp ALLOCPTR, PAGELIMIT
        lea rax, [%%lea_cons_done]
        jg lea_overflow         ;g; if alloc is at limit, then that's fine; next alloc is win
%%lea_cons_done:
        %endmacro


lea_overflow:
        ;; I guess we look at the difference between ALLOCPTR and rdi
        ;; and deduce the desired malloc size.
        push rax                ;will RET later, lel
        ;; rax is now scratch
        ;; rdi may be tagged now.
        ;; we'll likely do gc work.
        ;; use rsi for extra scratch.
        push rsi
        mov rax, ALLOCPTR
        sub rax, rdi            ;size - tag: btwn size-7 and size
        add rax, 7              ;btwn size and size+7
        and rax, -8             ;size
        and rdi, 7              ;tag
        
        ;; in fact, we have to grab more memory before we do gc work
        ;; the below code is encumbered by the assumption that PAGELIMIT is a memory operand
        mov ALLOCPTR, PAGELIMIT
        mov rsi, [page_size]
        add rsi, ALLOCPTR
        cmp rsi, [tospace_top]  ;would be a GC flip, or would die if both need gc flip and gc work
        jg epic_failure
        mov PAGELIMIT, rsi
        ;; now we "do gc work"
        ;; [might have to save rdi and whatever]
        ;; [btw, tag and size could be stored in same register, bwahaha]
        nop
        ;; now we do the allocation
        add rdi, ALLOCPTR            ;OR would also work
        add ALLOCPTR, rax
        
        pop rsi
        ret                     ;bwahaha
        
epic_failure:
        mov rax, 69        
        jmp return
        

subrout_cons_rdi_overflow:
        mov ALLOCPTR, PAGELIMIT
        mov rdi, [page_size]
        add rdi, ALLOCPTR
        cmp rdi, [tospace_top]
        jg epic_failure         ;same stack layout
        mov PAGELIMIT, rdi

subrout_cons_rdi_code:
        lea rdi, [ALLOCPTR + CONS_TAG]
        add ALLOCPTR, 16
        cmp ALLOCPTR, PAGELIMIT             ;"page" limit
        jg subrout_cons_rdi_overflow
        ret

        %macro subrout_cons_rdi 0
        call subrout_cons_rdi_code
        %endmacro


        
        ;; as in "Look Aside" [nope]
        ;; having the usual code involve a jump
        %macro aside_cons_rdi 0
        lea rdi, [ALLOCPTR + CONS_TAG]
        add ALLOCPTR, 16
        cmp ALLOCPTR, PAGELIMIT
        jng %%k
        call subrout_cons_rdi_overflow
%%k:    
        %endmacro



ignominious_failure:
        mov rax, 88
        jmp return


        ;; May destroy rax.
        ;; dest, src.
        %macro car_barr_tck 2
        lea %1, [%2 - CONS_TAG]
        test %1, 7
        jnz ignominious_failure
        mov %1, [%1]
        ptr_test %1
        jz %%win
        fromspace_test %1
        jnz ignominious_failure ;fuck ass
%%win:
        %endmacro

        ;; Just comparing speed for now...
        ;; Ignoring the dick-dicks.
        %macro car_barr_tck_2 2
        mov eax, 7
        and rax, %2
        cmp al, CONS_TAG
        jne ignominious_failure
        mov %1, [%2 - CONS_TAG]
        ptr_test %1
        jz %%win
        fromspace_test %1
        jnz ignominious_failure
%%win:
        %endmacro        


        %macro cdr_barr_tck 2
        lea %1, [%2 - CONS_TAG + 8]
        test %1, 7
        jnz ignominious_failure
        mov %1, [%1]
        ptr_test %1
        jz %%win
        fromspace_test %1
        jnz ignominious_failure ;fuck ass
%%win:
        %endmacro

        ;; Just comparing speed for now...
        ;; Ignoring the dick-dicks.
        %macro cdr_barr_tck_2 2
        mov eax, 7
        and rax, %2
        cmp al, CONS_TAG
        jne ignominious_failure
        mov %1, [%2 - CONS_TAG + 8]
        ptr_test %1
        jz %%win
        fromspace_test %1
        jnz ignominious_failure
%%win:
        %endmacro        
        
        
        
        


actual_code:


        ;; mov rax, [memory_bottom]
        
        ;; jmp return


        ;; For the moment, car and cdr will just be noobish.
        %macro cheap_car 2
        mov %1, [%2 - CONS_TAG]
        %endmacro
        %macro cheap_cdr 2
        mov %1, [%2 - CONS_TAG + 8]
        %endmacro



        ;; paltry parameter list atm
        %macro the_program 4

        ;; Give names to the parameters.
        %define name %1
        %define cons_rdi %2
        %define car %3
        %define cdr %4
        ;; Separate car and cdr?  Whatever.

        ;; ;;First, cons up the initial list...

        ;; ;;a = r8, b = r9

        ;; r8 = count
        shl r8, 3               ;tag

        ;; Will have: rdx = xs, rcx = ys
        mov rcx, 0

%[name]_loop:

        cons_rdi                ;may kill rax
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
        cdr rax, rcx
        car rax, rax
        ;; mov rax, 999
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
        cons_rdi
        ;; imul r8, r8
        scar rdi, r8
        scdr rdi, rdx
        mov rdx, rdi

        ;; can I do this?
        cdr rcx, rcx
        
        cmp rcx, 0
        jne %[name]_reverse_loop
        ret

        %endmacro





        ;; So, we do that, and we'll

        ;; mov rax, 444
        ;; jmp return

        ;; not rdi you fool
        cmp rcx, 0
        je lea_approach

        ;; mov rax, 555
        ;; jmp return
        
        cmp rcx, 1
        je subrout_approach
        cmp rcx, 2
        je aside_approach
        cmp rcx, 3
        je noob_approach

        cmp rcx, 4
        je lea_1
        cmp rcx, 5
        je lea_2
        cmp rcx, 6
        je aside_1
        cmp rcx, 7
        je aside_2


lea_approach:
        ;; mov rax, 666
        ;; jmp return
        the_program xxx, lea_cons_rdi, cheap_car, cheap_cdr

subrout_approach:
        the_program yyy, subrout_cons_rdi, cheap_car, cheap_cdr
aside_approach:
        the_program zzz, aside_cons_rdi, cheap_car, cheap_cdr
        
noob_approach:
        ;; the_program ...

lea_1:  the_program lea_1, lea_cons_rdi, car_barr_tck, cdr_barr_tck
lea_2:  the_program lea_2, lea_cons_rdi, car_barr_tck_2, cdr_barr_tck_2

aside_1:        the_program aside_1, aside_cons_rdi, car_barr_tck, cdr_barr_tck
aside_2:        the_program aside_2, aside_cons_rdi, car_barr_tck_2, cdr_barr_tck_2

        jmp return

;; arc> (each h '(0 0 1 1 2 2 0 1 2) (do (ga full-malloc-testing 6) (gc) (withs f (fn (x y z m u v) (time:call-asm full-malloc-testing x y z m u v)) n (* 1000 (expt 2 20)) b make-bytes.n (f b n 4096 h 1000 60010))))
;; time: 36 cpu: 35 gc: 0 mem: 2800
;; time: 35 cpu: 36 gc: 0 mem: 2544
;; time: 47 cpu: 47 gc: 0 mem: 2544
;; time: 47 cpu: 47 gc: 0 mem: 2544
;; time: 34 cpu: 35 gc: 0 mem: 2544
;; time: 36 cpu: 36 gc: 0 mem: 2544
;; time: 36 cpu: 36 gc: 0 mem: 2544
;; time: 47 cpu: 48 gc: 0 mem: 2544
;; time: 37 cpu: 37 gc: 0 mem: 2544
        

        ;; Roughly as before...
        ;; Now, the above are all cheating, because they lack tck and barr.
        ;; So.
        ;; ... Next iteration.
        ;; ...
        ;; Very difficult to tell, and at any rate the checking is not
        ;; a very high proportion of shit.
        ;; Although this is not having the page_limit thing in a register, which could be changed.
        ;; ... It's too much effort to rearrange certain shit, but.

;; arc> (do (ga full-malloc-testing2 6) (each h '(4 4 5 5 6 6 7 7 0 1 2 4 5 6 7) (gc) (withs f (fn (x y z m u v) (pr h " ") (time:call-asm full-malloc-testing2 x y z m u v)) n (* 1000 (expt 2 20)) b make-bytes.n (f b n 4096 h 1000 60010))))
;; 4 time: 43 cpu: 43 gc: 0 mem: 2640
;; 4 time: 42 cpu: 43 gc: 0 mem: 224
;; 5 time: 41 cpu: 41 gc: 0 mem: 224
;; 5 time: 41 cpu: 41 gc: 0 mem: 224
;; 6 time: 41 cpu: 41 gc: 0 mem: 224
;; 6 time: 43 cpu: 43 gc: 0 mem: 224
;; 7 time: 39 cpu: 39 gc: 0 mem: 224
;; 7 time: 40 cpu: 40 gc: 0 mem: 224
;; 0 time: 34 cpu: 35 gc: 0 mem: 224
;; 1 time: 47 cpu: 46 gc: 0 mem: 224
;; 2 time: 35 cpu: 35 gc: 0 mem: 224
;; 4 time: 42 cpu: 41 gc: 0 mem: 224
;; 5 time: 42 cpu: 41 gc: 0 mem: 224
;; 6 time: 41 cpu: 41 gc: 0 mem: 224
;; 7 time: 40 cpu: 40 gc: 0 mem: 224

        ;; Ok, with PAGELIMIT and that being r15:

;; arc> (do (ga full-malloc-testing2 6) (each h '(4 4 5 5 6 6 7 7 0 1 2 4 5 6 7) (gc) (withs f (fn (x y z m u v) (pr h " ") (time:call-asm full-malloc-testing2 x y z m u v)) n (* 1000 (expt 2 20)) b make-bytes.n (f b n 4096 h 1000 60010))))
;; 4 time: 41 cpu: 41 gc: 0 mem: 2640
;; 4 time: 41 cpu: 41 gc: 0 mem: 224
;; 5 time: 42 cpu: 43 gc: 0 mem: 224
;; 5 time: 42 cpu: 42 gc: 0 mem: 224
;; 6 time: 41 cpu: 41 gc: 0 mem: 224
;; 6 time: 40 cpu: 41 gc: 0 mem: 224
;; 7 time: 40 cpu: 40 gc: 0 mem: 224
;; 7 time: 40 cpu: 39 gc: 0 mem: 224
;; 0 time: 31 cpu: 31 gc: 0 mem: 224
;; 1 time: 47 cpu: 46 gc: 0 mem: 224
;; 2 time: 31 cpu: 30 gc: 0 mem: 224
;; 4 time: 39 cpu: 40 gc: 0 mem: 224
;; 5 time: 40 cpu: 40 gc: 0 mem: 224
;; 6 time: 40 cpu: 40 gc: 0 mem: 224
;; 7 time: 40 cpu: 40 gc: 0 mem: 224
        
        ;; Welp.
        ;; Anyway, I imagine it's dominated by the cost of memory operations.
        ;; Time for actual GC next.





        


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

        

        

        ;; Gah, uses rax.
        ;; Can't use this shit on rax.
        ;; Args: dest, src [cons cell], fail [label]
        %macro car_barr_tck 3
        tck %2, CONS_TAG, %3
        mov %1, [%2 - CONS_TAG]
        ;; test if is ptr and if is fromspace...
        ;; (totally wasteful to some extent; ptr testing overlaps with type checking)
        ;; ...
        ;; FUCK IT THIS IS TERRIBLE
        ;; Approaches.


        ;; fromspace test is likely to be better than ptr test at weeding out dick
        fromspace_test %1
        jz %%win
        ptr_test %1             
        jz %%win
        lea rax, [%2 - CONS_TAG]
        call barr_move_%1
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
        

%%win:
        %endmacro
        

        ;; Gah, some clunkiness.
        ;; But.
        ;; If you could destroy the cons... but no.

        ;; Well, as long as I'm probably destroying RAX, I can do it this way.

        ;; Args: dest, src [cons cell], fail [label]
        %macro car_barr_tck_2 3
        lea rax, [%2 - CONS_TAG]
        test rax, 7
        jnz %3
        mov %1, [%2 - CONS_TAG]
        ;; test if is ptr and if is fromspace...
        ;; (totally wasteful to some extent; ptr testing overlaps with type checking)
        ;; ...
        ;; FUCK IT THIS IS TERRIBLE
        ;; Approaches.

        ;; this actually has to return its result in RFLAGS
        ;; because you might want to "jump if" or "jump if not"
        fromspace_test %1
        jz %%win
        ptr_test %1             
        jz %%win
        call barr_move_%1

%%win:

        %endmacro

        
        ;; actually, there's an LEA approach to type checking that takes fewer instructions.
        ;; not sure about speed and whatnot.
        ;; but anyway.
        ;; one scratch register.
        
        

        ;; args: register containing ptr, type tag, failure dest.
        ;; probably requires a scratch register (RAX)
        ;; (does not destroy anything but the scratch)
        ;; optim: 8-bit regs when app.
        ;; ... Oh man, could have opt. 4th argument be the scratch reg (RAX default).
        ;; [I could also have this "return" its result in RFLAGS or smthg... but no, not useful.]
        %macro tck 3
        mov eax, 7
        and rax, %1
        cmp rax, %2
        jne %3
        %endmacro

        
