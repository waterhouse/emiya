
        DEFAULT REL
        

        %define ALLOCPTR r15
        %define GLOBVEC r14
        %define CONT r13
        %define DYN r12
        %define CLOS rbx
        %define ENV r11
        %define SCRATCH r10


        ;; fixnum tag is 000. built-in as fuck.
        %define CONS_TAG 0b001
        %define TABLE_TAG 0b010
        %define VEC_TAG 0b011
        %define CHAR_TAG 0b100
        %define USER_TAG 0b101
        %define SYM_TAG 0b110
        %define CLOS_TAG 0b111

        ;; this matches all tags but fixnum and character
        %define PTR_MASK 0b011

        ;; oh boy
        %define FROMSPACE_MASK [GLOBVEC + n] ;more precise later
        %define TOSPACE_TOP [GLOBVEC + n]
        

        ;; this is unchecked
        %macro CAR_INTO 2
        mov %2, [%1 - CONS_TAG]
        READ_BARR %2
        %endmacro

        %macro CDR_INTO 2
        mov %2, [%1 - CONS_TAG + 8]
        READ_BARR %2
        %endmacro
        



        ;; ok, so,
        ;; it should probably in fact be possible to have a
        ;; FROMSPACE_OR_PTR_MASK.
        ;; ...
        ;; um...
        ;; an integer is xxxxxxx000.
        ;; a character wd be xxxxx100.
        ;; a pointer can be kkxxxxx0yy.
        ;; ...
        ;; nope... ish...
        ;; 

        ;; given tag
        ;; 
;;         %macro BARR_TAG 2
;;         test %2, FROMSPACE_MASK
;;         jz %%dont
;;         test %1, PTR_MASK
;;         jz %%dont
;;         ;; call MOVE_
;;         ;; I need up to 16 of those functions, and I need this macro to
;;         ;; expand to the right one...
;;         call move_%1
;; %%dont:   

;;         %endmacro

        ;; ^ idiot, you can do that testing on the reg itself.

        %macro READ_BARR 1
        test %1, FROMSPACE_MASK
        jz %%dont
        test %1, PTR_MASK
        jz %%dont
        call move_%1
%%dont:
        %endmacro

        %macro READ_BARR_PROB_NONPTR 1
        test %1, PTR_MASK
        jz %%dont
        test %1, FROMSPACE_MASK
        jz %%dont
        call move_%1
%%dont:
        %endmacro




        ;; integers = 000.
        ;; chars should be either 100, 010, or 001
        ;; so that testing for ptr-ness is easy: test x, 011 [binary].
        ;; as for tospace and fromspace...
        ;; hmm... damn...
        ;; [and immovable space]
        ;; 




        ;; eval is exposed to the public
        ;; ... well...
        ;; ... certainly code-chunks that appear in continuation-closures
        ;; will be exposed to the public.
        ;; though that ain't saying much.
        ;; ... in fact, I can use whatever the fuck calling conv. I like, and the
        ;; continuation-closure-code-chunks can just mov args into the right
        ;; registers.

        ;; rdi = x
eval:
        mov SCRATCH, 0b111
        and SCRATCH, rdi
        cmp SCRATCH, SYM_TAG
        je lookup
        cmp SCRATCH, CONS_TAG
        jne eval_ucall

        ;; this is how you call a closure
        mov rax, rdi
        mov CLOS, CONT
        jmp [CONT - CLOS_TAG]

eval_ucall:     

        CDR_INTO rdi, rsi
        CAR_INTO rdi, rdi
        ;; oh my fucking god now
        ;; we allocate a continuation...
        ;; which saves cdr.x, d, e, k.
        ;; and in case this allocation causes a gc flip,
        ;; we will have to ensure car.x gets moved...
        ;; in the full multithreaded thing, we would have to assume
        ;; "this thread may not get to execute at all"
        ;; and everything would have to get tagged somehow...

        ;; however, this being single-threaded,
        ;; we can just read-barr car.x afterward.
        ;; ... no, that's several lines of extra code.
        ;; we should probably put dicks in, say, rax to indicate which
        ;; registers contain useful values. yeah.
        ;; bits.
        ;; [a more advanced technique is to have that shit in a table smwhr]
        ;; in that case, the alloc fn should just return a block of memory
        ;; without putting dicks in it.
        ;; ... the other choice is to inline the allocation.
        ;; which may be appropriate.
        ;; --well, this is eval, probably in its most common case,
        ;; so it damn well is appropriate.

eval_ucall_retry_alloc: 

        ;; sooo not multithreaded...
        mov rax, ALLOCPTR
        add ALLOCPTR, 40        ;code, cdr.x, d, e, k
        cmp rax, TOSPACE_TOP
        jnl eval_ucall_gc_flip  ;assuming signed? ... yes, shdn't mk diff...

        ;; btw, it would be slightly good if I used scratches that were
        ;; not extended registers, although 64-bit ops on usual regs will
        ;; also have an extra byte... but the common case of moving 7
        ;; into a reg is applicable. but for now, oh well.

        lea SCRATCH, [eval_k1]
        mov [rax + 32], CONT
        mov [rax + 24], ENV
        mov [rax + 16], DYN
        lea CONT, [rax + CLOS_TAG] ;yep, this is in fact the shortest
        mov [rax + 8], rsi
        mov [rax], SCRATCH

        ;; ENV and DYN are identical to before...
        ;; CONT is new and x is new.
        jmp eval

        ;; we shall use bits to indicate what regs are in use.
        ;; --and yes, it looks like nasm can do this.
