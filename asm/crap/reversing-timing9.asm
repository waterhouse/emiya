        ;; [semispaces.asm]

        %include "semispaces4.asm"

        ;; Now we will actually use a "nil".
        ;; Just for benchmarking purposes.
        ;; Also to get just a little idea of whether shit works properly.


        ;; So, at this point.
        ;; "return" is a label we can jump to, which restores stack shit.
        ;; In the meantime, we've consumed rdi, rsi, and rdx,
        ;; which contain mem, mem-len, and page-size,
        ;; and we have room for three more arguments.
        ;; rcx = mode.
        ;; r8 = x
        ;; r9 = y

        ;; Actually, now we take:
        ;; rcx = [handle][dlsym]
        ;; r8 = x
        ;; r9 = y

        ;; Ok, current program:
        ;; Make a list of length x, reverse it y times.

        ;; Partially redundant, but:
        ;; ... shall I have all registers, including rsp,
        ;; which it doesn't seem it would make sense to trace?
        ;; Sure, whatever.        
        

        jmp actual_code

        ;; Library shit...

        %include "gc-system20.asm"

        ;; Time to use better timing shit.
        ;; rdtsc puts a CPU cycle count in edx:eax.
        ;; [It may also not be supported by some processors.
        ;;  In theory I could query that shit.]
        ;; 

        ;; We'll see if using regs for cons_min_cycles and cons_max_cycles
        ;; makes a difference.
        

        ;; Definitions for BS crap will appear here.
        ;; 'Cause macros need to be defined before you use them.

        VAR nil

x:      dq 0
y:      dq 0
original_y:     dq 0
        
        ;; %define CONS_MIN_CYCLES r14
        ;; %define CONS_MAX_CYCLES r15
        %define CONS_MIN_CYCLES [cons_min_cycles]
        %define CONS_MAX_CYCLES [cons_max_cycles]
        ;; that didn't make a difference, possibly 1.5%

cons_min_cycles:  dq 0
cons_max_cycles:  dq 0
rev_min_cycles:   dq 0
rev_max_cycles:   dq 0

init:   dq 0
end:    dq 0
init_cpucycles: dq 0
end_cpucycles:  dq 0
total_time:     dq 0
total_cycles:   dq 0
        

        
actual_code:

        gc_header

        mov qword CONS_MIN_CYCLES, -1
        mov qword CONS_MAX_CYCLES, 0
        mov qword [rev_min_cycles], -1
        mov qword [rev_max_cycles], 0
        

        mov [x], r8
        mov [original_y], r9
        mov [y], r9

        ;; We will use a narcissistic cons cell as nil.

        saving 0
        cons rdi
        scar rdi, rdi
        scdr rdi, rdi
        mov [nil], rdi

	;; Use something other than mach_absolute_time,
	;; for general POSIX BS.
	;; ... We will use "gettimeofday".
	;; Sigh, this sucks, but oh well.

	;; ;; Sigh, probably not working yet.
	;; mov rax, [gettimeofday]

	;; sub rsp, 16
	;; lea rdi, [rsp]
	;; mov qword [rsp], 0
	;; mov qword [rsp+8], 0
	;; mov rsi, 0
	;; mov rax, 0
	;; call [gettimeofday]
	;; mov rax, [rsp+8]
	;; add rsp, 16
	;; jmp return
	;; ;; Seems ints are in fact big.
	;; ;; Right ho.


        ;; We shall use ... r12 for this thing.
        ;; Aw, fuck, that's currently PAGELIMIT.
        ;; How about... rbp.  Sure.  Excellent.

        ;; I'll assume that, when it says stuff is returned in edx:eax, the high 32 bits of
        ;; edx and eax are also cleared.
        %macro tsc 0
        ;; shl rdx, 32
        ;; or rax, rdx
        rdtsc
        shl rdx, 32
        or rax, rdx
        ;; mov rax, ALLOCPTR
        %endmacro
        
        ;; better not be using rdx, which, luckily, we're not
        ;; the runtime of this is apparently dominated by the rdtsc instruction
        %macro timed_cons 1
        tsc
        mov rbp, rax
        cons %1
        tsc
        sub rax, rbp
        minify CONS_MIN_CYCLES, rax
        maxify CONS_MAX_CYCLES, rax
        ;; cons %1
        %endmacro


        ;; dest, src
        %macro maxify 2
        cmp %1, %2
        jnb %%nope
        mov %1, %2
