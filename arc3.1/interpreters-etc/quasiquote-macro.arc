;First we will write quasiquote as a macro, using quasiquote because it is convenient.
;Then we will translate it to not use quasiquote.

;I should note perhaps that Guy Steele did at least that much at the end of CLTL2.

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

;obviously the append involved must be proper (i.e. prepared for impropriety)
;--turns out append is in fact like that in racket, CLISP, and SBCL. good.
;also in "a". good.

;methinks I may use some sentinel values and eq to do combining-ish stuff

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

(def atom? (x) (no acons.x))

;`(,a (quasiquote (quasiquote (quasiquote x))) ,c)
;-> (list* a '(quasiquote (quasiquote (quasiquote x))) c nil)
;`(,a (quasiquote (b ,,c)) ,d)
;-> (list* a (list* 'quasiquote (list* b (list* 'unquote c nil) nil) nil) d nil)
;`(,a (quasiquote (b ,(c ,@d

;Btw, me thinking about the exact details of (unquote ,@crap) and things seems
;a bit like Newton thinking about theology.

;Space-safe, cheap error reporting.
;Have two thread-local vars that you use.
;One you'll assign to the error handler you want to use.
;The other you'll assign to the continuation it's supposed to correspond to.
;Not actually an error handler, but will be a source of error message.
;The second thing should probably be a weak ptr.
;Or a bit-pattern not treated like a ptr (but compared with eq if necessary).
;Or even a hash.
;This is quite separate from parameterizing an exception handler where that
;would actually be useful.


;one strategy for dealing with ,@ is to have it get handled by whosits
;guaranteed not to return an atom...
;actually, that implies I don't need weird sentinels
;...
;ok, in general...
;I might want to have some things become (idfn x).
;well, we'll see.

;ok.
;`(... `(,,@xs)) -> (list* ... (list* 'quasiquote (list* 'unquote xs) nil) nil)
;that be my executive decision.
;note that it would be possible to achieve the same effect with:
;(with qq 'quasiquote uq 'unquote
;  `(... (,qq (,uq ,@xs))))
;and methinks it's benign to support things that can be achieved in other ways.

(mac casenlet (var expr . args)
  (let ex (afn (args)
               (if (no (cdr args))
                   (car args)
                   `(if ,(if sym?car.args
                             `(is ,var ',(car args))
                             `(in ,var ,@(map [list 'quote _] car.args)))
                        ,(cadr args)
                        ,(self (cddr args)))))
    `(let ,var ,expr
       ,(ex args))))

(mac casen (x . args)
  `(casenlet ,(uniq) ,x ,@args))

;... being totally raw with list* here (no cons, no list).
;probably with append too ((append x nil) remains so).
(def expand-qq (x n)
  (if atom?x
      `(quote ,x)
      quasiquote?car.x
      (let (u) cdr.x
        (let v (expand-qq u inc.n)
          (casen car.v
            quote (list 'quote (list 'quasiquote cadr.v))
            ;idfn (list  ;since n ≥ 1, this is impossible
            (list* append)
            (list 'list* 'quasiquote
                  v
                  nil)
            ;splice-pls (list 'list* 'quasiquote cadr.v) ;also impossible
            (err "WTF?" v u x))))
      unquote?car.x
      (let (u) cdr.x
        (if (is n 1)
            (list 'idfn u)
            (let v (expand-qq u dec.n)
              (casen car.v
                quote (list 'quote (list 'unquote cadr.v))
                (list* append)
                (list 'list* 'unquote v nil)
                idfn (list 'list* 'unquote cadr.v nil)
                splice-pls (list 'list* 'unquote cadr.v)
                (err "WTF?" v u x)))))
      unquote-splicing?car.x
      (let (u) cdr.x
        (if (is n 1)
            ;(err "Bad place for unquote-splicing" x)
            (list 'splice-pls u)
            (let v (expand-qq u dec.n)
              (casen car.v
                quote (list 'quote (list 'unquote-splicing cadr.v))
                (list* append)
                (list 'list* 'unquote-splicing v nil)
                idfn (list 'list* 'unquote-splicing cadr.v nil)
                splice-pls (list 'list* 'unquote-splicing cadr.v)
                (err "WTF?" v u x)))))
      (withs a (expand-qq car.x n)
             b (expand-qq-rest cdr.x n)
             ad car.a bd car.b
        ;quote, list*, append, idfn, splice-pls
        ;actually it's impossible for b to be idfn or splice-pls
        (if (and quote?ad quote?bd)
            (list 'quote (cons cadr.a cadr.b))
            splice-pls?ad
            (list 'append cadr.a b)
            (list 'list* (if idfn?ad cadr.a a) b)))))

(def expand-qq-rest (x n)
  (if atom.x
      (list 'quote x)
      (withs a (expand-qq car.x n)
             b (expand-qq-rest cdr.x n)
             ad car.a bd car.b
        ;quote, list*, append, idfn, splice-pls
        ;actually it's impossible for b to be idfn or splice-pls
        (if (and quote?ad quote?bd)
            (list 'quote (cons cadr.a cadr.b))
            splice-pls?ad
            (list 'append cadr.a
                  (if idfn?bd cadr.b b))
            (list 'list* a (if idfn?bd cadr.b b))))))

(mac the-quasiquote (x)
  (expand-quasiquote x))
(= tqq the-quasiquote)

;Ok, this appears to produce legal output.
;However, it's rather ugly.
;I did drop the idfn from the output, but still...
;Cosmetic issues:
;- (list* x (list* ...)) -> (list* x ...)
;- (list* x y) -> (cons x y)
;- (list* ... nil) -> (list ...) ;also (cons x nil) -> (list x), possibly
;- (append x nil) -> x, or perhaps (idfn x)
;- (append x (append y ...)) -> (append x y ...), possibly
;Also there are some redundancies in the code.


