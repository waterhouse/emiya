;So, this is quasiquote as a macro, written without the use of quasiquote.
;Although it depends on macros that are written with quasiquote.

;Quoted things should be connected as much as possible.

;btw, testing is good:
;arc> (do (= last-pp (pbpaste)) (while t (sleep .1) (let u (pbpaste) (when (isnt u last-pp) (= last-pp u) wrn:expand-quasiquote:read.u))))

;obviously the append involved must be proper (i.e. prepared for impropriety)
;--turns out append is in fact like that in racket, CLISP, and SBCL. good.
;also in "a". good.

;This crap is for inclusion into dyn-cont.
;Let us put library crap first.
;...
;I guess I should keep the models for reference.

#;(mac casenlet (var expr . args)
  `(let ,var ,expr
     ,(xloop (args args)
        (if no?cdr.args
            car.args
            `(if (or ,@(map [list 'is var `',_]
                            (if cons?car.args
                                car.args
                                list:car.args)))
                 ,cadr.args
                 ,next:cddr.args)))))

(mac casenlet (var expr . args) ;version 4: use or
  (list 'let var expr
     (xloop (args args)
       (if (no (cdr args))
           (car args)
           (list 'if
              (cons 'or
                 (map1 (fn (x) (list 'is var (list 'quote x)))
                       (if (cons? (car args))
                           (car args)
                           (list (car args)))))
              (cadr args)
              (next (cddr args)))))))

