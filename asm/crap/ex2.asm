; File: hello.asm
; Build: nasm -f macho hello.asm && gcc -arch i386 -o hello hello.o

SECTION .rodata
hello db 'Hello, World!',0x0a,0x00

SECTION .text

extern _printf ; could also use _puts...
GLOBAL _main

; aligns rsp to 16 bytes in preparation for calling a C library function
; arg is number of bytes to pad for function arguments, this should be a multiple of 16
; unless you are using push/pop to load args
%macro clib_prolog 1
    mov rbx, rsp        ; remember current rsp
    and rsp, 0xFFFFFF00 ; align to next 16 byte boundary (could be zero offset!)
    sub rsp, 24         ; skip ahead 12 so we can store original rsp
    push rbx            ; store rsp (16 bytes aligned again)
    add rsp, %1         ; pad for arguments (make conditional?)
%endmacro

; arg must match most recent call to clib_prolog
%macro clib_epilog 1
    sub rsp, %1         ; remove arg padding
    pop rbx             ; get original rsp
    mov rsp, rbx        ; restore
%endmacro

_main:
    ; set up stack frame
    push rbp
    mov rbp, rsp
    push rbx

    clib_prolog 32

	mov r12, hello
    mov [rsp], r12
    call _printf
    ; can make more clib calls here...
    clib_epilog 32

    ; tear down stack frame
    pop rbx
    mov rsp, rbp
    pop rbp
    mov rax, 0          ; set return code
    ret
