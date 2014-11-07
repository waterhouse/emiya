

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
        mov rbx, 31
        mov [rsp - 48], rbx
        
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
        je typecheck_b_barr1    ;test reg, [mem]
        cmp rdx, 7
        je typecheck_b_barr2    ;test reg, xxxx
        cmp rdx, 8
        je typecheck_b_barr3    ;test reg, reg
        cmp rdx, 9
        je typecheck_b_barr4    ;bt reg, [mem] ;accually is barr5; can't bt reg, [mem].
        cmp rdx, 10
        je typecheck_b_barr5    ;bt reg, xxxx
        cmp rdx, 11
        je typecheck_b_barr6    ;bt reg, reg
        
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

typecheck_b_barr1:    
        xor eax, eax
typecheck_b_barr1_loop:
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
        jnz typecheck_b_barr1_loop
        ret

typecheck_b_barr2:
        xor eax, eax
typecheck_b_barr2_loop:
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
        test edi, 0xc0000000    ;oh boy
        jnz typecheck_b_barr_fail
        dec rsi
        jnz typecheck_b_barr2_loop
        ret

typecheck_b_barr3:    
        xor eax, eax
        mov rbx, [rsp - 32]
typecheck_b_barr3_loop:
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
        test rdi, rbx
        jnz typecheck_b_barr_fail
        dec rsi
        jnz typecheck_b_barr3_loop
        ret

        ;; Ok turns out bt is reg/mem, reg and reg/mem, imm8; no reg, reg/mem.

typecheck_b_barr4:
        xor eax, eax
typecheck_b_barr4_loop:
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
        bt rdi, 31
        jc typecheck_b_barr_fail
        dec rsi
        jnz typecheck_b_barr4_loop
        ret


typecheck_b_barr5:
        xor eax, eax
typecheck_b_barr5_loop:
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
        bt rdi, 31
        jc typecheck_b_barr_fail ;ah yes, 'tis carry flag
        dec rsi
        jnz typecheck_b_barr5_loop
        ret


typecheck_b_barr6:
        xor eax, eax
        mov rbx, [rsp - 40]
typecheck_b_barr6_loop:
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
        bt rdi, rbx
        jc typecheck_b_barr_fail
        dec rsi
        jnz typecheck_b_barr6_loop
        ret        


        ;; je typecheck_b_barr1    ;test reg, [mem]
        ;; cmp rdx, 7
        ;; je typecheck_b_barr2    ;test reg, xxxx
        ;; cmp rdx, 8
        ;; je typecheck_b_barr3    ;test reg, reg
        ;; cmp rdx, 9
        ;; je typecheck_b_barr4    ;bt reg, [mem]
        ;; cmp rdx, 10
        ;; je typecheck_b_barr5    ;bt reg, xxxx
        ;; cmp rdx, 11
        ;; je typecheck_b_barr6    ;bt reg, reg
        

        



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

        ;; Ok, it looks like the read barriers are very consistent with each other.
        ;; N=1000, k=800k:
;; 1 time: 999 cpu: 999 gc: 0 mem: 160
;; 1 time: 990 cpu: 990 gc: 0 mem: 160
;; 1 time: 993 cpu: 993 gc: 0 mem: 160
;; 3 time: 998 cpu: 999 gc: 0 mem: 160
;; 3 time: 1001 cpu: 1000 gc: 0 mem: 160
;; 3 time: 997 cpu: 997 gc: 0 mem: 160
;; 4 time: 1488 cpu: 1488 gc: 0 mem: 160
;; 4 time: 1486 cpu: 1486 gc: 0 mem: 160
;; 4 time: 1486 cpu: 1486 gc: 0 mem: 160
;; 5 time: 2745 cpu: 2745 gc: 0 mem: 160
;; 5 time: 2735 cpu: 2735 gc: 0 mem: 160
;; 5 time: 2754 cpu: 2754 gc: 0 mem: 160
;; 6 time: 1268 cpu: 1268 gc: 0 mem: 160
;; 6 time: 1269 cpu: 1269 gc: 0 mem: 160
;; 6 time: 1264 cpu: 1264 gc: 0 mem: 160
;; 7 time: 1246 cpu: 1247 gc: 0 mem: 160
;; 7 time: 1250 cpu: 1251 gc: 0 mem: 192
;; 7 time: 1245 cpu: 1246 gc: 0 mem: 160
;; 8 time: 1251 cpu: 1251 gc: 0 mem: 160
;; 8 time: 1254 cpu: 1253 gc: 0 mem: 160
;; 8 time: 1248 cpu: 1248 gc: 0 mem: 160
;; 10 time: 1252 cpu: 1252 gc: 0 mem: 160
;; 10 time: 1253 cpu: 1254 gc: 0 mem: 160
;; 10 time: 1248 cpu: 1248 gc: 0 mem: 160
;; 11 time: 1255 cpu: 1255 gc: 0 mem: 160
;; 11 time: 1249 cpu: 1249 gc: 0 mem: 160
;; 11 time: 1252 cpu: 1252 gc: 0 mem: 160

