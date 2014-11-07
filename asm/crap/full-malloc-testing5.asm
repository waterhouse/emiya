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

        ;; No need for that fromspace_mask_table crap, it's crap.
        
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

	;; Ok, so, if bit 63 is set, then it is definitely a negative number.
        %macro fwd_ptr_test 1
        cmp %1, 0
        %endmacro
        ;; these tests end up setting the 0 flag
	;; --Now this test sets ... "less than" signed flags.



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
        fwd_ptr_test r14	;sets "less than 0" flags
        jl maybe_lucky
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

        ;; So, since I'll probably generally want to leave a couple
        ;; of registers usable for the moving crap,
        ;; I probably don't really have a problem with register usage in
        ;; these things.

        ;; Want to test a bunch of permutations.
        ;; The cdrs must be generated automatically.
        ;; "car" -> "cdr" and "CONS_TAG]" -> "CONS_TAG + 8]".

        ;; Choices...
        ;; - The type check can be done with either "lea reg, [%2 - CONS_TAG]; test reg, 7"
        ;;   or something like "mov reg, %2; and reg, 7; cmp reg, CONS_TAG".
        ;; - The order of "fromspace_test" and "ptr_test" can be swapped.
        ;;   Logically, "fromspace_test" should go first in cdr, and seems reasonably
        ;;   likely it should go first in car as well.
        ;;   Not testing this atm.  (Using a bunch of lists of high or negative fixnums
        ;;    would be the case in which it sucked.  --I guess I could test a bit.)
        ;; - The call to the "move" thing can either be accomplished with a "call"
        ;;   that you normally jump across, or with a "lea reg, [return_addr]" followed
        ;;   by a conditional jump.
        ;; - The fromspace-ptr tests could be combined into a memory-operation-requiring
        ;;   thing: "mov reg, %1; and reg, 7; test %1, [fromspace_mask_table + 8*reg]".
        ;;   This was determined to be terribly expensive and bad.
        ;; - The 

        ;; All of these may wreck rax and shouldn't take it as args.

        ;; Oh man, another way.


ptr_test_rcx_at_r15:        
        ptr_test rcx
        jnz ptr_test_rcx_at_r15_fail
        jmp rax
ptr_test_rcx_at_r15_fail:
        call move_rcx_at_r15
        jmp rax
        ;; or something.
        ;; that shit could be reworked, really

ptr_test_r8_at_r15:
        ptr_test r8
        jnz ptr_test_r8_at_r15_fail
        jmp rax
ptr_test_r8_at_r15_fail:
        call move_r8_at_r15
        jmp rax

ptr_test_r8_car_rcx:
        ptr_test r8
        jnz ptr_test_r8_car_rcx_fail
        jmp rax
ptr_test_r8_car_rcx_fail:
        call move_r8_car_rcx
        jmp rax

ptr_test_rcx_cdr_r13:
        ptr_test rcx
        jnz ptr_test_rcx_cdr_r13_fail
        jmp rax
ptr_test_rcx_cdr_r13_fail:
        call move_rcx_cdr_r13
        jmp rax

        ;; fuck it
subrout_ptr_test_r8_car_rcx:
        ptr_test r8
        jz plain_ret
        jmp move_r8_car_rcx

subrout_ptr_test_rcx_cdr_r13:
        ptr_test rcx
        jz plain_ret
        jmp move_rcx_cdr_r13

subrout_ptr_test_r8_at_r15:
        ptr_test r8
        jz plain_ret
        jmp move_r8_at_r15

subrout_ptr_test_rcx_at_r15:
        ptr_test rcx
        jz plain_ret
        jmp move_rcx_at_r15

        
        
        
        
        %macro car_1 2
        lea r15, [%2 - CONS_TAG]
        test r15, 7
        jnz type_error
        mov %1, [r15]
        fromspace_test %1
        jz %%win
        ptr_test %1
        jz %%win
        call move_%1_at_r15
%%win:
        %endmacro
        
        %macro car_2 2
        lea r15, [%2 - CONS_TAG]
        test r15, 7
        jnz type_error
        mov %1, [r15]
        ;; lea rax, [move_%1_at_r15] ;YOU FUCKING COMPLETE TOTAL IDIOT FUCK
        lea rax, [%%win]
        fromspace_test %1
        jz %%win
        ptr_test %1
        jnz move_%1_at_r15_and_jmp_rax
%%win:
        %endmacro

        %macro car_3 2
        lea r15, [%2 - CONS_TAG]
        test r15, 7
        jnz type_error
        mov %1, [r15]
        fromspace_test %1
        lea rax, [%%win]
        jnz ptr_test_%1_at_r15
%%win:
        %endmacro

        
        ;; Cutting out that lea for the type check.
        ;; (Again, below shit could use smaller...)
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
        ;; ... dicks ... just try this
        call move_%1_car_%2