%%nope:
        %endmacro
        %macro minify 2
        cmp %1, %2
        jna %%nope
        mov %1, %2
%%nope:
        %endmacro

        c_save
        get_nanoseconds
        mov [init], rax
        c_restore

        tsc
        mov [init_cpucycles], rax

        
        


        ;;First, cons up the initial list...

        ;;a = r8, b = r9

        ;; r8 = count
        shl r8, 3               ;tag

        ;; Testing:
        ;; neg r8

        ;; Will have: rdx = xs, rcx = ys
        ;; Oh, good lord, that's inconvenient
        ;; Time to replace rdx with r15, which is conveniently free now.
        mov rcx, [nil]

loop:
        

        saving rcx
        timed_cons rdi          ;may kill rax
        scar rdi, r8
        scdr rdi, rcx
        mov rcx, rdi
        

        ;; inc r8
        ;; cmp r8, r9
        ;; jb %[name]_loop

        ;; dec r8
        sub r8, 8
        ;; add r8, 8
        jnz loop


        ;; rcx = list
        ;; now that's in reverse...
        ;; oh well, it ... shall it always be in reverse?
        ;; neh, let us reverse it.

        ;; Let's also store that list in a place we won't touch till the end.
        push rcx


        ;; Ok, so, this will simply reverse it a bunch of times.
        ;; r9 = reps
        ;; let's put it in memory; registers are in high demand.
        ;; it already is in memory, so.
        cmp qword [y], 0
        je done
reversing_loop:
        call reverse            ;arg and return in rcx
        dec qword [y]
        jnz reversing_loop
        ;; now return something at least vaguely meaningful
done:

        push rcx

        c_save
        get_nanoseconds
        mov [end], rax
        c_restore

        tsc
        mov [end_cpucycles], rax

        mov rax, [end]
        sub rax, [init]
        mov [total_time], rax
        mov rax, [end_cpucycles]
        sub rax, [init_cpucycles]
        mov [total_cycles], rax

        ;; As I've discovered before: printf wants rax = 0.
        ;; ("al" = number of "vector" arguments, whatever the fuck -- System V ABI)
        
        lea rdi, [thing]
        mov rsi, [gc_flip_count]
        mov rdx, [moved_count]
        mov rcx, [bytes_moved]
        mov r8, [bytes_traced]
        mov r9, [work_count]
        push ALLOCPTR
        ;; xor eax, eax
        mov rax, 0
        call [printf]
        ;; not sure how to call more than 6 args; a naive attempt leads to segfault
        pop ALLOCPTR

        mov rdi, [tospace_top]
        sub rdi, [tospace_bottom]

        mov rax, [original_y]
        mov rcx, 16             ;conses are this big
        mul rcx
        mul qword [x]
        div rdi
        mov rsi, rax
        lea rdi, [dick]
        mov rax, 0
        call [printf]

        lea rdi, [thing3]
        mov rsi, [traced_count]
        mov rdx, [gc_cycles]
        mov rcx, [overflow_count]
        mov r8, [stacked_count]
        mov rax, 0
        call [printf]

        ;; We report times in real time, not CPU cycles.
        ;; We will thus have to convert.

        ;; lea rdi, [thing4]
        ;; mov rsi, CONS_MIN_CYCLES
        ;; mov rdx, CONS_MAX_CYCLES
        ;; mov rcx, [rev_min_cycles]
        ;; mov r8, [rev_max_cycles]
        ;; mov rax, 0
        ;; call [printf]

        %macro scaled_mov 2
        mov rax, %2
        mul qword [total_time]
        ;; In case we're doing shit so that total_cycles becomes 0
        cmp qword [total_cycles], 0
        jle %%nope
        div qword [total_cycles]
%%nope:
        mov %1, rax
        %endmacro

        lea rdi, [thing4]
        scaled_mov rsi, CONS_MIN_CYCLES
        scaled_mov rcx, [rev_min_cycles]
        scaled_mov r8, [rev_max_cycles]
        scaled_mov rdx, CONS_MAX_CYCLES ;must be last because mul/div uses rdx
        mov rax, 0
        call [printf]

        lea rdi, [thing5]
        mov rax, [total_cycles]
        mov rcx, 1000
        mul rcx
        mov rsi, [total_time]
        div rsi
        mov rcx, rax
        mov rdx, [total_cycles]
        mov rax, 0
        call [printf]

        pop rcx
        
        ;; ass
        cheap_cdr rax, rcx
        cheap_car rax, rax

        pop rdi
        cheap_car rsi, rdi
        add rax, rsi
        
        jmp return