(mac casen (x . args)
  (list* 'casenlet (uniq) x args))

;and...
;since the normal "case" uses is for comparison, there is never
;a point in having (case blah (k1 k2) val ...). the comparison
;would be with '(k1 k2), which is almost certainly not ...
;well, it's impossible with non-shared code.
;anyway, it is impractical.  therefore...

(mac case args
  (cons 'casen args))

;must define withs
;... several macros will eat pairs like this.

;returns `(,vars ,vals ,body)
#;(def get-with-arglist (xs) ;version 0
  (if (or atom?xs no?cdr.xs)
      (list nil nil xs)
      cons?car.xs
      (let u (tuples 2 car.xs)
        (list (map car xs) (map cadr xs) cdr.xs))
      (xloop (vars nil vals nil xs xs)
        (if (or no?xs no?cdr.xs no:sym?car.xs ssyntax?car.xs)
            (list rev.vars rev.vals xs)
            (next (cons car.xs vars)
                  (cons cadr.xs vals)
                  cddr.xs)))))

;so good
;arc> (do (= u nil) (while t (let h (pbpaste) (unless (is h u) (pbcopy:tostring:write:dss:read:= u (pbpaste))) (sleep .1))))

(def get-with-arglist (xs) ;version 1: the usual ;also fixing, but put into 0 too
  (if (or (atom xs) (no (cdr xs)))
      (list nil nil xs)
      (cons? (car xs))
      (let u (tuples 2 (car xs))
        (list (map car xs) (map cadr xs) (cdr xs)))
      (xloop (vars nil vals nil xs xs)
        (if (or (no xs) (no (cdr xs)) (no (sym? (car xs))) (ssyntax? (car xs)))
            (list (rev vars) (rev vals) xs)
            (next (cons (car xs) vars)
                  (cons (cadr xs) vals)
                  (cddr xs))))))

(mac with bd
  (let (vars vals body) (get-with-arglist bd)
    ;`((fn ,vars ,@body) ,@vals)))
    (list* (list* 'fn vars body) vals))) ;list* feels nicer here than cons

(mac withs bd
  (let (vars vals body) (get-with-arglist bd)
    (xloop (vars vars vals vals)
      (if (no vars)
          (cons 'do body)
          #;`(let ,car.vars ,car.vals
             ,(next cdr.vars cdr.vals))
          (list 'let (car vars) (car vals)
                (next (cdr vars) (cdr vals)))))))


;now the real stuff.

#;(def expand-quasiquote (xs)
  (let u (expand-qq xs 1)
    (if idfn?car.u
        cadr.u
        splice-pls?car.u
        (err "Inappropriate usage of unquote-splicing" u xs)
        u)))

(def expand-quasiquote (xs)
  (let u (expand-qq xs 1)
    (if (is 'idfn (car u))
        (cadr u)
        (is 'splice-pls (car u))
        (err "Inappropriate usage of unquote-splicing" u xs)
        u)))

#;(def expand-qq (x n)
  (if atom?x
      (list 'quote x)
      (case car.x
        quasiquote
        (let (u) cdr.x
          (narb 'quasiquote (expand-qq u inc.n)))
        unquote
        (let (u) cdr.x
          (if (is n 1)
              (list 'idfn u)
              (narb 'unquote (expand-qq u dec.n))))
        unquote-splicing
        (let (u) cdr.x
          (if (is n 1)
              (list 'splice-pls u)
              (narb 'unquote-splicing (expand-qq u dec.n))))
        (expand-qq-rest x n))))

(def expand-qq (x n)
  (if (atom? x)
      (list 'quote x)
      (case (car x)
        quasiquote
        (let (u) (cdr x)
          (qq-narb 'quasiquote (expand-qq u (+ n 1))))
        unquote
        (let (u) (cdr x)
          (if (is n 1)
              (list 'idfn u)
              (qq-narb 'unquote (expand-qq u (- n 1)))))
        unquote-splicing
        (let (u) (cdr x)
          (if (is n 1)
              (list 'splice-pls u)
              (qq-narb 'unquote-splicing (expand-qq u (- n 1)))))
        (expand-qq-rest x n))))

;smthg like (unquote 'x) -> '(unquote x),
;or (unquote (list x y)) -> (list 'unquote (list x y)).
#;(def narb (name v) ;version 0
  (let qname (list 'quote name)
    (casen car.v
      quote (list 'quote (list name cadr.v))
      (list* cons) (list* 'list* qname cdr.v)
      (list append) (list 'list qname v)
      idfn (list 'list qname cadr.v)
      splice-pls (list 'cons qname cadr.v)
      (err "WTF?" name v))))

(def qq-narb (name v) ;version 1: renamed and no ssx
  (let qname (list 'quote name)
    (casen (car v)
      quote (list 'quote (list name (cadr v)))
      (list* cons) (list* 'list* qname (cdr v))
      (list append) (list 'list qname v)
      idfn (list 'list qname (cadr v))
      splice-pls (list 'cons qname (cadr v))
      (err "WTF?" name v))))

#;(def expand-qq-rest (x n) ;version 0
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

(def expand-qq-rest (x n) ;version 1: no ssx, use case, use "is x 'dick" not "dick? x"
  (if (atom x)
      (list 'quote x)
      (withs a (expand-qq (car x) n)
             b (expand-qq-rest (cdr x) n)
             ad (car a) bd (car b)
        the-a (if (is 'idfn ad) (cadr a) a)
        the-b (if (is 'idfn bd) (cadr b) b)
        ;quote, list*, append, idfn, splice-pls, list, cons
        (if (and (is 'quote ad) (is 'quote bd))
            (list 'quote (cons (cadr a) (cadr b)))
            (is 'splice-pls ad)
            (if (iso b ''nil)
                (list 'idfn (cadr a))
                (is bd 'append)
                (list* 'append (cadr a) (cdr b))
                (list 'append (cadr a) the-b))
            (iso b ''nil)
            (list 'list the-a)
            (casen bd
              (list* cons) (list* 'list* the-a (cdr b))
              list (list* 'list the-a (cdr b))
              (list 'cons the-a the-b))))))


(def expand-qq-rest (x n) ;version 2: ...?
  (if (atom x)
      (list 'quote x)
      (withs a (expand-qq (car x) n)
             b (expand-qq-rest (cdr x) n)
             ad (car a) bd (car b)
        the-a (if (is 'idfn ad) (cadr a) a)
        the-b (if (is 'idfn bd) (cadr b) b)
        ;quote, list*, append, idfn, splice-pls, list, cons
        (if (and (is 'quote ad) (is 'quote bd))
            (list 'quote (cons (cadr a) (cadr b)))
            (is 'splice-pls ad)
            (if (iso b ''nil)
                (list 'idfn (cadr a))
                (is bd 'append)
                (list* 'append (cadr a) (cdr b))
                (list 'append (cadr a) the-b))
            (iso b ''nil)
            (list 'list the-a)
            (casen bd
              (list* cons) (list* 'list* the-a (cdr b))
              list (list* 'list the-a (cdr b))
              (list 'cons the-a the-b))))))

(mac the-quasiquote (x)
  (expand-quasiquote x))
(= tqq the-quasiquote)


