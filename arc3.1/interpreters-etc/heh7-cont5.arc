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


;goddammit this still ain't executing in constant space.
;I suspect Racket is unnecessarily saving dicks in the closures
;it creates.
;Therefore, I shall enforce the contrary.

;Goddammit.
;Even after all this, no success.
;Welp, time to clean some things up, then.
;--Well, actually, turns out I did gain success.
;Only problem was that I was still running version 4.
;Well, oh well.  Bwahahaha.
;... A reason to not make join-envs completely primitive is that
;it involves a potentially unbounded amount of work.
;Ok, throwing out version 6.
;Ok I will just clean up in version 6.

(def if3 (v th el) ;the single use of this is unnec.
  (if v (th) (el)))
(def make-alist xs
  (tuples 2 xs))

#;(= fn-table (table)
   fn-n 0)

;global fn: not saving anything.
(mac gfn (args . body)
  `',(eval `(fn ,args ,@body)))

#;(= stack-depth 0)
#;(mac def (name args . body)
  `(= ,name (fn ,args
              (++ stack-depth)
              ,@(butlast body)
              (-- stack-depth)
              ,last.body)))
;ghnarf
;moar...
                   

;ok so all conts will look like this:
;(closure <proc> <env>)
;interpreted-closures will look the same way.
;the process of creating them will look a little different.
;it'll create a runtime-closure with some variables saved, one
;of which is an interpreted-closure thing.

;continuation closures will generally take a single argument.
;(plus an env argument)
;other closures will take an env, a cont, and any number of arguments.
;... Arc closures should prob'ly be wrapped in some way, or smthg.
;mmm...

;(fn (x) (+ x 3))
;->
;(list 'closure
;      (gfn (ev k x) (k (+ x 3)))
;      nil)
;(fn (x) (g x))
;->
;(list 'closure
;      (gfn (ev k x) (g.1 g.2 k x))
;      nil)
;or (gfn (ev k x) (ccall g k x))
;but fuck that.
;(...)
;(fn (x) (fn (y) (g x y)))
;->
;(list 'closure
;      (gfn (ev k x)
;        (list 'closure
;              (gfn (ev k y)
;                (g.1 g.2 k (alref ev 'x) y))
;              (make-alist 'x x)))
;      nil)
;oh boy.
;this will be kind of terrible...
;--or not.


(def ccall (f . args)
  (apply f.1 f.2 args))
(def capply (f . args)
  (apply apply f.1 f.2 args)) ;lol

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
(= evlens nil)
(def join-envs (env arglist xs k)
  #;(push size.k evlens)
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
      ;(capply f idfn-closure xs) ;hmmph, idfn-closure? ;no
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

;ok this does not need a continuation argument.
;it is basically a primitive.
;oh and yes the crap shd be mvd from uapply to here

;hmm... so.
;either closures must take one argument always,
;or I need an apply-closure.
;latter, obviously.
;btw. the crap about uapply taking an unnecessary cont argument
;probably builds up a call stack and makes tail recursion not happen.
;should be illegal.
;anyway... apply-closure.

;yes, I be right.  of course. heh.

;ok so now user closures accept cont arguments.
;however, this is not apparent from the user code.
;mmm... address somehow.
;... well, accept it and pass it around.
(def eval-fn (xs env)
  (let (arglist . bodexprs) xs
    (list 'closure
          (gfn (ev k . args)
            (call-uclosure
             k ;oh man so much permutation
             args
             (alref ev 'arglist)
             (alref ev 'env)
             (alref ev 'bodexprs)))
          (make-alist 'arglist arglist
                      'env env 'bodexprs bodexprs))))

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

;NOPE THIS STILL DOESN'T CHANGE THINGS
;And it doesn't look like the objects are getting bigger.
;Therefore... Racket call stack, it would seem.
;Let's take a look at that... if possible.  More like,
;inspect the code for dicks.
(= size
   ($ (lambda (x)
        (let ((seen (make-hasheq)))
          (let loop ((x x))
            (cond ((hash-ref seen x (not #t) #;omg) 0)
                  ((pair? x)
                   (hash-set! seen x #t)
                   (+ (loop (car x)) (loop (cdr x))))
                  (#t 1)))))))

;so a user function normally does this crap...
(def call-uclosure (k xs arglist env bodexprs)
  (join-envs env arglist xs
             (list 'closure
                   (gfn (ev u)
                        (ueval-progn u
                                     (alref ev 'bodexprs)
                                     (alref ev 'k)))
                   (make-alist 'bodexprs bodexprs
                               'k k))))

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
;upon reflection, this is the entire dick-user.
;ueval-call will probably, regrettably (hah),
;not do anything with the k argument if it calls a closure.
;as a matter of fact, I suspect it shouldn't have any k argument.
;... or smthg.
;let's take a look...
#;(= dicks nil)
;mmm, k does tend to be sizable. (but not grow huge)
;still... mmm...
;if it's one of those things like quote-object, then this is
;basically a primitive function.
;if it happens to be calling a macro, then there is cause for
;continuations to happen, but... mmm... this thing...
;and if it happens to be calling a closure, it is quite poss...
;mmm...
;this is really a portion of eval.
;so... we shall see...
;it really is possible for a macro to leak a continuation.
;in that case I want the continuation to be in a form I control.
;hence this crap.
;"apply-mac" should definitely take a continuation argument.
;"eval"... mmm...
;there are places where call/cc could happen.
;hmm...

;d'oh.
;closures need to take a continuation argument.
;... in addition to their env, I guess.
;I guess I'll compromise this time and put the cont argument
;at or near the front.

;ok so in a normal procedure call...
;user closures are (fn (ev k . args) ...).
;we shall handle this fine.
(def ueval-call (u xs env k)
  #;(push size.k dicks)
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
                           #;(ccall (alref ev 'k)
                                    (uapply (alref ev 'u)
                                            args))
                           (uapply (alref ev 'u)
                                   (alref ev 'k) ;there we go
                                   args))
                      (make-alist 'u u 'k k)))))
;I construct two closures here.
;Methinks I could conceivably construct them both at once.
;Mmm.

;... no, can't. "a" is not created until dick.
;... ok, well then. time to... reuse the old env.
;... no. too terrible.
;btw I should see if things like xloop execute in constant space.
;(which they should, just... see if that does happen)
;sharing env here, but...
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
      (let (x . rest) xs
        (if (and (acons x)
                 (is n 1)
                 (is car.x 'unquote-splicing))
            (ueval cadr.x env
                   (list 'closure
                         (gfn (ev a)
                           (eval-qq-tail (alref ev 'rest)
                                         (alref ev 'n)
                                         (alref ev 'env)
                                         (list 'closure
                                               (gfn (ev b)
                                                 (ccall (alref ev 'k)
                                                               (join (alref ev 'a)
                                                                     b)))
                                               (make-alist 'a a
                                                           'k (alref ev 'k)))))
                         (make-alist 'rest rest
                                     'n n 'env env 'k k)))
            (eval-qq x n env
                     (list 'closure
                           (gfn (ev a)
                             (eval-qq-tail (alref ev 'rest)
                                           (alref ev 'n)
                                           (alref ev 'env)
                                           (list 'closure
                                                 (gfn (ev b)
                                                   (ccall
                                                    (alref ev 'k)
                                                    (cons (alref ev 'a) b)))
                                                 (make-alist 'a a
                                                             'k (alref ev 'k)))))
                           (make-alist 'rest rest
                                       'n n 'env env 'k k)))))))
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
   ;global-value!nil nil
   global-value!apply-mac (fn (f xs) (apply-mac f xs idfn-cont))
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