thing:  db "flips: %ld moved: %ld mbytes: %ld tbytes: %ld trace-ops: %ld alloc: %ld", 10, 0
thing2: db "alloc: %ld", 10, 0
thing3: db "traced-count: %ld gc-cycles: %ld overflow-count: %ld stacked-count: %ld", 10, 0
thing4: db "cons-min: %ld cons-max: %ld rev-min: %ld rev-max: %ld", 10, 0
thing5: db "time: %ld cycles: %ld cycles/usec: %ld", 10, 0
whatever:       db "nerf", 10, 0
dick:   db "achtung %ld", 10, 0
        
        
        ;; Arg in rcx, dest in rcx.
        ;; Garbage ftw.
        ;; No continuations.
        ;; Assume nonempty.
        ;; ... Use r8 as scratch, eh?
        ;; Ah, this runs into barrs.
        ;; ... Also must initialize rdx to 0, I suppose.
        ;; Might as well make it proper reverse.
reverse:
        ;; c_save
        ;; call [mach_absolute_time]
        ;; mov rbp, rax
        ;; c_restore
        tsc
        mov rbp, rax
        
        ;; push rbp ;bad idea... [fake pointers on stack] oh dear.
        ;; ok, fine, I can shl it.
        shl rbp, 3
        push rbp
        
        
        mov r9, [nil]          ;newly freed
        cmp rcx, [nil]
        je reverse_ret
reverse_loop:        
        car r8, rcx
        saving rcx, r9          ;and not r8 because we know it's a uint
        timed_cons rdi
        ;; cons rdi

        scar rdi, r8
        scdr rdi, r9
        mov r9, rdi

        ;; we can actually "cdr x, x" now
        cdr rcx, rcx
        
        cmp rcx, [nil]
        jne reverse_loop
reverse_ret:
        mov rcx, r9

        tsc
        mov rbp, rax
        pop rax
        shr rax, 3
        sub rbp, rax
        ;; rbp is now the dick
        minify [rev_min_cycles], rbp
        maxify [rev_max_cycles], rbp
        
        ret
        



        mov rax, 77
        jmp return




        ;; Ok, that seemed to work.
        ;; Moar.


rejected:
        mov rax, 981
        jmp return


        
        ;; BRETTY GOOD [26 microsecond pauses]
        ;; also the instrumentation introduces 18x overhead

        ;; ...
        ;; actually...
        ;; I think the conses may never have had to do GC work, it all being done in the GC cycle
        ;; imm. after the GC flip.        

        ;; this is bad, it looks like the GC work is always done in one chunk

;; arc> (do (= h (ffi-lib "Dropbox/c-lib/dlhandle-dlsym.dylib") derp (get-ffi-obj "install_handle_and_dlsym" h (cprocedure (list $.c-_bytes) $.c-_int64))) (= u make-bytes.16) (derp u) (ga reversing-timing2 6) (each h (join (range 0 1)) (gc) (sleep .5) (withs f (fn (x y z m u v) (pr (pad h 2) " ") (call-asm reversing-timing2 x y z m u v)) n (* 1000 (expt 2 20)) b make-bytes.n (time:do (pr (f b n 4096 u 100000 2000) " ")))))
;;  0 flips: 12 moved: 2400012 mbytes: 3200016 tbytes: 3200016 trace-ops: 2365 alloc: 4582190608
;; achtung 11
;; traced-count: 2400012 gc-cycles: 12 overflow-count: 781647 stacked-count: 2400012
;; cons-min: 15 cons-max: 22840 rev-min: 4365004 rev-max: 6406852 total: 9184401615
;; 24 time: 9185 cpu: 9185 gc: 0 mem: 5792
;;  1 flips: 12 moved: 2400012 mbytes: 3200016 tbytes: 3200016 trace-ops: 2365 alloc: 4582190608
;; achtung 11
;; traced-count: 2400012 gc-cycles: 12 overflow-count: 781647 stacked-count: 2400012
;; cons-min: 15 cons-max: 23772 rev-min: 4363988 rev-max: 6112640 total: 9151349548
;; 24 time: 9152 cpu: 9152 gc: 0 mem: 2896
;; nil
;; arc> ;now THAT'S more like it

        ;; ok, so, 22-23 microsecond pauses.
        ;; and the above is sensical.
        ;; [it helps to have a bunch of BS output]

        ;; Varying page size:

