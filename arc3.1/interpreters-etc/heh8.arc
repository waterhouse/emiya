;A scheme for handling "compose" in imitation of Arc.
;(compose mac-f g ...) -> (macro args `(',mac-f (,g (... ,@args))))
;(compose func-f mac-g ...) -> (macro args `(',func-f (',mac-g (... ,@args))))
;Note that you quote the things that have been already evaluated.
;Note also that this 

;One slight annoyance is that it's not just macros we must check for:
;it's also special objects.  Ah well.

;Another irritation is that repeated composition of functions will,
;in a naive way, lead to a bunch of stupid &rest arglists that contain
;just one argument.
;A point in favor of expanding f:g.b directly into (f (g b)) rather than
;((compose f g) b).
;That can be kind of an option, though.
;(Though likely the preferred option for stuff I will do.)

;Incidentally, I can still keep everything in non-ssexpanded form, and ssexpand
;upon each eval.
;Lolz.
;That is the natural thing to do.



;Oh god, one problem.
;macex1.  Does (macex1 '((compose mac-f g) blah blah)) expand?
;... it does, according to how I've defined it below.
;Actually, it also will err on (macex1 '(non-macro ...)).
;Eh, not a problem.
(def is-system-proc (x)
  (isa x 'fn))
(unless bound!global-value
  (= global-value
   (obj + + - - * * / / cons cons car car cdr cdr is is < < > >
        scar scar scdr scdr uniq uniq)))
(each s '(quote if = fn mc quasiquote arc unquote compose)
  (let obj-name (symb s '-object)
    (= symbol-value.obj-name `(special-form ,(string s))
       global-value.s symbol-value.obj-name)))
(def is-special (x)
  (and acons.x (is car.x 'special-form)))
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
  #;(prsn env exprs)
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
  #;(prsn 'ueval x)
  (if (isa x 'int)
      x
      (isa x 'sym)
      (aif ssyntax.x
           (ueval ssexpand.x env)
           (assoc x env)
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
      (is u compose-object)
      (eval-compose xs env)
      (and acons.u (is car.u 'macro))
      (ueval (apply-mac u xs) env)
      (uapply u (map-eval xs env))))
(def map-eval (xs env)
  (if no.xs
      nil
      (let (x . rest) xs
        (cons (ueval x env)
              (map-eval rest env)))))
;To acquire hygiene here, I could be like (,quote-object ,quoted-thing),
;but screw that.
;Ok...
;If f is macro and xs is (a b c), we want to produce:
;(macro (fn gargs `(',f (a (b (c ,@gargs))))))
;which is eqv to (fn gargs (list f (list 'a (list 'b (cons 'c gargs))))).
;Incidentally, it's logically eqv to generate code containing f or to put f
;in the env of the closure we make.
;We will do the former because it is simpler for us (because we in our current
; mind do not know about closure env representation).
;... If f is not macro or special form, then it is mundane and we compose.
#;(def eval-compose (xs env)
  (if no.xs
      idfn
      (let (qf . qrest) xs
        (if no.qrest
            (ueval qf env)
            (let f (ueval qf env)
              (if (and acons.f (in car.f 'macro 'special-form))
                  (w/uniq gargs
                    (let (xc . xs) rev.qrest ;lolz
                      `(macro (closure nil ,gargs
                                ,(xloop (xs xs expr `(cons ',xc ,gargs))
                                   (if no.xs
                                       `(list ',f ,expr)
                                       (next cdr.xs `(list ',(car xs) ,expr))))))))))))))
(def eval-compose (xs env)
  (if no.xs
      idfn
      (no cdr.xs)
      (ueval car.xs env)
      (eval-compose1 nil xs env)))
(def eval-compose1 (funcs xs env)
  (if no.xs
      (compose-rev funcs)
      (let (qf . rest) xs
        (let f (ueval qf env)
          (if (and acons.f (in car.f 'macro 'special-form))
              (let (xc . xs) rev.rest
                (let outer-func (and funcs (compose-rev funcs))
                  (w/uniq gargs
                    `(macro (closure nil ,gargs
                              ,(let uexpr `(list '',f
                                            ,(xloop (xs xs expr `(cons ',xc ,gargs))
                                               (if no.xs
                                                   expr
                                                   (next cdr.xs `(list ',(car xs) ,expr)))))
                                 (if outer-func
                                     `(list '',outer-func ,uexpr)
                                     uexpr)))))))
              (eval-compose1 (cons f funcs) rest env))))))
(def compose-rev (xs)
  (let (f . rest) xs
    (if no.rest
        f
        (w/uniq gargs
          `(closure nil ,gargs
             ,(xloop (xs rest expr `(apply ',f ,gargs))
                (if no.xs
                    expr
                    (next cdr.xs `(',(car xs) ,expr)))))))))
;humph, this quoting stuff doesn't seem to work well even in heh7...
;which would indicate that that sucks.
;my policy is to leave things be in earlier versions.
;in the meantime...
;--neh, turns out I was probably being an idiot

;k, I'm being stupid, so let's make it stupid.
;(plus:a:b x y)
;plus:a:b => (macro ...).
;(plus:a:b x y) => like (plus (a (b x y))).
;plus:a:b => (macro args
;              `(',plus (a (b ,@args))))
;or:
;plus:a:b => (macro args
;              (list ',plus (l
;... got it, needed more quoting and ridiculous crap: "(list '',x" vs "(',x".
              
  
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