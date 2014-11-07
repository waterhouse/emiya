

        mov rax, 0xfffefafd

        ;; Conceptually, we take n
        ;; and return a list of rho-shaped lists,
        ;; each of which is "1 a a^2 ... a^k ... a^k ..." mod n.
        ;; To do this, we shall accept a memory vector of a given size
        ;; and return the address of our thing.
        ;; No GC.
        ;; Um... Except for the fact that we will have to trace
        ;; and serialize everything at the end,
        ;; to turn it into offsets relative from beginning of mem vec
        ;; rather than real memory addresses.
        ;; The Arc process at the other end may learn to interpret the results.

        ;; ... and we shall err semi-nicely if mem vec is too small.

        ;; rdi = n
        ;; rsi = mem vec
        ;; rdx = mem vec len

        ;; we shall have integer n rep. as 8n
        ;; and cons cell at mem addr 8n rep. as 8n+1.
        ;; nil = -7 = cons cell at addr -8.
        ;; need not represent explicitly.

        ;; mem vec should be 8-byte aligned.
        ;; testing with return-rdi, it seems to be.
        ;; but would not trust implicitly.

        test rsi, 7
        jnz screw_you_misaligned

        ;; c calling convention...
        ;; well, let us save r12-r15.
        ;; we can freely modify r8-r11
        ;; and don't plan to modify rbx or rbp.
        ;; -- oh wait

        ;; r14 shall be alloc ptr
        ;; r15 shall be a vector of useful variables,
        ;; which will occupy the first several words of mem vec.

        cmp rdx, 64
        jl out_of_memory_plain

        push r12
        push r13
        push r14
        push r15

        ;; oh fuck, to do a proper out_of_memory escape,
        ;; must reset the stack pointer properly.
        ;; in that case...
        ;; push things later, and should store stack top somewhere.
        ;; ...
        ;; there are cases where we won't have to pop crap.
        ;; ok, um.
        ;; ok. push now, and ensure we will reset to a stack pointer
        ;; that is in the right place to pop things.

        ;; vector: [mem-bottom] [mem-top] [stack-toppish]

        mov [rsi], rsi
        add rdx, rsi
        mov [rsi+8], rdx
        mov [rsi+16], rsp
        
        mov r15, rsi
        mov r14, rsi
        add r14, 24

        ;; now I probably won't actually use alloc_cons much directly
        ;; instead will dick...
        mov r13, rdi            ;n
        ;; actually it is most convenient to have...
        shl r13, 3              ;8n
        mov r12, 1              ;a
        mov r11, -7             ;nil

        ;; mov r11, 23
        ;; mov rax, 8
        ;; call alloc
        ;; jmp return_r11

        ;; mov rdi, 1
        ;; mov rsi, 2
        ;; call alloc_cons
        ;; call alloc_cons
        ;; mov rax, rsp
        ;; sub rax, [r15+16]
        ;; mov r11, rax
        ;; push r11
        ;; push rax
        ;; jmp out_of_memory
        ;; jmp return_r11

        ;; loop: r11 = main list.
        ;; ... I shall execute nrev on it.
        ;; the poss-cyc lists, I shall make cons cells and scdr.
loop:
        shl r12, 3
        cmp r12, r13
        je return_nrevd_r11
        shr r12, 3              ;d'oh; oh well

        ;; xadd rax, rdx
        ;; jmp return_r11

        mov rdi, 8              ;1
        mov rsi, -7             ;nil
        call alloc_cons
        mov r10, rax
        mov r9, rax

        ;; jmp return_r11

subloop:
        ;; r10 = head
        ;; r9 = tail
        ;; rdi = 8a^n
        mov rax, rdi
        mul r12                 ;... not shl'd, so pretty good
        div r13                 ;8*rem rdx
        ;; now we see if the result is in the list already
        mov rcx, r10
memq_loop:
        cmp rdx, [rcx-1]        ;oh man type detagging
        je subloop_match
        mov rcx, [rcx+7]
        cmp rcx, -7
        jne memq_loop
        ;; no match; prepare for more loop (subloop rather)
        mov rdi, rdx
        mov rsi, -7
        call alloc_cons
        mov [r9+7], rax
        mov r9, rax
        jmp subloop

subloop_match:
        mov [r9+7], rcx         ;tag...
        ;; now prepare for more loop

        mov rdi, r10
        mov rsi, r11
        call alloc_cons
        mov r11, rax
        add r12, 1              ;not 8
        jmp loop


return_nrevd_r11:
        jmp return_r11          ;lolz for now
        




return_r11:
        mov rax, r11
        pop r15
        pop r14
        pop r13
        pop r12
        ret
        ;; that should work assuming all stacks have been
        ;; properly handled...

screw_you_misaligned:
        mov rax, -2
        ret

out_of_memory:
        mov rsp, [r15+16]
        pop r15
        pop r14
        pop r13
        pop r12

out_of_memory_plain:

        mov rax, -3
        ret

alloc_cons:
        ;; c calling conv
        mov rax, 16
        call alloc
        mov [rax], rdi
        mov [rax+8], rsi
        add rax, 1
        ret

alloc:                          ;arg in rax
        xadd r14, rax           ;d'oh, reversed dicks
        cmp r14, [r15+8]
        ja out_of_memory
        ret                     ;d'oh, forgot that shit...






        