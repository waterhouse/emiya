


        mov rax, 0xfffefafd

        ;; rdi = [dl-handle][dlsym]
        ;; rsi = a buffer
        ;; rdx = len

        ;; Do we ... yes, the internet probably says we need to align the stack to 16 bytes
        ;; before calling C functions.
        ;; [we start out so aligned, of course]

        default rel

        mov [buf], rsi
        mov [buflen], rdx
        mov rsi, [rdi]
        mov [handle], rsi
        mov rdi, [rdi + 8]
        mov [dlsym], rdi
        ;; Inefficiency.  I love it.
        mov rdi, [handle]
        lea rsi, [read_str]
        call [dlsym]
        mov [read], rax
        mov rdi, [handle]
        lea rsi, [write_str]
        call [dlsym]
        mov [write], rax

        mov rdi, [handle]
        lea rsi, [getchar_str]
        call [dlsym]
        mov [getchar], rax

        mov rdi, [handle]
        lea rsi, [putchar_str]
        call [dlsym]
        mov [putchar], rax

        ;; mov rdi, 10
        ;; call [putchar]

        mov rdi, 0              ;stdin
        mov rsi, [buf]
        mov rdx, [buflen]
        call [read]

        mov rdi, 1              ;stdout
        mov rsi, [buf]
        mov rdx, rax
        call [write]

        ret



buf:    dq 0
buflen: dq 0
        

handle: dq 0
dlsym:  dq 0
read:   dq 0
write:  dq 0
getchar: dq 0
putchar:     dq 0   


read_str:       db "read", 0
write_str:      db "write", 0
getchar_str:    db "getchar", 0
putchar_str:    db "putchar", 0


        
