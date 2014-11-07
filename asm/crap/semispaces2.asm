

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
        
