



        %define a b
        %define b c
        %define c d
        %define d 10

        mov rax, a
        %defstr dick a%[a]%[%[a]]
        db dick

        ;; the above is actually "db 'a1010'".
        ;; now...

        %define xy 33
        %define u x
        mov rax, %[u]y          ;is 33
        %define x z
        %define zy 69
        mov rax, %[u]y          ;is 69

        %define lel xy

;; xy:                             ;is "33:" ;which isn't valid

;; %[zy]:                          ;is "69:", also invalid
;; lel:                            ;is "33:", invalid

        %define nub noob
nub:                            ;is "noob:", valid
        


        
