

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
        push r15

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

        mov r15, rsp
        sub r15, 160

        mov rax, 0
        mov [r15 + 0], rax
        mov rax, 0xc0000000
        mov [r15 + 8], rax
        mov rax, 0xc0000000
        mov [r15 + 16], rax
        mov rax, 0xc0000000
        mov [r15 + 24], rax
        mov rax, 0
        mov [r15 + 32], rax
        mov rax, 0xc0000000
        mov [r15 + 40], rax
        mov rax, 0xc0000000
        mov [r15 + 48], rax
        mov rax, 0xc0000000
        mov [r15 + 56], rax

        
        
        call ptrify
        
metaloop:
        mov rdx, r9
        call metastep
        dec r8
        mov rdi, r10
        mov rsi, r11
        
        jnz metaloop

        pop r15
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
        cmp rdx, 13
        je typecheck_b_dumb_dumb1 ;read barrs on car and cdr; 110 used as ptr check mask
        cmp rdx, 14               ;--or, no, 011; I'm pretending 001 is cons
        je typecheck_b_dumb_dumb2
        cmp rdx, 15
        je typecheck_b_dumb_dumb3
        cmp rdx, 16
        je typecheck_b_dumb_dumb4
        cmp rdx, 17
        je typecheck_b_dumb_dumb5
        
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

        ;; oh fuck, I don't want the main line (or either main line or something)
        ;; to have a jump...
        ;; damn. it may be necessary to try that guy's idea, of using a low bit to tag fromspace.
        ;; (which has interesting implications...)
        ;; hmm...
        ;; so there are cases where I'd be about to use a fixnum, as here.
        ;; those can and should be optimized in a nice way like the above.
        ;; however, there are cases where I'm moving data around.
        ;; I can, of course, perform the fromspace test on what might be a fixnum and fix
        ;; *that* up later. that has terribly mind-screwing performance implications.
        ;; (a program manipulating fixnums with 0 bits in the right places will perform faster)
        ;; which leads me to dislike it.
        ;; ....

        ;; Fuck.  I'll have to try several fucking variations.
        ;; Ok, one that doesn't involve branching is likely to have....
        ;; cmov crap, or maybe weird sign extension crap...

        ;; Btw, if a program *expects* something to be a ptr, then it is advantageous
        ;; to just do the fromspace test without the ptr test, and let the general
        ;; read barrier handler handle it.  (actually you can go to a prefix of the usual
        ;;  handler: the prefix tests for non-ptr, the main thing does not)
        ;; If we do not have any prejudices, then...
        ;; ... hmm...
        ;; if fixnum was 000 and char was 001, I could compare for > 2.
        ;; also it is conceivable I could have chars be ptrs; would not need to allocate,
        ;; just create silly ptrs.
        ;; however, I'd still have to disambig. the fixnum.

        ;; 1. mov ecx, 011; and cl, dil; cmovnz rcx, rdx; test rcx, [mem]
        ;; 2. xor ecx, ecx; test dil, 011; cmovnz rcx, rdx; test rcx, [mem]
        ;; 3. test rdx, 011; jz non_ptr; test rdx, [mem]; jnz barr; non_ptr: ... barr: ...
        ;; 4. test rdx, 011; jnz ptr; fine: ... ptr: test [mem]; jnz fine; barr: ...
        ;; 5. test rdx, 011; jnz ptr; jmp fine; [... I can't finish this, should be 3]
        ;; 6. mov cl, 7; and cl, dil; test
        ;; ...
        ;; 7. mov ecx, 7; and cl, dil; test rdx, [r15 + 8 * rcx]; jnz barr; ...
        ;; ^ LOLOLOLOLOLOLOLOLOLOL AWESOME [TERRIBLE]
        ;; wtf would I do on ARM?
        ;; I guess I could expand it out...
        ;; sigh. this will really suck.
        ;; I don't feel like I can do all that by hand.
        ;; therefore, Arc... oh dear.
        ;; OH god.
        ;; hmmph.
        ;; hmmph.
        ;; this is terrible.
        ;; well.

        ;; 
        

        ;; ok, let's start with the good one.
typecheck_b_dumb_dumb1:  
        xor eax, eax
typecheck_b_dumb_dumb1_loop:
        mov cl, 7
        and cl, dil
        cmp cl, 1
        jnz typecheck_b_fail    ;too lazy to change
        mov rdx, [rdi-1]
        ;; now read barr
        mov ecx, 7
        and cl, dl
        test rdx, [r15 + 8 * rcx]
        jnz typecheck_b_barr_fail
        ;; now type check
        test dl, 7
        jnz typecheck_b_fail
        ;; now add
        add rax, rdx
        jc typecheck_b_carry
        mov rdi, [rdi+7]
        ;; now read barr 2
        mov ecx, 7
        and cl, dil
        test rdi, [r15 + 8 * rcx]
        jnz typecheck_b_barr_fail
        ;; and loop
        dec rsi
        jnz typecheck_b_dumb_dumb1_loop
        ret

        ;; now... dicks...
typecheck_b_dumb_dumb2:  
        xor eax, eax
typecheck_b_dumb_dumb2_loop:
        mov cl, 7
        and cl, dil
        cmp cl, 1
        jnz typecheck_b_fail    ;too lazy to change
        mov rdx, [rdi-1]
        ;; now read barr
        mov ecx, 011
        and cl, dl
        cmovnz rcx, rdx
        test rcx, [rbx - 40]
        jnz typecheck_b_barr_fail
        ;; now type check
        test dl, 7
        jnz typecheck_b_fail
        ;; now add
        add rax, rdx
        jc typecheck_b_carry
        mov rdi, [rdi+7]
        ;; now read barr 2
        mov ecx, 011
        and cl, dil
        cmovnz rcx, rdi
        test rcx, [rbx - 40]
        jnz typecheck_b_barr_fail
        ;; and loop
        dec rsi
        jnz typecheck_b_dumb_dumb2_loop
        ret

        ;; now eqv dicks

typecheck_b_dumb_dumb3:  
        xor eax, eax
typecheck_b_dumb_dumb3_loop:
        mov cl, 7
        and cl, dil
        cmp cl, 1
        jnz typecheck_b_fail    ;too lazy to change
        mov rdx, [rdi-1]
        ;; now read barr
        xor ecx, ecx
        test dl, 011
        cmovnz rcx, rdx
        test rcx, [rbx - 40]
        jnz typecheck_b_barr_fail
        ;; now type check
        test dl, 7
        jnz typecheck_b_fail
        ;; now add
        add rax, rdx
        jc typecheck_b_carry
        mov rdi, [rdi+7]
        ;; now read barr 2
        xor ecx, ecx
        test dil, 011
        cmovnz rcx, rdi
        test rcx, [rbx - 40]
        jnz typecheck_b_barr_fail
        ;; and loop
        dec rsi
        jnz typecheck_b_dumb_dumb3_loop
        ret        



typecheck_b_dumb_dumb4:  
        xor eax, eax
typecheck_b_dumb_dumb4_loop:
        mov cl, 7
        and cl, dil
        cmp cl, 1
        jnz typecheck_b_fail    ;too lazy to change
        mov rdx, [rdi-1]
        ;; now read barr
        test dl, 011
        jz dumbdumb4_a
        test rdx, [rbx - 40]
        jnz typecheck_b_barr_fail
dumbdumb4_a:    
        ;; now type check ;dumb
        test dl, 7
        jnz typecheck_b_fail
        ;; now add
        add rax, rdx
        jc typecheck_b_carry
        mov rdi, [rdi+7]
        ;; now read barr 2
        test dil, 011
        jz dumbdumb4_b
        test rdi, [rbx - 40]
        jnz typecheck_b_barr_fail
dumbdumb4_b:    
        ;; and loop
        dec rsi
        jnz typecheck_b_dumb_dumb4_loop
        ret

typecheck_b_dumb_dumb5:  
        xor eax, eax
typecheck_b_dumb_dumb5_loop:
        mov cl, 7
        and cl, dil
        cmp cl, 1
        jnz typecheck_b_fail    ;too lazy to change
        mov rdx, [rdi-1]
        ;; now read barr
        test dl, 011
        jnz dumbdumb5_a
dumbdumb5_a_back:       
        ;; now type check ;dumb
        test dl, 7
        jnz typecheck_b_fail
        ;; now add
        add rax, rdx
        jc typecheck_b_carry
        mov rdi, [rdi+7]
        ;; now read barr 2
        test dil, 011
        jnz dumbdumb5_b
dumbdumb5_b_back:
        ;; and loop
        dec rsi
        jnz typecheck_b_dumb_dumb4_loop
        ret
        ;; crap
dumbdumb5_a:
        test rdx, [rbx - 40]
        jz dumbdumb5_a_back
        ;; here, since we're already in "off-main" code, we can inline the local_err
        ;; code.
        call typecheck_b_barr_fail
        jmp dumbdumb5_a_back
dumbdumb5_b:
        test rdi, [rbx - 40]
        jz dumbdumb5_b_back
        call typecheck_b_barr_fail
        jmp dumbdumb5_b_back
        
        

        ;; 1. mov ecx, 011; and cl, dil; cmovnz rcx, rdx; test rcx, [mem]
        ;; 2. xor ecx, ecx; test dil, 011; cmovnz rcx, rdx; test rcx, [mem]
        ;; 3. test rdx, 011; jz non_ptr; test rdx, [mem]; jnz barr; non_ptr: ... barr: ...
        ;; 4. test rdx, 011; jnz ptr; fine: ... ptr: test [mem]; jnz fine; barr: ...
        ;; 5. test rdx, 011; jnz ptr; jmp fine; [... I can't finish this, should be 3]
        ;; 6. mov cl, 7; and cl, dil; test
        ;; ...
        ;; 7. mov ecx, 7; and cl, dil; test rdx, [r15 + 8 * rcx]; jnz barr; ...
        ;; ^ LOLOLOLOLOLOLOLOLOLOL AWESOME [TERRIBLE]        
        

        



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
        
        ;; Welp, time for a huge statistics dump.

;;         arc> (do l.read-barr2 (ga read-barrier5 4) (= N 10000 k 25000 g time:nerb.N h time:make-narb.g) (prn:* g.1 8) (time:read-barrier5-thing read-barrier5 h N 1 k))time: 7 cpu: 7 gc: 0 mem: 310624time: 2 cpu: 2 gc: 0 mem: 322976
;; 5068160
;; time: 1010 cpu: 1010 gc: 0 mem: 2592
;; 5068160
;; arc> (do l.read-barr2 (ga read-barrier5 4) (= N 10000 k 25000 g time:nerb.N h time:make-narb.g) (prn:* g.1 8) (time:read-barrier5-thing read-barrier5 h N 12 k))
;; time: 8 cpu: 9 gc: 0 mem: 312864
;; time: 2 cpu: 2 gc: 0 mem: 323616
;; 5076048
;; time: 1003 cpu: 1004 gc: 0 mem: 3072
;; 5076048
;; arc> (do l.read-barr2 (ga read-barrier5 4) (= N 10000 k 25000 g time:nerb.N h time:make-narb.g) (prn:* g.1 8) (time:read-barrier5-thing read-barrier5 h N 13 k))
;; time: 7 cpu: 8 gc: 0 mem: 314784
;; time: 3 cpu: 2 gc: 0 mem: 323776
;; 5056064
;; time: 1007 cpu: 1008 gc: 0 mem: 3072
;; 5056064
;; arc> (do l.read-barr2 (ga read-barrier5 4) (= N 10000 k 25000 g time:nerb.N h time:make-narb.g) (prn:* g.1 8) (time:read-barrier5-thing read-barrier5 h N 14 k))
;; time: 20 cpu: 20 gc: 10 mem: -32481816
;; time: 2 cpu: 2 gc: 0 mem: 321520
;; 5040968
;; time: 995 cpu: 995 gc: 0 mem: 2592
;; 5040968
;; arc> (do l.read-barr2 (ga read-barrier5 4) (= N 10000 k 25000 g time:nerb.N h time:make-narb.g) (prn:* g.1 8) (time:read-barrier5-thing read-barrier5 h N 15 k))
;; time: 8 cpu: 7 gc: 0 mem: 309984
;; time: 2 cpu: 3 gc: 0 mem: 321376
;; 5087600
;; time: 987 cpu: 986 gc: 0 mem: 2432
;; 5087600
;; arc> (do l.read-barr2 (ga read-barrier5 4) (= N 10000 k 25000 g time:nerb.N h time:make-narb.g) (prn:* g.1 8) (time:read-barrier5-thing read-barrier5 h N 16 k))
;; time: 8 cpu: 8 gc: 0 mem: 310624
;; time: 2 cpu: 2 gc: 0 mem: 322640
;; 5068456
;; time: 1687 cpu: 1687 gc: 0 mem: 2912
;; 5068456
;; arc> (do l.read-barr2 (ga read-barrier5 4) (= N 10000 k 25000 g time:nerb.N h time:make-narb.g) (prn:* g.1 8) (time:read-barrier5-thing read-barrier5 h N 17 k))
;; time: 8 cpu: 7 gc: 0 mem: 310784
;; time: 2 cpu: 3 gc: 0 mem: 322336
;; 5161528
;; time: 1635 cpu: 1635 gc: 0 mem: 2592
;; 5161528
;; arc> (each x (rev '(1 1 1 3 3 3 4 4 4 6 6 6 12 12 12 13 13 13 14 14 14 15 15 15 16 16 16 17 17 17)) (do (= h make-narb.g) (pr x " ") (time:read-barrier4-thing read-barrier4 h N x k)))17 time: 0 cpu: 0 gc: 0 mem: 160
;; 17 time: 0 cpu: 0 gc: 0 mem: 160
;; 17 time: 0 cpu: 0 gc: 0 mem: 160
;; 16 time: 1 cpu: 0 gc: 0 mem: 160
;; 16 time: 0 cpu: 0 gc: 0 mem: 192
;; 16 time: 0 cpu: 0 gc: 0 mem: 160
;; 15 time: 0 cpu: 0 gc: 0 mem: 160
;; 15 time: 0 cpu: 0 gc: 0 mem: 160
;; 15 time: 0 cpu: 0 gc: 0 mem: 160
;; 14 time: 0 cpu: 0 gc: 0 mem: 160
;; 14 time: 0 cpu: 0 gc: 0 mem: 160
;; 14 time: 0 cpu: 0 gc: 0 mem: 160
;; 13 time: 0 cpu: 0 gc: 0 mem: 160
;; 13 time: 0 cpu: 0 gc: 0 mem: 160
;; 13 time: 0 cpu: 0 gc: 0 mem: 160
;; 12 time: 1015 cpu: 1015 gc: 0 mem: 160
;; 12 time: 1024 cpu: 1024 gc: 0 mem: 160
;; 12 time: 1013 cpu: 1013 gc: 0 mem: 160
;; 6 time: 1020 cpu: 1020 gc: 0 mem: 160
;; 6 time: 1023 cpu: 1023 gc: 0 mem: 160
;; 6 time: 1028 cpu: 1028 gc: 0 mem: 160
;; 4 user break
;; > (tl)
;; Use (quit) to quit, (tl) to return here after an interrupt.
;; arc> (each x (rev '(1 1 1 3 3 3 4 4 4 6 6 6 12 12 12 13 13 13 14 14 14 15 15 15 16 16 16 17 17 17)) (do (= h make-narb.g) (pr x " ") (time:read-barrier5-thing read-barrier5 h N x k)))
;; 17 time: 1638 cpu: 1638 gc: 0 mem: 160
;; 17 time: 1636 cpu: 1636 gc: 0 mem: 160
;; 17 time: 1642 cpu: 1642 gc: 0 mem: 160
;; 16 time: 1634 cpu: 1633 gc: 0 mem: 160
;; 16 time: 1632 cpu: 1632 gc: 0 mem: 160
;; 16 time: 1634 cpu: 1635 gc: 0 mem: 160
;; 15 time: 988 cpu: 988 gc: 0 mem: 160
;; 15 time: 985 cpu: 985 gc: 0 mem: 160
;; 15 time: 990 cpu: 989 gc: 0 mem: 160
;; 14 time: 986 cpu: 985 gc: 0 mem: 160
;; 14 time: 988 cpu: 987 gc: 0 mem: 160
;; 14 time: 985 cpu: 986 gc: 0 mem: 160
;; 13 time: 1013 cpu: 1013 gc: 0 mem: 160
;; 13 time: 1009 cpu: 1009 gc: 0 mem: 160
;; 13 time: 1013 cpu: 1013 gc: 0 mem: 160
;; 12 time: 1009 cpu: 1009 gc: 0 mem: 160
;; 12 time: 1011 cpu: 1011 gc: 0 mem: 160
;; 12 time: 1008 cpu: 1008 gc: 0 mem: 160
;; 6 time: 1018 cpu: 1018 gc: 0 mem: 160
;; 6 time: 1014 cpu: 1014 gc: 0 mem: 160
;; 6 time: 1017 cpu: 1018 gc: 0 mem: 160
;; 4 time: 1194 cpu: 1194 gc: 0 mem: 160
;; 4 time: 1195 cpu: 1195 gc: 0 mem: 160
;; 4 time: 1197 cpu: 1197 gc: 0 mem: 160
;; 3 time: 1003 cpu: 1003 gc: 0 mem: 160
;; 3 time: 1006 cpu: 1007 gc: 0 mem: 160
;; 3 time: 1004 cpu: 1003 gc: 0 mem: 160
;; 1 time: 1009 cpu: 1009 gc: 0 mem: 160
;; 1 time: 1009 cpu: 1009 gc: 0 mem: 160
;; 1 time: 1012 cpu: 1011 gc: 0 mem: 160
;; nil
;; arc> (list N k)
;; (10000 25000)
;; arc> (do l.read-barr2 (ga read-barrier5 4) (= N 100000 k 2000 g time:nerb.N h time:make-narb.g) (prn:* g.1 8) (time:read-barrier5-thing read-barrier5 h N 17 k))time: 42 cpu: 42 gc: 0 mem: 2470464
;; time: 20 cpu: 19 gc: 0 mem: 3203744
;; 50886656
;; time: 2620 cpu: 2620 gc: 0 mem: 2912
;; 50886656
;; arc> (do l.read-barr2 (ga read-barrier5 4) (= N 100000 k 2000 g time:nerb.N h time:make-narb.g) (prn:* g.1 8) (time:read-barrier5-thing read-barrier5 h N 1 k))
;; time: 49 cpu: 48 gc: 8 mem: -28714736
;; time: 19 cpu: 18 gc: 0 mem: 3203264
;; 50708536
;; time: 2128 cpu: 2128 gc: 0 mem: 2912
;; 50708536
;; arc> (do l.read-barr2 (ga read-barrier5 4) (= N 100000 k 1000 g time:nerb.N h time:make-narb.g) (prn:* g.1 8) (time:read-barrier5-thing read-barrier5 h N 1 k))
;; time: 43 cpu: 43 gc: 0 mem: 2469984
;; time: 18 cpu: 18 gc: 0 mem: 3202784
;; 50712136
;; time: 1060 cpu: 1060 gc: 0 mem: 2912
;; 50712136
;; arc> (each x (rev '(1 1 1 3 3 3 4 4 4 6 6 6 12 12 12 13 13 13 14 14 14 15 15 15 16 16 16 17 17 17)) (do (= h make-narb.g) (pr x " ") (time:read-barrier5-thing read-barrier5 h N x k)))
;; 17 time: 1324 cpu: 1324 gc: 0 mem: 160
;; 17 time: 1325 cpu: 1325 gc: 0 mem: 160
;; 17 time: 1326 cpu: 1326 gc: 0 mem: 160
;; 16 time: 1321 cpu: 1321 gc: 0 mem: 160
;; 16 time: 1316 cpu: 1317 gc: 0 mem: 160
;; 16 time: 1328 cpu: 1327 gc: 0 mem: 160
;; 15 time: 1036 cpu: 1035 gc: 0 mem: 160
;; 15 time: 1033 cpu: 1033 gc: 0 mem: 160
;; 15 time: 1037 cpu: 1036 gc: 0 mem: 160
;; 14 time: 1034 cpu: 1034 gc: 0 mem: 160
;; 14 time: 1037 cpu: 1037 gc: 0 mem: 160
;; 14 time: 1032 cpu: 1032 gc: 0 mem: 160
;; 13 time: 1037 cpu: 1037 gc: 0 mem: 160
;; 13 time: 1033 cpu: 1033 gc: 0 mem: 160
;; 13 time: 1039 cpu: 1039 gc: 0 mem: 160
;; 12 time: 1076 cpu: 1076 gc: 0 mem: 160
;; 12 time: 1080 cpu: 1080 gc: 0 mem: 160
;; 12 time: 1079 cpu: 1080 gc: 0 mem: 160
;; 6 time: 1077 cpu: 1076 gc: 0 mem: 160
;; 6 time: 1079 cpu: 1080 gc: 0 mem: 160
;; 6 time: 1076 cpu: 1076 gc: 0 mem: 160
;; 4 time: 1105 cpu: 1104 gc: 0 mem: 160
;; 4 time: 1102 cpu: 1103 gc: 0 mem: 160
;; 4 time: 1105 cpu: 1105 gc: 0 mem: 160
;; 3 time: 1076 cpu: 1076 gc: 0 mem: 160
;; 3 time: 1097 cpu: 1098 gc: 0 mem: 160
;; 3 time: 1082 cpu: 1081 gc: 0 mem: 160
;; 1 time: 1446 cpu: 1446 gc: 0 mem: 160
;; 1 time: 1440 cpu: 1440 gc: 0 mem: 160
;; 1 time: 1420 cpu: 1419 gc: 0 mem: 160
;; nil
;; arc> (do l.read-barr2 (ga read-barrier5 4) (= N 100000 k 1000 g time:nerb.N h time:make-narb.g) (prn:* g.1 8) (time:read-barrier5-thing read-barrier5 h N 1 k))time: 45 cpu: 44 gc: 0 mem: 2472584
;; time: 18 cpu: 18 gc: 0 mem: 3203568
;; 50545984
;; time: 1350 cpu: 1350 gc: 0 mem: 2592
;; 50545984
;; arc> (do l.read-barr2 (ga read-barrier5 4) (= N 100000 k 1000 g time:nerb.N h time:make-narb.g) (prn:* g.1 8) (time:read-barrier5-thing read-barrier5 h N 1 k))
;; time: 44 cpu: 44 gc: 0 mem: 2471744
;; time: 19 cpu: 19 gc: 0 mem: 3203728
;; 50827440
;; time: 1083 cpu: 1083 gc: 0 mem: 2912
;; 50827440
;; arc> (do l.read-barr2 (ga read-barrier5 4) (= N 1000 k 200000 g time:nerb.N h time:make-narb.g) (prn:* g.1 8) (time:read-barrier5-thing read-barrier5 h N 1 k))time: 1 cpu: 2 gc: 0 mem: 98144
;; time: 1 cpu: 0 gc: 0 mem: 34352
;; 504648
;; time: 251 cpu: 251 gc: 0 mem: 2912
;; 504648
;; arc> (do l.read-barr2 (ga read-barrier5 4) (= N 1000 k 800000 g time:nerb.N h time:make-narb.g) (prn:* g.1 8) (time:read-barrier5-thing read-barrier5 h N 1 k))
;; time: 1 cpu: 2 gc: 0 mem: 97824
;; time: 1 cpu: 0 gc: 0 mem: 35632
;; 509856
;; time: 1356 cpu: 1356 gc: 0 mem: 2912
;; 509856
;; arc> (each x (rev '(1 1 1 3 3 3 4 4 4 6 6 6 12 12 12 13 13 13 14 14 14 15 15 15 16 16 16 17 17 17)) (do (= h make-narb.g) (pr x " ") (time:read-barrier5-thing read-barrier5 h N x k)))
;; 17 time: 1887 cpu: 1887 gc: 0 mem: 160
;; 17 time: 1878 cpu: 1877 gc: 0 mem: 160
;; 17 time: 1874 cpu: 1874 gc: 0 mem: 160
;; 16 time: 1875 cpu: 1875 gc: 0 mem: 160
;; 16 time: 1873 cpu: 1873 gc: 0 mem: 160
;; 16 time: 1868 cpu: 1868 gc: 0 mem: 160
;; 15 time: 1512 cpu: 1513 gc: 0 mem: 160
;; 15 time: 1510 cpu: 1510 gc: 0 mem: 160
;; 15 time: 1512 cpu: 1511 gc: 0 mem: 160
;; 14 time: 1503 cpu: 1502 gc: 0 mem: 160
;; 14 time: 1508 cpu: 1508 gc: 0 mem: 160
;; 14 time: 1503 cpu: 1503 gc: 0 mem: 160
;; 13 time: 1793 cpu: 1792 gc: 0 mem: 160
;; 13 time: 1783 cpu: 1783 gc: 0 mem: 160
;; 13 time: 1783 cpu: 1783 gc: 0 mem: 160
;; 12 time: 1246 cpu: 1246 gc: 0 mem: 160
;; 12 time: 1251 cpu: 1251 gc: 0 mem: 160
;; 12 time: 1248 cpu: 1248 gc: 0 mem: 160
;; 6 time: 1257 cpu: 1257 gc: 0 mem: 160
;; 6 time: 1250 cpu: 1250 gc: 0 mem: 160
;; 6 time: 1245 cpu: 1245 gc: 0 mem: 160
;; 4 time: 1487 cpu: 1486 gc: 0 mem: 160
;; 4 time: 1488 cpu: 1488 gc: 0 mem: 160
;; 4 time: 1483 cpu: 1482 gc: 0 mem: 160
;; 3 time: 1000 cpu: 1000 gc: 0 mem: 160
;; 3 time: 999 cpu: 1000 gc: 0 mem: 160
;; 3 time: 1008 cpu: 1009 gc: 0 mem: 160
;; 1 time: 1006 cpu: 1006 gc: 0 mem: 160
;; 1 time: 988 cpu: 987 gc: 0 mem: 160
;; 1 time: 990 cpu: 989 gc: 0 mem: 160
;; nil
;; arc> (do l.read-barr2 (ga read-barrier5 4) (= N 100 k 8000000 g time:nerb.N h time:make-narb.g) (prn:* g.1 8) (time:read-barrier5-thing read-barrier5 h N 1 k))time: 1 cpu: 1 gc: 0 mem: 76704
;; time: 1 cpu: 0 gc: 0 mem: 6816
;; 49632
;; time: 952 cpu: 953 gc: 0 mem: 2912
;; 49632
;; arc> (each x (rev '(1 1 1 3 3 3 4 4 4 6 6 6 12 12 12 13 13 13 14 14 14 15 15 15 16 16 16 17 17 17)) (do (= h make-narb.g) (pr x " ") (time:read-barrier5-thing read-barrier5 h N x k)))
;; 17 time: 1954 cpu: 1953 gc: 0 mem: 160
;; 17 time: 1964 cpu: 1963 gc: 0 mem: 160
;; 17 time: 1947 cpu: 1947 gc: 0 mem: 160
;; 16 time: 1871 cpu: 1870 gc: 0 mem: 160
;; 16 time: 1869 cpu: 1869 gc: 0 mem: 160
;; 16 time: 1870 cpu: 1870 gc: 0 mem: 160
;; 15 time: 1670 cpu: 1670 gc: 0 mem: 160
;; 15 time: 1678 cpu: 1677 gc: 0 mem: 160
;; 15 time: 1672 cpu: 1672 gc: 0 mem: 160
;; 14 time: 1607 cpu: 1606 gc: 0 mem: 160
;; 14 time: 1607 cpu: 1606 gc: 0 mem: 160
;; 14 time: 1606 cpu: 1606 gc: 0 mem: 160
;; 13 time: 1748 cpu: 1748 gc: 0 mem: 160
;; 13 time: 1719 cpu: 1719 gc: 0 mem: 192
;; 13 time: 1699 cpu: 1700 gc: 0 mem: 160
;; 12 time: 1327 cpu: 1327 gc: 0 mem: 160
;; 12 time: 1334 cpu: 1333 gc: 0 mem: 160
;; 12 time: 1330 cpu: 1331 gc: 0 mem: 160
;; 6 time: 1338 cpu: 1338 gc: 0 mem: 160
;; 6 time: 1342 cpu: 1342 gc: 0 mem: 160
;; 6 time: 1343 cpu: 1343 gc: 0 mem: 160
;; 4 time: 1458 cpu: 1458 gc: 0 mem: 160
;; 4 time: 1459 cpu: 1458 gc: 0 mem: 160
;; 4 time: 1460 cpu: 1460 gc: 0 mem: 160
;; 3 time: 1134 cpu: 1134 gc: 0 mem: 160
;; 3 time: 1136 cpu: 1136 gc: 0 mem: 160
;; 3 time: 1107 cpu: 1107 gc: 0 mem: 160
;; 1 time: 967 cpu: 967 gc: 0 mem: 160
;; 1 time: 961 cpu: 961 gc: 0 mem: 160
;; 1 time: 951 cpu: 951 gc: 0 mem: 160
;; nil
;; arc> (do l.read-barr2 (ga read-barrier5 4) (= N 10 k 80000000 g time:nerb.N h time:make-narb.g) (prn:* g.1 8) (time:read-barrier5-thing read-barrier5 h N 1 k))time: 1 cpu: 1 gc: 0 mem: 74704
;; time: 0 cpu: 1 gc: 0 mem: 3936
;; 4992
;; time: 919 cpu: 919 gc: 0 mem: 2912
;; 4992
;; arc> (each x (rev '(1 1 1 3 3 3 4 4 4 6 6 6 12 12 12 13 13 13 14 14 14 15 15 15 16 16 16 17 17 17)) (do (= h make-narb.g) (pr x " ") (time:read-barrier5-thing read-barrier5 h N x k)))
;; 17 time: 2270 cpu: 2270 gc: 0 mem: 160
;; 17 time: 2268 cpu: 2268 gc: 0 mem: 160
;; 17 time: 2262 cpu: 2262 gc: 0 mem: 160
;; 16 time: 2343 cpu: 2344 gc: 0 mem: 160
;; 16 time: 2344 cpu: 2344 gc: 0 mem: 160
;; 16 time: 2343 cpu: 2343 gc: 0 mem: 160
;; 15 time: 2069 cpu: 2069 gc: 0 mem: 160
;; 15 time: 2071 cpu: 2071 gc: 0 mem: 160
;; 15 time: 2068 cpu: 2069 gc: 0 mem: 160
;; 14 time: 2287 cpu: 2288 gc: 0 mem: 160
;; 14 time: 2288 cpu: 2289 gc: 0 mem: 160
;; 14 time: 2289 cpu: 2288 gc: 0 mem: 160
;; 13 time: 1789 cpu: 1788 gc: 0 mem: 160
;; 13 time: 1793 cpu: 1794 gc: 0 mem: 160
;; 13 time: 1797 cpu: 1797 gc: 0 mem: 160
;; 12 time: 1570 cpu: 1569 gc: 0 mem: 160
;; 12 time: 1570 cpu: 1569 gc: 0 mem: 160
;; 12 time: 1578 cpu: 1578 gc: 0 mem: 160
;; 6 time: 1754 cpu: 1755 gc: 0 mem: 160
;; 6 time: 1755 cpu: 1754 gc: 0 mem: 160
;; 6 time: 1724 cpu: 1724 gc: 0 mem: 160
;; 4 time: 1230 cpu: 1230 gc: 0 mem: 160
;; 4 time: 1235 cpu: 1235 gc: 0 mem: 160
;; 4 time: 1234 cpu: 1234 gc: 0 mem: 160
;; 3 time: 1152 cpu: 1153 gc: 0 mem: 160
;; 3 time: 1161 cpu: 1161 gc: 0 mem: 160
;; 3 time: 1162 cpu: 1162 gc: 0 mem: 160
;; 1 time: 912 cpu: 913 gc: 0 mem: 160
;; 1 time: 910 cpu: 910 gc: 0 mem: 160
;; 1 time: 914 cpu: 914 gc: 0 mem: 160
;; nil
;; arc> (do l.read-barr2 (ga read-barrier5 4) (= N 4 k 240000000 g time:nerb.N h time:make-narb.g) (prn:* g.1 8) (time:read-barrier5-thing read-barrier5 h N 1 k))time: 1 cpu: 1 gc: 0 mem: 74400
;; time: 0 cpu: 0 gc: 0 mem: 3744
;; 2496
;; time: 1491 cpu: 1491 gc: 0 mem: 2928
;; 2496
;; arc> (do l.read-barr2 (ga read-barrier5 4) (= N 4 k 240000000 g time:nerb.N h time:make-narb.g) (prn:* g.1 8) (time:read-barrier5-thing read-barrier5 h N 1 k))
;; time: 11 cpu: 11 gc: 8 mem: -32185624
;; time: 0 cpu: 0 gc: 0 mem: 1184
;; 1392
;; time: 1413 cpu: 1414 gc: 0 mem: 2272
;; 1392
;; arc> (do l.read-barr2 (ga read-barrier5 4) (= N 4 k 240000000 g time:nerb.N h time:make-narb.g) (prn:* g.1 8) (time:read-barrier5-thing read-barrier5 h N 1 k))
;; time: 0 cpu: 1 gc: 0 mem: 68640
;; time: 0 cpu: 1 gc: 0 mem: 1184
;; 3352
;; time: 1117 cpu: 1117 gc: 0 mem: 2272
;; 3352
;; arc> (do l.read-barr2 (ga read-barrier5 4) (= N 4 k 240000000 g time:nerb.N h time:make-narb.g) (prn:* g.1 8) (time:read-barrier5-thing read-barrier5 h N 1 k))
;; time: 1 cpu: 1 gc: 0 mem: 68480
;; time: 0 cpu: 0 gc: 0 mem: 1344
;; 1104
;; time: 1412 cpu: 1412 gc: 0 mem: 2272
;; 1104
;; arc> (do l.read-barr2 (ga read-barrier5 4) (= N 4 k 240000000 g time:nerb.N h time:make-narb.g) (prn:* g.1 8) (time:read-barrier5-thing read-barrier5 h N 1 k))
;; time: 1 cpu: 1 gc: 0 mem: 68320
;; time: 0 cpu: 0 gc: 0 mem: 2144
;; 800
;; time: 1409 cpu: 1409 gc: 0 mem: 2592
;; 800
;; arc> (do l.read-barr2 (ga read-barrier5 4) (= N 4 k 240000000 g time:nerb.N h time:make-narb.g) (prn:* g.1 8) (time:read-barrier5-thing read-barrier5 h N 1 k))
;; time: 1 cpu: 1 gc: 0 mem: 70400
;; time: 0 cpu: 0 gc: 0 mem: 2464
;; 2584
;; time: 1504 cpu: 1503 gc: 0 mem: 2592
;; 2584
;; arc> (do l.read-barr2 (ga read-barrier5 4) (= N 4 k 240000000 g time:nerb.N h time:make-narb.g) (prn:* g.1 8) (time:read-barrier5-thing read-barrier5 h N 1 k))
;; time: 0 cpu: 1 gc: 0 mem: 70880
;; time: 0 cpu: 0 gc: 0 mem: 2784
;; 2680
;; time: 1494 cpu: 1495 gc: 0 mem: 2592
;; 2680
;; arc> (do l.read-barr2 (ga read-barrier5 4) (= N 4 k 240000000 g time:nerb.N h time:make-narb.g) (prn:* g.1 8) (time:read-barrier5-thing read-barrier5 h N 1 k))
;; time: 1 cpu: 0 gc: 0 mem: 70560
;; time: 1 cpu: 0 gc: 0 mem: 2304
;; 2856
;; time: 1127 cpu: 1127 gc: 0 mem: 2432
;; 2856
;; arc> (each x (rev '(1 1 1 3 3 3 4 4 4 6 6 6 12 12 12 13 13 13 14 14 14 15 15 15 16 16 16 17 17 17)) (do (= h make-narb.g) (pr x " ") (time:read-barrier5-thing read-barrier5 h N x k)))
;; 17 time: 3266 cpu: 3266 gc: 0 mem: 160
;; 17 time: 3296 cpu: 3296 gc: 0 mem: 160
;; 17 time: 3268 cpu: 3268 gc: 0 mem: 160
;; 16 time: 3251 cpu: 3251 gc: 0 mem: 160
;; 16 time: 3269 cpu: 3269 gc: 0 mem: 160
;; 16 time: 3315 cpu: 3316 gc: 0 mem: 160
;; 15 time: 3139 cpu: 3139 gc: 0 mem: 160
;; 15 time: 3124 cpu: 3123 gc: 0 mem: 160
;; 15 time: 3140 cpu: 3140 gc: 0 mem: 160
;; 14 time: 3170 cpu: 3170 gc: 0 mem: 160
;; 14 time: 3191 cpu: 3192 gc: 0 mem: 192
;; 14 time: 3177 cpu: 3177 gc: 0 mem: 160
;; 13 time: 2669 cpu: 2669 gc: 0 mem: 160
;; 13 time: 2673 cpu: 2673 gc: 0 mem: 160
;; 13 time: 2677 cpu: 2677 gc: 0 mem: 160
;; 12 time: 2228 cpu: 2229 gc: 0 mem: 160
;; 12 time: 2231 cpu: 2231 gc: 0 mem: 160
;; 12 time: 2227 cpu: 2227 gc: 0 mem: 160
;; 6 time: 2159 cpu: 2160 gc: 0 mem: 160
;; 6 time: 2153 cpu: 2152 gc: 0 mem: 160
;; 6 time: 2154 cpu: 2155 gc: 0 mem: 160
;; 4 time: 1709 cpu: 1709 gc: 0 mem: 160
;; 4 time: 1707 cpu: 1707 gc: 0 mem: 160
;; 4 time: 1707 cpu: 1708 gc: 0 mem: 160
;; 3 time: 1634 cpu: 1634 gc: 0 mem: 160
;; 3 time: 1639 cpu: 1639 gc: 0 mem: 160
;; 3 time: 1635 cpu: 1635 gc: 0 mem: 160
;; 1 time: 1132 cpu: 1131 gc: 0 mem: 160
;; 1 time: 1136 cpu: 1136 gc: 0 mem: 160
;; 1 time: 1147 cpu: 1147 gc: 0 mem: 160

        

        ;; Ok, so, 16 and 17 consistently perform terribly.
        ;; They also have more code size.
        ;; We can comfortably throw them out.
        ;; Next.
        ;; 14 and 15 are pretty comparable (also very similar).
        ;; I could also consider a variation involving MOVing 0 into ecx,
        ;; perhaps after a test (MOV does not change RFLAGS).
        ;; That'd be in next round.
        ;; There is a case (N=10) where 14 does somewhat better than 15,
        ;; and another case where a little of the reverse is true.
        ;; Shall retest those...
        ;; Mmm, the difference seems to disappear with further exp.
        ;; Well, then...
        ;; Mmmph...
        ;; Anyway.  13 was my favorite going in. W.r.t. 14/15, it seems
        ;; to bear a mild or zero disadvantage at high N, but is superior
        ;; at lower N.  Hmm.
        ;; Next step: try the mov ecx thing, which will possibly be better
        ;; pipelined than 14 or 15.
        ;; ... I'll drop the one I don't like.
        ;; Also plain dropping 16 and 17.
        


        