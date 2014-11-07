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
        jng lea_overflow_noflip
        call gc_flip
        ;; manually move registers; CHEATING (for now) ;the gc_flip itself does that
        ;; ...
lea_overflow_noflip:
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
        jng subrout_overflow_noflip
        call gc_flip
        ;; the above manually moves registers
        
subrout_overflow_noflip:        
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

        %macro reckless_cons_rdi 0
        lea rdi, [ALLOCPTR + CONS_TAG]
        add ALLOCPTR, 16
        %endmacro


        ;; uses rax
        %macro swap 2
        mov rax, %1
        xchg rax, %2
        mov %1, rax
        %endmacro

        ;; also we don't need to care about gc work yet
        
gc_flip:
        push rax
        
        
        swap [tospace_bottom], [fromspace_bottom]
        swap [tospace_top], [fromspace_top]
        swap [tospace_mask], [fromspace_mask]

        ;; mov qword [fromspace_mask_table + 16], 22
        
        ;; mov rax, 69
        ;; jmp return

        ;; testing this shit
        mov rax, [fromspace_mask]
        
        mov [fromspace_mask_table + 8], rax
        mov [fromspace_mask_table + 16], rax

        xchg rax, [fromspace_mask_table + 24]

        ;; The following blows up on 9
        ;; mov [fromspace_mask_table + 24], rax
        ;; mov rax, 69
        jmp return
        
        ;; no 32; that's char
        mov [fromspace_mask_table + 40], rax
        mov [fromspace_mask_table + 48], rax
        mov [fromspace_mask_table + 56], rax
        ;; it can be all 0's to start with, since nothing is from fromspace at that point

        
        mov rax, 69
        jmp return
        
        mov ALLOCPTR, [tospace_bottom]
        mov rax, ALLOCPTR
        add rax, [page_size]
        mov PAGELIMIT, rax

        ;; normally we'd trace some root ptrs
        ;; but there are almost none
        ;; however, there are a few registers.
        ;; which we are cheating at.
        ;; Now...
        ;; There are two places where things are allocated.
        ;; Though the first one is used only at the beginning.
        ;; rcx and rdx probably contain lists.
        ;; rdi was about to be allocated, but contains nothing meaningful.
        ;; And... r8 likely contains ... an integer, never mind that.
        ;; So.
        cmp qword [dont_move_stuff], 0
        jnz gc_flip_done_moving
        
        mov rax, rcx
        call possibly_move_rax
        mov rcx, rax
        mov rax, rdx
        call possibly_move_rax
        mov rdx, rax
        