%%win:
        %endmacro
        ;; For direct comparison

        %macro car_5 2
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

        %macro car_6 2
        mov rax, %2
        and al, 7
        cmp al, CONS_TAG
        jne type_error
        mov %1, [%2 - CONS_TAG]
        fromspace_test %1
        lea rax, [%%win]
        jnz ptr_test_%1_car_%2
%%win:
        %endmacro

        %macro car_7 2
        mov rax, %2
        and al, 7
        cmp al, CONS_TAG
        jne type_error
        mov %1, [%2 - CONS_TAG]
        fromspace_test %1
        lea rax, [%%win]
        lea r15, [%2 - CONS_TAG]
        jnz ptr_test_%1_at_r15
%%win:
        %endmacro

        %macro car_8 2
        mov rax, %2
        and al, 7
        cmp al, CONS_TAG
        jne type_error
        mov %1, [%2 - CONS_TAG]
        fromspace_test %1
        jz %%win
        call subrout_ptr_test_%1_car_%2
%%win:
        %endmacro


        %macro car_9 2
        mov rax, %2
        and al, 7
        cmp al, CONS_TAG
        jne type_error
        mov %1, [%2 - CONS_TAG]
        fromspace_test %1
        jz %%win
        lea r15, [%2 - CONS_TAG]
        call subrout_ptr_test_%1_at_r15
%%win:
        %endmacro


        ;; ----------------- cdrs ------------------

        
        %macro cdr_1 2
        lea r15, [%2 - CONS_TAG + 8]
        test r15, 7
        jnz type_error
        mov %1, [r15]
        fromspace_test %1
        jz %%win
        ptr_test %1
        jz %%win
        call move_%1_at_r15
%%win:
        %endmacro
        
        %macro cdr_2 2
        lea r15, [%2 - CONS_TAG + 8]
        test r15, 7
        jnz type_error
        mov %1, [r15]
        ;; lea rax, [move_%1_at_r15] ;YOU FUCKING COMPLETE TOTAL IDIOT FUCK
        lea rax, [%%win]
        fromspace_test %1
        jz %%win
        ptr_test %1
        jnz move_%1_at_r15_and_jmp_rax
%%win:
        %endmacro

        %macro cdr_3 2
        lea r15, [%2 - CONS_TAG + 8]
        test r15, 7
        jnz type_error
        mov %1, [r15]
        fromspace_test %1
        lea rax, [%%win]
        jnz ptr_test_%1_at_r15
%%win:
        %endmacro

        
        ;; Cutting out that lea for the type check.
        ;; (Again, below shit could use smaller...)
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
        ;; ... dicks ... just try this
        call move_%1_cdr_%2
%%win:
        %endmacro
        ;; For direct comparison

        %macro cdr_5 2
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

        %macro cdr_6 2
        mov rax, %2
        and al, 7
        cmp al, CONS_TAG
        jne type_error
        mov %1, [%2 - CONS_TAG + 8]
        fromspace_test %1
        lea rax, [%%win]
        jnz ptr_test_%1_cdr_%2
%%win:
        %endmacro

        %macro cdr_7 2
        mov rax, %2
        and al, 7
        cmp al, CONS_TAG
        jne type_error
        mov %1, [%2 - CONS_TAG + 8]
        fromspace_test %1
        lea rax, [%%win]
        lea r15, [%2 - CONS_TAG + 8]
        jnz ptr_test_%1_at_r15
%%win:
        %endmacro

        %macro cdr_8 2
        mov rax, %2
        and al, 7
        cmp al, CONS_TAG
        jne type_error
        mov %1, [%2 - CONS_TAG + 8]
        fromspace_test %1
        jz %%win
        call subrout_ptr_test_%1_cdr_%2
%%win:
        %endmacro

        %macro cdr_9 2
        mov rax, %2
        and al, 7
        cmp al, CONS_TAG
        jne type_error
        mov %1, [%2 - CONS_TAG + 8]
        fromspace_test %1
        jz %%win
        lea r15, [%2 - CONS_TAG + 8]
        call subrout_ptr_test_%1_at_r15
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
        ;; jmp return
        push r15
        xchg rax, rcx
        call move_rax
        pop r15
        mov [r15], rax
        xchg rax, rcx
        ret

move_r8_at_r15_and_jmp_rax:
        ;; jmp return
        call move_r8_at_r15
        jmp rax
