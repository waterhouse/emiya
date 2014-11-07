

        ;; So.
        ;; Testing versions of stuff.
        ;; Allocate a cons cell a bunch of times.

        ;; Program:
        ;; Create a list, xs, of (1 . nil),
        ;; then keep replacing xs with the result of:
        ;; "For each x in xs, accumulate x and x+5."
        ;; 0/10 bretty stupid.
        ;; But that is the general idea.

        ;; It actually is possible for me to rely on global variables here, by the way, because
        ;; the Racket runtime won't move any shit around during program execution.
        ;; But neh, no need to do that.
        

        ;; Args:
        ;; rdi = mode
        ;; rsi = reps
        ;; rdx = "page" size (4096 as my arbitrary choice)
        
        ;; rcx = memory buffer
        ;; r8 = buffer length (or screw that?)

        ;; Then:
        ;; r9 = malloc ptr (?)
        ;; Actually, nah, have that be the memory buffer.

        ;; r9 = "page" limit

        ;; r10 = xs
        ;; r11 will be ys

        mov rax, 0xfffefafd

        %define CONS_TAG 3
        
        add r8, rcx             ;buf + size
        push rcx                ;need dick for end
        push r8                 ;rarely use
        push rdx                ;likewise
        lea r9, [rcx + rdx]     ;need it to set up this though

        ;; initial list
        lea r10, [rcx + CONS_TAG]
        mov qword [r10 - CONS_TAG], 8
        mov qword [r10 + 8 - CONS_TAG], 0
        add rcx, 16
        mov r11, 0


        cmp rdi, 0
        je lea_approach
        cmp rdi, 1
        je subrout_approach
        cmp rdi, 2
        je aside_approach
        cmp rdi, 3
        je noob_approach

        ;; DESTROYS RAX
        %macro lea_cons_rdi 0
        lea rdi, [rcx + CONS_TAG]
        add rcx, 16
        cmp rcx, r9
        lea rax, [rel %%lea_cons_done]
        jg lea_overflow         ;g; if alloc is at limit, then that's fine; next alloc is win
%%lea_cons_done:
        %endmacro
        
        
        ;; grab dicks...
        ;; no type checking, though

        ;; xs = r10
        ;; ys = r11
        ;; ... reverse? nah. it can be flipped as desired.

        ;; we know that xs doesn't start as nil.

lea_approach:   
        
lea_loop:
        lea_cons_rdi
        mov rdx, [r10 - CONS_TAG] ;car
        mov r10, [r10 - CONS_TAG + 8] ;cdr
        mov [rdi - CONS_TAG], rdx
        mov [rdi - CONS_TAG + 8], r11
        mov r11, rdi

        add rdx, 40
        lea_cons_rdi
        mov [rdi - CONS_TAG], rdx
        mov [rdi - CONS_TAG + 8], r11
        mov r11, rdi
        
        cmp r10, 0
        jne lea_loop

        mov r10, r11
        mov r11, 0

        dec rsi
        jnz lea_loop
        
        ;; return
        mov rax, rdx
        mov rax, r10
        sub rax, [rsp + 16]     ;offset from end
        
        add rsp, 24
        ret

lea_overflow:
        ;; I guess we look at the difference between rcx and rdi
        ;; and deduce the desired malloc size.
        ;; I suppose we could save registers or something.
        ;; But we could also use unused shit.
        ;; r10.
        ;; eh, not unused, so.

        ;; rdi may be tagged now.
        push r10
        mov r10, rcx
        sub r10, rdi            ;size - tag: btwn size-7 and size
        add r10, 7              ;btwn size and size+7
        and r10, -8             ;size
        ;; now we "do gc work"
        nop
        ;; now we "grab more memory"
        mov rcx, r9
        add r9, [rsp + 8]       ;page size
        cmp r9, [rsp + 16]      ;memory limit
        jg epic_failure
        ;; now we do the allocation
        and rdi, 7
        add rdi, rcx            ;OR would also work
        add rcx, r10
        ;; return
        ;; erm, restore
        pop r10
        jmp rax

        
