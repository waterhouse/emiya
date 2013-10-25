;Closures: (list 'closure <closure-fn> <env>)
;closure-fn: (fn (ev k . args) ...)
;env: (list (list 'name val) ...)
;Usually, closure-fn:
;(fn (ev k . args)
;  (eval '(body) (new-env '(env) args arglist) k))
;However, call-cc's fn will be:
;(fn (ev k f)
;  (f k))
;Normally, k is a cont-closure.
;cont-closure: (list 'closure (fn (ev v) ...))

;I think I'll have a nicely named closure-fn thing.
;Rather than some weird-ass thing.

;All right.  I think shit is done here, so time for cleanup.

(def if3 (v th el) ;the single use of this is unnec.
  (if v (th) (el)))
(def make-alist xs
  (tuples 2 xs))

;global fn: not saving anything. demonstrates success.
(mac gfn (args . body)
  `',(eval `(fn ,args ,@body)))

(def ccall (f . args)
  (apply f.1 f.2 args))
(def capply (f . args)
  (apply apply f.1 f.2 args)) ;lol

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
      (ccall k nil)
      (let (a . axs) xs
        (if no.axs
            (ueval a env k)
            ;... and I think I shall not go too far in pre-grabbing
            (ueval a env
                   (list 'closure
                         (gfn (ev v)
                           (if v
                               (ueval (car:alref ev 'axs)
                                      (alref ev 'env)
                                      (alref ev 'k))
                               (eval-if (cdr:alref ev 'axs)
                                        (alref ev 'env)
                                        (alref ev 'k))))
                         (make-alist 'env env 'axs axs 'k k)))))))
                         
(def ueval-progn (env exprs k)
  (unless acons.exprs ;note we've already tested for nil
    (err "What kind of function body is this?" exprs))
  (let (x . rest) exprs
    (if no.rest
        (ueval x env k) ;tail call!
        (ueval x env
               (list 'closure
                     (gfn (ev ignored)
                       (ueval-progn (alref ev 'env)
                                    (alref ev 'rest)
                                    (alref ev 'k)))
                     (make-alist 'env env 'rest rest 'k k))))))
(def join-envs (env arglist xs k)
  (if no.arglist
      (if no.xs
          (ccall k env)
          (err "Too many arguments:" xs)) ;kind of strict
      acons.arglist
      (if no:acons.xs
          (err "Arg!" arglist xs)
          (join-envs env car.arglist car.xs
                     (list 'closure
                           (gfn (ev u)
                             (join-envs u (cdr:alref ev 'arglist)
                                        (cdr:alref ev 'xs)
                                        (alref ev 'k)))
                           (make-alist 'arglist arglist
                                       'xs xs 'k k))))
      (isa arglist 'sym)
      (ccall k (cons (list arglist xs) env))
      (err "What kind of argument is this?" arglist)))
(def eval-= (xs env k)
  (let (v x . rest) xs
    (if no.rest
        (eval-=1 v x env k)
        (eval-=1 v x env
                 (list 'closure
                       (gfn (ev ign)
                         (eval-= (alref ev 'rest)
                                 (alref ev 'env)
                                 (alref ev 'k)))
                       (make-alist 'rest rest 'env env 'k k))))))
(def eval-=1 (v x env k)
  (ueval x env
         (list 'closure
               (gfn (ev u)
                 (aif (assoc (alref ev 'v)
                             (alref ev 'env))
                      (ccall (alref ev 'k)
                             (= cadr.it u))
                      (ccall (alref ev 'k)
                             (= (global-value (alref ev 'v))
                                (or u 'HELLA-NIL)))))
               (make-alist 'v v 'env env 'k k))))
(def uapply (f k xs) ;making things less terrible with k
  (if (is-system-proc f)
      (ccall k (apply f xs)) ;either this or wrappers around all sysfuncs
      (and acons.f (is car.f 'closure))
      (capply f k xs)
      ;if not prim proc or closure, then string, table, or list
      ;(must err on macros, though) (uapply is user-exposed)
      (and acons.f (is car.f 'macro))
      (err "Can't apply a macro." f xs)
      (in type.f 'string 'cons 'table)
      (ccall k (apply f xs))
      (err "uapply: What is this?" f 'with 'args xs)))
;NOOB YOU'RE AN IDIOT
;YOU DON'T NEED TO DO SHADOWED NOR USED VARS
;(SO SUGGESTS WHOSIT, AND IT's PROBABLY RIGHT)

(def eval-fn (xs env)
  (let (arglist . body) xs
    (list 'closure
          eval-body
          (make-alist 'arglist arglist
                      'env env 'body body))))

(def eval-body (ev k . args)
  #;(prsn 'eval-body ev k args)
  (join-envs (alref ev 'env)
             (alref ev 'arglist)
             args
             (list 'closure
                   (gfn (ev u)
                        ;(prsn 'eval-body-nub ev u)
                        (ueval-progn u
                                     (alref ev 'body)
                                     (alref ev 'k)))
                   (make-alist 'body (alref ev 'body)
                               'k k))))

;join-envs really could be a primitive. oh well.
;... yes, this does not need a cont argument...
;the uclosure could very well go back to the toplevel.
;this thing shall fake an idfn thing.
(= idfn-closure (list 'closure
                      (fn (ev k x) (k x))
                      nil)
   idfn-cont (list 'closure
                   (fn (ev x) x)
                   nil))

#;(= size
   ($ (lambda (x)
        (let ((seen (make-hasheq)))
          (let loop ((x x))
            (cond ((hash-ref seen x (not #t) #;omg) 0)
                  ((pair? x)
                   (hash-set! seen x #t)
                   (+ (loop (car x)) (loop (cdr x))))
                  (#t 1)))))))

(def ueval (x (o env nil) (o k idfn-cont))
  (if (isa x 'int)
      (ccall k x)
      (isa x 'sym)
      (aif (assoc x env)
           (ccall k (cadr it))
           global-value.x
           (if (is it 'HELLA-NIL)
               (ccall k 'nil)
               (ccall k it)) ;DISMAL HACK (actually not too bad)
           (err "ueval: Not defined:" x))
      (and acons.x (is car.x 'special-object))
      (ccall k x)
      (alist x) ;hmmm... could make "acons" so that ((fn x x) . 1) would work,
                ;but then would have to look at the destructuring of arglist
                ;to see how to eval the args...
      (let (f . xs) x ;this is pretty explicitly inspired by lis.py
        (ueval f env
               (list 'closure
                      (gfn (ev u)
                        (ueval-call u (alref ev 'xs)
                                    (alref ev 'env)
                                    (alref ev 'k)))
                      (make-alist 'xs xs 'env env 'k k))))
      (err "What is this?" x)))

(def ueval-call (u xs env k)
  (if (is u quote-object)
      (ccall k (car xs))
      (is u if-object)
      (eval-if xs env k)
      (is u =-object)
      (eval-= xs env k)
      (is u fn-object)
      (ccall k (eval-fn xs env))
      (is u mc-object)
      (ccall k (eval-macro xs env))
      (is u quasiquote-object)
      (eval-qq (car xs) 1 env k)
      (is u arc-object)
      (ccall k (eval car.xs))
      (and acons.u (is car.u 'macro))
      (apply-mac u xs
        (list 'closure
              (gfn (ev expr)
                (ueval expr (alref ev 'env)
                       (alref ev 'k)))
              (make-alist 'env env 'k k)))
      (map-eval xs env
                (list 'closure
                      (gfn (ev args) ;ok this was one dick-user (half)
                           (uapply (alref ev 'u)
                                   (alref ev 'k) ;there we go
                                   args))
                      (make-alist 'u u 'k k)))))

;sharing env here boss
(def map-eval (xs env k)
 (if no.xs
   (ccall k nil)
   (let
       (x . rest)
       xs
     (ueval x env
       (list 'closure
         (gfn (ev a)
           (map-eval
             (alref ev 'rest)
             (alref ev 'env)
             (list 'closure
               (gfn (ev b)
                 (ccall
                   (alref ev 'k)
                   (cons
                     (alref ev 'a)
                     b)))
               (cons
                 (list 'a a)
                 cddr.ev))))
         (make-alist 'rest rest 'env env 'k k))))))

;hmm, special objects make this a little weird
;should the reader have turned the `,,@ crap
;into special objects? ... no, could be quoted.
;well then, must do it this way. oh well.
;ignore error-checking
(def eval-qq (x n env k)
 (if atom.x
   (ccall k x)
   (let (f . xs)
        x
     (if
       (is f 'quasiquote)
       (eval-qq car.xs inc.n env
         (list 'closure
           (gfn (ev h)
             (ccall
               (alref ev 'k)
               (list 'quasiquote h)))
           (make-alist 'k k)))
       (is f 'unquote)
       (if
         (is n 1)
         (ueval car.xs env k)
         (eval-qq car.xs dec.n env
           (list 'closure
             (gfn (ev h)
               (ccall
                 (alref ev 'k)
                 (list 'unquote h)))
             (make-alist 'k k))))
       (is f 'unquote-splicing)
       (if
         (is n 1)
         (err "Bad use of unquote-splicing")
         (eval-qq car.xs dec.n env
           (list 'closure
             (gfn (ev h)
               (ccall
                 (alref ev 'k)
                 (list 'unquote-splicing h)))
             (make-alist 'k k))))
       (eval-qq f n env
         (list 'closure
           (gfn (ev a)
             (eval-qq-tail
               (alref ev 'xs)
               (alref ev 'n)
               (alref ev 'env)
               (list 'closure
                 (gfn (ev b)
                   (ccall
                     (alref ev 'k)
                     (cons
                       (alref ev 'a)
                       b)))
                 (make-alist 'k
                   (alref ev 'k)
                   'a a))))
           (make-alist 'xs xs 'n n 'env env 'k k)))))))

;I see.  It is the difference between flattening closures and sharing
;them. In *this* code, the eval code is completely functional except
;for the effects to the global-value table, so it makes no difference.
;(If it did make a difference, it should be shared.)
(def eval-qq-tail (xs n env k)
 (if atom.xs
   (ccall k xs)
   (let (x . rest)
        xs
     (if (and
          (acons x)
          (is n 1)
          (is car.x 'unquote-splicing))
       (ueval cadr.x env
         (list 'closure
           (gfn
             (ev a)
             (eval-qq-tail
               (alref ev 'rest)
               (alref ev 'n)
               (alref ev 'env)
               (list 'closure
                 (gfn
                   (ev b)
                   (ccall
                     (alref ev 'k)
                     (join
                       (alref ev 'a)
                       b)))
                 (make-alist 'a a 'k
                   (alref ev 'k)))))
           (make-alist 'rest rest 'n n 'env env 'k k)))
       (eval-qq x n env
         (list 'closure
           (gfn
             (ev a)
             (eval-qq-tail
               (alref ev 'rest)
               (alref ev 'n)
               (alref ev 'env)
               (list 'closure
                 (gfn
                   (ev b)
                   (ccall
                     (alref ev 'k)
                     (cons
                       (alref ev 'a)
                       b)))
                 (make-alist 'a a 'k
                   (alref ev 'k)))))
           (make-alist 'rest rest 'n n 'env env 'k k)))))))

(def eval-macro (xs env) ;a macro is (mc (arg arg ...) body ...)
  (list 'macro (eval-fn xs env)))
(def apply-mac (f xs k)
  (uapply (cadr f) k xs))
(def heh ()
  (xloop (prompt t)
    (when prompt (pr "heh> "))
    (aif (read:readline)
         (when (isnt it 'quit) (do wrn:ueval.it next.t))
         next.nil)))

(= global-value!apply (fn (f . xs)
                        (apply uapply f idfn-cont xs))
   global-value!eval ueval
   global-value!apply-mac (fn (f xs) (apply-mac f xs idfn-cont)))

;so the issue with call/cc is that there are two kinds of closures,
;user closures and conts, with diff. calling conventions (conts
; take no cont argument, closures take one cont argument), and
;if they have equal status, so that a given variable x could be
;bound to either a cont or a user closure, then that is problematic.
;me solves this by making call/cc wrap its cont in a user-closure.
;now time to check the Appel.

#;(def ucall/cc (ev k f)
  (prsn 'ucall/cc ev k f)
  #;(ccall f k)
  ;it's a user closure... hmmm...
  (ccall idfn-closure k)
    ;that reveals an error. expects 3 args.
  )

#;(def ucall/cc (ev k f)
  (ccall f k idfn-closure))
;mmm...

#;(def ucall/cc (ev k f)
  (uapply f k
          (list k)))

(def ucall/cc (ev k f)
  (ccall f k
         (list 'closure
               (fn (ev k2 x)
                 (ccall (alref ev 'k) x))
               (make-alist 'k k))))


(= global-value!ccc (list 'closure
                          ucall/cc
                          nil)
   global-value!fake-add3
   (list 'closure
         (fn (ev k x) (ccall k (+ x 3)))
         nil))

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
              (def take (n xs)
                (if (or (no xs) (is n 0))
                    nil
                    (cons (car xs) (take (- n 1) (cdr xs)))))
              (def drop (n xs)
                (if (or (no xs) (is n 0))
                    xs
                    (drop (- n 1) (cdr xs))))
              (def tuples (n xs)
                (if (no xs)
                    nil
                    (cons (take n xs) (tuples n (drop n xs)))))
              (def map1 (f xs)
                (if (no xs)
                    nil
                    (cons (f (car xs)) (map1 f (cdr xs)))))
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