;Oh dear cps.
;Hmm... can I provide a call/cc?
;call/cc is a procedure, only a kind of special one...
;it cannot be treated normally by "uapply", although it
;must be treated normally by everything else.
;... at a certain level, it should basically be the built-in Racket
;call/cc. what I would gain from is having conts be represented
;in my way.
;... '(continuation 
;So most continuations will take one argument.
;A couple will take zero.
;Conceivably I could allow more than one, but prob' not.
;A continuation should simply be a closure, more or less...
;Hmm... The funny thing is... there would seem to be two kinds
;of closures.  One is in the interpreted language, the other is in
;the implementing language.  The former at the moment is represented
;with source code; the latter would be with compiled code.
;If I want uniformity, which I probably do, then I have two choices.
;One is to make base-closures use source code. The other is to make
;interpreted-closures use compiled code.
;As I have discussed elsewhere, the latter is probably the thing to
;go for... Just a tad of compiled code.
;The code would probably be, like... (eval <this> saved-env)...
;Hmm...
;Incidentally, with lambda-splitting and the env splitting (into
; env-info and an env vector), it seems λ-ex should be like:
;(fn (ev arg arg) (λ-code ev-info ev arg arg)).
;If we want to avoid any free variables, that is...

;Eh, whatever. At any rate, at the moment, I'm still using alist
;envs.
;Mmm, hmm...
;Closures in the runtime language would generally not be visible
;to the interpreted language, except as system-procs and now as
;continuations.
;My idea is to expose them a little...
;Also, I think generally the position of runtime-closures vs
;interpreted-closures would be enough to distinguish them...
;Generally. Until I add call/cc.
;Right...
;Meh. So all closures shall be made to look like `(,code ,env).
;I could even make fake wrappers for system-procs like +.
;That offends my sensibilities. Prob' not.
;Neway.

(def if3 (v th el)
  (if v (th) (el)))

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
(def eval-if (xs env k)
  (if no.xs
      (k nil)
      (let (a . axs) xs
        (if no.axs
            (ueval a env k)
            ;... and I think I shall not go too far in pre-grabbing
            (ueval a env
                   (fn (v)
                     (if3 v
                          (fn () (ueval car.axs env k))
                          (fn () (eval-if cdr.axs env k)))))))))
(def ueval-progn (env exprs k)
  (unless acons.exprs ;note we've already tested for nil
    (err "What kind of function body is this?" exprs))
  (let (x . rest) exprs
    (if no.rest
        (ueval x env k) ;tail call!
        (ueval x env
               (fn (ignored)
                 (ueval-progn env rest k))))))
(def join-envs (env arglist xs k)
  (if no.arglist
      (if no.xs
          (k env)
          (err "Too many arguments:" xs)) ;kind of strict
      acons.arglist
      (if no:acons.xs
          (err "Arg!" arglist xs)
          (join-envs env car.arglist car.xs
                     (fn (u)
                       (join-envs u cdr.arglist cdr.xs k))))
      (isa arglist 'sym)
      (k (cons (list arglist xs)
            ;in actual impl, envs would prob. be vectors with parent ptr,
            ;and could not remove shadowed vars from parent envs (unless
            ; compiler or GC could prove no one else would use those vars).
            ;dynamic-variable trees _would_ want tree-like treatment and
            ;the ability to GC old items.
            env))
      (err "What kind of argument is this?" arglist)))
(def eval-= (xs env k)
  (let (v x . rest) xs
    (if no.rest
        (eval-=1 v x env k)
        (eval-=1 v x env
                 (fn (ign)
                   (eval-= rest env k))))))
(def eval-=1 (v x env k)
  (ueval x env
         (fn (u)
           (aif (assoc v env)
                (k (= cadr.it u))
                (k (= global-value.v (or u 'HELLA-NIL)))))))
(def uapply (f xs k)
  (if (is-system-proc f)
      (k (apply f xs))
      (and acons.f (is car.f 'closure))
      (let (env arglist . bodexprs) cdr.f
        (if no.bodexprs
            (k nil)
            (join-envs env arglist xs
                       (fn (ev)
                         (ueval-progn ev bodexprs k)))))
      ;if not prim proc or closure, then string, table, or list
      ;(must err on macros, though) (uapply is user-exposed)
      (and acons.f (is car.f 'macro))
      (err "Can't apply a macro." f xs)
      (in type.f 'string 'cons 'table)
      (k (apply f xs))
      (err "uapply: What is this?" f 'with 'args xs)))
;NOOB YOU'RE AN IDIOT
;YOU DON'T NEED TO DO SHADOWED NOR USED VARS
;(SO SUGGESTS WHOSIT, AND IT's PROBABLY RIGHT)
(def eval-fn (xs env k)
  (withs ((arglist . bodexprs) xs)
    (k (list* 'closure
              env
              arglist
              bodexprs))))
(def ueval (x (o env nil) (o k idfn))
  (if (isa x 'int)
      (k x)
      (isa x 'sym)
      (aif (assoc x env)
           (k (cadr it))
           global-value.x
           (if (is it 'HELLA-NIL)
               (k 'nil)
               (k it)) ;DISMAL HACK (actually not too bad)
           (err "ueval: Not defined:" x))
      (and acons.x (is car.x 'special-object))
      (k x)
      (alist x) ;hmmm... could make "acons" so that ((fn x x) . 1) would work,
                ;but then would have to look at the destructuring of arglist
                ;to see how to eval the args...
      (let (f . xs) x ;this is pretty explicitly inspired by lis.py
        (ueval f env
               (fn (u) (ueval-call u xs env k))))
      (err "What is this?" x)))
(def ueval-call (u xs env k)
  (if (is u quote-object)
      (k (car xs))
      (is u if-object)
      (eval-if xs env k)
      (is u =-object)
      (eval-= xs env k)
      (is u fn-object)
      (eval-fn xs env k)
      (is u mc-object)
      (eval-macro xs env k)
      (is u quasiquote-object)
      (eval-qq (car xs) 1 env k)
      (is u arc-object)
      (k (eval car.xs))
      (and acons.u (is car.u 'macro))
      (apply-mac u xs (fn (expr)
                        (ueval expr env k)))
      (map-eval xs env
                (fn (arglist)
                  (uapply u arglist k)))))
(def map-eval (xs env k)
  (if no.xs
      (k nil)
      (let (x . rest) xs
        (ueval x env
               (fn (a)
                 (map-eval rest env
                           (fn (b)
                             (k (cons a b)))))))))
  
(def eval-qq (x n env k) ;hmm, special objects make this a little weird
  (if atom.x           ;should the reader have turned the `,,@ crap
      (k x)                ;into special objects? ... no, could be quoted.
      (let (f . xs) x  ;well then, must do it this way. oh well.
        (if (is f 'quasiquote)
            (eval-qq car.xs inc.n env
                     (fn (h) (k (list 'quasiquote h))))
            (is f 'unquote)
            (if (is n 1)
                (ueval car.xs env k)
                (eval-qq car.xs dec.n env
                         (fn (h) (k (list 'unquote h)))))
            (is f 'unquote-splicing)
            (if (is n 1)
                (err "Bad use of unquote-splicing")
                (eval-qq car.xs dec.n env
                         (fn (h) (k (list 'unquote-splicing h)))))
            (eval-qq f n env
                     (fn (a)
                       (eval-qq-tail xs n env
                                     (fn (b)
                                       (k (cons a b)))))))))) ;ignoring error-checking
(def eval-qq-tail (xs n env k)
  (if atom.xs
      (k xs)
      (let (x . rest) xs
        (if (and (acons x)
                 (is n 1)
                 (is car.x 'unquote-splicing))
            (ueval cadr.x env
                   (fn (a)
                     (eval-qq-tail rest n env
                                   (fn (b) (k (join a b))))))
            (eval-qq x n env
                     (fn (a)
                       (eval-qq-tail rest n env
                                     (fn (b) (k (cons a b))))))))))
(def eval-macro (xs env k) ;a macro is (mc (arg arg ...) body ...)
  (eval-fn xs env
           (fn (h)
             (k (list 'macro h)))))
(def apply-mac (f xs k)
  (uapply (cadr f) xs k))
(def heh ()
  (xloop (prompt t)
    (when prompt (pr "heh> "))
    (aif (read:readline)
         (when (isnt it 'quit) (do wrn:ueval.it next.t))
         next.nil)))

(= global-value!apply (fn (f . xs)
                        (apply uapply f (join xs list.idfn)))
   global-value!eval ueval
   ;global-value!nil nil
   global-value!apply-mac (fn (f xs) (apply-mac f xs idfn))
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