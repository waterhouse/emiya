

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

        push rbx

        ;; for testing xxxx things...
;;         arc> (num->digs 4398783577 2)
;; (1 0 0 0 0 0 1 1 0 0 0 1 1 0 0 0 0 0 0 0 1 1 1 0 0 0 1 0 1 1 0 0 1)
        ;; that's 33 bits.
        ;; so 2^31 + 2^30, i.e. 11000..., i.e. -0x40000000, is a test xxxx.
        ;; and 31 can be a bt xxxx.
        ;; eh, neh, write positively. I can.
        mov rbx, 0xc0000000
        mov [rsp - 40], rbx     ;must avoid sign extension of dicks

        mov rbx, rsp
        
        call ptrify
        
metaloop:
        mov rdx, r9
        call metastep
        dec r8
        mov rdi, r10
        mov rsi, r11
        
        jnz metaloop

        pop rbx
        ret

metastep:       
        
        cmp rdx, 0
        je only_ptrs            ;only turn offsets to ptrs
        cmp rdx, 1
        je no_checking          ;no read barrier, no typecheck
        ;; cmp rdx, 2
        ;; je typecheck_a           ;typecheck: special: test 110, jnz, test 001, jz
        cmp rdx, 3
        je typecheck_b          ;typecheck: load 111, and, jz ;uses reg
        cmp rdx, 4
        je typecheck_c          ;typecheck: xor 001, test 111, jnz ;changes ptr
        cmp rdx, 5
        je typecheck_car        ;car, cdr as subroutines

        cmp rdx, 6
        je typecheck_b_barr    ;test reg, [mem]
        ;; cmp rdx, 7
        ;; je typecheck_b_barr2    ;test reg, xxxx
        ;; cmp rdx, 8
        ;; je typecheck_b_barr3    ;test reg, reg
        ;; cmp rdx, 9
        ;; je typecheck_b_barr4    ;bt reg, [mem] ;accually is barr5; can't bt reg, [mem].
        ;; cmp rdx, 10
        ;; je typecheck_b_barr5    ;bt reg, xxxx
        ;; cmp rdx, 11
        ;; je typecheck_b_barr6    ;bt reg, reg

        cmp rdx, 12
        je typecheck_b_barr_ret
        
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

        
typecheck_b_barr_fail:
        mov rax, 717
        ;; mov rax, [rsp - 32]
        ret

typecheck_b_barr:    
        xor eax, eax
typecheck_b_barr_loop:
        mov cl, 7
        and cl, dil
        cmp cl, 1
        jnz typecheck_b_fail    ;too lazy to change
        mov rdx, [rdi-1]
        test dl, 7
        jnz typecheck_b_fail
        add rax, rdx
        jc typecheck_b_carry
        mov rdi, [rdi+7]
        test rdi, [rsp - 32]    ;geh, offset
        jnz typecheck_b_barr_fail
        dec rsi
        jnz typecheck_b_barr_loop
        ret

typecheck_b_barr_ret:
        xor eax, eax
typecheck_b_barr_ret_loop:
        mov cl, 7
        and cl, dil
        cmp cl, 1
        jnz typecheck_b_fail    ;too lazy to change
        mov rdx, [rdi-1]
        test dl, 7
        jnz typecheck_b_fail
        add rax, rdx
        jc typecheck_b_carry
        mov rdi, [rdi+7]
typecheck_b_pre_read_barr:      
        mov rcx, 23             ;this shall identify this segment of code
        test rdi, [rbx - 40]    ;geh, offset
        jnz typecheck_b_barr_fail
        dec rsi
        jnz typecheck_b_barr_ret_loop
        ret
        

        



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

        ;; So.  Looks like the read barriers are very consistent with each other.
        ;; Looks like they make a 25% overhead w.r.t. just typechecking,
        ;; and a 125% overhead w.r.t. no checking.
        ;; I'll use the "test reg, [mem]" thing, because that is obviously the best
        ;; if they're equal according to the other metrics.
        ;; Next I shall add in the "where do I return to".
        

