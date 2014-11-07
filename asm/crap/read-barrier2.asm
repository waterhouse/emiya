

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
        ;; reps in rcx.

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

        mov r8, rcx
        mov r9, rdx
        mov r10, rdi
        mov r11, rsi
        call ptrify
        
metaloop:
        mov rdx, r9
        call metastep
        dec r8
        mov rdi, r10
        mov rsi, r11
        
        jnz metaloop
        ret

metastep:       
        
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
        cmp rdx, 5
        je typecheck_car        ;car, cdr as subroutines
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
        xor eax, eax
typecheck_c_loop:
        xor dil, 1
        test dil, 7
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

typecheck_car:
        xor eax, eax
typecheck_car_loop:     
        call checked_car_rdi_rcx
        test cl, 7
        jnz typecheck_car_fail
        add rax, rcx
        jc typecheck_car_carry
        call checked_cdr_rdi_rcx
        mov rdi, rcx
        dec rsi
        jnz typecheck_car_loop
        ret

typecheck_car_fail:
        mov rax, 694
        ret
typecheck_car_carry:
        mov rax, 674
        ret
        
checked_car_rdi_rcx:
        mov cl, 7
        and cl, dil
        cmp cl, 1
        jne checked_car_fail
        mov rcx, [rdi-1]
        ret

checked_car_fail:
        mov rax, 694

checked_cdr_rdi_rcx:
        mov cl, 7
        and cl, dil
        cmp cl, 1
        jne checked_cdr_fail
        mov rcx, [rdi+7]
        ret

checked_cdr_fail:
        mov rax, 694

        



        ;; well, this is a little weird, but not much:
        ;; with N as 1M, there is no detectable difference between 1-4.
        ;; (about 1046 msec for 20 reps)
        ;; then...
        ;; we shall see about smaller N.
        ;; N=1000; 800k reps
        ;; 1: 1008
        ;; 2: 1266
        ;; 3: 1011
        ;; 4: 1502

        ;; N=10; 80M reps
        ;; 1: 903
        ;; 2: 1444
        ;; 3: 1228
        ;; 4: 1258

        ;; damn, wtf?

        ;; N=100; 8M reps
        ;; 1:974
        ;; 2:1344
        ;; 3:1086
        ;; 4:1498

        ;; N=10k; 20k reps
        ;; about 812 for 1-3, 960 for 4

        ;; N=100k; 2k reps
        ;; about 1070 for all

        ;; hmm...
        ;; and it was sometimes 1500 for #1...
        ;; hmm...
        ;;
        ;; so things like this...
;;         arc> (do l.read-barr2 (ga read-barrier2 4) (= N 100000 k 1000 g time:nerb.N h time:make-narb.g) (prn:* g.1 8) (time:read-barrier2-thing read-barrier2 h N 2 k))
;; time: 39 cpu: 39 gc: 0 mem: 2469664
;; time: 20 cpu: 20 gc: 0 mem: 3202624
;; 50818176
;; time: 1082 cpu: 1082 gc: 0 mem: 2912
;; 50818176

        ;; with "h N 1 k" there, I get 1500 some of the time (maybe 1/4).
        ;; so far, I haven't managed to get very high except 1200-ish once with 2.
        ;; ... well, fuck, whatever.

        ;; ok, so, I've learned that that XOR approach is probably bad.
        ;; convenient, because it's also el stupido.
        ;; ................. except it is better at low numbers.
        ;; jez'.

        ;; N=4, k=120M:
;;         arc> (each x '(1 1 1 2 2 2 3 3 3 4 4 4) (do (= h make-narb.g) (pr x " ") (time:read-barrier2-thing read-barrier2 h N x k)))
;; 1 time: 674 cpu: 673 gc: 0 mem: 160
;; 1 time: 675 cpu: 674 gc: 0 mem: 160
;; 1 time: 669 cpu: 668 gc: 0 mem: 160
;; 2 time: 1023 cpu: 1023 gc: 0 mem: 160
;; 2 time: 1022 cpu: 1023 gc: 0 mem: 160
;; 2 time: 1027 cpu: 1027 gc: 0 mem: 160
;; 3 time: 930 cpu: 930 gc: 0 mem: 160
;; 3 time: 934 cpu: 934 gc: 0 mem: 160
;; 3 time: 931 cpu: 931 gc: 0 mem: 160
;; 4 time: 888 cpu: 888 gc: 0 mem: 160
;; 4 time: 894 cpu: 895 gc: 0 mem: 160
;; 4 time: 889 cpu: 889 gc: 0 mem: 160

        ;; what do we make of that.
        ;; hmmph.
        ;; well, at least, #3, which seems prob' the best in terms of dick.
        ;; ok, in #4, replacing rdi with dil in a test and an xor.
        ;; ... mmm, seems eqv at N=4, ... and at N=1k and 100k.
        ;; probably eqv always.
        ;; then...
        ;; [incidentally, throughout this, the cost of installing ptrs is about
        ;;  nil compared to the rest]

        ;; hmm...
        ;; well, read barriers...
        ;; oh, one more.
        ;; car by itself.

        ;; hmm. with very short reps, prob. will be biased against later ones.
        ;; oh well.

        ;; Ok, so, with ca/dr as subroutine:
        ;; Small lists (<= 100):
        ;; 1 = 1
        ;; 2 = 1.6
        ;; 3 = 1.4
        ;; 4 = 1.3
        ;; 5 = 3.5

        ;; Medium (1k):
        ;; 1 = 1
        ;; 2 = 1.25
        ;; 3 = 1
        ;; 4 = 1.5
        ;; 5 = 3

        ;; Big (10k):
        ;; 1 = 1
        ;; 2 = 1
        ;; 3 = 1
        ;; 4 = 1.2
        ;; 5 = 1.1

        ;; Huge (>= 100k):
        ;; 1 = 1
        ;; 2 = 1
        ;; 3 = 1
        ;; 4 = 1.05
        ;; 5 = 1
        

        ;; Looks like 3 is a pretty safe option...
        ;; Though an uber-compiler could try changing which, based on runtime info...
        ;; Anyway.
        ;; I'll add a fake read barrier next.
        ;; That'll probably change things.
        ;; ...
        ;; Ok, so.
        ;; Few approaches to read barrier itself.
        ;; 1. test reg, [r15 + n] ;stored in memory somewhere
        ;; 2. test reg, xxxx ;stored in code; must recompile upon resizing, and
        ;;    must abandon this approach when you use more than 2^32 bytes of memory
        ;; 3. test reg, reg ;stored in a register, possibly loaded from memory upon
        ;;    entry to a function or something. this could be combined with the mailbox,
        ;;    actually--lolz.
        ;; 4. bt reg, [r15 + n] ;only works with 1-bit identification of fromspace
        ;; 5. bt reg, xx ;stored in code; must recompile upon resizing
        ;; 6. bt reg, reg ;like test

        ;; And do note that, in this case, ...
        ;; Actually, even with bignums, we can put off the read barrier until after
        ;; the type check.
        ;; Hmm.  Is there any advantage to having a fwd ptr point to something of different
        ;; type?

        ;; And then, of course, there is the thing of where to return to...
        ;; Let's see.  I think I'll test the effects on #3...
        ;; ... somewhat terrible but oh well.

        ;; And #2 has never performed better than #3 and it's not general-purpose.
        ;; Its single advantage is not consuming a register.
        ;; Which... is probably not significant with 16 registers.
        ;; Will drop.


        