; macasm.asm
;
; A Simple MAC OS X Assembly Language Program
; 
;
;
; Written by Praseed Pai K.T.
;            http://praseedp.blogspot.com
;
;
; At the MAC OS X  terminal
;
; nasm -f macho macasm.asm
; ld -o macasm.exe -e entrypoint macasm.o
; ./macasm.exe
;
;
;

section .text   ;------- This is the Code Segment

global entrypoint ; global execution start point

entrypoint:
;
; How do i write some thing on to a console
;
; write(1 , "hello world",12);
;

push dword messagelength
push dword message
push dword 1
mov eax , 0x4   ; System call number
sub esp,4  ; decrement stack pointer for MAC OS X system call
int 0x80
add esp,16 ; Clean up the stack after system call

;------- Exit the Program
; exit(0);
;
push dword 0
mov eax , 0x1   ; // System call for exit
int 0x80

section .data

    message db "Hello MAC OS X from assembly",13,0xa
        messagelength equ $-message ;length