;I will want the arglist-argnames function.
;Currently my plan is for optionals and crap to be done as a macro
;over an underlying fn, but 

#;(def arglist-argnames (xs) ;version 0
  (keep [isa _ 'sym] flat.xs))

;version 2: make use of the goddamn "sym?" function.
(def arglist-argnames (xs) 
  (keep sym? (flat xs)))

;hmm... should I have specialized "if-object?", etc. procedures?
;or should I compare them to the real objects?
;I guess the latter is better...
;(it just seemed to me that perhaps I should avoid letting those be
; accessible... nope.)

(def bound-to? (s v)
  (and (sym? s)
       (bound? s)
       (is (symbol-value s) v)))

#;(def de-macro (x (o env nil)) ;version 0
  (if ssyntax.x
      (de-macro ssexpand.x env)
      atom.x
      x
      (let (a . b) x
        (when ssyntax.a
          (zap ssexpand a))
        (if (and acons.a (is car.a 'compose))
            (de-macro (xloop (a cdr.a b b)
                        ;non-tail-rec way from decompose is easiest
                        (if no.a ;composition of nothing shd be idfn
                            (if cdr.b ;multiple values
                                (err "Wat" x) ;are not allowed
                                car.b)
                            (let u cdr.a
                              (if no.u
                                  (cons car.a b)
                                  (list car.a
                                        (next u b))))))
                      env)
            (let a (de-macro a env)
              (if (mem a env)
                  ;... we could detect local bindings to literal macros
                  ;and maybe direct calls to literal macros as well
                  ;(as in ((macro ...) arg ...))
                  ;but neh
                  (cons a (map [de-macro _ env] b))
                  (and (isa a 'sym)
                       bound.a
                       (isa symbol-value.a 'mac))
                  (de-macro (macex:cons a b) env)
                  (is a 'fn)
                  (cons a (let u car.b
                            (cons u
                                  (let env (join (arglist-argnames u) env)
                                    (map [de-macro _ env] cdr.b)))))
                  (is a 'quote)
                  (cons a b)
                  (is a 'quasiquote)
                  (if cdr.b
                      (err "Quasiquote better" x)
                      (de-macro (de-macro-qq car.b env 1)
                                env)) ;bwahaha
                  (is a '$)
                  (cons a b)
                  (cons a (map [de-macro _ env] b))))))))


;lessee...
;I think I will keep compose the way it is
;and as for $, I shall handle both that and "arc".

;version 3: fuck, no optional args. also acons -> cons?.
#;(def de-macro (x env)
  (if (ssyntax? x)
      (de-macro (ssexpand x) env)
      (atom x)
      x
      (let (a . b) x
        (let a (if (ssyntax? a) (ssexpand a) a)
          (if (and (cons? a) (is (car a) 'compose))
              (de-macro (xloop (a (cdr a) b b)
                          ;non-tail-rec way from decompose is easiest
                          (if (no a) ;composition of nothing shd be idfn
                              (if (cdr b) ;multiple values
                                  (err "Wat" x) ;are not allowed
                                  (car b))
                              (let u (cdr a)
                                (if (no u)
                                    (cons (car a) b)
                                    (list (car a)
                                          (next u b))))))
                        env)
              (let a (de-macro a env)
                (if (mem a env)
                    ;... we could detect local bindings to literal macros
                    ;and maybe direct calls to literal macros as well
                    ;(as in ((macro ...) arg ...))
                    ;but neh (this is where a 'mc special form is useful,
                    ; 'cause otherwise it's (make-macro) on insane crap...
                    ; eh, wouldn't be too hard... feh)
                    (cons a (map [de-macro _ env] b))
                    (and (sym? a)
                         (bound a)
                         (macro? (symbol-value a)))
                    (de-macro (macex (cons a b)) env)
                    (is a 'fn)
                    (cons a (let u (car b)
                              (cons u
                                    (let env (append (arglist-argnames u) env)
                                      (map [de-macro _ env] (cdr b))))))
                    (is a 'quote)
                    (cons a b)
                    (in a '$ 'arc)
                    (cons a b)
                    (cons a (map [de-macro _ env] b)))))))))

;version 4: (bound-to? s if-object) rather than (is s 'if)
;also, dropping $... hmm... ...
;actually, not.
;as for compose... do I really wanna have a compose object?
;it's either that or a pretty nonperformant macro...
;...
;...
;for this expansion to work well...
;it'd suck if someone could take "compose", redefine it to
;be something equivalent, and then have this shit not work anymore.
;but testing something for equality to (symbol-value 'compose) seems
;fairly terrible too...
;Ok, fuck this. I ... I'm just gonna say "is x 'compose".
;Note that "compose" is an ssx thing, and so I can kinda still
;justify it that way.
;Meanwhile, I will use fn-object ('cause I intend to make use of that)
;and quote-object (for consistency).
;And then '$ and 'arc I'll just continue to leave in there...

;--No.
;Unacceptable.
;"compose" must be handled properly by the interpreter.
;My semantics will continue to be "dss before eval".
;And I think a $-object will be permissible.
;No arc-object, at least not in final.
(def de-macro (x env)
  (if (ssyntax? x)
      (de-macro (ssexpand x) env)
      (atom x)
      x
      (let (a . b) x
        (let a (if (ssyntax? a) (ssexpand a) a)
          (if (and (cons? a)
                   #;(bound-to? (car a) compose-object)
                   #;(no (mem a env)) ;ssx would ignore...
                   (is a 'compose)))
              (de-macro (xloop (a (cdr a) b b)
                          ;non-tail-rec way from decompose is easiest
                          (if (no a) ;composition of nothing shd be idfn
                              (if (cdr b) ;multiple values
                                  (err "Wat" x) ;are not allowed
                                  (car b))
                              (let u (cdr a)
                                (if (no u)
                                    (cons (car a) b)
                                    (list (car a)
                                          (next u b))))))
                        env)
              (let a (de-macro a env)
                (if (mem a env)
                    ;... we could detect local bindings to literal macros
                    ;and maybe direct calls to literal macros as well
                    ;(as in ((macro ...) arg ...))
                    ;but neh (this is where a 'mc special form is useful,
                    ; 'cause otherwise it's (make-macro) on insane crap...
                    ; eh, wouldn't be too hard... feh)
                    (cons a (map [de-macro _ env] b))
                    (and (sym? a)
                         (bound a)
                         (macro? (symbol-value a)))
                    (de-macro (macex (cons a b)) env)
                    (bound-to? a fn-object)
                    (cons a (let u (car b)
                              (cons u
                                    (let env (append (arglist-argnames u) env)
                                      (map [de-macro _ env] (cdr b))))))
                    (bound-to? a quote-object)
                    (cons a b)
                    (in a '$ 'arc)
                    (cons a b)
                    (cons a (map [de-macro _ env] b)))))))))

;so it occurred to me that, in all the code I immediately intend to use
;the above for, I'm not shadowing any global macros, so I could omit that crap.
;but nah.

;then there is how real correctness would deal with special forms:
;it should be "x is bound to if-object", not "x is 'if".

;Eghhhhhhhhhh...
;How the fuck do we do an eq-hash-table?
;... Or any kind of hash table, in fact.
;'Cause of mutation.
;Actually, probably no one has a solution...

;Some experimentation with SBCL shows:
;- SBCL's cons cells do appear to be 16 bytes each.
;  This appears to rule out things like having all objects contain
;  a field which is their current hash, and which is updated upon
;  any set-ca/dr operation.
;- Modifying a cons cell that has been used in a key in a hash table
;  does (although, spookily, not always--I suspect compiler-optimization
;  shenanigans) lead to that key not being recognized when you reuse it.
;  This is what I'd expect from a straightforward approach: "the results
;  are unspecified when you modify keys".
;Racket also says weird shit may happen if you modify keys in an equal-hash.
;I suspect ...
;Righto, I suspect that eq- and eqv-hashes use some kind of extra object-id
;field inside each object.
;(Alternatives are "same hash for everything, then use your comparison
; function to find the right object out of the list of all that have the
; same hash" and "use memory addresses for the hashing of objects represented
; in memory, and lazily re-sort the table upon every GC".  The latter sounds
; pretty terrible--but it seems to be fair: any more-clever scheme seems
; to probably involve at least an extra word of memory per object, in which
; case having an extra object id field is superior.)


;User closures should have "user-defined type" tags.
;Real closures have a real tag.
;User is expected to make real closures soon.

;Well, here we are at machine code again.
;Models:
;- Machine code alloc'd and free'd.
;--> In this case, things are quite static.
;    Only problems are if (a) we don't feel like doing alloc/free stuff
;    in the GC or (b) we actually want to free things a lot, in the
;    manner of a GC.
;- Machine code in GC-managed memory, each block of machine code
;  separately managed and moved.
;--> This is simplest on the garbage collector, but worst to the
;    machine code, in which all subroutines must either be called
;    through a global array or something, or be duplicated.
;    In particular, note that the code-block that every continuation
;    points to must be by itself.
;    This is pretty terrible.  Rejecting.
;- Machine code in GC-managed memory, with many machine-code functions
;  in the same contiguous block.
;--> This will have approximately the same performance characteristics
;    as the alloc/free model if code never becomes garbage.
;    However, if one is in the business of generating and throwing
;    away code a lot, this is probably better.
;    (One could sort of achieve stuff with a weak-pointer wrapper of
;     machine code, and ... epicycles. Sucks.)
;
;The second approach just sucks.  The third approach is best, but it is
;hard to implement.  I shall use the first approach for the moment, for
;booting.
;Fortunately, all these approaches can coexist just fine...

;[written earlier]
;Oh man.
;The booting will be easy.
;API:
;- closure = [codeptr env ...]
;- codeptr = machine code to be executed
;- [codeptr - 8] = ptr to "move me" (subroutine; returns with ret)
;- [codeptr - 16] = ptr to "trace me" (subroutine; returns with ret)
;;;;- [codeptr - 24] = ptr to "trace and execute me" (continuation; doesn't ret)
;;; ^ actually that's not necessary: "move me" should know about that.

;The booting crap can just be allocated outside the GC range
;and never moved.
;In that case, none of the above code-blocks will move the machine
;code ("me" = the closure).
;In the other model, 

;Note that, although "move me" and "trace me" should never appear
;in the codeptr field of a closure, "trace and execute me" will.
;Therefore, "trace and execute me" will need a couple of dickass
;fields in front of it as well--additional pointers to "move me" and
;"trace me".
;"move me" = move closure, leaving fwd ptr (in the codeptr field
;   of the corpse--it's ok, things shouldn't appear in negative
;   addr space) and installing ptr to "trace and execute me" in
;   the codeptr field of the ... ghola? I should come up with a
;   name for this ... "heir" seems good. ... yes.
;"trace me" = move anything saved in the closure. This can be as
;   function-specific as you like: if the compiler knows it doesn't
;   store anything that needs moving in its closure, then "trace me"
;   can immediately ret.  (Actually, in that case, "move me" should
;   just install "execute" in the codeptr field of the heir, and
;   there should be no "trace and execute me" code.)
;"trace and execute me" = what it says. Should pretty much be this:
;   "CALL trace_me; JMP execute".

;Note that, for GC-stack purposes, ...
;Huh.
;... Ok, yeah. For GC-stack purposes, ...
;Actually, because this is so good, if the compiler is smart, then
;if a closure's env is ...
;Ok, no. ...
;Ok, partially.
;In model #1, if a closure's env is empty, then the "move me" code
;can know that, and can not even put crap on someone's GC stack.
;However, in model #3, the closure's code ptr may have to be moved.
;And then ...
;Eh, well... ok, fine.  --No.
;Then you will have to change it to "trace and execute" and all
;of that crap.

;I have received a sign that, in model #3, closures should in fact
;contain ...
;Ok, never mind.
;(Nawp, there still seems to be no argument of putting things from
; a "module-compiled-together" into a closure structure over into
; RIP-relative things, assuming tracing the latter can be done.)

;Well, all right.
;Next iteration shall do the improved thing.



