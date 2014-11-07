

        mov rax, 0xfffefafd


        ;; rdi = a, rsi = b, rdx = mode, rcx = n.

        ;; Results:
;; arc> (map [time:absolute-difference-thing absolute-difference 3232981211 29392323232 _ 100000000] '(0 1 2 3))
;; time: 69 cpu: 70 gc: 0 mem: 160
;; time: 95 cpu: 95 gc: 0 mem: 160
;; time: 85 cpu: 85 gc: 0 mem: 160
;; time: 74 cpu: 74 gc: 0 mem: 160
;; (26159342021 26159342021 26159342021 26159342021)

        ;; Note that the cqo crap is incorrect for large unsigned integers (where 2^63 bit is 1).
        ;; The sign extension is not ... ... ... Yes. The sign extension is not correct.
        ;; arc> (map [time:absolute-difference-thing absolute-difference (+ 20 (expt 2 63)) 19 _ 100000000] '(0 1 2 3))
        ;; cqo_crap yields different result (by two).
        ;; Also, the carry_dick method doesn't require rax/rdx. I shall use it.
        ;; ... Jesus christ, the jumping is faster, and both are the same.
        ;; I think this is due to branch fucking prediction.
        ;; ... Whatever. Won't use it. Theory trumps data here. (lolz)

        ;; Very well, sbb reg, 0 is superior to sbb reg, reg.
        ;; Oh god I'm a complete idiot.
        ;; OH GOD THE COMPUTER IS A COMPLETE IDIOT
        ;; Comparing carry_ass2 and carry_ass, we observe that the introduction
        ;; of "xor edx, edx" reduces execution time. jesus.
        ;; Maybe cache crap, maybe it focuses the mind of the CPU, whatever.
        ;; Time to try Alvin.
	;; FWIW, Alvin:
	;; arc> (map [time:absolute-difference-thing absolute-difference (+ 20 (ash 1 63)) (+ 18 (ash 1 0)) _ 100000000] (range 0 10))
;; time:	 115 cpu: 115 gc: 0 mem: 352
;; time:	 128 cpu: 128 gc: 0 mem: 352
;; time:	 113 cpu: 114 gc: 0 mem: 352
;; time:	 119 cpu: 119 gc: 0 mem: 352
;; time:	 76 cpu: 75 gc: 0 mem: 352
;; time:	 76 cpu: 76 gc: 0 mem: 352
;; time:	 120 cpu: 120 gc: 0 mem: 352
;; time:	 121 cpu: 121 gc: 0 mem: 352
;; time:	 121 cpu: 120 gc: 0 mem: 352
;; time:	 114 cpu: 113 gc: 0 mem: 352
;; time:	 125 cpu: 121 gc: 0 mem: 352
	;; Probably caching dicks is it.
	;; ... And I'm going to assume branch prediction BS
	;; for the jumps.
	;; Anyway, a smart CPU should recognize "sbb samereg, samereg".
	;; So I shall use that.
        ;; Bwah, new-pollard went slightly faster after using the carry_ass version. I shall credit that.
        ;; carry_ass is formal recommendation.

        

        cmp rdx, 0
        je cqo_crap
        cmp rdx, 1
        je cmov_dick
        cmp rdx, 2
        je cmov_ass
        cmp rdx, 3
        je carry_dick
        cmp rdx, 4
        je jumping
        cmp rdx, 5
        je jumping_reversed
        cmp rdx, 6
        je carry_dick2
        cmp rdx, 7
        je carry_dick2_2
        cmp rdx, 8
        je carry_dick_orig_2
        cmp rdx, 9
        je carry_ass
        cmp rdx, 10
        je carry_ass2
        

cqo_crap:
        mov rax, rdi
        sub rax, rsi
	cqo			;sign-extend into RDX
	xor rax, rdx
	sub rax, rdx		;now rax = |x-y|

        dec rcx
        jnz cqo_crap
        ret

cmov_dick:
        mov rax, rdi
        mov rdx, rsi
        cmp rdi, rsi
        cmovb rax, rsi
        cmovb rdx, rdi
        sub rax, rdx

        dec rcx
        jnz cmov_dick
        ret

cmov_ass:

        mov rax, rdi
        sub rax, rsi
        mov rdx, rsi
        sub rdx, rdi
        cmp rdi, rsi
        cmovb rax, rdx

        dec rcx
        jnz cmov_ass
        ret

carry_dick:
        xor edx, edx
        mov rax, rdi
        sub rax, rsi
        sbb rdx, rdx
        xor rax, rdx
        sub rax, rdx

        dec rcx
        jnz carry_dick
        ret

jumping:
        mov rax, rdi
        sub rax, rsi
        jnc jumping_next
        neg rax
jumping_next:
        dec rcx
        jnz jumping
        ret

jumping_reversed:
        mov rax, rsi
        sub rax, rdi
        jnc jumping_reversed_next
        neg rax
jumping_reversed_next:
        dec rcx
        jnz jumping_reversed
        ret

carry_dick2:
        xor eax, eax
        mov rdx, rdi
        sub rdx, rsi
        sbb rax, 0
        xor rdx, rax
        sub rdx, rax

        dec rcx
        jnz carry_dick2
        mov rax, rdx
        ret

carry_dick2_2:
        xor edx, edx
        mov rax, rdi
        sub rax, rsi
        sbb rdx, 0
        xor rax, rdx
        sub rax, rdx
        
        dec rcx
        jnz carry_dick2_2
        ret


carry_dick_orig_2:
        xor edx, edx
        mov rax, rdi
        sub rax, rsi
        sbb rdx, rdx
        xor rax, rdx
        sub rax, rdx

        dec rcx
        jnz carry_dick_orig_2
        ret

carry_ass:
        mov rax, rdi
        sub rax, rsi
        sbb rdx, rdx
        xor rax, rdx
        sub rax, rdx

        dec rcx
        jnz carry_ass
        ret

carry_ass2:
        xor edx, edx
        mov rax, rdi
        sub rax, rsi
        sbb rdx, rdx
        xor rax, rdx
        sub rax, rdx

        dec rcx
        jnz carry_ass2
        ret

        
        
