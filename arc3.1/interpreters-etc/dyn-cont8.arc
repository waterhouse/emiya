
;Arbitrarily putting "d e k" at front of arglist to the extent applicable.
;Also shall include user types.


;A more awesome default case.
(def ueval (d e k x)
  (if usym?x ;using artificial syms
      (lookup d e k x)
      cons?x
      (with k1 [ucall d e k _ cdr.x]
        (ueval d e k1 car.x))
      k.x))

;no quasiquote, is macro
;Should I segregrate memory allocations? ... This is good enough.
;Should I go for "dlet"?  [I didn't even take account of that in
; my de-macro procedure...] Or "call-with-parameterization"?
;... Meh... Eh... Yeah, screw dynamic variables; let's make this simpler.
(def ucall (d e k f xs)
  (vcase f
    qif (ueval-if d e k xs)
    qquote (let (x) xs k.x)
    qfn (let (ag . bd) xs
          (let u (make-uclos e ag bd)
            k.u))
    qassign
     (let (x v) xs
       (let k1 [uassign e k x _]
         (ueval d e k1 v)))
    (if umac?f
        (let (mc clos) f
          (let k1 [ueval d e k _]
            (uapply d k1 clos xs)))
        (let k1 [uapply d k f _]
          (map-ueval d e k1 xs)))))

(def map-ueval (d e k xs)
  (if no?xs
      k.xs
      (let k1 [let a _
                (let k2 [let u (cons a _) k.u]
                  (map-ueval d e k2 cdr.xs))]
        (ueval d e k1 car.xs))))

;oh man, remember that we "apply" in diff. order now (d k vs k d)
;"fn?" = builtin [poss. closure], "uclos?" = user closure (i.e. crappy)
;.........
;ok, let's have some jump tables.
;... yes, tags. righto.
;tags are currently syms, although there is still base vs user.
(def uapply (d k f args)
  (let u base-tag.f
    (let addr (uapply-base-table u [err "How do I call this?" __])
      (addr d k f args))))

(def apply-cons (d k f args)
  (let (n) args
    (ulist-ref-righto d k f n f n))) ;beheheh, error reporting

#;(def ulist-ref (d k xs n)
  (if cons?xs
      (if (is n 0)
          k:car.xs
          (ulist-ref d k cdr.xs dec.n))
      (err "ulist-ref: fuck")))

;ok let's be nice about error reporting
(def ulist-ref-righto (d k xs-head n-start xs n)
  (if cons?xs
      (if (is n 0)
          k:car.xs
          (ulist-ref-righto d k xs-head n-start cdr.xs dec.n))
      (err "ulist-ref: List too short or improper" xs-head n-start)))

;and then fuck it here
(def apply-string (d k f args)
  (let (n) args
    f.n))

;we ... strip off the Racket struct thing? ... neh.
(def apply-user (d k f args)
  (let u user-obj-tag.f
    (let addr (apply-user-table u [err "How do I call this user thing?" __])
      (addr d k f args))))

(def apply-fn (d k f args) ;aww yeah
  (f k d args))

(= uapply-base-table
   (obj cons apply-cons
        string apply-string
        user apply-user
        fn apply-fn))


(def apply-uclos (d k f args)
  (with ev uclos-env.f ag uclos-arglist.f bd uclos-body.f
    (let k1 [ubegin d _ k bd]
      (join-e d ev k1 ag args))))

