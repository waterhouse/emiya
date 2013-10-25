;So, this is quasiquote as a macro, written without the use of quasiquote.
;Although it depends on macros that are written with quasiquote.

;Exactly what should semantics be?
;Something like `(a . ,b) is actually `(a . (unquote b)),
;which is actually `(a unquote b).
;Which should not be expanded.
;I think that's the main point of contention.

;Let's see.
;Quoted things should be connected as much as possible.

;`(blah blah blah) -> (quote (blah blah blah))
;`(blah ,blah blah) -> (list* 'blah blah '(blah))
;`(blah blah ,blah) -> (list* 'blah 'blah blah 'nil) ;lolz
;`(,blah blah blah) -> (list* blah '(blah blah)) ;bahaha, cons is superseded
;`(,@blah blah blah) -> (append blah '(blah blah))
;`(blah ,@blah blah) -> (list* 'blah (append blah '(blah)))
;`(blah blah ,@blah) -> (list* 'blah 'blah blah)
;`(blah blah . ass) -> '(blah blah . ass)
;`(blah ,@blah . ass) -> (list* 'blah (append blah 'ass))

;btw, testing is good:
;arc> (do (= last-pp (pbpaste)) (while t (sleep .1) (let u (pbpaste) (when (isnt u last-pp) (= last-pp u) wrn:expand-quasiquote:read.u))))

;obviously the append involved must be proper (i.e. prepared for impropriety)
;--turns out append is in fact like that in racket, CLISP, and SBCL. good.
;also in "a". good.

;version 6: some definitions incorporated into "a".

(def expand-quasiquote (xs)
  (let u (expand-qq xs 1)
    (if idfn?car.u
        cadr.u
        splice-pls?car.u
        (err "Inappropriate usage of unquote-splicing" u xs)
        u)))

(def quasiquote? (x) (is x 'quasiquote))
(def unquote? (x) (is x 'unquote))
(def unquote-splicing? (x) (is x 'unquote-splicing))

(def quote? (x) (is x 'quote))
(def append? (x) (is x 'append))
(def splice-pls? (x) (is x 'splice-pls))
(def idfn? (x) (is x 'idfn))

;`(,a (quasiquote (quasiquote (quasiquote x))) ,c)
;-> (list* a '(quasiquote (quasiquote (quasiquote x))) c nil)
;`(,a (quasiquote (b ,,c)) ,d)
;-> (list* a (list* 'quasiquote (list* b (list* 'unquote c nil) nil) nil) d nil)
;`(,a (quasiquote (b ,(c ,@d

;ok.
;`(... `(,,@xs)) -> (list* ... (list* 'quasiquote (list* 'unquote xs) nil) nil)
;that be my executive decision.
;[by now that'd be (list ... (list 'quasiquote (cons 'unquote xs)))]
;note that it would be possible to achieve the same effect with:
;(with qq 'quasiquote uq 'unquote
;  `(... (,qq (,uq ,@xs))))
;and methinks it's benign to support things that can be achieved in other ways.

;for those reading:
;expand-qq will return a list whose car is one of:
; quote, list*, append, cons, list, idfn, splice-pls.
;expand-qq returns subexpressions which are subsequently combined.
;e.g. when we expand `(a b), we will get the subexpressions
; (quote a) for the car and (quote (b)) for the cdr.
;these will be combined into, not (cons 'a '(b)), but '(a b).
;idfn is used to mark user code, so that we never accidentally change user code.
; e.g. if the user writes (cons 'a '(b)), we should not turn that into '(a b),
; because that is semantically different.
;splice-pls is obviously for unquote-splicing. when it gets combined,
; the result usually has "append" or "cons".
;idfn and splice-pls should obviously never appear in the resulting code.
;we maintain the invariant that the subexpressions we pass around are the
;above kind of list, and idfn and splice-pls can only appear in the car of
;those subexpressions.

(def expand-qq (x n)
  (if atom?x
      (list 'quote x)
      (case car.x
        quasiquote
        (let (u) cdr.x
          (qq-narb 'quasiquote (expand-qq u inc.n)))
        unquote
        (let (u) cdr.x
          (if (is n 1)
              (list 'idfn u)
              (qq-narb 'unquote (expand-qq u dec.n))))
        unquote-splicing
        (let (u) cdr.x
          (if (is n 1)
              (list 'splice-pls u)
              (qq-narb 'unquote-splicing (expand-qq u dec.n))))
        (expand-qq-rest x n))))

;smthg like (unquote 'x) -> '(unquote x),
;or (unquote (list x y)) -> (list 'unquote (list x y)).
(def qq-narb (name v)
  (let qname (list 'quote name)
    (casen car.v
      quote (list 'quote (list name cadr.v))
      (list* cons) (list* 'list* qname cdr.v)
      (list append) (list 'list qname v)
      idfn (list 'list qname cadr.v)
      splice-pls (list 'cons qname cadr.v)
      (err "WTF?" name v))))

(def expand-qq-rest (x n)
  (if atom.x
      (list 'quote x)
      (withs a (expand-qq car.x n)
             b (expand-qq-rest cdr.x n)
             ad car.a bd car.b
        the-a (if idfn?ad cadr.a a)
        the-b (if idfn?bd cadr.b b)
        ;quote, list*, append, idfn, splice-pls, list, cons
        (if (and quote?ad quote?bd)
            (list 'quote (cons cadr.a cadr.b))
            splice-pls?ad
            (if (iso b ''nil)
                (list 'idfn cadr.a)
                (is bd 'append)
                (list* 'append cadr.a cdr.b)
                (list 'append cadr.a the-b))
            (iso b ''nil)
            (list 'list the-a)
            (casen bd
              (list* cons) (list* 'list* the-a cdr.b)
              list (list* 'list the-a cdr.b)
              (list 'cons the-a the-b))))))

(mac the-quasiquote (x)
  (expand-quasiquote x))
(= tqq the-quasiquote)

;Cosmetic issues:
;- (list* x (list* ...)) -> (list* x ...)
;- (list* x y) -> (cons x y)
;- (list* ... nil) -> (list ...) ;also (cons x nil) -> (list x), possibly
;- (append x nil) -> x, or perhaps (idfn x)
;- (append x (append y ...)) -> (append x y ...), possibly
  
;All of the above are handled.  Teh wootz. 
  

;Incidentally, qq-narb ess. wants to be (make-list ''blah thing), and
;expand-qq-rest wants to use (make-cons a b).
;Well, we shall see.


