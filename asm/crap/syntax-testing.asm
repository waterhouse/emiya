



%macro dick 3
        %define arg_one %1
        %define arg_two %2
        %define arg_three %3

        mov rax, %1
        mov rax, %2
dick_%2:        
        mov rax, %3

dick_%3:
        mov rax, %1

dick_%[arg_one]:
        

        %endmacro


        dick 1, 2, 3
        dick rax, 4, rcx

        ;; Results:
;; ~/D/asm> nm -n syntax-testing.o 
;; 000000000000000a t dick_2
;; 000000000000000f t dick_3
;; 0000000000000014 t dick_1
;; 000000000000001c t dick_4
;; 000000000000001f t dick_rcx
;; 0000000000000022 t dick_rax




        
