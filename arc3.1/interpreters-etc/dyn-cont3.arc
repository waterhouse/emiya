;load this with ssx-load

;ok, what representation is it this time?
;shall we revert to `(closure ,env ,args ,body)?
;heh, why not.
;and then ... ah yes. my goal was to have some kind
;of exception handlers and crap...
;therefore...
;continuations.
;hmm...

;there was that experimental approach to making envs,
;where an item saved in the closure would describe the
;structure of the env field(s), and usually partial eval
;would eliminate all references to it.
;in a straight interpreter like this, this is a pretty
;dumb idea, because there is never more than one closure
;that shares a particular env structure.
;... however, I shall do it anyway. lolz.
;kk yeah...
;... hmm...
;actually, no. screw.

;I will want dynamic variables.
;Which will not actually be variables.
;As in Racket, they will be first-class objects, which will
;be called like functions (although I could change the latter)
;to obtain their value.
;I will probably have to think for a while about "space safety"
;with this crap. How it might be obtained.
;... Btw, should d(ynamic env) and e(nv) be completely separate,
;or can one be contained in the other?
;Fuck whatever. Neh.


;Executive decision:
;"Native procedures" will still exist as distinct from user closures,
;but they will use continuation-passing style.
;Furthermore, actually, they will take their continuation as an
;additional _first_ argument.
;Hey, I can use something I learned to slightly reduce allocation
;on the native Arc... (knowing 'bout arglists to avoid rest args)
;This will reinforce a separation between "procedures used" and
;"procedures exported", I suppose.
;... Um. They also need to take the dynamic environment.
;Well, we shall do that.
;Btw.
;The argument for putting the cont argument and other things first
;is that, in the native thing, there will be one register always used
;for the cont argument, and one register always used for the dyn-env
;argument, and so on.  (Self [i.e. env/closure] would be another. And
; some registers would probably be reserved for global and thread-local
; BS.) Independent of how many arguments are passed to a function.
;The first argument to a procedure is always found in the same place, no
;matter how many other arguments are passed.
;The last argument to a procedure is found in different places depending on
;how mayn other arguments are passed.
;Therefore, special arguments like k,d,e should go first in the calling
;convention.

(def ueval (x d e k)
  ;(prsn 'ueval x d e k)
  (if (or no?x num?x string?x char?x)
      k.x
      sym?x
      (lookup x d e k) ;need d for err
      cons?x
      (with k1 [ucall _ cdr.x d e k]
        (ueval car.x d e k1))
      (err "ueval: What is this?" d x)))

(def tuples-plus (n xs)
  (let (x y) (split rev.xs (mod len.xs n))
    (list (tuples n rev.y) rev.x)))

;same as case except you eval the test-exprs
(mac vcase (expr . clauses)
  (let (pairs default) (tuples-plus 2 clauses)
    (w/uniq gexpr
      `(let ,gexpr ,expr
         (if ,@(mappend (fn ((x y)) `((is ,gexpr ,x) ,y)) pairs)
             ,@default)))))

;ok, so, I will need a special form to parameterize things.
;is there any point in having "parameterize multiple things"
;be a primitive?  I don't think so. maybe conceivably with atomic
;crap... but no, you don't lock anyone else, you just...
;mmmyes. "dwith" should just be a macro. meanwhile I shall
;have a "dlet".
;... actually... does dlet even need to be ... I think it can be
;a procedure.  --well, except for the body portion.
;'course, many things could be written with a "more primitive"
;procedure that takes a thunk, with the usual form written as a
;macro on top of that.
;is there any reason to prefer one over the other?
;well, macro output of the non-thunk form looks much better, and
;is less verbose.
;meanwhile, if most of your BS depends on thunks, as in Racket,
;then it's easy for some idiot to run some completely different
;language on top of it (although, if your compiler isn't amazing,
; it may be kinda slower than it should be).
;anyway, special forms for me for the moment.

;note that, in this function, f has been eval'd, xs has not
(def ucall (f xs d e k)
  (vcase f
    qif (ueval-if xs d e k)
    qquote (let (x) xs k.x)
    qquasiquote (let (x) xs (ueval-qq x d e 1 k))
    qfn (let u `(clos ,e ,@xs) k.u) ;note don't need d
    qdlet 
    ;ok there are a couple of strategies
    ;I shall minimize allocation
    (let (var val . body) xs
      (with k1 (fn (vvar)
                 (if dyn?vvar
                     (withs
                       k2 [ubegin body _ e k]
                       k3 [derived-d vvar _ d k2]
                       (ueval val d e k3))
                     (uerror "Attempted to parameterize a non-dynvar" d var)))
        (ueval var d e k1)))
      
    qassign
    (let (x v) xs
      (let k1 [uassign x _ e k]
        (ueval v d e k1)))
    
    (if umac?f
        (let (mc clos) f
          (let k1 [ueval _ d e k]
            (uapply clos d xs k1)))
        (let k1 [uapply f d _ k]
          (map-ueval xs d e k1)))))

;oh man
(def map-ueval (xs d e k)
  (if no.xs
      k.xs
      (with k1 [let a _
                 (with k2 [let u (cons a _) k.u]
                   (map-ueval cdr.xs d e k2))]
        (ueval car.xs d e k1))))

;ok actually I'm going to imitate Arc and be like "making a macro
; from a fn can be a procedure".

;I am faced with a strong temptation to have macros not use the
;dynamic environment.
;Hmm...
;Recall that a macro is like saying (eval `(...)).
;So the question is then: should "eval" use the current dyn-env or not?
;...

;Hohoho. Racket provides a (current-parameterization).
;... As well as call-with-parameterization.

;By the way, quasiquote kind of could be a macro...
;... Interesting.
;If you say (eval `(...)), then what is used to compute
;the macro definitely depends on the current dyn-env.
;Therefore macex'ing should do that.
;As for how the result is eval'd--well, of course, yes.
;So, yes.
;Then what should user eval be?
;Well, ... if the user defined it as a procedure, then ...
;calling it would use the current dyn-env.
;A separate "eval in blank env" could be provided if desired.
;Also the lexenv could be specified, defaulting to nil.
;In the interest of laziness, I shall not provide that myself yet.
;However, user "apply" is definitely in core Arc.

;note that user "apply" will be bound to a tricky macro.
;(mc (f . args) (eval (cons `',f args))).
;that suffices.
;... actually, must be careful to have the right dyn-env.

;(= user-apply
;   `(macro (closure (f . args)
;                    ,(fn (d e f ag)
;                       (ucall 

;guh, generating code feels bad. oh well.

;... actually, it would appear that this would work just fine...
;(mac apply (f . xs) (cons f xs))
;Assuming it is fine ...

;(let xs '(1 2 3)
;  (apply + xs))
;->
;(let xs '(1 2 3)
;  (+ . xs))
;->
;...
;Oh fuck, no, does not work.
;(apply f (cdr xs)) ≠ (f cdr xs).
;Ok, so much for any remnants of the idea that "compose" behavior
;with macros could be justified in an interpreter unless it took
;care of that in an ssexpansion phase.

;Well, then. Back to "apply" being nonsensical on a macro.

;this works on closures and pseudo-functions

(def uapply (f d args k)
  #;(prsn 'uapply 'f f 'd d 'args args 'k k)
  (if uclos?f
      (let (cls ev ag . bd) f
        (let k1 [ubegin bd d _ k]
          (join-e ev ag args k1)))
      fn?f
      (apply f k d args)
      (let dest (if table?f utable-ref
                    string?f ustring-ref
                    dyn?f dyn
                    ;fn?f uapply-builtin
                    cons?f ulist-ref ;must ask for this after things that are conses
                    uerror)
        ;(prsn 'uapply f d args k)
        (let res (dest f d args)
          k.res))))

;(var) => lookup
;(var val) => assignment (which, according to PLT and CL, will only
;                         affect the bottommost assignment--well duh)
(def dyn (f d args)
  (if no.args
      (dyn-lookup d f)
      (let (x) args
        (dyn-assign f d x))))

(= globe (table)
   dyn-globe (table))

(= dyn-count 0)

(def make-dyn (x)
  (let n ++.dyn-count
    (= dyn-globe.n x)
    (cons 'dyn n)))

(def dyn? (x)
  (and cons?x (is car.x 'dyn)))

(def dyn-id (x)
  cdr.x)

;my instincts dictate that lookup is "d x".
(def dyn-lookup (d x)
  (let x dyn-id.x
    (aif (assoc x d)
         cadr.it
         dyn-globe.x)))

;currently not in any way space safe or whatever
(def derived-d (var val d k)
  (let u (cons (list dyn-id.var val) d)
    k.u))

(def uclos? (x)
  (and cons?x (is car.x 'clos)))

;dsb
;(... it will throw an error if things aren't bound right...
; therefore, it should be passed d... hmm...
; fuck whatever for now)

;this is done with continuations; in general an arglist could be
;massive or could be cyclic, and we'd like to die gracefully in
;that case

(= dumb-n 0)
;btw I switched argument order, lolz
(def join-e (e argl args k)
  #;(when argl (prsn 'join-e 'argl argl 'args args))
  (if no?argl
      (if no?args
          k.e
          (err "Bad arglist binding (not en. args)" argl args e))
      sym?argl
      (let u (cons (list argl args) e)
        k.u)
      cons?argl
      (if cons?args
          (let k1 [join-e _ cdr.argl cdr.args k]
            (join-e e car.argl car.args k1))
          (err "Bad arglist binding (atommy args)" argl args e))
      (err "Bad arglist" argl e)))

;doesn't malloc, but eh, might as well accept a cont
;also let's inline the assoc part
(def lookup (x d e k) ;d for error and crap
  (if cons?e
      (if (is x caar.e)
          k:cadar.e
          (lookup x d cdr.e k))
      (aif globe.x
           (if (is it 'HELLA-NIL)
               k.nil
               k.it)
           (err "lookup: unbound variable" x d e))))

;likewise let us inline the assoc and crap
(def uassign (x v e k)
  (if cons?e
      (if (is x caar.e)
          (do (scar cdar.e v)
            k.v)
          (uassign x v cdr.e k))
      (do (= globe.x (or v 'HELLA-NIL))
        k.v)))

(def ubegin (xs d e k)
  (if no?cdr.xs
      (ueval car.xs d e k) ;if xs is nil, then we can get nil...
      (let k1 [ubegin cdr.xs d e k] ;ignores result passed
        (ueval car.xs d e k1))))

(def ueval-if (xs d e k)
  (if no?xs
      k.nil
      no?cdr.xs
      (ueval car.xs d e k)
      (let (a b . rest) xs
        (let k1 [if _
                    (ueval b d e k)
                    (ueval-if rest d e k)]
          (ueval a d e k1)))))

(def ulist-ref (xs d args)
  (let (n) args
    xs.n))
(def utable-ref (x d args)
  (if cdr.args
      (let (k default) args ;default ≠ thunk for now
        (x k default))
      (let (k) args
        x.k)))
(def ustring-ref (x d args)
  (let (n) args x.n))

(def no? (x) no.x)
(= num? $.number?
   cons? $.pair?
   string? $.string?
   table? $.hash?
   sym? $.symbol?
   fn? $.procedure?)

(def ue (x)
  (ueval dss.x nil nil idfn))

#;(def huh ()
  (pr "huh> ")
  (let k [do wrn._ (huh)]
    (ueval (read) nil nil k)))
(= huh-repl-cont-closure
   (fn (ignk ignd ignx)
     (pr "huh> ")
     (let k [do (= globe!that _)
              wrn._ 
              (huh-repl-cont-closure nil nil nil)]
       (ueval (read) nil nil k))))
(def huh ()
  (huh-repl-cont-closure nil nil nil))

(def make-umac (clos)
  (list 'macro clos))
(def umac? (x)
  (and cons?x (is car.x 'macro)))

(each x '(if quote quasiquote fn #;mc dlet assign)
  (let v (cons 'special-value x)
    (= (symbol-value:symb 'q x) v
       globe.x v)))


;ok now we must CPS-ify all inserted procedures.
;let's be a little nice.

(def auto-nerb (f)
  (let n $.procedure-arity.f
    (with
      gk (uniq)
      gd (uniq)
      xs (if num?n
             (n-of n (uniq))
             (uniq))
      gf (uniq)
      (eval `(let ,gf ',f
               (fn ,(list* gk gd xs)
                 (,gk
                  ,(if num?n
                      `(,gf ,@xs)
                      `(apply ,gf ,xs)))))))))

;OMGAW a continuation is supposed to contain the dynamic env
;...
;...
;um...
;actually, that should probably be saved elsewhere

;ok, now we have the problem that the continuation fucking looks different
;from normal closures--only taking one argument...
;Racket continuations are procedures, but not vice versa...
;aha, yes, I recall.
;according to the Appel, what we do is have call-cc actually save a wrapper
;closure-compatible procedure.
;now, this bothers me, because this will create a new procedure each time.
;if, for example, you save a continuation where you're just about to call
;call/cc and use that to save _that_ continuation somewhere, then successive
;calls to the first continuation will produce different objects that are
;supposed to represent the identical second continuation.
;Probably not acceptable.
;Anyway, it appears that the native solution will just have all continuations
;silently ignore the k,d arguments that are passed to it.
;Then there will be no need for duplication.
;As for me...
;Can I guarantee object identity by using some idiot hash table?
;Eeeyes, although it might be a bit strange that separate cases of
;having the continuation be idfn (which is one procedure) would yield
;the same continuation.
;In fact, what Arc should really do is use its own ccc and supply the
;resulting continuation to ueval.
;Well, anyway.

;the cont really should be usable as a user closure.
;however, for now, I must make a wrapper closure around it.
;I shall imagine that there really is a (lazily evaluated) wrapper closure,
;and we shall use a weak-hasheq for this.
(= cont-closure* ($.make-weak-hasheq))
(def cont-closure (k)
  (aif cont-closure*.k ;* is another candidate for special treatment...
       it
       (= cont-closure*.k
          (fn (ignk ignd x)
            k.x))))

(def char? (x) (isa x 'char))
(def chars->sym (xs)
  (unless (all char? xs)
    (err "Not all chars" xs))
  symb.xs)
(def int->char (n)
  char.n)
(def char->int (c)
  int.c)

;I am going to rapidly copy the R7RS exception system.
;So there's a raise function.
;It takes one argument and calls the current exception handler on that argument.
;Exception handlers should take one argument.
;Also, when called, they will find the default exception handler to be
;whatever it was when they were... created.
;Or bound or whatever.
;In general they'll find
;Now, a one-argument function will become a function that
;takes probably a few arguments, in my case...

;A closure should remain consistent. Same like with making continuations.
;Actually, these sort of are continuations.
;... Are they necessarily continuations?
;... 
;... No.
;An exception handler for "raise-continuable", if it returns, will return
;to where "raise-continuable" was called.
;I guess that means the continuation it's passed is the continuation of
;the "raise-continuable" expression.
;Meanwhile, an exception handler for "raise", if it returns, will "call
; some parent exception handler".
;That means the continuation it's passed (as k) is the parent exception
;handler. I am going to specify that it's the prior value of the
;"current-exception-handler" dynvar.

;A "continuation" will just be a function that happens to ignore its
;continuation argument (and never returns--these are eqv).

;Let's see...
;The exn handler itself must have its entire dyn-env stored within it.
;So...
;The closure that is the usual exception handler should 

;... I got confused about closures and continuations again.
;Call-cc in the interpreted Lisp is implemented with a bit of leaking
;of the fact of continuations in the compiled Lisp.
;The compiled Lisp is therefore written in continuation-passing style,
;or mostly so, to make this convenient.
;The usual continuations of the compiled Lisp only take one explicit argument.
;However, all closures of the 

;Ok, 

;... Suppose there's a user closure, f.
;If we execute the user code (f (g x)),
;this is equivalent to being like
;(uapply g d list.x [f _]).
;Hmm...
;Lolz.
;I may be a complete idiot... maybe.
;Eh, nah.
;So.
;Suppose we are like
;(f (g (h x))).
;This is like
;(uapply h d list.x [uapply g d list._ [uapply f d list._ k]]).
;Suppose that g('s body) is (ccc (fn (c) (push c safe-place) ...)).
;In that case, ideally, c should get bound to that exact closure:
;[uapply f d list._ k].
;And so my dictum about having a sticky-noted user-closure that represents
;that continuation makes sense.
;Incidentally, that thing contains the d it'll use.

;Ok, so, then, what happens when we try to pass off a user-closure as
;an exception handler.
;Well, in the above case, it's impossible for the user to write code
;that makes his user closure be the continuation.
;You may have g save the continuation in (f (g x)),
;but the continuation is not f (the user closure),
;but [uapply f d list._ k] (the compiled-Lisp continuation-closure).
;
;Things are probably coming to a resolution...
;In the case of the continuations, it is generally done like
;(withs k1 [uapply f d list._ k]
;       k2 [uapply g d list._ k1]
;  (uapply h d list.x k2))
;or, at least, it can in theory be done like that.
;In that case [I wrote cakes], it seems only right that call/cc
;should capture the exact arguments k2 and k1.
;Whereas 

;call-with-exn-handler will have to create a new closure
;(a compiled-Lisp continuation) given the user closure that it's given.
;it will contain the information "call this user closure with the dyn-env
; captured at time of creation". note that you could call-with-exn-handler
;the identical closure at different times, with different dynamic envs,
;and so obviously the resulting closure 
;call-cc targets a continuation that already exists by the time call-cc
;is called.
;call-with-exn-handler ... does not.
;incidentally, if the user clasure passed to call-with-exn-handler
;is _actually_ a continuation, then it'll ignore the dyn-env it's passed.
;it is conceivable that a compiler or runtime that understood this would cause
;that crap to just keep that user closure.

;Let's see.
;Thus far, the user hasn't been able to directly touch compiled-Lisp
;continuations. ccc provides "them", but what it provides is actually
;a continuation wrapped in a user closure.  (I may be able to get
; rid of that distinction.)
;(Though I now see that, since it must save the dyn-env, I can't
; actually save ... Fuck, shut up, stop confusing yourself.)
;However, I want the exn-handler dynvar to be plain and user-accessible.
;This has led to some confusion in my brain.
;I guess that, for this iteration, the user will have access to strange
;objects, and in the next iteration, ...
;Fuck.
;Ok, according to "raise-continuable" an exception handler will need to
;accept a k argument. Thus, user closure signature.
;I see.
;First iteration: no raise-continuable; exceptions are continuations.
;Second iteration: all continuations have closure signature...
;...

(def default-exn-handler (ignk ignd x)
  ;(prsn "Error!" x)
  (prsn "Exception!" x)
  ;(prn "Continuing with repl") ;that'd be irritating as fuck
  (huh-repl-cont-closure nil nil nil))
        
(= exn-handler-v (make-dyn default-exn-handler))        

;uapply; f d args k
;ok so we create a cont, containing the info about the current dyn-env.
(def ucall-with-exn-handler (x uthunk d k)
  ;(let current-exn-handler  ;turns out we do do that after all
    ;(let x-cont [uapply x d list._ current-exn-handler]
       ;(let x-closure (fn (k2 ignd x2)
       ;                 (uapply x d list.x2 k2))
  (let current-exn-handler (dyn-lookup d exn-handler-v)
    (let x-closure (fn (k2 d2 x2)
                     (let new-d2 (dyn-extend d exn-handler-v
                                             current-exn-handler)
                       (uapply x new-d2 list.x2 k2)))
      (let new-d (dyn-extend d exn-handler-v x-closure)
        (uapply uthunk new-d nil k)))))

;So raise should definitely ...
;Huh.
;If an exn-handler returns from being called by raise,
;that should probably be eqv to having the exn-handler call raise itself.
;... dyn-env... ....
;Huh, not sure exactly how this shit works... must test.
;Ok, Racket thinks that the exn handler should be called in the same dynamic
;environment as the call to raise.
;I.e.
;> (let ((z (make-parameter 8))) (call-with-exception-handler (lambda (x) (displayln x) (displayln (z))) (lambda () (parameterize ((z 15)) (raise "H" #t)))))
;H
;15
;uncaught exception: #<void>

;I'm pretty sure Racket is just being a dumb idiot here.

;Incidentally, the result is different with with-handlers.
;(let ((u (make-parameter 8))) 
;    (with-handlers (((lambda (x) #t)
;                     (lambda (x) (displayln x) (displayln (u)))))
;      (parameterize ((u 69)) (raise "H"))))
;--> the number printed is 8, not 69.

;To be sure:

;> (let ((z (make-parameter 8))) (call-with-exception-handler (lambda (x) (displayln x) (displayln (z)) (raise x)) (lambda () (parameterize ((z 15)) (raise "H" #t)))))
;H
;15
;raise called (with non-exception value) by exception handler: "H"; original raise called (with non-exception value): "H"

;So. How can you bind the exception handler to something else (creating dyn-env #2),
;then bind z to something else (creating dyn-env #3),
;then raise an exception in a dyn-env that obviously doesn't contain the first
;binding but does contain the second?
;Likely, Racket claims it ...
;Oh. It's R7RS that sez: "The system implicitly maintains a current
; exception handler in the dynamic environment."
;Well. Anyway.
;raise shall use the dyn-env saved in the exn-handler.
;(It'll use the current dyn-env to find that exn-handler, but.)

;... Um.
;It doesn't look like I can arrange for the definition of "raise"
;to have "return from exn handler" mean "call parent exn handler".
;It could only find that parent exn handler inside the closure that
;is the current exn handler, and since it is, as Shivers says, "Church-
; encoded", that is not permissible.
;So I do in fact nead some kind of "backup" or "uncaught" or "whatever
; exception handler".
;... R7RS sez that, if the "raise"d thing returns, a secondary exception
;is raised in the same dynamic environment as that thing.
;Right ho.

;... WTF.
;The R7RS sez that, when raise[-continuable]ing, the exn-handler procedure
;should be called in an identical dyn-env to the call to "raise", except
;for the fact that the exn-handler will be rebound to the dick saved in
;the exn-handler.
;Fuck.
;...
;... I may have to accept that as being a good idea.
;The most obvious dynvars so far, other than exn-handler, are stdin/out/error.
;If you parameterize stderr to be something else, then raise an error,
;it seems fairly obvious that what should be done is that stderr should stay
;being something else in the exn handler.
;It would be frustrating if you couldn't do that.
;Meanwhile, given this model, it seems easy to do the first model: save
;a continuation with the dyn-env you want, and have the exn handler call
;(or be) that continuation.

(def backup-exn-handler (ignk ignd x)
  (prsn "It happened again???" x)
  (huh-repl-cont-closure nil nil nil))

(def uraise (ignk d x)
  ;(prsn 'uraise ignk d x)
  (let f (dyn-lookup d exn-handler-v)
    ;prn.f
    (uapply f d list.x [apply backup-exn-handler d list.x _])))

(def uraise-continuable (k d x)
  (let f (dyn-lookup d exn-handler-v)
    (uapply f d list.x k)))

(def uerror args  ;only for a moment
  (apply prsn 'uerror args)
  (err args))

(each x
  '(+ - * /
    cons
    (apply (fn (k d f xs)
             (prsn 'user-uapply 'k k 'd d 'f f 'xs xs)
             (uapply f d xs k)))
    no car cdr is < > cadr
    prn list list* prsn
    int->char char->int chars->sym char
    cons?
    mod div
    make-dyn
    (make-mac (fn (k d x)
                (k (make-umac x))))
    (macro? (auto-nerb umac?))
    (unsafe-macro-fn auto-nerb.cadr)
    (eight make-dyn.8)
    (exn-handler exn-handler-v)
    (raise-continuable uraise-continuable)
    (raise uraise)
    (call-w/exn-handler (fn (k d x)
                          (let (f thunk) x
                            (ucall-with-exn-handler f thunk d k))))
                           
    (ccc (fn (k d f)
           (let user-cont cont-closure.k
             (uapply f d list.user-cont k))))
    (arc-eval (fn (k d x) k:eval.x))
    (eval (fn (k d x)
            (ueval x d nil k)))
    (test (fn (k d x)
            (prsn 'k k)
            (prsn 'd d)
            (prsn 'x x)))
    err
    (string-length auto-nerb.len) ;lolce
    string?
    (t 't)
    )
               
  (if sym?x
      (uassign x 
               auto-nerb:eval.x
               nil idfn)
      (let (x v) x
        (uassign x
                 eval.v
                 nil idfn))))

;Ok, so far it looks like things are basically working...
;Then what about call/cc?
;Hmm...
;I could have a special value for call/cc, treated specially by ... by uapply.
;I could have all system procs be forced to accept a cont argument.
;And I could make all closures into [ptr + env], and also make all system procs
; look like that.
;The first option is ugly.
;The second option seems right [inevitable in a native thing], and the third option
;is really kind of orthogonal.
;Let us then proceed.

;Right ho, it all seems to work.  Time for a bit of a standard library.
;Maybe I'll see if I can put qq into the stdlib.

;... All right, I've written a qq macro.
;Now...
;I think I'll take "chars->sym" and a few others as primitives...
;And then.
;Do I get to use ssyntax?
;...
;Actually, it seems like a good thing to do would be to put ssyntax
;into the stdlib.
;Oh man.
;Ok, then, I will need...
;- string-append
;- string->sym
;- sym->string
;- string-ref (that can be implied)
;- character comparisons
;- 

;Ok, in doing all the below,
;I am using "err" a bunch.
;I think I should make error handling a bit less magical before going
;very far.
;Oh man added chars, somewhat.
;Ok, things are probably working as is.
;I'll probably want an actual "char" function,
;and whatnot, that throws proper errors.
;Oh man.

([len:map [ueval _ nil nil idfn] _]
 '((assign mac (make-mac (fn (name args . body)
                           (list 'assign name
                                 (list 'make-mac
                                       (list* 'fn args body))))))
   (mac def (name args . body)
     (list 'assign name
           (list* 'fn args body)))
   (mac let (var val . body)
     (list (list* 'fn (list var) body) val))
   (mac do body
     (list* 'let nil body))
   (mac rfn (name args . body)
     (list 'let name nil
           (list 'assign name
                 (list* 'fn args body))))
   (def map1 (f xs)
     (if (no xs)
         nil
         (cons (f (car xs)) (map1 f (cdr xs)))))
   (def take (n xs)
     (if (if (is n 0) t (no xs)) ;no or
         nil
         (cons (car xs) (take (- n 1) (cdr xs)))))
   (def drop (n xs)
     (if (if (is n 0) t (no xs))
         xs
         (drop (- n 1) (cdr xs))))
   (def tuples (n xs)
     (if (no xs)
         nil
         (cons (take n xs) (tuples n (drop n xs)))))
   (mac xloop (varvals . body)
     (let vv (tuples 2 varvals)
       (list* (list* 'rfn 'next (map1 car vv) body)
              (map1 cadr vv))))
   
   (def flip (xs ys)
     (if (no xs)
         ys
         (flip (cdr xs) (cons (car xs) ys))))
   (def rev (xs)
     (flip xs nil))
   
   (assign uniq-count 0)
   (def decimal-digits (n)
     (xloop (n n xs nil)
       (if (is n 0)
           xs
           (next (div n 10)
                 (cons (mod n 10) xs)))))
   (def digit->char (n)
     (int->char (+ (char->int #\0) n)))
   (def uniq ()
     (chars->sym
      (list* #\g #\s
             (map1 digit->char
                   (decimal-digits (assign uniq-count
                                           (+ 1 uniq-count)))))))
   
   (mac or args
     (if (no args)
         nil
         (no (cdr args))
         (car args)
         (let g (uniq)
           (list 'let g (car args)
                 (list 'if g
                       g
                       (list* 'or (cdr args)))))))
   (mac and args
     (if (no args)
         ''t
         (no (cdr args))
         (car args)
         (list 'if (car args)
               (list* 'and (cdr args))))) ;implied nil
   (mac do body ;redefining to be better
     (if (and (cons? body) (no (cdr body)))
         (car body)
         (list* 'let nil nil body)))
   
   (def macro-fn (x)
     (if (macro? x)
         (unsafe-macro-fn x)
         (err "Not a macro!" x)))
   (def macex1 (x)
     #;(prsn 'macex1 x)
     (let u (eval (car x))
       #;(prsn 'macex1-macro u)
       (if (macro? u)
           (apply (macro-fn u) (cdr x))
           (err "macex1: Not a macro!" u x))))
   
   (def len (x)
     (if (string? x)
         (string-length x)
         (no x)
         0
         (cons? x)
         (xloop (i 1 x (cdr x))
           (if (no x)
               i
               (next (+ i 1) (cdr x))))
         (err "How do I len" x)))
   
   
   (def find-string (f s)
     (let slen (len s)
       (xloop (i 0)
         (if (> i slen)
             nil
             (f (s i))
             i
             (next (+ i 1))))))
   
   (def err args
     (raise (cons "Error:" args)))
       
     
   
   ))
   ;btw or can be safely written without uniq, assuming
   ;fn and if are not redefined, which is assumed anyway:
   
;   (or x y ...)
;   ->
;   (((fn (test b)
;       (if test
;           (fn () test)
;           b))
;     x
;     (fn () (or y ...))))
     
;Ok, exceptions appear to be working now.
;I'll clean up a bunch on next iteration.
          
          
          
          
   