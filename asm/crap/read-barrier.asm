

        ;; Testing read barrier.



        mov rax, 0xfffefafd

        ;; make-bytes.n in rdi, n in rsi,
        ;; random number seed in rdx,
        ;; mode in rcx.

        ;; Ok, we should permute ... fuck.  Hmmph.
        ;; Fine, too lazy and can do it in Arc.


        ;; bytes in rdi, n in rsi.
        ;; n is number of dicks. bytes has size 16n.
        ;; mode in rdx.
        ;; ... um, what in rdx?  feh.
        ;; fine, I'll just replace.

        ;; hmm... a program that expects to manipulate
        ;; numbers could conceivably reduce the read barrier
        ;; to a type check--if it gets a pointer, ...
        ;; mmm, hmm. I guess bignums will be rep'd with ptrs.
        ;; but dick.
        ;; now... it could be a list of conses whose cars
        ;; are numbers. that'd be another thing.

        ;; I'll also prob. want to test an array, although
        ;; ... a smart compiler should be like "if I'm iter'ing
        ;; through an array, I may as well ..."
        ;; um, hmm... ok, that would be like optimizing away
        ;; a length check. not the read barrier-ish-ness.
        ;; yeah, iter'ing through an array should be a test
        ;; too.
        ;; Should exp. with different sizes of n.
        ;; ... oh man, I'll be checking cdrs too...

        ;; Fuck, it's difficult for the Arc to make things into genuine ptrs,
        ;; rather than offsets from front of array.
        ;; The asm shall have to do that work.
        ;; Which will change the timing results slightly.
        ;; Therefore, I must take the difference of the times.

        ;; Um, the given ptr isn't tagged the way conses normally are.
        add rdi, 1

        cmp rdx, 0
        je only_ptrs            ;only turn offsets to ptrs
        cmp rdx, 1
        je no_checking          ;no read barrier, no typecheck
        cmp rdx, 2
        je typecheck_a           ;typecheck: special: test 110, jnz, test 001, jz
        cmp rdx, 3
        je typecheck_b          ;typecheck: load 111, and, jz ;uses reg
        cmp rdx, 4
        je typecheck_c          ;typecheck: xor 001, test 111, jnz ;changes ptr
        ;; cmp rdx, 5
        ;; je typecheck_general    ;unknown, but will load integer for returning

        ;; ;; hey, it's actually the same issue with typechecks as with read barriers.
        ;; ;; with a plain conditional jump for error, return addr must know how to get back.
        ;; ;; mmm.
        ;; cmp rdx, 3
        ;; je teh_barrier_a          ;read barr, typecheck, car encoded
        ;; cmp rdx, 4
        ;; je teh_barrier_b


        
        ;; cmp rdx, 3
        ;; je horrible_barrier     ;read barr, typecheck, car as subroutine

        ;; ;; Now I recall more code-size issues.
        ;; ;; If we have a plain conditional jump into an error place, then
        ;; ;; we must have a separate error place for each test.
        ;; ;; (Like, "test; jnz must_move; do-dicks" => the must_move place
        ;; ;;  must know to jump back to the do-dicks place.
        ;; ;;  If one block of code has multiple places where it uses a read
        ;; ;;  barrier, then there must be multiple must_move places, so that
        ;; ;;  the must_move place knows where to jump back to.
        ;; ;;  An alternative approach is to leave evidence in registers about
        ;; ;;  which place you must jump back to.
        ;; ;;  I could reserve a register for that shit... with 16 or 32 regs,
        ;; ;;  that's probably not too bad... also it doesn't need to happen
        ;; ;;  in all blocks of code, only those that want to economize...)
        
        ;; cmp rdx, 5
        ;; je barrier_with_bad_branching ;read barr: "test; jz no_move; call move; no_move: ..."
        ;; cmp rdx, 6
        ;; ;; je barrier_with_counting ;read barr: annotate where to jump back to by... lolz
        ;; ;; if you have up to 2^32 read barriers in your code, then one constant,
        ;; ;; installable with a "mov reg, [const]", is enough to identify where to jump
        ;; ;; back to, globally. like a return address.
        ;; ;; this is awesome and terrible.
        ;; ;; would need to update shit when moving shit, but oh well.
        ;; je barrier_with_return_id

        
only_ptrs:
        call ptrify
        mov rax, rdi
        ret

ptrify:
        ;; rdi = bytes, rsi = n
        ;; for convenience, we shall leave nil as 0.
        ;; ... not sure if nil would be rep'd as 0 or as
        ;; something like -3 or as an address that would be
        ;; kept in memory...
        ;; whatever.
        ;; (hmm, can't be negative, that'd fail the fromspace test)

        mov rdx, rdi
        mov rcx, rsi
        ;; shl rcx, 4
ptrify_loop:
        add [rdx+7], rdi        ;tagged
        add rdx, 16
        dec rcx
        jnz ptrify_loop
        ret

no_checking:
        
        call ptrify
        xor eax, eax

        
no_checking_loop:       
        add rax, [rdi-1]
        mov rdi, [rdi+7]
        dec rsi
        jnz no_checking_loop
        ret

        ;; ok, how do I do my type-check?
        ;; bweheheh.  when the tag happens to have only one 1 bit,
        ;; I can try this...

        ;; ... oh.  must test dicks...

typecheck_a:    
        call ptrify
        xor eax, eax
typecheck_a_loop:
        test rdi, 6
        jnz typecheck_a_fail
        test rdi, 1
        jz typecheck_a_fail
        mov rcx, [rdi-1]
        test cl, 7
        jnz typecheck_a_fail
        add rax, rcx
        jc typecheck_a_carry
        mov rdi, [rdi+7]
        dec rsi
        jnz typecheck_a_loop
        ret
typecheck_a_fail:
        mov rax, 691
        ret
typecheck_a_carry:
        mov rax, 671
        ret

typecheck_b:    
        call ptrify
        xor eax, eax
typecheck_b_loop:
        mov cl, 7
        and cl, dil
        cmp cl, 1
        jnz typecheck_b_fail
        mov rdx, [rdi-1]
        test dl, 7
        jnz typecheck_b_fail
        add rax, rdx
        jc typecheck_b_carry
        mov rdi, [rdi+7]
        dec rsi
        jnz typecheck_b_loop
        ret
typecheck_b_fail:
        mov rax, 692
        ret
typecheck_b_carry:
        mov rax, 672
        ret


typecheck_c:
        call ptrify
        xor eax, eax
typecheck_c_loop:
        xor rdi, 1
        test rdi, 7
        jnz typecheck_c_fail
        mov rdx, [rdi]
        test dl, 7
        jnz typecheck_c_fail
        add rax, rdx
        jc typecheck_c_carry
        mov rdi, [rdi+8]
        dec rsi
        jnz typecheck_c_loop
        ret
typecheck_c_fail:
        mov rax, 693
        ret
typecheck_c_carry:
        mov rax, 673
        ret

        



        








        


        ;; je typecheck_a           ;typecheck: special: test 110, jnz, test 001, jz
        ;; je typecheck_b          ;typecheck: load 111, and, jz ;uses reg
        ;; je typecheck_c          ;typecheck: xor 001, test 111, jnz ;changes ptr

        