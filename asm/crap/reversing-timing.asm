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

        %include "gc-system11.asm" ;10 also works

        

        ;; Definitions for BS crap will appear here.
        ;; 'Cause macros need to be defined before you use them.

        VAR nil

handle: dq 0
dlsym:  dq 0

x:      dq 0
y:      dq 0

cons_min_time:  dq 0
cons_max_time:  dq 0
rev_min_time:   dq 0
rev_max_time:   dq 0

init:   dq 0
end:    dq 0
        

        
actual_code:

        gc_header

        mov qword [cons_min_time], -1
        mov qword [cons_max_time], 0
        mov qword [rev_min_time], -1
        mov qword [rev_max_time], 0
        

        mov [x], r8
        mov [y], r9

        ;; We will use a narcissistic cons cell as nil.

        saving 0
        cons rdi
        scar rdi, rdi
        scdr rdi, rdi
        mov [nil], rdi


        mov rdi, [rcx]
        mov [handle], rdi
        mov rdi, [rcx + 8]
        mov [dlsym], rdi
        

        ;; Grab some functions.
        %macro sysfunc 1
        mov rdi, [handle]
        lea rsi, [%1_str]
        call [dlsym]
        mov [%1], rax
        jmp %%end               ;murderously terrible code organization, but oh well
        align 8
%1_str:
        %defstr %%nerf %1
        db %%nerf, 0
