section .text

	mov rax, 0xfffefafd

	;; Convert from UCS-4 to UTF-8.
	;; i.e. 32-bit Unicode integers to a UTF-8 byte sequence.
	;; For the moment, we're going to only handle ASCII. Lolz.
	;; This should give an upper bound on speed.

	;; In order to make an asm dylib, you must have a
	;; "section .text" dickass, and you must put an underscore
	;; before the name, and globalize the dick.
	;; "section .text
	;;  ...
	;;  global _dick
	;;  _dick:
	;;  ..."
	;; causes it to be possible to load the symbol "dick" from
	;; this thing.

        ;; Hmm. Calling return with no arguments is faster, by up to a factor of 2 (3 if you subtract out
        ;; the overhead of the repeat loop), than calling it with 3 arguments.



	;; rdi = dest
	;; rsi = src
	;; rdx = n
	;; rcx = mode

	cmp rdx, 0
	je return

	cmp rcx, 0
	je no_checking_eax
	cmp rcx, 1
	je no_checking_rax
	cmp rcx, 2
	je eax_checking
	cmp rcx, 3
	je rax_checking
	cmp rcx, 4
	je rax_checking2


no_checking_eax:
	mov eax, [rsi]
	add rsi, 4
	mov [rdi], al
	inc rdi
	dec rdx
	jnz no_checking_eax
	jmp return

no_checking_rax:
	mov rax, [rsi]
	add rsi, 8
	mov [rdi], al
	shr rax, 32
	mov [rdi+1], al
	add rdi, 2
	sub rdx, 2
	jnl no_checking_rax
	jmp return

	;; On Alvin, for 90m chars repeated 10 times,
	;; ranges from 1074-1083 msec for rax, vs 1112-1116 for eax.

	global _eax_checking_call
	
_eax_checking_call:
	cmp rdx, 0
	je return

	global eax_checking
;; 	global _eax_checking
;; _eax_checking:	
	
eax_checking:
	mov eax, [rsi]
	add rsi, 4
	test eax, 0xffffff80
	jnz eax_checking_fake_handler
	mov [rdi], al
	inc rdi
	dec rdx
	jnz eax_checking
	jmp return

eax_checking_fake_handler:
	mov rax, -1
	jmp return
	
rax_checking:
	mov rax, [rsi]
	add rsi, 8
	test eax, 0xffffff80
	jnz rax_checking_fake_handler
	mov [rdi], al
	shr rax, 32
	test eax, 0xffffff80
	jnz rax_checking_fake_handler
	mov [rdi+1], al
	add rdi, 2
	sub rdx, 2
	jnl rax_checking
	jmp return

rax_checking_fake_handler:
	mov rax, -1
	jmp return


	;; 1135-1144 vs 1116-1133 on eax_checking vs rax_checking.

rax_checking2:
	mov rcx, 0xffffff80ffffff80
rax_checking2_loop:	
	mov rax, [rsi]
	add rsi, 8
	test rax, rcx
	jnz rax_checking2_fake_handler
	mov [rdi], al
	shr rax, 32
	mov [rdi+1], al
	add rdi, 2
	sub rdx, 2
	jnl rax_checking2_loop
	jmp return

rax_checking2_fake_handler:
	mov rax, -1
	jmp return

	;; 1105-1122 for rax_checking2. Somewhat interesting.

	;; about 75 msec to make-bytes something that size.
	;; about 300 msec to string->bytes/utf-8 this string.
	;; Outputs from some testing.
	;; (1908 2010 1866 1933 2002 1937 1866 1945 1868 1864 1878)
	;; as non-GC CPU time...
	;; for making a bytes and then copying it.
	;; As low as 180 msec for one iteration.
	;; However, it seems always to cause a minor gc; I suppose
	;; that makes sense.
	;; Meanwhile, string->bytes/utf-8 takes 3000 msec, +/-,
	;; when doing 10 reps.  Substantive improvement, possibly worthwhile.
	;; Now... time to investigate smaller strings.

	;; --Ok, what the FUCK ... oh, when you look at CPU time, not too unsurprising.
