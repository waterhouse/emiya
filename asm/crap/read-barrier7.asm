

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
        push r14

        ;; for testing xxxx things...
;;         arc> (num->digs 4398783577 2)
;; (1 0 0 0 0 0 1 1 0 0 0 1 1 0 0 0 0 0 0 0 1 1 1 0 0 0 1 0 1 1 0 0 1)
        ;; that's 33 bits.
        ;; so 2^31 + 2^30, i.e. 11000..., i.e. -0x40000000, is a test xxxx.
        ;; and 31 can be a bt xxxx.
        ;; eh, neh, write positively. I can.
        mov rbx, rsp
        mov rax, 0xc0000000
        mov [rbx - 40], rax     ;must avoid sign extension of dicks

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

        
        


        lea r14, [rel only_ptrs]
        ;; cmp rdx, 0
        ;; je only_ptrs            ;only turn offsets to ptrs
        lea rax, [rel no_checking]
        cmp rdx, 1
        cmove r14, rax          ;no read barrier, no typecheck
        ;; cmp rdx, 2
        ;; je typecheck_a           ;typecheck: special: test 110, jnz, test 001, jz
        lea rax, [rel typecheck_b]
        cmp rdx, 3
        cmove r14, rax          ;typecheck: load 111, and, jz ;uses reg
        lea rax, [rel typecheck_c]
        cmp rdx, 4
        cmove r14, rax          ;typecheck: xor 001, test 111, jnz ;changes ptr
        lea rax, [rel typecheck_car]
        cmp rdx, 5
        cmove r14, rax        ;car, cdr as subroutines

        lea rax, [rel typecheck_b_barr]
        cmp rdx, 6
        cmove r14, rax    ;test reg, [mem]
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

        lea rax, [rel typecheck_b_barr_ret]
        cmp rdx, 12
        cmove r14, rax
        lea rax, [rel typecheck_b_dumb_dumb1]
        cmp rdx, 13
        cmove r14, rax ;read barrs on car and cdr; 110 used as ptr check mask
        lea rax, [rel typecheck_b_dumb_dumb2]
        cmp rdx, 14               ;--or, no, 011; I'm pretending 001 is cons
        cmove r14, rax
        lea rax, [rel typecheck_b_dumb_dumb3]
        cmp rdx, 15
        cmove r14, rax
        ;; cmp rdx, 16
        ;; je typecheck_b_dumb_dumb4
        ;; cmp rdx, 17
        ;; je typecheck_b_dumb_dumb5
        lea rax, [rel typecheck_b_dumb_dumb6]
        cmp rdx, 18
        cmove r14, rax
        
        call ptrify
                
metaloop:

        ;; lea rax, [rel typecheck_b_barr_ret]
        ;; sub rax, r14
        ;; jmp return
        
        mov rdx, r9
        call r14
        dec r8
        mov rdi, r10
        mov rsi, r11
        
        jnz metaloop

return: 

        pop r14
        pop r15
        pop rbx
        ret
        
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
        test rdi, [rbx - 40]    ;geh, offset
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


typecheck_b_dumb_dumb6:  
        xor eax, eax
