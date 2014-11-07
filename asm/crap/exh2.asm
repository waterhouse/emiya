; File: hello.asm
; Build: nasm -f macho hello.asm && gcc -arch i386 -o hello hello.o

SECTION .rodata
hello.msg db 'Hello, World!',0x0a,0x00

SECTION .text

extern printf ; could also use _puts...
GLOBAL main

; aligns esp to 16 bytes in preparation for calling a C library function
; arg is number of bytes to pad for function arguments, this should be a multiple of 16
; unless you are using push/pop to load args
%macro clib_prolog 1
    mov ebx, esp        ; remember current esp
    and esp, 0xFFFFFFF0 ; align to next 16 byte boundary (could be zero offset!)
    sub esp, 12         ; skip ahead 12 so we can store original esp
    push ebx            ; store esp (16 bytes aligned again)
    add esp, %1         ; pad for arguments (make conditional?)
%endmacro

; arg must match most recent call to clib_prolog
%macro clib_epilog 1
    sub esp, %1         ; remove arg padding
    pop ebx             ; get original esp
    mov esp, ebx        ; restore
%endmacro

main:
    ; set up stack frame
    push ebp
    mov ebp, esp
    push ebx

    clib_prolog 16
    mov dword [esp], hello.msg
    call printf
    ; can make more clib calls here...
    clib_epilog 16

    ; tear down stack frame
    pop ebx
    mov esp, ebp
    pop ebp
    mov eax, 0          ; set return code
    ret