epic_failure:
        mov rax, 69
        add rsp, 32
        
        ret
                
        
subrout_approach:

subrout_loop:
        call subrout_cons_rdi
        mov rdx, [r10 - CONS_TAG] ;car
        mov r10, [r10 - CONS_TAG + 8] ;cdr
        mov [rdi - CONS_TAG], rdx
        mov [rdi - CONS_TAG + 8], r11
        mov r11, rdi

        add rdx, 40
        call subrout_cons_rdi
        mov [rdi - CONS_TAG], rdx
        mov [rdi - CONS_TAG + 8], r11
        mov r11, rdi
        
        cmp r10, 0
        jne subrout_loop

        mov r10, r11
        mov r11, 0

        dec rsi
        jnz subrout_loop
        
        ;; return
        mov rax, rdx
        
        mov rax, r10
        sub rax, [rsp + 16]     ;offset from end
        
        add rsp, 24
        ret
        

subrout_cons_rdi_overflow:
        mov rcx, r9
        add r9, [rsp + 8]       ;stack = [return addr] ["page" size] [memory limit] ...
        cmp r9, [rsp + 16]
        jg epic_failure         ;same stack layout

subrout_cons_rdi:
        lea rdi, [rcx + CONS_TAG]
        add rcx, 16
        cmp rcx, r9             ;"page" limit
        jg subrout_cons_rdi_overflow
        ret


        ;; as in "Look Aside" [nope]
        ;; having the usual code involve a jump
aside_approach:

        %macro aside_cons_rdi 0
        lea rdi, [rcx + CONS_TAG]
        add rcx, 16
        cmp rcx, r9
        jng %%k
        call subrout_cons_rdi_overflow
%%k:    
        %endmacro

aside_loop:
        aside_cons_rdi
        mov rdx, [r10 - CONS_TAG] ;car
        mov r10, [r10 - CONS_TAG + 8] ;cdr
        mov [rdi - CONS_TAG], rdx
        mov [rdi - CONS_TAG + 8], r11
        mov r11, rdi

        add rdx, 40
        aside_cons_rdi
        mov [rdi - CONS_TAG], rdx
        mov [rdi - CONS_TAG + 8], r11
        mov r11, rdi
        
        cmp r10, 0
        jne aside_loop

        mov r10, r11
        mov r11, 0

        dec rsi
        jnz aside_loop
        
        ;; return
        mov rax, rdx
        
        mov rax, r10
        sub rax, [rsp + 16]     ;offset from end
        
        add rsp, 24
        ret


noob_approach:
        ;; this requires extra crappy code
        
noob_loop:
        lea rdi, [rcx + CONS_TAG]
        add rcx, 16
        cmp rcx, r9
        jg noob_1
noob_1_return:  
        
        mov rdx, [r10 - CONS_TAG] ;car
        mov r10, [r10 - CONS_TAG + 8] ;cdr
        mov [rdi - CONS_TAG], rdx
        mov [rdi - CONS_TAG + 8], r11
        mov r11, rdi

        add rdx, 40

        lea rdi, [rcx + CONS_TAG]
        add rcx, 16
        cmp rcx, r9
        jg noob_2
noob_2_return:  
        mov [rdi - CONS_TAG], rdx
        mov [rdi - CONS_TAG + 8], r11
        mov r11, rdi
        
        cmp r10, 0
        jne aside_loop

        mov r10, r11
        mov r11, 0

        dec rsi
        jnz aside_loop
        
        ;; return
        mov rax, rdx
        
        mov rax, r10
        sub rax, [rsp + 16]     ;offset from end
        
        add rsp, 24
        ret        

        ;; lazy as fuck here
noob_1:
        call subrout_cons_rdi_overflow
        jmp noob_1_return
