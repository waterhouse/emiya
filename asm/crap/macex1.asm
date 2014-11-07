

        default rel

        %macro sysfunc 1
        mov rdi, [handle]
        lea rsi, [%1_str]
        call [dlsym]
        mov [%1], rax
        jmp %%end               ;murderously terrible code organization, but oh well
        align 8
;; %1_str: db \"%1\", 0 ;nope
%1_str:
        ;; db %1, 0 ;nope
        ;; db \" %+ %1 %+ \" ;nope
        ;; db \'%1\', 0 ;nope
        ;; db \'%[%1]\', 0 ;nope

        %defstr %%nerf %1
        db %%nerf, 0 ;nope ;yep

        ;; %defstr sysfunc_str %1
        ;; db sysfunc_str, 0
        
        
%1:     dq 0
%%end:
        %endmacro

        sysfunc puts
        sysfunc write
        sysfunc read
        
        
        

        
