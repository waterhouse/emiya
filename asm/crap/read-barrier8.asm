

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
        ;; lea rax, [rel typecheck_b_dumb_dumb2]
        ;; cmp rdx, 14               ;--or, no, 011; I'm pretending 001 is cons
        ;; cmove r14, rax
        lea rax, [rel typecheck_b_dumb_dumb3]
        cmp rdx, 15
        cmove r14, rax
        ;; cmp rdx, 16
        ;; je typecheck_b_dumb_dumb4
        ;; cmp rdx, 17
        ;; je typecheck_b_dumb_dumb5
        ;; lea rax, [rel typecheck_b_dumb_dumb6]
        ;; cmp rdx, 18
        ;; cmove r14, rax
        lea rax, [rel typecheck_b_better_12]
        cmp rdx, 19
        cmove r14, rax
        lea rax, [rel typecheck_b_cadr_13]
        cmp rdx, 20
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


        ;; ok, actually it turns out 12 basically assumed the cdr
        ;; was a pointer, and therefore 13's approach offers no benefits.
        ;; what I can at least do is eliminate the "mov ecx" thing, because
        ;; that turns out (by a below analysis) to be actually probably less
        ;; efficient code-size-wise.

typecheck_b_better_12: 
        xor eax, eax
typecheck_b_better_12_loop:    
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
        ;; now read barr
        test rdi, [rbx - 40]    ;geh, offset
        jnz typecheck_b_barr_fail
        dec rsi
        jnz typecheck_b_better_12_loop
        ret

        ;; finally we have the car approach.


typecheck_b_cadr_13:    
        xor eax, eax
typecheck_b_cadr_13_loop:     
        call barr_13_car_rdi_rcx
        test cl, 7
        jnz typecheck_car_fail
        add rax, rcx
        jc typecheck_car_carry
        call barr_13_cdr_rdi_rcx
        mov rdi, rcx
        dec rsi
        jnz typecheck_car_loop
        ret
typecheck_b_cadr_13_fail:
        mov rax, 2094
        ret
typecheck_b_cadr_13_carry:
        mov rax, 2074
        ret
        
barr_13_car_rdi_rcx:
        ;; typecheck
        mov cl, 7
        and cl, dil
        cmp cl, 1
        jne barr_13_car_rdi_rcx_fail
        ;; car
        mov rcx, [rdi-1]
        ;; barr
        mov edx, 7
        and dl, cl
        test rcx, [r15 + 8 * rdx]
        jnz barr_13_car_rdi_rcx_fail
        ret
barr_13_car_rdi_rcx_fail:
        add rsp, 8
        mov rax, 2077
        ret

barr_13_cdr_rdi_rcx:
        ;; typecheck
        mov cl, 7
        and cl, dil
        cmp cl, 1
        jne barr_13_cdr_rdi_rcx_fail
        ;; car
        mov rcx, [rdi+7]
        ;; barr
        mov edx, 7
        and dl, cl
        test rcx, [r15 + 8 * rdx]
        jnz barr_13_cdr_rdi_rcx_fail
        ret
barr_13_cdr_rdi_rcx_fail:
        add rsp, 8
        mov rax, 2078
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

        ;; Oh, damn.
        ;; I must also account for the overhead of the metaloop and the ptrifying.
        ;; Actually it's just the metaloop: ptrifying is called once.

        ;; Well, then, it looks like, at small N (<50),
        ;; typechecking costs 2x, and the smart version (12, 19) costs
        ;; about 1.5x on top of typechecking, and the double barrier (13, 15)
        ;; costs about 2x on top of typechecking.
        ;; At N=100, typechecking has 1x overhead (none), and single and double
        ;; barriers cost 1.3x and 1.6x respectively.
        ;; N=330, same story.
        ;; N=1000, more like 1x, 1.25x, 1.5x.
        ;; N=10000, 1x, 1x, 1x.
        ;; N=100k, about 1x all around.
        ;; And in this measurement, 15 never beat 13.  Interesting.
        ;; Actually, more spec. about the small N:
        ;; N=4: 2.1x typecheck, add. 1.5x single barr, 2x double barr.
        ;; N=10: 2.1x typecheck, add. 1.3x single barr, 1.8x double barr. (mental arithmetic in all this...)
        ;; N=50: 1.3x typecheck, add. 1.25x single barr, 1.75x double barr.
        ;; N=100: 1.1x typecheck, add. 1.25x single barr, 1.6x double barr.
        ;; N=330: 1.03x typecheck, add. 1.27x single barr, 1.55x double barr.
        ;; N=1000: 1x typecheck, add. 1.25x single barr, 1.5x double barr.
        ;; N=3300: 1x typecheck, 1.04x single barr, 1.25x double barr.
        ;; N=10000: 1x 1x 1x
        ;; N=100000: 1x 1x 1x

        ;; "pbpaste | grep '^(3|1|13|19|0|With) '" is helpful (grep = grep -P --color=auto)


