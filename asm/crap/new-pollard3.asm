

        ;; Stripped down. Formal.
        ;; Fairly sophisticated.
        ;; Shall return... 0 if seems to be prime,
        ;; [nontrivial factor of m] if found.

        ;; Use dumb cutoff for trial division.
        ;; Start with an even test and a gcd test.
        ;; gcd is subroutine, pollard with floyd is subroutine, trial division is subroutine.
        ;; Note that division exceptions are baed.

        mov rax, 0xfffefafd


        test rdi, 1
        jz two_divides
        
        ;; mov rax, 100000000000000
        ;; mov rax, 1
        ;; ok so pollard starts being faster for non-primes btwn 10^7 and 10^8.
        ;; comparable around 3*10^7. [really they're very close]

        ;; hmmmm... with testing... prime leads to bad shit.
        ;; not prime is significantly different...
        
        ;; let's see. for miller-rabin test.
        ;; x fools miller-rabin for q if:
        ;; let u = q^[x-1 with 2's divided out].
        ;; either u = 1, or, with squarings,
        ;; you reach -1 and then 1 before or exactly when you reach q^x-1.
        ;; x fails at miller-rabin for q if:
        ;; let u = q^[x-1 with 2's divided out].
        ;; with squarings of u, you either don't reach 1 when you reach q^x-1,
        ;; or you reach 1 without reaching -1 first.
        ;; --neh, user should have prime-bits, and also there is gcd for fast testing
        ;; that becomes trial division in those cases.
        ;; still, could... mmm...
        ;; ok, according to http://oeis.org/A014233, primes up to 37 works for all 64-bit integers.
        ;; next version.

        ;; now we do one gcd check...
        ;; 16294579238595022365 is product of primes from 3 to 53 and is < 2^64
        mov rax, 16294579238595022365
        xor edx, edx
        div rdi                 ;rem rdx        
        mov rax, rdx
        cmp rdx, 0              ;in that case, rdi is product of small primes
        je trial_division
        mov rdx, rdi            ;backup
        call binary_gcd_with_assumptions
        mov rdi, rdx


        ;; the caller might likely have a prime-bits up to 100 million. (bweheheh)
        ;; thus, we shall do miller-rabinning only if pretty big.

        cmp rdi, 30000000           ;current (non)arbitrary cutoff
        jb trial_division

        ;; now...
        ;; http://oeis.org/A014233 shall be useful. I may verify its results at some point somehow.

        
        cmp rax, 1
        je main_pollard
        ;; if contains small primes, best do trial division
        
        ;; rdi; uses rcx, rdx, rax, rsi; ret rax
trial_division:
        ;; cmp rdi, 2
        ;; jb return_zero
        ;; test rdi, 1
        ;; jz two_divides

        ;; Quick examination to figure out a quick Newton's algorithm...
        ;; g -> (g + x/g) / 2, or (g^2 + x) / 2g; former is better
        bsr rcx, rdi            ;index of highest bit; max 2^63
        shr ecx, 1
        mov rsi, 1
        shl rsi, cl
        mov rax, rdi
        xor rdx, rdx
        div rsi                 ;quot rax, rem rdx
        add rsi, rax
        shr rsi, 1              ;now this is our upper bound; should be fairly accurate
        
        mov rax, rdi
        xor rdx, rdx
        div rsi
        add rsi, rax
        shr rsi, 1              ;another one for shiznits

        ;; ok, now, loop
        ;; having tested 2... we must test 3, then we shall test 6n+{1,5}.
        ;; ... shall I div for 3, or shall I do stupid mul crap?
        ;; meh. apparently div gets faster in ivy bridge or summat.
        ;; also this is probably used with small numbers...
        mov rcx, 3
        mov rax, rdi
        xor rdx, rdx
        div rcx
        cmp rdx, 0
        je return_rcx

        mov rcx, 5

trial_division_loop:

        mov rax, rdi
        xor edx, edx            ;turns out doesn't, with my settings, optimize "xor rdx, rdx" into "xor edx, edx".
        div rcx
        cmp edx, 0              ;lolz
        je return_rcx
        add ecx, 2              ;lolololz...
        
        mov rax, rdi
        xor edx, edx
        div rcx
        cmp edx, 0
        je return_rcx
        add ecx, 4
        cmp ecx, esi
        jna trial_division_loop
        
        ;; failure
        ;; mov rax, rdi ;neh, return 0 if prime
return_zero:    
        xor eax, eax
        ret

return_rcx:
        ;; but return 0 if prime (such terrible naming)
        cmp rcx, rdi
        je return_zero
        mov rax, rcx
        ret


        ;; rdi = p.
        ;; note that -7 has a sqrt mod 2^64.
        ;; but -1 through -6 don't.
        ;; so this is the optimum level of avoiding carrying.
        ;; ... let's have rbx = c.
        ;; rbp will be 100-ish. (start at maybe 10)  NO, uncommon-ish.
        ;; rbp might be accumulator, lolz...
        ;; rdi = p, rsi = hare.
        ;; rcx will be counter.
        ;; rax and rdx will be scattered... an accumulator will be rax,
        ;; and will need to be moved into rax (it becoming remainder'd).
        ;; r8 can be 2^n, and r9 can be a_2^n. (a_0 = 2, a_n+1 = f(a_n))
        ;; r10 will be actual 2^n; r8 will be counter.
        ;; rbx can be c.
main_pollard:
        push rbp
        ;; mov rbp, 1              ;accum ;later
        push rbx
        mov rbx, 3              ;c ;ok, again. now with 17.
        push r12                ;c calling convention...
        ;; push r13                ;debugging

        ;; mov r13, rsi            ;dbg!

        ;; Ok wtf.
        ;; rbx = 3 => bad shit.
        ;; Not when rbx = 1 or 2, but 3. (with 100011 or smthg; maybe fixed, maybe not)
        ;; Time to investigate wtf.
        ;; Jesus christ, I'm doing it...
        ;; top -o cpu -l 1 | grep racket | head -n 1 | grep -o '^[0-9]+'
        ;; ARGH FUCK IT I GOT THE WRONG ONES
        ;; oh well

        ;; ... r8 somehow goes to 0.
        ;; this is a sign of shit going wrong.
        ;; let's see.
        ;; ok, giant rcx.
        ;; that sounds fixable...

        ;; ok, I see problem illustrated with 17, c=3.
        ;; the original hare backup really should just be the same
        ;; as the original hare. I do things that assume that.
        ;; It should be no trouble.
        ;; (The hare takes a step before it is compared, so there is
        ;; no problem with getting x-y=0 to start with.)
        
main_pollard_after_c:   
        mov rsi, 2              ;hare
        mov rcx, 16             ;counter
        mov r8, 16              ;literally 2^n
        mov r9, 2               ;a_2^n
        mov r10, 0             ;2^n downward counter; transfers units to rcx
        mov r11, 16             ;100-ish

        mov r12, 2            ;prev value of hare ;now actually a hare value; a stupid one, but at least not fatal

        ;; call pollard_floyd
        ;; jmp main_pollard_return

main_pollard_loop_init: 
        mov rbp, 1

main_pollard_loop:
        ;; hmm, rcx being huge is not problem...

        ;; dec r13
        ;; jz oh_fuck

        mov rax, rsi
        mul rsi
        add rax, rbx
        div rdi                 ;rem rdx
        mov rsi, rdx
        ;; now we take x-y.
        ;; ... wow, seriously? not enough dick?
        ;; hare. p. accum. c. counter. oldval.
        ;; and rax/rdx are kind of a staging area. hmm.
        ;; try...
        ;; ok, so, if, at beginning of loop, rax were hare...
        ;; ... must store hare elsewhere before dick...
        ;; fuck, I'd probably have to keep rotating registers around.
        ;; fine, I shall use one of r8-r15.
        ;; [... it doesn't even cost an REX prefix if that's already used]


        sub rdx, r9
        sbb rax, rax            ;0 or -1
        xor rdx, rax            ;d, or -1 - d
        sub rdx, rax            ;d, or -d
        
        mov rax, rdx
        mul rbp                 ;accum
        div rdi
        mov rbp, rdx

        ;; mov rax, rcx

        ;; cmp rbp, 0
        ;; je main_pollard_return
        
        dec rcx
        jnz main_pollard_loop

        ;; well, this is sort of working, but...
        ;; time to try crippling it.

        ;; ok, so, it fails after a single going to dead_end.

        ;; mov rbp, 0 ;don't do this to trigger bad performance, it breaks some assumptions



        ;; ... ok, um... there are several things that can happen.
        ;; rbp will _not_ be p. rbp is a remainder mod p.
        ;; rbp might be 0.
        ;; I could test for that earlier but that would probably not be worth it.
        ;; anyway, in that case, either cycles happen to coincide (this does happen, e.g. 19*37, start 2, c=1),
        ;; or they're close to coinciding and we fucked shit up and will probably be lazy about trying to fix it.
        ;; we probably try a cleanup phase with "finding the single thing that matches w/ current a_2^n",
        ;; maybe a second cleanup phase with "use floyd with previous value of hare (a_k-100; initialize that to 0)",
        ;; and then try c++ [NO NO NEVER].
        cmp rbp, 0
        je main_pollard_loop_dead_end

        
        ;; rdx (like rbp) is accum
        mov rax, rdx
        mov rdx, rdi            ;back up p
        call binary_gcd_with_assumptions
        mov rdi, rdx
        ;; gcd shall be 1 or 1 < it < p.
        ;; if latter, we win, we're done.
        ;; if former, then it is mundane; all comparisons were false, proceed with loop.
        cmp rax, 1
        jne main_pollard_return

        cmp r10, 0
        je main_pollard_loop_bigger
main_pollard_loop_counters:
        mov r12, rsi            ;hare backup
        mov rcx, r10
        cmp r11, r10
        cmovb rcx, r11          ;min(100ish, 2^n - [done so far]) steps
        sub r10, rcx
        jmp main_pollard_loop_init
        
main_pollard_loop_bigger:
        ;; ok, remember.
        ;; r8 is a power of 2, and is index of the resulting a_2^n (it's kind of optimistic).
        ;; r9 is the a_2^n.
        ;; r10 is a counter downward, initially 2^n.
        ;; r11 is about 100; min(100, r10).
        ;; rcx will become min(r10, r11).
        mov r10, r8             ;e.g. 16
        add r8, r8              ;e.g. 32
        mov r9, rsi             ;e.g. a_16
        mov r11, 100            ;e.g. 100
        cmp r10, 100            ;e.g. smaller
        cmovb r11, r10          ;e.g. 16
        jmp main_pollard_loop_counters

main_pollard_loop_dead_end:
        ;; first recourse: compare one at a time with old rsi.
        ;; ... actually, this old rsi is a_n-100.
        ;; second recourse: floyd with previous rsi. [invalid if no previous; init to 0.]
        ;; ... no.
        ;; if a_n-100 doesn't work, then the only previous thing we have is a_2^n, which will
        ;; mean O(2^n) more steps if we use floyd or anything.
        ;; at that point, we may as well just use a different c.
        ;; therefore.

        ;; only recourse: start from a_n-100 comparing with a_2^n one at a time.
        ;; if fail, then next c.

        ;; ... ... Am I finding that it's possible to perpetually...? No... no...
        ;; Well, this thing claims it is.
        ;; Oh, maybe I see.
        ;; Hmm, do I?  Hmm...
        ;; Ok, so, if you get to this dead_end_loop...
        ;; You should be here only if there were a_i such that |a_i - r9| wasn't coprime to rdi.
        ;; In that case, it is inappropriate for me to trigger this with "mov rbp, 0".

        mov rsi, r12
main_pollard_dead_end_loop:

        ;; mov rax, 69
        ;; jmp main_pollard_return

        ;; dec r13
        ;; jz main_pollard_return
        
        mov rax, rsi
        mul rsi
        add rax, rbx
        div rdi                 ;rem rdx
        mov rsi, rdx


        ;; mov rax, rdx
        ;; jmp main_pollard_return

        sub rdx, r9
        sbb rax, rax
        xor rdx, rax
        sub rdx, rax
        
        jz main_pollard_next_c

        mov rax, rdx
        mov rdx, rdi
        call binary_gcd_with_assumptions
        mov rdi, rdx
        cmp rax, 1
        je main_pollard_dead_end_loop
        jmp main_pollard_return

main_pollard_next_c:

        ;; mov rax, rbx
        ;; jmp main_pollard_return
        
        inc rbx
        cmp rbx, 7
        jne main_pollard_after_c

        ;; give up
        mov rax, 0
        
main_pollard_return:                 ;pop all this crap

        ;; pop r13
        pop r12
        pop rbx
        pop rbp

        ret
        
        
        
        ;; subroutine: binary gcd.
        ;; would be nice if could handle zero and evens...
        ;; arguments in rax, rdi; rax is likely smaller (poss. 0).
        ;; rcx is probably 0, usable; and rdx can be destroyed.
        ;; AWP NAWP NAWP
        ;; rdx shall be backup for p. now v. important to keep. (lolz)
        ;; ok, so, I'll assume rdi > rax, rdi odd.
        ;; yeah.
        ;; ... if rax literally is 0, then... ... that would certainly give you infinite loop.
        ;; so caller must test for 0.
binary_gcd_with_assumptions:    
        bsf rcx, rax
        shr rax, cl
        ;; jmp binary_gcd_rdi_bigger
                
binary_gcd_rdi_bigger:  
        sub rdi, rax

        bsf rcx, rdi
        shr rdi, cl
        cmp rdi, rax
        ja binary_gcd_rdi_bigger
        je binary_gcd_return
        
binary_gcd_rax_bigger:
        sub rax, rdi
        bsf rcx, rax
        shr rax, cl

        cmp rdi, rax
        ja binary_gcd_rdi_bigger
        jb binary_gcd_rax_bigger
binary_gcd_return:              ;should have rax = rdi = gcd
        ret

        

two_divides:
        cmp rdi, 2
        je return_zero
        cmp rdi, 0
        je return_zero
        mov rax, 2
        ret


        ;; Time
        ;; We are interested in the general problem of proving that
        ;; all composites less than N fail a certain set of Miller-Rabin
        ;; tests.
        ;; Efficiently.
        ;; All composites less than N will have a prime factor less than sqrt(N).
        ;; If dick, then we could hope for an O(small) way to check each prime
        ;; less than sqrt(N), or even each prime power.
        ;; Well, we shall see...

        ;; Given prime p and test a.
        ;; When might p*(q...) fail?
        ;; Initially, dick is raised to [product - 1] / 2^k power, then squared repeatedly.
        ;; [product - 1] is -1 mod p.
        ;; But what the hell is it mod p-1?
        ;; Now we're getting somewhere.
        ;; Well, it's (q...) - 1 mod p-1, p being 1 mod p-1.

        ;; So one category of failure is when (q...) is not 1 mod p-1, and in fact
        ;; is not 1 mod [the "order" of a mod p]. In that case, p*(q...) would even
        ;; fail the Fermat test with a.

        ;; Remaining cases are when (q ...) is 1 mod p-1. We hope for a relevant power
        ;; of a to be 1 mod p but -1 [or some other non-1 sqrt of 1] mod (q...),
        ;; or to be -1 mod p but 1 [or some other non--1 sqrt of 1] mod (q...).
        ;; ... For all relevant purposes, all primes involved will be odd.
        ;; So, [k divides p-1] divides (q...) - 1.

        ;; ... Given p, we have NUM_PRIMES_BELOW_SQRT_N / [k, probably like p/2 to p/4 on avg]
        ;; primes to look through for the next step.
        ;; Which becomes maybe 2-4 SQRT_N log SQRT_N total.
        ;; ... I suppose that might be acceptable... (terrible... but ok...)

        ;; ... if k... 


        ;; rdi = prime.
        ;; we will have rsi = ... ... neh. Laterz.
miller_rabin:
        




return:
        ret