
        DEFAULT REL

        
        
        

        %define ALLOCPTR r15
        %define GLOBVEC r14
        %define CONT r13
        %define DYN r12
        %define CLOS rbx
        ;; %define ENV r11  ;nope, that's a regular argument.
        %define SCRATCH r10

        %define GC_NEXT whatever ;maybe register, maybe not
        ;; maybe gc workers will use a register, while read barrs will not


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

        %define OURSPACE_TOP [GLOBVEC + n]

        %define GLOBAL_NIL [GLOBVEC + n]
        %define GLOBAL_T [GLOBVEC + n]
        
        %define GLOBAL_IF [GLOBVEC + n]

        %define GLOBAL_GC_WORKCOUNT [GLOBVEC + n]
        
        

        ;; this is unchecked
        ;; and CAR_INTO x,x works.
        %macro CAR_INTO 2
        mov %2, [%1 - CONS_TAG]
        READ_BARR %2
        %endmacro

        %macro CDR_INTO 2
        mov %2, [%1 - CONS_TAG + 8]
        READ_BARR %2
        %endmacro

        ;; TAG_INTO is better name--did that accidentally
        %macro TAG_INTO 2
        ;; mov %2d, %1d
        ;; and %2d
        mov %2, %1
        and %2, 0b111
        %endmacro


        
        %macro BARR_USING_RDI_RAX_AT 1
        mov rdi, %1
        test rdi, FROMSPACE_MASK
        jz %%dont
        test rdi, PTR_MASK
        jz %%dont
        ;; mov eax, 0b111 ;no, is bigger, discovered that before
        ;; and eax, edi
        mov eax, edi
        and eax, 0b111
        call [move_jump_table + 8*rax]
        mov %1, rdi
%%dont:
        %endmacro
        
        
        

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



        .align 8
        mov rax, 0xfffefafd
        nop
        nop
        nop
        ;; this alignment crap is just an exercise at the moment, I guess,
        ;; but it might be useful to enable the "an exception is raised upon
        ;;  unaligned memory accesses" thing, in which case it would be
        ;; necessary to ensure that all crap I write to is aligned.
        
