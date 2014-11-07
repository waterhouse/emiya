

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
        %define PAGELIMIT qword [page_alloc_ptr]  ;jesus
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
        
        ;; [semispaces.asm]

        ;; %include "./semispaces2.asm"

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
        cmp ALLOCPTR, [page_limit]
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
        mov ALLOCPTR, [page_limit]
        mov rsi, [page_size]
        add rsi, ALLOCPTR
        cmp rsi, [tospace_top]  ;would be a GC flip, or would die if both need gc flip and gc work
        jg epic_failure
        mov [page_limit], rsi
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
        mov ALLOCPTR, [page_limit]
        mov rdi, [page_size]
        add rdi, ALLOCPTR
        cmp rdi, [tospace_top]
        jg epic_failure         ;same stack layout
        mov [page_limit], rdi

subrout_cons_rdi_code:
        lea rdi, [ALLOCPTR + CONS_TAG]
        add ALLOCPTR, 16
        cmp ALLOCPTR, [page_limit]             ;"page" limit
        jg subrout_cons_rdi_overflow
        ret

        %macro subrout_cons_rdi 0
        call subrout_cons_rdi_code
        %endmacro


        
        ;; as in "Look Aside" [nope]
        ;; having the usual code involve a jump
        %macro aside_cons_rdi 0
        lea rdi, [rcx + CONS_TAG]
        add rcx, 16
        cmp rcx, r9
        jng %%k
        call subrout_cons_rdi_overflow
%%k:    
        %endmacro        


        
        
        


actual_code:


        ;; mov rax, [memory_bottom]
        
        ;; jmp return


        ;; For the moment, car and cdr will just be noobish.
        %macro car 2
        mov %1, [%2 - CONS_TAG]
        %endmacro
        %macro cdr 2
        mov %1, [%2 - CONS_TAG + 8]
        %endmacro



        ;; paltry parameter list atm
        %macro the_program 2

        ;; Give names to the parameters.
        %define name %1
        %define cons_rdi %2


        ;; %define car whatever

        ;; ;;First, cons up the initial list...

        ;; ;;a = r8, b = r9

        ;; r8 = count

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

        dec r8
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

        mov rax, 555
        jmp return
        
        cmp rcx, 1
        je subrout_approach
        cmp rcx, 2
        je aside_approach
        cmp rcx, 3
        je noob_approach


lea_approach:
        ;; mov rax, 666
        ;; jmp return
        the_program xxx, lea_cons_rdi

subrout_approach:
        the_program yyy, subrout_cons_rdi
aside_approach:
        the_program zzz, aside_cons_rdi
noob_approach:
        ;; the_program ...

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

        
