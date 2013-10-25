(def is-system-proc (x)
  (isa x (quote fn)))
(= global-value
   (obj + + - - * * / / cons cons car car cdr cdr is is < < > >))
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
  (if (and no.arglist no.xs)
      env
      (xor no.arglist no.xs)
      (err "Length mismatch:" arglist xs)
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
         (= (global-value car.xs) u))
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
           (global-value x fail*)
           (if (is it fail*) (err "ueval: Not defined:" x) it))
      (alist x)
      (if (is car.x (quote quote))
          (cadr x)
          (is car.x (quote if))
          (eval-if (cdr x) env)
          (is car.x (quote =))
          (eval-= (cdr x) env)
          (is car.x (quote fn))
          (eval-fn (cdr x) env)
          (uapply (ueval (car x) env)
                  (map (bracket-fn (ueval _ env))
                       (cdr x))))
      (err "What is this?" x)))
(def heh ()
  (xloop (prompt t)
    (when prompt (pr "heh> "))
    (aif (read:readline)
         (when (isnt it 'quit) (do prn:ueval.it next.t))
         next.nil)))