typecheck_b_dumb_dumb6_loop:
        mov cl, 7
        and cl, dil
        cmp cl, 1
        jnz typecheck_b_fail    ;too lazy to change
        mov rdx, [rdi-1]
        ;; now read barr
        test dl, 011
        mov ecx, 0
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
        test dil, 011
        mov ecx, 0
        cmovnz rcx, rdi
        test rcx, [rbx - 40]
        jnz typecheck_b_barr_fail
        ;; and loop
        dec rsi
        jnz typecheck_b_dumb_dumb6_loop
        ret

        
        
        

        ;; 1. mov ecx, 011; and cl, dil; cmovnz rcx, rdx; test rcx, [mem]
        ;; 2. xor ecx, ecx; test dil, 011; cmovnz rcx, rdx; test rcx, [mem]
        ;; 3. test rdx, 011; jz non_ptr; test rdx, [mem]; jnz barr; non_ptr: ... barr: ...
        ;; 4. test rdx, 011; jnz ptr; fine: ... ptr: test [mem]; jnz fine; barr: ...
        ;; 5. test rdx, 011; jnz ptr; jmp fine; [... I can't finish this, should be 3]
        ;; 6. mov cl, 7; and cl, dil; test
        ;; ...
        ;; 7. mov ecx, 7; and cl, dil; test rdx, [r15 + 8 * rcx]; jnz barr; ...
        ;; ^ LOLOLOLOLOLOLOLOLOLOL AWESOME [TERRIBLE]        
        

        




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
        

        ;; Hmm, time to equalize some crap.
        ;; Just to be sure.

        ;; All right, time for huge statistics dump.  Fairly exhaustive.
        ;; I didn't go up to N=1.2M,k=1 because that led to some addresses not having
        ;; both their 2^31 and 2^30 digits as 0.  (This caused things to hit the
        ;;  read barrier.  I guess that shows it works, at least.)

;; arc> (do l.read-barr2 (ga read-barrier7 4) (each (N k) master-list (prsn "With" N k) (pr "Setup: ") (= g time:nerb.N) (each x '(1 3 3 4 4 1 6 6 12 12 1 13 13 1 14 14 15 15 1 18 18 1 3 4 6 12 13 14 15 18) (= h nil h make-narb.g) (pr x " ") (let answer (* g.1 8) (let res (time:read-barrier7-thing read-barrier7 h N x k) (unless (is res answer) (prsn "FAILURE" res "EXPECTED" answer))))) sleep.4))
;; With 4 250000000
;; Setup: time: 1 cpu: 1 gc: 0 mem: 74400
;; 1 time: 1001 cpu: 1000 gc: 0 mem: 3088
;; 3 time: 1657 cpu: 1657 gc: 0 mem: 160
;; 3 time: 1629 cpu: 1629 gc: 0 mem: 160
;; 4 time: 1488 cpu: 1489 gc: 0 mem: 160
;; 4 time: 1486 cpu: 1487 gc: 0 mem: 160
;; 1 time: 1000 cpu: 1000 gc: 0 mem: 160
;; 6 time: 1879 cpu: 1879 gc: 0 mem: 160
;; 6 time: 1876 cpu: 1876 gc: 0 mem: 160
;; 12 time: 1851 cpu: 1852 gc: 0 mem: 160
;; 12 time: 1877 cpu: 1877 gc: 0 mem: 160
;; 1 time: 1004 cpu: 1004 gc: 0 mem: 160
;; 13 time: 2229 cpu: 2228 gc: 0 mem: 160
;; 13 time: 2235 cpu: 2236 gc: 0 mem: 160
;; 1 time: 1001 cpu: 1001 gc: 0 mem: 160
;; 14 time: 2823 cpu: 2823 gc: 0 mem: 160
;; 14 time: 2823 cpu: 2823 gc: 0 mem: 160
;; 15 time: 2637 cpu: 2636 gc: 0 mem: 160
;; 15 time: 2649 cpu: 2649 gc: 0 mem: 160
;; 1 time: 1000 cpu: 1000 gc: 0 mem: 160
;; 18 time: 2809 cpu: 2809 gc: 0 mem: 160
;; 18 time: 2807 cpu: 2807 gc: 0 mem: 160
;; 1 time: 1000 cpu: 1001 gc: 0 mem: 160
;; 3 time: 1622 cpu: 1623 gc: 0 mem: 160
;; 4 time: 1495 cpu: 1494 gc: 0 mem: 160
;; 6 time: 1871 cpu: 1870 gc: 0 mem: 160
;; 12 time: 1874 cpu: 1874 gc: 0 mem: 160
;; 13 time: 2237 cpu: 2236 gc: 0 mem: 160
;; 14 time: 2820 cpu: 2820 gc: 0 mem: 160
;; 15 time: 2646 cpu: 2647 gc: 0 mem: 160
;; 18 time: 2818 cpu: 2818 gc: 0 mem: 160
;; With 10 130000000
;; Setup: time: 0 cpu: 0 gc: 0 mem: 624
;; 1 time: 1005 cpu: 1005 gc: 0 mem: 160
;; 3 time: 1953 cpu: 1953 gc: 0 mem: 160
;; 3 time: 1951 cpu: 1950 gc: 0 mem: 160
;; 4 time: 1846 cpu: 1846 gc: 0 mem: 160
;; 4 time: 1846 cpu: 1846 gc: 0 mem: 160
;; 1 time: 1001 cpu: 1000 gc: 0 mem: 160
;; 6 time: 2220 cpu: 2220 gc: 0 mem: 160
;; 6 time: 2217 cpu: 2217 gc: 0 mem: 160
;; 12 time: 2137 cpu: 2137 gc: 0 mem: 160
;; 12 time: 2138 cpu: 2137 gc: 0 mem: 160
;; 1 time: 1003 cpu: 1003 gc: 0 mem: 160
;; 13 time: 2666 cpu: 2666 gc: 0 mem: 160
;; 13 time: 2652 cpu: 2652 gc: 0 mem: 160
;; 1 time: 1000 cpu: 1000 gc: 0 mem: 160
;; 14 time: 3567 cpu: 3567 gc: 0 mem: 160
;; 14 time: 3574 cpu: 3574 gc: 0 mem: 160
;; 15 time: 3228 cpu: 3228 gc: 0 mem: 160
;; 15 time: 3242 cpu: 3242 gc: 0 mem: 160
;; 1 time: 1008 cpu: 1007 gc: 0 mem: 160
;; 18 time: 3421 cpu: 3421 gc: 0 mem: 160
;; 18 time: 3423 cpu: 3423 gc: 0 mem: 160
;; 1 time: 1012 cpu: 1012 gc: 0 mem: 160
;; 3 time: 1964 cpu: 1964 gc: 0 mem: 160
;; 4 time: 1865 cpu: 1865 gc: 0 mem: 160
;; 6 time: 2238 cpu: 2238 gc: 0 mem: 160
;; 12 time: 2132 cpu: 2132 gc: 0 mem: 160
;; 13 time: 2666 cpu: 2666 gc: 0 mem: 160
;; 14 time: 3510 cpu: 3510 gc: 0 mem: 160
;; 15 time: 3245 cpu: 3245 gc: 0 mem: 160
;; 18 time: 3420 cpu: 3419 gc: 0 mem: 160
;; With 100 8000000
;; Setup: time: 1 cpu: 0 gc: 0 mem: 2784
;; 1 time: 1272 cpu: 1272 gc: 0 mem: 160
;; 3 time: 1069 cpu: 1070 gc: 0 mem: 160
;; 3 time: 1072 cpu: 1072 gc: 0 mem: 160
;; 4 time: 1454 cpu: 1454 gc: 0 mem: 160
;; 4 time: 1453 cpu: 1453 gc: 0 mem: 160
;; 1 time: 948 cpu: 948 gc: 0 mem: 160
;; 6 time: 1334 cpu: 1334 gc: 0 mem: 160
;; 6 time: 1336 cpu: 1335 gc: 0 mem: 160
;; 12 time: 1321 cpu: 1321 gc: 0 mem: 160
;; 12 time: 1314 cpu: 1314 gc: 0 mem: 160
;; 1 time: 947 cpu: 947 gc: 0 mem: 160
;; 13 time: 1738 cpu: 1739 gc: 0 mem: 160
;; 13 time: 1700 cpu: 1699 gc: 0 mem: 160
;; 1 time: 946 cpu: 947 gc: 0 mem: 160
;; 14 time: 1734 cpu: 1733 gc: 0 mem: 160
;; 14 time: 1736 cpu: 1736 gc: 0 mem: 160
;; 15 time: 1658 cpu: 1659 gc: 0 mem: 160
;; 15 time: 1661 cpu: 1660 gc: 0 mem: 160
;; 1 time: 947 cpu: 948 gc: 0 mem: 160
;; 18 time: 1736 cpu: 1735 gc: 0 mem: 160
;; 18 time: 1733 cpu: 1733 gc: 0 mem: 160
;; 1 time: 948 cpu: 948 gc: 0 mem: 160
;; 3 time: 1073 cpu: 1073 gc: 0 mem: 160
;; 4 time: 1457 cpu: 1457 gc: 0 mem: 160
;; 6 time: 1336 cpu: 1336 gc: 0 mem: 160
;; 12 time: 1318 cpu: 1318 gc: 0 mem: 160
;; 13 time: 1756 cpu: 1756 gc: 0 mem: 160
;; 14 time: 1736 cpu: 1736 gc: 0 mem: 160
;; 15 time: 1655 cpu: 1655 gc: 0 mem: 160
;; 18 time: 1730 cpu: 1731 gc: 0 mem: 160
;; With 1000 800000
;; Setup: time: 1 cpu: 1 gc: 0 mem: 24384
;; 1 time: 1323 cpu: 1324 gc: 0 mem: 160
;; 3 time: 995 cpu: 995 gc: 0 mem: 160
;; 3 time: 999 cpu: 1000 gc: 0 mem: 160
;; 4 time: 1481 cpu: 1481 gc: 0 mem: 160
;; 4 time: 1478 cpu: 1479 gc: 0 mem: 160
;; 1 time: 1327 cpu: 1326 gc: 0 mem: 160
;; 6 time: 1247 cpu: 1246 gc: 0 mem: 160
;; 6 time: 1242 cpu: 1241 gc: 0 mem: 160
;; 12 time: 1243 cpu: 1243 gc: 0 mem: 160
;; 12 time: 1242 cpu: 1242 gc: 0 mem: 160
;; 1 time: 1358 cpu: 1357 gc: 0 mem: 160
;; 13 time: 1490 cpu: 1490 gc: 0 mem: 160
;; 13 time: 1492 cpu: 1492 gc: 0 mem: 160
;; 1 time: 1332 cpu: 1332 gc: 0 mem: 160
;; 14 time: 1506 cpu: 1506 gc: 0 mem: 160
;; 14 time: 1505 cpu: 1505 gc: 0 mem: 160
;; 15 time: 1499 cpu: 1499 gc: 0 mem: 160
;; 15 time: 1495 cpu: 1495 gc: 0 mem: 160
;; 1 time: 1358 cpu: 1357 gc: 0 mem: 160
;; 18 time: 1506 cpu: 1506 gc: 0 mem: 160
;; 18 time: 1507 cpu: 1506 gc: 0 mem: 160
;; 1 time: 1344 cpu: 1344 gc: 0 mem: 160
;; 3 time: 997 cpu: 997 gc: 0 mem: 160
;; 4 time: 1477 cpu: 1478 gc: 0 mem: 160
;; 6 time: 1243 cpu: 1243 gc: 0 mem: 160
;; 12 time: 1244 cpu: 1244 gc: 0 mem: 160
;; 13 time: 1486 cpu: 1486 gc: 0 mem: 160
;; 14 time: 1507 cpu: 1507 gc: 0 mem: 160
;; 15 time: 1502 cpu: 1501 gc: 0 mem: 160
;; 18 time: 1505 cpu: 1505 gc: 0 mem: 160
;; With 10000 25000
;; Setup: time: 9 cpu: 9 gc: 0 mem: 240384
;; 1 time: 1009 cpu: 1009 gc: 0 mem: 160
;; 3 time: 1014 cpu: 1014 gc: 0 mem: 160
;; 3 time: 1009 cpu: 1009 gc: 0 mem: 160
;; 4 time: 1197 cpu: 1197 gc: 0 mem: 160
;; 4 time: 1194 cpu: 1195 gc: 0 mem: 160
;; 1 time: 1016 cpu: 1015 gc: 0 mem: 160
;; 6 time: 1018 cpu: 1019 gc: 0 mem: 160
;; 6 time: 1022 cpu: 1022 gc: 0 mem: 160
;; 12 time: 1019 cpu: 1019 gc: 0 mem: 160
;; 12 time: 1019 cpu: 1018 gc: 0 mem: 160
;; 1 time: 1014 cpu: 1014 gc: 0 mem: 160
;; 13 time: 991 cpu: 992 gc: 0 mem: 160
;; 13 time: 994 cpu: 994 gc: 0 mem: 160
;; 1 time: 1011 cpu: 1011 gc: 0 mem: 160
;; 14 time: 992 cpu: 992 gc: 0 mem: 160
;; 14 time: 989 cpu: 989 gc: 0 mem: 160
;; 15 time: 994 cpu: 994 gc: 0 mem: 160
;; 15 time: 992 cpu: 992 gc: 0 mem: 160
;; 1 time: 1013 cpu: 1014 gc: 0 mem: 160
;; 18 time: 991 cpu: 991 gc: 0 mem: 160
;; 18 time: 995 cpu: 995 gc: 0 mem: 160
;; 1 time: 1010 cpu: 1010 gc: 0 mem: 160
;; 3 time: 1014 cpu: 1014 gc: 0 mem: 160
;; 4 time: 1199 cpu: 1199 gc: 0 mem: 160
;; 6 time: 1023 cpu: 1023 gc: 0 mem: 160
;; 12 time: 1015 cpu: 1015 gc: 0 mem: 160
;; 13 time: 999 cpu: 999 gc: 0 mem: 160
;; 14 time: 991 cpu: 991 gc: 0 mem: 160
;; 15 time: 995 cpu: 995 gc: 0 mem: 160
;; 18 time: 992 cpu: 993 gc: 0 mem: 160
;; With 100000 1000
;; Setup: time: 43 cpu: 43 gc: 0 mem: 2400384
;; 1 time: 1059 cpu: 1059 gc: 0 mem: 160
;; 3 time: 1056 cpu: 1056 gc: 0 mem: 160
;; 3 time: 1061 cpu: 1060 gc: 0 mem: 160
;; 4 time: 1084 cpu: 1084 gc: 0 mem: 160
;; 4 time: 1087 cpu: 1088 gc: 0 mem: 160
;; 1 time: 1056 cpu: 1056 gc: 0 mem: 176
;; 6 time: 1061 cpu: 1061 gc: 0 mem: 160
;; 6 time: 1060 cpu: 1060 gc: 0 mem: 160
;; 12 time: 1062 cpu: 1062 gc: 0 mem: 160
;; 12 time: 1060 cpu: 1061 gc: 0 mem: 160
;; 1 time: 1056 cpu: 1056 gc: 0 mem: 160
;; 13 time: 1019 cpu: 1020 gc: 0 mem: 160
;; 13 time: 1014 cpu: 1015 gc: 0 mem: 160
;; 1 time: 1059 cpu: 1059 gc: 0 mem: 160
;; 14 time: 1013 cpu: 1013 gc: 0 mem: 160
;; 14 time: 1020 cpu: 1020 gc: 0 mem: 160
;; 15 time: 1015 cpu: 1015 gc: 0 mem: 160
;; 15 time: 1019 cpu: 1020 gc: 0 mem: 160
;; 1 time: 1057 cpu: 1057 gc: 0 mem: 160
;; 18 time: 1021 cpu: 1021 gc: 0 mem: 160
;; 18 time: 1017 cpu: 1017 gc: 0 mem: 160
;; 1 time: 1058 cpu: 1058 gc: 0 mem: 160
;; 3 time: 1056 cpu: 1056 gc: 0 mem: 160
;; 4 time: 1089 cpu: 1088 gc: 0 mem: 160
;; 6 time: 1061 cpu: 1060 gc: 0 mem: 160
;; 12 time: 1064 cpu: 1064 gc: 0 mem: 160
;; 13 time: 1020 cpu: 1021 gc: 0 mem: 160
;; 14 time: 1017 cpu: 1017 gc: 0 mem: 160
;; 15 time: 1019 cpu: 1019 gc: 0 mem: 160
;; 18 time: 1015 cpu: 1016 gc: 0 mem: 160

        ;; Ok, 15 decidedly beats 14 by a little bit.
        ;; Then...
        ;; We repeat earlier observations that 4 beats 3 by... 10% or so
        ;; at N=4 and 5% at N=10, and 3 beats 4 by 40% at N=100 and N=1000
        ;; and by 18% at N=10k and 3% at N=100k.
        ;; Surprisingly, 15 is decidedly better than 18 as well.
        ;; Next...
        ;; [This shit is specifically for my laptop's CPU...]
        ;; [An uber runtime could test and specialize for the current CPU...]
        ;; Interestingly, 6 tends to be just a tad more expensive than 12,
        ;; even though I describe 12 as being 6 with a little more added...
        ;; Let's see.
        ;; The interesting things are 1, 3, 12, 15.
        ;; 1 is no typechecks and no read barriers: baseline.
        ;; 3 is typechecks.
        ;; 12 is typechecks and one read barrier--relatively intelligent compiler.
        ;;    (The second read barrier can be folded into the code that raises a
        ;;    type error, which should be called rarely.)
        ;; 15 is typechecks and two read barriers--relatively dumb compiler.
        ;; First let's take 15 to represent read barriers.
        ;; We have seen that:
        ;; At N=4, 3 is 1.6x slower than 1, and 15 is 1.6x slower than 3.
        ;; At N=10, 3 is 1.9x slower than 1, and 15 is 1.6x slower than 3. [Probably still fits in L1 cache w/ less overhead.]
        ;; At N=100, 3 is 1.13x slower than 1, and 15 is 1.6x slower than 3.
        ;; At N=1000, 3 is comparable to 1 [sigh, 1 acts sillily], and 15 is 1.5x slower than 3.
        ;; At N>=10000, 1 and 3 and 15 are comparable.

        ;; Meanwhile, if we look at 12:
        ;; At N=4, 12 is 1.2x slower than 3.
        ;; At N=10, 12 is 1.09x slower than 3.
        ;; At N=100, 12 is 1.25x slower than 3.
        ;; At N=1000, 12 is 1.25x slower than 3.
        ;; At N>=10000, 12 is comparable to 3.

        ;; Looping through an array should naively be fairly similar to N=10 or 100, although
        ;; if we loop through the whole thing, then it is a relatively obvious optimization
        ;; (which may be difficult for the compiler to do automatically, but it should be
        ;;  easy to provide primitives that loop through a whole array) to read-barr
        ;; either the whole thing first or

        ;; Oh, right, there's also the 13 contender.
        ;; 13 is 20% superior to 15 at N=4, 30% superior at N=10,
        ;; and about 8% inferior at N=100, and comparable elsewhere.
        ;; Come to think of it... maybe I could combine 13's approach with 4's typecheck
        ;; and maybe get something that's always superior to 15.
        ;; Kk let's try. Dump 14.
        ;; Also for completeness try isolating a car.

        ;; Communication from the future:
        ;; hmm.
        ;; actually, since I zero out the type tag in typecheck_c,
        ;; I don't need to screw around much...
        ;; this may lead to some complicated code registration
        ;; for arbitrary interrupts.
        ;; ... actually, since I zero out the type tag,
        ;; there is no way to adapt the 13 approach.
        ;; the compiler must be intelligent enough.
        ;; hmmph.
        ;; ... hmm...
        ;; Some more results.

;; With 50 18000000
;; Setup: time: 0 cpu: 1 gc: 0 mem: 1584
;; 1 time: 1378 cpu: 1377 gc: 0 mem: 160
;; 3 time: 1282 cpu: 1283 gc: 0 mem: 160
;; 3 time: 1284 cpu: 1284 gc: 0 mem: 160
;; 4 time: 1584 cpu: 1583 gc: 0 mem: 160
;; 4 time: 1587 cpu: 1587 gc: 0 mem: 160
;; 1 time: 1506 cpu: 1506 gc: 0 mem: 160
;; 6 time: 1597 cpu: 1598 gc: 0 mem: 160
;; 6 time: 1599 cpu: 1599 gc: 0 mem: 160
;; 12 time: 1601 cpu: 1601 gc: 0 mem: 160
;; 12 time: 1598 cpu: 1598 gc: 0 mem: 160
;; 1 time: 1372 cpu: 1372 gc: 0 mem: 160
;; 13 time: 1856 cpu: 1856 gc: 0 mem: 160
;; 13 time: 2051 cpu: 2051 gc: 0 mem: 160
;; 1 time: 1348 cpu: 1349 gc: 0 mem: 160
;; 15 time: 2041 cpu: 2041 gc: 0 mem: 160
;; 15 time: 2050 cpu: 2050 gc: 0 mem: 160
;; 1 time: 1288 cpu: 1288 gc: 0 mem: 160
;; 18 time: 2224 cpu: 2224 gc: 0 mem: 160
;; 18 time: 2212 cpu: 2212 gc: 0 mem: 160
;; 1 time: 1008 cpu: 1008 gc: 0 mem: 160
;; 3 time: 1290 cpu: 1290 gc: 0 mem: 160
;; 4 time: 1593 cpu: 1592 gc: 0 mem: 160
;; 6 time: 1607 cpu: 1608 gc: 0 mem: 160
;; 12 time: 1605 cpu: 1605 gc: 0 mem: 160
;; 13 time: 2055 cpu: 2056 gc: 0 mem: 160
;; 15 time: 2057 cpu: 2057 gc: 0 mem: 160
;; 18 time: 2233 cpu: 2233 gc: 0 mem: 160

        ;; So 13 and 15 are comparable at N=50.
        ;; I think 13 is superior on x86 (-64) machines.
        ;; Less portable, obviously, but obviously this is x86 asm.
        ;; (Since there are different flavors of x86-64--e.g. there
        ;;  are extra bit-manipulation things introduced in prob. Ivy
        ;;  Bridge--I think it makes sense to call this x86.)
        ;; For uber-completeness, I could write a version of 12 that
        ;; used 13's read barrier.
        ;; ... Fine, all right, I'll do it.
        ;; And the fucking car that uses the 13 barr.
        


        ;; Fyi.
;; arc> grid.master-list
;;      4 250000000
;;     10 130000000
;;    100   8000000
;;   1000    800000
;;  10000     25000
;; 100000      1000
        

        



        