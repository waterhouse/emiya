section .data
hello_world     db      "Hello World!", 0x0a
 
section .text
global start
 
start:
mov rax, 0x2000004      ; System call write = 4
mov rdi, 1              ; Write to standard out = 1
mov rsi, hello_world    ; The address of hello_world string


	
	;; ;; mov qword [rax], 256
	;; mov rbx, [rax]
	;; bswap rbx
	;; mov [rax], rbx
mov rdx, 2500000000            ; The size to write; seems it can be up to ~2 billion (32-bit signed int? this is 32-bit kernel).
syscall                 ; Invoke the kernel
mov rax, 0x2000001      ; System call number for exit = 1
mov rdi, 0              ; Exit success = 0
syscall                 ; Invoke the kernel


	;; nasm -f macho64 mac2.asm; ld mac2.o; ./a.out