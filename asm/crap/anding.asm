
        ;; ok so this takes rdi = destination buffer,
        ;; [rdi] = len of dest buffer (and the assumed length of resulting cycle),
        ;; [rdi+8] = number of cycles to AND together,
        ;; rsi rdx rcx r8 r9 = cycles. (cycles are linked lists in buffers)


        mov rax, 0xfffefafd

        ;; we'll get some number of cycles and a destination buffer
        ;; and put the ANDed cycles into the destination buffer.
        ;; (its len = lcm of cycles' lens)
        ;; how many cycles? ...
        ;; either I can write code for 2 cycles, code for 3 cycles, ...,
        ;; or I could accept that as a parameter, accept a vector of cycles,
        ;; and loop through that vector each time (indirect memory references)...

        ;; this would be a good time to generate code that handled n cycles
        ;; and run that code. that'd be best. but no.

        ;; time to run a bunch of versions. mechanically pre-generated code isn't
        ;; all that much worse than mechanically-generated-at-runtime code.

        ;; Model.
        ;; How should shit be passed? Since we expect to handle shit in registers,
        ;; pass in registers. Destination is the first argument, which is also rdi.
        ;; Length? Testing? ... Either could test directly, or caller should pass
        ;; the length.
        ;; Length will be the first field in the destination buffer, which will be
        ;; overwritten. Hah. That is awesome.

        ;; ... As a bonus... I think I don't need to save any things. --'Cept RBX.

        ;; Fuck, how do I encode the number of cycles passed?
        ;; Answer: Put that as the second word in the destination buffer.
        ;; Jesus christ.

        ;; ... FUCK. Turns out Microsoft x64 calling convention is different.
        ;; I suppose I'll just save everything.
        ;; How the fuck would I parse arg... fuck.  Jesus.  Fuck.
        ;; ... Oh well. Anyone who wants to use this crap with Windows will have
        ;; to figure out how to pass arguments himself.

        ;; Goddammit, can't figure out a non-terrible way to pass offsetted byte-string
        ;; pointers to asm code. The options seem to be Eli Barzilay's trick of making
        ;; a pointer that contains a pointer (and putting it in a "thread-cell" so there
        ;; aren't multithreading problems), or figuring out some horrible way to offset
        ;; Racket pointers (unsafe-fx+ seems to cause segfaults), or passing things in
        ;; separate arguments (gargh, we hate extra arguments and the stack--we'd have
        ;; to add more shit to run-code, or perhaps try to figure out varargs), or
        ;; wrapping shit (ptr+offset is passed as (list ptr offset)).
        ;; I think I'm going for wrapping shit.

        ;; NOPE FUCK it is difficult to encode a ptr as a sequence of bytes.
        ;; And even if I did, ... GC problems. Don't want to run into the same problem
        ;; as Eli Barzilay's original thing.
        ;; Meanwhile, what I could do is bytes-append an offset to the start.
        ;; However, that will construct a completely new byte-string, and if I want it to
        ;; be like I've modified the original byte-string, I'll have to subbytes that.
        ;; This involves creating two extra byte-strings that become garbage (or making
        ;; one of the original ones garbage and one of the new ones).
        ;; Since a major use case is modifying a large byte-string, this is really bad.
        ;; So... Options are either passing them separately or handling giant byte-strings.
        ;; The former option seems to suffice for the moment.

        ;; So. Game plan. Make a large bytes. Since racket initializes it anyway, I may
        ;; as well initialize it to 0b10101010..., aka 0xaaaa... .  Then I can use btr to
        ;; get ... Or maybe I'll initialize to 0xffff and include 2.  Mmm.
        ;; No, 2 must be special-cased... k.
        ;; Use btr to get the primes up to, say, 100 or 200, and put them into nice groups
        ;; and make cycles with them.
        ;; For now, I'll try <=.5 MB per combined-cycle.

                ;; SAVING EVERYTHING BUT RAX, RSP
        pushfq
        push rbx
        push rcx
        push rdx
        push rdi
        push rsi
        push rbp
        push r8
        push r9
        push r10
        push r11
        push r12
        push r13
        push r14
        push r15

        
        mov rbx, [rdi]
        mov r10, rbx            ;later use... Only 1-5 cycles shall be used.

        mov r11, [rdi+8]

        ;; mov r12, 23

        ;; mov rax, r11
        ;; jmp return
        
        cmp r11, 1
        je and_1cycles
        cmp r11, 2
        je and_2cycles
        cmp r11, 3
        je and_3cycles
        cmp r11, 4
        je and_4cycles
        cmp r11, 5
        je and_5cycles

silly:
        mov rax, r10
        sub rax, rbx
        jmp return


and_1cycles:
        
        mov rax, [rsi]
        add rsi, [rsi+8]

        mov [rdi], rax
        mov qword [rdi+8], 16
        add rdi, 16
        dec rbx
        jnz and_1cycles
        
        jmp afterwards

and_2cycles:
        mov rax, [rsi]
        add rsi, [rsi+8]
        and rax, [rdx]
        add rdx, [rdx+8]

        mov [rdi], rax
        mov qword [rdi+8], 16
        add rdi, 16
        dec rbx
        jnz and_2cycles
        jmp afterwards

and_3cycles:
        mov rax, [rsi]
        add rsi, [rsi+8]
        and rax, [rdx]
        add rdx, [rdx+8]
        and rax, [rcx]
        add rcx, [rcx+8]

        mov [rdi], rax
        mov qword [rdi+8], 16
        add rdi, 16
        dec rbx
        jnz and_3cycles
        jmp afterwards

and_4cycles:
        mov rax, [rsi]
        add rsi, [rsi+8]
        and rax, [rdx]
        add rdx, [rdx+8]
        and rax, [rcx]
        add rcx, [rcx+8]
        and rax, [r8]
        add r8, [r8+8]

        mov [rdi], rax
        mov qword [rdi+8], 16
        add rdi, 16
        dec rbx
        jnz and_4cycles
        jmp afterwards

and_5cycles:
        mov rax, [rsi]
        add rsi, [rsi+8]
        and rax, [rdx]
        add rdx, [rdx+8]
        and rax, [rcx]
        add rcx, [rcx+8]
        and rax, [r8]
        add r8, [r8+8]
        and rax, [r9]
        add r9, [r9+8]

        mov [rdi], rax
        mov qword [rdi+8], 16
        add rdi, 16
        dec rbx
        jnz and_5cycles
        jmp afterwards

        ;; Source code for your pleasure.
        ;; arc> (pbcopy:tostring:with (s "\n        " r '(nothing rsi rdx rcx r8 r9)) (for k 1 5 (pr "and_" k "cycles:") (for i 1 k (pr s (if (is i 1) "mov" "and") " rax, [" r.i "]" s "add " r.i ", [" r.i "+8]")) (prn) (prn s "mov [rdi], rax" s "mov qword [rdi+8], 16" s "add rdi, 16" s "dec rbx" s "jnz and_" k "cycles" s "jmp afterwards") (prn)))


        
and_two_cycles:
        mov rax, [rsi]
        add rsi, [rsi+8]        ;these are relative linked lists, so add
        and rax, [rdx]
        add rdx, [rdx+8]

        mov [rdi], rax
        mov qword [rdi+8], 16   ;goddammit, must specify size; also why not movq?
        add rdi, 16
        dec rbx
        jnz and_two_cycles
        jmp afterwards



afterwards:
        ;; rdi =  after last cons cell in byte-buffer
        
        shl r10, 4              ;jesus christ
        sub r10, 16             ;dist to start
        neg r10
        mov [rdi-8], r10
        
return:
        pop r15
        pop r14
        pop r13
        pop r12
        pop r11
        pop r10
        pop r9
        pop r8
        pop rbp
        pop rsi
        pop rdi
        pop rdx
        pop rcx
        pop rbx
        popfq
        
        ret