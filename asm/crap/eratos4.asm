

        ;; Aw m'gaw. Realized how I could improve btr.
        ;; ... ok, a few variations.
        ;; - couple of ways of doing 1 5 mod 6
        ;;   (one index, two registers to hold increments;
        ;;    two indices, one register holding an increment of 6p;
        ;;    one index, a linked list of increments)
        ;; - maybe do 1 7 11 13 17 19 23 29 mod 30
        ;;   (eight indices, one inc; one ind, 8 reg incs;
        ;;    one ind, one linked list holding incs)

        ;; also exactly how end testing is done


        ;; do I use C calling convention?  or completely ignore?
        ;; it seems to have worked to clobber everything...
        ;; I think I'll be conservative and will save registers to follow
        ;; the calling convention.

        ;; note that accessing original registers (not r8-r15) probably carries
        ;; some benefit if I can avoid the REX prefix. ... eh.

        ;; note that (system-type 'machine) = uname -a, which contains x86_64 on x86-64.


        ;; buf, n in rdi rsi

        ;; first, since we use base 2, we handle it.
        ;; iterate over 8-byte chunks, then handle remaining bytes indiv.'lly.
        ;; I would consider using "move string", and using the same tactic from
        ;; gzip: e.g. write 8 bytes to x, then copy 200 bytes from x to x+8.
        ;; that is equivalent to writing 25 copies of that 8-byte.
        ;; but I wonder if that blows a cache or a pipeline or invalidates prefetching
        ;; or something.


        ;; I might test shit, but to start with, I'll just mov.
        ;; Eh...

        mov rax, 0xfffefafd

        cmp rsi, 0
        je return

        ;; SAVING EVERYTHING BUT RAX, RSP
        pushfq
        push rbx
        push rcx
        push rdx
        push rdi
        push rsi
        push rbp
        push r8
        push r9
        push r10
        push r11
        push r12
        push r13
        push r14
        push r15


        ;; buf, n in rdi rsi
        ;; mode in rdx
        ;; extra crap in rcx ...
        ;; shifting mode: rcx = primes, r8 = shifts, r9 = array of blocks

        cmp rdx, 0
        je shifting
        cmp rdx, 1
        je linked_list
        cmp rdx, 2
        je btr_one_prime
        cmp rdx, 3
        je finish_with_btr
        cmp rdx, 4
        je linked_list4
        cmp rdx, 5
        je finish_with_btr2
        cmp rdx, 6
        je finish_with_btr3
	cmp rdx, 7
	je finish_with_btr4

shifting:
        ;; buf in rdi
        mov rbp, rdi            ;backup buf
        ;; n in rsi
        mov rdx, rcx            ;primes
        mov rcx, r8             ;shifts
        
        mov rax, r9             ;arr, soon to die

        mov r8, [rax + 0]
        mov r9, [rax + 8]
        mov r10, [rax + 16]
        mov r11, [rax + 24]
        mov r12, [rax + 32]
        mov r13, [rax + 40]
        mov r14, [rax + 48]
        mov r15, [rax + 56]

        ;; Oh crap, no, I want easy access to low bits in primes/shifts.
        ;; movzx dest, <low 8 bits> is best; hence--
        ;; ;; Fuck, need rcx for shl.  rbx, rdx.
        ;; rcx = shifts, rdx = primes.

shifting_loop:
        ;; 0b0101 = 0x[10] = 0xa
        mov rax, 0xaaaaaaaaaaaaaaaa

        ;; Now, correspondence.
        ;; dl corresponds to.. r8 or r15? it'd make sense for small to be small,
        ;; but currently I'm doing ass in opp. direction.
        ;; Fix that on Arc end. Ok done.
        ;; ... Lolz.  shifts should be rcx because of dick. Hahahahaha horrible.

        ;; noob, the following is not the way.
        ;; you can update shit and use it immediately,
        ;; or you can update everything, then use everything, then repeat.
        ;; actually this is probably better.
        ;; ... noob. (I had the and at the end; just move to front.
        
        and rax, r8
        shl r8, cl              ;jesus christ
        bsf rbx, r8
        sub bl, dl              ;oh my god
        jl dont_set_r8
        bts r8, rbx
dont_set_r8:       
        ror rcx, 8
        ror rdx, 8
        and rax, r9
        shl r9, cl              ;jesus christ
        bsf rbx, r9
        sub bl, dl              ;oh my god
        jl dont_set_r9
        bts r9, rbx
dont_set_r9:       
        ror rcx, 8
        ror rdx, 8
        and rax, r10
        shl r10, cl              ;jesus christ
        bsf rbx, r10
        sub bl, dl              ;oh my god
        jl dont_set_r10
        bts r10, rbx
dont_set_r10:       
        ror rcx, 8
        ror rdx, 8
        and rax, r11
        shl r11, cl              ;jesus christ
        bsf rbx, r11
        sub bl, dl              ;oh my god
        jl dont_set_r11
        bts r11, rbx
dont_set_r11:       
        ror rcx, 8
        ror rdx, 8
        and rax, r12
        shl r12, cl              ;jesus christ
        bsf rbx, r12
        sub bl, dl              ;oh my god
        jl dont_set_r12
        bts r12, rbx
dont_set_r12:       
        ror rcx, 8
        ror rdx, 8
        and rax, r13
        shl r13, cl              ;jesus christ
        bsf rbx, r13
        sub bl, dl              ;oh my god
        jl dont_set_r13
        bts r13, rbx
dont_set_r13:       
        ror rcx, 8
        ror rdx, 8
        and rax, r14
        shl r14, cl              ;jesus christ
        bsf rbx, r14
        sub bl, dl              ;oh my god
        jl dont_set_r14
        bts r14, rbx
dont_set_r14:       
        ror rcx, 8
        ror rdx, 8
        and rax, r15
        shl r15, cl              ;jesus christ
        bsf rbx, r15
        sub bl, dl              ;oh my god
        jl dont_set_r15
        bts r15, rbx
dont_set_r15:       
        ror rcx, 8
        ror rdx, 8

        ;; hoo boy.
        ;; now. don't want to duplicate so much code, so will have to
        ;; handle the two cases here the same way.
        sub rsi, 8
        jl shifting_loop_final
        mov [rdi], rax          ;could be STOSQ
        add rdi, 8
        jmp shifting_loop
        

shifting_loop_final:
        ;; at this point, the blocks and shifting are all done (though we want primes)
        ;; so we can trash those registers. need rax, save rbp (buf) and reconstruct n (from rbp, rsi).
        mov rcx, 7
        and rcx, rsi
        jz shifting_loop_done   ;nothing left
        ;; now we copy some bytes.
        ;; we assume we can access (though can't modify) the remaining fractional part of word.

        shl cl, 3
        mov r8, -1
        xor r9, r9
        shld r9, r8, cl
        and [rdi], r8
        and rax, r9
        or [rdi], rax

shifting_loop_done:
        ;; rbp = buf, rdi + rsi + 8 = buf + n
        add rsi, 8
        add rsi, rdi
        sub rsi, rbp            ;should be n

        mov rax, rsi
        jmp return
        
        ;; AAAAAAAAAAND
        ;; 1070 msec, compared to 23 msec for MOVSQ.
        ;; Owwwwwwnt. Hmm, well, let's find out how linked list does.

linked_list:
        
        ;; buf in rdi
        mov rbp, rdi            ;backup buf
        ;; n in rsi
        ;; mov rdx, rcx            ;primes ;nope
        ;; mov rcx, r8             ;shifts? no
        
        mov rax, r9             ;arr, soon to die


        mov r8, rax
        add r8, [rax + 0]
        mov r9, rax
        add r9, [rax + 8]
        mov r10, rax
        add r10, [rax + 16]
        mov r11, rax
        add r11, [rax + 24]
        mov r12, rax
        add r12, [rax + 32]
        mov r13, rax
        add r13, [rax + 40]
        mov r14, rax
        add r14, [rax + 48]
        mov r15, rax
        add r15, [rax + 56]

        ;; we process the list, which is [elm] [offset to cdr, us. 16]
        ;; and... leave it as is. too lazy and not sure if benefit to use mov rather than add.

        ;; now we want hella optimization here; not much code to duplicate.
        ;; ... meh.

        

list_loop:
        mov rax, 0xaaaaaaaaaaaaaaaa

        and rax, [r8]
        add r8, [r8 + 8]
        and rax, [r9]
        add r9, [r9 + 8]
        and rax, [r10]
        add r10, [r10 + 8]
        and rax, [r11]
        add r11, [r11 + 8]
        and rax, [r12]
        add r12, [r12 + 8]
        and rax, [r13]
        add r13, [r13 + 8]
        and rax, [r14]
        add r14, [r14 + 8]
        and rax, [r15]
        add r15, [r15 + 8]

        sub rsi, 8
        jl list_loop_final
        ;; mov [rdi], rax          ;could be STOSQ
        ;; No, we want to AND shit in.
        and [rdi], rax
        add rdi, 8
        jmp list_loop
        

list_loop_final:
        ;; at this point, the blocks and shifting are all done (though we want primes)
        ;; so we can trash those registers. need rax, save rbp (buf) and reconstruct n (from rbp, rsi).
        mov rcx, 7
        and rcx, rsi
        jz list_loop_done   ;nothing left
        ;; now we copy some bytes.
        ;; we assume we can access (though can't modify) the remaining fractional part of word.

        shl cl, 3
        mov r8, -1
        xor r9, r9
        shld r9, r8, cl
        and [rdi], r8
        and rax, r9
        or [rdi], rax

list_loop_done:
        ;; rbp = buf, rdi + rsi + 8 = buf + n
        add rsi, 8
        add rsi, rdi
        sub rsi, rbp            ;should be n

        mov rax, rsi
        jmp return

        ;; 368 msec. Shit yeah.
        ;; ... jesus.


        ;; ok time for the main
        ;; I may need to experiment somewhat to see
        ;; how fast this is and other things are and
        ;; things like that.


btr_one_prime:
        ;; for testing purposes if desired

        mov rax, rsi
        shl rax, 3
        sub rax, 1              ;teh max

        ;; for the moment, we're given one prime, and then we neeed
        ;; to get the next prime.

        mov rdx, rcx
        imul rcx, rcx
        cmp rcx, rax
        jg return

btr_one_loop:
        btr [rdi], rcx
        add rcx, rdx
        cmp rcx, rax
        jng btr_one_loop
        jmp return

        
finish_with_btr:
        ;; rdi = buf, rsi = len in bytes, rdx = mode, rcx = skip primes below this

        ;; for one prime:
        ;; 503 msec with p=2
        ;; 205 msec with p=5
        ;; 17-18 msec with p=61
        ;; 5 msec with p=203 [all this is 400 MB]
        ;; NOPE LIES (btr is [dest] off not dest off)

        ;; for one prime:
        ;; 4105 msec with p=2
        ;; 1624 msec with p=5
        ;; 141 msec with p=61
        ;; 51 msec with p=203
        ;; 47 msec with p=512 (if mem accesses get 8 words at a time, this does
        ;;                     the same amount of memory fucking as anything<512)
        ;; 44 msec with 1024 ;surprising
        ;; 28-29 msec with 2048
        ;; 12-13 with 4096
        ;; 11 with 4097
        ;; 4 with 9001
        ;; ... so. looks like btr'ing one word 32 times takes 87x as long as
        ;; mov'ing that word. btr = roughly 3x mov.

        ;; mov rcx, 203

        ;; mov r12, 20

        mov rbx, rsi
        shl rbx, 3
        sub rbx, 1              ;teh max

        ;; for the moment, we're given one prime, and then we neeed
        ;; to get the next prime.
        ;; we'll store a word of the sieve and use bsf to get primes,
        ;; deleting each prime from that word as we use it.

        mov rax, rcx
        xor rdx, rdx
        mov r8, 64
        div r8                  ;q rax, r rdx
        shl rax, 3              ;into byte offset ;oh god I'm dumb, 6 not 5 ;OH GOD there we go

        mov r8, rax             
        add r8, rdi             ;addr of word containing next primes
        mov r9, rax
        shl r9, 3               ;number of bits skipped over...
        
        mov r10, [r8]
        mov rcx, rdx
        shr r10, cl
        shl r10, cl             ;kill all primes before this one
        mov r11, rdi
        add r11, rsi       ;max address
        ;; now we scan forward to find our prime...
        
btr_find_prime: 
        bsf rcx, r10
        jz btr_next_word

        btr r10, rcx            ;consume prime
        add rcx, r9             ;make prime

        jmp btr_main_loop

btr_next_word:
        add r8, 8
        add r9, 64
        cmp r8, r11
        jnl return
        mov r10, [r8]
        cmp r10, 0
        je btr_next_word
        jmp btr_find_prime

btr_main_loop:

        ;; dec r12
        ;; jnz btr_main_loop2
        ;; mov rax, rcx
        ;; jmp return
btr_main_loop2:

        
        mov rdx, rcx
        imul rcx, rcx
        cmp rcx, rbx
        jg return

        ;; mov rcx, 841
        ;; btr [rdi], rcx
        ;; jmp return

        ;; mov rax, rcx
        ;; jmp return

        ;; rdi = buf, rcx = p^2 = index, rdx = p, rbx = max.
btr_loop:
        btr [rdi], rcx
        add rcx, rdx
        cmp rcx, rbx
        jng btr_loop

        jmp btr_find_prime

        
        
        jmp return



linked_list4:
        
        ;; buf in rdi
        mov rbp, rdi            ;backup buf
        ;; n in rsi
        mov rdx, rcx            ;primes
        ;; mov rcx, r8             ;shifts? no
        
        mov rax, r9             ;arr, soon to die
        mov r8, rax
        add r8, [rax + 0]
        mov r9, rax
        add r9, [rax + 8]
        mov r10, rax
        add r10, [rax + 16]
        mov r11, rax
        add r11, [rax + 24]
        ;; mov r12, rax
        ;; add r12, [rax + 32]

        ;; we process the list, which is [elm] [offset to cdr, us. 16]
        ;; and... leave it as is. too lazy and not sure if benefit to use mov rather than add.

        ;; now we want hella optimization here; not much code to duplicate.
        ;; ... meh.
        

list_loop4:
        mov rax, 0xaaaaaaaaaaaaaaaa

        ;; all right, so.
        ;; handling 4 dicks, it takes 102-105 msec
        ;; handling 8 dicks, it takes 158-159 msec.
        ;; how about longer dicks?
        ;; mmmhmm, dicks taking up nearly 1 MB raise it to (gasp) 110-111 msec.

;;         arc> (do l.a (ga eratos3 6) (withs (real-primes primes primes (take 8 (keep prime (range 3 64))) passed-primes (digs->num rev.primes 256) passed-blocks (lists->array+bytes:map prime-block-cycle primes) longer-blocks (lists->array+bytes:map (fn (ps) (apply cycle-map bit-and (map prime-block-cycle ps))) (tuples 3 (s-take 12 s-cdr.real-primes)))) (each (x y) '((1 x) (4 t) (4 x) (4 t) (4 x) (4 t) (4 x)) (pr x " " y " ") (time:eratos3-thing eratos3 dest N x passed-primes 0 (if (is y t) longer-blocks passed-blocks)))))
;; 1 x time: 345 cpu: 344 gc: 0 mem: 3216
;; 4 t time: 128 cpu: 129 gc: 0 mem: 224
;; 4 x time: 104 cpu: 105 gc: 0 mem: 224
;; 4 t time: 111 cpu: 111 gc: 0 mem: 224
;; 4 x time: 104 cpu: 104 gc: 0 mem: 224
;; 4 t time: 110 cpu: 109 gc: 0 mem: 224
;; 4 x time: 104 cpu: 104 gc: 0 mem: 224


        and rax, [r8]
        add r8, [r8 + 8]
        and rax, [r9]
        add r9, [r9 + 8]
        and rax, [r10]
        add r10, [r10 + 8]
        and rax, [r11]
        add r11, [r11 + 8]

        sub rsi, 8
        jl list_loop4_final
        mov [rdi], rax          ;could be STOSQ
        add rdi, 8
        jmp list_loop4
        

list_loop4_final:
        ;; at this point, the blocks and shifting are all done (though we want primes)
        ;; so we can trash those registers. need rax, save rbp (buf) and reconstruct n (from rbp, rsi).
        mov rcx, 7
        and rcx, rsi
        jz list_loop4_done   ;nothing left
        ;; now we copy some bytes.
        ;; we assume we can access (though can't modify) the remaining fractional part of word.

        shl cl, 3
        mov r8, -1
        xor r9, r9
        shld r9, r8, cl
        and [rdi], r8
        and rax, r9
        or [rdi], rax

list_loop4_done:
        ;; rbp = buf, rdi + rsi + 8 = buf + n
        add rsi, 8
        add rsi, rdi
        sub rsi, rbp            ;should be n

        mov rax, rsi
        jmp return


finish_with_btr2:
        ;; rdi = buf, rsi = len in bytes, rdx = mode, rcx = skip primes below this

        ;; mov rcx, 203

        ;; mov r12, 20

        mov rbx, rsi
        shl rbx, 3
        sub rbx, 1              ;teh max

        cmp rcx, 3
        jng return              ;we're acting like 2,3 are already crossed out

        ;; for the moment, we're given one prime, and then we neeed
        ;; to get the next prime.
        ;; we'll store a word of the sieve and use bsf to get primes,
        ;; deleting each prime from that word as we use it.

        mov rax, rcx
        xor rdx, rdx
        mov r8, 64
        div r8                  ;q rax, r rdx
        shl rax, 3              ;into byte offset ;oh god I'm dumb, 6 not 5 ;OH GOD there we go

        mov r8, rax             
        add r8, rdi             ;addr of word containing next primes
        mov r9, rax
        shl r9, 3               ;number of bits skipped over...
        
        mov r10, [r8]
        mov rcx, rdx
        shr r10, cl
        shl r10, cl             ;kill all primes before this one
        mov r11, rdi
        add r11, rsi       ;max address
        ;; now we scan forward to find our prime...
        
btr2_find_prime: 
        bsf rcx, r10
        jz btr2_next_word

        btr r10, rcx            ;consume prime
        add rcx, r9             ;make prime

        jmp btr2_main_loop

btr2_next_word:
        add r8, 8
        add r9, 64
        cmp r8, r11
        jnl return
        mov r10, [r8]
        cmp r10, 0
        je btr2_next_word
        jmp btr2_find_prime

btr2_main_loop:

        ;; dec r12
        ;; jnz btr_main_loop2
        ;; mov rax, rcx
        ;; jmp return
btr2_main_loop2:

        
        mov rdx, rcx
        imul rcx, rcx
        cmp rcx, rbx
        jg return

        ;; rdi = buf, rcx = p^2 = index, rdx = p, rbx = max.

        ;; now, we can rely on the wonderful fact that, for all primes p other
        ;; than 2 and 3, p^2 is 1 mod 6.
        ;; hmmph, which regs can I use?
        ;; as above:
        ;; rdi = buf, rbx = max.
        ;; r8, r9, r10, r11 are used in dick.
        ;; rbp and rsp, try not to touch. --hmmph, could touch rbp if needed.
        ;; also could save things on a stack or some shit.
        
        ;; rcx = p^2 = index, rdx = p.
        ;; rsi = len. can be killed.
        ;; rax is basically unused.
        ;; and r12-r15.
        ;; heh, that is exactly enough for a 5 thing (erknounlesscrap)... but not yet.

        ;; First method: should be slowish.
        ;; M1: Use rcx as index, use rdx and rax as increments.

        ;; All right, with primes up to 100m (so 12.5m bytes) and p=5 onwards:
        ;; 651 msec with finish_with_btr, 238 with M1.
        ;; For 800m (100m bytes): 6968 with f_w_b, 2531 with M1. (And 5090 with prime_bits.)
        ;; 

        add rdx, rdx            ;2p
        mov rax, rdx
        add rax, rax            ;4p

        ;; so note rbx is max, like 399999999
        sub rbx, rax            ;max - 4p
        cmp rbx, rcx            ;we know rcx <= max, though.
        jl btr2_loop_last
        
btr2_loop:

        btr [rdi], rcx          ;1 mod 6
        add rcx, rax
        btr [rdi], rcx          ;5 mod 6
        add rcx, rdx

        cmp rcx, rbx
        jng btr2_loop

btr2_loop_last:
        add rbx, rax            ;max again
        ;; at this point we know prev_rcx <= max - 4p.
        ;; now rcx = prev_rcx + 6p, so must compare and be teh careful.
        
        cmp rcx, rbx
        jg btr2_find_prime
        btr [rdi], rcx
        add rcx, rax
        cmp rcx, rbx
        jg btr2_find_prime
        
        btr [rdi], rcx
        jmp btr2_find_prime

        
        ;; btr [rdi], rcx
        ;; add rcx, rdx
        ;; cmp rcx, rbx
        ;; jng btr2_loop
        ;; jmp btr2_find_prime

        
        
        jmp return
        

        


finish_with_btr3:
        ;; rdi = buf, rsi = len in bytes, rdx = mode, rcx = skip primes below this

        ;; mov rcx, 203

        ;; mov r12, 20

        mov rbx, rsi
        shl rbx, 3
        sub rbx, 1              ;teh max

        cmp rcx, 3
        jng return              ;we're acting like 2,3 are already crossed out

        ;; for the moment, we're given one prime, and then we neeed
        ;; to get the next prime.
        ;; we'll store a word of the sieve and use bsf to get primes,
        ;; deleting each prime from that word as we use it.

        mov rax, rcx
        xor rdx, rdx
        mov r8, 64
        div r8                  ;q rax, r rdx
        shl rax, 3              ;into byte offset ;oh god I'm dumb, 6 not 5 ;OH GOD there we go

        mov r8, rax             
        add r8, rdi             ;addr of word containing next primes
        mov r9, rax
        shl r9, 3               ;number of bits skipped over...
        
        mov r10, [r8]
        mov rcx, rdx
        shr r10, cl
        shl r10, cl             ;kill all primes before this one
        mov r11, rdi
        add r11, rsi       ;max address
        ;; now we scan forward to find our prime...
        
btr3_find_prime: 
        bsf rcx, r10
        jz btr3_next_word

        btr r10, rcx            ;consume prime
        add rcx, r9             ;make prime

        jmp btr3_main_loop

btr3_next_word:
        add r8, 8
        add r9, 64
        cmp r8, r11
        jnl return
        mov r10, [r8]
        cmp r10, 0
        je btr3_next_word
        jmp btr3_find_prime

btr3_main_loop:

        ;; dec r12
        ;; jnz btr_main_loop2
        ;; mov rax, rcx
        ;; jmp return
btr3_main_loop2:

        
        mov rdx, rcx
        imul rcx, rcx
        cmp rcx, rbx
        jg return

        ;; rdi = buf, rcx = p^2 = index, rdx = p, rbx = max.

        ;; now, we can rely on the wonderful fact that, for all primes p other
        ;; than 2 and 3, p^2 is 1 mod 6.
        ;; hmmph, which regs can I use?
        ;; as above:
        ;; rdi = buf, rbx = max.
        ;; r8, r9, r10, r11 are used in dick.
        ;; rbp and rsp, try not to touch. --hmmph, could touch rbp if needed.
        ;; also could save things on a stack or some shit.
        
        ;; rcx = p^2 = index, rdx = p.
        ;; rsi = len. can be killed.
        ;; rax is basically unused.
        ;; and r12-r15.
        ;; heh, that is exactly enough for a 5 thing (erknounlesscrap)... but not yet.

        ;; First method: should be slowish.
        ;; M1: Use rcx as index, use rdx and rax as increments.
        ;; M2: Use rcx and rax as indices, use rdx as 6p.

        ;; All right, with primes up to 100m (so 12.5m bytes) and p=5 onwards:
        ;; 651 msec with finish_with_btr, 238 with M1.
        ;; For 800m (100m bytes): 6968 with f_w_b, 2531 with M1. (And 5090 with prime_bits.)
        ;; Ok so apparently M2 is more or less exactly as fast as M1.  Harrumph.
        ;; On Tau, at least. It's possible other CPUs wouldn't be so good.
	;; Slight advantage on Alvin. M1 has 7744 and 7654 vs M2 having 7585 and 7506.
	;; Very slight.
	;; ACTUALLY NO I MISDID THAT, THAT WAS DROPPING 5 USING SAME METHOD
	;; M1 AND M2 SEEM TO DO EQUALLY WELL
	;; --Now as for linked list... as before, we will have the problem that initializing
	;; the list will take too long.
	;; --I can have this shit degrade into previous versions when numbers
	;; get small enough.  (...
	;; --Or I can use the stack or summat.  Lolz. (Maybe use stack to hold linked list,
	;; but that kind of sucks.) Optimal sequence of adds to put crap on the stack...
	;; Finally, shit can be inlined.
	;; Unfortunately, it's a bit of a pain to compute p(^2) mod 5 and stuff.
	;; ... Perhaps it is time to use ridiculous (fish) methods.
	;; --feh, neh.
        
        add rdx, rdx            ;2p
        mov rax, rdx
        add rdx, rdx
        add rdx, rax            ;6p
        add rax, rcx            ;p^2 + 4p (5 mod 6)

        ;; so note rbx is max, like 399999999
        sub rbx, rdx            ;max - 6p
        cmp rbx, rcx            ;we know rcx <= max, though.
        jl btr3_loop_last
        
btr3_loop:

        btr [rdi], rcx          ;1 mod 6
        add rcx, rdx
        btr [rdi], rax          ;5 mod 6
        add rax, rdx

        cmp rcx, rbx            ;major non pipelining issues!
        jng btr3_loop

btr3_loop_last:
        add rbx, rdx            ;max again
        ;; at this point we know prev_rcx <= max - 4p.
        ;; now rcx = prev_rcx + 6p, so must compare and be teh careful.
        
        cmp rcx, rbx
        jg btr3_find_prime
        btr [rdi], rcx
        
        cmp rax, rbx
        jg btr3_find_prime
        btr [rdi], rax
        
        jmp btr3_find_prime

        
        ;; btr [rdi], rcx
        ;; add rcx, rdx
        ;; cmp rcx, rbx
        ;; jng btr3_loop
        ;; jmp btr3_find_prime

        
        
        jmp return






finish_with_btr4:
        ;; rdi = buf, rsi = len in bytes, rdx = mode, rcx = skip primes below this

        ;; mov rcx, 203

        ;; mov r12, 20

        mov rbx, rsi
        shl rbx, 3
        sub rbx, 1              ;teh max

        cmp rcx, 3
        jng return              ;we're acting like 2,3 are already crossed out

        ;; for the moment, we're given one prime, and then we neeed
        ;; to get the next prime.
        ;; we'll store a word of the sieve and use bsf to get primes,
        ;; deleting each prime from that word as we use it.

        mov rax, rcx
        xor rdx, rdx
        mov r8, 64
        div r8                  ;q rax, r rdx
        shl rax, 3              ;into byte offset ;oh god I'm dumb, 6 not 5 ;OH GOD there we go

        mov r8, rax             
        add r8, rdi             ;addr of word containing next primes
        mov r9, rax
        shl r9, 3               ;number of bits skipped over...
        
        mov r10, [r8]
        mov rcx, rdx
        shr r10, cl
        shl r10, cl             ;kill all primes before this one
        mov r11, rdi
        add r11, rsi       ;max address
        ;; now we scan forward to find our prime...
        
btr4_find_prime: 
        bsf rcx, r10
        jz btr4_next_word

        btr r10, rcx            ;consume prime
        add rcx, r9             ;make prime

        jmp btr4_main_loop

btr4_next_word:
        add r8, 8
        add r9, 64
        cmp r8, r11
        jnl return
        mov r10, [r8]
        cmp r10, 0
        je btr4_next_word
        jmp btr4_find_prime

btr4_main_loop:

        ;; rdi = buf, rcx = p^2 = index, rdx = p, rbx = max.

        ;; now, we can rely on the wonderful fact that, for all primes p other
        ;; than 2 and 3, p^2 is 1 mod 6.
        ;; hmmph, which regs can I use?
        ;; as above:
        ;; rdi = buf, rbx = max.
        ;; r8, r9, r10, r11 are used in dick.
        ;; rbp and rsp, try not to touch. --hmmph, could touch rbp if needed.
        ;; also could save things on a stack or some shit.
        
        ;; rcx = p^2 = index, rdx = p.
        ;; rsi = len. can be killed.
        ;; rax is basically unused.
        ;; and r12-r15.
        ;; heh, that is exactly enough for a 5 thing (erknounlesscrap)... but not yet.

        ;; First method: should be slowish.
        ;; M1: Use rcx as index, use rdx and rax as increments.
        ;; M2: Use rcx and rax as indices, use rdx as 6p.

        ;; All right, with primes up to 100m (so 12.5m bytes) and p=5 onwards:
        ;; 651 msec with finish_with_btr, 238 with M1.
        ;; For 800m (100m bytes): 6968 with f_w_b, 2531 with M1. (And 5090 with prime_bits.)
        ;; Ok so apparently M2 is more or less exactly as fast as M1.  Harrumph.
        ;; On Tau, at least. It's possible other CPUs wouldn't be so good.
	;; Slight advantage on Alvin. M1 has 7744 and 7654 vs M2 having 7585 and 7506.
	;; Very slight.
	;; ACTUALLY NO I MISDID THAT, THAT WAS DROPPING 5 USING SAME METHOD
	;; M1 AND M2 SEEM TO DO EQUALLY WELL
	;; --Now as for linked list... as before, we will have the problem that initializing
	;; the list will take too long.
	;; --I can have this shit degrade into previous versions when numbers
	;; get small enough.  (...
	;; --Or I can use the stack or summat.  Lolz. (Maybe use stack to hold linked list,
	;; but that kind of sucks.) Optimal sequence of adds to put crap on the stack...
	;; Finally, shit can be inlined.
	;; Unfortunately, it's a bit of a pain to compute p(^2) mod 5 and stuff.
	;; ... Perhaps it is time to use ridiculous (fish) methods.
	;; --feh, neh.

	;; all right. 5 crap.
	;; I'll test correspondents of M1 and M2.
	;; I may not bother with the stack or linked-list testing.
	;; An advantage of M1 is that it requires fewer registers in this case.
	;;
	;; All right. M1, i.e. btr4, i.e. 2*3*5 with a bunch of compares and
	;; a bunch of additions and crap, from p=7 upward, yields 6259 msec, vs 7412
	;; for btr3.  In theory, btr4 could be as low as 4/5 of btr3.
	;; 4/5 of btr3 would be 5929.  I could call this 5% overhead instead of 20%.
	;; Fuck, this is probably not worth improving.
	;; Either the pipelining is really good or the number of memory accesses
	;; is the determining factor.  I'm guessing the latter.

	;; rcx = prime

        ;; fuck, need to take p mod 30 in a way I don't entirely understand
        ;; ... so we consider the sequence [p*p p*p+1 p*p+2 p*p+3 ...]
        ;; and are interested in the multiples of 2,3,5 there. (in excluding them, specifically)
        ;; they have the same indices as those in the sequence [p p+1 p+2 p+3 ...].
        ;; (and fuck, I made the same dumb mistake with the 2*3 case)
        ;; we start at the element (p mod 30) in the sequence [p p+1 p+2 p+3 ...].
        ;; I'm going to encode eight conditional jumps.

	mov rax, rcx
	xor rdx, rdx
        mov rsi, 30
	div rsi                 ;q rax, r rdx
	mov r12, rdx		;rem
        mov rdx, rcx
        imul rdx, rcx           ;p^2
	cmp rdx, rbx
	jg return

	;; M1. Bunch of dicks.
	add rcx, rcx		;2p
	mov rax, rcx
	add rax, rcx		;4p
	mov rsi, rax
	add rsi, rcx		;6p

	;; the seq is 1 7 11 13 17 19 23 29 [1]
	;; with delta  6 4  2  4  2  4  6  2.
	;; if rem = 1, then we're at 1; else rem = 4 and we're at 19.

        ;; oh jesus christ.
        ;; it's not just what p^2 is mod 5, it's what p is.
        ;; ... really?
        ;; well, take 73. 73^2 is 9 mod 10 so 4 mod 5.
        ;; 73 is 3 mod 5.
        ;; ...
        ;; 73 is 13 mod 30; 73^2 is 19 mod 30.
        ;; 19 32 15 28 11 24 7
        ;; 0           +4    +2
        ;; hmmph, that definitely proves wrong what I had written.
        ;; so...
        ;; p is 1,2,3,4 mod 5.
        ;; 1 case:
        ;; p*1, p*2, p*3, p*4, ...
        ;; 
        ;; 2: p*2, p*4, p*6
        ;; DISREGARD THAT

	cmp r12, 1
	je btr4_one
        cmp r12, 7
        je btr4_seven
        cmp r12, 11
        je btr4_eleven
        cmp r12, 13
        je btr4_thirteen
        cmp r12, 17
        je btr4_seventeen
        cmp r12, 19
        je btr4_nineteen
        cmp r12, 23
        je btr4_twenty_three
        cmp r12, 29
        je btr4_twenty_nine

	;; now should I cmp after every addition, or should I unroll the
	;; loop somewhat? I'm kind of lazy so I'll do the former.
	;; then I'll have to compare it with unrolled...

	;; arc> (pbcopy:tostring:each x '(6 4 2 4 2 4 6 2) (prn "\tbtr [rdi], rdx\n\tadd rdx, " (case x 2 'rcx 4 'rax 6 'rsi) "\t\t;" x "\n\tcmp rdx, rbx\n\tjg btr4_find_prime"))

	;; rcx=2p rax=4p rsi=6p
btr4_one:
	btr [rdi], rdx
	add rdx, rsi		;6
	cmp rdx, rbx
	jg btr4_find_prime
btr4_seven:     
	btr [rdi], rdx
	add rdx, rax		;4
	cmp rdx, rbx
	jg btr4_find_prime
btr4_eleven:    
	btr [rdi], rdx
	add rdx, rcx		;2
	cmp rdx, rbx
	jg btr4_find_prime
btr4_thirteen:  
	btr [rdi], rdx
	add rdx, rax		;4
	cmp rdx, rbx
	jg btr4_find_prime
btr4_seventeen: 
	btr [rdi], rdx
	add rdx, rcx		;2
	cmp rdx, rbx
	jg btr4_find_prime
btr4_nineteen:	
	btr [rdi], rdx
	add rdx, rax		;4
	cmp rdx, rbx
	jg btr4_find_prime
btr4_twenty_three:      
	btr [rdi], rdx
	add rdx, rsi		;6
	cmp rdx, rbx
	jg btr4_find_prime
btr4_twenty_nine:       
	btr [rdi], rdx
	add rdx, rcx		;2
	cmp rdx, rbx

	jng btr4_one
	jmp btr4_find_prime
        
        
        jmp return



        
        
        
        
        

        ;; ;; now experiment has shown that 89 is a nice number to space the movs by.
        ;; ;; probably as good as many, but 89 is nice.
        ;; ;; I suppose it'll likely differ from computer to computer. oh well.
        ;; DISREGARD
        ;; 3*5*7*11 = 1155, which is well in optimal area.
        ;; Also, handling 4 dicks is manageable.

        ;; Now.  How to handle things in 13-61?
        ;; Was thinking:
        ;; - Difficult but doable (~5 instructions, ~2-3 registers?) to keep blocks in single
        ;; registers and to shift and update them.
        ;; - Annoying but possible (2 instructions, 1 register, 1 memory pull) to keep, for
        ;; each prime, a linked list of the blocks. Need space to do that. Or might be able to
        ;; use space at the end, then re-handle it semi-manually.
        ;; - Also horrible but possible (several instructions, div, no regs, 1 memory pull) to
        ;; hold blocks somewhere and maintain an index in a reg.

        ;; Probably some shit should be parameterized...
        ;; Leaning towards thinking that all primes (except 2) are equiv. and I might not use MOVS.
        ;; ... this crap is hard to tell in a "superscalar" core where I think things might or might
        ;; not be parallelized and crap.
        ;; Fuck, whatever, time to see what happens for 3-11.

        ;; Time to do linked-list block approach.

        ;; Time to do single-register shifting approach.

        ;; imagine rbx = prime p.
        ;; we want something with multiples of p set to 0 so they'll AND out.
;;         mov rcx, -1
;;         mov rdx, p
;; little_loop:
;;         btr rcx, rdx
;;         add rdx, rbx
;;         cmp rdx, 64
;;         jnge little_loop

        ;; now rcx = block, rbx = p
        ;; how do we dick?
        ;; we could shl by 64. this is eqv to shl by (64 mod p).
        ;; either store 64 mod p or repeatedly recompute. latter really sucks.
        ;; ... also we want to shr, not shl.
        ;; this is even more inconvenient; ... nah, shr eqv shl by -x mod p.
        ;; so. get dick [somehow], shl by dick, get bsf, sub by p, jl proceed,
        ;; else bts block at bsf - p.
        ;; rotating pairs... jesus... well, sure.
        ;; next try the linked list.
;; other_loop:
;;         ...

;;         shl rcx, rbx

        ;; OMG SO BAD/GOOD
        ;; store in one 64b register four prime/dick pairs (all byte size)
        ;; use instructions that only look at the bottom however so many digits
        ;; I'm pretty sure that, at least, I could use... certain instr'ns...

        ;; ... maybe if memory ops are slow enough... shit wouldn't make a difference... neh.

        ;; ok so. rotating pairs (actually two rotating registers, 8 primes), xoring in.
        ;; for now I'll be lazy and hardcode the primes myself.

        ;; rdi = primes
        ;; rsi = shifts

        push rdi
        push rsi

        xor rdi, rdi
        xor rsi, rsi

        or rdi, 3
        shl rdi, 8
        or rdi, 5
        shl rdi, 8
        or rdi, 7
        shl rdi, 8
        or rdi, 11
        shl rdi, 8
        
        or rdi, 13
        shl rdi, 8
        or rdi, 17
        shl rdi, 8
        or rdi, 19
        shl rdi, 8
        or rdi, 23

        mov rbx, 8

compute_shifts:
        mov rcx, rdi
        and rcx, 255
        mov rax, 64
        xor rdx, rdx
        div rcx                 ;q = rax, r = rdx
        sub rcx, rdx            ;-64 mod p (and p isn't 2)
        or rsi, rcx

        rol rdi, 8
        rol rsi, 8
        dec rbx
        jnz compute_shifts

        ;; that works. now.
        ;; set up blocks in r8-r15. (Too epic.)

        mov rbx, 8
blockify:
        mov rcx, rdi
        and rcx, 255

        ;; jesus. wtf am I doing?
        ;; all this could be done in Arc, and the results passed to asm.
        ;; I think I'll actually go do that.
        
        
        

        

movs:
        ;; rcx = number to skip
        mov rcx, 89
        ;; check if that's actually bigger than our buffer...
        shl rcx, 3
        cmp rcx, rsi
        cmovg rcx, rsi
        shr rcx, 3

        ;; save mov-count
        mov r10, rcx
        ;; save buf
        mov rbx, rdi
        ;; save n
        mov rdx, rsi

        cmp rcx, 0
        je movs_loop_done        
movs_loop:      
        mov [rdi], rax
        add rdi, 8
        dec rcx
        jnz movs_loop
movs_loop_done:


        mov rcx, rsi            ;n
        shr rcx, 3              ;full words in buf
        sub rcx, r10            ;words left to mov
        jz after_movs
        
        mov rsi, rbx            ;rsi -> rdi

        cld
        rep movsq


after_movs:
        ;; rdi = last 0-7 bytes
        ;; now... imagining that a boundary could occur mid-word, we shall copy
        ;; bytes one by one, rather than doing bit-installation XOR crap.
        ;; actually, let's do bit-installation XOR crap.
        ;; mov cl, dl
        ;; and cl, 7
        ;; jz moving_done
        
        mov rcx, 7
        and rcx, rdx

        
        jz moving_done
        shl cl, 3
        mov rsi, -1
        xor r8, r8
        shld r8, rsi, cl
        and [rdi], rsi
        and rax, r8
        or [rdi], rax

moving_done:
        ;; rbx = buf, rdx = n
        ;; crap buffer in r9...
        ;; mov byte [rbx], 0b00110101 ;2 3 5 7

        ;; So.  

        jmp return

        ;; jesus christ
        ;; what I could do is:
        ;; take

        ;; There are a bunch of strategies that are useful for smaller primes.
        ;; For p=2, I write all the blocks with stuff filled in.
        ;; For p=3, I could make three blocks [64-bit words] and AND them into
        ;; the existing blocks.  (e.g. 3n would be ANDED with 110, 3n+1 ANDED with 101, etc.)
        ;; I could combine p=3 with p=7 or smthg.
        ;; Make 21 blocks and just write them all...
        ;; I'm guessing writing is faster than ANDing.
        ;; However, I will need to AND for later ones.

        ;; Noob.  I don't need to make new blocks.  I just write out 21 of them at the start
        ;; (and cross out the primes themselves as well) and use move string,
        ;; then un-cross-out the primes at the start afterwards.

        ;; So I was like "noob you're an idiot just how much work might you save with crazy
        ;; optimizations for primes < 64 versus all other primes?"
        ;; And then I was like...
        ;; arc> (time:sumlist inex:/ (keep prime (range 2 63)))
        ;; time: 0 cpu: 0 gc: 0 mem: 14968
        ;; 1.7138570367094215
        ;; arc> (time:sumlist inex:/ (keep prime (range 64 1000000)))
        ;; time: 985 cpu: 975 gc: 113 mem: 56396560
        ;; 1.1734710628582445
        ;; Jesus christ.  Even more so.
        ;; Let's see. First I'll do actual computation, then approximation.
        ;; If we make a 500 MB dick, then that corresponds to 0 through 4e9.
        ;; We would perform operations on p^2 through N inclusive.
        ;; arc> (let N (* 4 (expt 10 9)) (time:sumlist [div (- N (* _ _)) _] (keep prime (range 2 isqrt.N))))
        ;; time: 55 cpu: 55 gc: 0 mem: 9428288
        ;; 10469449990
        ;; arc> (let N (* 4 (expt 10 9)) (time:sumlist [div (- N (* _ _)) _] (keep prime (range 64 isqrt.N))))
        ;; time: 67 cpu: 67 gc: 12 mem: -20348480
        ;; 3614022352
        ;; Jeeeeeeeeesus chriiiiiiiiist.
        ;; In general:
        ;; sum of (N - p^2)/p, p up to sqrt N
        ;; = sum of N/p - p, p up to sqrt N
        ;; approximated by: (see below)

        ;; ---BEGIN CRAP---
        ;; integral of (N/p - p) * (1/ln p - 1), p from...0?1?2? to sqrt N
        ;; integral of N/(p ln p) - N/p - p/ln p + p
        ;; N ln ln p - N ln p - fuck + p^2

        ;; integral of N/(p ln p)...
        ;; u = ln p
        ;; du = 1/p dp
        ;; => N/(p ln p) = N/(ln p) * 1/p dp = N/u du
        ;; => N ln u
        ;; => N ln ln p

        ;; integral of p/ln p: u = ln p, du = 1/p dp
        ;; => p^2/u du = e^2u

        ;; 1/f ' = f' / f^2

        ;; p/ln p ' = 1/ln p - 1/ln^2 p
        ;; p/ln^2 p ' = 1/ln^2 p - 2/ln^3 p
        ;; p^3/ln p ' = 3p^2/ln p - p^2/ln^2 p
        ;; p^2/ln^2 p ' = 2p/ln^2 p - 2p/ln^3 p
        ;; nerf.
        ;; 1/ln p ' = -1/(p ln^2 p)

        ;; p^2/ln p ' = 2p/ln p - p/ln^2 p

        ;; integ p/ln^2 p dp
        ;; u = ln p
        ;; du = 1/p dp
        ;; p^2 / u^2 du...
        ;; Hmmph, fuck it, it turns out even Wolfram Alpha can't integrate p/ln p.
        ;; Gives an answer in terms of "Ei(x)", i.e. "Exponential integral", which is total BS.
        ;; And Wikipedia can only give recursive formulae for x^n/ln^m x, which will not
        ;; simplify it.  Well, oh well.
        ;; ---END CRAP---

        ;; integral of (N/p - p) * (1/ln p - 1/ln^2 p)...
        ;; integral of N/(p ln p) - N/(p ln^2 p) - p/ln p + p/ln^2 p

        ;; first: u = ln p, du = 1/p dp => int N/u du = N ln u = N ln ln p
        ;; sec: u = ln p, du = 1/p dp => int N/u^2 du = -N/u = -N/ln p
        ;; thi: fuck
        ;; fou: u = ln p, du = 1/p dp => int p^2/u^2 du
        ;; u = p^a ln^b p, du = a*p^a-1 ln^b + b p^a-1 ln^b-1 p dp
        ;;  = p^a-1 ln^b-1 * (a ln p + b)
        ;; u du = p^2a-1 ln^2b-1 * (a ln p + b) dp
        ;; a=2
        ;; u du = p ln^2b-1 * (2 ln p + b) dp
        ;; b=0 => 2p
        ;; b=1 => 2p ln^2 p + p ln p
        ;; b=1/2 => p ln p + 1/2 p
        ;; meh, it's small enough that it ... matters.
        ;; fuck.
        ;; well, oh well.


        ;; N/ln N primes up to N
        ;; means that, from N to N+k, there are (N+k)/ln N+k - N/ln N primes

        ;; d/dN -> 1/ln N - N/(N ln^2 N) = 1/ln N - 1/ln^2 N


        ;; ... conceivably, instead of constructing p blocks, I could make one block
        ;; and construct the next from the previous by shifting... There is a ROL
        ;; and a ROR instruction.  Jesus christ.
        ;; And for any p < 64, it is advantageous to do this ANDing rather than 
        ;; to write 

        ;; now.
        mov rax, 69


return:

        
        pop r15
        pop r14
        pop r13
        pop r12
        pop r11
        pop r10
        pop r9
        pop r8
        pop rbp
        pop rsi
        pop rdi
        pop rdx
        pop rcx
        pop rbx
        popfq

        ret


        ;; All right, testing (on Tau) shows:
        ;; mode 0 (mov): 47 msec to fill 400,000,000 bytes.
        ;; mode 1 (movs):
        ;; - 92 msec when skipping 1 word
        ;; - 57-58 msec when skipping 2 words
        ;; - 50 msec when skipping 3 words
        ;; - 49 msec when skipping 4 words
        ;; - 46-47 msec when skipping 8 words, and 16, and 32.

        ;; Seems mov with a loop is tied for best, and simplest.
        ;; WAIT NO

        ;; - 34-37 msec when skipping 8000 words.  Jesus.
        ;; 35-37 at 16k
        ;; 38 at 160k
        ;; up to 56 msec at 1.6m (probably it blows a cache of some sort)

        ;; 25 msec at 1600
        ;; 23-24 at 1000, 500
        ;; 23-25 at 100

;; arc> (time:for i 1 100 (pr i " ") (time:ee dest 400000000 1 i #xfeed 16))
;; 1 time: 93 cpu: 93 gc: 0 mem: 416
;; 2 time: 54 cpu: 54 gc: 0 mem: 416
;; 3 time: 48 cpu: 48 gc: 0 mem: 416
;; 4 time: 48 cpu: 48 gc: 0 mem: 416
;; 5 time: 47 cpu: 48 gc: 0 mem: 416
;; 6 time: 48 cpu: 47 gc: 0 mem: 416
;; 7 time: 48 cpu: 48 gc: 0 mem: 416
;; 8 time: 46 cpu: 46 gc: 0 mem: 416
;; 9 time: 50 cpu: 50 gc: 0 mem: 416
;; 10 time: 45 cpu: 46 gc: 0 mem: 416
;; 11 time: 47 cpu: 47 gc: 0 mem: 416
;; 12 time: 46 cpu: 46 gc: 0 mem: 416
;; 13 time: 47 cpu: 47 gc: 0 mem: 416
;; 14 time: 46 cpu: 46 gc: 0 mem: 416
;; 15 time: 46 cpu: 46 gc: 0 mem: 416
;; 16 time: 46 cpu: 46 gc: 0 mem: 416
;; 17 time: 46 cpu: 46 gc: 0 mem: 416
;; 18 time: 46 cpu: 46 gc: 0 mem: 416
;; 19 time: 46 cpu: 47 gc: 0 mem: 416
;; 20 time: 45 cpu: 45 gc: 0 mem: 416
;; 21 time: 46 cpu: 47 gc: 0 mem: 416
;; 22 time: 47 cpu: 46 gc: 0 mem: 416
;; 23 time: 46 cpu: 46 gc: 0 mem: 416
;; 24 time: 46 cpu: 46 gc: 0 mem: 416
;; 25 time: 46 cpu: 46 gc: 0 mem: 416
;; 26 time: 46 cpu: 47 gc: 0 mem: 416
;; 27 time: 46 cpu: 46 gc: 0 mem: 416
;; 28 time: 46 cpu: 46 gc: 0 mem: 416
;; 29 time: 46 cpu: 46 gc: 0 mem: 416
;; 30 time: 47 cpu: 46 gc: 0 mem: 416
;; 31 time: 46 cpu: 47 gc: 0 mem: 416
;; 32 time: 47 cpu: 46 gc: 0 mem: 416
;; 33 time: 47 cpu: 47 gc: 0 mem: 416
;; 34 time: 46 cpu: 47 gc: 0 mem: 416
;; 35 time: 47 cpu: 47 gc: 0 mem: 416
;; 36 time: 47 cpu: 47 gc: 0 mem: 416
;; 37 time: 47 cpu: 47 gc: 0 mem: 416
;; 38 time: 47 cpu: 48 gc: 0 mem: 416
;; 39 time: 47 cpu: 47 gc: 0 mem: 416
;; 40 time: 49 cpu: 49 gc: 0 mem: 416
;; 41 time: 49 cpu: 49 gc: 0 mem: 416
;; 42 time: 47 cpu: 47 gc: 0 mem: 416
;; 43 time: 48 cpu: 48 gc: 0 mem: 416
;; 44 time: 48 cpu: 48 gc: 0 mem: 416
;; 45 time: 48 cpu: 48 gc: 0 mem: 416
;; 46 time: 48 cpu: 48 gc: 0 mem: 416
;; 47 time: 49 cpu: 49 gc: 0 mem: 416
;; 48 time: 48 cpu: 49 gc: 0 mem: 416
;; 49 time: 49 cpu: 49 gc: 0 mem: 416
;; 50 time: 48 cpu: 49 gc: 0 mem: 416
;; 51 time: 49 cpu: 50 gc: 0 mem: 416
;; 52 time: 49 cpu: 49 gc: 0 mem: 416
;; 53 time: 51 cpu: 50 gc: 0 mem: 416
;; 54 time: 49 cpu: 50 gc: 0 mem: 416
;; 55 time: 51 cpu: 51 gc: 0 mem: 416
;; 56 time: 50 cpu: 50 gc: 0 mem: 416
;; 57 time: 52 cpu: 52 gc: 0 mem: 416
;; 58 time: 50 cpu: 50 gc: 0 mem: 416
;; 59 time: 52 cpu: 51 gc: 0 mem: 416
;; 60 time: 49 cpu: 50 gc: 0 mem: 416
;; 61 time: 51 cpu: 51 gc: 0 mem: 416
;; 62 time: 49 cpu: 49 gc: 0 mem: 416
;; 63 time: 47 cpu: 47 gc: 0 mem: 416
;; 64 time: 43 cpu: 43 gc: 0 mem: 416
;; 65 time: 42 cpu: 41 gc: 0 mem: 416
;; 66 time: 39 cpu: 39 gc: 0 mem: 416
;; 67 time: 38 cpu: 38 gc: 0 mem: 416
;; 68 time: 35 cpu: 35 gc: 0 mem: 416
;; 69 time: 32 cpu: 32 gc: 0 mem: 416
;; 70 time: 29 cpu: 29 gc: 0 mem: 416
;; 71 time: 26 cpu: 26 gc: 0 mem: 416
;; 72 time: 27 cpu: 27 gc: 0 mem: 416
;; 73 time: 25 cpu: 25 gc: 0 mem: 416
;; 74 time: 23 cpu: 24 gc: 0 mem: 416
;; 75 time: 23 cpu: 22 gc: 0 mem: 416
;; 76 time: 22 cpu: 22 gc: 0 mem: 448
;; 77 time: 22 cpu: 22 gc: 0 mem: 416
;; 78 time: 22 cpu: 22 gc: 0 mem: 416
;; 79 time: 22 cpu: 21 gc: 0 mem: 416
;; 80 time: 22 cpu: 23 gc: 0 mem: 416
;; 81 time: 21 cpu: 21 gc: 0 mem: 416
;; 82 time: 22 cpu: 21 gc: 0 mem: 416
;; 83 time: 21 cpu: 21 gc: 0 mem: 416
;; 84 time: 21 cpu: 22 gc: 0 mem: 416
;; 85 time: 21 cpu: 21 gc: 0 mem: 416
;; 86 time: 21 cpu: 21 gc: 0 mem: 416
;; 87 time: 21 cpu: 21 gc: 0 mem: 416
;; 88 time: 21 cpu: 21 gc: 0 mem: 416
;; 89 time: 20 cpu: 21 gc: 0 mem: 416
;; 90 time: 22 cpu: 22 gc: 0 mem: 416
;; 91 time: 21 cpu: 21 gc: 0 mem: 448
;; 92 time: 21 cpu: 21 gc: 0 mem: 416
;; 93 time: 21 cpu: 21 gc: 0 mem: 416
;; 94 time: 21 cpu: 21 gc: 0 mem: 416
;; 95 time: 22 cpu: 22 gc: 0 mem: 416
;; 96 time: 22 cpu: 22 gc: 0 mem: 416
;; 97 time: 22 cpu: 22 gc: 0 mem: 416
;; 98 time: 23 cpu: 23 gc: 0 mem: 416
;; 99 time: 22 cpu: 22 gc: 0 mem: 416
;; 100 time: 23 cpu: 23 gc: 0 mem: 416
;; time: 3979 cpu: 3984 gc: 0 mem: 218928
;; nil
;; rlwrap: warning: arc killed by SIGSEGV.
;; rlwrap has not crashed, but for transparency,
;; it will now kill itself (without dumping core)with the same signal

;; Segmentation fault