;; arc> (do l.read-barr2 (ga read-barrier8 4) (each (N k) master-list (prsn "With" N k) (pr "Setup: ") (= g time:nerb.N) (each x '(0 1 3 3 4 4 1 6 6 12 12 1 13 13 15 15 1 19 19 20 20 0 1 3 4 6 12 13 15 19 20) (= h nil h make-narb.g) (pr x " ") (let answer (* g.1 8) (let res (time:read-barrier8-thing read-barrier8 h N x k) (unless (or (is res answer) (is x 0)) (prsn "FAILURE" res "EXPECTED" answer))))) sleep.4))
;; With 4 250000000
;; Setup: time: 1 cpu: 1 gc: 0 mem: 73920
;; 0 time: 540 cpu: 540 gc: 0 mem: 2912
;; 1 time: 1010 cpu: 1009 gc: 0 mem: 160
;; 3 time: 1551 cpu: 1551 gc: 0 mem: 160
;; 3 time: 1540 cpu: 1540 gc: 0 mem: 160
;; 4 time: 1539 cpu: 1539 gc: 0 mem: 160
;; 4 time: 1534 cpu: 1534 gc: 0 mem: 160
;; 1 time: 1000 cpu: 1000 gc: 0 mem: 160
;; 6 time: 1894 cpu: 1893 gc: 0 mem: 160
;; 6 time: 1900 cpu: 1901 gc: 0 mem: 160
;; 12 time: 1970 cpu: 1969 gc: 0 mem: 160
;; 12 time: 1982 cpu: 1981 gc: 0 mem: 160
;; 1 time: 996 cpu: 997 gc: 0 mem: 160
;; 13 time: 2533 cpu: 2532 gc: 0 mem: 160
;; 13 time: 2541 cpu: 2541 gc: 0 mem: 160
;; 15 time: 2925 cpu: 2925 gc: 0 mem: 160
;; 15 time: 2953 cpu: 2953 gc: 0 mem: 160
;; 1 time: 1001 cpu: 1001 gc: 0 mem: 160
;; 19 time: 1927 cpu: 1927 gc: 0 mem: 160
;; 19 time: 1929 cpu: 1929 gc: 0 mem: 160
;; 20 time: 4242 cpu: 4243 gc: 0 mem: 160
;; 20 time: 4235 cpu: 4235 gc: 0 mem: 160
;; 0 time: 542 cpu: 541 gc: 0 mem: 160
;; 1 time: 1003 cpu: 1003 gc: 0 mem: 160
;; 3 time: 1545 cpu: 1546 gc: 0 mem: 160
;; 4 time: 1539 cpu: 1539 gc: 0 mem: 160
;; 6 time: 1893 cpu: 1894 gc: 0 mem: 160
;; 12 time: 2004 cpu: 2003 gc: 0 mem: 160
;; 13 time: 2538 cpu: 2538 gc: 0 mem: 160
;; 15 time: 2947 cpu: 2948 gc: 0 mem: 160
;; 19 time: 1926 cpu: 1926 gc: 0 mem: 160
;; 20 time: 4249 cpu: 4249 gc: 0 mem: 160
;; With 10 130000000
;; Setup: time: 0 cpu: 0 gc: 0 mem: 624
;; 0 time: 291 cpu: 291 gc: 0 mem: 160
;; 1 time: 997 cpu: 998 gc: 0 mem: 160
;; 3 time: 1846 cpu: 1846 gc: 0 mem: 160
;; 3 time: 1838 cpu: 1838 gc: 0 mem: 160
;; 4 time: 1851 cpu: 1851 gc: 0 mem: 160
;; 4 time: 1854 cpu: 1854 gc: 0 mem: 160
;; 1 time: 998 cpu: 999 gc: 0 mem: 160
;; 6 time: 2233 cpu: 2233 gc: 0 mem: 160
;; 6 time: 2233 cpu: 2233 gc: 0 mem: 160
;; 12 time: 2288 cpu: 2289 gc: 0 mem: 160
;; 12 time: 2285 cpu: 2285 gc: 0 mem: 160
;; 1 time: 997 cpu: 997 gc: 0 mem: 160
;; 13 time: 2992 cpu: 2992 gc: 0 mem: 160
;; 13 time: 3005 cpu: 3005 gc: 0 mem: 160
;; 15 time: 3494 cpu: 3493 gc: 0 mem: 160
;; 15 time: 3539 cpu: 3539 gc: 0 mem: 160
;; 1 time: 1009 cpu: 1009 gc: 0 mem: 160
;; 19 time: 2226 cpu: 2226 gc: 0 mem: 160
;; 19 time: 2217 cpu: 2217 gc: 0 mem: 160
;; 20 time: 5136 cpu: 5136 gc: 0 mem: 160
;; 20 time: 5091 cpu: 5091 gc: 0 mem: 160
;; 0 time: 281 cpu: 281 gc: 0 mem: 160
;; 1 time: 1029 cpu: 1028 gc: 0 mem: 160
;; 3 time: 1902 cpu: 1903 gc: 0 mem: 160
;; 4 time: 1899 cpu: 1899 gc: 0 mem: 160
;; 6 time: 2315 cpu: 2314 gc: 0 mem: 160
;; 12 time: 2388 cpu: 2389 gc: 0 mem: 160
;; 13 time: 3053 cpu: 3053 gc: 0 mem: 160
;; 15 time: 3464 cpu: 3465 gc: 0 mem: 160
;; 19 time: 2198 cpu: 2198 gc: 0 mem: 160
;; 20 time: 5070 cpu: 5071 gc: 0 mem: 160
;; With 50 18000000
;; Setup: time: 0 cpu: 0 gc: 0 mem: 1584
;; 0 time: 44 cpu: 44 gc: 0 mem: 160
;; 1 time: 1007 cpu: 1006 gc: 0 mem: 160
;; 3 time: 1277 cpu: 1277 gc: 0 mem: 160
;; 3 time: 1274 cpu: 1274 gc: 0 mem: 160
;; 4 time: 1598 cpu: 1598 gc: 0 mem: 160
;; 4 time: 1598 cpu: 1597 gc: 0 mem: 160
;; 1 time: 1011 cpu: 1010 gc: 0 mem: 160
;; 6 time: 1615 cpu: 1614 gc: 0 mem: 160
;; 6 time: 1615 cpu: 1616 gc: 0 mem: 160
;; 12 time: 1588 cpu: 1588 gc: 0 mem: 160
;; 12 time: 1588 cpu: 1588 gc: 0 mem: 160
;; 1 time: 1009 cpu: 1009 gc: 0 mem: 160
;; 13 time: 2212 cpu: 2212 gc: 0 mem: 160
;; 13 time: 2126 cpu: 2126 gc: 0 mem: 160
;; 15 time: 2199 cpu: 2200 gc: 0 mem: 160
;; 15 time: 2205 cpu: 2206 gc: 0 mem: 160
;; 1 time: 1010 cpu: 1010 gc: 0 mem: 160
;; 19 time: 1556 cpu: 1556 gc: 0 mem: 160
;; 19 time: 1551 cpu: 1550 gc: 0 mem: 160
;; 20 time: 3463 cpu: 3464 gc: 0 mem: 160
;; 20 time: 3467 cpu: 3467 gc: 0 mem: 160
;; 0 time: 40 cpu: 40 gc: 0 mem: 160
;; 1 time: 1012 cpu: 1013 gc: 0 mem: 160
;; 3 time: 1273 cpu: 1273 gc: 0 mem: 160
;; 4 time: 1597 cpu: 1596 gc: 0 mem: 160
;; 6 time: 1607 cpu: 1606 gc: 0 mem: 160
;; 12 time: 1591 cpu: 1591 gc: 0 mem: 160
;; 13 time: 2115 cpu: 2115 gc: 0 mem: 160
;; 15 time: 2278 cpu: 2277 gc: 0 mem: 160
;; 19 time: 1595 cpu: 1596 gc: 0 mem: 160
;; 20 time: 3473 cpu: 3473 gc: 0 mem: 160
;; With 100 8000000
;; Setup: time: 1 cpu: 1 gc: 0 mem: 2816
;; 0 time: 23 cpu: 23 gc: 0 mem: 160
;; 1 time: 960 cpu: 960 gc: 0 mem: 160
;; 3 time: 1058 cpu: 1058 gc: 0 mem: 160
;; 3 time: 1060 cpu: 1060 gc: 0 mem: 160
;; 4 time: 1450 cpu: 1450 gc: 0 mem: 160
;; 4 time: 1446 cpu: 1446 gc: 0 mem: 160
;; 1 time: 947 cpu: 947 gc: 0 mem: 160
;; 6 time: 1316 cpu: 1315 gc: 0 mem: 160
;; 6 time: 1319 cpu: 1318 gc: 0 mem: 160
;; 12 time: 1319 cpu: 1319 gc: 0 mem: 160
;; 12 time: 1316 cpu: 1315 gc: 0 mem: 160
;; 1 time: 956 cpu: 957 gc: 0 mem: 160
;; 13 time: 1634 cpu: 1633 gc: 0 mem: 160
;; 13 time: 1660 cpu: 1661 gc: 0 mem: 160
;; 15 time: 1744 cpu: 1745 gc: 0 mem: 160
;; 15 time: 1735 cpu: 1735 gc: 0 mem: 160
;; 1 time: 949 cpu: 949 gc: 0 mem: 160
;; 19 time: 1306 cpu: 1305 gc: 0 mem: 160
;; 19 time: 1318 cpu: 1318 gc: 0 mem: 160
;; 20 time: 3044 cpu: 3044 gc: 0 mem: 160
;; 20 time: 3035 cpu: 3035 gc: 0 mem: 160
;; 0 time: 17 cpu: 17 gc: 0 mem: 160
;; 1 time: 983 cpu: 983 gc: 0 mem: 160
;; 3 time: 1061 cpu: 1061 gc: 0 mem: 160
;; 4 time: 1498 cpu: 1498 gc: 0 mem: 160
;; 6 time: 1331 cpu: 1332 gc: 0 mem: 160
;; 12 time: 1344 cpu: 1344 gc: 0 mem: 160
;; 13 time: 1644 cpu: 1644 gc: 0 mem: 160
;; 15 time: 1741 cpu: 1741 gc: 0 mem: 160
;; 19 time: 1317 cpu: 1317 gc: 0 mem: 160
;; 20 time: 3016 cpu: 3017 gc: 0 mem: 160
;; With 330 2500000
;; Setup: time: 0 cpu: 1 gc: 0 mem: 8304
;; 0 time: 10 cpu: 11 gc: 0 mem: 160
;; 1 time: 1018 cpu: 1018 gc: 0 mem: 160
;; 3 time: 1043 cpu: 1043 gc: 0 mem: 160
;; 3 time: 1041 cpu: 1041 gc: 0 mem: 160
;; 4 time: 1527 cpu: 1527 gc: 0 mem: 160
;; 4 time: 1535 cpu: 1535 gc: 0 mem: 160
;; 1 time: 1016 cpu: 1017 gc: 0 mem: 160
;; 6 time: 1306 cpu: 1307 gc: 0 mem: 160
;; 6 time: 1306 cpu: 1306 gc: 0 mem: 160
;; 12 time: 1310 cpu: 1310 gc: 0 mem: 160
;; 12 time: 1311 cpu: 1312 gc: 0 mem: 160
;; 1 time: 1019 cpu: 1019 gc: 0 mem: 160
;; 13 time: 1587 cpu: 1587 gc: 0 mem: 160
;; 13 time: 1586 cpu: 1587 gc: 0 mem: 160
;; 15 time: 1616 cpu: 1616 gc: 0 mem: 160
;; 15 time: 1615 cpu: 1615 gc: 0 mem: 160
;; 1 time: 1013 cpu: 1013 gc: 0 mem: 160
;; 19 time: 1303 cpu: 1304 gc: 0 mem: 160
;; 19 time: 1328 cpu: 1329 gc: 0 mem: 160
;; 20 time: 3154 cpu: 3155 gc: 0 mem: 160
;; 20 time: 3149 cpu: 3148 gc: 0 mem: 160
;; 0 time: 6 cpu: 6 gc: 0 mem: 160
;; 1 time: 1031 cpu: 1031 gc: 0 mem: 160
;; 3 time: 1040 cpu: 1040 gc: 0 mem: 160
;; 4 time: 1538 cpu: 1538 gc: 0 mem: 160
;; 6 time: 1301 cpu: 1301 gc: 0 mem: 160
;; 12 time: 1308 cpu: 1309 gc: 0 mem: 160
;; 13 time: 1583 cpu: 1584 gc: 0 mem: 160
;; 15 time: 1616 cpu: 1616 gc: 0 mem: 160
;; 19 time: 1298 cpu: 1298 gc: 0 mem: 160
;; 20 time: 3087 cpu: 3087 gc: 0 mem: 160
;; With 1000 800000
;; Setup: time: 2 cpu: 2 gc: 0 mem: 24384
;; 0 time: 4 cpu: 4 gc: 0 mem: 160
;; 1 time: 1315 cpu: 1315 gc: 0 mem: 160
;; 3 time: 989 cpu: 989 gc: 0 mem: 160
;; 3 time: 991 cpu: 991 gc: 0 mem: 160
;; 4 time: 1472 cpu: 1473 gc: 0 mem: 160
;; 4 time: 1482 cpu: 1482 gc: 0 mem: 160
;; 1 time: 1301 cpu: 1302 gc: 0 mem: 160
;; 6 time: 1247 cpu: 1247 gc: 0 mem: 160
;; 6 time: 1253 cpu: 1253 gc: 0 mem: 160
;; 12 time: 1254 cpu: 1254 gc: 0 mem: 160
;; 12 time: 1246 cpu: 1247 gc: 0 mem: 160
;; 1 time: 1335 cpu: 1335 gc: 0 mem: 160
;; 13 time: 1499 cpu: 1500 gc: 0 mem: 160
;; 13 time: 1494 cpu: 1494 gc: 0 mem: 160
;; 15 time: 1503 cpu: 1503 gc: 0 mem: 160
;; 15 time: 1504 cpu: 1504 gc: 0 mem: 160
;; 1 time: 1348 cpu: 1348 gc: 0 mem: 160
;; 19 time: 1244 cpu: 1244 gc: 0 mem: 160
;; 19 time: 1253 cpu: 1253 gc: 0 mem: 160
;; 20 time: 3002 cpu: 3003 gc: 0 mem: 160
;; 20 time: 2985 cpu: 2985 gc: 0 mem: 160
;; 0 time: 2 cpu: 2 gc: 0 mem: 160
;; 1 time: 1295 cpu: 1296 gc: 0 mem: 160
;; 3 time: 1028 cpu: 1028 gc: 0 mem: 160
;; 4 time: 1499 cpu: 1499 gc: 0 mem: 160
;; 6 time: 1275 cpu: 1275 gc: 0 mem: 160
;; 12 time: 1270 cpu: 1271 gc: 0 mem: 160
;; 13 time: 1505 cpu: 1505 gc: 0 mem: 160
;; 15 time: 1527 cpu: 1527 gc: 0 mem: 160
;; 19 time: 1262 cpu: 1263 gc: 0 mem: 160
;; 20 time: 3027 cpu: 3027 gc: 0 mem: 160
;; With 10000 25000
;; Setup: time: 8 cpu: 8 gc: 0 mem: 240384
;; 0 time: 0 cpu: 0 gc: 0 mem: 160
;; 1 time: 1038 cpu: 1038 gc: 0 mem: 160
;; 3 time: 1019 cpu: 1019 gc: 0 mem: 160
;; 3 time: 1003 cpu: 1003 gc: 0 mem: 160
;; 4 time: 1193 cpu: 1192 gc: 0 mem: 160
;; 4 time: 1194 cpu: 1194 gc: 0 mem: 160
;; 1 time: 1009 cpu: 1009 gc: 0 mem: 160
;; 6 time: 1014 cpu: 1015 gc: 0 mem: 160
;; 6 time: 1041 cpu: 1041 gc: 0 mem: 160
;; 12 time: 1047 cpu: 1047 gc: 0 mem: 160
;; 12 time: 1031 cpu: 1031 gc: 0 mem: 160
;; 1 time: 1014 cpu: 1015 gc: 0 mem: 160
;; 13 time: 1003 cpu: 1002 gc: 0 mem: 160
;; 13 time: 1023 cpu: 1023 gc: 0 mem: 160
;; 15 time: 998 cpu: 998 gc: 0 mem: 160
;; 15 time: 986 cpu: 985 gc: 0 mem: 160
;; 1 time: 1013 cpu: 1013 gc: 0 mem: 160
;; 19 time: 1019 cpu: 1020 gc: 0 mem: 160
;; 19 time: 1020 cpu: 1019 gc: 0 mem: 160
;; 20 time: 1119 cpu: 1120 gc: 0 mem: 160
;; 20 time: 1116 cpu: 1116 gc: 0 mem: 160
;; 0 time: 1 cpu: 0 gc: 0 mem: 160
;; 1 time: 1010 cpu: 1010 gc: 0 mem: 160
;; 3 time: 1008 cpu: 1007 gc: 0 mem: 160
;; 4 time: 1192 cpu: 1192 gc: 0 mem: 160
;; 6 time: 1011 cpu: 1012 gc: 0 mem: 160
;; 12 time: 1009 cpu: 1008 gc: 0 mem: 160
;; 13 time: 1006 cpu: 1007 gc: 0 mem: 160
;; 15 time: 1018 cpu: 1018 gc: 0 mem: 160
;; 19 time: 1063 cpu: 1063 gc: 0 mem: 160
;; 20 time: 1144 cpu: 1144 gc: 0 mem: 160
;; With 100000 1000
;; Setup: time: 45 cpu: 45 gc: 0 mem: 2400384
;; 0 time: 0 cpu: 0 gc: 0 mem: 160
;; 1 time: 1407 cpu: 1407 gc: 0 mem: 160
;; 3 time: 1096 cpu: 1096 gc: 0 mem: 160
;; 3 time: 1121 cpu: 1121 gc: 0 mem: 160
;; 4 time: 1149 cpu: 1149 gc: 0 mem: 160
;; 4 time: 1144 cpu: 1144 gc: 0 mem: 160
;; 1 time: 1106 cpu: 1106 gc: 0 mem: 160
;; 6 time: 1131 cpu: 1131 gc: 0 mem: 160
;; 6 time: 1121 cpu: 1121 gc: 0 mem: 160
;; 12 time: 1108 cpu: 1108 gc: 0 mem: 160
;; 12 time: 1131 cpu: 1130 gc: 0 mem: 160
;; 1 time: 1118 cpu: 1119 gc: 0 mem: 160
;; 13 time: 1087 cpu: 1086 gc: 0 mem: 160
;; 13 time: 1077 cpu: 1077 gc: 0 mem: 160
;; 15 time: 1076 cpu: 1075 gc: 0 mem: 160
;; 15 time: 1063 cpu: 1063 gc: 0 mem: 160
;; 1 time: 1118 cpu: 1118 gc: 0 mem: 160
;; 19 time: 1122 cpu: 1122 gc: 0 mem: 160
;; 19 time: 1119 cpu: 1119 gc: 0 mem: 160
;; 20 time: 1099 cpu: 1099 gc: 0 mem: 160
;; 20 time: 1088 cpu: 1088 gc: 0 mem: 160
;; 0 time: 0 cpu: 0 gc: 0 mem: 160
;; 1 time: 1103 cpu: 1103 gc: 0 mem: 160
;; 3 time: 1130 cpu: 1130 gc: 0 mem: 160
;; 4 time: 1164 cpu: 1164 gc: 0 mem: 160
;; 6 time: 1108 cpu: 1108 gc: 0 mem: 160
;; 12 time: 1115 cpu: 1115 gc: 0 mem: 160
;; 13 time: 1077 cpu: 1077 gc: 0 mem: 160
;; 15 time: 1080 cpu: 1080 gc: 0 mem: 160
;; 19 time: 1130 cpu: 1130 gc: 0 mem: 160
;; 20 time: 1096 cpu: 1096 gc: 0 mem: 160


        ;; Additional.

;; arc> (do l.read-barr2 (ga read-barrier8 4) (each (N k) (or '((3300 133000)) master-list) (prsn "With" N k) (pr "Setup: ") (= g time:nerb.N) (each x '(0 1 3 3 4 4 1 6 6 12 12 1 13 13 15 15 1 19 19 20 20 0 1 3 4 6 12 13 15 19 20) (= h nil h make-narb.g) (pr x " ") (let answer (* g.1 8) (let res (time:read-barrier8-thing read-barrier8 h N x k) (unless (or (is res answer) (is x 0)) (prsn "FAILURE" res "EXPECTED" answer))))) sleep.4))
;; With 3300 133000
;; Setup: time: 2 cpu: 2 gc: 0 mem: 149824
;; 0 time: 1 cpu: 1 gc: 0 mem: 2752
;; 1 time: 1020 cpu: 1020 gc: 0 mem: 160
;; 3 time: 1011 cpu: 1011 gc: 0 mem: 160
;; 3 time: 1011 cpu: 1011 gc: 0 mem: 160
;; 4 time: 1412 cpu: 1412 gc: 0 mem: 160
;; 4 time: 1405 cpu: 1405 gc: 0 mem: 160
;; 1 time: 1018 cpu: 1019 gc: 0 mem: 160
;; 6 time: 1060 cpu: 1060 gc: 0 mem: 160
;; 6 time: 1061 cpu: 1062 gc: 0 mem: 160
;; 12 time: 1037 cpu: 1037 gc: 0 mem: 160
;; 12 time: 1038 cpu: 1038 gc: 0 mem: 160
;; 1 time: 1006 cpu: 1006 gc: 0 mem: 160
;; 13 time: 1261 cpu: 1262 gc: 0 mem: 160
;; 13 time: 1261 cpu: 1262 gc: 0 mem: 160
;; 15 time: 1258 cpu: 1258 gc: 0 mem: 160
;; 15 time: 1258 cpu: 1259 gc: 0 mem: 160
;; 1 time: 1011 cpu: 1011 gc: 0 mem: 160
;; 19 time: 1062 cpu: 1062 gc: 0 mem: 160
;; 19 time: 1062 cpu: 1062 gc: 0 mem: 160
;; 20 time: 1623 cpu: 1623 gc: 0 mem: 160
;; 20 time: 1626 cpu: 1626 gc: 0 mem: 160
;; 0 time: 0 cpu: 1 gc: 0 mem: 160
;; 1 time: 1016 cpu: 1017 gc: 0 mem: 160
;; 3 time: 1006 cpu: 1006 gc: 0 mem: 160
;; 4 time: 1407 cpu: 1407 gc: 0 mem: 160
;; 6 time: 1059 cpu: 1060 gc: 0 mem: 160
;; 12 time: 1039 cpu: 1040 gc: 0 mem: 160
;; 13 time: 1267 cpu: 1267 gc: 0 mem: 160
;; 15 time: 1257 cpu: 1257 gc: 0 mem: 160
;; 19 time: 1061 cpu: 1061 gc: 0 mem: 160
;; 20 time: 1626 cpu: 1626 gc: 0 mem: 160
        
        
        







        