;; (do (= h (ffi-lib "Dropbox/c-lib/dlhandle-dlsym.dylib") derp (get-ffi-obj "install_handle_and_dlsym" h (cprocedure (list $.c-_bytes) $.c-_int64))) (= u make-bytes.16) (derp u) (ga reversing-timing2 6) (each h (join (range 0 1)) (gc) (sleep .5) (withs f (fn (x y z m u v) (pr (pad h 2) " ") (call-asm reversing-timing2 x y z m u v)) n (* 1000 (expt 2 20)) b make-bytes.n (time:do (pr (f b n 1024 u 100000 2000) " ")))))
;;  0 flips: 12 moved: 2400012 mbytes: 3200016 tbytes: 3200016 trace-ops: 9397 alloc: 4582183696
;; achtung 11
;; traced-count: 2400012 gc-cycles: 12 overflow-count: 3126569 stacked-count: 2400012
;; cons-min: 15 cons-max: 33257 rev-min: 4404873 rev-max: 6359142 total: 9204940918
;; 24 time: 9206 cpu: 9205 gc: 0 mem: 5792
;;  1 flips: 12 moved: 2400012 mbytes: 3200016 tbytes: 3200016 trace-ops: 9397 alloc: 4582183696
;; achtung 11
;; traced-count: 2400012 gc-cycles: 12 overflow-count: 3126569 stacked-count: 2400012
;; cons-min: 15 cons-max: 26362 rev-min: 4396545 rev-max: 6329676 total: 9224184782
;; 24 time: 9224 cpu: 9224 gc: 0 mem: 2896
;; nil
;; arc> ;... that didn't really connect with the point... welp, huh.
;; ;let's try:
;; (do (= h (ffi-lib "Dropbox/c-lib/dlhandle-dlsym.dylib") derp (get-ffi-obj "install_handle_and_dlsym" h (cprocedure (list $.c-_bytes) $.c-_int64))) (= u make-bytes.16) (derp u) (ga reversing-timing2 6) (each h (join (range 0 1)) (gc) (sleep .5) (withs f (fn (x y z m u v) (pr (pad h 2) " ") (call-asm reversing-timing2 x y z m u v)) n (* 1000 (expt 2 20)) b make-bytes.n (time:do (pr (f b n 16384 u 100000 2000) " ")))))
;;  0 flips: 12 moved: 2400012 mbytes: 3200016 tbytes: 3200016 trace-ops: 612 alloc: 4582216208
;; achtung 11
;; traced-count: 2400012 gc-cycles: 12 overflow-count: 195416 stacked-count: 2400012
;; cons-min: 15 cons-max: 45649 rev-min: 4383821 rev-max: 6552674 total: 9185563694
;; 24 time: 9186 cpu: 9186 gc: 0 mem: 5792
;;  1 flips: 12 moved: 2400012 mbytes: 3200016 tbytes: 3200016 trace-ops: 612 alloc: 4582216208
;; achtung 11
;; traced-count: 2400012 gc-cycles: 12 overflow-count: 195416 stacked-count: 2400012
;; cons-min: 15 cons-max: 47220 rev-min: 4384443 rev-max: 6254890 total: 9188755577
;; 24 time: 9189 cpu: 9189 gc: 0 mem: 2896
;; nil
        
        ;; Looks like, I'm guessing, the gc flip takes 23 microseconds.