;; arc> (do l.read-barr2 (ga read-barrier3 4) (= N 10000 k 20000 g time:nerb.N h time:make-narb.g) (prn:* g.1 8) (time:read-barrier3-thing read-barrier3 h N 1 k))
;; time: 5 cpu: 6 gc: 0 mem: 310784
;; time: 2 cpu: 2 gc: 0 mem: 322336
;; 5060008
;; time: 1079 cpu: 1079 gc: 0 mem: 2592
;; 5060008
;; arc> (each x '(1 1 1 3 3 3 4 4 4 5 5 5 6 6 6 7 7 7 8 8 8 10 10 10 11 11 11) (do (= h make-narb.g) (pr x " ") (time:read-barrier3-thing read-barrier3 h N x k)))
;; 1 time: 797 cpu: 797 gc: 0 mem: 160
;; 1 time: 806 cpu: 806 gc: 0 mem: 160
;; 1 time: 799 cpu: 799 gc: 0 mem: 160
;; 3 time: 805 cpu: 806 gc: 0 mem: 160
;; 3 time: 801 cpu: 801 gc: 0 mem: 160
;; 3 time: 799 cpu: 799 gc: 0 mem: 160
;; 4 time: 959 cpu: 959 gc: 0 mem: 160
;; 4 time: 951 cpu: 951 gc: 0 mem: 160
;; 4 time: 959 cpu: 959 gc: 0 mem: 160
;; 5 time: 906 cpu: 907 gc: 0 mem: 160
;; 5 time: 899 cpu: 900 gc: 0 mem: 160
;; 5 time: 899 cpu: 900 gc: 0 mem: 160
;; 6 time: 807 cpu: 807 gc: 0 mem: 160
;; 6 time: 811 cpu: 811 gc: 0 mem: 160
;; 6 time: 807 cpu: 806 gc: 0 mem: 160
;; 7 time: 809 cpu: 809 gc: 0 mem: 160
;; 7 time: 808 cpu: 808 gc: 0 mem: 160
;; 7 time: 808 cpu: 808 gc: 0 mem: 160
;; 8 time: 800 cpu: 799 gc: 0 mem: 160
;; 8 time: 799 cpu: 799 gc: 0 mem: 160
;; 8 time: 806 cpu: 806 gc: 0 mem: 160
;; 10 time: 803 cpu: 802 gc: 0 mem: 160
;; 10 time: 804 cpu: 804 gc: 0 mem: 160
;; 10 time: 803 cpu: 803 gc: 0 mem: 160
;; 11 time: 800 cpu: 800 gc: 0 mem: 160
;; 11 time: 804 cpu: 803 gc: 0 mem: 160
;; 11 time: 801 cpu: 801 gc: 0 mem: 160

;; arc> (do l.read-barr2 (ga read-barrier3 4) (= N 100 k 8000000 g time:nerb.N h time:make-narb.g) (prn:* g.1 8) (time:read-barrier3-thing read-barrier3 h N 1 k))
;; time: 1 cpu: 1 gc: 0 mem: 73184
;; time: 0 cpu: 0 gc: 0 mem: 5696
;; 49176
;; time: 977 cpu: 977 gc: 0 mem: 2912
;; 49176
;; arc> (each x '(1 1 1 3 3 3 4 4 4 5 5 5 6 6 6 7 7 7 8 8 8 10 10 10 11 11 11) (do (= h make-narb.g) (pr x " ") (time:read-barrier3-thing read-barrier3 h N x k)))
;; 1 time: 976 cpu: 976 gc: 0 mem: 160
;; 1 time: 960 cpu: 960 gc: 0 mem: 160
;; 1 time: 957 cpu: 956 gc: 0 mem: 160
;; 3 time: 1059 cpu: 1059 gc: 0 mem: 160
;; 3 time: 1077 cpu: 1076 gc: 0 mem: 160
;; 3 time: 1065 cpu: 1064 gc: 0 mem: 160
;; 4 time: 1465 cpu: 1466 gc: 0 mem: 160
;; 4 time: 1463 cpu: 1462 gc: 0 mem: 160
;; 4 time: 1467 cpu: 1467 gc: 0 mem: 160
;; 5 time: 3329 cpu: 3329 gc: 0 mem: 160
;; 5 time: 3326 cpu: 3326 gc: 0 mem: 160
;; 5 time: 3331 cpu: 3331 gc: 0 mem: 160
;; 6 time: 1341 cpu: 1341 gc: 0 mem: 160
;; 6 time: 1336 cpu: 1336 gc: 0 mem: 160
;; 6 time: 1341 cpu: 1341 gc: 0 mem: 160
;; 7 time: 1333 cpu: 1333 gc: 0 mem: 160
;; 7 time: 1330 cpu: 1331 gc: 0 mem: 160
;; 7 time: 1337 cpu: 1337 gc: 0 mem: 160
;; 8 time: 1342 cpu: 1342 gc: 0 mem: 160
;; 8 time: 1334 cpu: 1334 gc: 0 mem: 160
;; 8 time: 1342 cpu: 1343 gc: 0 mem: 160
;; 10 time: 1342 cpu: 1341 gc: 0 mem: 160
;; 10 time: 1345 cpu: 1345 gc: 0 mem: 160
;; 10 time: 1342 cpu: 1342 gc: 0 mem: 160
;; 11 time: 1350 cpu: 1350 gc: 0 mem: 160
;; 11 time: 1346 cpu: 1346 gc: 0 mem: 160
;; 11 time: 1351 cpu: 1352 gc: 0 mem: 160

;; arc> (do l.read-barr2 (ga read-barrier3 4) (= N 10 k 24000000 g time:nerb.N h time:make-narb.g) (prn:* g.1 8) (time:read-barrier3-thing read-barrier3 h N 10 k))
;; time: 1 cpu: 1 gc: 0 mem: 71184
;; time: 0 cpu: 1 gc: 0 mem: 2976
;; 3712
;; time: 481 cpu: 480 gc: 0 mem: 2912
;; 3712
;; arc> (each x '(1 1 1 3 3 3 4 4 4 5 5 5 6 6 6 7 7 7 8 8 8 10 10 10 11 11 11) (do (= h make-narb.g) (pr x " ") (time:read-barrier3-thing read-barrier3 h N x k)))
;; 1 time: 203 cpu: 203 gc: 0 mem: 160
;; 1 time: 204 cpu: 204 gc: 0 mem: 160
;; 1 time: 201 cpu: 202 gc: 0 mem: 160
;; 3 time: 386 cpu: 385 gc: 0 mem: 160
;; 3 time: 381 cpu: 381 gc: 0 mem: 160
;; 3 time: 375 cpu: 375 gc: 0 mem: 160
;; 4 time: 380 cpu: 380 gc: 0 mem: 160
;; 4 time: 379 cpu: 379 gc: 0 mem: 160
;; 4 time: 379 cpu: 378 gc: 0 mem: 160
;; 5 time: 961 cpu: 961 gc: 0 mem: 160
;; 5 time: 959 cpu: 959 gc: 0 mem: 160
;; 5 time: 961 cpu: 960 gc: 0 mem: 160
;; 6 time: 464 cpu: 464 gc: 0 mem: 160
;; 6 time: 463 cpu: 463 gc: 0 mem: 160
;; 6 time: 462 cpu: 463 gc: 0 mem: 160
;; 7 time: 464 cpu: 464 gc: 0 mem: 160
;; 7 time: 461 cpu: 462 gc: 0 mem: 160
;; 7 time: 461 cpu: 461 gc: 0 mem: 160
;; 8 time: 471 cpu: 470 gc: 0 mem: 160
;; 8 time: 473 cpu: 474 gc: 0 mem: 160
;; 8 time: 474 cpu: 474 gc: 0 mem: 160
;; 10 time: 485 cpu: 484 gc: 0 mem: 160
;; 10 time: 485 cpu: 485 gc: 0 mem: 160
;; 10 time: 483 cpu: 483 gc: 0 mem: 160
;; 11 time: 492 cpu: 492 gc: 0 mem: 160
;; 11 time: 495 cpu: 495 gc: 0 mem: 160
;; 11 time: 491 cpu: 491 gc: 0 mem: 160

        ;; So.  Looks like the read barriers are very consistent with each other.
        ;; Looks like they make a 25% overhead w.r.t. just typechecking,
        ;; and a 125% overhead w.r.t. no checking.
        ;; I'll use the "test reg, [mem]" thing, because that is obviously the best
        ;; if they're equal according to the other metrics.
        ;; Next I shall add in the "where do I return to".
        

        
        


        