initialize:                     ;name for documentation purposes
        lea rax, [move_cons]
        mov [move_jump_table + 8*CONS_TAG], rax
        lea rax, [move_sym]
        mov [move_jump_table + 8*SYM_TAG], rax
        lea rax, [move_user]
        mov [move_jump_table + 8*USER_TAG], rax



        ;; next we have "move me" codeptrs for closures
        ;; .....
        ;; y'know, I don't really have to do that, I don't think.
        ;; a length for closures might suffice.
        ;; I am still using a "trace me and execute" codeptr, though.
        ;; ...
        ;; the issue, I suppose, is with closures that might have their
        ;; code in a static place or a C place or something, vs closures
        ;; that might be otherwise. right, yes. I must support that.

        ;; ... and then there is the other issue.
        ;; -- oh, right. nvm.  will confront that, but is ok.
        ;; [distinguishing fwd ptr from codeptr: see bit 63.]

        lea rax, [eval_k1]
        mov [eval_k1 - 8], rax
        



        ;; moves the ptr in rdi,
        ;; assumes gc-next is in some register
        ;; probably consumes rax and maybe other crap (we'll see)
move_jump_table:
        resq 64                ;don't know how many I'll need; whatever




        ;; move the cons cell in rdi
        ;; consume rax.
        ;; ...
        ;; ...
        ;; due to tags, a pointer can literally never be zero, which is
        ;; a nice resolution if I want to use neg.
        ;; ... but neh. btr.
        ;; ... put the actual moving on the fast path, methinks, to
        ;; spread the wealth.
        ;; ...
        ;; destroy SCRATCH too.  oh jesus.
        ;; [or maybe push and pop things...]
        ;; ... geez, I'm so register-starved.
        ;; r10 
move_cons:      
        mov rax, [rdi - CONS_TAG]
        bt rax, 63
        jc move_cons_maybe_lucky

move_cons_actually:
        
        ;; in multithreaded, we'd have to test here whether we'd
        ;; exceeded our current OURSPACE, and grab more if not.
        ;; but here, we can assume we have space.
        ;; in fact, we can be clever.  ALLOCPTR is pretty definitely
        ;; a register.  [... Hmm... I have a feeling the FROMSPACE_MASK
        ;;  thing should be in a register, if read barriers happen more
        ;;  often than allocations, which seems ... possible, dunno.
        ;;  I may have some extra registers, though.  --But ALLOCPTR seems
        ;;  to be used strictly more often than GC_NEXT, for example.]

        ;; hmm...
        ;; also in multithreaded, we would grab the cdr and then the car.
        ;; I am uncertain whether the architecture would require me to put
        ;; a memory barrier in between.
        ;; anyway, here, this is what we do.
        mov [ALLOCPTR], rax
        mov SCRATCH, [rdi - CONS_TAG + 8]
        mov [ALLOCPTR + 8], SCRATCH
        lea rax, [ALLOCPTR + CONS_TAG] ;in mult. would pres. rax for cmpxchg

        ;; rdi = the corpse
        ;; rax = the heir
        
        mov SCRATCH, rax
        bts SCRATCH, 63         ;fwd ptr

        mov [rdi - CONS_TAG], SCRATCH ;installed, also committed
        add ALLOCPTR, 16
        ;; gc-next, then
        mov SCRATCH, GC_NEXT    ;necessary iff GC_NEXT is in memory
        mov [rdi - CONS_TAG + 8], SCRATCH
        mov GC_NEXT, rdi        ;gc-next is a tagged ptr
        ;; now our return value will be in rdi.
        mov rdi, rax
        ret
        

move_cons_maybe_lucky:
        test eax, PTR_MASK      ;boy
        jz move_cons_actually
        ;; found a forwarding pointer

move_found_fwd: 
        btr rax, 63
        mov rdi, rax
        ret



        ;; ok, so.
        ;; syms have their own tag, not a user tag.
        ;; syms probably are: [symbol-value symbol-string symbol-hash]
        ;; actually, make that [symbol-string symbol-value symbol-hash]
        ;; to rule out negints in the first field, so the fwd ptr test is easier.
        ;; although I dunno if the symbol-hash will be used yet
move_sym:       
        mov rax, [rdi - SYM_TAG]
        bt rax, 63
        jc move_found_fwd

        ;; all right, drill.
        mov [ALLOCPTR], rax
        mov SCRATCH, [rdi - SYM_TAG + 8]
        mov rax, [rdi - SYM_TAG + 16] ;again, in mult. would pres. rax
        mov [ALLOCPTR + 8], SCRATCH
        mov [ALLOCPTR + 16], rax
        lea rax, [ALLOCPTR + SYM_TAG]
        ;; now fwd and claim
        mov SCRATCH, rax
        bts SCRATCH, 63
        mov [rdi - SYM_TAG], SCRATCH
        add ALLOCPTR, 24
        ;; gc-next
        mov SCRATCH, GC_NEXT    ;drop if GC_NEXT = reg
        mov [rdi - SYM_TAG + 8], SCRATCH
        mov GC_NEXT, rdi
        mov rdi, rax
        ret




move_clos:
        mov rax, [rdi - CLOS_TAG]
        ;; jmp [rax - 8]           ;neh? ;neh
        bt rax, 63
        jc move_found_fwd       ;no need to test for negints: is codeptr or fwd.
        jmp [rax - 8]

        ;; now this one may be the doozy
        ;; vec = [parent lock length/elms elm ...]
        ;; hmmm...
        ;; ok, so, the first field of the heir/the prince can be 0 if done moving,
        ;; and a ptr (into fromspace, no bit63) if still moving.
        ;; meanwhile, the first field of the corpse...
        ;; there isn't actually a reason that needs to have its bit63 set for a fwd.
        ;; 
        
        ;; let's see...
        ;; due to reasons, 
move_vec:
        mov rax, [rdi - SYM_TAG]
        
        
        

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






        ;; integers = 000.
        ;; chars should be either 100, 010, or 001
        ;; so that testing for ptr-ness is easy: test x, 011 [binary].

        
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

        ;; this is how you call a closure ;actually I'll change that right now, new ver.
        mov rax, rdi
        mov CLOS, CONT
        jmp [CONT - CLOS_TAG]

eval_ucall:     

        CDR_INTO rdi, rdx
        CAR_INTO rdi, rcx
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


        ;; ok, so...
        ;; lelz--we can't save a continuation so we can alloc a continuation.
        ;; anyway.
        ;; ...
        ;; let's try a very generic thing.
        ;; and regarding saving...
        ;; with allocating giant things, we may need to do multiple
        ;; gc flips.
        ;; in that case, this shit ... needs ... ass.

        ;; rax is an obvious destination for the ptr.
        ;; then what should be mask?
        ;; ...
        ;; geez. I think that, for *this* kind of convenience,
        ;; I am ...
        ;; ...

        ;; Ok, fine.
        ;; rax = mask.
        ;; rdi => ptr.
        ;; sigh.

        ;; now.
        ;; atm rsi = env, rdx = cdr.x, rcx = car.x,
        ;; CONT = k, DYN = d.
        ;; those need potentially saving.

        ;; hmmm...
        ;; the gc flip will need to know how big we want it, in case it needs
        ;; to make it bigger. thus this calling convention--gc flip can deduce
        ;; the size from dick, and will give us the dick we wanted.

        mov rdi, ALLOCPTR
        add ALLOCPTR, 40        ;code, cdr.x, e, d, k
        ;; cmp rdi, OURSPACE_TOP   ;either top of tospace or gc-work marker ;dumbass
        cmp ALLOCPTR, OURSPACE_TOP
        jl eval_ucall_proceed
        ;; gc work or gc flip
        mov rax, RSI_MASK | RDX_MASK | RCX_MASK | CONT_MASK | DYN_MASK
        call gc_work_or_flip    ;assumes ptr=rdi, mask=rax
eval_ucall_proceed:     

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
        ;; must put x (= car.prev_x) back in rdi.
        mov rdi, rcx
        jmp eval                

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

        ;; K AND D AND CLOS ARE PROPERLY ADDED TO ALL ARGLISTS AS SPECIAL REGS
        ;; BUT ENV IS ONLY USED BY EVAL AND A FEW OTHERS

        ;; ok, rdi -> rdi, it is decided.
        ;; so now.
        ;; not sure exactly where this will be called from--anyway load stuff:
        mov rax, [rdi - CLOS_TAG]
        bt rax, 63
        jc move_found_fwd
        

        ;; again, in mult., we'd have to load ...
        ;; Actually, no, I don't think we would.
        ;; It doesn't matter if you copy a garbage value that is someone else's
        ;; gc-next pointer into a new object that you drop as garbage anyway
        ;; because someone beat you to the fwd ptr.
        ;; Good, good.

        ;; Now I should maybe have some subroutines that do this stuff.
        ;; Certainly for closures...
        ;; Perhaps for all types, although that would make more runtime work.
        ;; ... Yeah, just closures (and user things eventually).
        ;; ...
        ;; Fuck.  Well, let's at least do one example before messing with stuff.

        lea rax, [eval_k1_trace_x] ;usual mult. disclaimer
        mov SCRATCH, [rdi - CLOS_TAG + 8]
        mov [ALLOCPTR], rax
        mov [ALLOCPTR + 8], SCRATCH
        mov rax, [rdi - CLOS_TAG + 16]
        mov SCRATCH, [rdi - CLOS_TAG + 24]
        mov [ALLOCPTR + 16], rax
        mov [ALLOCPTR + 24], SCRATCH
        mov rax, [rdi - CLOS_TAG + 32]
        mov [ALLOCPTR + 32], rax
        ;; done moving
        lea rax, [ALLOCPTR + CLOS_TAG]
        ;; fwd and claim
        mov SCRATCH, rax
        bts SCRATCH, 63
        mov [rdi - CLOS_TAG], SCRATCH
        add ALLOCPTR, 40
        ;; gc-next
        mov SCRATCH, GC_NEXT
        mov [rdi - CLOS_TAG + 8], SCRATCH
        mov GC_NEXT, rdi
        mov rdi, rax
        ret

just_ret:
        ret


        ;; so here, we get args and CLOS.
        ;; basically we read-barr the contents (4 vars saved).
        ;; lessee...
        ;; the eval_k1 code itself assumes they are read-barr'd.
        ;; so there isn't redundancy there.
        ;; now...
        ;; for flagellation purposes, we shall return in rax
        ;; the length of the thing.
        ;; this makes it convenient to use a subroutine to do
        ;; such read-barring.
        ;; oh man.
        ;; how about recursive calls?
        ;; no, tracing doesn't lead to tracing.
        ;; I think we're fine.
        ;; ...
        ;; actually, trace_x is useless for flagellation.
        ;; [actually, I guess we can put a count of gc work in our vector]

        ;; So I forget if I've written this elsewhere yet,
        ;; but actually I'm definitely not following the C calling convention,
        ;; because the way you return from a function is not by popping
        ;; from the stack, but by calling a continuation.
        ;; [And subroutines don't really count; also I definitely don't return
        ;;  results from there in rax.]
        ;; So I dunno if things should actually pass their results to a continuation
        ;; in rax.  Suspect not.
        ;; So let's say that's just in rdi.
        ;; In that case, I do have to be a bit careful...
        
eval_k1_trace_x:
        mov rcx, rdi            ;backup, 'cause we do barrs on rdi

        add GLOBAL_GC_WORKCOUNT, 40

;;         ;; let's illustrate it the first time by writing it all out.
;;         mov rdi, [CLOS - CLOS_TAG + 8]
;;         test rdi, FROMSPACE_MASK ;ones identify fromspace
;;         jz skip_first
;;         test rdi, PTR_MASK
;;         jz skip_first
;;         mov eax, 0b111
;;         and eax, edi
;;         call [move_jump_table + 8*rax]
;;         mov [CLOS - CLOS_TAG + 8], rdi
;; skip_first:
;;         ;; oh god, do that crap again?
;;         ;; no, el macro-o.
;;         ;; the macro is BARR_USING_RDI_RAX_AT.
;;         ;; it's nine instructions.
;;         ;; don't wanna have all that written out here.
;;         ;; therefore, we will have a subroutine.

        ;; subroutine uses... rsi.
        ;; for the pointer.
        ;; --and rdx for a counter. fine.
        lea rsi, [CLOS - CLOS_TAG + 8]
        mov edx, 4
        call trace_n_at
        lea rax, [eval_k1]
        mov rdi, rcx            ;restoring that thing
        mov [CLOS - CLOS_TAG], rax ;in mult, it is critical you do this *after* tracing
        jmp eval_k1

;; move_n_at:
;;         te
        
;; move_even_n_at:                 ;instinctive unrolling

;; move_five_at:
;;         BARR_USING_RDI_RAX_AT

;; move_two_at:
;;         BARR_USING_RDI_RAX_AT
;; move_one_at:    
;;         BARR_USING_RDI_RAX_AT 
;; move_one_at_ret:
;;         ret

        ;; ... idiot, this is trace, not move.

;; trace_even_loop_check:   
;;         sub rsi, 2
;;         j
;; trace_even_loop: 
        

;; trace_two_at:
;;         mov rdi, [rsi+8]
;;         test rdi, FROMSPACE_MASK
;;         jz trace_one_at
;;         test rdi, PTR_MASK
;;         jz trace_one_at
;;         mov eax, 0b111
;;         and eax, edi
;;         call [move_jump_table + 8*rax]
;;         mov [rsi+8], rdi
;; trace_one_at:
;;         mov rdi, [rsi]
;;         test rdi, FROMSPACE_MASK
;;         jz trace_even_loop_check
;;         test rdi, PTR_MASK
;;         jz trace_even_loop_check

        ;; ok, whatever, let's just go for code size...
        ;; rdi, rsi, rdx=n

trace_n_at_bef1:        
        dec rdx
        jz trace_n_ret
trace_n_at_bef2:
        add rsi, 8
trace_n_at:     
        mov rdi, [rsi]
        test rdi, FROMSPACE_MASK
        jz trace_n_at_bef1
        test rdi, PTR_MASK
        jz trace_n_at_bef1
        mov eax, edi
        and eax, 0b111
        call [move_jump_table + 8*rax]
        mov [rsi], rdi          ;would cmpxchg in mult.
        dec rdx
        jnz trace_n_at_bef2
trace_n_ret:    
        ret
        
        
        ;; generically, moving a closure of n
        ;; should involve putting some things in places
        ;; and then ... deh.
        


;; move_closure_of_five:
        
        
        
        




        ;; defaults for this should maybe be a helpful error message
apply_jump_table:
        resq 64


        ;; ok, so, apply will, upon being handed a CLOS_TAG'd thing as f,
        ;; parse an arglist and ...
        ;; ok, where the fuck do I do argument list length checking?
        ;; that is, does apply check that, and if so, how does it figure
        ;; out the arity of the CLOS it's passed?
        ;; if not...
        ;; I guess I can create user-object wrappers that do checking.
        ;; (kinda like that time at the Taj Mahal Casino ...)
        ;; 

        ;; f=rdi, xs=rsi, d k in places.
        ;; now...
        ;; this stuff is slow enough (geez, reaching inside an arglist to
        ;;  get the index you use to reach into a string?) that I don't feel
        ;; like I need a jump table.  so.
        ;; -- although I will if there are a serious number of user apply things.
        ;; ok, then.
        ;; ...
        ;; the apply jump table is really easy, you fool.
        ;; well whatever
apply:
        TAG_INTO rdi, rdx       ;keeps confusing me
        cmp rdx, CLOS_TAG
        je parse_xs_call_clos
        cmp rdx, STRING_TAG
        je parse_xs_string_ref


        

        ;; so I guess these builtin functions ...
        ;; hmm...
        ;; geh, if you want your extra args on the stack,
        ;; then get it called by something else than apply.
        ;; wrap your builtin in another function.

        ;; we will assume ...
        ;; no, we will not assume a proper arglist, we will verify.
        ;; ... as for number of arguments?
        ;; ... bahaha, that is not passed at all here.
        ;; wrap your shit in a function that finds # args and passes
        ;; that if you wish.
        ;; right.

        ;; ok, so.
        ;; rdi rsi rdx rcx r8, and if 6+, then r9 contains rest.
        ;; so good.
        
parse_xs_call_clos:
        mov CLOS, rdi
        xor edi, edi            ;why not
        mov r9, rsi
        TAG_INTO rsi, rax
        cmp rax, CONS_TAG
        jne hope_is_end
        CDR_INTO rsi, r9
        CAR_INTO rsi, rdi

        ;; oh man code generation
;; arc> (pbcopy:tostring:each reg '(rsi rdx rcx r8) (prn "        TAG_INTO r9, rax\n        cmp rax, CONS_TAG\n        jne hope_is_end\n        CAR_INTO r9, " reg "\n        CDR_INTO r9, r9") (prn))        
        
        TAG_INTO r9, rax
        cmp rax, CONS_TAG
        jne hope_is_end
        CAR_INTO r9, rsi
        CDR_INTO r9, r9

        TAG_INTO r9, rax
        cmp rax, CONS_TAG
        jne hope_is_end
        CAR_INTO r9, rdx
        CDR_INTO r9, r9

        TAG_INTO r9, rax
        cmp rax, CONS_TAG
        jne hope_is_end
        CAR_INTO r9, rcx
        CDR_INTO r9, r9

        TAG_INTO r9, rax
        cmp rax, CONS_TAG
        jne hope_is_end
        CAR_INTO r9, r8
        CDR_INTO r9, r9

        jmp done_parsing

hope_is_end:    
        cmp r9, GLOBAL_NIL
        jne bad_arglist
done_parsing:   
        jmp [CLOS - CLOS_TAG]


bad_arglist:    
        ;; oh no what do we do now
        


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


        ;; ...
        ;; could I even have cont-closures have an alternate
        ;; calling convention, where they find themselves
        ;; in CONT rather than CLOS?
        ;; ...
        ;; dayumn.
        ;; I am already screwing up their calling convention
        ;; by putting their argument in RAX.
        ;; And call/cc will create a wrapper for them that
        ;; looks like a normal closure (is, in fact) and has
        ;; the normal calling convention.
        ;; Mmm...
        ;; Well, at least I can localize the method for calling.

call_cont_on_rdi:
        mov SCRATCH, [CONT - CLOS_TAG]
        mov rax, rdi
        mov CLOS, CONT
        jmp SCRATCH
        

        ;; map-eval is not exposed to the public

        ;; ok where do we find nil
        ;; ah yes, in a vector of global variables
        ;; righto.
        ;; xs=rdi, e=rsi, d=DYN, k=CONT
map_eval:       
        cmp rdi, GlOBAL_NIL
        je call_cont_on_rdi

        ;; now we prepare ...
        ;; yeah, I ...
        ;; we shall allocate two continuations, one of which will
        ;; save the other ...



        ;; xs d e k...
        ;; xs in rdi, e in rsi, d k in DYN CONT.
eval_if:
        cmp rdi, GLOBAL_NIL
        je call_cont_on_rdi     ;lel

        CDR_INTO rdi, rdx
        CAR_INTO rdi, rdi
        cmp rdx, GLOBAL_NIL     ;this will be true about half the time (if3 = usual)
        je eval                 ;lovely, lovely

        ;; oh man, now we must make a cont
        ;; and do some shit
        ;; rdi = a; rdx = (b . rest)
        CDR_INTO rdx, rcx       ;I'm thinking I should swap arg order next v.
        CAR_INTO rdx, rdx
        ;; rdi = a; rdx = b; rcx = rest
        ;; we make a cont containing: eval_if_k1 b rest e d k.
        ;; ... let's see.
        ;; I guess we're using rdi for allocation? ...

        ;; you know it'd be very cheap to have a "gc_work_or_flip_using_regx"
        ;; that would say "xchg regx, rdi; call gc_work_or_flip; xchg regx, rdi; ret".
        ;; so do that you fuckhead.
        ;; ... hmmmmm...
        ;; I guess it may also interact with [the space-time continuum] the mask thing.
        ;; In that case...
        ;; .....
        ;; Ok, where exactly might Mr. GC Flip need to flip twice, again?
        ;; When someone's allocating a giant dick.
        ;; That isn't here.  Although I don't like depending on such an assumption.
        ;; (In the multithreaded case, for example, ... someone else might try to
        ;;  allocate a giant dick.  ...)
        ;; ... Ok, well...
        ;; ...
        ;; So, when gc_work_or_flip calls gc_flip...
        ;; I guess it'l be ok to do it like this:
        ;; The brains are in gc_work_or_flip.
        ;; [Or in roughly 16 sub-versions of them, and they have common subroutines
        ;;  that do much of the work.]

        ;; Incidentally, I could also use stuff in the mask to indicate
        ;; which register is the pointer to the memory being allocated.
        ;; 

        ;; mov r8, rdi ;fuckhead
        ;; mov rdi, ALLOCPTR
        
        mov r8, ALLOCPTR
        add ALLOCPTR, 48
        cmp ALLOCPTR, OURSPACE_TOP
        jl eval_if_proceed
        mov rax, SOME_MASK
        call gc_work_or_flip 


eval_if_proceed:
        lea rax, [eval_if_k1]
        mov [r8 + 40], CONT
        lea CONT, [r8 + CLOS_TAG]
        mov [r8 + 32], DYN
        mov [r8 + 24], rsi      ;e
        mov [r8 + 16], rcx      ;rest
        mov [r8 + 8], rdx       ;b
        mov [r8], rax
        ;; now we call ueval: x e d k1 are already in place.
        jmp ueval


eval_if_k1_move_slot:
        resq 1

        ;; CLOS contains [code b rest e d k]
        ;; rdi will be, um...
        ;; ah, return value in rax. roight.
eval_if_k1:
        mov CONT, [CLOS - CLOS_TAG + 40]
        mov DYN, [CLOS - CLOS_TAG + 32]
        mov rsi, [CLOS - CLOS_TAG + 24]
        cmp rax, GLOBAL_NIL
        cmove rdi, [CLOS - CLOS_TAG + 16]
        je eval_if              ;alternate
        mov rdi, [CLOS - CLOS_TAG + 8]
        jmp eval                ;consequent

eval_if_k1_move:        
        ;; < move a closure with five elements,
        ;;   one of which is a dyn-tree (which should just mean
        ;;   a cons, so no issue there), and put the corpse with its
        ;;   ... >
        ;; Um.
        ;; I suppose that for *most* data structures, when you move them,
        ;; you'll need to trace them later.
        ;; Hmm...
        ;; [The question in my head is basically whether 


        ;; Hmm...
        ;; Code that moves stuff does know where you keep your gc-next ptr.
        ;; So, 

        ;; dick in CLOS?
        ;; maybe "move" will trace closures by putting them in CLOS.
        ;; yeah, that's ...
        ;; hmm, that's interesting.
        ;; meanwhile, it seems it'd be simple and pretty definitely the right
        ;; thing (like, strictly better) to have the canonical location of gc-next,
        ;; when you are moving an object, be in a register rather than in memory.
        ;; however, in general it'd probably be good to have it in memory.
        ;; so moving should begin with a mov like that.
        ;; and end with the anti-mov.
        ;; [and then it could turn out I could spare a register for gc-next in general]
        ;;

        ;; ...
        ;; I think it is generally a good idea to move things in rdi.




        
        ;; Ok.
        ;; Moving mode is a thing.
        ;; When in moving mode, gc-next is in a register.
        ;; Also, rdi will contain either a pointer to be moved or a pointer that
        ;; has been moved.
        ;; Also, rax will be in danger (used by cmpxchg, too lazy).


        ;; An external-ish procedure.
        ;; So...
        ;; move_rdi, move_rsi, move_rdx, and so on will call move_rdi.
        ;; (well, move_rdi itself will not)
        ;; These are procedures that will assume we're not in moving mode,
        ;; and will put us into moving mode.
        ;; [... I can see how a read barrier, when it gets invoked, could slow down
        ;;  the program by a lot.  This crap could be ameliorated by (a) keeping
        ;;  gc-next in a register always--though that might cause issues with
        ;;  multithreading (Oh man you could have a signal that says "Dump your
        ;;  gc-next into your memory slot designated for this purpose"--that would
        ;;  be very simple and could work well...), to avoid the load and store,
        ;;  (b) inlining all crap into "move_rsi", "move_rdx", and so on, to
        ;;  avoid the register swaps, ... (c) already knowing where the tag is,
        ;;  to avoid the TAG_INTO (a MOV and an AND)... 

move_rdi:
        MAYBE_MOVE_GC_NEXT_INTO_REGISTER

        TAG_INTO rdi, rax
        ;; call [rax*8 + move_jump_table]
        ;; ret
        jmp [rax*8 + move_jump_table]
        
        ;; wow, if all that is done, then...
        ;; the MOVE can be incredibly simple...
        ;; just a f'n call, and move_rdi doesn't need to be a subroutine.
        ;; wow.
        ;; that's amazing.
        ;; ok, that demands immediate action.
        ;; --oh wait one problem.
        ;; the things in the move_jump_table will probably
        ;; need to be, like, rdi-specific or something.
        ;; (they assume the ptr is in rdi)
        ;; ... the move_jump_table will probably be big:
        ;; [# types] * 8 bytes.
        ;; probably don't want a bunch of copies of that.
        ;; perhaps I could get away with just a couple of copies.
        ;; neh...
        ;; ... k, fine, rdi will be a thingy.
        ;; (i.e. will be treated somewhat specially for performance)
        ;; I could maybe make a macro that would whatever.


        MAYBE_MOVE_GC_NEXT_BACK_INTO_MEMORY




        
        
eval_if_k1_trace:
        ;; this assumes gc-next is in its gc-next-temp place
        



eval_if_k1_move_slot2:
        resq 1
        
        ;; this takes the same args as eval_if_k1.
        ;; I suppose that means rax and CLOS.
eval_if_k1_trace_and_execute:
        ;; < trace the closure, then install eval_if_k1 in the code ptr>
        ;; call eval_if_k1_move    ;if args are in the right place ;no
        call eval_if_k1_trace   ;if args are in the right place
        
        









        ;; oh no, another philosophical crisis
        ;; if we are indeed more glib about allocation,
        ;; then read barriers must ...
        ;; must be prepared to do a GC flip and to save/move registers afterward.
        ;; .......
        ;; that'd be terrible if that meant more instructions.
        ;; here, flexible memory would be very useful.
        ;; ...
        ;; ...
        ;; ok.
        ;; if I use inflexible memory,
        ;; then I must do that "gc flip at 80%" thing, and otherwise be very strict.
        ;; either that or be extremely intelligent, and have annotations in a table
        ;; somewhere containing information about register use at a given code thing.
        ;; I think I'm not that ambitious yet (and it would complicate things for
        ;;  someone adding his own code).
        ;; if not, then ...

        ;; can I write shit with macros, and then deal with dick later?
        ;; yes. I shall enforce that.
        

        ;; Ok, this is going to be a fucking subroutine.
        ;; Either because we're using flexible memory, so a read barr can
        ;; just allocate willy-nilly,
        ;; or because we're using careful flagellation, so a read barr is
        ;; guaranteed to have enough space,
        ;; or because the system is sufficiently clever (e.g. with annotations in
        ;;  some table for code blocks) that the gc flip can look at the return
        ;; address and determine what things are ptrs that must be moved.
        ;; The conclusion being that I don't need to write, for read barriers,
        ;; something about what registers must be saved.

        ;; so dynvars are user_tag = [tag int val].
        ;; and the dyn-tree is ... probably conses, poss. untagged...
        ;; neh, use fuckin' cons cells.
        ;; anyway, it's bas. an assoc of int -> val.
        ;; a more advanced impl. might make it a tree or smthg.
        ;; ...
        ;; ok, so.
        ;; DYN = list of stuff.
        ;; car.dyn = (cons int val).
        ;; right.
        
        ;; rdi = x, DYN = d.
        

        ;; I could probably have a lazy "remove useless dicks" thing.
        ;; but anyway.
        ;; ...
        ;; return value in rdi. it's a subroutine.
        ;; -- no type checks.
        ;; -- probably don't want to kill DYN
        ;; -- actually don't kill anything except rdi.
        
dyn_lookup:
        cmp DYN, GLOBAL_NIL
        je dyn_lookup_else

        push rsi
        push rdx
        push rcx
        mov rsi, [rdi - USER_TAG + 8] ;the int
        mov rdx, DYN

dyn_lookup_loop:
        CAR_INTO rdx, rcx
        cmp rsi, [rcx - CONS_TAG + 8] ;know it contains an integer, no barr
        je dyn_lookup_found

        CDR_INTO rdx, rdx
        
        cmp rdx, GLOBAL_NIL
        jne dyn_lookup_loop

        pop rcx
        pop rdx
        pop rsi

dyn_lookup_else:
        mov rdi, [rdi - USER_TAG + 16] ;the plain val
        ret
        
dyn_lookup_found:
        CDR_INTO rcx, rdi
        pop rcx
        pop rdx
        pop rsi
        ret

        ;; ahhh, some nice assembly.

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


        ;; btw the word of God (or a random thought) sez functions written here
        ;; should accept rest-args as register-args, and it is uapply that will
        ;; have to do any parsing
        
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
        


        