gc_flip_done_moving:

        ;; mov rax, 69
        ;; jmp return

        pop rax
        ret


        ;; There are a few ways to deal with moving.
        ;; A couple of different ways to set the high bit
        ;; in the register [or possibly negate it or use some
        ;;  other way of denoting

        %macro fwd_ptr_test 1
        bt %1, 63
        %endmacro
        ;; these tests end up setting the 0 flag



        ;; Ok, for this movement shit, we really want some
        ;; free registers.
        ;; Esp. in multithreaded, when we'd grab cdr and then car.
        ;; [With optional memory barrier.]
        ;; [..................... Actually, do you need ......]
        ;; [No, I don't think you need a memory barrier there.]

possibly_move_rax:      
        ptr_test rax
        jz plain_ret
        fromspace_test rax
        jz plain_ret
move_rax:
        ;; Now this depends on the type of thing.
        ;; [Actually, we might use a type dispatch to obviate the ptr test.]
        ;; ... Well, I'm not making jump tables yet, and at the moment
        ;; the only ptr type is a cons.
        ;; So.

mov_rax_cons:
        ;; Check for fwd ptr.
        ;; ... 
        ;; We are appropriating r14 and r15.

        ;; ....
        ;; Dickass considerations here.
        ;; [Multiple ways to do the comparison with diff. performance characteristics.]
        ;; Meh.
        mov r14, [rax - CONS_TAG]
        fwd_ptr_test r14
        jnz maybe_lucky
not_lucky:
        ;; must actually move it
        
        lea r15, [ALLOCPTR + CONS_TAG]
        add ALLOCPTR, 16
        ;; now we could ... we must at least compare with the page limit
        cmp ALLOCPTR, PAGELIMIT
        ja grab_moar
        mov [r15 - CONS_TAG], r14
        mov r14, [rax - CONS_TAG + 8]
        mov [r15 - CONS_TAG + 8], r14
        ;; make fwd ptr
        mov r14, r15
        bts r14, 63
        ;; install
        mov [rax - CONS_TAG], r14
        ;; don't use gc stack atm
        mov rax, r15
        ret

maybe_lucky:  
        ptr_test r14
        jz not_lucky
        ;; lucky: is moved.
        btr r14, 63
        mov rax, r14
        ret

        ;; another page.
        ;; we could also check whether we've run out of pages.
        ;; in which case we're way out of memory.
        ;; [but could simply use more with virtual memory]

        ;; meanwhile, 
grab_moar:
        mov ALLOCPTR, PAGELIMIT
        mov r15, [page_size]
        add PAGELIMIT, r15
        jmp not_lucky
        



        



ignominious_failure:
        mov rax, 88
        mov rax, rcx
        mov rax, [fromspace_mask]
        mov rax, [tospace_top]
        jmp return


        ;; The following two tables are for a certain method of
        ;; testing stuff...
        ;; Often you have to test whether something is a pointer and whether
        ;; it matches a certain mask.
        ;; 
        align 8
fwd_mask_table:
        dq 0
        dq 1 << 63
        dq 1 << 63
        dq 1 << 63
        dq 0
        dq 1 << 63
        dq 1 << 63
        dq 1 << 63

        
fromspace_mask_table:
        %rep 16
        dq 0
        %endrep
        


        ;; Oh man.
        ;; Ideaz.
        ;; A version of car that .............
        ;; Actually, you can't really 


        ;; Geez.
        ;; Now the barriers will actually happen.
        ;; And I'll have to worry about ...
        
        ;; [By the way, car and cdr are a little different.
        ;;  The cdr, whether it holds a cons or nil, will
        ;;  almost always be a pointer.
        ;;  The car is far more likely to be either a fixnum
        ;;  or a character.]

        ;; Ok, listing out methods.

        ;; There are two semi-orthogonal things here.
        ;; One is the type-checking.
        ;; The other is the barrier.

        ;; I don't know how many registers I might want to use,
        ;; or might have available, or what.
        ;; So let's assume I have everything.
        ;; Then, if I discover that they're all eqv,
        ;; I can choose the one that uses fewest registers/is most
        ;; convenient about its use.
        %macro car_1 2
        ;; Test.
        lea r15, [%2 - CONS_TAG]
        test r15, 7
        jnz type_error
        mov %1, [r15]
        fromspace_test %1
        jz %%win
        ptr_test %1
        jz %%win
        call move_%1_at_r15
%%win:                          ;there must be a newline btwn this and the endmacro
        %endmacro

        ;; All falling through.
        ;; But requiring more memory access.
        %macro car_2 2
        lea r15, [%2 - CONS_TAG]
        test r15, 7
        jnz type_error
        mov %1, [r15]
        lea r14, [fromspace_mask_table]
        mov eax, 7
        and rax, %1
        test %1, [r14 + 8*rax]
        ;; test %1, [fromspace_mask_table + 8*rax]
        ;; GAH I CAN'T DO THAT
        ;; shl rax, 3
        ;; test %1, [fromspace_mask_table + rax]
        ;; NOR CAN I DO THAT
        lea rax, [%%win]
        jnz move_%1_at_r15_and_jmp_rax
%%win:
        %endmacro

        ;; Cutting out that lea for the type check.
        ;; (Again, below shit could use smaller...)
        %macro car_3 2
        mov rax, %2
        and al, 7
        cmp al, CONS_TAG
        jne type_error
        mov %1, [%2 - CONS_TAG]
        fromspace_test %1
        jz %%win
        ptr_test %1
        jz %%win
        ;; ... dicks ... just try this
        call move_%1_car_%2
%%win:
        %endmacro
        ;; For direct comparison

        %macro car_4 2
        mov rax, %2
        and al, 7
        cmp al, CONS_TAG
        jne type_error
        mov %1, [%2 - CONS_TAG]
        fromspace_test %1
        jz %%win
        ptr_test %1
        jz %%win
        lea r15, [%2 - CONS_TAG]
        call move_%1_at_r15
%%win:
        %endmacro

        %macro car_5 2
        mov rax, %2
        and al, 7
        cmp al, CONS_TAG
        jne type_error
        mov %1, [%2 - CONS_TAG]
        lea r14, [fromspace_mask_table]
        mov eax, 7
        and rax, %1
        test %1, [r14 + 8*rax]
        lea rax, [%%win]
        jnz move_%1_car_%2_and_jmp_rax
%%win:
        %endmacro

        ;; Oh boy, copy and paste and dumb modifications.

        %macro cdr_1 2
        ;; Test.
        lea r15, [%2 - CONS_TAG + 8]
        test r15, 7
        jnz type_error
        mov %1, [r15]
        fromspace_test %1
        jz %%win
        ptr_test %1
        jz %%win
        call move_%1_at_r15
%%win:                          ;there must be a newline btwn this and the endmacro
        %endmacro

        ;; All falling through.
        ;; But requiring more memory access.
        %macro cdr_2 2
        lea r15, [%2 - CONS_TAG + 8]
        test r15, 7
        jnz type_error
        mov %1, [r15]
        lea r14, [fromspace_mask_table]
        mov eax, 7
        and rax, %1
        test %1, [r14 + 8*rax]
        lea rax, [%%win]
        jnz move_%1_at_r15_and_jmp_rax
%%win:
        %endmacro

        ;; Cutting out that lea for the type check.
        ;; (Again, below shit could use smaller...)
        %macro cdr_3 2
        mov rax, %2
        and al, 7
        cmp al, CONS_TAG
        jne type_error
        mov %1, [%2 - CONS_TAG + 8]
        fromspace_test %1
        jz %%win
        ptr_test %1
        jz %%win
        ;; ... dicks ... just try this
        call move_%1_cdr_%2
%%win:
        %endmacro
        ;; For direct comparison

        %macro cdr_4 2
        mov rax, %2
        and al, 7
        cmp al, CONS_TAG
        jne type_error
        mov %1, [%2 - CONS_TAG + 8]
        fromspace_test %1
        jz %%win
        ptr_test %1
        jz %%win
        lea r15, [%2 - CONS_TAG + 8]
        call move_%1_at_r15
%%win:
        %endmacro

        %macro cdr_5 2
        mov rax, %2
        and al, 7
        cmp al, CONS_TAG
        jne type_error
        mov %1, [%2 - CONS_TAG + 8]
        lea r14, [fromspace_mask_table]
        mov eax, 7
        and rax, %1
        test %1, [r14 + 8*rax]
        lea rax, [%%win]
        jnz move_%1_cdr_%2_and_jmp_rax
%%win:
        %endmacro        
        


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

type_error:
        mov rax, 51
        jmp return


move_rax_at_r15:
        push r15                ;lel, prob. fix later
        call move_rax
        pop r15
        mov [r15], rax
        ret

move_r8_at_r15:
        push r15
        xchg rax, r8
        call move_rax
        pop r15
        mov [r15], rax
        xchg rax, r8
        ret

move_rcx_at_r15:
        push r15
        xchg rax, rcx
        call move_rax
        pop r15
        mov [r15], rax
        xchg rax, rcx
        ret

move_r8_at_r15_and_jmp_rax:
        call move_r8_at_r15
        jmp rax
move_rcx_at_r15_and_jmp_rax:
        call move_r8_at_r15
        jmp rax
        
move_r8_car_rcx:        
        xchg rax, r8
        call move_rax
        xchg rax, r8
        scdr rcx, r8
        ret

move_rcx_cdr_r13:
        xchg rax, rcx
        call move_rax
        xchg rax, rcx
        scdr r13, rcx
        ret

move_r8_car_rcx_and_jmp_rax:
        call move_r8_car_rcx
        jmp rax

move_rcx_cdr_r13_and_jmp_rax:
        call move_rcx_cdr_r13
        jmp rax


        
        



        ;; the cheapo things that don't barr will use this
dont_move_stuff:  dq 0
        
        


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

name:   

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


        ;; mov rax, 339
        ;; jmp return
        
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
        ;; cheap_cdr rax, rcx
        ;; cheap_car rax, rax
        ;; mov rax, 999
        ;; mov rax, 932
        mov rax, [memory_top]
        sub rax, ALLOCPTR
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
        cons_rdi
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

        %endmacro


        ;; mov rax, [tospace_mask]
        ;; sub rax, [fromspace_mask]
        ;; swap [tospace_bottom], [fromspace_bottom]
        ;; mov rax, [fromspace_bottom]
        ;; and rax, [fromspace_mask]
        ;; jmp return



        ;; So, we do that, and we'll


        ;; add rsp, 4096
        ;; fuckin' idiot
        ;; sub rsp, 4096
        ;; damn, that didn't get dick

        
        mov qword [dont_move_stuff], 1
        
        ;; not rdi you fool
        ;; --aw fuck, cmov only takes regs as destination
        cmp rcx, 0
        je lea
        
        
        cmp rcx, 1
        je subrout
        cmp rcx, 2
        je aside
        cmp rcx, 3
        je noob

        mov qword [dont_move_stuff], 0

        cmp rcx, 4
        je lea_1
        cmp rcx, 5
        je lea_2
        cmp rcx, 6
        je aside_1
        cmp rcx, 7
        je aside_2

        cmp rcx, 8
        je lea_car1
        cmp rcx, 9
        je lea_car2
        cmp rcx, 10
        je lea_car3
        cmp rcx, 11
        je lea_car4
        cmp rcx, 12
        je lea_car5

        mov rax, 77
        jmp return



        the_program lea, lea_cons_rdi, cheap_car, cheap_cdr
        the_program subrout, subrout_cons_rdi, cheap_car, cheap_cdr
        the_program aside, aside_cons_rdi, cheap_car, cheap_cdr
        
        the_program noob, reckless_cons_rdi, cheap_car, cheap_cdr

        the_program lea_1, lea_cons_rdi, car_barr_tck, cdr_barr_tck
        the_program lea_2, lea_cons_rdi, car_barr_tck_2, cdr_barr_tck_2

        the_program aside_1, aside_cons_rdi, car_barr_tck, cdr_barr_tck
        the_program aside_2, aside_cons_rdi, car_barr_tck_2, cdr_barr_tck_2

        the_program lea_car1, lea_cons_rdi, car_1, cdr_2
        the_program lea_car2, lea_cons_rdi, car_2, cdr_2
        the_program lea_car3, lea_cons_rdi, car_3, cdr_3
        the_program lea_car4, lea_cons_rdi, car_4, cdr_4
        the_program lea_car5, lea_cons_rdi, car_5, cdr_5        

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

        