;; arc> (do (= h (ffi-lib "Dropbox/c-lib/dlhandle-dlsym.dylib") derp (get-ffi-obj "install_handle_and_dlsym" h (cprocedure (list $.c-_bytes) $.c-_int64))) (= u make-bytes.16) (derp u) (ga reversing-timing4 6) (each h (join (range 0 1)) (gc) (sleep .5) (withs f (fn (x y z m u v) (pr (pad h 2) " ") (call-asm reversing-timing4 x y z m u v)) n (* 400 (expt 2 20)) b make-bytes.n (time:do (pr (f b n 4096 u 100000 600) " ")))))
;;  0 flips: 14 moved: 2800014 mbytes: 3200016 tbytes: 3200016 trace-ops: 2760 alloc: 4563187216
;; achtung 14
;; traced-count: 2800014 gc-cycles: 14 overflow-count: 234773 stacked-count: 2800014
;; cons-min: 15 cons-max: 26553 rev-min: 4385801 rev-max: 6647167 total: 2771745485
;; 24 time: 2773 cpu: 2773 gc: 0 mem: 5792
;;  1 flips: 14 moved: 2800014 mbytes: 3200016 tbytes: 3200016 trace-ops: 2760 alloc: 4563187216
;; achtung 14
;; traced-count: 2800014 gc-cycles: 14 overflow-count: 234773 stacked-count: 2800014
;; cons-min: 15 cons-max: 17503 rev-min: 4400942 rev-max: 6326298 total: 2755122265
;; 24 time: 2755 cpu: 2756 gc: 0 mem: 2896
;; nil

        ;; All right, current figures on Tau.
;; arc> (do (= h (ffi-lib "Dropbox/c-lib/dlhandle-dlsym") derp (get-ffi-obj "install_handle_and_dlsym" h (cprocedure (list $.c-_bytes) $.c-_int64))) (= u make-bytes.16) (derp u) (ga reversing-timing6 6) (each h (join (range 0 1)) (gc) (sleep .5) (withs f (fn (x y z m u v) (pr (pad h 2) " ") (call-asm reversing-timing6 x y z m u v)) n (* 400 (expt 2 20)) b make-bytes.n (time:do (pr (f b n 4096 u 100000 600) " ")))))
;;  0 flips: 14 moved: 2800014 mbytes: 3200016 tbytes: 3200016 trace-ops: 2760 alloc: 4697404944
;; achtung 0
;; traced-count: 2800014 gc-cycles: 14 overflow-count: 234773 stacked-count: 2800014
;; cons-min: 5 cons-max: 23553 rev-min: 1704634 rev-max: 3640922
;; time: 1163047111 cycles: 2558703640 cycles/1000sec: 2199
;; 24 time: 1164 cpu: 1164 gc: 0 mem: 5792
;;  1 flips: 14 moved: 2800014 mbytes: 3200016 tbytes: 3200016 trace-ops: 2760 alloc: 4697404944
;; achtung 0
;; traced-count: 2800014 gc-cycles: 14 overflow-count: 234773 stacked-count: 2800014
;; cons-min: 5 cons-max: 47261 rev-min: 1705292 rev-max: 3627941
;; time: 1143259148 cycles: 2515170128 cycles/1000sec: 2200
;; 24 time: 1143 cpu: 1144 gc: 0 mem: 2896
;; nil

        ;; (Why that variation?  I have no clue.  Could be other programs... whatever.)
        ;; And as for Alvin...

	;; Well, I get highly variable times and I'm not sure why.
	;; The lowest so far is 91 microseconds, but usually it's 500-1000 microseconds.
	;; I suspect it may be that it's a dual-core computer and other crap is running
	;; at the same time, and
	;; The number I'd expect would be perhaps up to 3x Tau's number, anyway.
	;; Whatever.
	;; (I guess it's dominated by rdtsc ... no, that's only about 1.5x as long.)

