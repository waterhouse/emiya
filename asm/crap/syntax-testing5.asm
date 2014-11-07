

        ;; nasm -E shows macroexpanded output. useful.

        ;; now we abuse the system thoroughly.

        default rel
        
        ;; constants go near top
        %define RAX_MASK 1
        %define RBX_MASK 2
        %define RCX_MASK 4
        %define RDX_MASK 8
        %define RDI_MASK 16
        %define RSI_MASK 32

        %define CONS_TAG 3
        %define CLOS_TAG 5


        ;; Let's say that ints are 000 and chars are 100.
        ;; Then the ptr mask is 011.
        %macro ptr_test 1
        test %1, 3
        %endmacro



        ;; Doesn't include ptr test.
        %macro fromspace_test 1
        test %1, [fromspace_mask]
        %endmacro

        %define CONT_REG rbp    ;why not
        
        ;; these actually have to return their result in RFLAGS
        ;; because you might want to "jump if" or "jump if not"


        ;; Shit begins.
        ;; Variables.
        ;; Mostly in the other file; we'll just have enough to assemble this file.
fromspace_mask: dq 0
        


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


        ;; Ok, now... could add closures, but there's also adding "move" shit.
        ;; Well, this is testing syntax, so let's do closures.


        %define alloc_count 0           ;hope this works...
        %define alloc_ptr r12
        ;; terminology: slice, hunk, lump...
        ;; hunk.
        %define hunk_limit rbx  ;likely keep this in memory

        ;; could raise error if arg is rax, but eh
        %macro cons 1
        lea %1, [alloc_ptr + CONS_TAG]
        add alloc_ptr, 16
        cmp alloc_ptr, hunk_limit
        lea rax, [alloc_return_%[alloc_count]]
        jg alloc_overflow_%1
        alloc_return_%[alloc_count]:
        
        %endmacro
        

        %macro saving 1
        %assign alloc_count alloc_count+1
        %define saved_regs_%[alloc_count] %1
        %endmacro

        ;; Together, these will actually guarantee that "cons" et al aren't used more than
        ;; once in succession: otherwise alloc_return_n is a label for two places.


        ;; A closure.
        ;; Oh man.
        ;; Uses some cooperating macros.
        ;; Syntax:
        
        ;; closure name
        ;; args ...
        ;; saved ...
        ;; body
        ;; [actual code]
;;         ->
;;         align 8
;;         ;; Pre-code fields...
;;         dq n ;; argmin
;;         dq n ;; argmax
;;         dq n ;; saved-count
;;         dq 0 ;; trace-exec, install at startup
;;         dq 0 ;; metadata
;;         [actual code]
;; name:
;;         ...

;;         align 8
;;         dq n                    ;argmin
;;         dq n                    ;argmax
;;         dq n                    ;saved-count
;;         dq 0                    ;trace-exec, remains 0 [probably]
;;         dq 0                    ;metadata, remains 0
;;         ;; [some of those fields might be omitted]
;; name_trace_exec:
;;         call trace_generic_closure ;can look in the CONT argument for all it needs
;;         jmp name
        
