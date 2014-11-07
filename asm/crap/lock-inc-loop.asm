
        ;; On Tau, 7.246 seconds to do 1 billion iterations.
        ;; This is roughly 3x the 2.34 seconds without the lock.
        
                mov rax, 0xfffefafd

;;;  rdi = int ptr
;;;  rsi = n

                cmp rsi, 0
                je return
loop:
                lock inc qword [rdi]
                dec rsi
                jnz loop


return:
                mov rax, [rdi]
                ret
