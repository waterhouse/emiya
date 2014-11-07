

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
        
        
;;         %macro lea_cons_rdi 0
;;         ;; mov rdi, 16
;;         ;; add rdi, rcx
;;         lea rdi, [rcx + 16]     ;BRETTY GOOD
;;         cmp rdi, r9
;;         lea rax, lea_cons_done
;;         jnl lea_overflow
;;         add rcx, 16
;; %%lea_cons_done:
;;         add rdi, CONS_TAG
;;         %endmacro

;;         %macro lea_cons_rdi 0
;;         ;; mov rdi, 16
;;         ;; add rdi, rcx
;;         lea rdi, [rcx + 16 + CONS_TAG]     ;10/10
;;         cmp rdi, r9
;;         lea rax, lea_cons_done
;;         jnl lea_overflow
;;         add rcx, 16
;; %%lea_cons_done:
;;         %endmacro

        ;; wait wtf you're an idiot
        ;; you want the current ........
        ;; fuck

        ;; DESTROYS RAX
        %macro lea_cons_rdi 0
        lea rdi, [rcx + CONS_TAG]
        add rcx, 16
        cmp rcx, r9
        lea rax, [rel %%lea_cons_done]
        jnl lea_overflow
%%lea_cons_done:
        %endmacro
        
       
;;         ;; Couple of ways I can imagine, but...

;;         lea rax, lea_alloced
;;         mov rdi, 16
;;         add rdi, rcx
;;         ;; could reorder some of the above
;;         cmp rdi, r9
;;         jnl lea_overflow

;; lea_alloced:
;;         ;; car and cdr and crap
;;         ;; ...
;;         ;; no type tags?
;;         ;; mebbe.
;;         ;; type tags.
;;         add rdi, CONS_TAG

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
        ;; lel I forgot to write the code here
        ;; and fucked up the prev. line
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
        ;; add r9, rdx             ;page size
        ;; MOVED THAT SHIT UP
        ;; add r9, [rsp]           ;page size
        ;; cmp r9, [rsp + 8]       ;memory limit
        ;; SHIT, FORGOT TO MOVE THAT SHIT UP
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
                
        



        
