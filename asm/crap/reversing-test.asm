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
        %define RAX_MASK 1
        %define RBX_MASK 2
        %define RCX_MASK 4
        %define RDX_MASK 8
        %define RDI_MASK 16
        %define RSI_MASK 32
        %define RBP_MASK 64
        %define RSP_MASK 128
        %define R8_MASK 256
        %define R9_MASK 512
        %define R10_MASK 1024
        %define R11_MASK 2048
        %define R12_MASK 4096
        %define R13_MASK 8192
        %define R14_MASK 16384
        %define R15_MASK 32768
        
        

        jmp actual_code

        ;; Library shit...

        %include "gc-system2.asm"

        
plain_ret:      ret


        ;; Definitions for BS crap will appear here.
        ;; 'Cause macros need to be defined before you use them.




        ;; uses rax
        %macro swap 2
        mov rax, %1
        xchg rax, %2
        mov %1, rax
        %endmacro

        ;; also we don't need to care about gc work yet
        
gc_flip:
        push rax

        add qword [gc_flip_count], 1
        
        
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


        ;; All right, time to stop cheating.
        ;; ..............
        ;; Next iteration.
        ;; Or even a different file name, because ...
        ;; Mmm.

        
        
        mov rax, rcx
        call possibly_move_rax
        mov rcx, rax
        mov rax, rdx
        call possibly_move_rax
        mov rdx, rax
        
gc_flip_done_moving:

        ;; mov rax, 69
        ;; jmp return

        ;; add qword [gc_flip_count], 1

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
        add r15, PAGELIMIT
        cmp r15, [tospace_top]
        ja out_of_memory
        mov PAGELIMIT, r15
        jmp not_lucky
        
out_of_memory:
        mov rax, 666
        ;; mov rax, [gc_flip_count]
        ;; mov rax, r15
        ;; sub rax, [tospace_top]
        ;; add rax, [tospace_bottom]
        ;; sub rax, [tospace_top]
        
        jmp return
        ;; oh dear, we're hitting this a lot atm
        ;; when we should not


        



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

gc_flip_count:
        dq 0
                


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

        ;; Removing excess.

        ;; By the way, one could have fromspace_mask *usually* stored in one of the
        ;; r14 or r15 registers that we'll probably reserve for read barrier moving shit.
        ;; Then movements could restore that if they destroy it.
        ;; Eh.
        
        
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



        
        



        ;; the cheapo things that don't barr will use this
dont_move_stuff:  dq 0
        
        


actual_code:

        mov qword [gc_flip_count], 0


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

        %endmacro



        ;; So, we do that, and we'll


        mov qword [dont_move_stuff], 1
        mov qword [dont_move_stuff], 0
        

        cmp rcx, 0
        je lea_car4
        cmp rcx, 1
        je lea_car5
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

        the_program lea_car4, lea_cons_rdi, car_4, cdr_4
        the_program lea_car5, lea_cons_rdi, car_5, cdr_5

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


        
        
        
