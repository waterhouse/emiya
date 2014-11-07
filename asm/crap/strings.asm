


        ;; Ok, so.
        ;; Strings have some tag.
        ;; Defined elsewhere.
        ;; Since this is single-threaded, we don't have to worry about locks or CAS or the ABA problem or LDREX/STREX.
        ;; So.
        ;; string=[parent][hole][len-ish][data ...]

        ;; We'll need to do some ... stuff...
        ;; So........
        ;; Sometimes the size of the string may be in the code...
        ;; I think 99% of the time it'll be a variable, found in a register.
        ;; Well, let's see.
        ;; The size should be a uint.
        ;; We might do the usual partially-inlined thing,
        ;; or might have a subroutine call.
        ;; Either way it should be invoked with a macro, methinks.
        ;; Two arguments: dst, size.

        %macro string 2         ;%1 better not be rax
        lea %1, [ALLOCPTR + STRING_TAG]
        ;; must round up
        ;; also must account for extra fields
        ;; add %2, 56              ;+24*2 + 8
        ;; and %2, -16             ;+24*2 rounded
        ;; shr %2, 1               ;+24 rounded ;the speed of this and alternatives has not been tested
        ;; no, we need the length unmodified to install into the string...
        lea rax, [%2 + 56]
        and rax, -16
        shr rax, 1
        add ALLOCPTR, rax
        lea r15, [alloc_return_%[alloc_count]]
        cmp ALLOCPTR, PAGELIMIT
        ja alloc_overflow_%1
alloc_return_%[alloc_count]:
        mov [%1 + STRING_LENGTH], %2
        mov [%1 + STRING_PARENT], qword 0
        mov [%1 + STRING_HOLE], qword 0 ;....... whatever
        %endmacro

        ;; These things shall have the tag encoded...
        %assign STRING_PARENT   (0 - STRING_TAG)
        %assign STRING_HOLE     (8 - STRING_TAG)
        %assign STRING_LENGTH   (16 - STRING_TAG)
        %assign STRING_CONTENTS (24 - STRING_TAG)
        ;; Am both using "assign" and parenthesizing.  Unnecessary.  Oh well.

        ;; Access.
        ;; Heh heh heh.
        ;; Here I will want to test various approaches...
        ;; We don't need a read barrier, but we do need a type check.
        ;; ...
        ;; In practice, probably shit much different from this should be used.
        ;; (E.g.: if you loop through a string, type-checking should be done
        ;;  once, getting the length should be done once, worrying about whether
        ;;  the string is fully copied over should be done probably once or at
        ;;  least only a few times, etc.  Also, of course, you should probably
        ;;  be incrementing a pointer, and at the very least should not be doing
        ;;  a shift-right on every access.  [Useful that chars are tagged 100.])
        ;; However, this is for lazy fucks like me who just want a thing to work at all.
        ;; This won't even destroy the source or offset operands.

        ;; It would be possible, of course, to represent strings with a pointer to their
        ;; contents, and find the other fields behind them or something.
        ;; (However, it is just as cheap to add -STRING_TAG as it is to add -STRING_TAG+24.)
        ;; It also would be possible to put the length fields earlier or something.
        ;; But neh.
        ;; Don't think it really makes a difference, so will maintain consistency.
        
        ;; dest, src, offset
        ;; %macro string_ref 3
        ;; mov rax, %2             ;should be, like, an 8-bit register
        ;; and al, 7
        ;; test al, STRING_TAG
        ;; jne type_error
        ;; mov rax, %3
        ;; shr rax, 1
        ;; mov %1, [rax + %2       ;... geh, still must strip the type tag

        ;; Dear god.
        ;; Ok, let's see.
        ;; THe following lacks a type check.
        ;; dst, src
        %macro string_len 2
        mov rax, [%2 - STRING_PARENT]
        cmp rax, 0
        lea r15, [%%done]
        jne string_other_len_%1
        mov %1, [%2 - STRING_LENGTH]
%%done:
        %endmacro

        %macro define_string_other_len 1
string_other_len_%1:
        mov %1, [rax - STRING_LENGTH]
        jmp r15
        %endmacro

        ;; Well, there's one strategy, anyway.
        ;; (For multithreading, it is critical to get the len after checking that parent = 0.)
        ;; ... Another approach would be to have the "hole" field be used as a "full length"
        ;; field.
        ;; Well, mmm.

        ;; And that's if I want the user-transparent length.
        ;; Feh.
        
;;         ;; dest, src, offset=uint
;;         ;; these must be different...
;;         %macro string_ref 3
;;         cmp %3, 0
;;         jl string_ref_error
;;         lea rax, [%2 + STRING_CONTENTS]
;;         test rax, 7
;;         jnz type_error
;;         mov r15, %3
;;         shr r15, 1
;;         cmp %3, [%2 + STRING_LENGTH]
;;         jl %%win
;;         ;; check the other half if exists
;;         mov %1, [%2 + STRING_PARENT]
;;         cmp %1, 0
;;         jz string_ref_error
;;         cmp %3, [%1 + STRING_LENGTH]
;;         jnl string_ref_error
;;         add %1, STRING_CONTENTS
;;         mov %1, [%1 + r15]
;;         jmp %%done
;; %%win:
;;         mov %1, [rax + r15]
;; %%done:
;;         ;; still need to tag it
;;         shl %1, 3
;;         or %1, CHAR_TAG
;;         %endmacro

        ;; that's terrible.
        ;; I think it might be right, though.
        ;; wait, no.
        ;; the destination has to be a 32-bit register.
        ;; fuck.
        ;; .... the "altregs" thing doesn't provide all the things I'd want.
        ;; hmm, well.

        ;; just in case.

        ;; arc> (pbcopy:tostring:each reg '(ax bx cx dx di si bp sp) (each pre '(r e "") (each (suff p s) '((b "" l) (l "" l) (w "" "") (d e "") (q r "")) (withs alias (string pre reg suff) output (if (and (is string.reg.1 #\x) (is s 'l)) reg (string p reg s)) (unless (is alias output) (prn "        %idefine " alias " " output))))))

        ;; Well, actually...
        ;; I guess I can do something similar to what x264/x265 does.

        %macro define_suffix 2

        %idefine r%1q r%1
        %idefine e%1q r%1
        %idefine r%1d e%1
        %idefine e%1d e%1
        %idefine r%1w %1
        %idefine e%1w %1
        %idefine r%1b %2
        %idefine e%1b %2

        %endmacro

        define_suffix ax, al
        define_suffix bx, bl
        define_suffix cx, cl
        define_suffix dx, dl
        define_suffix bp, bpl
        define_suffix sp, spl
        define_suffix di, dil
        define_suffix si, sil

        ;; dest, src, offset=uint
        ;; these must be different...
        %macro string_ref 3
        cmp %3, 0
        jl string_ref_error
        lea rax, [%2 + STRING_CONTENTS]
        test al, 7
        jnz type_error
        mov r15, %3
        shr r15, 1
        cmp %3, [%2 + STRING_LENGTH]
        jl %%win
        ;; check the other half if exists
        mov %1, [%2 + STRING_PARENT]
        cmp %1, 0
        jz string_ref_error
        cmp %3, [%1 + STRING_LENGTH]
        jnl string_ref_error
        add %1, STRING_CONTENTS
        mov %1d, [%1 + r15]     ;32-bit!
        jmp %%done
