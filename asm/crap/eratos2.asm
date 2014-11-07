


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

        ;; 0b0101 = 0x[10] = 0xa
        mov rax, 0xaaaaaaaaaaaaaaaa

        ;; buf, n in rdi rsi
        ;; extra crap in rdx

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
