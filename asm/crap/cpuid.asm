

        mov rax, 0xfffefafd

        ;; takes argument in EAX
        ;; and returns results in E[ABCD]X
        ;; to obey C calling convention, we might save those things

        pushfq
        push rbx
        push rcx
        push rdx

        ;; so our argument was given in RDI (or EDI).
        ;; and we should store results in a byte string of length 8 * 4,
        ;; passed in RSI.
        ;; the high 4 bytes of each 8-byte should be all 0.
        ;; (could be more efficient but whatever, checking wins)
        ;; eh, neh, changed my mind.
        ;; also, for some reason, it's EBX EDX ECX for one string.

        mov rax, rdi
        cpuid
        mov [rsi], eax
        mov [rsi+4], ebx
        mov [rsi+8], ecx        ;SWAPPED ;NOPE
        mov [rsi+12], edx       ;FOR SHIZZLE, APPARENTLY

        pop rdx
        pop rcx
        pop rbx
        popfq

        ret
        