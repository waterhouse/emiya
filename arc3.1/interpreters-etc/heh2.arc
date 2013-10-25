(def is-system-proc (x)
  (isa x (quote fn)))
(= global-value
   (obj + + - - * * / / cons cons car car cdr cdr is is < < > >
        scar scar scdr scdr uniq uniq)) ;FUCK HOW DO I MAKE SOMETHING NIL
(def eval-if (xs env)
  (if no.xs
      nil
      no:cdr.xs
      (ueval car.xs env)
      (ueval car.xs env)
      (ueval cadr.xs env)
      (eval-if cddr.xs env)))
(def uapply-loop (env exprs)
  (if no.exprs
      nil
      (let u (ueval car.exprs env)
        (if no:cdr.exprs
            u
            (uapply-loop env cdr.exprs)))))
(def join-envs (env arglist xs)
  (if no.arglist
      (if no.xs env (err "Too many arguments:" xs)) ;kind of strict
      acons.arglist
      (if no:acons.xs
          (err "Arg!" arglist xs)
          (join-envs (join-envs env car.arglist car.xs) cdr.arglist cdr.xs))
      (isa arglist (quote sym))
      (cons (list arglist xs)
            (rem (bracket-fn (is car._ arglist)) env))
      (err "What kind of argument is this?" arglist)))
(def eval-= (xs env)
  (let u (ueval cadr.xs env)
    (aif (assoc car.xs env)
         (= cadr.it u)
         (= (global-value car.xs) (or u 'HELLA-NIL)))
    (aif cddr.xs (eval-= it env) u)))
(def uapply (f xs)
  (if (is-system-proc f)
      (apply f xs)
      no:alist.f
      (err "uapply: What is this?" f (quote with) (quote args) xs)
      (is car.f (quote closure))
      (let (env arglist . bodexprs) cdr.f
        (uapply-loop (join-envs env arglist xs) bodexprs))
      (and acons.xs no:cdr.xs (isa car.xs 'int))
      f:car.xs
      (err "uapply: What is this?" f (quote with) (quote args) xs)))
(def eval-fn (xs env)
  (withs ((arglist . bodexprs) xs shadowed-vars flat.arglist used-vars flat.bodexprs)
         (list* 'closure
                (keep (bracket-fn (mem car._ used-vars))
                      (rem (bracket-fn (mem car._ shadowed-vars))
                           env))
                arglist
                bodexprs)))
(def ueval (x (o env nil))
  (if (isa x (quote int))
      x
      (isa x (quote sym))
      (aif (assoc x env)
           (cadr it)
           global-value.x
           (if (is it 'HELLA-NIL) 'nil it) ;DISMAL HACK (actually not too bad)
           (err "ueval: Not defined:" x))
      (alist x)
      (if (is car.x (quote quote))
          (cadr x)
          (is car.x (quote if))
          (eval-if (cdr x) env)
          (is car.x (quote =))
          (eval-= (cdr x) env)
          (is car.x (quote fn))
          (eval-fn (cdr x) env)
          (is car.x 'mc)
          (eval-macro (cdr x) env)
          (let u (ueval (car x) env)
            (if (and acons.u (is car.u 'macro))
                (ueval (apply-mac u (cdr x)) env)
                (uapply u
                        (map (bracket-fn (ueval _ env))
                             (cdr x))))))
      (err "What is this?" x)))
(def eval-macro (xs env) ;a macro is (mc (arg arg ...) body ...)
  (list 'macro
        (eval-fn xs env)))
(def apply-mac (f xs)
  (uapply (cadr f) xs))
(def heh ()
  (xloop (prompt t)
    (when prompt (pr "heh> "))
    (aif (read:readline)
         (when (isnt it 'quit) (do prn:ueval.it next.t))
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
                (list '= name (list* 'fn args body)))
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
              (mac do body (list* 'fn () body))
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