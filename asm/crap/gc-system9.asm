

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


        ;; This iteration.
        ;; 1. "move" things should not trigger GC work.
        ;; 2. Specifically, they should ignore the fuck out of the PAGELIMIT thing,
        ;;    but respect the [tospace_top] thing.
        ;; 3. Consequently, ALLOCPTR may be way ahead of PAGELIMIT at times.
        ;;    In that case, resetting ALLOCPTR to PAGELIMIT would be disastrous, and
        ;;    is likely a bug in a previous version.
        ;;    Instead, when the next main-allocation overflow happens,
        ;;    ALLOCPTR should be backed up to where it was,
        ;;    and PAGELIMIT should be set to that plus [page_size].
        ;;    (After some GC work probably happens.)



        ;; Relying on semispaces4.asm now.        

        %macro gc_header 0
        call startup_sequence
        %endmacro
        

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


        ;; This shit really belongs in here...
        
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

        %define CONS_TAG 3
        %define CLOS_TAG 5

        ;; Let's say that ints are 000 and chars are 100.
        ;; Then the ptr mask is 011.
        %macro ptr_test 1
        test %1, 3
        %endmacro
        ;; Doesn't include ptr test.
        %macro fromspace_test 1
        test %1, FROMSPACEMASK
        %endmacro
        ;; these actually have to return their result in RFLAGS
        ;; because you might want to "jump if" or "jump if not"
        

        ;; These I can define here, may as well.
        ;; --They will move qwords.  Convenient.
        %macro scar 2
        mov qword [%1 - CONS_TAG], %2
        %endmacro
        %macro scdr 2
        mov qword [%1 - CONS_TAG + 8], %2
        %endmacro


        %define CONT_REG rbp    ;why not; similar sort of role
        ;; in multithreaded, rbx should hold a bunch of shit
        ;; but for now, let's use it thus.

        %define GC_SCRATCH r15
        %define GC_SCRATCH_2 r14

        ;; %define FROMSPACEMASK r11 ;just for test
        %define FROMSPACEMASK r13 ;better, doesn't get destroyed by C calls
        ;; %define FROMSPACEMASK [fromspace_mask]

        %define ALLOCPTR rbx
        ;; %define page_limit qword [page_alloc_ptr] ;sigh, whatever
        ;; %define PAGELIMIT qword [page_alloc_ptr]  ;jesus
        %define PAGELIMIT r12   ;swap these out for testing


        ;; Ok, I get a 10% improvement in performance putting FROMSPACEMASK
        ;; in a register.
        ;; But putting PAGELIMIT in a register seems significantly less important.
        ;; (This is for a program that does two c[ad]rs for every malloc, of course.)
        ;; Anyway.

        
        ;; Generally I'll try to follow the C calling convention,
        ;; methinks... ... really?
        ;; Well, meh.
        ;; We'll see.

        ;; We need the gc_flip to move some global variables.
        ;; Which will be defined by the user program.
        ;; Therefore, gc_flip must be defined in the footer.
        ;; And.

        %define gced_variable_count 0

        %macro VAR 1
        %assign gced_variable_count gced_variable_count+1
%1:     dq 0
        %define gced_variable_%[gced_variable_count] %1
        %endmacro

        


        
        %define alloc_count 0           ;hope this works...
        ;; terminology: slice, hunk, lump...
        ;; ^ so much for that


        
        ;; could raise error if arg is rax, but eh
        ;; [or could do something clever]
        %macro cons 1
        lea %1, [ALLOCPTR + CONS_TAG]
        add ALLOCPTR, 16
        cmp ALLOCPTR, PAGELIMIT
        lea r15, [alloc_return_%[alloc_count]]
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
        mov rax, 999
        jmp return
        ;; jmp move_rax


        
        ;; E.g.:
        ;; saving RDI_MASK | RBX_MASK
        ;; cons rcx
        ;; saving RDX_MASK
        ;; cons rsi



;;         ;; we can use r14 and r15 as we wish.
;;         ;; also, for the moment, we're wrecking rax.
;;         ;; and assuming rdi has the alloc thing.
;; alloc_overflow_rdi:
;;         ;; I guess we look at the difference between ALLOCPTR and rdi
;;         ;; and deduce the desired malloc size.
;;         ;; push rax                ;will RET later, lel
;;         push r15