;; arc> (do l.read-barr2 (ga read-barrier4 4) (= N 4 k 240000000 g time:nerb.N h time:make-narb.g) (prn:* g.1 8) (time:read-barrier4-thing read-barrier4 h N 1 k))
;; time: 1 cpu: 1 gc: 0 mem: 71040
;; time: 0 cpu: 1 gc: 0 mem: 1504
;; 2008
;; time: 1052 cpu: 1052 gc: 0 mem: 2592
;; 2008
;; arc> (each x (rev '(1 1 1 3 3 3 4 4 4 6 6 6 12 12 12)) (do (= h make-narb.g) (pr x " ") (time:read-barrier4-thing read-barrier4 h N x k)))
;; 12 time: 2321 cpu: 2322 gc: 0 mem: 160
;; 12 time: 2306 cpu: 2306 gc: 0 mem: 160
;; 12 time: 2315 cpu: 2315 gc: 0 mem: 160
;; 6 time: 2271 cpu: 2271 gc: 0 mem: 160
;; 6 time: 2270 cpu: 2270 gc: 0 mem: 160
;; 6 time: 2273 cpu: 2273 gc: 0 mem: 160
;; 4 time: 1790 cpu: 1790 gc: 0 mem: 160
;; 4 time: 1786 cpu: 1785 gc: 0 mem: 160
;; 4 time: 1786 cpu: 1786 gc: 0 mem: 160
;; 3 time: 1727 cpu: 1727 gc: 0 mem: 160
;; 3 time: 1729 cpu: 1728 gc: 0 mem: 160
;; 3 time: 1731 cpu: 1730 gc: 0 mem: 192
;; 1 time: 1056 cpu: 1056 gc: 0 mem: 160
;; 1 time: 1051 cpu: 1050 gc: 0 mem: 160
;; 1 time: 1056 cpu: 1056 gc: 0 mem: 160


;; arc> (do l.read-barr2 (ga read-barrier4 4) (= N 100 k 8000000 g time:nerb.N h time:make-narb.g) (prn:* g.1 8) (time:read-barrier4-thing read-barrier4 h N 12 k))
;; time: 1 cpu: 1 gc: 0 mem: 73504
;; time: 1 cpu: 0 gc: 0 mem: 5216
;; 56016
;; time: 1331 cpu: 1332 gc: 0 mem: 2592
;; 56016
;; arc> (each x (rev '(1 1 1 3 3 3 4 4 4 6 6 6 12 12 12)) (do (= h make-narb.g) (pr x " ") (time:read-barrier4-thing read-barrier4 h N x k)))
;; 12 time: 1336 cpu: 1335 gc: 0 mem: 160
;; 12 time: 1353 cpu: 1353 gc: 0 mem: 160
;; 12 time: 1343 cpu: 1344 gc: 0 mem: 160
;; 6 time: 1333 cpu: 1333 gc: 0 mem: 160
;; 6 time: 1332 cpu: 1332 gc: 0 mem: 160
;; 6 time: 1328 cpu: 1329 gc: 0 mem: 160
;; 4 time: 1464 cpu: 1464 gc: 0 mem: 160
;; 4 time: 1463 cpu: 1462 gc: 0 mem: 160
;; 4 time: 1468 cpu: 1468 gc: 0 mem: 160
;; 3 time: 1081 cpu: 1080 gc: 0 mem: 160
;; 3 time: 1085 cpu: 1084 gc: 0 mem: 160
;; 3 time: 1080 cpu: 1080 gc: 0 mem: 160
;; 1 time: 969 cpu: 969 gc: 0 mem: 160
;; 1 time: 958 cpu: 958 gc: 0 mem: 160
;; 1 time: 954 cpu: 954 gc: 0 mem: 160

;; arc> (do l.read-barr2 (ga read-barrier4 4) (= N 1000 k 800000 g time:nerb.N h time:make-narb.g) (prn:* g.1 8) (time:read-barrier4-thing read-barrier4 h N 1 k))
;; time: 2 cpu: 1 gc: 0 mem: 94464
;; time: 0 cpu: 0 gc: 0 mem: 33856
;; 513336
;; time: 1015 cpu: 1016 gc: 0 mem: 2592
;; 513336
;; arc> (each x (rev '(1 1 1 3 3 3 4 4 4 6 6 6 12 12 12)) (do (= h make-narb.g) (pr x " ") (time:read-barrier4-thing read-barrier4 h N x k)))
;; 12 time: 1272 cpu: 1272 gc: 0 mem: 160
;; 12 time: 1274 cpu: 1274 gc: 0 mem: 160
;; 12 time: 1273 cpu: 1274 gc: 0 mem: 160
;; 6 time: 1265 cpu: 1266 gc: 0 mem: 160
;; 6 time: 1269 cpu: 1269 gc: 0 mem: 160
;; 6 time: 1268 cpu: 1268 gc: 0 mem: 160
;; 4 time: 1502 cpu: 1502 gc: 0 mem: 160
;; 4 time: 1505 cpu: 1505 gc: 0 mem: 160
;; 4 time: 1504 cpu: 1505 gc: 0 mem: 160
;; 3 time: 1013 cpu: 1014 gc: 0 mem: 160
;; 3 time: 1017 cpu: 1016 gc: 0 mem: 160
;; 3 time: 1014 cpu: 1014 gc: 0 mem: 160
;; 1 time: 1007 cpu: 1008 gc: 0 mem: 160
;; 1 time: 1004 cpu: 1004 gc: 0 mem: 160
;; 1 time: 1012 cpu: 1012 gc: 0 mem: 160
        
;; arc> (do l.read-barr2 (ga read-barrier4 4) (= N 10000 k 25000 g time:nerb.N h time:make-narb.g) (prn:* g.1 8) (time:read-barrier4-thing read-barrier4 h N 1 k))
;; time: 7 cpu: 7 gc: 0 mem: 310784
;; time: 2 cpu: 2 gc: 0 mem: 322496
;; 5069144
;; time: 1020 cpu: 1020 gc: 0 mem: 2592
;; 5069144
;; arc> (each x (rev '(1 1 1 3 3 3 4 4 4 6 6 6 12 12 12)) (do (= h make-narb.g) (pr x " ") (time:read-barrier4-thing read-barrier4 h N x k)))
;; 12 time: 1034 cpu: 1034 gc: 0 mem: 160
;; 12 time: 1042 cpu: 1042 gc: 0 mem: 160
;; 12 time: 1035 cpu: 1035 gc: 0 mem: 160
;; 6 time: 1031 cpu: 1032 gc: 0 mem: 160
;; 6 time: 1027 cpu: 1027 gc: 0 mem: 160
;; 6 time: 1032 cpu: 1032 gc: 0 mem: 160
;; 4 time: 1213 cpu: 1213 gc: 0 mem: 160
;; 4 time: 1208 cpu: 1208 gc: 0 mem: 160
;; 4 time: 1212 cpu: 1212 gc: 0 mem: 160
;; 3 time: 1014 cpu: 1014 gc: 0 mem: 160
;; 3 time: 1017 cpu: 1017 gc: 0 mem: 160
;; 3 time: 1017 cpu: 1016 gc: 0 mem: 160
;; 1 time: 1016 cpu: 1016 gc: 0 mem: 160
;; 1 time: 1015 cpu: 1015 gc: 0 mem: 160
;; 1 time: 1021 cpu: 1020 gc: 0 mem: 160

        ;; It looks like basically all overheads are minor with large N,
        ;; (I suspect 4's bad performance with large N comes from how you change a mem addr
        ;;  in a way that might defeat prefetching or smthg.)
        ;; and at lower N... with N=4, typechecking costs 70%, read barrier + typechecking 125%,
        ;; and full read barrier maybe 130%.
        ;; hmm...
        ;; for completeness, I should probably include a dumb read barrier that will still
        ;; move things even when it doesn't need...

        ;; So I might imagine: int = 000, char = 001, and those are the only non-ptrs.
        ;; Then I can test for ptr-ness with a 110 mask.
        ;; Ok, that's how it'll be done.

        ;; A relatively sophisticated compiler should be able to reorganize its
        ;; jumps and/or combine things, so that testing for whether x is a fixnum
        ;; should be done first, and if true, should make read barr. unnec.
        ;; Also, if it would do nothing except err with a non-fixnum... mmm...
        ;; I guess the erroring could dick... mmm.
        ;; Well, time for uberbad.

        ;; Oh right, the other thing.
        ;; I suspect that the extra memory use of
        ;; "mov ecx, NNN; test; jnz global_err; [extra ptr in global_err_table]"
        ;; exceeds that of
        ;; "test; jnz local_err; call global_err; jmp continue"
        ;; . 4-5 bytes for the mov ecx; x bytes for test; 6 bytes for glob jnz;
        ;; 8 bytes for ptr. 18-19 + x bytes.
        ;; vs: x for test; 2-6 bytes for local jnz; 5 bytes for call; 5 bytes for jmp.
        ;; 12-16 + x bytes.
        ;; hah, yes, it is more efficient.
        ;; damn.
        ;; ok, then:
        ;; in terms of code size:
        ;; "call car_reg1_reg2": 5 bytes.
        ;; "test reg1, [r15 + n]; jnz local_err; mov reg2, [reg1 - 1]; ... call global_err; jmp continue"
        ;; 4 bytes (it turns out) + 2-6 bytes + 4 bytes + 5 bytes + 2-5 bytes = 17-24 bytes.
        ;; Is that worth it?  Me thinks so.  (Note that 6-10 bytes will be on the main code path.)

        ;; Ok, onto dumb dumb.
        
        
        

        


        