%1:     dq 0
%%end:
        %endmacro

        ;; It looks like we'll have to be careful to save r8 and r9 for the below.
        ;; [Or store them and use them somewhere else, but I'm not doing that.]

        push r8
        push r9


        sysfunc puts
        sysfunc printf
        sysfunc getchar
        sysfunc putchar

        sysfunc mach_absolute_time

        %ifnidn FROMSPACEMASK, [fromspace_mask]
        mov FROMSPACEMASK, [fromspace_mask]
        %endif

        pop r9
        pop r8
        ;; pop rcx
        ;; pop rdx
        ;; pop rsi
        ;; pop rdi

        ;; jmp return

        ;; xor edx, edx            ;in case...

        %macro c_save 0
        push rax
        ;; rbx is saved
        push rcx
        push rdx
        push rdi
        push rsi
        ;; rbp is saved, rsp is stupid
        push r8
        push r9
        push r10
        push r11
        ;; r12 through r15 are saved
        %endmacro
        %macro c_restore 0
        pop r11
        pop r10
        pop r9
        pop r8
        pop rsi
        pop rdi
        pop rdx
        pop rcx
        pop rax
        %endmacro

        ;; We shall use ... r12 for this thing.
        ;; Aw, fuck, that's currently PAGELIMIT.
        ;; How about... rbp.  Sure.  Excellent.

        %macro timed_cons 1
        c_save
        call [mach_absolute_time]
        mov rbp, rax
        c_restore
        cons %1
        c_save
        call [mach_absolute_time]
        sub rax, rbp
        ;; max-min shit
        ;; cmp rax, [cons_min_time]
        ;; cmovb [cons_min_time], rax
        ;; cmp rax, [cons_max_time]
        ;; cmova [cons_max_time], rax
        ;; goddammit, that don't work
        minify [cons_min_time], rax
        maxify [cons_max_time], rax
        c_restore
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
        call [mach_absolute_time]
        mov [init], rax
        c_restore
        


        ;;First, cons up the initial list...

        ;;a = r8, b = r9

        ;; r8 = count
        shl r8, 3               ;tag

        ;; Testing:
        ;; neg r8

        ;; Will have: rdx = xs, rcx = ys
        mov rcx, [nil]

loop:
        

        saving RCX_MASK | RDX_MASK
        timed_cons rdi

        ;; cons_rdi                ;may kill rax
        ;; mov [rdi - CONS_TAG], r8 ;scar
        ;; mov [rdi - CONS_TAG + 8], rcx ;scdr
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
        cmp r9, 0
        je done
reversing_loop:
        call reverse
        mov rcx, rdx
        dec r9
        jnz reversing_loop
        ;; now return something at least vaguely meaningful
done:

        push rcx

        c_save
        call [mach_absolute_time]
        mov [end], rax
        c_restore

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

        mov rax, [y]
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

        lea rdi, [thing4]
        mov rsi, [cons_min_time]
        mov rdx, [cons_max_time]
        mov rcx, [rev_min_time]
        mov r8, [rev_max_time]
        mov r9, [end]
        sub r9, [init]
        mov rax, 0
        call [printf]

                

        pop rcx
        
        ;; ass
        cheap_cdr rax, rcx
        cheap_car rax, rax

        pop rdi
        cheap_car rsi, rdi
        add rax, rsi
        ;; mov rax, 999
        ;; mov rax, 932
        ;; mov rax, [memory_top]
        ;; sub rax, ALLOCPTR
        ;; mov rax, ALLOCPTR
        ;; sub rax, [tospace_bottom]
        
        jmp return

thing:  db "flips: %ld moved: %ld mbytes: %ld tbytes: %ld trace-ops: %ld alloc: %ld", 10, 0
thing2: db "alloc: %ld", 10, 0
thing3: db "traced-count: %ld gc-cycles: %ld overflow-count: %ld stacked-count: %ld", 10, 0
thing4: db "cons-min: %ld cons-max: %ld rev-min: %ld rev-max: %ld total: %ld", 10, 0
whatever:       db "nerf", 10, 0
dick:   db "achtung %ld", 10, 0
        
        
        ;; Arg in rcx, dest in rdx, I suppose.
        ;; Garbage ftw.
        ;; No continuations.
        ;; Assume nonempty.
        ;; ... Use r8 as scratch, eh?
        ;; Ah, this runs into barrs.
        ;; ... Also must initialize rdx to 0, I suppose.
        ;; Might as well make it proper reverse.
reverse:
        c_save
        call [mach_absolute_time]
        mov rbp, rax
        c_restore
        ;; push rbp ;bad idea... [fake pointers on stack] oh dear.
        ;; ok, fine, I can shl it.
        shl rbp, 3
        push rbp
        
        
        mov rdx, [nil]
        cmp rcx, [nil]
        je reverse_ret
reverse_loop:        
        ;; mov r8, [rcx - CONS_TAG] ;accualy is car, must operationalize...
        car r8, rcx
        saving RCX_MASK | RDX_MASK
        ;; saving 0
        ;; Now, for purposes of fucking shit up, we actually don't rely on that.
        ;; push rcx
        ;; push rdx
        timed_cons rdi
        ;; pop rdx
        ;; pop rcx
        ;; jesus christ that slows down the program

        ;; unfortunately I don't see proof that this works, but...

        scar rdi, r8
        scdr rdi, rdx
        mov rdx, rdi

        ;; can I do this?
        ;; not in some places
        ;; cdr rcx, rcx
        ;; mov r13, rcx
        ;; cdr rcx, r13
        mov r10, rcx
        cdr rcx, r10
        
        cmp rcx, [nil]
        jne reverse_loop
reverse_ret:
        c_save
        call [mach_absolute_time]
        mov rbp, rax
        c_restore
        pop rax
        shr rax, 3
        sub rbp, rax
        ;; rbp is now the dick
        ;; cmp rbp, [rev_min_time]
        ;; cmovb [rev_min_time], rbp
        ;; cmp rbp, [rev_max_time]
        ;; cmova [rev_max_time], rbp
        minify [rev_min_time], rbp
        maxify [rev_max_time], rbp
        
        ret


        



        mov rax, 77
        jmp return




        ;; Ok, that seemed to work.
        ;; Moar.


rejected:
        mov rax, 981
        jmp return


;; arc> (do (= h (ffi-lib "Dropbox/c-lib/dlhandle-dlsym.dylib") derp (get-ffi-obj "install_handle_and_dlsym" h (cprocedure (list $.c-_bytes) $.c-_int64))) (= u make-bytes.16) (derp u) (ga reversing-timing 6) (each h (join (range 0 1)) (gc) (sleep .5) (withs f (fn (x y z m u v) (pr (pad h 2) " ") (call-asm reversing-timing x y z m u v)) n (* 40 (expt 2 20)) b make-bytes.n (time:do (pr (f b n 4096 u 1000 200000) " ")))))
;;  0 flips: 191 moved: 382191 mbytes: 32016 tbytes: 32016 trace-ops: 191 alloc: 4531674016
;; achtung 190
;; traced-count: 382191 gc-cycles: 191 overflow-count: 781253 stacked-count: 382191
;; cons-min: 15 cons-max: 26519 rev-min: 43520 rev-max: 99349 total: 9174785456
;; 24 time: 9175 cpu: 9176 gc: 0 mem: 5792
;;  1 flips: 191 moved: 382191 mbytes: 32016 tbytes: 32016 trace-ops: 191 alloc: 4531674016
;; achtung 190
;; traced-count: 382191 gc-cycles: 191 overflow-count: 781253 stacked-count: 382191
;; cons-min: 15 cons-max: 33129 rev-min: 43520 rev-max: 88304 total: 9094862450
;; 24 time: 9095 cpu: 9095 gc: 0 mem: 2896
;; nil
        
        ;; BRETTY GOOD [26 microsecond pauses]
        ;; also the instrumentation introduces 18x overhead

        ;; ...
        ;; actually...
        ;; I think the conses may never have had to do GC work, it all being done in the GC cycle
        ;; imm. after the GC flip.

;; arc> (do (= h (ffi-lib "Dropbox/c-lib/dlhandle-dlsym.dylib") derp (get-ffi-obj "install_handle_and_dlsym" h (cprocedure (list $.c-_bytes) $.c-_int64))) (= u make-bytes.16) (derp u) (ga reversing-timing 6) (each h (join (range 0 1)) (gc) (sleep .5) (withs f (fn (x y z m u v) (pr (pad h 2) " ") (call-asm reversing-timing x y z m u v)) n (* 40 (expt 2 20)) b make-bytes.n (time:do (pr (f b n 4096 u 10000 20000) " ")))))
;;  0 flips: 194 moved: 3880194 mbytes: 320016 tbytes: 320016 trace-ops: 194 alloc: 4521222944
;; achtung 190
;; traced-count: 3880194 gc-cycles: 194 overflow-count: 781289 stacked-count: 3880194
;; cons-min: 16 cons-max: 249901 rev-min: 483821 rev-max: 963435 total: 10484456185
;; 24 time: 10485 cpu: 10484 gc: 0 mem: 5792
;;  1 flips: 194 moved: 3880194 mbytes: 320016 tbytes: 320016 trace-ops: 194 alloc: 4521222944
;; achtung 190
;; traced-count: 3880194 gc-cycles: 194 overflow-count: 781289 stacked-count: 3880194
;; cons-min: 16 cons-max: 195321 rev-min: 484275 rev-max: 737405 total: 10412033388
;; 24 time: 10412 cpu: 10413 gc: 0 mem: 2896

;; arc> (do (= h (ffi-lib "Dropbox/c-lib/dlhandle-dlsym.dylib") derp (get-ffi-obj "install_handle_and_dlsym" h (cprocedure (list $.c-_bytes) $.c-_int64))) (= u make-bytes.16) (derp u) (ga reversing-timing 6) (each h (join (range 0 1)) (gc) (sleep .5) (withs f (fn (x y z m u v) (pr (pad h 2) " ") (call-asm reversing-timing x y z m u v)) n (* 40 (expt 2 20)) b make-bytes.n (time:do (pr (f b n 4096 u 100000 2000) " ")))))
;;  0 flips: 235 moved: 47000235 mbytes: 3200016 tbytes: 3200016 trace-ops: 235 alloc: 4541521440
;; achtung 190
;; traced-count: 47000235 gc-cycles: 235 overflow-count: 781640 stacked-count: 47000235
;; cons-min: 15 cons-max: 1804842 rev-min: 4389195 rev-max: 7746188 total: 9569040707
;; 24 time: 9569 cpu: 9569 gc: 0 mem: 5792
;;  1 flips: 235 moved: 47000235 mbytes: 3200016 tbytes: 3200016 trace-ops: 235 alloc: 4541521440
;; achtung 190
;; traced-count: 47000235 gc-cycles: 235 overflow-count: 781640 stacked-count: 47000235
;; cons-min: 15 cons-max: 2427669 rev-min: 4385120 rev-max: 8181862 total: 9723859652
;; 24 time: 9724 cpu: 9724 gc: 0 mem: 2896
        

        ;; this is bad, it looks like the GC work is always done in one chunk
        
        

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


        
        
        