;; startup_sequence:
;;         ...
;;         lea rax, [name_trace_exec]
;;         mov [name - CLOS_TRACE_EXEC], rax
;;         ;; then we'd also like to install metadata of at least the name
;;         ;; and possibly the arglist too...
;;         ;; can do the cheapo thing
;;         call make_arc_string
;;         db "name", 0
;;         mov rdx, rax
;;         cons rdi
;;         mov [rdi - CONS_TAG], rdx
;;         mov [rdi - CONS_TAG + 8], nil ;nil => [the_nil]
;;         mov [name - CLOS_METADATA], rdi
;;         ;; maybe just call a common subroutine on a string containing
;;         ;; the name and arglist and other shit.


        %define closure_count 0
        
        %macro closure 1
        %assign closure_count closure_count+1
        %define closure_%[closure_count]_name %1
        %endmacro
        ;; For args, a more advanced user may set argmin and argmax separately.
        ;; Also there isn't really a need to store it in closure_n_argmin instead
        ;; of just "argmin" or something.
        ;; Just serves as a kind of verification, that "body" will throw an error
        ;; unless the above shit has been defined.
        ;; ... Actually, these fields are supposed to store 8n, rather than n.
        ;; So.
        %macro args 0-*
        %assign closure_%[closure_count]_argmin (%0 * 8)
        %assign closure_%[closure_count]_argmax (%0 * 8)
        %endmacro

        ;; As for saved-n.
        ;; 8n, or n?
        ;; Can any purpose be served by the low bits?
        ;; Could I pack all this information into fewer fields?  (Words, that is.)
        ;; Meh, I'll just use 8n for consistency.
        ;; (Actually, is possibly useful for encoding an offset.)
        %macro saved 0-*
        %assign closure_%[closure_count]_saved (%0 * 8)
        %endmacro
        ;; Again, the above could be redefined later to actually store the names
        ;; of the vars somewhere useful.

        %define CLOS_METADATA 40
        %define CLOS_TRACE_EXEC 32
        %define CLOS_SAVED 24
        %define CLOS_ARGMAX 16
        %define CLOS_ARGMIN 8

        ;; actually these should be in reverse order

        %macro body 0           ;ironic that this macro, doing all the work, takes 0 args [could be hacked later]

        align 8
        dq -8                ;metadata, probably remains 0 ;have be, say, -8 to indicate "this is trace-exec, not regular code"
        dq 0                ;trace-exec, probably remains 0 ;idiot, GC workers that trace but not exec need this
        dq closure_%[closure_count]_saved
        dq closure_%[closure_count]_argmax
        dq closure_%[closure_count]_argmin
%[closure_%[closure_count]_name]_trace_exec:
        ;; call trace_exec_generic
        ;; jmp closure_%[closure_count]_name
        jmp trace_exec_generic
        
        
        align 8
        dq 0                ;metadata, startup probably will overwrite
        dq 0                ;trace-exec, startup must overwrite
        dq closure_%[closure_count]_saved
        dq closure_%[closure_count]_argmax
        dq closure_%[closure_count]_argmin
closure_%[closure_count]_name:  ;nasm macexes completely
        ;; the user will put the actual code after this
        ;; meanwhile... anything?

        %endmacro



        ;; we likely have random-ass args passed to us.
        ;; ... could save an instruction and a return if we had the closure's orig. ptr in
        ;; a field before the trace-exec.
        ;; I dunno.
        ;; .... now, I'll probably save a reg or two, but.........
        ;; if my calling convention is something, then I can guarantee I don't need to save some regs.
        ;; if my calling convention is something else, then I would probably need to save some.
        ;; ...
        ;; For now, whatever the fuck.  It probably won't happen very often anyway.
        %define save_some_regs nop ;lel
trace_exec_generic:
        save_some_regs
        ;; mov rdi, [CONT_REG - CLOS_TAG - CLOS_SAVED] ;idiot
        mov rdi, [CONT_REG - CLOS_TAG] ;trace_exec code ptr
        mov rdi, [rdi - CLOS_SAVED]    ;saved-count
        ;; now we loop through the saved items...
        ;; of which there may be none.
        ;; could put addr in rdi, or could use count.
        ;; eh... for protocol, you probably want the address of the thing-needing-to-be-moved
        ;; to be stored somewhere useful.
        ;; this is tightly coupled with the thing that moves and that stores the moved thing, though...
        ;; ... "sub"/"jnz" is good.
        ;; [wtvr, could be changed in future anyway]
        ;; ... can't have "[reg + reg + constant]", I think, so we go with ptr.
        cmp rdi, 0
        jz trace_exec_return
        add rdi, CONT_REG
