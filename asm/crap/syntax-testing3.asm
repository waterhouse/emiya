

        ;; nasm -E shows macroexpanded output. useful.

        ;; now we abuse the system thoroughly.



;;         Model:
;;         saving rcx, rdx, rsi
;;         cons rdi

;;         saving rdi
;;         cons rdx

;;         Let's be a bit less adventurous than that.

;;         saving RCX_MASK | RDX_MASK | RSI_MASK
;;         cons rdi

;;         etc.

        ;; ->
        ;; [cons instructions]
        ;; lea rax, [rel place_i]
        ;; cmp
        ;; jg get_more_memory_and_possibly_flip
        ;; place_i:
        ;; ...

        ;; saved_info:
        ;; resq n*2
        ;; ...
        ;; startup_sequence:
        ;; lea rax, [rel place_1]
        ;; mov [rel saved_info + 2*i*8], rax
        ;; mov [rel saved_info + 2*i*8 + 8], RCX_MASK | RDX_MASK | RSI_MASK

        ;; Btw, another option for the alloc sequence is to put the mask in the
        ;; code itself, if we go for the "default is a skipping-over jump"/"aside" option.
        ;; (Sort of like I'm planning to do for closures, 'cept that happens before.)
        ;; Would reduce (but not eliminate) the need for setting shit up on startup.
        ;; However, would mean the "overflow" code would have to deal with that.
        ;; Meh.
        ;; (Also not entirely sure about the alignment thing...)

        ;; Btw, all these labels show up at the end of the object file.
        ;; Oh well.  Sort of like comments.  Just waste a bit of contiguous memory.

        default rel

        %define n 0           ;hope this works...
        %define alloc_ptr r12
        ;; terminology: slice, hunk, lump...
        ;; hunk.
        %define hunk_limit rbx  ;likely keep this in memory

        ;; could raise error if arg is rax, but eh
        %macro cons 1
        lea %1, [alloc_ptr + CONS_TAG]
        add alloc_ptr, 16
        cmp alloc_ptr, hunk_limit
        lea rax, [alloc_return_%[n]]
        jg alloc_overflow_%1
        alloc_return_%[n]:
        
        %endmacro
        

        %macro saving 1
        %assign n n+1
        %define saved_regs_%[n] %1
        %endmacro

        ;; Together, these will actually guarantee that "cons" et al aren't used more than
        ;; once in succession: otherwise alloc_return_n is a label for two places.

        %define RAX_MASK 1
        %define RBX_MASK 2
        %define RCX_MASK 4
        %define RDX_MASK 8
        %define RDI_MASK 16
        %define RSI_MASK 32

        %define CONS_TAG 3
        

        saving RDI_MASK | RBX_MASK
        cons rcx
        saving RDX_MASK
        cons rsi


alloc_overflow_rcx:
        ;; Neeh
alloc_overflow_rsi:
        ;; Write this code later.
        
        


        ;; this better be aligned
saved_regs:
        ;; resq n*2
        ;; Non-warning:
        %rep n*2
        dq 0
        %endrep
        ;; lel
        
        ;; good lord, off-by-1 errors?
        ;; ...
        ;; I seem doomed to encounter them
        ;; oh well
startup_sequence:
        %define i 1
        %rep n
        lea rax, [alloc_return_%[i]]
        mov [saved_regs + 2*(i-1)*8], rax
        mov qword [saved_regs + 2*(i-1)*8 + 8], saved_regs_%[i]

        %assign i i+1
        %endrep
        



        
