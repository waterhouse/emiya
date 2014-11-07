

        mov rax, 0xfffefafd

        ;; http://www.youtube.com/watch?v=xe821OoYPUY
        ;; We are going to test the speed of call chains and so forth.
        ;; Actually that song isn't appropriate yet.

        ;; All right, with resb 40 million btwn stuff, no slower than with resb 4. (Even with resb 0.)
        ;; (On Tau, 132 msec to do 100m iterations.)
        ;; Probably this is because only code goes in instruction cache, and in fact
        ;; only relevant crap goes in any cache at all.

top:

place1:
        jmp place2
place2:
        jmp place3
place3:
        dec rdi
        jz return
        jmp place1

return:
        ret


        