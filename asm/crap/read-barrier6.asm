

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
        ;; cmp rdx, 16
        ;; je typecheck_b_dumb_dumb4
        ;; cmp rdx, 17
        ;; je typecheck_b_dumb_dumb5
        cmp rdx, 18
        je typecheck_b_dumb_dumb6
        
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
        