eval_ucall_gc_flip:
        mov rax, CONT_MASK | ENV_MASK | DYN_MASK | RSI_MASK | RDI_MASK
        call gc_flip_and_move_by_mask ;such economy of code size
        jmp eval_ucall_retry_alloc
                

eval_k1_move_codeptr:
        resq 1
eval_k1:
        ;; want to call "ucall" on f (rax), xs, d, e, k (all saved, in order).
        ;; and btw we can assume this has been traced
        mov rdi, rax
        mov rsi, 


        
eval_k1_move:
        ;; ... where shall we find the closure?
        ;; in rax, say?
        ;; ...
        ;; this will be called from GC workers (tracing) and read barriers.

        ;; also, in fact, this can just be:
        ;; generically move a closure of a codeptr and four saved objects.
        ;; but meanwhile...
        ;; --thinking rdi -> rax, like a general function (lelz).

        ;; K AND D AND CLOS ARE PROPERLY ADED TO ALL ARGLISTS AS SPECIAL REGS
        ;; BUT ENV IS ONLY USED BY EVAL AND A FEW OTHERS
        



        ;; ucall is not funcall; want a better name than "call"...
ucall:  




        ;; map-eval is not exposed to the public
        
map-eval:       

        




        ;; now this will actually be public
        ;; ...
        ;; do we have an "args" register,
        ;; or do we
        ;; it seems like requiring "args" is simplest on the rest
        ;; of the system, although it is terrible...
        ;; neh...

        ;; ok, eval (spec. map-eval) will _always_ produce an arglist.
        ;; therefore, only a compiler or smthg could produce a desired "list-star" thing.
        ;; ... or a saved continuation, perhaps...
        ;; well, can do that whenever desired.
        ;; at any rate.

        ;; this is public-facing, accepts "arglist".
        ;; ... eeeeven then, it would be possible to make a "call-from-arglist" code-chunk,
        ;; and make ... closures? ... that would then call the args-in-registers version.
        ;; ... But, the interpreter will have an "apply" function, and any user code
        ;; that calls builtins will call them with that "apply".
        ;; ... Am I gonna goddamn tag closures with how many args they're supposed
        ;; to accept, so that "apply" or some chained "call0, call1, ..." choice
        ;; can reach inside? ... Of course, argument checking is in principle important.
        ;; ... The interpreter itself better not check args for it calling each other.
        ;; Hmm...

        ;; list* seems somewhat unusual, in that it not only accepts rest args, but
        ;; rather prefers that.

        ;; ok, so, let's say the user wants to introduce his own assembly function.

        ;; ...
        ;; rax = argc (ignored when you don't care about checking)
        ;; [I could either do that or have a special END_OF_ARGUMENTS value passed...]
        ;; argc negative for rest args...
        ;; perhaps (argc = -1) => (rest arg = rdi), (argc = -2) => rdi rsi=rest...
        ;; and extra dicks will end up on the stack.
        ;; I guess that makes as much sense as anything.
        ;; well then.
        ;; ... oh man.
        ;; k so methinks prob'ly you'll only call things without the arg-parsing crap
        ;; at the start when you can see your destination at compile time.
        ;; [... alternative seems to be


        ;; So, I am thinking.
        ;; - functions may be passed args in rest lists or in whatever
        ;; - this is indicated with the contents of rax
        ;; - - it seems nicer to have rax = 2*[plain args] + [1 if rest args, 0 oth.]
        ;; - there will be library subroutines for parsing n args out of this
        ;; - functions that take optional args may do some fancy shit after that
        ;; - keyword args seem probably to appear as plain args that happen to be
        ;;   certain things
        ;; - cooperative compilation would help with crap

        ;; Meanwhile, for doing list-star, actually,
        ;; it is probably helpful to eat chunks of args at once [not that the arglists
        ;;  will usually be very long].
        ;; Now...
        
list-star:
        call parse_up_to_three
        ;; that will be like reentry; rax will be updated
        cmp rax, 0
        je return_nil           ;a library function? lolz
        cmp rax, 2              ;one arg
        je return_rdi           ;lel
        ;; in that case we have at least two args; now...
        ;; common case...
        ;; from user code, this will most commonly be called with 3 args,
        ;; maybe 4 or a few more, in macroexpansions of quasiquote.
        ;; anyone who wants cons will probably call cons (including my qq).
        ;; actually that goes for compiled code too.
        ;; so two args can be second-class here.
        ;; ... this whole thing can be second-class...
        cmp rax, 4
        je cons_parsed

        ;; well, then...

        ;; ... we can call cons as a subroutine...
        ;; there is the thing about interrupts and threading.
        ;; I guess I can afford to ignore that for now.
        ;; then there's if a GC flip occurs during said subroutine.
        ;; that can be dealt with easily, too.
        ;; lelz, I can have subroutines that do that shit...

        
        
        ;; and now we should get into a loop
        ;; with a head and a tail or smthg
        ;;


        ;; idiot, this is hard because you haven't defined the consing
        ;; macros yet.
        


        ;; well, fuck, let us do cons.

cons:
        call parse_exactly_two  ;that should err if not
cons_parsed:
        ;; since 
        add 

        

        