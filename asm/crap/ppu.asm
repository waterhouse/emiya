; printf1.asm   print an integer from storage and from a register
; Assemble:	nasm -f elf -l printf.lst  printf1.asm
; Link:		gcc -o printf1  printf1.o
; Run:		printf1
; Output:	a=5, eax=7

; Equivalent C code
; /* printf1.c  print an int and an expression */
; #include <stdio.h>
; int main()
; {
;   int a=5;
;   printf("a=%d, eax=%d\n", a, a+2);
;   return 0;
; }

; Declare some external functions
;
        extern	printf		; the C function, to be called

        SECTION .data		; Data section, initialized variables

	a:	dd	5		; int a=5;
fmt:    db "a=%d, eax=%d", 10, 0 ; The printf format, "\n",'0'


        SECTION .text                   ; Code section.

        global _main		; the standard gcc entry point
_main:				; the program label for the entry point
        push    rbp		; set up stack frame
        mov     rbp,rsp

	mov r10, a

	mov	rax, [r10]	; put a from store into register
	add	rax, 2		; a+2
	push	rax		; value of a+2
        push    qword [r10]	; value of variable a
	mov r10, fmt
        push    r10	; address of ctrl string
        call    printf		; Call C function
        add     rsp, 12		; pop stack 3 push times 4 bytes

        mov     rsp, rbp	; takedown stack frame
        pop     rbp		; same as "leave" op

	mov	rax,0		;  normal, no error, return value
	ret			; return
	
