;Datatypes probably go at the top.


(let meh `(int ,@(randperm '(fn sym cons char
                             string user vector)))
  (= type-num (table)
     type-name (table)) ;here we go, good name
  (on x meh (= type-num.x index type-name.index x)))

(def make-uclos (env args body)
  (user-obj user-type-num!uclos (list* env args body)))
(def uclos-env (x) user-obj-val.x.0)
(def uclos-arglist (x) user-obj-val.x.1)
(def uclos-body (x) cddr:user-obj-val.x)
(def uclos? (x) (and user?x (is user-obj-tag.x user-type-num!uclos)))

(def make-umac (uclos)
  (user-obj user-type-num!umac uclos))
(def umac-clos (x) user-obj-val.x)
(def umac? (x) (and user?x (is user-obj-tag.x user-type-num!umac)))


;d = assoc-list of (dyn-id val)
;dyn = [user-tag 'dyn `(,dyn-id . ,val)]
(= dyn-count 0)
(def make-dyn (v)
  (user-obj user-type-num!dyn (list ++.dyn-count v)))
(def dyn-id (x) user-obj-val.x.0)
(def dyn-val (x) user-obj-val.x.1)
(def dyn? (x) (and user?x (is user-type-num!dyn user-obj-tag.x)))


;usym: [usym name value]
;name = string
;value = duh
;no name-hash atm

;... oh god, there's one problem with usyms.
;nil.
;--meh.

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

(def usymb args
  (let s (tostring:map pr args)
    (or usym-table.s
        (= usym-table.s make-usym.s)))) ;unbound
(= sym->usym usymb)


(= user-type-count 0
   user-type-num (table)
   user-type-name (table) ;meh
   )
(def enumerate-user-type (sm)
  (let u user-type-count
    ++.user-type-count
    (= user-type-num.sm u
       user-type-name.u sm)
    u))