;; arc> (do (= h (ffi-lib "Dropbox/c-lib/dlhandle-dlsym") derp (get-ffi-obj "install_handle_and_dlsym" h (cprocedure (list $.c-_bytes) $.c-_int64))) (= u make-bytes.16) (derp u) (ga reversing-timing6 6) (each h (join (range 0 1)) (gc) (sleep .5) (withs f (fn (x y z m u v) (pr (pad h 2) " ") (call-asm reversing-timing6 x y z m u v)) n (* 400 (expt 2 20)) b make-bytes.n (time:do (pr (f b n 4096 u 100000 600) " ")))))
;;  0 flips: 14 moved: 2800014 mbytes: 3200016 tbytes: 3200016 trace-ops: 2760 alloc: 4563187216
;; achtung 0
;; traced-count: 2800014 gc-cycles: 14 overflow-count: 234773 stacked-count: 2800014
;; cons-min: 11 cons-max: 723772 rev-min: 3478971 rev-max: 13103615
;; time: 2158416993 cycles: 5727004590 cycles/1000sec: 2653
;; 24 time: 2159 cpu: 2141 gc: 0 mem: 5776
;;  1 flips: 14 moved: 2800014 mbytes: 3200016 tbytes: 3200016 trace-ops: 2760 alloc: 4563187216
;; achtung 0
;; traced-count: 2800014 gc-cycles: 14 overflow-count: 234773 stacked-count: 2800014
;; cons-min: 11 cons-max: 107065 rev-min: 3478862 rev-max: 6281063
;; time: 2137301406 cycles: 5670977890 cycles/1000sec: 2653
;; 24 time: 2138 cpu: 2133 gc: 0 mem: 2880
;; nil
;; arc> (do (= h (ffi-lib "Dropbox/c-lib/dlhandle-dlsym") derp (get-ffi-obj "install_handle_and_dlsym" h (cprocedure (list $.c-_bytes) $.c-_int64))) (= u make-bytes.16) (derp u) (ga reversing-timing6 6) (each h (join (range 0 1)) (gc) (sleep .5) (withs f (fn (x y z m u v) (pr (pad h 2) " ") (call-asm reversing-timing6 x y z m u v)) n (* 400 (expt 2 20)) b make-bytes.n (time:do (pr (f b n 4096 u 100000 600) " ")))))
;;  0 flips: 14 moved: 2800014 mbytes: 3200016 tbytes: 3200016 trace-ops: 2760 alloc: 4563187216
;; achtung 0
;; traced-count: 2800014 gc-cycles: 14 overflow-count: 234773 stacked-count: 2800014
;; cons-min: 11 cons-max: 1930988 rev-min: 3480554 rev-max: 24663265
;; time: 2210964114 cycles: 5866429730 cycles/1000sec: 2653
;; 24 time: 2213 cpu: 2146 gc: 0 mem: 5776
;;  1 flips: 14 moved: 2800014 mbytes: 3200016 tbytes: 3200016 trace-ops: 2760 alloc: 4563187216
;; achtung 0
;; traced-count: 2800014 gc-cycles: 14 overflow-count: 234773 stacked-count: 2800014
;; cons-min: 11 cons-max: 1053311 rev-min: 3480336 rev-max: 6343984
;; time: 2148684147 cycles: 5701180080 cycles/1000sec: 2653
;; 24 time: 2150 cpu: 2139 gc: 0 mem: 2880
;; nil
;; arc> (do (= h (ffi-lib "Dropbox/c-lib/dlhandle-dlsym") derp (get-ffi-obj "install_handle_and_dlsym" h (cprocedure (list $.c-_bytes) $.c-_int64))) (= u make-bytes.16) (derp u) (ga reversing-timing6 6) (each h (join (range 0 1)) (gc) (sleep .5) (withs f (fn (x y z m u v) (pr (pad h 2) " ") (call-asm reversing-timing6 x y z m u v)) n (* 400 (expt 2 20)) b make-bytes.n (time:do (pr (f b n 4096 u 100000 600) " ")))))
;;  0 flips: 14 moved: 2800014 mbytes: 3200016 tbytes: 3200016 trace-ops: 2760 alloc: 4563187216
;; achtung 0
;; traced-count: 2800014 gc-cycles: 14 overflow-count: 234773 stacked-count: 2800014
;; cons-min: 11 cons-max: 807911 rev-min: 3478900 rev-max: 6335828
;; time: 2149048639 cycles: 5702147200 cycles/1000sec: 2653
;; 24 time: 2149 cpu: 2143 gc: 0 mem: 5776
;;  1 flips: 14 moved: 2800014 mbytes: 3200016 tbytes: 3200016 trace-ops: 2760 alloc: 4563187216
;; achtung 0
;; traced-count: 2800014 gc-cycles: 14 overflow-count: 234773 stacked-count: 2800014
;; cons-min: 11 cons-max: 91827 rev-min: 3478368 rev-max: 6097208
;; time: 2134423977 cycles: 5663343120 cycles/1000sec: 2653
;; 24 time: 2135 cpu: 2133 gc: 0 mem: 2880
;; nil
	;; All right, well.

	;; Alvin on Linux!
