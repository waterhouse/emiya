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

(def ueval (x d e)
  ;(prsn x d e)
  (if (or no?x num?x string?x)
      x
      sym?x
      (lookup x d e) ;need d for err
      cons?x
      (ucall (ueval car.x d e)
             cdr.x
             d
             e)
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
(def ucall (f xs d e)
  (vcase f
    qif (ueval-if xs d e)
    qquote (let (x) xs x)
    qquasiquote (let (x) xs (ueval-qq x d e 1))
    qfn (let (argl . body) xs (ueval-fn argl body e)) ;note don't need d
    ;qmc (let (argl . body) xs (ueval-mc arg1 body e)) ;likewise
    qdlet (let (var val . body) xs
            (let var (ueval var d e)
              (if dyn?var
                  (let val (ueval val d e)
                    (let d2 (derived-d var val d)
                      (ubegin body d2 e)))
                  (uerror "Attempted to parameterize a non-dynvar"
                          d var))))
    qassign (let (x v) xs
              (let vv (ueval v d e)
                (uassign x vv e)))
    
    (if umac?f
        (let (mc clos) f
          (ueval (uapply clos d xs) d e))
        (let args (map [ueval _ d e] xs)
          (uapply f d args)))))

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
(def uapply (f d args)
  ;(prsn f d args)
  (let dest (if uclos?f uapply-clos
                table?f utable-ref
                string?f ustring-ref
                dyn?f dyn
                fn?f uapply-builtin
                cons?f ulist-ref ;must ask for this after things that are conses
                uerror)
    (dest f d args)))

;(var) => lookup
;(var val) => assignment (which, according to PLT and CL, will only
;                         affect the bottommost assignment--well duh)
(def dyn (f d args)
  (if no.args
      (dyn-lookup f d)
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

(def dyn-lookup (x d)
  (let x dyn-id.x
    (aif (assoc x d)
         cadr.it
         dyn-globe.x)))

;currently not in any way space safe or whatever
(def derived-d (var val d)
  (cons (list dyn-id.var val) d))

(def ueval-fn (argl body e)
  `(clos ,argl ,body ,e))

(def uclos? (x)
  (and cons?x (is car.x 'clos)))

(def uapply-clos (f d args)
  (let (cls argl body e) f
    (let e2 (join-e argl args e)
      (ubegin body d e2))))

;dsb
;(... it will throw an error if things aren't bound right...
; therefore, it should be passed d... hmm...
; fuck whatever for now)
(def join-e (argl args e)
  (if no?argl
      (if no?args
          e
          (err "Bad arglist binding (not en. args)" argl args e))
      sym?argl
      (cons (list argl args) e)
      cons?argl
      (if cons?args
          (join-e cdr.argl cdr.args
                  (join-e car.argl car.args e))
          (err "Bad arglist binding (atommy args)" argl args e))
      (err "Bad arglist" argl e)))

(def lookup (x d e) ;d for error and crap
  (aif (assoc x e)
       cadr.it
       globe.x
       (if (is it 'HELLA-NIL)
           nil
           it)
       (err "lookup: unbound variable" x d e)))

(def uassign (x v e)
  (aif (assoc x e)
       (scar cdr.it v)
       (= globe.x (or v 'HELLA-NIL))))

(def ubegin (xs d e)
  (if no?cdr.xs
      (ueval car.xs d e) ;if xs is nil, then we can get nil...
      (let ignored (ueval car.xs d e)
        (ubegin cdr.xs d e))))

(def ueval-if (xs d e)
  (if no?xs
      nil
      no?cdr.xs
      (ueval car.xs d e)
      (let (a b . rest) xs
        (if (ueval a d e)
            (ueval b d e)
            (ueval-if rest d e)))))

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
  (ueval dss.x nil nil))

(def uapply-builtin (f d args)
  (apply f args))

(def make-umac (clos)
  (list 'macro clos))
(def umac? (x)
  (and cons?x (is car.x 'macro)))

(each x '(if quote quasiquote fn #;mc dlet assign)
  (let v (cons 'special-value x)
    (= (symbol-value:symb 'q x) v
       globe.x v)))

(each x 
  '(+ - * /
    cons (apply uapply)
    no car cdr
    make-dyn
    (make-mac make-umac)
    (eight make-dyn.8)
    )
  (if sym?x
      (uassign x eval.x nil)
      (let (x v) x
        (uassign x eval.v nil))))

;Ok, so far it looks like things are basically working...



         