

        ;; So, the user wants to write a program.
        ;; A program that uses operations like cons, car, cdr, and closure.
        ;; This is some shit the user can include to make a program like that work.

        ;; The user will "%include "gc-system.asm" at the top.
        ;; This will define a bunch of macros that may be used in the user's main program.
        ;; Then the user shall call "gc_footer" at the bottom.
        ;; This will define the "startup_sequence" label, all the startup code,
        ;;  and all the stub functions that are needed.
        ;; Now, there's a bunch of crap that I could choose to put in various places.
        ;; There are the variables like "fromspace_mask", and the jump tables I'll
        ;; define, and the saved_regs table.
        ;; (Closures and the fields before them will necessarily be in the main code.)
        ;; nasm seems to think I should put some of the above in a "data" section, different
        ;; from a "code" or "text" section.
        ;; (It prints a warning with "resq" in a non-data section, it seems.)
        ;; ("bss" section is for resq shit.)
        ;; (..............................
        ;;  Goddammit, according to section 7.9.2 nasm has various default section things,
        ;;  and none of them provides both "exec" and "write".
        ;;  So there's value in my writing shit.
        ;;  However, I could probably tell it to have it be writable and whatnot.
        ;;  Then I could actually run Racket shit.
        ;;  Which might obviate ... much of the startup_sequence I have to write.
        ;;  Possibly all the stuff that's not specific to Arc.)
        
        ;; Now, the info table at least must be defined, and basically therefore must appear,
        ;; after the main user code, because its size comes from the number of times the
        ;; user's code increments "alloc_count".
        ;; Can you have a data section after a code section?
        ;; If you have it after lexically, will nasm reorder them?
        ;; Would that be a problem?
        ;; Could be tested.
        ;; --Looks like: lexical permutations are legal, multiple bss sections and probably
        ;;  any sections are legal, and nasm does reorder them.
        ;; Well... 

        ;; Anyway, meanwhile, I haven't tested and chosen which of a few different
        ;; alloc. and other methods to use, so this will wait a bit...
        

        ;; So, here we go.


        ;; Relying on semispaces2.asm atm.
        

        

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


        %define RAX_MASK 1
        %define RBX_MASK 2
        %define RCX_MASK 4
        %define RDX_MASK 8
        %define RDI_MASK 16
        %define RSI_MASK 32
        %define RBP_MASK 64
        %define RSP_MASK 128
        %define R8_MASK 256
        %define R9_MASK 512
        %define R10_MASK 1024
        %define R11_MASK 2048
        %define R12_MASK 4096
        %define R13_MASK 8192
        %define R14_MASK 16384
        %define R15_MASK 32768

        


        %define alloc_count 0           ;hope this works...
        ;; %define alloc_ptr r12
        ;; terminology: slice, hunk, lump...
        ;; hunk.
        ;; %define hunk_limit rbx  ;likely keep this in memory
        ;; ^ so much for that


        
        ;; could raise error if arg is rax, but eh
        ;; [or could do something clever]
        %macro cons 1
        lea %1, [ALLOCPTR + CONS_TAG]
        add ALLOCPTR, 16
        cmp ALLOCPTR, PAGELIMIT
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



        ;; Might as well have both the GC library code and the shit that goes at the bottom
        ;; be the 



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
        jmp move_rax


        
        ;; E.g.:
        ;; saving RDI_MASK | RBX_MASK
        ;; cons rcx
        ;; saving RDX_MASK
        ;; cons rsi



        ;; we can use r14 and r15 as we wish.
alloc_overflow_rdi:
        ;; I guess we look at the difference between ALLOCPTR and rdi
        ;; and deduce the desired malloc size.
        push rax                ;will RET later, lel
        ;; rax is now scratch
        ;; rdi may be tagged now.
        ;; we'll likely do gc work.
        
        mov rax, ALLOCPTR
        sub rax, rdi            ;size - tag: btwn size-7 and size
        add rax, 7              ;btwn size and size+7
        and rax, -8             ;size
        and rdi, 7              ;tag
        
        ;; in fact, we have to grab more memory before we do gc work
        ;; the below code is encumbered by the assumption that PAGELIMIT is a memory operand
        mov ALLOCPTR, PAGELIMIT
        mov r15, [page_size]
        add r15, ALLOCPTR
        mov PAGELIMIT, r15
        cmp r15, [tospace_top]  ;would be a GC flip, or would die if both need gc flip and gc work
        jng alloc_overflow_noflip
        call gc_flip
        ;; I guess we trust that to not fuck up rax or rdi
        
        ;; manually move registers; CHEATING (for now) ;the gc_flip itself does that
        ;; ...
alloc_overflow_noflip:
        ;; mov PAGELIMIT, r15 ;YOU DON'T DO THAT IF GC FLIP HAPPENED, THAT'S IDIOTIC
        ;; now we "do gc work"
        ;; [might have to save rdi and whatever]
        ;; [btw, tag and size could be stored in same register, bwahaha]
        nop
        ;; now we do the allocation
        add rdi, ALLOCPTR            ;OR would also work
        add ALLOCPTR, rax
        
        ;; pop rsi
        ret                     ;bwahaha

        
        %macro define_alloc_overflow 1
alloc_overflow_%1:
        push rax
        xchg %1, rdi
        call alloc_overflow_rdi
        xchg %1, rdi
        ret
        %endmacro

        define_alloc_overflow rcx
        


        
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


        ;; closure dickify
        ;; args x, y, z
        ;; saved u
        ;; body
        ;; mov rax, 3
        ;; ret

        ;; closure assify
        ;; args x
        ;; saved y, z
        ;; body
        ;; jmp dickify

        ;; closure nerbify
        ;; args
        ;; saved
        ;; body
        ;; jmp nerbify



        ;; uses rax
        %macro swap 2
        mov rax, %1
        xchg rax, %2
        mov %1, rax
        %endmacro

        ;; also we don't need to care about gc work yet

        ;; So, gc flips are so rare that we can require gc_flip to save
        ;; all registers that are passed to it.
        ;; Other than those that it's supposed to modify, of course.
        
gc_flip:
        push rax

        add qword [gc_flip_count], 1
        
        
        swap [tospace_bottom], [fromspace_bottom]
        swap [tospace_top], [fromspace_top]
        swap [tospace_mask], [fromspace_mask]

        ;; No need for that fromspace_mask_table crap, it's crap.
        
        mov ALLOCPTR, [tospace_bottom]
        mov rax, ALLOCPTR
        add rax, [page_size]
        mov PAGELIMIT, rax

        ;; normally we'd trace some root ptrs
        ;; but there are almost none
        ;; however, there are a few registers.
        ;; which we are cheating at.
        ;; Now...
        ;; There are two places where things are allocated.
        ;; Though the first one is used only at the beginning.
        ;; rcx and rdx probably contain lists.
        ;; rdi was about to be allocated, but contains nothing meaningful.
        ;; And... r8 likely contains ... an integer, never mind that.
        ;; So.
        
        
        mov rax, rcx
        call possibly_move_rax
        mov rcx, rax
        mov rax, rdx
        call possibly_move_rax
        mov rdx, rax
        
gc_flip_done_moving:


        pop rax
        ret


        ;; There are a few ways to deal with moving.
        ;; A couple of different ways to set the high bit
        ;; in the register [or possibly negate it or use some
        ;;  other way of denoting

	;; Ok, so, if bit 63 is set, then it is definitely a negative number.
        %macro fwd_ptr_test 1
        cmp %1, 0
        %endmacro
        ;; these tests end up setting the 0 flag
	;; --Now this test sets ... "less than" signed flags.



        ;; Ok, for this movement shit, we really want some
        ;; free registers.
        ;; Esp. in multithreaded, when we'd grab cdr and then car.
        ;; [With optional memory barrier.]
        ;; [..................... Actually, do you need ......]
        ;; [No, I don't think you need a memory barrier there.]

possibly_move_rax:      
        ptr_test rax
        jz plain_ret
        fromspace_test rax
        jz plain_ret
move_rax:
        ;; Now this depends on the type of thing.
        ;; [Actually, we might use a type dispatch to obviate the ptr test.]
        ;; ... Well, I'm not making jump tables yet, and at the moment
        ;; the only ptr type is a cons.
        ;; So.

mov_rax_cons:
        ;; Check for fwd ptr.
        ;; ... 
        ;; We are appropriating r14 and r15.

        ;; ....
        ;; Dickass considerations here.
        ;; [Multiple ways to do the comparison with diff. performance characteristics.]
        ;; Meh.
        mov r14, [rax - CONS_TAG]
        fwd_ptr_test r14	;sets "less than 0" flags
        jl maybe_lucky
not_lucky:
        ;; must actually move it
        
        lea r15, [ALLOCPTR + CONS_TAG]
        add ALLOCPTR, 16
        ;; now we could ... we must at least compare with the page limit
        cmp ALLOCPTR, PAGELIMIT
        ja grab_moar
        mov [r15 - CONS_TAG], r14
        mov r14, [rax - CONS_TAG + 8]
        mov [r15 - CONS_TAG + 8], r14
        ;; make fwd ptr
        mov r14, r15
        bts r14, 63
        ;; install
        mov [rax - CONS_TAG], r14
        ;; don't use gc stack atm
        mov rax, r15
        ret

maybe_lucky:  
        ptr_test r14
        jz not_lucky
        ;; lucky: is moved.
        btr r14, 63
        mov rax, r14
        ret

        ;; another page.
        ;; we could also check whether we've run out of pages.
        ;; in which case we're way out of memory.
        ;; [but could simply use more with virtual memory]

        ;; meanwhile, 
grab_moar:
        mov ALLOCPTR, PAGELIMIT
        mov r15, [page_size]
        add r15, PAGELIMIT
        cmp r15, [tospace_top]
        ja out_of_memory
        mov PAGELIMIT, r15
        jmp not_lucky
        
out_of_memory:
        mov rax, 666
        ;; mov rax, [gc_flip_count]
        ;; mov rax, r15
        ;; sub rax, [tospace_top]
        ;; add rax, [tospace_bottom]
        ;; sub rax, [tospace_top]
        
        jmp return
        ;; oh dear, we're hitting this a lot atm
        ;; when we should not




        ;; The following two tables are for a certain method of
        ;; testing stuff...
        ;; Often you have to test whether something is a pointer and whether
        ;; it matches a certain mask.
        ;; 
        align 8
fwd_mask_table:
        dq 0
        dq 1 << 63
        dq 1 << 63
        dq 1 << 63
        dq 0
        dq 1 << 63
        dq 1 << 63
        dq 1 << 63

gc_flip_count:
        dq 0









        
        
        ;; [By the way, car and cdr are a little different.
        ;;  The cdr, whether it holds a cons or nil, will
        ;;  almost always be a pointer.
        ;;  The car is far more likely to be either a fixnum
        ;;  or a character.]

        ;; Ok, listing out methods.

        ;; There are two semi-orthogonal things here.
        ;; One is the type-checking.
        ;; The other is the barrier.

        ;; I don't know how many registers I might want to use,
        ;; or might have available, or what.
        ;; So let's assume I have everything.
        ;; Then, if I discover that they're all eqv,
        ;; I can choose the one that uses fewest registers/is most
        ;; convenient about its use.

        ;; So, since I'll probably generally want to leave a couple
        ;; of registers usable for the moving crap,
        ;; I probably don't really have a problem with register usage in
        ;; these things.


        ;; Choices...
        ;; - The type check can be done with either "lea reg, [%2 - CONS_TAG]; test reg, 7"
        ;;   or something like "mov reg, %2; and reg, 7; cmp reg, CONS_TAG".
        ;; - The order of "fromspace_test" and "ptr_test" can be swapped.
        ;;   Logically, "fromspace_test" should go first in cdr, and seems reasonably
        ;;   likely it should go first in car as well.
        ;;   Not testing this atm.  (Using a bunch of lists of high or negative fixnums
        ;;    would be the case in which it sucked.  --I guess I could test a bit.)
        ;; - The call to the "move" thing can either be accomplished with a "call"
        ;;   that you normally jump across, or with a "lea reg, [return_addr]" followed
        ;;   by a conditional jump.
        ;; - The fromspace-ptr tests could be combined into a memory-operation-requiring
        ;;   thing: "mov reg, %1; and reg, 7; test %1, [fromspace_mask_table + 8*reg]".
        ;;   This was determined to be terribly expensive and bad.
        ;; - The 

        ;; All of these may wreck rax and shouldn't take it as args.

        ;; Removing excess.

        ;; By the way, one could have fromspace_mask *usually* stored in one of the
        ;; r14 or r15 registers that we'll probably reserve for read barrier moving shit.
        ;; Then movements could restore that if they destroy it.
        ;; Eh.
        
        
        ;; Cutting out that lea for the type check.
        ;; (Again, below shit could use smaller...)
        %macro car 2
        mov rax, %2
        and al, 7
        cmp al, CONS_TAG
        jne type_error
        mov %1, [%2 - CONS_TAG]
        fromspace_test %1
        jz %%win
        ptr_test %1
        jz %%win
        ;; ... dicks ... just try this
        call move_%1_car_%2
%%win:
        %endmacro
        ;; For direct comparison

        ;; Alternate.
;;         %macro car_5 2
;;         mov rax, %2
;;         and al, 7
;;         cmp al, CONS_TAG
;;         jne type_error
;;         mov %1, [%2 - CONS_TAG]
;;         fromspace_test %1
;;         jz %%win
;;         ptr_test %1
;;         jz %%win
;;         lea r15, [%2 - CONS_TAG]
;;         call move_%1_at_r15
;; %%win:
;;         %endmacro


        
        ;; Cutting out that lea for the type check.
        ;; (Again, below shit could use smaller...)
        %macro cdr 2
        mov rax, %2
        and al, 7
        cmp al, CONS_TAG
        jne type_error
        mov %1, [%2 - CONS_TAG + 8]
        fromspace_test %1
        jz %%win
        ptr_test %1
        jz %%win
        call move_%1_cdr_%2
%%win:
        %endmacro

        ;; Alternate.
;;         %macro cdr_5 2
;;         mov rax, %2
;;         and al, 7
;;         cmp al, CONS_TAG
;;         jne type_error
;;         mov %1, [%2 - CONS_TAG + 8]
;;         fromspace_test %1
;;         jz %%win
;;         ptr_test %1
;;         jz %%win
;;         lea r15, [%2 - CONS_TAG + 8]
;;         call move_%1_at_r15
;; %%win:
;;         %endmacro



type_error:
        mov rax, 51
        jmp return


move_rax_at_r15:
        push r15                ;lel, prob. fix later
        call move_rax
        pop r15
        mov [r15], rax
        ret

move_r8_at_r15:
        push r15
        xchg rax, r8
        call move_rax
        pop r15
        mov [r15], rax
        xchg rax, r8
        ret

move_rcx_at_r15:
        ;; jmp return
        push r15
        xchg rax, rcx
        call move_rax
        pop r15
        mov [r15], rax
        xchg rax, rcx
        ret

        
move_r8_car_rcx:        
        xchg rax, r8
        call move_rax
        xchg rax, r8
        scdr rcx, r8
        ret

move_rcx_cdr_r13:
        xchg rax, rcx
        call move_rax
        xchg rax, rcx
        scdr r13, rcx
        ret        
                
        
        

        


        %macro gc_footer 0
        

startup_sequence:
        
        mov qword [gc_flip_count], 0

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
        
        

        %endmacro
                

        


        











        