;; arc> (do (= h (ffi-lib "Dropbox/c-lib/dlhandle-dlsym") derp (get-ffi-obj "install_handle_and_dlsym" h (cprocedure (list $.c-_bytes) $.c-_int64))) (= u make-bytes.16) (derp u) (ga reversing-timing8 6) (each h (join (range 0 1)) (gc) (sleep .5) (withs f (fn (x y z m u v) (pr (pad h 2) " ") (call-asm reversing-timing8 x y z m u v)) n (* 400 (expt 2 20)) b make-bytes.n (time:do (pr (f b n 4096 u 100000 600) " ")))))
;;  0 flips: 14 moved: 2800014 mbytes: 3200016 tbytes: 3200016 trace-ops: 2760 alloc: 140254304318992
;; achtung 14
;; traced-count: 2800014 gc-cycles: 14 overflow-count: 234773 stacked-count: 2800014
;; cons-min: 11 cons-max: 85737 rev-min: 3026201 rev-max: 8564083
;; time: 1905921000 cycles: 5057048420 cycles/1000sec: 2653
;; 24 time: 1906 cpu: 1905 gc: 0 mem: 5728
;;  1 flips: 14 moved: 2800014 mbytes: 3200016 tbytes: 3200016 trace-ops: 2760 alloc: 140254304318992
;; achtung 14
;; traced-count: 2800014 gc-cycles: 14 overflow-count: 234773 stacked-count: 2800014
;; cons-min: 11 cons-max: 89728 rev-min: 3026236 rev-max: 8547359
;; time: 1903521000 cycles: 5050679460 cycles/1000sec: 2653
;; 24 time: 1904 cpu: 1903 gc: 0 mem: 3152

        ;; New API now, back on Tau.
;; arc> (do (= u (handle-and-dlsym)) (ga reversing-timing9 6) (each h (join (range 0 1)) (gc) (sleep .5) (withs f (fn (x y z m u v) (pr (pad h 2) " ") (call-asm reversing-timing9 x y z m u v)) n (* 400 (expt 2 20)) b make-bytes.n (time:do (pr (f b n 4096 u 100000 600) " ")))))
;;  0 flips: 14 moved: 2800014 mbytes: 3200016 tbytes: 3200016 trace-ops: 2760 alloc: 4563187216
;; achtung 14
;; traced-count: 2800014 gc-cycles: 14 overflow-count: 234773 stacked-count: 2800014
;; cons-min: 5 cons-max: 22210 rev-min: 1765400 rev-max: 3601720
;; time: 1148316924 cycles: 2526297200 cycles/1000sec: 2199
;; 24 time: 1150 cpu: 1149 gc: 0 mem: 8608
;;  1 flips: 14 moved: 2800014 mbytes: 3200016 tbytes: 3200016 trace-ops: 2760 alloc: 4563187216
;; achtung 14
;; traced-count: 2800014 gc-cycles: 14 overflow-count: 234773 stacked-count: 2800014
;; cons-min: 5 cons-max: 23055 rev-min: 1765286 rev-max: 3484614
;; time: 1137250569 cycles: 2501951240 cycles/1000sec: 2199
;; 24 time: 1137 cpu: 1138 gc: 0 mem: 3152
;; nil

        

        ;; BELOW IS UNRELATED SHIT


        ;; Optimizations:
        ;; - 8-bit registers
        ;; -

        ;; Probably requires a scratch register.
        ;; Let's have dest be first argument, src be second.
        ;; ... Issues ...
        ;; Fuck, whatever.
        ;; ... Can have a "skip over" jump thing,
        ;; or can require a stub,
        ;; or can use "lea rax" shit.
        ;; Since already probably destroying rax as a scratch...
        ;; (Could make some dicks that use ... k.)

        

        
        ;; that'll demand up to sixteen little stubs.
        ;; but that's ok
        ;; ['cause the balance of power's maintained that way]
        ;; could insert a check ("%ifidn") for shit being rax.
        ;; could drop the "lea rax" if I was willing to have up to 15*14 little stubs.
        ;; (though most wouldn't be used)
        ;; actually, I have an idea for automatically generating stubs, involving heavy use of macros
        ;; (generate a bunch of macros that are either "do nothing" or "ifidn x y, do nothing, else do z"
        ;;  and then have things that use the stub either redefine the macro or redefine x to something new
        ;;  and have the "do z" part define the stub, and auto-execute all those macros at the end)
        

        gc_footer


        
        
        
