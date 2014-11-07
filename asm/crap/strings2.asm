


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
        ;; and we need the length unmodified to install into the string...
        lea rax, [%2 + 56]
        and rax, -16
        shr rax, 1
        add ALLOCPTR, rax
        lea r11, [alloc_return_%[alloc_count]]
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
        lea r11, [%%done]
        jne string_other_len_%1
        mov %1, [%2 - STRING_LENGTH]
%%done:
        %endmacro

        %macro define_string_other_len 1
string_other_len_%1:
        mov %1, [rax - STRING_LENGTH]
        jmp r11
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
;;         mov r11, %3
;;         shr r11, 1
;;         cmp %3, [%2 + STRING_LENGTH]
;;         jl %%win
;;         ;; check the other half if exists
;;         mov %1, [%2 + STRING_PARENT]
;;         cmp %1, 0
;;         jz string_ref_error
;;         cmp %3, [%1 + STRING_LENGTH]
;;         jnl string_ref_error
;;         add %1, STRING_CONTENTS
;;         mov %1, [%1 + r11]
;;         jmp %%done
;; %%win:
;;         mov %1, [rax + r11]
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
        mov r11, %3
        shr r11, 1
        cmp %3, [%2 + STRING_LENGTH]
        jl %%win
        ;; check the other half if exists
        mov %1, [%2 + STRING_PARENT]
        cmp %1, 0
        jz string_ref_error
        cmp %3, [%1 + STRING_LENGTH]
        jnl string_ref_error
        add %1, STRING_CONTENTS
        mov %1d, [%1 + r11]     ;32-bit!
        jmp %%done
%%win:
        mov %1d, [rax + r11]    ;32-bit!
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
        lea r11, [%%done]
        jne canonicalize_code
%%done:
        %endmacro

        ;; corpse in rax, ret in r11
        ;; let's save all registers we use
canonicalize_code:      
        push r11
        push rdi
        push rsi
        push rcx

        ;; We could think about being supplied a maximum number of bytes to move.
        ;; And have this be a subroutine or whatever.
        ;; Anyway.
        mov r11, [rax - STRING_TAG] ;fwd ptr
        btr r11, 63                 ;heir
        mov rcx, [rax + STRING_LENGTH] ;corpse length
        mov rdi, [r11 + STRING_LENGTH] ;heir length, also offset for copy ptrs
        sub rcx, [r11 + STRING_LENGTH] ;bytes needed to move
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
        mov [r11 + rdi], esi
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
        ;; destroys rax as well as r11.
        ;; return value in RFLAGS.
        ;; ...
        ;; also, what will be immediately useful is not exactly strcmp,
        ;; which officially determines ordering, but str-equal, which just
        ;; 
        
strcmp: 
        canonicalize rdi
        canonicalize rsi
        ;; lazy as fuck.
        ;; now, these will actually be correct
        ;; let's see.
        ;; in some domains, most likely the strings will be different,
        ;; and we'll find a mismatch usually in the first character or few.
        ;; in others, the strings will likely be the same.
        ;; in a few, they'll be the same a lot but differ at the end...
        ;; anyway, I'm going to not take pains to record which string is
        ;; shorter, and determine that at the end if it's necessary, which
        ;; it most likely will not be.
        mov r11, [rdi + STRING_LENGTH]
        mov rax, [rsi + STRING_LENGTH]
        cmp rax, r11
        cmovl r11, rax          ;we take the shorter length
        cmp r11, 0
        mov r10, STRING_CONTENTS
        je strcmp_loop_done
        test r11, 7
        jnz str_has_malformed_length_field
strcmp_loop:
        mov eax, [rdi + r10]
        cmp eax, [rsi + r10]
        jne plain_ret           ;bahaha
        add r10, 4
        sub r11, 8
        jnz strcmp_loop         ;beautiful

strcmp_loop_done:
        ;; they've been equal so far.
        ;; in that case, if they're equal length, then they compare equal;
        ;; otherwise, the shorter one is "less".
        mov rax, [rdi + STRING_LENGTH]
        cmp rax, [rsi + STRING_LENGTH]
        ret                     ;bretty good

        
        ;; eq is a bad name, because this is more than a pointer comparison.
        ;; however, there is never a need for
        ;; anyway.
        ;; rdi, rsi args.
        ;; ret in ZF.
str_eq: 
        canonicalize rdi
        canonicalize rsi

        mov r11, [rdi + STRING_LENGTH]
        cmp r11, [rsi + STRING_LENGTH]
        jne plain_ret           ;the flags will still be set after return
        ;; ok, so.
        ;; we can use r11 for counting down.
        ;; then I suppose we should keep rdi and rsi intact.
        ;; so use r10 as an index, and rax/eax to hold intermediate shit.

        cmp r11, 0
        mov r10, STRING_CONTENTS
        je plain_ret            ;again, will have correct flags
        ;; Um, we're going to make a hard assumption that the length is correctly
        ;; a uint, a multiple of 8.
        ;; Actually...
        test r11, 7
        jnz str_has_malformed_length_field
str_eq_loop:    
        mov eax, [rdi + r10]
        cmp eax, [rsi + r10]
        jnz plain_ret           ;so good
        add r10, 4
        sub r11, 8
        jnz str_eq_loop
        ret                     ;eq flags

