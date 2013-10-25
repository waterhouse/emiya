;Here we shall be exactly correct about when we grab cars and cdrs.
(def is-system-proc (x)
  (isa x 'fn))
(= global-value
   (obj + + - - * * / / cons cons car car cdr cdr is is < < > >
        scar scar scdr scdr uniq uniq))
(each s '(quote if = fn mc quasiquote arc unquote)
  (let obj-name (symb s '-object)
    (= symbol-value.obj-name `(special-form ,(string s))
       global-value.s symbol-value.obj-name)))
(def eval-if (xs env)
  (if no.xs
      nil
      (let (a . axs) xs
        (if no.axs
            (ueval a env)
            ;... and I think I shall not go too far in pre-grabbing
            (ueval a env)
            (ueval car.axs env)
            (eval-if cdr.axs env)))))
(def ueval-progn (env exprs)
  (unless acons.exprs ;note we've already tested for nil
    (err "What kind of function body is this?" exprs))
  (let (x . rest) exprs
    (if no.rest
        (ueval x env) ;tail call!
        (do (ueval x env)
          (ueval-progn env rest)))))
(def join-envs (env arglist xs)
  (if no.arglist
      (if no.xs env (err "Too many arguments:" xs)) ;kind of strict
      acons.arglist
      (if no:acons.xs
          (err "Arg!" arglist xs)
          (join-envs (join-envs env car.arglist car.xs) cdr.arglist cdr.xs))
      (isa arglist 'sym)
      (cons (list arglist xs)
            ;in actual impl, envs would prob. be vectors with parent ptr,
            ;and could not remove shadowed vars from parent envs (unless
            ; compiler or GC could prove no one else would use those vars).
            ;dynamic-variable trees _would_ want tree-like treatment and
            ;the ability to GC old items.
            env)
      (err "What kind of argument is this?" arglist)))
(def eval-= (xs env)
  (let (v x . rest) xs
    (if no.rest
        (eval-=1 v x env)
        (do (eval-=1 v x env)
          (eval-= rest env)))))
(def eval-=1 (v x env)
  (let u (ueval x env)
    (aif (assoc v env)
         (= cadr.it u)
         (= global-value.v (or u 'HELLA-NIL)))))
(def uapply (f xs)
  (if (is-system-proc f)
      (apply f xs)
      (and acons.f (is car.f 'closure))
      (let (env arglist . bodexprs) cdr.f
        (if no.bodexprs
            nil
            (ueval-progn (join-envs env arglist xs) bodexprs)))
      ;if not prim proc or closure, then string, table, or list
      ;(must err on macros, though) (uapply is user-exposed)
      (and acons.f (is car.f 'macro))
      (err "Can't apply a macro." f xs)
      (in type.f 'string 'cons 'table)
      (apply f xs)
      (err "uapply: What is this?" f 'with 'args xs)))
;NOOB YOU'RE AN IDIOT
;YOU DON'T NEED TO DO SHADOWED NOR USED VARS
;(SO SUGGESTS WHOSIT, AND IT's PROBABLY RIGHT)
(def eval-fn (xs env)
  (withs ((arglist . bodexprs) xs)
         (list* 'closure
                env
                arglist
                bodexprs)))
(def ueval (x (o env nil))
  (if (isa x 'int)
      x
      (isa x 'sym)
      (aif (assoc x env)
           (cadr it)
           global-value.x
           (if (is it 'HELLA-NIL) 'nil it) ;DISMAL HACK (actually not too bad)
           (err "ueval: Not defined:" x))
      (and acons.x (is car.x 'special-object))
      x
      (alist x) ;hmmm... could make "acons" so that ((fn x x) . 1) would work,
                ;but then would have to look at the destructuring of arglist
                ;to see how to eval the args...
      (let (f . xs) x ;this is pretty explicitly inspired by lis.py
        (let u (ueval f env)
          (ueval-call u xs env)))
      (err "What is this?" x)))
(def ueval-call (u xs env)
  (if (is u quote-object)
      (car xs)
      (is u if-object)
      (eval-if xs env)
      (is u =-object)
      (eval-= xs env)
      (is u fn-object)
      (eval-fn xs env)
      (is u mc-object)
      (eval-macro xs env)
      (is u quasiquote-object)
      (eval-qq (car xs) 1 env)
      (is u arc-object)
      (eval car.xs)
      (and acons.u (is car.u 'macro))
      (ueval (apply-mac u xs) env)
      (uapply u (map-eval xs env))))
(def map-eval (xs env)
  (if no.xs
      nil
      (let (x . rest) xs
        (cons (ueval x env)
              (map-eval rest env)))))
  
(def eval-qq (x n env) ;hmm, special objects make this a little weird
  (if atom.x           ;should the reader have turned the `,,@ crap
      x                ;into special objects? ... no, could be quoted.
      (let (f . xs) x  ;well then, must do it this way. oh well.
        (if (is f 'quasiquote)
            (list 'quasiquote (eval-qq car.xs inc.n env))
            (is f 'unquote)
            (if (is n 1)
                (ueval car.xs env)
                (list 'unquote (eval-qq car.xs dec.n env)))
            (is f 'unquote-splicing)
            (if (is n 1)
                (err "Bad use of unquote-splicing")
                (list 'unquote-splicing (eval-qq car.xs dec.n env)))
            (cons (eval-qq f n env)
                  (eval-qq-tail xs n env)))))) ;ignoring error-checking
(def eval-qq-tail (xs n env)
  (if atom.xs
      xs
      (let (x . rest) xs
        (if (and (acons x)
                 (is n 1)
                 (is car.x 'unquote-splicing))
            (join (ueval cadr.x env)
                  (eval-qq-tail rest n env))
            (cons (eval-qq x n env)
                  (eval-qq-tail rest n env))))))
(def eval-macro (xs env) ;a macro is (mc (arg arg ...) body ...)
  (list 'macro
        (eval-fn xs env)))
(def apply-mac (f xs)
  (uapply (cadr f) xs))
(def heh ()
  (xloop (prompt t)
    (when prompt (pr "heh> "))
    (aif (read:readline)
         (when (isnt it 'quit) (do wrn:ueval.it next.t))
         next.nil)))

(= global-value!apply uapply
   global-value!eval ueval
   ;global-value!nil nil
   global-value!apply-mac apply-mac
   )

(no:ueval '((fn ()
              (= list (fn args args)
                 no (fn (x) (is x 'nil))
                 nil 'nil
                 list* (fn args (if (no (cdr args))
                                    (car args)
                                    (cons (car args) (apply list* (cdr args)))))
                 mac (mc (name args . body)
                         (list '= name (list* 'mc args body))))
              (mac def (name args . body)
                `(= ,name (fn ,args ,@body)))
              (def cadr (x) (car (cdr x)))
              (def macex1 (xs)
                (apply-mac (eval (car xs)) (cdr xs)))
              (mac let (var val . body)
                (list (list* 'fn (list var) body) val))
              (mac or args
                (if (no args)
                    ''t
                    (no (cdr args))
                    (car args)
                    (let u (uniq)
                      (list 'let u (car args)
                            (list 'if u u (list* 'or (cdr args)))))))
              (mac bracket-fn (body)
                (list 'fn '(_) body))
              (mac do body (list (list* 'fn () body)))
              (def accumulate (comb f xs init next done)
                (if (done xs)
                    init
                    (accumulate comb f
                                (next xs) (comb (f xs) init)
                                next done)))
;              (def take (n xs)
;                (if (or (no xs) (is n 0))
;                    nil
;                    (cons (car xs) (take (- n 1) (cdr xs)))))
;              (def drop (n xs)
;                (if (or (no xs) (is n 0))
;                    xs
;                    (drop (- n 1) (cdr xs))))
;              (def tuples (n xs)
;                (if (no xs)
;                    nil
;                    (cons (take n xs) (tuples n (drop n xs)))))
;              (def map1 (f xs)
;                (if (no xs)
;                    nil
;                    (cons (f (car xs)) (map1 f (cdr xs)))))
              (def id (x) x)
              (def rev (xs)
                (accumulate cons car xs nil cdr no))
              (mac -- (n . d)
                (list '= n (list '- n (if d (list 'quote d) 1))))
              (def take (n xs)
                (rev (accumulate cons car xs nil cdr [or (no _) (> 0 (-- n))])))
              (def drop (n xs)
                (if (or (is n 0) (no xs))
                    xs
                    (drop (- n 1) (cdr xs))))
              (def tuples (n xs)
                (rev (accumulate cons [take n _] xs nil [drop n _] no)))
              (def map1 (f xs)
                (rev (accumulate cons [f (car _)] xs nil cdr no)))
              (mac rfn (name args . body) ;oh man, circular data structure
                (list 'let name 'nil
                      (list '= name
                            (list* 'fn args body))))
              (mac xloop (varvals . body)
                 (list* (list* 'rfn 'next (map1 car (tuples 2 varvals)) body)
                        (map1 cadr (tuples 2 varvals)))))))