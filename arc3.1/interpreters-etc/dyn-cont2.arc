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
        (let res (dest f d args)
          k.res))))

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
  (wrn:ue:read)
  (huh))
;play better with user ccc...
(def huh ()
  (pr "huh> ")
  (let k [do wrn._ (huh)]
    (ueval (read) nil nil k)))

#;(def uapply-builtin (f d args) ;inlined
  (apply f args))

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
    (ccc (fn (k d f)
           ;(let user-cont (fn (ignk ignd x)
           ;                 (
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
     
           
          
          
          
          
   