;; arc> (time:repeat 1000 (bytes-length (let u (make-bytes len.s9k) (f fake-utf8 u s len.s9k 0) u)))
;; time: 255 cpu: 38 gc: 0 mem: 9208576
;; nil
;; arc> (time:repeat 1000 (bytes-length (let u (make-bytes len.s9k) (f fake-utf8 u s len.s9k 0) u)))
;; time: 111 cpu: 24 gc: 0 mem: 9208896
;; nil
;; arc> (time:repeat 1000 (bytes-length (let u (make-bytes len.s9k) (f fake-utf8 u s len.s9k 0) u)))
;; time: 24 cpu: 24 gc: 0 mem: 9208576
;; nil
;; arc> (time:repeat 1000 (bytes-length (let u (make-bytes len.s9k) (f fake-utf8 u s len.s9k 0) u)))
;; time: 22 cpu: 22 gc: 5 mem: -24070664
;; nil
;; arc> (time:repeat 1000 (bytes-length (let u (make-bytes len.s9k) (f fake-utf8 u s len.s9k 0) u)))
;; time: 17 cpu: 16 gc: 0 mem: 9208608
;; nil

	;; Anyway.
	;; Maybe 17-20 msec for repeated dick with this asm stuff,
	;; and 29-33 msec for string->bytes/utf-8,
	;; for a 9k-char string.

	;; For 9 chars...
	;; 1m reps of nothing => 116-133 msec.
	;; 321-326 msec for string->bytes/utf-8.
	;; And 1140-1213 for making-bytes and then method 4.
	;; Roughly the same for other asms.
	;; ... Replacing len.s9 with 9 shaves off 80 msec each time.
	;; If this were implemented in Racket...
	;; Going to 90 chars and dividing reps by 10 nearly divides time by 10.
	;; For 10 x 1m of 9char:
	;; 3300 msec with string->bytes/utf-8, 11900 msec with asm.
	;; For 10 x 100k of 90char:
	;; 622 msec with string->bytes/utf-8, 1397 msec with asm.
	;; For 10 x 10k of 900char:
	;; 313 msec with string->bytes/utf-8, 267 msec with asm.
	;; This makes sense.

	;; After dying and reopening, 10 x 100k of 900char:
	;; 3065 msec with string->bytes/utf-8, 2604 msec with asm
	;; For 10 x 10k of 9k char:
	;; 2800 with builtin, 1498 with asm.


	;; OMGAW
	;; Well, fuck.
	;; Don't necessarily know how long of an output buffer I need.
	;; Fuck.
	;; Really this should be done with some small output buffer
	;; with periodic WRITE calls.
	;; An alternative strategy is to preemptively go through the string
	;; and count up all dicks. (Hope no one modifies it, jesus christ.)
	;; (I wonder if you could fool [hours pass] Racket by changing the
        ;; string while it's decoding it... time to try...)
        ;; Foiled. It seems to not observe the changes. Will try again.
        ;; Damn, it looks like PLT locks dick.
        ;; Well, (= s.n x) does use atomic.
        ;; (wow jesus, something weird happened--a deadlock? ^C; no harm...)
        ;; Even using raw string-set!, it does seem to be atomic.
        ;; Now that is something that would probably be hard to duplicate.
        ;; Frankly, probably also undesirable.
        ;; (This asm shit would probably disable the GC temporarily...)
        ;; (Well, there's probably something you can do. I believe I have
        ;; seen something suggestive in the docs.)
	;; The ideal thing would decode bytes into a preallocated byte-buffer,
        ;; periodically WRITE it out (or call write-bytes, wtvr),
        ;; and overwrite old shit.
        ;; Obviously, use a thread-cell thing for that.





	global _return
_return:	

return:
	ret

	;; Will there ever be RET FAR?
	;; Feh whatever.
	