;curious how the numbers are assigned much later than the
;procedures are defined; this prob. wouldn't be so in assembly
;[unless I used macros to do that]
(map enumerate-user-type '(uclos dyn umac))

($ (struct user-obj (tag val)
           #:transparent))
(= user-obj $.user-obj
   user-obj? ($:lambda (x) (if (user-obj? x) 't 'nil))
   user-obj-tag $.user-obj-tag
   user-obj-val $.user-obj-val)
(= user? user-obj?)
(= user user-obj)


;type: bclos.
;base closure.
;has a code-pointer, and an env vector.
;also has information about it elsewhere.
;let's see...
;in the ideal thing...
;there could be a vector with all closure codeptrs sorted,
;and a parallel vector of information.
;but that is kind of sucky.
;it could be maintained, even with code ptrs that GC would
;move around; but let us declare it "too advanced atm".
;so then the next approach is to have the extra information
;either before or pointed to by something before the code.
;that is the approach I had settled on.
;welp...
;let us break this into two steps.
;bclosures is big enough.

;WARNING: INCONSISTENCY [oh well, not like I used other stuff much]
($ (struct bclos (code env) #:transparent))
(= make-bclos $.bclos ;clunky name for clunky operator
   bclos? ($:lambda (x) (if (bclos? x) 't 'nil))
   bclos-code $.bclos-code
   bclos-env $.bclos-env)

(def bclos (code . args) ;convenient name for convenient operator
  (make-bclos code (apply $.vector args)))

;[strategy 0 w.r.t allocing and saving:
; save all vars on stack, grab memory, retrieve from stack.
; should probably start with that.]

;(def eref (bc n) (vref bclos-env.bc n))
;(def e (self)
;  [eref self _]) ;oh man, syntax

;Nah, fuck it.
;Use some goddamned unhygienic macros.
;Yeah, that's what to do.
;[Actually this is also a case where I might have wanted
; a kind of macrolet.]
;And we are intending to imitate assembly,
;So this shit does have to be broken up into sep. functions.

(mac e (n)
  `(vref bclos-env.self ,n))

;AW CRAP I ALSO HAVE TO CHANGE CONT-CALLS
;feh.

(def bcall (b . args)
  (apply bclos-code.b b args))

;Arbitrarily putting "d e k" at front of arglist to the extent applicable.
;Also shall include user types.
;... Usually "d k", because no e.  Oh boy.  Oh well.

;I do do error handling, but...
;There is a difference between "user error" and "implementation error".
;It is sort of appropriate... well... whatever.
(mac uassert (expr)
  `(unless ,expr
     (err "Assertion failed:" ',expr)))


;A more awesome default case.
#;(def ueval (d e k x)
  (if usym?x ;using artificial syms
      (lookup d e k x)
      cons?x
      (with k1 [ucall d e k _ cdr.x]
        (ueval d e k1 car.x))
      k.x))

(def ueval (d e k x)
  (if usym?x ;using artificial syms
      (lookup d e k x)
      cons?x
      (with k1 (bclos ueval-k1 d e k cdr.x)
        (ueval d e k1 car.x))
      (bcall k x)))
;note there is technically a change in semantics
;if btwn ueval and ucall, someone modifies cdr.x,
;then we will now see the results of that
(def ueval-k1 (self _)
  (ucall e.0 e.1 e.2 _ e.3))

;no quasiquote, is macro
;Should I segregrate memory allocations? ... This is good enough.
;Should I go for "dlet"?  [I didn't even take account of that in
; my de-macro procedure...] Or "call-with-parameterization"?
;... Meh... Eh... Yeah, screw dynamic variables; let's make this simpler.
#;(def ucall (d e k f xs)
  (vcase f
    qif (ueval-if d e k xs)
    qquote (let (x) xs k.x)
    qfn (let (ag . bd) xs
          (let u (make-uclos e ag bd)
            k.u))
    qassign
     (let (x v) xs
       (let k1 [uassign d e k x _]
         (ueval d e k1 v)))
    (if umac?f
        (let clos umac-clos.f
          (let k1 [ueval d e k _]
            (uapply d k1 clos xs)))
        (let k1 [uapply d k f _]
          (map-ueval d e k1 xs)))))
;get ready
(def ucall (d e k f xs)
  (vcase f
    qif (ueval-if d e k xs)
    qquote (let (x) xs
             (bcall k x))
    qfn (let (ag . bd) xs
          (let u (make-uclos e ag bd)
            (bcall k u)))
    qassign
     (let (x v) xs
       (let k1 (bclos ucall-k1 d e k x)
         (ueval d e k1 v)))
    (if umac?f
        (let clos umac-clos.f
          (let k1 (bclos ucall-k2 d e k)
            (uapply d k1 clos xs)))
        (let k1 (bclos ucall-k3 d k f)
          (map-ueval d e k1 xs)))))

(def ucall-k1 (self _)
  (uassign e.0 e.1 e.2 e.3 _))
;Often they do look like that. But ... ... I *think* not always.
;[Meh.]
;Geez, some of these may actually be identical.
(def ucall-k2 (self _)
  (ueval e.0 e.1 e.2 _))
(def ucall-k3 (self _)
  (uapply e.0 e.1 e.2 _))

#;(def map-ueval (d e k xs)
  (if no?xs
      k.xs
      (let k1 [let a _
                (let k2 [let u (cons a _) k.u]
                  (map-ueval d e k2 cdr.xs))]
        (ueval d e k1 car.xs))))
;finally, a complex thing
(def map-ueval (d e k xs)
  (if no?xs
      (bcall k xs)
      (let k1 (bclos map-ueval-k1 d e k cdr.xs)
        (ueval d e k1 car.xs))))

(def map-ueval-k1 (self _)
  (let k2 (bclos map-ueval-k2 _ e.2)
    (map-ueval e.0 e.1 k2 e.3)))
;... we have some options.
;we can make the closure "flat", by putting e.2 in the
;map-ueval-k2 closure, which is the obvious thing;
;or we can put a ptr to k1's self in the k2 closure.
;the latter is vaguely worse in a few ways, although it
;would be necessary if these variables could ever be modified.
(def map-ueval-k2 (self _)
  (let u (cons e.0 _)
    (bcall e.1 u)))

;oh man, remember that we "apply" in diff. order now (d k vs k d)
;"fn?" = builtin [poss. closure], "uclos?" = user closure (i.e. crappy)
;.........
;ok, let's have some jump tables.
;... yes, tags. righto.
;tags are currently syms, although there is still base vs user.
(def uapply (d k f args)
  (let u base-tag.f
    (let addr (vref uapply-base-table u)
      (addr d k f args))))

(def apply-cons (d k f args)
  (let (n) args
    (uassert num?n)
    (xloop (x f c n)
      (if cons?x
          (if (is c 0)
              (bcall k car.x)
              (next cdr.x dec.c))
          (uraise d k (list 'list-ref-error f n))))))

(def apply-string (d k f args)
  (let (n) args
    (uassert num?n)
    (if (and string?f (< n len.f))
        (bcall k f.n) ;there we go, fuckup
        (uraise d k (list 'string-ref-error f n)))))

;we ... strip off the Racket struct thing? ... neh.
(def apply-user (d k f args)
  (let u user-obj-tag.f
    (let addr (vref apply-user-table u)
      (addr d k f args))))

;now both bclos's and procedures will be called 'fn
;[later, the latter may be wrapped in bclos's]
(def apply-fn (d k f args)
  (if bclos?f
      (bclos-code.f f k d args) ;an inlined bcall
      (f k d args)))

(= uapply-base-table
   (make-vector 8 (fn (k d args)
                    (uraise d k (list 'apply-unknown-error args)))))
(map (fn ((x y)) (vset uapply-base-table type-num.x symbol-value.y))
     `((cons apply-cons)
       (string apply-string)
       (user apply-user)
       (fn apply-fn)))


#;(def apply-uclos (d k f args)
  (with ev uclos-env.f ag uclos-arglist.f bd uclos-body.f
    (let k1 [ubegin d _ k bd]
      (join-e d ev k1 ag args))))

(def apply-uclos (d k f args)
  (with ev uclos-env.f ag uclos-arglist.f bd uclos-body.f
    (let k1 (bclos apply-uclos-k1 d k bd)
      (join-e d ev k1 ag args))))

(def apply-uclos-k1 (self _)
  (ubegin e.0 _ e.1 e.2))


;both kinds of lookups and assigns...
;shall take a cont argument.
;technically unnecessary, but they will only be
;used in places where that will happen.

;this api is slightly diff., but seems better:
;no global dyn table, dyns just have a field in them (like syms)
(def dyn-lookup (d k x)
  (let n dyn-id.x
    (aif (assoc n d)
         (bcall k cadr.it)
         (bcall k dyn-val.x))))

(def dyn-assign (d k x val)
  (let n dyn-id.x
    (aif (assoc n d)
         (bcall k (scar cdr.it val))
         (let xs user-obj-val.x
           (bcall k (= xs.1 val))))))

(def dextend (d k x val)
  (let u (cons (list dyn-id.x val) d)
    (bcall k u)))

(def install-uassignment (x v)
  (let u sym->usym.x
    (usym-set u v)))
(= uinstall install-uassignment)

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
       (bcall k cadr.it)
       (let u usym-value.x
         (if (is u unbound-value)
             (uraise d k (list 'unbound-variable-error x e))
             (bcall k u)))))

(def uassign (d e k x v)
  (aif (assoc x e)
       (bcall k (scar cdr.it v))
       (bcall k (usym-set x v))))


;now.
;(dyn) => lookup 
;(dyn val) => assignment
  
(def apply-dyn (d k f args)
  (if no.args
      (dyn-lookup d k f)
      (let (val) args
        (dyn-assign d k f val))))

;how big should this dispatch table be?
;I arbitrarily thought 256.
;Esp. because that could be convenient for
;masking of some sort by an 8-bit.
(= apply-user-table ($.make-vector 256
                                 (fn (k d args)
                                   (uraise d k (list 'apply-user-unknown-error
                                                     args)))))

(vset apply-user-table user-type-num!uclos apply-uclos)
(vset apply-user-table user-type-num!dyn apply-dyn)
;no applying umacs



(def base-tag (x) ;syms atm
  (type-num
   (if int?x 'int
       fn?x 'fn ;i.e. builtin closure (usually empty env)
       bclos?x 'fn ;*really* builtin closure
       string?x 'string
       char?x 'char
       ;table?x 'table ;prob. not impl. ;also it belong in user tags
       vector?x 'vector ;likewise
       usym?x 'sym
       no?x 'sym ;... wtvr
       sym?x (err "Translate Arc syms into usyms" x)
       cons?x 'cons
       user-obj?x 'user
       
       ;would not appear in assembly
       ;num?x 'scheme-number ;lolz, I committed to fairly restrictive tck on arith.
       
       (err "WTF type is this?" x))))

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
          (num? number?)
          ;user-obj? defined here
          )
  (with arc-name (if sym?x x car.x)
    scheme-name (if sym?x x cadr.x)
    (= symbol-value.arc-name arc-pred.scheme-name)))

(def utype (x)
  (let u base-tag.x
    (if (is u user-type-num!user)
        (let v user-obj-tag.x
          (aif user-type-name.v
               it
               (err "Unknown user type" v x)))
        type-name.u)))


;ok, types out of the way, jesus [prob. not entirely]

#;(def ubegin (d e k xs)
  (if no?cdr.xs
      (ueval d e k car.xs) ;tail call elim
      (let k1 [ubegin d e k cdr.xs] ;ignore result
        (ueval d e k1 car.xs))))
(def ubegin (d e k xs)
  (if no?cdr.xs
      (ueval d e k car.xs) ;tail call elim
      (let k1 (bclos ubegin-k1 d e k cdr.xs)
        (ueval d e k1 car.xs))))
(def ubegin-k1 (self _) ;ignore result
  (ubegin e.0 e.1 e.2 e.3))

#;(def ueval-if (d e k xs)
  (if no?xs
      k.nil
      no?cdr.xs
      (ueval d e k car.xs)
      (let (a b . rest) xs
        (let k1 [if _
                    (ueval d e k b)
                    (ueval-if d e k rest)]
          (ueval d e k1 a)))))

(def ueval-if (d e k xs)
  (if no?xs
      (bcall k nil)
      no?cdr.xs
      (ueval d e k car.xs)
      (let (a . more) xs ;changing it a little
        (let k1 (bclos ueval-if-k1 d e k more)
          (ueval d e k1 a)))))
#;(def ueval-if-k1 (self _) ;dumbass
  (if _
      (ueval d e k car.more)
      (ueval-if d e k cdr.more)))
(def ueval-if-k1 (self _)
  (if _
      (ueval e.0 e.1 e.2 car:e.3)
      (ueval-if e.0 e.1 e.2 cdr:e.3)))

;aw, man, methinks d and k should be together, e not between them...
;'cause some ... well... whatever, meh.

;hide the terrible
(def join-e (d e k pars args)
  (join-e2 d e k pars args pars args))

#;(def join-e2 (d e k p0 a0 pars args)
  (let fail (fn () (uraise d k (list 'arglist-binding-error p0 a0)))
    (if no?pars
        (if no?args
            k.e
            (fail))
        usym?pars
        (let u (cons (list pars args) e)
          k.u)
        cons?pars
        (if cons?args
            (let k1 [join-e2 d _ k p0 a0 cdr.pars cdr.args]
              (join-e2 d e k1 p0 a0 car.pars car.args))
            (fail))
        (fail))))

(def join-e2 (d e k p0 a0 pars args)
  (let fail (fn () (uraise d k (list 'arglist-binding-error p0 a0)))
    (if no?pars
        (if no?args
            (bcall k e)
            (fail))
        usym?pars
        (let u (cons (list pars args) e)
          (bcall k u))
        cons?pars
        (if cons?args
            (let k1 (bclos join-e2-k1 d k p0 a0 cdr.pars cdr.args)
              (join-e2 d e k1 p0 a0 car.pars car.args))
            (fail))
        (fail))))
;oh man
(def join-e2-k1 (self _)
  (join-e2 e.0 _ e.1 e.2 e.3 e.4 e.5))


;now... I am slightly queasy about having the if-objects and stuff be
;GC-managed objects.
;but, actually, things have to return nil and sometimes t.
;so, screw.
(each x '(if quote fn assign)
  (let v (user 'special-object x)
    (= (symbol-value:symb 'q x) v)
    (uinstall x v)))

(uinstall 't (sym->usym 't))
(uinstall 'nil nil) ;is probably the right thing


;some essential procedures...
;let's see...
;actually these things can have a calling convention completely orthogonal
;to the core functions I've defined above.
;well.

;calling convention will be "k d arglist". lel.
;continuations are still one-param Arc procedures.



#;(def ucall-w/param (d k dyn var thunk)
  (let k2 [uapply _ k thunk nil] ;might want thunk to be an fn
    (dextend d k2 dyn var)))

(def ucall-w/param (d k dyn var thunk)
  (let k1 ;(bclos k thunk) ;might want thunk to be an fn ;DUMB ASS IDIOT
    (bclos ucall-w/param-k1 k thunk)
    (dextend d k1 dyn var)))
(def ucall-w/param-k1 (self _)
  (uapply _ e.0 e.1 nil))

(uinstall 'call-w/param (fn (k d (dyn var thunk))
                          (ucall-w/param d k dyn var thunk)))

;now this is some stuff I decided I wanted
(uinstall 'current-dyn-env (fn (k d ignargs)
                             (bcall k d)))

(uinstall 'call/kd (fn (k d (k2 d2 thunk))
                     (uapply d2 k2 thunk nil)))
;(uinstall 'safe-call/kd (fn (k d (k2 d2 thunk))
;                          (let k3 [do (prn "You're an idiot, putting a non-cont"
;                                           "where a cont goes")
;                                    (utoplevel)]
;                            (let k4 [uapply 
;                            (uapply d2 k3 
;Neh, that only really applies in the assembly world.

(= uinsult-toplevel (bclos
                     (fn (self _) ;forgivable here because this is just one func.
                       (prn "You're an idiot, putting a non-cont"
                            "where a cont goes")
                       prn._
                       (utoplevel))))

(def closure->cont (f) ;also just turns conts into eqv. conts
  (bclos closure->cont-k1 f))
(def closure->cont-k1 (self _)
  (uapply nil uinsult-toplevel e.0 list._))

(uinstall 'safe-call/kd (fn (k d (k2 d2 thunk))
                          (uapply d2 closure->cont.k2 thunk nil)))

;this is actually relatively substantial now
(def cont->closure (k) ;feh
  (fn (ignk ignd (x)) (bcall k x)))

(uinstall 'ccc (fn (k d (f))
                 (let u cont->closure.k
                   (uapply d k f list.u))))
(uinstall 'raw-ccc (fn (k d (f)) (uapply d k f list.k)))

(uinstall 'eval (fn (k d (x (o e nil)))
                  (ueval d e k x)))
(uinstall 'apply (fn (k d (f . args))
                   (uapply d k f (apply list* args))))

;ok, so, a brilliant genius has informed me:

;(def raise (x)
;  ((current-exn-handler) x))

;...
;yeah, that thing from CwC seems to be a dumb consequence of the
;dumb fact that they use sethdlr/gethdlr, rather than parameterize.
;now... 

;now...
;this means stuff can probably be defined by the user.
;except for the fact that the primitives ...........
;ok, actually, conceivably, I could provide completely
;unsafe versions of arithmetic functions and stuff,
;and the error handling could be completely user-stuff.
;...

;that seems a ... bit difficult.
;more to the point, difficult to make performant.
;...
;I guess I could provide, primitively, a function that took
;a closure and some args and created a closure that would
;take args, check if they were good, raise an exception if not,
;and otherwise call the original closure.
;that would be el goodo.

;(udef arg-typecheck (k d (f tp err-fn))
;  (k (fn args
;       (if (all [is type._ tp] args)
;           (apply f args)
;           (err-fn ...)))))
;...
;gah, should create a base-closure or wtvr [... wtvr]
;hmm...
;right.
;it'd be fine.
;like:
;(= tck-app (fn (self k d arglist)
;             (let tp self!tp
;               (if (all [is type._ tp] arglist)
;                   (uapply self!f args)
;                   (self!efn ...)))))
;(= arg-tck (fn (k d (f tp efn))
;             (let u `(CLOSURE ,tck-app
;                              ((f ,f) (tp ,tp) (efn ,efn)))
;               u)))

;....
;for uniformity...
;that shall call "uapply", which shall not know whether
;it is being given a builtin-closure, or a user-closure.
;this shall be an example of stupidity.

;this could be a bclos...
;...
;as an exercise, I shall make *this* one create a bclos.
;[it's not a cont...]
#;(def uarg-tck (tp f)
  (fn (k d args)
    (if no:proper-list.args
        (uraise d k (list 'args-error args f))
        (all [is utype._ tp] args)
        (uapply d k f args)
        (uraise d k (list 'type-error tp args f)))))
(def uarg-tck (tp f)
  (bclos uarg-tck-c1 tp f))

(def uarg-tck-c1 (self k d args)
  (if no:proper-list.args
      (uraise d k (list 'args-error args e.1))
      (all [is utype._ e.0] args)
      (uapply d k e.1 args)
      (uraise d k (list 'type-error e.0 args e.1))))
(uinstall 'arg-type-check (fn (k d args)
                      (bcall k (apply uarg-tck args))))
(def uarg-nck (n f)
  (fn (k d args)
    (if (and proper-list.args (is n len.args))
        (uapply d k f args)
        (uraise d k (list 'args-error n args f)))))
(uinstall 'arg-num-check (fn (k d args)
                     (bcall k (apply uarg-nck args))))
#;(def uraise (d k obj)
  (let k2 [uapply d k _ list.obj]
    (dyn-lookup d k2 uhandler)))
;here I have a choice: create list.obj here and put it in the cont,
;or have the cont create list.obj.
;I shall do the former.
(def uraise (d k obj)
  (let k1 (bclos uraise-k1 d k list.obj)
    (dyn-lookup d k1 uhandler)))
(def uraise-k1 (self _)
  (uapply e.0 e.1 _ e.2))

(def default-uhandler (d k (obj))
  (prsn "An exception!" obj)
  (utoplevel))

#;(def utoplevel ()
  (pr "heh> ")
  (awhen (read)
    (let k [do (uinstall 'that _)
             wrn:prettify._
             (utoplevel)]
      (ueval nil nil k uify.it))))
;now...
#;(def utoplevel ()
  (pr "heh> ")
  (awhen (read)
    (let k (bclos utoplevel-k1)
      (ueval nil nil k uify.it))))
;or, actually, since that cont is always the same (empty env),
;I don't need to create a new one each time.
(def utoplevel ()
  (pr "heh> ")
  (awhen (read)
    (ueval nil nil utoplevel-kk uify.it)))

(def utoplevel-k1 (self _)
  (uinstall 'that _)
  wrn:prettify._
  (utoplevel))

(= utoplevel-kk (bclos utoplevel-k1))

#;(= utoplevel-cont [utoplevel])
(= utoplevel-cont (bclos (fn (self _) (utoplevel))))
(= uhandler (make-dyn default-uhandler))
(uinstall 'default-exn-handler uhandler)



(unless bound!safe-to-udef
  (= safe-to-udef (table)))
(w/uniq (gk gd gargs)
  (mac udef (name (d-arg k-arg . rest) . body)
    (let arcname (symb 'x name)
      `(if (and (bound ',arcname) (no:safe-to-udef ',arcname))
           (err "Oh crap this is bound" ',arcname)
           (do (def ,arcname (,d-arg ,k-arg ,@rest) ,@body)
             (= (safe-to-udef ',arcname) t)
             (install-uassignment ',name (fn (,gk ,gd ,gargs)
                                           (,arcname ,gd ,gk ,gargs))))))))

;ehm...
;ah, yes.
;"x" functions still use d-k convention.

;the more mundane sorts of things
(udef list (d k args)
  (let u copylist.args
    (bcall k u)))

;let's be explicit
(udef cons (d k (x y))
  (bcall k (cons x y)))

(def ucons (d k x y) ;maintaining the old signature
  (bcall k (cons x y)))

(udef list* (d k (x . rest))
  (if no.rest
      (bcall k x)
      (let k1 (bclos list*-k1 d k x)
        (xlist* d k1 rest))))

(def list*-k1 (self _)
  (ucons e.0 e.1 e.2 _))

;exercises
;[these really could be defined by the user]
(udef append (d k xses)
  (if no.xses
      (bcall k nil)
      (let (xs . rest) xses
        (let k1 (bclos append-k1 d k xs)
          (xappend d k1 rest)))))

(def append-k1 (self _)
  (append2-good e.0 e.1 e.2 _))

;recursive, not great; eh
(def append2-good (d k a b)
  (if no.a
      (bcall k b)
      (let (x . rest) a
        (let k1 (bclos append2-good-k1 d k x)
          (append2-good d k1 rest b)))))
(def append2-good-k1 (self _)
  (cons-good e.0 e.1 e.2 _))

(udef idfn (d k (x)) (bcall k x))



;ok, some primitives
;(being lazy for now about real error handling)

(udef chars->string (d k (xs))
  (uassert:all char? xs)
  (bcall k string.xs))

(udef make-string (d k (n)) ;screw the default char
  (bcall k (newstring n #\nul)))

(udef string->sym (d k (s))
  (uassert string?s)
  (bcall k usymb.s))

(udef symbol-name (d k (x)) ;user defines sym->string
  (uassert usym?x)
  (bcall k usym-name.x))

(udef symbol-value (d k (x)) ;will return UNBOUND-VALUE when appr.
  (bcall k usym-value.x))

(udef symbol-set (d k (x v))
  (bcall k (usym-set x v)))
(udef bound (d k (x))
  (bcall k (isnt unbound-value usym-value.x)))

(udef int->char (d k (n)) (bcall k char.n))
(udef char->int (d k (c)) (bcall k int.c))
(udef string-set (d k (s n v))
  (uassert string?s)
  (bcall k (= s.n v)))


(def proc->ufn (f)
  (fn (k d args)
    (bcall k (apply f args))))


(each x '((make-mac make-umac)
          (mac-clos umac-clos) (unsafe-macro-fn umac-clos)
          cons? (acons cons?)
          no (no? no)
          (closure? uclos?)
          (macro? umac?)
          (make-closure make-uclos)
          (closure-env uclos-env)
          (closure-args uclos-arglist)
          (closure-body uclos-body)
          atom atom?
          (fn? (orf uclos? fn?)) ;used in 'testify, obv. means both
          (sym? usym?)
          string?
          (all-bound-symbols uall-bound-syms)
          (sym->string usym-name)
          
          )
  (with arc-name (if cons?x cadr.x x)
    uname (if cons?x car.x x)
    (uinstall uname proc->ufn:eval.arc-name)))


;lolz, just integer arithmetic...
;'cause of how I wrote dick.
;oh well.
(each x '(+ - * / < >
          div mod)
  (uinstall x (uarg-tck 'int proc->ufn:symbol-value.x)))

#;(each x '(car cdr cadr cddr)
  (uinstall x (uarg-nck 1 (uarg-tck 'cons proc->ufn:symbol-value.x))))
;that's actually not too great
;...
;lel, just drop type check
(each x '(car cdr cadr cddr)
  (uinstall x (uarg-nck 1 proc->ufn:symbol-value.x)))

(each x '(< >)
  (uinstall (symb x 2)
            (uarg-nck 2 (uarg-tck 'int proc->ufn:symbol-value.x))))

(uinstall 'string-length (uarg-tck 'string proc->ufn.len))

(each x '(is)
  (install-uassignment x proc->ufn:symbol-value.x))







;just for convenience
(each x '(prn prsn pr)
  (install-uassignment x proc->ufn:symbol-value.x))

(def uify (x)
  (deep-map [if sym?_ sym->usym._ _] x))

(def usym->sym (x) symb:usym-name.x)
(def de-uify (x)
  (deep-map [if usym?_ usym->sym._ _] x))
(uinstall 'arc-eval (fn (k d (x)) (bcall k eval:de-uify.x)))

(= idfn-k (bclos (fn (self _) _)))

(def ue (x)
  (ueval nil nil ;idfn ;inappropriate use of a cont
         idfn-k
         uify.x))

(def heh () (utoplevel))

(def boot ((o file (string src-directory "arc-boot.arc")))
  (let n 0
    (let fuck-me nil
      (fromfile file
        (whilet u (read)
          (= last-u u)
;          prn.n
          (when fuck-me (err "Goddammit"))
          (on-err (fn (ex) (prsn "Screwed up at" n "with" ex)
                    (= fuck-me t)
                    (err "Screw"))
                  (fn ()
                    (let h uify.u
                      (let hd (fn (k d (x))
                                (do (prn "Failed to eval expr " n ":")
                                  pprn.u
                                  (= ass x)
                                  (prsn "raising exception" prettify.x)
                                  (err "Fuck")))
                        (let res (ucall-w/param nil idfn-k uhandler hd
                                                (fn (k d ign)
                                                  (ueval d nil k h)))
                          (when (and acons.u (is car.u 'def)
                                     no:uclos?res)
                            (prsn "This probably ain't a function" (= ass res))
                            prn.n
                            (err "Dicks")))))))
          ++.n)))))

(def prettify (x)
  (deep-map [if usym?_ usym->sym._
                user?_ `(,upcase:user-type-name:user-obj-tag._
                         ,@(prettify user-obj-val._))
                _]
            x))

(def ucp ()
  (ue:read:pbpaste))
            
;Ok...
;Next...
;I want to get to the point where closures get their code-pointers
;overwritten for GC purposes, and also to the point of having assembly
;and GC.
;Actually those three could mostly be done in any order, I think.
;The assembly part should probably be last or something.
;Well...
;At any rate, the code-pointer thing is probably next.