noob_2: 
        call subrout_cons_rdi_overflow
        jmp noob_2_return

        
        ;; All right.
        ;; Results...


;; arc> (for x 0 3 (let y x (let i 22 (do (= n (* 800 (expt 2 20)) xs nil xs (gc) xs make-bytes.n) (repeat 2 (prsn y (time:malloc-testing2-thing malloc-testing2 y i (* 1 4096) xs n)))))))
;; time: 19 cpu: 19 gc: 0 mem: 192
;; 0 134217699
;; time: 20 cpu: 19 gc: 0 mem: 192
;; 0 134217699
;; time: 26 cpu: 26 gc: 0 mem: 192
;; 1 134217699
;; time: 26 cpu: 27 gc: 0 mem: 192
;; 1 134217699
;; time: 19 cpu: 19 gc: 0 mem: 192
;; 2 134217699
;; time: 19 cpu: 20 gc: 0 mem: 192
;; 2 134217699
;; time: 19 cpu: 19 gc: 0 mem: 192
;; 3 134217699
;; time: 19 cpu: 19 gc: 0 mem: 192
;; 3 134217699
;; nil
;; arc> (for x 0 3 (let y x (let i 22 (do (= n (* 800 (expt 2 20)) xs nil xs (gc) xs make-bytes.n) (repeat 2 (pr y " ") (prn:time:malloc-testing2-thing malloc-testing2 y i (* 1 4096) xs n))))))
;; 0 time: 19 cpu: 19 gc: 0 mem: 192
;; 134217699
;; 0 time: 21 cpu: 21 gc: 0 mem: 192
;; 134217699
;; 1 time: 26 cpu: 26 gc: 0 mem: 192
;; 134217699
;; 1 time: 28 cpu: 29 gc: 0 mem: 192
;; 134217699
;; 2 time: 19 cpu: 19 gc: 0 mem: 192
;; 134217699
;; 2 time: 20 cpu: 21 gc: 0 mem: 192
;; 134217699
;; 3 time: 20 cpu: 19 gc: 0 mem: 192
;; 134217699
;; 3 time: 21 cpu: 21 gc: 0 mem: 192
;; 134217699
;; nil
;; arc> (for x 0 3 (let y x (let i 24 (do (= n (* 800 (expt 2 20)) xs nil xs (gc) xs make-bytes.n) (repeat 2 (pr y " ") (prn:time:malloc-testing2-thing malloc-testing2 y i (* 1 4096) xs n))))))
;; 0 time: 79 cpu: 79 gc: 0 mem: 192
;; 536870883
;; 0 time: 81 cpu: 81 gc: 0 mem: 192
;; 536870883
;; 1 time: 109 cpu: 109 gc: 0 mem: 192
;; 536870883
;; 1 time: 110 cpu: 110 gc: 0 mem: 192
;; 536870883
;; 2 time: 79 cpu: 79 gc: 0 mem: 192
;; 536870883
;; 2 time: 81 cpu: 81 gc: 0 mem: 192
;; 536870883
;; 3 time: 78 cpu: 79 gc: 0 mem: 192
;; 536870883
;; 3 time: 82 cpu: 82 gc: 0 mem: 192
;; 536870883
;; nil
;; arc> (for x 0 3 (let y x (let i 25 (do (= n (* 800 (expt 2 20)) xs nil xs (gc) xs make-bytes.n) (repeat 2 (pr y " ") (prn:time:malloc-testing2-thing malloc-testing2 y i (* 1 4096) xs n))))))
;; 0 time: 122 cpu: 123 gc: 0 mem: 192
;; 69
;; 0 time: 125 cpu: 125 gc: 0 mem: 192
;; 69
;; 1 time: 165 cpu: 165 gc: 0 mem: 192
;; 69
;; 1 time: 166 cpu: 166 gc: 0 mem: 192
;; 69
;; 2 time: 125 cpu: 125 gc: 0 mem: 192
;; 69
;; 2 time: 126 cpu: 126 gc: 0 mem: 192
;; 69
;; 3 time: 122 cpu: 123 gc: 0 mem: 192
;; 69
;; 3 time: 125 cpu: 125 gc: 0 mem: 192
;; 69
;; nil
;; arc> (for x 0 3 (let y x (let i 25 (do (= n (* 1200 (expt 2 20)) xs nil xs (gc) xs make-bytes.n) (repeat 2 (pr y " ") (prn:time:malloc-testing2-thing malloc-testing2 y i (* 1 4096) xs n))))))
;; 0 time: 835 cpu: 441 gc: 0 mem: 192
;; 1073741795
;; 0 time: 161 cpu: 161 gc: 0 mem: 192
;; 1073741795
;; 1 time: 213 cpu: 213 gc: 0 mem: 192
;; 1073741795
;; 1 time: 217 cpu: 217 gc: 0 mem: 192
;; 1073741795
;; 2 time: 193 cpu: 193 gc: 0 mem: 192
;; 1073741795
;; 2 time: 161 cpu: 161 gc: 0 mem: 192
;; 1073741795
;; 3 time: 159 cpu: 159 gc: 0 mem: 192
;; 1073741795
;; 3 time: 164 cpu: 165 gc: 0 mem: 192
;; 1073741795
;; nil
;; arc> (for x 0 3 (let y x (let i 25 (do (= n (* 1200 (expt 2 20)) xs nil xs (gc) xs make-bytes.n) (repeat 2 (pr y " ") (prn:time:malloc-testing2-thing malloc-testing2 y i (* 1 4096) xs n))))))
;; 0 time: 201 cpu: 201 gc: 0 mem: 192
;; 1073741795
;; 0 time: 167 cpu: 167 gc: 0 mem: 192
;; 1073741795
;; 1 time: 217 cpu: 217 gc: 0 mem: 192
;; 1073741795
;; 1 time: 228 cpu: 228 gc: 0 mem: 192
;; 1073741795
;; 2 time: 162 cpu: 162 gc: 0 mem: 192
;; 1073741795
;; 2 time: 168 cpu: 168 gc: 0 mem: 192
;; 1073741795
;; 3 time: 167 cpu: 168 gc: 0 mem: 192
;; 1073741795
;; 3 time: 170 cpu: 169 gc: 0 mem: 192
;; 1073741795
;; nil
;; arc> (for x 0 3 (let y (- 3 x) (let i 25 (do (= n (* 1200 (expt 2 20)) xs nil xs (gc) xs make-bytes.n) (repeat 2 (pr y " ") (prn:time:malloc-testing2-thing malloc-testing2 y i (* 1 4096) xs n))))))
;; 3 time: 196 cpu: 196 gc: 0 mem: 192
;; 1073741795
;; 3 time: 166 cpu: 166 gc: 0 mem: 192
;; 1073741795
;; 2 time: 163 cpu: 163 gc: 0 mem: 192
;; 1073741795
;; 2 time: 164 cpu: 165 gc: 0 mem: 192
;; 1073741795
;; 1 time: 291 cpu: 291 gc: 0 mem: 192
;; 1073741795
;; 1 time: 216 cpu: 217 gc: 0 mem: 192
;; 1073741795
;; 0 time: 163 cpu: 163 gc: 0 mem: 192
;; 1073741795
;; 0 time: 166 cpu: 165 gc: 0 mem: 192
;; 1073741795
;; nil

        ;; Looks like "aside" and "lea" are actually comparable.
        ;; I don't know if that will always be the case...
        ;; (I kind of expect "lea" to be best)
        ;; The "aside" method has the advantage of not requiring a scratch register.
        ;; Hmm...
        ;; The branch prediction is probably equally good in both cases.
        ;; I feel like having a jump ... should screw up pipelining and stuff.
        ;; Though a really short jump might not.
        ;; And possibly ... if you have a bunch of pieces of code.
        

        