str_has_malformed_length_field:
        mov rax, 66631
        jmp return




        ;; Other library shit.

        ;; arg in rdi.
        ;; ret in ... eh, could go for rax or rdi...

        ;; so, there are philosophical issues.
        ;; in this case, chars_to_string will create a string,
        ;; and consequently may trigger a GC flip.
        ;; what to trace?
        ;; the mere address of this will not have any relation to the "parent"
        ;; who called this.
        ;; so.
        ;; probably it'll be, as decided before, parent must save anything it wants to
        ;; save on the stack before calling an allocing subroutine like this one.
        ;; alternate schemes are possible, but this is what I shall start with.
        ;; meanwhile.
        ;; this will call "length" as a subroutine.
        ;; which probably should not destroy its arg, and should return in rax.
        ;; so.

        ;; let's see.
        ;; alloc_overflow crap doesn't destroy r10.
        ;; so we could use that to pass the length to the string construction

        ;; oh dear.
        ;; so.
        ;; I am being forced to confront something.
        ;; a thing that I did, above, puts shit with certain type tags into a register
        ;; and leaves it there.
        ;; meanwhile, I'm about to write a thing that thinks maybe it should save the
        ;; contents of some register on the stack, or something, so that it can use
        ;; that register.
        ;; but, given the above, that would be terribly destructive.
        ;; so, no.
        ;; "this subroutine doesn't save registers, you have to save GCed values on the
        ;;  stack" means "this actually will destroy zero or more non-saved registers".
        ;; anyway, meanwhile, this 
chars_to_string:
        call list_length             ;rdi -> rax, leaves rdi intact
        ;; mov r10, rax                 ;this is a bit terrible; oh well
        ;; you know, I'm not confident that the GC flip and stuff won't destroy r10
        mov rdx, rax
        mov rsi, rdi
        saving rsi
        string rdi, rdx
        ;; now, we are going to assume that no one has changed the list.
        ;; (otherwise we might overflow the string, 'cause we're not checking its length)
        mov rcx, STRING_CONTENTS   
        cmp rsi, [nil]
        je plain_ret
chars_to_string_loop:
        car r8, rsi
        ;; do we check it's a char?
        ;; sure.

        %macro tck 2
        mov al, %1b             ;hell yeah
        and al, 7
        cmp al, %2
        jne type_error
        %endmacro
        
        tck r8, CHAR_TAG
        shr r8d, 3
        mov [rdi + rcx], r8d
        cdr rsi, rsi
        add rcx, 4
        cmp rsi, [nil]
        jne chars_to_string_loop
        ret


        ;; nil had better not have been created using chars_to_string

        ;; arg in rdi, ret in rax
        ;; no current "tortoise and hare" anti-cycle countermeasures
        ;; probably destroy rsi to put nil in a register
        ;; ... let's save rdi.  stack.
        ;; --neh.
        ;; we could also save rcx.  this won't trigger a GC flip, so that wouldn't be
        ;; harmful.  eh.  whatever.
list_length:
        mov rsi, [nil]
        xor ecx, ecx
        cmp rdi, rsi
        je list_length_ret
        mov rdx, rdi
list_length_loop:
        add rcx, 8
        cdr rdx, rdx
        cmp rdx, rsi
        jne list_length_loop
list_length_ret:
        mov rax, rcx
        ret


        ;; A few possible ways to print strings.
        ;; One would be to convert to a C string--and either implement byte strings or put
        ;; it on the stack or something (or just put it after ALLOCPTR, assuming there's room,
        ;;  without bumping up ALLOCPTR), and then call write.
        ;; Another is to call putchar a bunch.
        ;; The latter is easier, so I'll do it for now.
        ;; Save everything. --Including rdi.
        ;; arg in rdi.
print_string:
        canonicalize rdi
        c_save
        push r14
        push r15
        push rdi
        mov r14, [rdi + STRING_LENGTH]
        lea r15, [rdi + STRING_CONTENTS]
        cmp r14, 0
        je print_string_ret
        ;; won't bother this time to check for bad-length strings
        ;; ... ok, fine, will.
        test r14, 7
        jnz str_has_malformed_length_field
print_string_loop:
        mov edi, [r15]
        call [putchar]
        add r15, 4
        sub r14, 8
        jnz print_string_loop
        
print_string_ret:
        pop rdi
        pop r15
        pop r14
        c_restore
        ret


        ;; Use like this:
        ;; call literal_string
        ;; db "whatever", 0
        ;; ... return value in rax ...
        ;; [might write a macro that puts the 0 automatically]
        ;; A trick from Randall Hyde's book.
        ;; --Since we'll be allocing (btw this will likely be called
        ;;  very early in any program, although such a program could be
        ;;  loaded late in the lifetime of the runtime process...),
        ;; we shall be unrestrained in our destruction of registers.
literal_string:
        ;; The top of the stack contains the return address,
        ;; which is also the beginning of the string.
        ;; We may assume the string has ... no, we may not assume it has
        ;; nonzero length.
        ;; Ok, first, compute the length.
        mov rdi, [rsp]
        mov rsi, 0
length_loop:
        cmp byte [rdi], 0
        je literal_string_make
        add rsi, 8
        inc rdi
        jmp length_loop
        ;; rsi contains length
        ;; [rsp] is the original string pointer
literal_string_make:
        saving 0
        string rdi, rsi
        mov rcx, [rsp]
        ;; also, we need to update the return address.
        ;; currently it's the start of the string.
        ;; the "length" we computed does not include the 0 byte at the end.
        ;; so we need to bump it up by that plus one.
        shr rsi, 3
        add [rsp], rsi
        inc qword [rsp]
        ;; and we must note that the length is now not a uint
        mov rdx, STRING_CONTENTS ;index
        xor eax, eax
        cmp rsi, 0
        je plain_ret
literal_string_install_loop: 
        mov al, [rcx]
        mov [rdi + rdx], eax
        add rdx, 4
        inc rcx
        dec rsi
        jnz literal_string_install_loop
        ret


        
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
        

        
