        ;; [semispaces.asm]


        ;; This program...
        ;; We shall have a bunch of eqv portions of code...
        ;; I guess I could have something amount to unrolling the loop of the prev. program.
        ;; But neh.

        ;; Ooh............
        ;; Exponentiation... perhaps modexp, perhaps not.
        ;; And doing it by always allocating new crap, rather than using old things.
        ;; Let's see...

        ;; Smallish bignums.
        ;; Take a b c d e ... neh.
        ;; Hardcode...
        ;; ...
        ;; Too inefficient...
        ;; Ooh, how about really stupid continuation-based recursion or something?
        ;; Would be good.
        ;; Then...
        ;; ...
        ;; A deeply forested "sum of squares"?
        ;; Sure.

        ;; ...
        ;; Feh.
        ;; Fibonacci.
        ;; Ok.
        ;; Possibly useful for "practice", anyway.



        ;; A few macros need to go at the top.

        %define RAX_MASK 1
        %define RBX_MASK 2
        %define RCX_MASK 4
        %define RDX_MASK 8
        %define RDI_MASK 16
        %define RSI_MASK 32

        %define CONS_TAG 3
        %define CLOS_TAG 5
        ;; Let's say that ints are 000 and chars are 100.
        ;; Then the ptr mask is 011.
        %macro ptr_test 1
        test %1, 3
        %endmacro
        ;; Doesn't include ptr test.
        %macro fromspace_test 1
        test %1, [fromspace_mask]
        %endmacro
        ;; these actually have to return their result in RFLAGS
        ;; because you might want to "jump if" or "jump if not"

        ;; These I can define here, may as well.
        ;; --They will move qwords.  Convenient.
        %macro scar 2
        mov qword [%1 - CONS_TAG], %2
        %endmacro
        %macro scdr 2
        mov qword [%1 - CONS_TAG + 8], %2
        %endmacro


        %define CONT_REG rbp    ;why not; similar sort of role
        ;; in multithreaded, rbx should hold a bunch of shit
        ;; but for now, let's use it thus.
        %define ALLOCPTR rbx
        ;; %define page_limit qword [page_alloc_ptr] ;sigh, whatever
        ;; %define PAGELIMIT qword [page_alloc_ptr]  ;jesus
        %define PAGELIMIT r12   ;swap these out for testing
        
        ;; Generally I'll try to follow the C calling convention,
        ;; methinks... ... really?
        ;; Well, meh.
        ;; We'll see.


        

        ;; Sum of ints^2^n mod 2^64 or smthg.
        ;; Achieved by making a big list, then repeatedly "map square"ing it.

        ;; Actually, I'm thinking this will create a bunch of garbage,
        ;; esp. if I use continuations,
        ;; and I am tempted to make it GC.
        ;; Real-time, of course; but might even compare.
        ;; (I could make a huge macro that is the entire text of the program,
        ;;  and pass it various shit to test diff. shit.  That'd be bretty good.)
        ;; (General convention: if macros use a scratch register, rax is a good choice.)

        ;; Closures?
        ;; Field ... for ...
        ;; ...
        ;; Hmm, for this crap I'd need ...
        ;; ...
        ;; Fuck.
        ;; Well.

        

        ;; mode
        ;; memory
        ;; len
        ;; page
        ;; a
        ;; b

        default rel

        ;; How do I ensure alignment?
        ;; Right.
        
        ;; align 8
        ;; mov rax, 0xfffefafd
        ;; jmp actual_code
        ;; align 8
        ;; ;; Now this is aligned.
        ;; You idiot, it's not necessarily.

        align 8
        nop
        nop
        nop
        mov rax, 0xfffefafd
        align 8                 ;Should code for nothing.

        ;; Just to test...
        ;; lea rax, [page_alloc_ptr]
        ;; ret

        ;; So, we'll be passed some args.
        ;; rdi = buffer
        ;; rsi = len
        ;; rdx = page_len
        ;; others = args...

        ;; Setup...
        ;; We'll waste up to half of memory, methinks.
        ;; [Initially, can punt and just die on GC flip.]
        ;; Actually, we don't really have to do that...
        ;; Not too hard to 

        mov [memory_bottom], rdi
        lea rax, [rdi + rsi]
        mov [memory_top], rax
        ;; now compute our spaces
        ;; ... At any rate, we will have to learn where the
        ;; power-of-2 boundaries are.
        ;; ... We could demand to be passed a power of 2 as the len.
        ;; Sure, why not.
        ;; Next.
        ;; We can use r10 and r11...

        ;; Sigh, shl needs registers as second argument to be cl.
        ;; Terrible.
        push rcx
        bsr rcx, rsi
        ;; if r10 = n, then rsi is between 2^n and 2^n+1 - 1.
        mov r11, 1
        shl r11, cl            ;r11 = 2^n
        pop rcx                ;jesus christ
        ;; Now, for a dumb approach that works,
        ;; we try to find the largest 2^m such that you can fit two
        ;; blocks of size 2^m between "memory_bottom rounded up to a
        ;;  multiple of 2^m" and memory_top.
        ;; m should be either n-1 or n-2.


        ;; DISREGARD ALL THAT
        ;; We need something more than that: 01xxx for one region, 10xxx for another.
        ;; So...
        ;; We need:
        ;; largest 2^m such that:
        ;; ... Actually, 011xxx and 100xxx would work too.
        ;; We want a low bit, which corresponds to the actual size of the semispaces,
        ;; and a high bit that is also different.
        ;; We can get the high bit by adding and ANDing and BSFing or something.
        ;; So, let's see.
        ;; Beginning of the low semispace should be yyy1000 [1 at position m].
        ;; Then we want that + 2^(m+1) <= memory_top.
        ;; And that >= memory_bottom.
        ;; So...
try_again:
        mov rdi, [memory_bottom] ;redundant first time around
        lea rsi, [r11 - 1]      ;2^n - 1: 0000001111
        mov r10, 0
        sub r10, r11            ;   -2^n: 1111110000
        shr r11, 1              ;    2^m: 0000001000
        and rdi, r10            ;         yyyyyy0000
        add rdi, r11            ;         yyyyyy1000
        cmp rdi, [memory_bottom]
        ;; by this point it's possible that r11 is small enough that we can
        ;; fit a bunch of blocks in our given chunk of memory.
        ;; in that case, we look at:      (yy+1)1000
        ;; for our starting position.
        jnb dont_add
        sub rdi, r10            ;how real men add
dont_add:
        sub rdi, r10            ;         (yy+1)1000
        cmp rdi, [memory_top]
        ja try_again
        ;; Wootz.
        ;; At this point:
        ;; r11 = block size.
        ;; r10 = -2 * block_size.
        ;; rdi = top of block-pair
        ;;     = bottom of block-pair + 2*block_size.
        mov [fromspace_top], rdi
        sub rdi, r11
        mov [fromspace_bottom], rdi
        mov [tospace_top], rdi
        sub rdi, r11
        mov [tospace_bottom], rdi

        ;; As for the masks?
        ;; The "tospace mask" (i.e. what the fromspace mask will be after
        ;;  a GC flip) is 2^m.
        mov [tospace_mask], r11
        ;; The "fromspace mask" is the single (high) bit that is set
        ;; in the "fromspace_bottom" thing but not the "tospace_bottom"
        ;; thing.
        ;; This can be computed by ....
        ;; Complementing tospace_bottom, then ANDing with fromspace_bottom.
        mov rsi, -1             ;111111
        sub rsi, rdi            ;110100 ;eqv to xor
        and rsi, [fromspace_bottom]
        ;; Now, just to be sure, we *could* check that that ain't 0.
        jz either_math_is_wrong_or_user_passed_dumb_args
        ;; (By the way, if the user did pass args like the length being smaller
        ;;  than 4 or so, or the buffer starting at 0 or something [nah, the
        ;;   latter isn't a problem], we might have already hit an infinite
        ;;  loop above.)
        mov [fromspace_mask], rsi


        ;; Now.
        ;; Initialization.
        ;; There's the usual alloc ptr, which I probably keep in a register;
        ;; the page alloc ptr, which is in memory;
        ;; the current page limit ptr, which in single-threaded is identical
        ;;  to the page alloc ptr;
        ;; and the page size thing, which should also be in memory.
        ;; Which register?
        ;; I'll put that kind of constant crap up above.
        mov [page_size], rdx
        add rdx, rdi
        mov [page_alloc_ptr], rdx
        mov PAGELIMIT, rdx      ;may be rendundant with above, but: for cheapo testing purposes
        mov ALLOCPTR, rdi


        ;; Now, we'll want to save various registers.
        ;; It'll be useful at this point to save the stack pointer
        ;; so that we can have emergency exits.
        push rbp
        push rbx
        push r12
        push r13
        push r14
        push r15
        mov [stack_ptr], rsp
        ;; Beyond this point, any rets must use the saved stack pointer,
        ;; and restore the above regs.

        ;; Anyway.
        ;; We're basically ready to rumble.

        ;; mov rax, [tospace_bottom]
        ;; sub rax, [memory_bottom]

        ;; mov rax, [stack_ptr]
        ;; mov rax, [page_alloc_ptr]
        ;; sub rax, [tospace_bottom]

        ;; mov rax, [fromspace_mask]
        ;; sub rax, [tospace_mask]
        ;; mov rax, ALLOCPTR
        ;; and rax, [fromspace_mask]

        
        ;; jmp return

        ;; You know, I can have this be "include"d.
        jmp real_code
        
        
        
        
        
        
        ;; Single-threaded: can put things in memory here.
        ;; Lessee...
        ;; Memory barrier crap: in registers or not?
        ;; (Also other issues.)
        ;; (page_limit in register? diff. versions of closures?)
        ;; Screw.

        ;; I should perhaps come up with a better word than "page"
        ;; so that it is distinct...
        ;; Neh.

        align 8
memory_bottom:  dq 0
memory_top:     dq 0
        ;; from this we compute
tospace_bottom: dq 0
tospace_top:    dq 0
fromspace_bottom:       dq 0
fromspace_top:  dq 0
        ;; [possibly also some "wraparound" shit]
        ;; [that could also be recomputed each time]

fromspace_mask: dq 0
        ;; Just for convenience, so it's a simple switch.
tospace_mask:   dq 0

page_limit:                     ;same thing in single-threaded as:
page_alloc_ptr: dq 0
        
page_size:      dq 0
stack_ptr:      dq 0

        

still_gcing:    dq 0            ;accualy is boolean ;or could be gc_stack eqv
gc_stack:       dq 0

        ;; I can certainly use the LEA trick for the barriers.
        ;; Probably more effective there, because there are multiple of them.





        
either_math_is_wrong_or_user_passed_dumb_args:
        mov rax, 69
        jmp return


return:
exit:   
emergency_exit:
        mov rsp, [stack_ptr]
        pop r15
        pop r14
        pop r13
        pop r12
        pop rbx
        pop rbp
        ret


real_code:      
        


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

        mov [fromspace_mask_table + 40], rax

        lea r14, [fromspace_mask_table + 24]
        mov [r14 + 0], rax
        jmp return
        ;; mov rax, 69
        ;; jmp return

        mov [fromspace_mask_table + 24], rax

        ;; The following blows up on 9
        ;; mov [fromspace_mask_table + 24], rax
        ;; mov rax, 69
        ;; jmp return
        
        ;; no 32; that's char
        mov [fromspace_mask_table + 40], rax
        mov rax, 69
        jmp return
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
        
        ;; jmp return

move_rax_cons:
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
        ;; cmp ALLOCPTR, PAGELIMIT
        ;; ja grab_moar
        mov [r15 - CONS_TAG], r14
        mov r14, [rax - CONS_TAG + 8]
        mov [r15 - CONS_TAG + 8], r14
        ;; make fwd ptr
        ;; mov r14, r15
        ;; bts r14, 63
        ;; ;; install
        ;; mov [rax - CONS_TAG], r14
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
        call possibly_move_rax
        pop r15
        mov [r15], rax
        ret

move_r8_at_r15:
        push r15
        xchg rax, r8
        call move_rax           ;it's this one
        pop r15
        mov [r15], rax
        xchg rax, r8
        ret

move_rcx_at_r15:
        push r15
        xchg rax, rcx
        call possibly_move_rax
        pop r15
        mov [r15], rax
        xchg rax, rcx
        ret

move_r8_at_r15_and_jmp_rax:
        jmp return
        ;; has nothing to do with this
        
        call move_r8_at_r15
        jmp rax
move_rcx_at_r15_and_jmp_rax:
        ;; is this
        ;; jmp return
        call move_r8_at_r15     ;EL PROBLEMO
        jmp rax
        ;; LOLMONEY
        ;; THE ABOVE IS AN ERROR
        ;; but that still doesn't explain why it dies where it does
        ;; how can writing to memory location N-8, N, and N+24 be fine,
        ;; but not N+8?
        ;; and how can that depend on ... something random and weird done with
        ;; some registers?
        ;; this is absolute fuck.
        ;; whatever.
        
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


        mov rax, 3
        mov r13, 0
        lea r14, [fromspace_mask_table]
        test r13, [r14 + 8*rax]
        jnz move_r8_at_r15_and_jmp_rax
        

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



        the_program aside_1, aside_cons_rdi, car_barr_tck, cdr_barr_tck
        the_program aside_2, aside_cons_rdi, car_barr_tck_2, cdr_barr_tck_2

        the_program lea_car1, lea_cons_rdi, car_1, cdr_2
        the_program lea_car2, lea_cons_rdi, car_2, cdr_2
        the_program lea_car3, lea_cons_rdi, car_3, cdr_3
        the_program lea_car4, lea_cons_rdi, car_4, cdr_4
        the_program lea_car5, lea_cons_rdi, car_5, cdr_5        

        jmp return



        ;; Test cases look like:
;; arc> (do (ga test-case 6) (each h (join (range 6 8) '(1 2) (range 9 12)) (gc) (withs f (fn (x y z m u v) (pr h " ") (call-asm test-case x y z m u v)) n (* 1000 (expt 2 20)) b make-bytes.n (time:do (pr (f b n 4096 h 1000 20000) " ")))))
;; 6 69 time: 46 cpu: 46 gc: 0 mem: 3552
;; 7 69 time: 40 cpu: 39 gc: 0 mem: 816
;; 8 69 time: 51 cpu: 51 gc: 0 mem: 816
;; 1 77 time: 0 cpu: 0 gc: 0 mem: 816
;; 2 77 time: 1 cpu: 0 gc: 0 mem: 816
;; 9 69 time: 57 cpu: 56 gc: 0 mem: 816
;; 10 69 time: 45 cpu: 45 gc: 0 mem: 816
;; 11 69 time: 43 cpu: 43 gc: 0 mem: 816
;; 12 69 time: 59 cpu: 59 gc: 0 mem: 816
;; nil
;; arc> (do (ga test-case 6) (each h (join (range 6 8) '(1 2) (range 9 12)) (gc) (withs f (fn (x y z m u v) (pr h " ") (call-asm test-case x y z m u v)) n (* 1000 (expt 2 20)) b make-bytes.n (time:do (pr (f b n 4096 h 1000 20000) " ")))))
;; 6 69 time: 45 cpu: 45 gc: 0 mem: 3552
;; 7 69 time: 41 cpu: 41 gc: 0 mem: 816
;; 8 
;; rlwrap: warning: arc killed by SIGSEGV.
;; rlwrap has not crashed, but for transparency,
;; it will now kill itself (without dumping core)with the same signal
        

        

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

        
