
        DEFAULT REL
        

        %define ALLOCPTR r15
        %define GLOBVEC r14
        %define CONT r13
        %define DYN r12
        %define CLOS rbx
        ;; %define ENV r11  ;nope, that's a regular argument.
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

        ;; for this thing...
        ;; I prob. want
        ;; Ok, good, turns out assembler will turn "mov rcx, 3" into
        ;; "mov ecx, 3", with no REX prefix.
        ;; Still, even latter is 5 bytes.
        ;; ...
        ;; AHA.
        ;; "and reg32/64, imm8" exists.
        ;; very well.
        ;; ...
        ;; I want to force 32-bit reg-reg movs for one instruction
        ;; so that I can usually drop the REX prefix.
        ;; Well then...
        ;; ... Actually, foo', you should also be ANDing a 32-bit reg.
        ;; [It is a missing feature of nasm that it won't turn
        ;;  "and reg64, imm[8/32]" into "and reg32, imm[8/32]", because
        ;;  the two are absolutely func. eqv. and the latter may save a byte.]
        ;; In that case...
        ;; I guess I shall expose the impl. detail that specifying 32-bit registers
        ;; will likely save two bytes.

        ;; %define raxd eax
        ;; %define rbxd ebx
        ;; %define rcxd ecx
        ;; %define rdxd edx
        ;; %define rsid esi
        ;; %define rdid edi
        ;; %define rspd esp
        ;; %define rbpd ebp        

        ;; TAG_INTO is better name--did that accidentally
        %macro TAG_INTO 2
        ;; mov %2d, %1d
        ;; and %2d
        mov %2, %1
        and %2, 0b111
        %endmacro

        ;; Oh, but for getting the whole thing, ...
        ;; Hmm...
        ;; Am I going to assume that all type-code fields are dword-sized?
        ;; It would be ridiculous to do anything else, but... there is no
        ;; defensible reason to enforce it.
        ;; In that case, I shall have to do something like the above.
        ;; Oh god.
        ;; Hmm...
        ;; [One could certainly put arbitrary objects in the type-code field.
        ;;  Thing is, that would make certain tables gigantic.
        ;;  In fact, you couldn't even use rel32offs to refer to the opposite
        ;;  side of them, or any side if there was another table in the way.
        ;;  Therefore, this code does assume type-codes are dword-sized.
        ;;  Although other code, like that which moves shit around, shall not.]
        ;; [-- I'll again leave it up to the user to exploit this.]
        ;; --Thankfully, there is "cmp reg[32/64], imm8".

        ;; --But oh god, for dereferencing, I will need a 64-bit register.
        ;; Omg.

        %define raxq rax
        %define rbxq rbx
        %define rcxq rcx
        %define rdxq rdx
        %define rdiq rdi
        %define rsiq rsi
        %define rbpq rbp
        %define rspq rsp
        %define r8q r8
        %define r9q r9
        %define r10q r10
        %define r11q r11
        %define r12q r12
        %define r13q r13
        %define r14q r14
        %define r15q r15

        %define eaxq rax
        %define ebxq rbx
        %define ecxq rcx
        %define edxq rdx
        %define ediq rdi
        %define esiq rsi
        %define ebpq rbp
        %define espq rsp
        %define r8dq r8
        %define r9dq r9
        %define r10dq r10
        %define r11dq r11
        %define r12dq r12
        %define r13dq r13
        %define r14dq r14
        %define r15dq r15
        

        ;; A possible issue: In the below, if you go
        ;; TYPECODE_INTO CONT, rax
        ;; would that become
        ;; [...] mov rax, [CONTq + 8*raxq]
        ;; and then CONTq would be an invalid thing.
        ;; Well, for whatever reason, it turns out that is not a problem.
        %macro TYPECODE_INTO 2
        mov %2, %1
        and %2, 0b111
        cmp %2, USER_TAG
        jne %%dont              ;can't use cmov because it's stupid [segfault]
        mov %2, [%1q - USER_TAG + 8*%2q]
%%dont:
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
        ;; rsi = env
        ;; ........
        ;; it'd still be advantageous, given the switching around,
        ;; for env to be in a constant register btwn eval and ucall...
        ;; ... well, originally ucall was just a subroutine.
        ;; it seems to have general use, but... for the moment...
        ;; ok, I'll just have the argument sig of ucall be "f env xs".
        ;; hoo boy.
        ;; --wait, no.
        ;; nvm, shit gets put into a closure and taken out anyway in betwen.
        ;; ... ... sigh, that is the sad truth of life as we know it.
eval:
        ;; modern approaches show the below to be inferior
        ;; mov SCRATCH, 0b111
        ;; and SCRATCH, rdi
        ;; cmp SCRATCH, SYM_TAG
        ;; je lookup
        ;; cmp SCRATCH, CONS_TAG

        mov edx, edi
        and edx, 0b111
        cmp edx, SYM_TAG
        je lookup
        cmp edx, CONS_TAG
        jne eval_ucall

        ;; this is how you call a closure
        mov rax, rdi
        mov CLOS, CONT
        jmp [CONT - CLOS_TAG]

eval_ucall:     

        CDR_INTO rdi, rdx
        CAR_INTO rdi, rdi
        ;; oh my fucking god now
        ;; we allocate a continuation...
        ;; which saves cdr.x, e, d, k.
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
        add ALLOCPTR, 40        ;code, cdr.x, e, d, k
        cmp rax, TOSPACE_TOP
        jnl eval_ucall_gc_flip  ;assuming signed? ... yes, shdn't mk diff...

        ;; btw, it would be slightly good if I used scratches that were
        ;; not extended registers, although 64-bit ops on usual regs will
        ;; also have an extra byte... but the common case of moving 7
        ;; into a reg is applicable. but for now, oh well.

        lea SCRATCH, [eval_k1]
        mov [rax + 32], CONT
        mov [rax + 24], DYN
        mov [rax + 16], rsi
        lea CONT, [rax + CLOS_TAG] ;yep, this is in fact the shortest way
        mov [rax + 8], rdx
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
        ;; want to call "ucall" on f (rax), xs, e, d, k (all saved, in order).
        ;; and btw we can assume this has been traced
        mov rdi, rax
        mov rsi, [CLOS - CLOS_TAG + 8]
        mov rdx, [CLOS - CLOS_TAG + 16]
        mov DYN, [CLOS - CLOS_TAG + 24]
        mov CONT, [CLOS - CLOS_TAG + 32]
        jmp ucall


        
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
        ;; oh well...
        ;; f xs e in rdi rsi rdx; d k in DYN CONT; nothing useful in CLOS
        ;; ... we need some predicates now, fuck.
        ;; how do we do that?
        ;; a bunch of tests?
        ;; or a jump table?
        ;; the latter would be best, but can I do it...
        ;; I suppose that if I can do the weird closure stuff,
        ;; then I can certainly do this.
        ;; therefore.
        ;; type system.
        ;; ...
        ;; I have a couple of choices.
        ;; I could have a unified thing.
        ;; Or I could do otherwise...
        ;; Ok, I think I want a unified type system, then.
        ;; Now...
        ;; What do I store in the type-tag field of user things?
        ;; n or 8n?
        ;; If 8n, then it's likely that many allocations will ...
        ;; will require 4 bytes, rather than 1, to store an immediate
        ;; (signed) value ...
        ;; Actually, not true.
        ;; Actually, true.
        ;; Shit gets sign-extended.
        ;; However,

        ;; I should check exactly what kind of SIB weird [rax + 8*rbx + n]
        ;; crap is possible.
        ;; I think it's only [reg + n], [reg + [1248]*reg], maybe [reg*[1248] + n],
        ;; and rip can be a reg.

        ;; ok, assuming the above is correct, which I believe it is,
        ;; then the free-associating/thinking brain has spoken:
        ;; it is advantageous to deal with n, not 8*n.
        ;; you only need 8*n when you're referencing into some kind of table,
        ;; a jump table or a "type code -> type-name" table or something.
        ;; and in those cases, x86 makes it equally cheap, I believe,
        ;; to say "rcx + 8*rdx" or "rcx + rdx".
        ;; as for allocation and naming, you prefer the smaller integers.
        ;; so.
        ;; [if this were ARM, btw, my dec. would probably be the opposite]
        ;; and if the user wants the type-code, then, yeah, you will have
        ;; to multiply it by 8 (or lea it, [it * 8]; or shl it, 3).
        ;; --Yeah, I was right. [see lea-testing]
        ;; --No, not quite. You can do [reg*[1248] + reg + n].
        ;; But, yes:
        ;; The only thing that's cheaper with [reg + smthg] instead of
        ;; [reg*8 + smthg] is [reg + n].
        ;; Anyway.

        ;; I should probably put the ucall_jump_table somewhere far-ish.
        ;; To avoid separating code chunks much, and causing their offsets
        ;; to become disp32 rather than disp8 in jump instructions.
        ;; Anyway.

        ;; f xs e in rdi rsi rdx; d k in DYN CONT.
ucall:  
        TAG_INTO edi, ecx
        cmp




ucall_quote:
        CAR_INTO rsi, rax
        mov CLOS, CONT
        jmp [CONT - CLOS_TAG]

ucall_if:
        ;; maybe move some registers, then

        jmp ueval_if


        ;; oh boy.
        ;; ...
        ;; well, actually,
        ;; we can just make a fucking stupid "user-closure" data structure.
        ;; probably the thing to do.
ucall_fn:
        
        


ucall_assign:

ucall_dlet:

ucall_macro:


        ;; now I could 



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

        ;; Convention:
        ;; func_user => appears in a "closure", prob. bound to a globvar,
        ;;     accepts an arglist.
        ;; func => accepts args in rdi, rsi, etc.; prob. not bound to a globvar.
        ;; func_kn => continuation created by a complex function; prob. not
        ;;     bound to a globvar, but will appear in continuation-closures.

cons_user:
        call parse_exactly_two  ;that should err if not

        ;; x rdi y rsi ret rax CONT CONT ign ev. else
cons:
        ;; since we are single-threaded at the moment, we can lelz.
        mov rax, ALLOCPTR
        add ALLOCPTR, 16
        cmp ALLOCPTR, TOSPACE_TOP
        jnl cons_gc_flip
        mov 


cons_gc_flip:
        
        call gc_flip

        jmp cons



        ;; OH MY GOD I'VE FORGOTTEN ABOUT GC WORK
        ;; NEXT
        ;; ALLOCATE = PLAIN
        ;; ALLOC = DO GC WORK IF NEC., THEN ALLOCATE

        ;; ok, there are a few approaches...
        ;; 1. Baker exactly.  Before allocating n bytes, check if we're
        ;;    still tracing, and if so, call gc_work to trace 4n bytes.
        ;; 2. Larger granularity.  Use, in place of TOSPACE_TOP, a thing
        ;;    like MYSPACE_TOP [good name], which allocates chunks of
        ;;    size something like 4k.  (Could be varied to get the exact
        ;;    granularity of GC work I want...)
        ;;    This is essentially the strategy that must be used in the
        ;;    multi-threading situation.  Though the single-threaded
        ;;    case means you never have to waste a smallish chunk of
        ;;    memory.  (Fragmentationz.)
        ;;    Btw, this actually fits well, too, with deciding to invoke
        ;;    a gc flip well before you reach TOSPACE_TOP.
        ;; 3.

        ;; Aha.  I can achieve minimum granularity using MYSPACE_TOP.
        ;; I could always set MYSPACE_TOP = ALLOCPTR + 8, or even ALLOCPTR + 0,
        ;; and then allocs would always end up calling GC_WORK_OR_FLIP.
        ;; (Then, when gc work was done, it'd just bump it up to TOSPACE_TOP or wtvr.)
        ;; That is el goodo and I will do el thatto.

        ;; Issue.  Can I be sure I can make things fine if [current memory is filled
        ;;  before gc work is done]?

        ;; Answer seems to be yes.
        ;; It will cost a bit.
        ;; Just grab more dick, ensure that all prev. dick is "fromspace" atm,
        ;; and act like you've just gc-flipped.
        ;; First, "move" must check ... whether, when it finds a fwd ptr, it needs
        ;; to be moved itself.
        ;; Second, "trace" must ...
        ;; Well, when you're tracing an object, must check if it itself
        ;; has been moved. ...
        ;; If it has, then someone else has already signed up to trace it,
        ;; so you won't have to trace the moved thing.
        ;; In that case, the only problem is making sure you don't do terrible
        ;; things as a result of that... i.e. dereference bad pointers or replace
        ;; the forwarding ptr or the gc-next pointer with something new.
        ;; There are a couple of possible solutions.
        ;; - Ensure that fwd-ptr and gc-next are both 000-tagged, so tracing will
        ;;   have no effect.
        ;;   This makes following fwd-ptrs slower, as you have to put the tag back
        ;;   in, which sucks.  (Also it's not possible for both gc-next and fwd-ptr
        ;;   to lack a tag--at least one is necessary for the poor gc worker to
        ;;   figure out what it's tracing.)
        ;;   [... If there are things, such as blocks of code or shared closures
        ;;    or maybe arrays, where I don't want the gc-next to point to the front...
        ;;    ... Neh, that seems negligible.]
        ;; - Have tracing check whether the thing being traced has a fwd ptr.
        ;;   This slows down tracing, makes it more complex, and kinda sucks.
        ;; - Have tracing check whether the thing being traced is located in
        ;;   fromspace.
        ;;   This would also slow down tracing, but... it seems to have better
        ;;   performance characteristics...
        ;; ... And then there's also read-barring.
        ;; (Which leads to tracing, but in a slightly different context.)
        ;; ...
        ;; No...
        ;; That'd be addressed by the "moving" thing.  Not by the "tracing" thing.
        ;; User program will only see tospace ptrs.
        ;; If user program pulls a fromspace ptr out of a tospace object, it moves it.
        ;; Right.
        ;;

        ;; All right, I kind of hate a sacrifice this will force,
        ;; but it will fully address certain things without the need for brittle
        ;; cleverness.
        ;; - Tracing will check whether the thing being traced is located in
        ;;   fromspace.
        ;;   This is forced by the weird different kinds of tracing that you might
        ;;   expect to get from user-specified tracing for closures, weird things
        ;;   for vectors, and so on.
        ;;   You should never be tracing something that is in fromspace.
        ;; - Vector operations will have to do a bit of extra shit.
        ;;   As a consequence of this shit, if you are trying to get the nth elm
        ;;   of a vector, you may need to look through several vector corpses.
        ;;   In monotonically increasing order of their elements-copied/length field.
        ;;   You'll have to do a loop thing.
        ;;   Um...
        ;;   Oh, wow, I guess you kinda can look at the lengths you see to see if
        ;;   they ever decrease.  Wow.
        ;;   I love it when offhand sardonic remarks turn out to contain useful ideas.

        ;; All right.  No tracing w/o checking.  Moving must ...
        ;; Moving that finds a fwd ptr must check if that pts to fromspace.
        ;; Also, when moving things, you must check whether that overflows tospace.
        ;; Which sucks, but.
        ;; If branch prediction is all it's cracked up to be, then that should
        ;; make little difference.
        ;; Lessee...
        ;; Grab more memory either (a) when the total number of bytes of objects
        ;; saved from the last cycle exceeds, say, 80% of a semispace, or (b)
        ;; when you try to allocate memory and that plus # traced bytes would
        ;; exceed that threshold.  (In terms of amount of work... if you
        ;; have 80/20 old/new, then that implies all allocations are slowed down
        ;; by a GC work factor of 4... you really want time during which GC work
        ;; is not happening, especially if you use devious tactics on top of that--
        ;; versions of functions without read barriers and such.)
        ;; Hmm... I'm then tempted to put the ratio at 50% or something--if you
        ;; trace 50% or more of useful stuff [this implies a max of 62.5%], then
        ;; there will be a doubling.  At any rate, that should be easily changeable
        ;; at runtime.
        ;; But
        ;; --No, you fool!  The only way to guarantee that less than nn% will be
        ;; traced is to initiate a GC flip when less than nn% memory has been
        ;; allocated.
        ;; In *practice* memory will probably grow slower than that--all sorts of
        ;; garbage will be allocated in the form of continuation-closures and
        ;; whatnot.  In that case a policy of "double when > 50% or whatever" would
        ;; be useful.
        ;; However, we must also be prepared.

        ;; Incidentally, in the multithreading case, I suppose each thread could
        ;; assume that the other threads are attempting to allocate the same
        ;; size object, and then the one with the biggest may be likely to request
        ;; more memory...
        ;; Geh, neh.  Whatever about that.

        ;; Meanwhile, I think the main remaining issue is


        ;; imported from other investigations:
        ;; --
;; wow. I have unintentionally done a kind of "Fragger" test.
;; I guess it does make sense that it would have to give a chunk of
;; continuous addresses.  mmmyes, quite, yes.

;; ok, a good solution to dicks:
;; grab a large chunk of memory, larger than you need.
;; probably bump up gc work ratio.
;; and now ...
;; if you end up at 100%, with gc work ratio of 4,
;; then 80% of that is copied crap,
;; meaning that the total you might have is 120%.
;; you do another gc flip.
;; you throw away the previous gc-next crap.
;; and now ... actually, just by getting a destination semispace of size 200%,
;; you will be doing just fine.
;; (maintaining gc work ratio of 4, you'll be done at 150%)
;; only issue is if you're trying to allocate a gigantic object.
;; hmm...

;; Ok.
;; - If, at any time, you want to alloc, and GC is still happening, and
;; TOSPACE_TOP - ALLOCPTR < what you want to alloc, then clearly you need
;; more dick.  So get more dick and initiate a GC flip.
;; - If you want to alloc, and TOSPACE_TOP - ALLOCPTR leaves not enough,
;; and GC is in fact done, then initiate a GC flip and begin the next round
;; by allocating what you want.  (If you then find there's still not enough--
;; go to previous step.)
        ;; --

        ;; and then, regarding tagging and manipulating bits of to/fromspace...
        ;;
        ;; So, in normal usage, fromspace is 01 and tospace is 10, and the
        ;; TEST thing will distinguish them.
        ;; This is necessary so that the TEST mask can be switched without
        ;; regenerating code to switch the roles of from and tospace.
        ;;
        ;; Best thing, with "alloc pyramid beforehand and slowly inhabit it",
        ;; seems to be:
        ;; reside in 001 and 010,
        ;; when nec. expand into tospace=100 through 101 (with mask 100,
        ;; so that test 0 => fromspace),

        ;; Probably I could reverse that.
        ;; Whatever.
        ;; Routine expansion should work fine w/o static stuff.
        ;;
        ;; I think I have some prejudice towards "1 = not fromspace", but wtvr.
        ;; Prob. solved problem.
        
        
        ;; I guess this brings other kinds of advantages...

        ;; Btw, would be very bad to just fill up memory without stuff...
        ;; Would probably want "begin by tracing a certain amount" after a
        ;; forced, hasty doubling.
        ;; (Oh man more metaphors.  You really should plan out your pregnancies,
        ;;  and arrange for things beforehand.  Other people who would be
        ;;  involved in your plans would probably want you to tell them
        ;;  beforehand so they could prepare.  However, if you do get pregnant,
        ;;  they will have to deal with it, and it would be a total trashing of
        ;;  professional ethics for your doctor to say "Well, you didn't take my
        ;;  advice, so screw you and I'm not helping you" and demand that you
        ;;  abort your program.)
        
        


        ;; rdi = x, which is assumed to be a function or at least
        ;; a callable thing.
        ;; hmmph...
        ;; arc3.1's ccc expects a procedure as an argument.
        ;; I think I'll go with that.
        ;; procedure or user closure, humph.
call_cc:
        


        