%%win:
        mov %1d, [rax + r15]    ;32-bit!
%%done:
        ;; still need to tag it
        shl %1, 3
        or %1b, CHAR_TAG
        %endmacro

        
        
string_ref_error:
        mov rax, 2581
        jmp return


        ;; As for comparing two strings.
        ;; Jesus christ.
        ;; Well, let's have a subroutine.
        ;; Maybe a term for "making sure it's all in one place"...
        ;; De-corpsing?
        ;; Inheriting?
        ;; Canonicalizing?
        ;; Also, in the totally general case, what you probably want is to iterate
        ;; over a vector and, rather than comparing some "count until end" with 0,
        ;; instead comparing some "count until either end or need to move more shit"
        ;; with 0.
        ;; ... The x86 BS of using [reg + reg] as an index lets me obviate some concerns
        ;; about how I might want to bump up a pointer...
        ;; (Cases for which that would actually dominate the total time are also cases
        ;;  that probably allocate no memory, though.)
        ;; Well, anyway.

        %macro canonicalize 1   ;is string; need to write similar for vector, bytevector
        mov rax, [%1 + STRING_PARENT]
        cmp rax, 0
        lea r15, [%%done]
        jne canonicalize_code
%%done:
        %endmacro

        ;; corpse in rax, ret in r15
        ;; let's save all registers we use
canonicalize_code:      
        push r15
        push rdi
        push rsi
        push rcx

        ;; We could think about being supplied a maximum number of bytes to move.
        ;; And have this be a subroutine or whatever.
        ;; Anyway.
        mov r15, [rax - STRING_TAG] ;fwd ptr
        btr r15, 63                 ;heir
        mov rcx, [rax + STRING_LENGTH] ;corpse length
        mov rdi, [r15 + STRING_LENGTH] ;heir length, also offset for copy ptrs
        sub rcx, [r15 + STRING_LENGTH] ;bytes needed to move
        jle canonicalize_ret
        ;; so, now...
        ;; rdi will be the index
        ;; actually... it needs to be an offset, which means:
        sub rdi, STRING_TAG
        ;; rsi will be the temporary thing
        ;; (these could be switched around for REP MOVD purposes or smthg, but not now)
        ;; the copying could be done a qword at a time with a Duff's device kind of thing,
        ;; but whatever
canonicalize_loop:
        mov esi, [rax + rdi]
        mov [r15 + rdi], esi
        add rdi, 4
        sub rcx, 4
        jg canonicalize_loop
canonicalize_ret:
        pop rcx
        pop rsi
        pop rdi
        ret                     ;lel
        

        

        ;; ... there are repeat prefixes...
        ;; fuck that.
        ;; args in rdi, rsi.
        ;; destroys rax as well as r15.
        ;; return value in RFLAGS.
        ;; ...
        ;; 
        
strcmp: 
        canonicalize rdi
        canonicalize rsi
        ;; lazy as fuck.
        ;; now, these will actually be correct
        mov rax, [rdi + STRING_LENGTH]

        ;; ACTUALLY WE'VE REPURPOSED R15 AND R14 SO LET'S REDO THE ABOVE

        
        
        


        ;; The thing is...
        ;; If you try to allocate a giant string.
        ;; Under current scheme, you'll get a "jmp complain_to_the_management" about it
        ;; if you do that while GC work is happening.
        ;; Choices for how the system could respond to that...
        ;; - Die
        ;; - Do as much GC work as needed, possibly causing a big pause
        ;; - Grab more memory from the OS
        ;; - Have virtual memory grab more memory as desired, and hope GC catches up
        ;; (both of the preceding require reworking "semispaces")
        ;; (then there's freeing excess memory)
        ;; Anyway...
        ;; At the moment I don't intend to 


        ;; My brain has remembered a fundamental fact.
        ;; At least for vectors, they must be zeroed upon allocation, taking O(n) time.
        ;; So doing that GC work.....
        ;; Think about how fast the working set may grow given certain things...
        

        
