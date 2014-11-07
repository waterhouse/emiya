

        mov rax, 0xfffefafd

        ;; We use Fibonacci to test the speed of CALL vs PUSH;JMP.
        ;; Also, might as well: RET vs POP;JMP.
        ;; (This will test raw speed. Cache effects due to shorter
        ;; code... jesus christ, how will I ever test that well.)


        ;; rdi = n, rsi = mode


        mov rax, rdi
        
        cmp rsi, 0
        je fib_call
        cmp rsi, 1
        je fib_pushjmp

        ;; Lolz, jesus. What's the best way?
        ;; There will be fib(n) calls with n=0 and n=1,
        ;; and with everything bigger than that...
        ;; fib(n-2) + fib(n-3) + fib(n-4) + ... + fib(0).
        ;; I suspect that's always 1 less than fib(n).
        ;; Yup.
        ;; Jesus.
        ;; (derf, I forgot that popping = adding to SP)

        ;; Gw'oh fuck, it turns out that the stack provided to us is pretty small.
        ;; OH WAIT NO
        ;; Actually I was just stupid; fib(200) is large.
        ;; (It sucks when infinite loop is difficult to distinguish from "terrible errors".)

dumb_dick:
        mov rax, 23
        ret

fib_call:
        cmp rax, 2
        jl return
        dec rax
        push rax
        call fib_call
        xchg rax, [rsp]
        dec rax
        call fib_call
        add rax, [rsp]
        add rsp, 8
        ret


        ;; Now this will probably be a little difficult.
        ;; I'm sure that the assembled dick here will have 0000's
        ;; where that pointer should go. That pointer is a memory address,
        ;; and thus only known at or around runtime.
        ;; ... Well, still, here we go for now...

        ;; Ok, time for absolutely terrible tricks.
        ;; I'll annotate the code, compute offsets,
        ;; and then use some fucking CALL crap
        ;; (which pushes a return address onto the stack)
        ;; to 

        
        mov rax, 0xccddeeff
fib_pushjmp:
        call lolz_offset        ;now [rsp] = right before "lolz_offset".
        db "lolz_offset"
lolz_offset:
        mov rdx, [rsp]
        add rdx, 46
        mov rcx, [rsp]
        add rcx, 59 ;; 64
        mov r8, [rsp]
        add r8, 70
        ;; 80
        add rsp, 8
        jmp fib_a

        ;; AW MY GAAAAAAAAAAAAAWD THIS IS SO TERRIBLE AND IT WORKS
        ;; OH GOD IT'S SO TERRIBLE
        ;; arc> (bytes-length:$ #"lolz_offsetH\213\24$H\203\302\36H\213\f$H\203\301\27L\213\4$I\203\300\27H\203\304\b\353\5fib_a")
        ;; 46

        ;; OK IT'S ABOUT TWICE AS SLOW
        ;; JESUS CHRIST
        ;; OH MY GOD I CAN'T JUST CHANGE ONE OR TWO THINGS BACK TO CALL BECAUSE IT'LL SCREW UP THE DICKS
        ;; OH BUT I CAN CHANGE THE LAST N. OK.

        ;; All right, results are in.
        ;; On Tau:
        ;; For n=34:
        ;; mode 0: 104-107 msec.
        ;; mode 1: 189-201 msec.
        ;; mode 1, with "fib_c" removed and addresses adjusted: 179-183 msec.
        ;; mode 1, with "fib_b" and "fib_c" removed: 188-191 msec.
        ;; mode 1, with "fib_b" removed: 180-184 msec.
        ;; ... this is kind of absurd... probably insane caching and/or alignment effects.
        ;; Note that investigation in jmp-testing seems to indicate
        ;; that no difference would be made by replacing "jmp rdx" with direct "jmp fib_a".

                
        ;; mov rdx, fib_a
        ;; mov rcx, fib_b
        ;; mov r8, fib_c
        ;; jmp fib_a
        db "fib_a"
fib_a:  
        cmp rax, 2
        jl return
        dec rax
        push rax
        ;; call fib_a
        push rcx
        jmp rdx
        ;; db "fib_b"
fib_b:  
        xchg rax, [rsp]
        dec rax
        ;; call fib_a
        push r8
        jmp rdx
        ;; db "fib_c"
fib_c:
        add rax, [rsp]
        add rsp, 8
        ret

        mov rax, 0xffeeddcc


return:
        ret