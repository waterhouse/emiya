

        mov rax, 0xfffefafd


        ;; rdi = n, rsi = mode

        mov rcx, rdi
        cmp rsi, 0
        je pushes
        cmp rsi, 1
        je giant_dec

        ;; ... wow.
        ;; ... wait, no.
        ;; jeez, that was weird.
;; arc> (ga stack-framing 2)
;; #<procedure: stack-framing-thing>
;; arc> (time:stack-framing-thing stack-framing 1000000 0)
;; time: 45 cpu: 7 gc: 0 mem: 1840
;; 4384188944
;; arc> (time:stack-framing-thing stack-framing 1000000 1)
;; time: 4 cpu: 4 gc: 0 mem: 0
;; 4384188944
;; arc> (time:stack-framing-thing stack-framing 10000000 1)
;; time: 26 cpu: 26 gc: 0 mem: 0
;; 4384188944
;; arc> (time:stack-framing-thing stack-framing 100000000 1)
;; time: 231 cpu: 231 gc: 0 mem: 0
;; 4384188944
;; arc> (time:stack-framing-thing stack-framing 100000000 0)
;; time: 281 cpu: 282 gc: 0 mem: 0
;; 4384188944
;; arc> (time:stack-framing-thing stack-framing 1000000 0)
;; time: 4 cpu: 4 gc: 0 mem: 0
;; 4384188944
;; arc> (time:stack-framing-thing stack-framing 1000000 1)
;; time: 5 cpu: 4 gc: 0 mem: 0
;; 4384188944

        ;; ... well.
        ;; ok, this time, with the add instructions, I get:
;;         arc> (repeat 3 (time:stack-framing-thing stack-framing 100000000 0))
;; time: 259 cpu: 258 gc: 0 mem: 2160
;; time: 252 cpu: 252 gc: 0 mem: 0
;; time: 252 cpu: 252 gc: 0 mem: 0
;; nil
;; arc> (repeat 3 (time:stack-framing-thing stack-framing 100000000 1))
;; time: 280 cpu: 280 gc: 0 mem: 0
;; time: 277 cpu: 278 gc: 0 mem: 0
;; time: 278 cpu: 278 gc: 0 mem: 0
;; nil

        ;; hmm... interesting. the adding work is complete busywork
        ;; for the processor. because all those values are overwritten.
        ;; there should be no issues of "pipeline stalls" or whatever
        ;; (except maybe overuse of the ALU, but that is deliberate).
        ;; in other words, it would seem that 
        ;; ... no, even putting in extra "sub/add rsp" busywork to pushes,
        ;; pushes is still slightly superior.
        ;; [all this is on Tau, of course]
        ;; very well. I can certainly continue as planned.


pushes:
        sub rsp, 56

        push rbp
        push rsi
        push rdi
        push rdx
        push rcx
        push rbx
        push rax

        add rax, rbx
        add rdi, rcx
        add rsi, rsp
        add rdx, rbp


        pop rax
        pop rbx
        pop rcx
        pop rdx
        pop rdi
        pop rsi
        pop rbp

        add rsp, 56

        dec rcx
        jnz pushes
        ret



giant_dec:                      ;huh huh he said dick
        sub rsp, 56

        mov [rsp], rax
        mov [rsp+8], rbx
        mov [rsp+16], rcx
        mov [rsp+24], rdx
        mov [rsp+32], rdi
        mov [rsp+40], rsi
        mov [rsp+48], rbp

        add rax, rbx
        add rdi, rcx
        add rsi, rsp
        add rdx, rbp
        
        mov rax, [rsp]
        mov rbx, [rsp+8]
        mov rcx, [rsp+16]
        mov rdx, [rsp+24]
        mov rdi, [rsp+32]
        mov rsi, [rsp+40]
        mov rbp, [rsp+48]

        add rsp, 56

        

        dec rcx
        jnz giant_dec
        ret