

        mov rax, 0xfffefafd

        add rdi, rsp
        mov rax, [rdi]
        ret

        ;; Jesus christ.  Using return-rsp, it looks like Racket uses something like Baker's
        ;; treadmill algorithm, Cheney on the MTA.
;; arc> (return-rsp-thing return-rsp)
;; 140734799737560
;; arc> (return-rsp-thing return-rsp)
;; 140734799736088
;; arc> (return-rsp-thing return-rsp)
;; 140734799734616
;; arc> (return-rsp-thing return-rsp)
;; 140734799733144
;; arc> (let u (n-of 5 (return-rsp-thing return-rsp)) (list u delta.u))
;; ((140734799730616 140734799730808 140734799730808 140734799730808 140734799730808) (192 0 0 0))
        ;; Looks like it's for allocating closures or something.
        ;; I guess that's one way to do things, and probably bears some advantages.
        