(def make-uclos (env args body)
  (user-obj 'uclos (list env args body)))
(def uclos-env (x) user-obj-val.x.0)
(def uclos-arglist (x) user-obj-val.x.1)
(def uclos-body (x) user-obj-val.x.2)
(def uclos? (x) (and user?x (is user-obj-tag.x 'uclos)))


;in the design of dyns...
;I have included an integer n in them to allow for future
;sorting or whatever.
;... also keying by the integer. ah, yes.
;d = assoc-list of (dyn-id val)
;dyn = [user-tag 'dyn `(,dyn-id . ,val)]
(= dyn-count 0)
(def make-dyn (v)
  (user-obj 'dyn (list ++.dyn-count v)))
(def dyn-id (x) user-obj-val.x.0)
(def dyn-val (x) user-obj-val.x.1)
(def dyn? (x) (and user?x (is 'dyn user-obj-tag.x)))

;both kinds of lookups and assigns...
;shall take a cont argument.
;technically unnecessary, but they will only be
;used in places where that will happen.

;this api is slightly diff., but seems better:
;no global dyn table, dyns just have a field in them (like syms)
(def dyn-lookup (d k x)
  (let n dyn-id.x
    (aif (assoc n d)
         k:cadr.it
         k:dyn-val.x)))

(def dyn-assign (d k x val)
  (let n dyn-id.x
    (aif (assoc n d)
         (k:scar cdr.it val)
         (let xs user-obj-val.x
           (k:= xs.1 val)))))

(def dextend (d k x val)
  (let u (cons (list dyn-id.x val) d)
    k.u))

;now let's compare this with usual envs

;... shall I keep using the builtin syms?
;... it's coarse, rough, and irritating...
;... ok, let's say no.
;makes this part simpler.

;usym: [usym name value]
;name = string
;value = duh
;no name-hash atm

;... oh god, there's one problem with usyms.
;nil.
;...
;for the moment, just... I don't think I ever ... hmm.
;probably ok...

;one last reason I had been using a table instead of symbol-value fields:
;with the latter, remapping things can kind of only be done destructively.
;well, time enough to construct something more sophisticated once the
;basic thing is running.

($ (struct usym (name (value #:mutable)) #:transparent))
(= usym $.usym
   usym? ($:lambda (x) (if (usym? x) 't 'nil))
   usym-name $.usym-name
   usym-value $.usym-value
   set-usym-value $.set-usym-value!)
(def usym-set (x v)
  (set-usym-value x v)
  v)

;there must still be a list of all syms somewhere.

(= usym-table (table))

(= unbound-value 'UNBOUND)
(def make-usym (str (o val unbound-value))
  (let u (usym str val)
    (= usym-table.str u)))

(def uall-bound-syms ()
  (keep [isnt usym-value._ unbound-value]
        vals.usym-table))

(def lookup (d e k x) ;must handle errs
  (aif (assoc x e)
       k:cadr.it
       (let u usym-value.x
         (if (is u unbound-value)
             (err "Looking up an unbound variable" x e)
             k.u))))

(def uassign (d e k x v)
  (aif (assoc x e)
       (k:scar cdr.it v)
       (k:usym-set x v)))


;now.
;(dyn) => lookup 
;(dyn val) => assignment
  
(def apply-dyn (d k f args)
  (if no.args
      (dyn-lookup d k f)
      (let (val) args
        (dyn-assign d k f val))))
      
(= apply-user-table
   (obj uclos apply-uclos
        dyn apply-dyn))


($ (struct user-obj (tag val)
           #:transparent))
(= user-obj $.user-obj
   user-obj? ($:lambda (x) (if (user-obj? x) 't 'nil))
   user-obj-tag $.user-obj-tag
   user-obj-val $.user-obj-val)
(= user? user-obj?)

(def base-tag (x) ;syms atm
  (if int?x 'int
      fn?x 'fn ;i.e. builtin closure (usually empty env)
      string?x 'string
      char?x 'char
      table?x 'table ;prob. not impl.
      vector?x 'vector ;likewise
      usym?x 'sym
      no?x 'NULL ;... wtvr
      sym?x (err "Translate Arc syms into usyms" x)
      cons?x 'cons
      user-obj?x 'user
      (err "WTF type is this?" x)))

;to make the above work well (and not fall down on Racket structs due to "type")
(def arc-pred (sym)
  (eval `($ (lambda (x) (if (,sym x) 't 'nil)))))
(each x '((int? integer?)
          (fn? procedure?)
          string?
          char?
          (table? hash?)
          vector?
          ;usym? defined here
          (sym? symbol?)
          (cons? pair?)
          ;user-obj? defined here
          )
  (with arc-name (if sym?x x car.x)
    scheme-name (if sym?x x cadr.x)
    (= symbol-value.arc-name arc-pred.scheme-name)))


#;(= base-type-tag (table) ;unnec., syms atm
   base-type-tag!int 0)

;(on x (randperm '(


;ok, types out of the way, jesus [prob. not entirely]

(def ubegin (d e k xs)
  (if no?cdr.xs
      (ueval d e k car.xs) ;tail call elim
      (let k1 [ubegin d e k cdr.xs] ;ignore result
        (ueval d e k1 car.xs))))

(def ueval-if (d e k xs)
  (if no?xs
      k.nil
      no?cdr.xs
      (ueval d e k car.xs)
      (let (a b . rest) xs
        (let k1 [if _
                    (ueval d e k b)
                    (ueval-if d e k rest)]
          (ueval d e k1 a)))))
        


;aw, man, methinks d and k should be together, e not between them...
;'cause some ... well... whatever, meh.

#;(def join-e (d e k argl-orig args-orig argl args) ;naw
  (let fail (fn () (err "Failed to bind arglist" argl-orig args-orig))
    (if no?argl
        (if no?args
            k.e
            (fail))
        usym?argl
        (let u (cons (list argl args) e)
          k.u)
        cons?argl
        (if cons?args
            (let k1 [join-e d _ k argl-orig args-orig cdr.argl cdr.args]
              (join-e d e k argl-orig args-orig car.argl car.args))
            (fail))
        (fail))))

;hide the terrible
(def join-e (d e k argl args)
  (join-e2 d e k argl args argl args))

(def join-e2 (d e k argl-orig args-orig argl args)
  (let fail (fn () (err "Failed to bind arglist" argl-orig args-orig))
    (if no?argl
        (if no?args
            k.e
            (fail))
        usym?argl
        (let u (cons (list argl args) e)
          k.u)
        cons?argl
        (if cons?args
            (let k1 [join-e2 d _ k argl-orig args-orig cdr.argl cdr.args]
              (join-e2 d e k1 argl-orig args-orig car.argl car.args))
            (fail))
        (fail))))





(= user user-obj)

(def usymb args
  (let s (tostring:map pr args)
    (or usym-table.s
        (= usym-table.s make-usym.s)))) ;unbound
(= sym->usym usymb)


(def install-uassignment (x v)
  (let u sym->usym.x
    (usym-set u v)))

;now... I am slightly queasy about having the if-objects and stuff be
;GC-managed objects.
;but, actually, things have to return nil and sometimes t.
;so, screw.
(each x '(if quote fn assign)
  (let v (user 'special-object x)
    (= (symbol-value:symb 'q x) v)
    (install-uassignment x v)))

(def make-umac (uclos)
  (user 'macro uclos))
(def umac? (x) (and user?x (is user-obj-tag.x 'macro)))


;some essential procedures...
;let's see...
;actually these things can have a calling convention completely orthogonal
;to the core functions I've defined above.
;well.

;calling convention will be "k d arglist". lel.
;continuations are still one-param Arc procedures.

(unless bound!safe-to-udef
  (= safe-to-udef (table)))
(mac udef (name args . body)
  (let arcname (symb 'x name)
    `(if (and (bound ',arcname) (no:safe-to-udef ',arcname))
         (err "Oh crap this is bound" ',arcname)
         (do (def ,arcname ,args ,@body)
             (= (safe-to-udef ',arcname) t)
             (install-uassignment ',name ,arcname)))))

(udef call-w/param (k d (dyn var thunk)) ;oh my god I think I love this
  (let k2 [apply-uclos _ k thunk nil]
    (dextend d k2 dyn var)))

#;(udef call-w/cc (k d (f)) ;... never this simple
  (let xs list.k
    (uapply d k f xs)))

(def cont->closure (k) ;feh
  (fn (ignk ignd (x)) k.x))

(udef call-w/cc (k d (f))
  (let u cont->closure.k
    (uapply d k f list.u)))

(udef eval (k d (x (o e nil)))
  (ueval d k e x))

(udef apply (k d (f . args))
  (uapply d k f args))

;screw exceptions I'll handle them later
;;exceptions...
;(= huh-repl-cont
;   [do (install-uassignment 'that _)
;       wrn._
;       (huh)])
;
;(def huh ()
;  (pr "huh> ")
;  (let u (read)
;    (install-uassignment 'thatexpr u)
;    (ueval nil nil huh-repl-cont u)))
;
;(udef default-exn-handler (k d args)
;  (prsn "Exception!" args)
;  (huh))
;
;(= dexn-handler (make-dyn default-exn-handler))
;(install-uassignment 'exn-handler dexn-handler)
;
;;create a cont, containing the current d.
;;...
;;you know what
;(udef call-with-exn-handler (k d (h thunk))
;  (let curr-xh (dyn-lookup d dexn-handler)
;    (let x-closure (fn (k2 d2 args)
;                     (let new-d2 
;
;(udef raise-continuable (k d (x))
;  #;(let u (dyn-val d dexn-handler)
;    (uapply d k u list.x))
;  
;
;(udef raise (ignk d (x))
;  (let u (dyn-val d dexn-handler)
;    
;  
;;call-with-exn-handler can be defined by the user
;;NOPE NEVER MIND

;the more mundane sorts of things
(udef list (k d args)
  (let u copylist.args
    k.u))

;let's be explicit
(udef cons (k d (x y))
  (k:cons x y))

;oh dear lord... do I have to...
#;(udef list* (k d (x . rest))
  (if no.rest
      k.x
      (let k1 [xcons k d (list x _)]
        (xlist* k1 d rest))))
;let's do something a tad better

(def cons-good (d k x y) ;maintaining the old signature
  (k:cons x y))

(udef list* (k d (x . rest))
  (if no.rest
      k.x
      (let k1 [cons-good d k x _]
        (xlist* k1 d rest))))


;exercises
;[these really could be defined by the user]
(udef append (k d xses)
  (if no.xses
      k.nil
      (let (xs . rest) xses
        (let k1 [append2-good d k xs _]
          (xappend k1 d rest)))))

;recursive, not great; eh
(def append2-good (d k a b)
  (if no.a
      k.b
      (let (x . rest) a
        (let k1 [cons-good d k x _]
          (append2-good d k1 rest b)))))

(udef idfn (k d (x)) k.x)



;ok, some primitives
(mac uassert (expr)
  `(unless ,expr
     (err "Assertion failed:" ',expr)))

(udef chars->string (k d (xs))
  (uassert:all char? xs)
  k:string.xs)

(udef make-string (k d (n)) ;screw the default char
  (k:newstring n #\nul))

(udef string->sym (k d (s))
  (uassert string?s)
  k:usymb.s)

(udef symbol-name (k d (x)) ;user defines sym->string
  (uassert usym?x)
  k:usym-name.x)

(udef symbol-value (k d (x)) ;will return UNBOUND-VALUE when appr.
  k:usym-value.x)

(udef symbol-set (k d (x v))
  (k:usym-set-value x v))

(udef int->char (k d (n)) k:char.n)
(udef char->int (k d (c)) k:int.c)
(udef string-set (k d (s n v))
  (uassert string?s)
  (k:= s.n v))

           





(def proc->ufn (f)
  (fn (k d args)
    (k (apply f args))))

(each x '(+ - * /
          car cdr
          is < >
          )
  (install-uassignment x proc->ufn:symbol-value.x))


(def uify (x)
  (deep-map [if sym?_ sym->usym._ _] x))

(def ue (x)
  (ueval nil nil idfn
         uify.x))