trace_exec_loop:        
        sub rdi, 8              ;that's where the thing would be
        cmp rdi, CONT_REG
        je trace_exec_return
        mov rax, [rdi - CLOS_TAG]
        ptr_test rax
        jz trace_exec_loop
        fromspace_test rax
        jz trace_exec_loop
        call move_rax_using_whatever ;would probably want a couple of scratch regs
        mov [rdi - CLOS_TAG], rax ;in multithreaded, would use CAS to install
        jmp trace_exec_loop
        
trace_exec_return:
        ;; must be sure, in multithreaded at least, to only replace the code ptr
        ;; after everything else is traced.
        ;; and also don't replace the real code ptr with one that says "trace me again pls".
        ;; way-ull, we'll see.
        mov rdi, [CONT_REG - CLOS_TAG]
        cmp qword [rdi - CLOS_METADATA], -8
        jne trace_exec_codeptr_replaced
        mov rdi, [rdi - CLOS_TRACE_EXEC]
        mov [CONT_REG - CLOS_TAG], rdi
trace_exec_codeptr_replaced:    
        %define restore_some_regs nop ;...
        restore_some_regs
        jmp [CONT_REG - CLOS_TAG]

move_rax_using_whatever:
        ret


        

        saving RDI_MASK | RBX_MASK
        cons rcx
        saving RDX_MASK
        cons rsi


alloc_overflow_rcx:
        ;; Neeh
alloc_overflow_rsi:
        ;; Write this code later.

        ;; So, it'd be possible to have things, um, define macros like
        ;; "need_alloc_overflow_rdi", and then run things like
        ;; "%ifdef need_alloc_overflow_rdi
        ;;   define_alloc_overflow rdi
        ;;  %endif".
        ;; Maybe have a higher-order-macro that's like "map [that shit] [all reg names]".
        ;; (nasm's macro system is probably capable of general-purpose computation)
        ;; Anyway, issue is, that would have to go after all the user code.
        ;; Well, no problemo.
        ;; Next iteration.


        closure dickify
        args x, y, z
        saved u
        body
        mov rax, 3
        ret

        closure assify
        args x
        saved y, z
        body
        jmp dickify

        closure nerbify
        args
        saved
        body
        jmp nerbify
        

startup_sequence:


        %define i 0
        %rep closure_count
        %assign i i+1
        %define name %[closure_%[i]_name]
        lea rax, [%[name]_trace_exec]
        mov [name - CLOS_TRACE_EXEC], rax
        lea rax, [name]
        mov [%[name]_trace_exec - CLOS_TRACE_EXEC], rax
        ;; then we'd also like to install metadata of at least the name
        ;; and possibly the arglist too...
        ;; can do the cheapo thing
        ;; ;; IGNORED FOR NOW
        ;; call make_arc_string
        ;; db "name", 0
        ;; mov rdx, rax
        ;; cons rdi
        ;; mov [rdi - CONS_TAG], rdx
        ;; mov [rdi - CONS_TAG + 8], nil ;nil => [the_nil]
        ;; mov [name - CLOS_METADATA], rdi
        ;; maybe just call a common subroutine on a string containing
        ;; the name and arglist and other shit.
        %endrep

        
        
        
        
        
        ;; good lord, off-by-1 errors?
        ;; ...
        ;; I seem doomed to encounter them in this thing
        ;; oh well
        %define i 1
        %rep alloc_count
        lea rax, [alloc_return_%[i]]
        mov [saved_regs + 2*(i-1)*8], rax
        mov qword [saved_regs + 2*(i-1)*8 + 8], saved_regs_%[i]

        %assign i i+1
        %endrep


        ;; This startup thing is a subroutine intended to be called.
        ;; We need to put some shit possibly later, possibly before it,
        ;; certainly after the main program.
        ret





        ;; this better be aligned
saved_regs:
        ;; resq n*2
        ;; Non-warning:
        %rep alloc_count*2
        dq 0
        %endrep
        ;; lel
        
        

                

        


        