move_rcx_at_r15_and_jmp_rax:
        ;; it's here
        ;; jmp return
        ;; call move_rcx_at_r15    ;fixed that shit ;but not good enough?

        call move_rcx_at_r15
        jmp rax

        ;; mov rax, rcx
        ;; and rax, [fromspace_mask]
        ;; jmp return

        ;; push rax

        ;; ;; inlining
        ;; push r15
        ;; xchg rax, rcx
        ;; call possibly_move_rax
        ;; pop r15
        ;; mov [r15], rax
        ;; xchg rax, rcx
        
        ;; pop rax
        
        ;; jmp rax
        
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

        ;; Testing:
        ;; neg r8

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
        ;; add r8, 8
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

        ;; arc> (let n 8 (pbcopy:tostring:each x '(lea aside) (for i 1 9 (prn "        cmp rcx, " n) (prn "        je " x "_car" i) ++.n)))

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
        cmp rcx, 13
        je lea_car6
        cmp rcx, 14
        je lea_car7
        cmp rcx, 15
        je lea_car8
        cmp rcx, 16
        je lea_car9
        cmp rcx, 17
        je aside_car1
        cmp rcx, 18
        je aside_car2
        cmp rcx, 19
        je aside_car3
        cmp rcx, 20
        je aside_car4
        cmp rcx, 21
        je aside_car5
        cmp rcx, 22
        je aside_car6
        cmp rcx, 23
        je aside_car7
        cmp rcx, 24
        je aside_car8
        cmp rcx, 25
        je aside_car9


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

        ;; arc> (pbcopy:tostring:each x '(lea aside) (for i 1 9 (prn "        the_program " x "_car" i ", " x "_cons_rdi, car_" i ", cdr_" i)))

        the_program lea_car1, lea_cons_rdi, car_1, cdr_1
        the_program lea_car2, lea_cons_rdi, car_2, cdr_2
        the_program lea_car3, lea_cons_rdi, car_3, cdr_3
        the_program lea_car4, lea_cons_rdi, car_4, cdr_4
        the_program lea_car5, lea_cons_rdi, car_5, cdr_5
        the_program lea_car6, lea_cons_rdi, car_6, cdr_6
        the_program lea_car7, lea_cons_rdi, car_7, cdr_7
        the_program lea_car8, lea_cons_rdi, car_8, cdr_8
        the_program lea_car9, lea_cons_rdi, car_9, cdr_9
        
        the_program aside_car1, aside_cons_rdi, car_1, cdr_1
        the_program aside_car2, aside_cons_rdi, car_2, cdr_2
        the_program aside_car3, aside_cons_rdi, car_3, cdr_3
        the_program aside_car4, aside_cons_rdi, car_4, cdr_4
        the_program aside_car5, aside_cons_rdi, car_5, cdr_5
        the_program aside_car6, aside_cons_rdi, car_6, cdr_6
        the_program aside_car7, aside_cons_rdi, car_7, cdr_7
        the_program aside_car8, aside_cons_rdi, car_8, cdr_8
        the_program aside_car9, aside_cons_rdi, car_9, cdr_9

        

        


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
        
        ;; For posterity.

;; arc> (do (ga full-malloc-testing5 6) (each h (join ([mappend list _ _] (range 4 25)) (range 8 25)) (gc) (sleep .5) (withs f (fn (x y z m u v) (pr (pad h 2) " ") (call-asm full-malloc-testing5 x y z m u v)) n (* 80 (expt 2 20)) b make-bytes.n (time:do (pr (f b n 4096 h 1000 200000) " ")))))
;;  4 4546625536 time: 4 cpu: 4 gc: 0 mem: 5632
;;  4 4546625536 time: 3 cpu: 3 gc: 0 mem: 2896
;;  5 4546625536 time: 3 cpu: 3 gc: 0 mem: 2896
;;  5 4546625536 time: 3 cpu: 3 gc: 0 mem: 2896
;;  6 4546625536 time: 3 cpu: 3 gc: 0 mem: 2896
;;  6 4546625536 time: 3 cpu: 3 gc: 0 mem: 2896
;;  7 4546625536 time: 3 cpu: 3 gc: 0 mem: 2896
;;  7 4546625536 time: 3 cpu: 3 gc: 0 mem: 2896
;;  8 16 time: 698 cpu: 698 gc: 0 mem: 2896
;;  8 16 time: 687 cpu: 687 gc: 0 mem: 2896
;;  9 16 time: 791 cpu: 791 gc: 0 mem: 2896
;;  9 16 time: 797 cpu: 798 gc: 0 mem: 2896
;; 10 16 time: 749 cpu: 749 gc: 0 mem: 2912
;; 10 16 time: 755 cpu: 755 gc: 0 mem: 2912
;; 11 16 time: 640 cpu: 640 gc: 0 mem: 2912
;; 11 16 time: 641 cpu: 640 gc: 0 mem: 2912
;; 12 16 time: 665 cpu: 665 gc: 0 mem: 2912
;; 12 16 time: 672 cpu: 672 gc: 0 mem: 2912
;; 13 16 time: 714 cpu: 715 gc: 0 mem: 2912
;; 13 16 time: 716 cpu: 716 gc: 0 mem: 2912
;; 14 16 time: 773 cpu: 773 gc: 0 mem: 2912
;; 14 16 time: 776 cpu: 776 gc: 0 mem: 2912
;; 15 16 time: 665 cpu: 666 gc: 0 mem: 2912
;; 15 16 time: 666 cpu: 666 gc: 0 mem: 2912
;; 16 16 time: 695 cpu: 695 gc: 0 mem: 2912
;; 16 16 time: 688 cpu: 688 gc: 0 mem: 2912
;; 17 16 time: 711 cpu: 711 gc: 0 mem: 2912
;; 17 16 time: 716 cpu: 716 gc: 0 mem: 2912
;; 18 16 time: 783 cpu: 783 gc: 0 mem: 2912
;; 18 16 time: 782 cpu: 782 gc: 0 mem: 2912
;; 19 16 time: 801 cpu: 800 gc: 0 mem: 2912
;; 19 16 time: 794 cpu: 794 gc: 0 mem: 2912
;; 20 16 time: 671 cpu: 670 gc: 0 mem: 2912
;; 20 16 time: 675 cpu: 675 gc: 0 mem: 2912
;; 21 16 time: 688 cpu: 689 gc: 0 mem: 2912
;; 21 16 time: 688 cpu: 688 gc: 0 mem: 2912
;; 22 16 time: 742 cpu: 741 gc: 0 mem: 2912
;; 22 16 time: 743 cpu: 743 gc: 0 mem: 2912
;; 23 16 time: 753 cpu: 753 gc: 0 mem: 2912
;; 23 16 time: 760 cpu: 759 gc: 0 mem: 2912
;; 24 16 time: 686 cpu: 686 gc: 0 mem: 2912
;; 24 16 time: 679 cpu: 679 gc: 0 mem: 2912
;; 25 16 time: 699 cpu: 699 gc: 0 mem: 2912
;; 25 16 time: 703 cpu: 703 gc: 0 mem: 2912
;;  8 16 time: 689 cpu: 690 gc: 0 mem: 2896
;;  9 16 time: 799 cpu: 799 gc: 0 mem: 2896
;; 10 16 time: 750 cpu: 750 gc: 0 mem: 2912
;; 11 16 time: 646 cpu: 646 gc: 0 mem: 2912
;; 12 16 time: 665 cpu: 664 gc: 0 mem: 2912
;; 13 16 time: 720 cpu: 721 gc: 0 mem: 2912
;; 14 16 time: 771 cpu: 771 gc: 0 mem: 2912
;; 15 16 time: 660 cpu: 660 gc: 0 mem: 2912
;; 16 16 time: 693 cpu: 692 gc: 0 mem: 2912
;; 17 16 time: 716 cpu: 715 gc: 0 mem: 2912
;; 18 16 time: 785 cpu: 785 gc: 0 mem: 2912
;; 19 16 time: 806 cpu: 805 gc: 0 mem: 2912
;; 20 16 time: 675 cpu: 675 gc: 0 mem: 2912
;; 21 16 time: 687 cpu: 687 gc: 0 mem: 2912
;; 22 16 time: 746 cpu: 747 gc: 0 mem: 2912
;; 23 16 time: 758 cpu: 758 gc: 0 mem: 2912
;; 24 16 time: 686 cpu: 686 gc: 0 mem: 2912
;; 25 16 time: 704 cpu: 704 gc: 0 mem: 2912
;; nil
;; arc> (do (ga full-malloc-testing5 6) (each h (join ([mappend list _ _] (range 4 25)) (range 8 25)) (gc) (sleep .5) (withs f (fn (x y z m u v) (pr (pad h 2) " ") (call-asm full-malloc-testing5 x y z m u v)) n (* 20 (expt 2 20)) b make-bytes.n (time:do (pr (f b n 4096 h 1000 200000) " ")))))
;;  4 4492099584 time: 2 cpu: 1 gc: 0 mem: 5632
;;  4 4492099584 time: 1 cpu: 1 gc: 0 mem: 2896
;;  5 4492099584 time: 1 cpu: 1 gc: 0 mem: 2896
;;  5 4492099584 time: 1 cpu: 1 gc: 0 mem: 2896
;;  6 4492099584 time: 1 cpu: 1 gc: 0 mem: 2896
;;  6 4492099584 time: 1 cpu: 1 gc: 0 mem: 2896
;;  7 4492099584 time: 1 cpu: 1 gc: 0 mem: 2896
;;  7 4492099584 time: 1 cpu: 0 gc: 0 mem: 2896
;;  8 16 time: 843 cpu: 843 gc: 0 mem: 2896
;;  8 16 time: 817 cpu: 816 gc: 0 mem: 2896
;;  9 16 time: 954 cpu: 954 gc: 0 mem: 2896
;;  9 16 time: 956 cpu: 955 gc: 0 mem: 2896
;; 10 16 time: 894 cpu: 894 gc: 0 mem: 2912
;; 10 16 time: 895 cpu: 895 gc: 0 mem: 2912
;; 11 16 time: 746 cpu: 747 gc: 0 mem: 2912
;; 11 16 time: 744 cpu: 744 gc: 0 mem: 2912
;; 12 16 time: 793 cpu: 794 gc: 0 mem: 2912
;; 12 16 time: 792 cpu: 792 gc: 0 mem: 2912
;; 13 16 time: 860 cpu: 860 gc: 0 mem: 2912
;; 13 16 time: 862 cpu: 862 gc: 0 mem: 2912
;; 14 16 time: 915 cpu: 916 gc: 0 mem: 2912
;; 14 16 time: 922 cpu: 922 gc: 0 mem: 2912
;; 15 16 time: 789 cpu: 789 gc: 0 mem: 2912
;; 15 16 time: 781 cpu: 782 gc: 0 mem: 2912
;; 16 16 time: 825 cpu: 825 gc: 0 mem: 2912
;; 16 16 time: 835 cpu: 836 gc: 0 mem: 2912
;; 17 16 time: 845 cpu: 845 gc: 0 mem: 2912
;; 17 16 time: 847 cpu: 846 gc: 0 mem: 2912
;; 18 16 time: 964 cpu: 964 gc: 0 mem: 2912
;; 18 16 time: 965 cpu: 965 gc: 0 mem: 2912
;; 19 16 time: 972 cpu: 972 gc: 0 mem: 2912
;; 19 16 time: 973 cpu: 972 gc: 0 mem: 2912
;; 20 16 time: 807 cpu: 807 gc: 0 mem: 2912
;; 20 16 time: 813 cpu: 812 gc: 0 mem: 2912
;; 21 16 time: 821 cpu: 821 gc: 0 mem: 2912
;; 21 16 time: 830 cpu: 829 gc: 0 mem: 2912
;; 22 16 time: 916 cpu: 916 gc: 0 mem: 2912
;; 22 16 time: 914 cpu: 914 gc: 0 mem: 2912
;; 23 16 time: 922 cpu: 922 gc: 0 mem: 2912
;; 23 16 time: 919 cpu: 918 gc: 0 mem: 2912
;; 24 16 time: 833 cpu: 833 gc: 0 mem: 2912
;; 24 16 time: 833 cpu: 832 gc: 0 mem: 2912
;; 25 16 time: 858 cpu: 858 gc: 0 mem: 2912
;; 25 16 time: 862 cpu: 862 gc: 0 mem: 2912
;;  8 16 time: 822 cpu: 822 gc: 0 mem: 2896
;;  9 16 time: 950 cpu: 950 gc: 0 mem: 2896
;; 10 16 time: 896 cpu: 896 gc: 0 mem: 2912
;; 11 16 time: 746 cpu: 745 gc: 0 mem: 2912
;; 12 16 time: 799 cpu: 800 gc: 0 mem: 2912
;; 13 16 time: 860 cpu: 860 gc: 0 mem: 2912
;; 14 16 time: 919 cpu: 918 gc: 0 mem: 2912
;; 15 16 time: 787 cpu: 787 gc: 0 mem: 2912
;; 16 16 time: 830 cpu: 829 gc: 0 mem: 2912
;; 17 16 time: 850 cpu: 850 gc: 0 mem: 2912
;; 18 16 time: 970 cpu: 970 gc: 0 mem: 2912
;; 19 16 time: 975 cpu: 975 gc: 0 mem: 2912
;; 20 16 time: 808 cpu: 807 gc: 0 mem: 2912
;; 21 16 time: 821 cpu: 822 gc: 0 mem: 2912
;; 22 16 time: 914 cpu: 914 gc: 0 mem: 2912
;; 23 16 time: 926 cpu: 926 gc: 0 mem: 2912
;; 24 16 time: 832 cpu: 832 gc: 0 mem: 2912
;; 25 16 time: 864 cpu: 864 gc: 0 mem: 2912
;; nil
;; arc> (do (ga full-malloc-testing5 6) (each h (join ([mappend list _ _] (range 4 25)) (range 8 25)) (gc) (sleep .5) (withs f (fn (x y z m u v) (pr (pad h 2) " ") (call-asm full-malloc-testing5 x y z m u v)) n (* 1000 (expt 2 20)) b make-bytes.n (time:do (pr (f b n 4096 h 1000 200000) " ")))))
;;  4 5637144576 time: 47 cpu: 47 gc: 0 mem: 5632
;;  4 5637144576 time: 46 cpu: 46 gc: 0 mem: 2896
;;  5 5637144576 time: 42 cpu: 41 gc: 0 mem: 2896
;;  5 5637144576 time: 41 cpu: 41 gc: 0 mem: 2896
;;  6 5637144576 time: 46 cpu: 46 gc: 0 mem: 2896
;;  6 5637144576 time: 45 cpu: 44 gc: 0 mem: 2896
;;  7 5637144576 time: 41 cpu: 42 gc: 0 mem: 2896
;;  7 5637144576 time: 39 cpu: 40 gc: 0 mem: 2896
;;  8 16 time: 650 cpu: 651 gc: 0 mem: 2896
;;  8 16 time: 650 cpu: 650 gc: 0 mem: 2896
;;  9 16 time: 740 cpu: 740 gc: 0 mem: 2896
;;  9 16 time: 738 cpu: 738 gc: 0 mem: 2896
;; 10 16 time: 704 cpu: 704 gc: 0 mem: 2912
;; 10 16 time: 701 cpu: 700 gc: 0 mem: 2912
;; 11 16 time: 614 cpu: 614 gc: 0 mem: 2912
;; 11 16 time: 609 cpu: 609 gc: 0 mem: 2912
;; 12 16 time: 639 cpu: 639 gc: 0 mem: 2912
;; 12 16 time: 637 cpu: 637 gc: 0 mem: 2912
;; 13 16 time: 682 cpu: 682 gc: 0 mem: 2912
;; 13 16 time: 682 cpu: 682 gc: 0 mem: 2912
;; 14 16 time: 728 cpu: 728 gc: 0 mem: 2912
;; 14 16 time: 727 cpu: 727 gc: 0 mem: 2912
;; 15 16 time: 626 cpu: 627 gc: 0 mem: 2912
;; 15 16 time: 626 cpu: 627 gc: 0 mem: 2912
;; 16 16 time: 648 cpu: 648 gc: 0 mem: 2912
;; 16 16 time: 651 cpu: 651 gc: 0 mem: 2912
;; 17 16 time: 672 cpu: 671 gc: 0 mem: 2912
;; 17 16 time: 671 cpu: 670 gc: 0 mem: 2912
;; 18 16 time: 738 cpu: 738 gc: 0 mem: 2912
;; 18 16 time: 739 cpu: 739 gc: 0 mem: 2912
;; 19 16 time: 746 cpu: 747 gc: 0 mem: 2912
;; 19 16 time: 749 cpu: 750 gc: 0 mem: 2912
;; 20 16 time: 637 cpu: 637 gc: 0 mem: 2912
;; 20 16 time: 635 cpu: 635 gc: 0 mem: 2912
;; 21 16 time: 653 cpu: 653 gc: 0 mem: 2912
;; 21 16 time: 650 cpu: 650 gc: 0 mem: 2912
;; 22 16 time: 687 cpu: 687 gc: 0 mem: 2912
;; 22 16 time: 689 cpu: 688 gc: 0 mem: 2912
;; 23 16 time: 716 cpu: 716 gc: 0 mem: 2912
;; 23 16 time: 714 cpu: 714 gc: 0 mem: 2912
;; 24 16 time: 646 cpu: 646 gc: 0 mem: 2912
;; 24 16 time: 646 cpu: 646 gc: 0 mem: 2912
;; 25 16 time: 657 cpu: 656 gc: 0 mem: 2912
;; 25 16 time: 660 cpu: 661 gc: 0 mem: 2912
;;  8 16 time: 649 cpu: 649 gc: 0 mem: 2896
;;  9 16 time: 739 cpu: 738 gc: 0 mem: 2896
;; 10 16 time: 700 cpu: 701 gc: 0 mem: 2912
;; 11 16 time: 609 cpu: 609 gc: 0 mem: 2912
;; 12 16 time: 633 cpu: 633 gc: 0 mem: 2912
;; 13 16 time: 678 cpu: 678 gc: 0 mem: 2912
;; 14 16 time: 735 cpu: 735 gc: 0 mem: 2912
;; 15 16 time: 627 cpu: 627 gc: 0 mem: 2912
;; 16 16 time: 652 cpu: 653 gc: 0 mem: 2912
;; 17 16 time: 676 cpu: 677 gc: 0 mem: 2912
;; 18 16 time: 732 cpu: 732 gc: 0 mem: 2912
;; 19 16 time: 748 cpu: 748 gc: 0 mem: 2912
;; 20 16 time: 637 cpu: 637 gc: 0 mem: 2912
;; 21 16 time: 652 cpu: 653 gc: 0 mem: 2912
;; 22 16 time: 691 cpu: 691 gc: 0 mem: 2912
;; 23 16 time: 708 cpu: 708 gc: 0 mem: 2912
;; 24 16 time: 643 cpu: 643 gc: 0 mem: 2912
;; 25 16 time: 658 cpu: 657 gc: 0 mem: 2912
;; nil
;; arc> (do (ga full-malloc-testing5 6) (each h (join ([mappend list _ _] (range 4 25)) (range 8 25)) (gc) (sleep .5) (withs f (fn (x y z m u v) (pr (pad h 2) " ") (call-asm full-malloc-testing5 x y z m u v)) n (* 1000 (expt 2 20)) b make-bytes.n (time:do (pr (f b n 4096 h 1000 200000) " ")))))
;;  4 5100273664 time: 47 cpu: 47 gc: 0 mem: 5632
;;  4 5100273664 time: 46 cpu: 46 gc: 0 mem: 2896
;;  5 5100273664 time: 42 cpu: 42 gc: 0 mem: 2896
;;  5 5100273664 time: 42 cpu: 42 gc: 0 mem: 2896
;;  6 5100273664 time: 44 cpu: 44 gc: 0 mem: 2896
;;  6 5100273664 time: 45 cpu: 45 gc: 0 mem: 2896
;;  7 5100273664 time: 39 cpu: 39 gc: 0 mem: 2896
;;  7 5100273664 time: 39 cpu: 39 gc: 0 mem: 2896
;;  8 18446744073709551600 time: 701 cpu: 700 gc: 1 mem: 33096
;;  8 18446744073709551600 time: 704 cpu: 705 gc: 0 mem: 33096
;;  9 18446744073709551600 time: 759 cpu: 758 gc: 1 mem: 33096
;;  9 18446744073709551600 time: 764 cpu: 764 gc: 1 mem: 33096
;; 10 18446744073709551600 time: 815 cpu: 814 gc: 1 mem: 33096
;; 10 18446744073709551600 time: 814 cpu: 814 gc: 1 mem: 33096
;; 11 18446744073709551600 time: 663 cpu: 663 gc: 0 mem: 33096
;; 11 18446744073709551600 time: 673 cpu: 673 gc: 1 mem: 33096
;; 12 18446744073709551600 time: 678 cpu: 678 gc: 1 mem: 33096
;; 12 18446744073709551600 time: 700 cpu: 700 gc: 1 mem: 33096
;; 13 18446744073709551600 time: 855 cpu: 854 gc: 1 mem: 33096
;; 13 18446744073709551600 time: 847 cpu: 848 gc: 1 mem: 33096
;; 14 18446744073709551600 time: 873 cpu: 873 gc: 1 mem: 33096
;; 14 18446744073709551600 time: 865 cpu: 865 gc: 1 mem: 33096
;; 15 18446744073709551600 time: 1036 cpu: 1036 gc: 1 mem: 33096
;; 15 18446744073709551600 time: 1031 cpu: 1032 gc: 1 mem: 33096
;; 16 18446744073709551600 time: 1051 cpu: 1050 gc: 1 mem: 33096
;; 16 18446744073709551600 time: 1049 cpu: 1049 gc: 1 mem: 33096
;; 17 18446744073709551600 time: 721 cpu: 721 gc: 1 mem: 33096
;; 17 18446744073709551600 time: 717 cpu: 717 gc: 1 mem: 33096
;; 18 18446744073709551600 time: 766 cpu: 766 gc: 0 mem: 33096
;; 18 18446744073709551600 time: 761 cpu: 760 gc: 0 mem: 33096
;; 19 18446744073709551600 time: 806 cpu: 806 gc: 1 mem: 33096
;; 19 18446744073709551600 time: 806 cpu: 806 gc: 1 mem: 33096
;; 20 18446744073709551600 time: 685 cpu: 685 gc: 0 mem: 33096
;; 20 18446744073709551600 time: 680 cpu: 680 gc: 1 mem: 33096
;; 21 18446744073709551600 time: 680 cpu: 681 gc: 1 mem: 33096
;; 21 18446744073709551600 time: 675 cpu: 675 gc: 1 mem: 33096
;; 22 18446744073709551600 time: 783 cpu: 784 gc: 0 mem: 33096
;; 22 18446744073709551600 time: 776 cpu: 776 gc: 1 mem: 33096
;; 23 18446744073709551600 time: 867 cpu: 866 gc: 1 mem: 33096
;; 23 18446744073709551600 time: 860 cpu: 861 gc: 1 mem: 33096
;; 24 18446744073709551600 time: 1105 cpu: 1105 gc: 1 mem: 33096
;; 24 18446744073709551600 time: 1101 cpu: 1102 gc: 1 mem: 33096
;; 25 18446744073709551600 time: 1173 cpu: 1172 gc: 1 mem: 33096
;; 25 18446744073709551600 time: 1169 cpu: 1169 gc: 1 mem: 33096
;;  8 18446744073709551600 time: 706 cpu: 705 gc: 1 mem: 33096
;;  9 18446744073709551600 time: 762 cpu: 762 gc: 0 mem: 33096
;; 10 18446744073709551600 time: 807 cpu: 806 gc: 1 mem: 33096
;; 11 18446744073709551600 time: 662 cpu: 662 gc: 1 mem: 33096
;; 12 18446744073709551600 time: 684 cpu: 684 gc: 1 mem: 33096
;; 13 18446744073709551600 time: 853 cpu: 853 gc: 0 mem: 33096
;; 14 18446744073709551600 time: 858 cpu: 858 gc: 1 mem: 33096
;; 15 18446744073709551600 time: 1032 cpu: 1032 gc: 1 mem: 33096
;; 16 18446744073709551600 time: 1046 cpu: 1045 gc: 1 mem: 33096
;; 17 18446744073709551600 time: 719 cpu: 720 gc: 1 mem: 33096
;; 18 18446744073709551600 time: 769 cpu: 768 gc: 1 mem: 33096
;; 19 18446744073709551600 time: 809 cpu: 809 gc: 1 mem: 33096
;; 20 18446744073709551600 time: 678 cpu: 678 gc: 0 mem: 33096
;; 21 18446744073709551600 time: 674 cpu: 675 gc: 1 mem: 33096
;; 22 18446744073709551600 time: 778 cpu: 777 gc: 0 mem: 33096
;; 23 18446744073709551600 time: 857 cpu: 856 gc: 1 mem: 33096
;; 24 18446744073709551600 time: 1112 cpu: 1111 gc: 1 mem: 33096
;; 25 18446744073709551600 time: 1170 cpu: 1170 gc: 1 mem: 33096
;; nil
;; arc> ;that was with negatives
;; (- (expt 2 64) 18446744073709551600)
;; 16
        
        
        

        ;; Results are in.

;; arc> (do (ga full-malloc-testing3 6) (each h (join (range 0 12) (mappend list (range 0 12) (range 0 12))) (gc) (withs f (fn (x y z m u v) (pr h " ") (call-asm full-malloc-testing3 x y z m u v)) n (* 1000 (expt 2 20)) b make-bytes.n (time:do (pr (f b n 4096 h 1000 20000) " ")))))
;; 0 16 time: 42 cpu: 42 gc: 0 mem: 3552
;; 1 16 time: 55 cpu: 55 gc: 0 mem: 816
;; 2 16 time: 41 cpu: 42 gc: 0 mem: 816
;; 3 16 time: 48 cpu: 48 gc: 0 mem: 816
;; 4 6174015488 time: 47 cpu: 46 gc: 0 mem: 816
;; 5 6174015488 time: 41 cpu: 40 gc: 0 mem: 816
;; 6 6174015488 time: 43 cpu: 43 gc: 0 mem: 816
;; 7 6174015488 time: 39 cpu: 39 gc: 0 mem: 816
;; 8 16 time: 53 cpu: 52 gc: 0 mem: 816
;; 9 16 time: 114 cpu: 113 gc: 0 mem: 816
;; 10 16 time: 52 cpu: 52 gc: 0 mem: 816
;; 11 16 time: 51 cpu: 51 gc: 0 mem: 816
;; 12 16 time: 111 cpu: 111 gc: 0 mem: 816
;; 0 16 time: 42 cpu: 42 gc: 0 mem: 816
;; 0 16 time: 41 cpu: 41 gc: 0 mem: 816
;; 1 16 time: 55 cpu: 55 gc: 0 mem: 816
;; 1 16 time: 55 cpu: 55 gc: 0 mem: 816
;; 2 16 time: 40 cpu: 40 gc: 0 mem: 816
;; 2 16 time: 41 cpu: 40 gc: 0 mem: 816
;; 3 16 time: 41 cpu: 41 gc: 0 mem: 816
;; 3 16 time: 42 cpu: 42 gc: 0 mem: 816
;; 4 6174015488 time: 45 cpu: 44 gc: 0 mem: 816
;; 4 6174015488 time: 45 cpu: 45 gc: 0 mem: 816
;; 5 6174015488 time: 41 cpu: 40 gc: 0 mem: 816
;; 5 6174015488 time: 41 cpu: 40 gc: 0 mem: 816
;; 6 6174015488 time: 42 cpu: 43 gc: 0 mem: 816
;; 6 6174015488 time: 43 cpu: 44 gc: 0 mem: 816
;; 7 6174015488 time: 39 cpu: 39 gc: 0 mem: 816
;; 7 6174015488 time: 40 cpu: 39 gc: 0 mem: 816
;; 8 16 time: 53 cpu: 53 gc: 0 mem: 816
;; 8 16 time: 53 cpu: 54 gc: 0 mem: 816
;; 9 16 time: 114 cpu: 115 gc: 0 mem: 816
;; 9 16 time: 113 cpu: 114 gc: 0 mem: 816
;; 10 16 time: 51 cpu: 51 gc: 0 mem: 816
;; 10 16 time: 51 cpu: 51 gc: 0 mem: 816
;; 11 16 time: 52 cpu: 53 gc: 0 mem: 816
;; 11 16 time: 52 cpu: 51 gc: 0 mem: 816
;; 12 16 time: 112 cpu: 113 gc: 0 mem: 816
;; 12 16 time: 111 cpu: 111 gc: 0 mem: 816
;; nil
        
        ;; 9 and 12 suck ass,
        ;; meaning c[ad]r_[25] suck ass.
        ;; So that mask thing is a terrible idea.
        ;; Drop the fuck out of it.
        ;; Leave the usage and the numbers but drop the code, that shit takes up space.





        


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

        