;;         ;; So, we are passed the return address from this subroutine on the stack,
;;         ;; and, if necessary, the address gc_flip uses to determine register usage
;;         ;; in ...
;;         ;; In r15.  That be decided.

;;         ;; [An alternative would be to search the stack for the first return address
;;         ;;  that has an entry in the saved_regs table.  Suck; integers can impersonate
;;         ;;  return addresses and shit.]

        

        ;; better not be either rax or r15
        %macro define_alloc_overflow 1
alloc_overflow_%1:      
        push r15
%%again:
        ;; Ok, so.
        ;; It's possible for ALLOCPTR to be way ahead of PAGELIMIT, due to "move"
        ;; operations.
        ;; Consequently--and this should have been done anyway, though with all
        ;; objects the same size and a divisor of the page size, it hadn't made
        ;; a difference--we should instead roll back ALLOCPTR to what it was,
        ;; then set PAGELIMIT to be something greater than that.

        ;; mov rax, ALLOCPTR
        ;; xchg ALLOCPTR, %1
        ;; and rax, 7              ;tag
        ;; and ALLOCPTR, -8        ;old location
        ;; sub %1, ALLOCPTR        ;size
        ;; ;; note that we've switched the roles of rax and %1 compared to before
        ;; ;; ... that's stupid, there was a point in having the tag be in %1
        
        
        
        mov rax, ALLOCPTR
        sub rax, %1            ;size - tag: btwn size-7 and size
        add rax, 7              ;btwn size and size+7
        and rax, -8             ;size
        and %1, 7              ;tag
        sub ALLOCPTR, rax      ;pre-alloc value


        ;; Ok, now.
        ;; If tracing is still happening [will be: [gc_stack] /= 0],
        ;; then we call a subroutine that grabs memory, does gc work,
        ;; and comes back with a full page. [....... misgivings about this combined
        ;;  with large allocations that might be larger than a "full page"]
        ;; [also it wouldn't be a full page, probably rounded up to up to twice that]
        ;; [oh well, proceed for now]
        ;; Otherwise, we try to grab a page, and gc-flip if overflow.

        ;; Test if tracing is still happening.
        ;; Currently no gc stack, so:
        mov r15, [bytes_moved]
        cmp r15, [bytes_traced]
        jg %%work
        ;; No gc work to do here, just grab a page.
        ;; Which we do thus:
        mov r15, [page_size]
        add r15, ALLOCPTR
        mov PAGELIMIT, r15
        cmp r15, [tospace_top]
        ja %%flip
        ;; got our shit
        add %1, ALLOCPTR
        add ALLOCPTR, rax
        ret
%%flip:
        ;; gc_flip still wants dick in r15
        mov r15, [rsp]
        call gc_flip
        ;; and ... yes, let's do GC work right after the GC flip, and then get
        ;; what we want.
%%work:
        call work_and_grab_page
        ;; it should preserve rax and %1
        add %1, ALLOCPTR        ;tag
        add ALLOCPTR, rax       ;size
        cmp ALLOCPTR, PAGELIMIT
        ja complain_to_the_management
        cmp ALLOCPTR, [tospace_top]
        ja complain_to_the_management
        ret
        
        %endmacro
        
        
;;         ;; in fact, we have to grab more memory before we do gc work
;;         ;; the below code is encumbered by the assumption that PAGELIMIT is a memory operand
;;         mov ALLOCPTR, PAGELIMIT
;;         mov r15, [page_size]
;;         add r15, ALLOCPTR
;;         mov PAGELIMIT, r15
;;         cmp r15, [tospace_top]  ;would be a GC flip, or would die if both need gc flip and gc work
;;         jng alloc_overflow_%1_noflip
;;         mov r15, [rsp]          ;used to compute el dicko
;;         call gc_flip
;;         ;; I guess we trust that to not fuck up rax or rdi
;; alloc_overflow_%1_noflip:
;;         ;; now we "do gc work"
;;         ;; [might have to save rdi and whatever]
;;         ;; [btw, tag and size could be stored in same register, bwahaha]
;;         ;; nop
;;         call do_gc_work
;;         ;; now we do the allocation
;;         ;; actually, at this point, we can't be sure it will fit
;;         ;; so.
;;         ;; .....
;;         ;; geez, it would be inappropriate if the gc work kept giving you a 99% full page.
;;         ;; in fact, it should guarantee 
;;         add %1, ALLOCPTR            ;OR would also work
;;         add ALLOCPTR, rax
;;         cmp ALLOCPTR, PAGELIMIT
;;         ja %%again
        
;;         ret                     ;bwahaha
        ;; %endmacro

        define_alloc_overflow rcx
        define_alloc_overflow rdi

complain_to_the_management:

        mov rax, 66666
        jmp return
        


        
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


        ;; uses rax



        ;; In case these are desired
        %macro cheap_car 2
        mov %1, [%2 - CONS_TAG]
        %endmacro
        %macro cheap_cdr 2
        mov %1, [%2 - CONS_TAG + 8]
        %endmacro
        


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


        ;; .........
        ;; It is more sensible to "move rdi" or something.
        ;; Something that isn't a "scratch register".
        ;; Sometimes it'll actually be that, and if not,
        ;; we'll still have another register to work with.

        ;; On the other hand, I will have to be careful about bugs.
        ;; If I don't handle the registers properly, probably some
        ;; cons cell will end up being some other cons cell,
        ;; with possibly weird consequences.

        
        ;; Ok, for this movement shit, we really want some
        ;; free registers.
        ;; Esp. in multithreaded, when we'd grab cdr and then car.
        ;; [With optional memory barrier.]
        ;; [..................... Actually, do you need ......]
        ;; [No, I don't think you need a memory barrier there.]
possibly_move_rdi:      
        ptr_test rdi
        jz plain_ret
        fromspace_test rdi
        jz plain_ret
        ;; Our customer here is gc_flip.
        ;; So.
        ;; We'll want to save r15.
        ;; --Nah.
        ;; push r15
        ;; call move_rdi
        ;; ret
        
move_rdi:
        ;; Now this depends on the type of thing.
        ;; [Actually, we might use a type dispatch to obviate the ptr test.]
        ;; ... Well, I'm not making jump tables yet, and at the moment
        ;; the only ptr type is a cons.
        ;; So.

mov_rdi_cons:
        ;; Check for fwd ptr.
        ;; ... 
        ;; We are appropriating r14 and r15.

        ;; ....
        ;; Dickass considerations here.
        ;; [Multiple ways to do the comparison with diff. performance characteristics.]
        ;; Meh.
        mov r14, [rdi - CONS_TAG]
        fwd_ptr_test r14	;sets "less than 0" flags
        jl maybe_lucky
not_lucky:
        ;; must actually move it
        add qword [moved_count], 1
        add qword [bytes_moved], 16
        
        lea r15, [ALLOCPTR + CONS_TAG]
        add ALLOCPTR, 16
        ;; now we could ... we must at least compare with the page limit
        ;; cmp ALLOCPTR, PAGELIMIT
        ;; ja grab_moar
        cmp ALLOCPTR, [tospace_top]
        ja out_of_memory
        ;; in multithreaded, that'd be comparing with a real page limit (vs a gc work-trigger limit)
        ;; and might actually have to grab another page
        mov [r15 - CONS_TAG], r14
        mov r14, [rdi - CONS_TAG + 8]
        mov [r15 - CONS_TAG + 8], r14
        ;; make fwd ptr
        mov r14, r15
        bts r14, 63
        ;; install
        mov [rdi - CONS_TAG], r14
        ;; don't use gc stack atm
        ;; however, just to be sure... [hard mode]
        ;; let's destroy the cdr.
        mov qword [rdi - CONS_TAG + 8], 0
        mov rdi, r15
        ret

maybe_lucky:  
        ptr_test r14
        jz not_lucky
        ;; lucky: is moved.
        btr r14, 63
        mov rdi, r14
        ret

        ;; another page.
        ;; we could also check whether we've run out of pages.
        ;; in which case we're way out of memory.
        ;; [but could simply use more with virtual memory]

        ;; ok, so.
        ;; now we will ...
        ;; make use of "work-and-grab-page".

;; grab_moar:
;;         call work_and_grab_page
;;         ;; we should have a nice page
;;         ;; and the above should already have checked if
;;         ;; we're out of memory
;;         jmp not_lucky
        ;; unused now
        
out_of_memory:
        mov rax, 666
        ;; mov rax, [gc_flip_count]
        ;; mov rax, r15
        ;; sub rax, [tospace_top]
        ;; add rax, [tospace_bottom]
        ;; sub rax, [tospace_top]

        mov rax, [fromspace_mask]
        sub rax, FROMSPACEMASK
        
        jmp return


        ;; Ok, so...
        ;; It should be true that someone who's just hitting read barriers
        ;; a bunch should not have to do GC work as well.
        ;; Basically.
        ;; But anyway...
        ;; I think the notions of "pages grabbed by a [possibly solitary] thread"
        ;; and "GC work trigger" are going to have to be decoupled.
        ;; In multithreaded, a thread will grab a chunk of memory that should perhaps
        ;; be somewhat larger than the granularity of its GC work schedule.
        ;; (If there even is one, rather than having some threads do pure GC.)
        ;; In single-threaded, there is just one real "page": [tospace_bottom] through
        ;; [tospace_top], or perhaps just 80% of that.
        ;; (Well, really, that would be a GC stuff trigger chosen after GC work was
        ;;  finished... and the "move" stuff shouldn't interact at all with that.)
        ;; Ok, well, time to rearchitect a bit...




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
moved_count:
        dq 0
bytes_moved:
        dq 0
bytes_traced:
        dq 0
work_count:
        dq 0



work_and_grab_page:
        ;; So.
        ;; We can destroy r15 and probably rax.
        ;; But at the moment, there isn't really a need to.

        ;; We come here with a probably empty page.
        ;; mov ALLOCPTR, PAGELIMIT
        ;; Actually, ALLOCPTR may be way ahead of PAGELIMIT, and,
        ;; given that:
        mov r15, [page_size]
        add r15, ALLOCPTR
        mov PAGELIMIT, r15
        cmp r15, [tospace_top]
        ja out_of_memory

        ;; Now we "do gc work".
        

        ;; Start with shit that does basically nothing.
do_gc_work:

        add qword [work_count], 1

        push rax
        push rdi
        ;; mov rax, [moved_count]
        ;; shl rax, 6              ;* 16, * 4
        mov rax, ALLOCPTR
        sub rax, [tospace_bottom] ;bytes alloced
        sub rax, [bytes_moved]    ;bytes freshly alloced
        shl rax, 2                ;[fresh bytes] * [4 = gc work factor]
        
        ;; that's the maximum amount of work we would want done in total.
        ;; [we would do the difference between current bytes_traced and it]
        ;; however, there may be fewer than that number of bytes to trace.
        ;; so.
        cmp rax, [bytes_moved]
        cmovg rax, [bytes_moved]

        mov [bytes_traced], rax

        
        pop rdi
        pop rax

        ;; At the end, we should maybe ensure we have a good-size page...
        ;; Since the above doesn't move the ALLOCPTR, we needn't do anything
        ;; here right now.
        
        ret






        
        
        ;; [By the way, car and cdr are a little different.
        ;;  The cdr, whether it holds a cons or nil, will
        ;;  almost always be a pointer.
        ;;  The car is far more likely to be either a fixnum
        ;;  or a character.]

        ;; I don't know how many registers I might want to use,
        ;; or might have available, or what.

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
;;         %macro car 2
;;         mov rax, %2
;;         and al, 7
;;         cmp al, CONS_TAG
;;         jne type_error
;;         mov %1, [%2 - CONS_TAG]
;;         fromspace_test %1
;;         jz %%win
;;         ptr_test %1
;;         jz %%win
;;         ;; ... dicks ... just try this
;;         call move_%1_car_%2
;; %%win:
;;         %endmacro

        ;; Somewhat bizarrely, the below is outperforming the above.
        ;; Well, it's more convenient, at any rate.

        ;; Alternate.
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
        lea r15, [%2 - CONS_TAG]
        call move_%1_at_r15
%%win:
        %endmacro


        
        ;; Cutting out that lea for the type check.
        ;; (Again, below shit could use smaller...)
        ;; %macro cdr 2
;;         mov rax, %2
;;         and al, 7
;;         cmp al, CONS_TAG
;;         jne type_error
;;         mov %1, [%2 - CONS_TAG + 8]
;;         fromspace_test %1
;;         jz %%win
;;         ptr_test %1
;;         jz %%win
;;         call move_%1_cdr_%2
;; %%win:
;;         %endmacro

        ;; Alternate.
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
        lea r15, [%2 - CONS_TAG + 8]
        call move_%1_at_r15
%%win:
        %endmacro



type_error:
        mov rax, 51
        jmp return


        %macro define_move_at_r15 1
move_%1_at_r15:
        push r15
        xchg rdi, %1
        call move_rdi
        pop r15
        mov [r15], rdi
        xchg rdi, %1
        ret
        %endmacro


move_rdi_at_r15:
        push r15                ;lel, prob. fix later
        call move_rdi
        pop r15
        mov [r15], rdi
        ret

        define_move_at_r15 r8
        define_move_at_r15 rcx


;;         %macro define_move_car 2
;; move_%1_car_%2:
;;         %ifnidn rdi, %1
;;         xchg rdi, %1
;;         %endif
;;         call move_rdi
;;         scar %2, rdi
;;         %ifnidn rdi, %1
;;         xchg rdi, %1
;;         %endif
;;         ret
;;         %endmacro

;;         %macro define_move_cdr 2
;; move_%1_cdr_%2:
;;         %ifnidn rdi, %1
;;         xchg rdi, %1
;;         %endif
        
;;         call move_rdi
;;         scdr %2, rdi
        
;;         %ifnidn rdi, %1
;;         xchg rdi, %1
;;         %endif
        
;;         ret
;;         %endmacro        

;;         define_move_car r8, rcx
;;         define_move_cdr rcx, r13
        
        

        


        %macro gc_footer 0
        

startup_sequence:
        
        mov qword [gc_flip_count], 0
        mov qword [moved_count], 0
        mov qword [bytes_moved], 0
        mov qword [bytes_traced], 0
        mov qword [work_count], 0
        ;; all that crap should be handled with macros

        %ifnidn FROMSPACEMASK, [fromspace_mask]
        mov FROMSPACEMASK, [fromspace_mask]
        %endif

        ;; %ifnidn PAGELIMIT, [page_limit]
        ;; mov PAGELIMIT, [page_limit]
        ;; %endif

        mov ALLOCPTR, [tospace_bottom]
        mov rdi, [page_size]
        add rdi, ALLOCPTR
        mov PAGELIMIT, rdi
        ;; don't know why I do the below; currently make no use of [page_limit] if
        ;; it's not PAGELIMIT
        %ifnidn PAGELIMIT, [page_limit]
        mov [page_limit], PAGELIMIT
        %endif
        


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


plain_ret:      ret

        ;; this better be aligned
        align 8
saved_regs:
        ;; resq n*2
        ;; Non-warning:
        %rep alloc_count*2
        dq 0
        %endrep
        ;; lel



        %macro swap 2
        mov rax, %1
        xchg rax, %2
        mov %1, rax
        %endmacro

        ;; also we don't need to care about gc work yet

        ;; So, gc flips are so rare that we can require gc_flip to save
        ;; all registers that are passed to it.
        ;; Other than those that it's supposed to modify, of course.
        ;; Ok, so...

        ;; Well, it will 

        ;; r15 contains our "return address" thing.
        ;; Not necessarily the same thing as what overflow_common will
        ;; return to, for alloc_overflow_[not rdi].
gc_flip:
        ;; On principle, I'll leave rax as is. ;TURNED OUT TO BE A GOOD IDEA
        push rax

        add qword [gc_flip_count], 1
        mov qword [bytes_traced], 0
        mov qword [bytes_moved], 0
        
        
        swap [tospace_bottom], [fromspace_bottom]
        swap [tospace_top], [fromspace_top]
        swap [tospace_mask], [fromspace_mask]
        ;; beheheh
        mov rax, [fromspace_mask]
        mov FROMSPACEMASK, rax

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

        ;; At this point, we stop cheating.

        ;; Ok, so.
        ;; We need to be tightly coupled to the "overflow" things.
        ;; We need to know ........
        ;; Neh, treating this as a subroutine leads to [fear, fear leads to anger].
        ;; gc_flip wants to be passed the "return address" as an argument.
        ;; It doesn't actually return to that after that.
        ;; Consequently, the common "overflow" thing wants to be passed the "return address"
        ;; as an argument.
        ;; ... In general that might do GC work, so it doesn't need to be too fast.

        push rdi

        ;; r15 contains our address thing.
        ;; find_saved_regs wants rdi as the argument
        ;; and destroys rsi and rcx.
        ;; Ok, make it take and return r15, instead.
        push rsi
        push rcx
        call find_saved_regs
        
        pop rcx
        pop rsi

        ;; First we have to determine the saved registers.
        ;; That'll be above.
        ;; Then we have to move the used registers.
        ;; So.
        ;; Next, this possibly_move_rdi thing...
        ;; It destroys, at the moment: r14 and r15.
        ;; Very well, we shall put our list of masks in rax.
        mov rax, r15
        ;; So, at the moment, the stack looks like:
        ;; rsp=[rdi][rax]...  (rdi, rax = the values before gc flip)
        ;; Now, in all likelihood, rdi is .......
        ;; Very interesting.
        ;; Ok, suppose someone has used an "alloc into [non-rdi, say rsi]" thing,
        ;; which led to this.  With RDI_MASK possibly saved.
        ;; rsi better not be saved, else the user is an idiot.
        ;; Anyway, currently, in that case...
        ;; The old contents of rdi would have been xchg'd into rsi.
        ;; --Ok, changed the dicks, so now this should work fine.

        ;; Delightfully, this works on memory addresses too.
        %macro maybe_move 2
        test rax, %2
        jz %%nope
        mov rdi, %1
        call possibly_move_rdi
        mov %1, rdi
%%nope:
        %endmacro

        maybe_move [rsp + 8], RAX_MASK
        ;; rbx is currently ALLOCPTR
        test rax, RBX_MASK
        jnz dont_save_these_regs
        maybe_move rcx, RCX_MASK
        maybe_move rdx, RDX_MASK
        maybe_move [rsp], RDI_MASK
        maybe_move rsi, RSI_MASK
        test rax, RSP_MASK
        jnz dont_save_these_regs
        maybe_move rbp, RBP_MASK

        maybe_move r8, R8_MASK
        maybe_move r9, R9_MASK
        maybe_move r10, R10_MASK
        maybe_move r11, R11_MASK
        maybe_move r12, R12_MASK
        maybe_move r13, R13_MASK
        maybe_move r14, R14_MASK
        test rax, R15_MASK
        jnz dont_save_these_regs


        ;; The next things to do would be to move items on the stack that aren't return addresses,
        ;; and to move global variables.
        ;; Now we do both.

        ;; Ok, now we're going to move items on the stack.
        ;; Procedure:
        ;; Check that it has the low bits of a pointer,
        ;; check that it matches the fromspace mask,
        ;; and check that it's between [fromspace_bottom] and [fromspace_top].
        ;; Actually, the third obviates the second.
        ;; We inspect shit between ...
        ;; Well, stack is currently rsp=[rdi][rax][other crap]....
        ;; If RDI_MASK and RAX_MASK haven't been set, we should avoid tracing those.
        ;; So we will start at rsp+16 and move up until we hit the address that is
        ;; saved in [stack_ptr].
        ;; That address ... we shouldn't touch.
        ;; Very well.

        push rsi
        ;; now remember to avoid that: we actually start at rsp+24 now
        ;; lea rsi, [rsp + 24]
        ;; Since this is called with "call gc_flip", there's at least one thing in between.
        ;; ...
        ;; Actually, ok, we'll do it this way.

        lea rsi, [rsp + 24]
        
trace_stack:
        mov rdi, [rsi]
        ptr_test rdi
        jz trace_stack_next
        cmp rdi, [fromspace_bottom]
        jb trace_stack_next
        cmp rdi, [fromspace_top]
        jnb trace_stack_next
        ;; now we move and update the ptr
        call move_rdi
        mov [rsi], rdi

trace_stack_next:       
        add rsi, 8
        cmp rsi, [stack_ptr]
        jb trace_stack

        pop rsi        


        ;; Now we trace global variables.

        %define i 0
        %rep gced_variable_count
        %assign i i+1
        mov rdi, [gced_variable_%[i]]
        call possibly_move_rdi
        mov [gced_variable_%[i]], rdi
        %endrep
        
        
        

        ;; Oh man, done moving.
        

        pop rdi
        pop rax
        ret

dont_save_these_regs:
        ;; rax has the list
        jmp return



        

        ;; Argument in ... rdi. --No, r15.
        ;; Return: carry flag holds dick,
        ;;    and the return value (a mask) is in ... rdi.
        ;; ... I'm not entirely sure that the addresses will be in the correct order.
        ;; Validate that later.
        ;; For now, rely on linear search.
find_saved_regs:
        %if alloc_count = 0
        stc
        ret
        %endif
        
        lea rsi, [saved_regs]
        mov rcx, alloc_count
find_saved_regs_loop:
        cmp r15, [rsi]
        je find_saved_regs_win
        add rsi, 16
        dec rcx
        jnz find_saved_regs_loop
        stc
        ret

find_saved_regs_win:
        ;; an equal comparison should have carry flag be 0
        mov r15, [rsi + 8]
        ;; but just in case
        clc
        ret

        %endmacro
                

        
        ;; Ok.
        ;; The next step is to schedule GC work.
        ;; Now.
        ;; This shit will happen at the alloc_overflow phases.
        ;; And conceivably also at the "grab_moar" things, when you're
        ;; moving an object and you overflow.
        ;; Now...
        ;; 1. One naive scheme would be to do GC work at alloc_overflow,
        ;;    but not at grab_moar.  This has the problem that if you
        ;;    repeatedly allocate 4080 bytes, then move a cons cell,
        ;;    you'll not do any GC work for a long time, and then get a
        ;;    large backlog, which will probably break real-time constraints.
        ;; 2. Doing GC work unconditionally at grab_moar likely leads to
        ;;    doing all the tracing at once.
        ;; 3. I'm not exactly sure what real-time constraints might be, but
        ;;    I suspect tracing 16K bytes of data at a time is ok.  If not,
        ;;    that can certainly be reduced.
        ;; 4. In multithreaded, there will be a serious need to have threads
        ;;    grab "pages" of memory at a time, and not go outside those pages.
        ;;    However, the "PAGELIMIT" pointer need not be the actual size of
        ;;    those pages; e.g. they could grab 100K at a time, but the PAGELIMIT
        ;;    ensure that they take a GC break every 2K or 4K bytes.
        ;;    (But actually, in multithreaded, most of the time you probably want
        ;;     dedicated GC threads to do most of the GC work, and main execution
        ;;     threads only join GC work when that has fallen relatively behind.)
        ;; 5. The GC system probably needs to keep track of the progress it's making.
        ;;    In particular, a general idea is to make (# bytes traced) >= 4*(# bytes newly alloc'd).

        ;; - An option is to have "move" allocate its shit somewhere else
        ;;   than "next place in front of ALLOCPTR".  Options include a separate alloc area,
        ;;   and an adaptation of Henry Baker's idea, in which I'd alloc down from PAGELIMIT.
        ;;   That would probably be the most efficient (and might be good for locality), though
        ;;   I might actually want to reserve a register for PAGELIMIT if I did that.
        ;; - Another is to just increment a score counter (prob. in memory) every time you
        ;;   move something.  I think I'll do this. ....... Then the grab_moar thing can
        ;;   check the "moved vs alloced" score.
        











        
