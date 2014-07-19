;All right.
;Splitting this off into its own file.

;What do we assume?

;Special forms:
;assign
;if
;fn (plain and rest arglists)
;quote
;
;Procedures:
;make-mac
;make-clos
;
;sym-value
;set-sym-value
;
;cons
;list
;list*
;
;
;is
;
;+ - * /
;
;Not yet assumed:
;scar
;scdr


(assign mac (make-mac (fn (name args . body)
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
;to make debugging a tad easier...
;we can have a version of rfn that does not create circular structures.
;[lol]
#;(mac rfn (name args . body)
  (list 'let name nil
        (list 'assign name
              (list* 'fn args body))))
(def Y (f) (fn args (apply (f (Y f)) args)))
(mac rfn (name args . body)
  (list 'Y (list 'fn (list name)
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

;sigh, this isn't the same as repeatedly applying above
(def macex (x)
  (if (and (cons? x)
           (sym? (car x))
           (bound? (car x)))
      (let u (eval (car x))
        (if (macro? u)
            (macex (apply (macro-fn u) (cdr x)))
            x))
      x))

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


(def #;find-string string-pos (f s)
  (let slen (len s)
    (xloop (i 0)
      (if (is i slen)
          nil
          (f (s i))
          i
          (next (+ i 1))))))

#;(def err args ;used by builtin functions, so defined as builtin
    (raise (cons "Error:" args)))

(def chars->string (xs)
  (let n (len xs)
    (let s (make-string n)
      (xloop (xs xs i 0)
        (if (is i n)
            s
            (do (string-set s i (car xs))
              (next (cdr xs) (+ i 1))))))))

(def chars->sym (xs)
  (string->sym (chars->string xs)))

(def iso (x y) ;not robust to cycles
  (or (is x y)
      (and (cons? x)
           (cons? y)
           (iso (car x) (car y))
           (iso (cdr x) (cdr y)))))

;and now it is time to import some qq.

(mac casenlet (var expr . args)
  (list 'let var expr
        (xloop (args args)
          (if (no (cdr args))
              (car args)
              (list 'if
                    (cons 'or
                          (map1 (fn (x) (list 'is var (list 'quote x)))
                                (if (cons? (car args))
                                    (car args)
                                    (list (car args)))))
                    (cadr args)
                    (next (cddr args)))))))


(mac casen (x . args)
  (list* 'casenlet (uniq) x args))
(mac case args ;teh betterz
  (cons 'casen args))

(mac w/uniq bd
  (let vars (if (cons? (car bd))
                (car bd)
                (list (car bd)))
    (list* (list* 'fn vars (cdr bd))
           (map1 (fn (x) (list 'uniq)) vars))))


(mac in (x . vals)
  (w/uniq g
    (list 'let g x
          (list* 'or (map1 (fn (v) (list 'is g v)) vals)))))

(def isnt (x y)
  (no (is x y)))

;the following couple of functions will get redefined in the future
;so that a user can switch between arc3.1 ssyntax and my ssx

(def ssyntax? (x)
  nil)

(def ssexpand (x)
  (err "We are unprepared to ssexpand at the moment" x))

;with ssx semantics, we will probably dss an entire expression
;before handing it to anything like the following.
;however, with arc3.1 ssyntax, that is not the case.
;we may as well keep this compatible with both.

(def get-with-arglist (xs) ;version 1: the usual ;also fixing, but put into 0 too
  (if (or (atom xs) (no (cdr xs)))
      (list nil nil xs)
      (cons? (car xs))
      (let u (tuples 2 (car xs))
        (list (map car xs) (map cadr xs) (cdr xs)))
      (xloop (vars nil vals nil xs xs)
        (if (or (no xs)
                (no (cdr xs))
                (no (sym? (car xs)))
                (ssyntax? (car xs)) ;fuck that, dss it before handing it to this
                )
            (list (rev vars) (rev vals) xs)
            (next (cons (car xs) vars)
                  (cons (cadr xs) vals)
                  (cddr xs))))))

(mac with bd
  (let (vars vals body) (get-with-arglist bd)
    ;`((fn ,vars ,@body) ,@vals)))
    (list* (list* 'fn vars body) vals))) ;list* feels nicer here than cons

(mac withs bd
  (let (vars vals body) (get-with-arglist bd)
    (xloop (vars vars vals vals)
      (if (no vars)
          (cons 'do body)
          #;`(let ,car.vars ,car.vals
               ,(next cdr.vars cdr.vals))
          (list 'let (car vars) (car vals)
                (next (cdr vars) (cdr vals)))))))

;oh man. now...

(def expand-quasiquote (xs)
  (let u (expand-qq xs 1)
    (if (is 'idfn (car u))
        (cadr u)
        (is 'splice-pls (car u))
        (err "Inappropriate usage of unquote-splicing" u xs)
        u)))

(def expand-qq (x n)
  (if (atom? x)
      (list 'quote x)
      (case (car x)
        quasiquote
        (let (u) (cdr x)
          (qq-narb 'quasiquote (expand-qq u (+ n 1))))
        unquote
        (let (u) (cdr x)
          (if (is n 1)
              (list 'idfn u)
              (qq-narb 'unquote (expand-qq u (- n 1)))))
        unquote-splicing
        (let (u) (cdr x)
          (if (is n 1)
              (list 'splice-pls u)
              (qq-narb 'unquote-splicing (expand-qq u (- n 1)))))
        (expand-qq-rest x n))))

(def qq-narb (name v)
  (let qname (list 'quote name)
    (casen (car v)
      quote (list 'quote (list name (cadr v)))
      (list* cons) (list* 'list* qname (cdr v))
      (list append) (list 'list qname v)
      idfn (list 'list qname (cadr v))
      splice-pls (list 'cons qname (cadr v))
      (err "WTF?" name v))))

(def expand-qq-rest (x n)
  (if (atom x)
      (list 'quote x)
      (withs a (expand-qq (car x) n)
        b (expand-qq-rest (cdr x) n)
        ad (car a) bd (car b)
        the-a (if (is 'idfn ad) (cadr a) a)
        the-b (if (is 'idfn bd) (cadr b) b)
        ;quote, list*, append, idfn, splice-pls, list, cons
        (if (and (is 'quote ad) (is 'quote bd))
            (list 'quote (cons (cadr a) (cadr b)))
            (is 'splice-pls ad)
            (if (iso b ''nil)
                (list 'idfn (cadr a))
                (is bd 'append)
                (list* 'append (cadr a) (cdr b))
                (list 'append (cadr a) the-b))
            (iso b ''nil)
            (list 'list the-a)
            (casen bd
              (list* cons) (list* 'list* the-a (cdr b))
              list (list* 'list the-a (cdr b))
              (list 'cons the-a the-b))))))

(mac quasiquote (x)
  (expand-quasiquote x))

;ohhhh my gooooooooooooood, this is amazingly slow
;arc> (time:ue '(let x 2 `(+ ,x 3)))
;time: 175 cpu: 175 gc: 2 mem: 1195624
;(+ 2 3)
;arc> (time:ue '(let x 2 `(+ ,x 3 ,@(list 1 2))))
;time: 244 cpu: 244 gc: 4 mem: -18384328
;(+ 2 3 1 2)
;I may have to put in de-macro before other crap...
;well...
;not quite.
;...
;well, actually, de-macro is incredibly simple.
;especially now that I've handled qq here.

;arc> (dpprn:read:pbpaste)
;`(do
;  (sref signatures* ',parms ',name)
;  (sref definitions*
;    '(macro ,parms ,@body)
;    ',name)
;  (safeset ,name
;    (annotate 'mac
;      (fn ,parms ,@body))))
;nil
;arc> (dpprn:time:ue `(macex1 ',(read:pbpaste)))
;time: 2127 cpu: 2112 gc: 24 mem: -8480688
;(list 'do
;  (list 'sref 'signatures*
;    (list 'quote parms)
;    (list 'quote name))
;  (list 'sref 'definitions*
;    (list 'quote
;      (list* 'macro parms body))
;    (list 'quote name))
;  (list 'safeset name
;    (list 'annotate ''mac
;      (list* 'fn parms body))))
;nil

;I am staggered.
;Well. It would appear that I really need de-macro.
;General theory: I will need to essentially have a repository of which
;functions are "cuddly", which means they can be executed on constant
;arguments without causing strange things like side effects (and poss.
; type-error exceptions; I'm not sure exactly how I'll handle that).
;This information will be used by a de-macroizer/compiler.
;It seems that, in fact, I will need useful information about each function,
;rather than just substituting the source of each function as I simulate
;calling it, and doing everything atomically.
;(E.g. this means saying "map + xs is cuddly" and executing map at
; compile-time, rather than substituting the definition of "map" at
; each iteration.
; Incidentally, in the case of "map", it really depends on what the
; function is--the function has to be known and cuddly, I guess.
; And maybe the list has to be known and non-circular--maybe lists
; or data structures in general are cuddly when they're non-circular.)
;It would certainly be more efficient...
;... So some primitive functions would certainly have to be labeled by God
;(aka programmer) as cuddly. Then the system should be able to deduce
;that functions built from those are cuddly as well. (How about termination?
; ... That's certainly an argument for the "atomic" approach, sigh.
; Maybe the system can get good at automatically deducing termination.)

;Anyway, that would be the general theory.
;In this case, I'll probably introduce de-macro and ssx,
;and at that point *I* will know that all macro-functions are cuddly,
;and be sure because I wrote them.
;Then I can do that kidnap-your-closures-and-replace-them-with-clever-
;imitations-in-the-night thing. For efficiency!
;That will require some new primitives (closure-body, closure-env, etc.)
;... Um. Square that with the usual model of closure.

;Incidentally, blithely macexing stuff will change semantics.
;Suppose we macex "map".
;If we then pass a macro as the "f" argument to "map", the macro
;will get passed different stuff.
;It is possible to handle that, though.
;Just generate code that asks if "f" is a macro (or special form),
;and if so, it calls "f" on the actual source code and on a (lazily
; constructed?) lexenv.

;But, at any rate, I won't care about changing the semantics in that
;way for the code I'm writing and running.
;(Half of it isn't even written the way I'd like it to be.)
;

;... It seems like most closures will have to be assumed non-cuddly,
;unless they are specifically accounted for in the global bindings.
;This is because it seems it would be too much overhead to change all
;closures...........
;That seems like a terrible reason.
;Yeah, it pretty much is.
;It shouldn't be difficult to change all closures that are created
;from known closures.
;... Actually, yes, it should.
;(After re-macroexpansion, the code that created
; some old closure can become unrecognizable.)
;Continuations, continuations, continuations. And closures.
;Let's see.
;Cases.
;- make-counter is bound to a globvar.
;A made counter is bound to a globvar.
;It is straightforward that modifying the make-counter should do nothing
;to the existing made counter, and redefining some crap
;that the made counter depends on should cause the made
;counter to get recompiled.
;This goes if there are a lot of made counters in globvars, too, because there
;generally aren't too many globvars.
;They should probably share the code in some way.
;Next... some made closures will hide outside globvars (or inside big
; structures that are bound to globvars).
;

;Closures that are kind-of-compiled like this (that have been optimized under
; ass'ns) should just begin with code that says "check if ass'ns have been
; invalidated". Thus, compiled closures, when they create compiled continuation-
;closures, should make closures-that-begin-with-a-check (unless you happen to
; know exactly where that closure will be and when it will die).

;Well, then, I can proceed as planned...

;Get more sophisticated later.
(mac bracket-fn bd
  (list* 'fn '(_) bd))

(assign bound? bound)


;for debugging purposes, not creating cyclic structures...
;I shall do this.
;--nvm it had nothing to do with it
(def nflip (xs ys)
  #;(if (no xs)
      ys
      (let u (cdr xs)
        (scdr xs ys)
        (nflip u xs)))
  (flip xs ys))

(def nrev (xs)
  (nflip xs nil))

(def append2 (xs ys)
  (nflip (rev xs) ys))


;   ;not exactly sure how I feel about (ca/dr nil) = nil
;   ;(just that it adds yet another case to check in machine code)
;   ;(I guess I can treat that as second class and put it on a slow path)
;   (def xcar (x) (if (no x) x (car x)))
;   (def xcdr (x) (if (no x) x (cdr x))) ;not sure if this is necessary so far
;k, guess it is.

;(def xcar (x) (if (no x) x (car x)))
;(def xcdr (x) (if (no x) x (cdr x)))
;(assign raw-car car)
;(assign car xcar)
;(assign raw-cdr cdr)
;(assign cdr xcdr)

;HOHOHOHOHOHOHOHOHOHO OHHHHHHH MY GOD THAT HURTS PERFORMANCE SOOOOOOOO
;MUCH HOHOHOHOHOHOHOHOHOHO
;(in practice car/cdr really will be implemented as primitives that way)
;oh wait that's an infinite loop

(def xcar (x) (if (no x) x (raw-car x)))
(def xcdr (x) (if (no x) x (raw-cdr x)))
(assign raw-car car)
(assign raw-cdr cdr)
;(assign car xcar)
;(assign cdr xcdr)
;ok it makes a noticeable performance difference


(def accumulate (comb f xs init next done)
  ((rfn self (xs ys)
     (if (done xs)
         ys
         (self (next xs) (comb (f xs) ys))))
   xs init))


(def append xs
  (if (no xs)
      xs
      (no (cdr xs))
      (car xs)
      (no (cddr xs))
      (append2 (car xs) (cadr xs))
      (append2 (car xs) (apply append (cdr xs))))) ;eh

(def testify (f)
  (if (fn? f)
      f
      (fn (x) (is x f))))

(def all (f xs)
  (let f (testify f)
    (xloop (xs xs)
      (or (no xs)
          (and (f (car xs)) (next (cdr xs)))))))
(def some (f xs)
  (let f (testify f)
    (xloop (xs xs)
      (and xs
           (or (f (car xs)) (next (cdr xs)))))))

(def map (f . xs)
  (if (and (cons? xs) (no (cdr xs)))
      (map1 f (car xs))
      (some no xs)
      nil
      (cons (apply f (map1 car xs))
            (apply map f (map1 cdr xs)))))

;since this has proven fastest for the moment, will use
(def keep (f xs)
  (let f (testify f)
    (xloop (xs xs)
      (if (no xs)
          nil
          (f (car xs))
          (cons (car xs) (next (cdr xs)))
          (next (cdr xs))))))

;likewise (a compiler should make smthg else faster or eqv)
#;(def range (a b) ;unused so far, and don't have >< yet
    (if (> a b)
        nil
        (cons a (range (+ a 1) b))))


(def idfn (x) x)
(def inc (x) (+ x 1)) ;for now

(def flat (xs)
  (nrev
   (xloop (xs xs ys nil)
     (if (cons? xs)
         (next (cdr xs) (next (car xs) ys))
         (no xs)
         ys
         (cons xs ys)))))

(def arglist-argnames (xs)
  (keep sym? (flat xs)))

#;(def symbol-value (x) ;for the moment, be an idiot ;neh
    (if (no (sym? x))
        (err "symbol-value: Not a symbol" x)
        (eval x)))

(assign acons cons?)

(def mem (f xs)
  (mem-f (testify f) xs))
(def mem-f (f xs)
  (if (no xs)
      nil
      (f (car xs))
      xs
      (mem-f f (cdr xs))))

(assign fn-object fn)
(assign quote-object quote)
;(assign compose-object compose)

(def bound-to? (s v)
  (and (sym? s)
       (bound? s)
       (is (symbol-value s) v)))

(def de-macro (x env)
  #;(prsn 'de-macro x)
  (if (ssyntax? x)
      (de-macro (ssexpand x) env)
      (atom x)
      x
      (let (a . b) x
        #;(prsn 'lol a b)
        (let a (if (ssyntax? a) (ssexpand a) a)
          (if (and (cons? a)
                   #;(bound-to? (car a) compose-object)
                   #;(no (mem a env)) ;ssx would ignore...
                   (is (car a) 'compose)) ;geez, fixing that takes a while...
              (de-macro (xloop (a (cdr a) b b)
                          ;non-tail-rec way from decompose is easiest
                          (if (no a) ;composition of nothing shd be idfn
                              (if (cdr b) ;multiple values
                                  (err "Wat" x) ;are not allowed
                                  (car b))
                              (let u (cdr a)
                                (if (no u)
                                    (cons (car a) b)
                                    (list (car a)
                                          (next u b))))))
                        env)
              (let a (de-macro a env)
                #;(prsn 'der a)
                (if (mem a env)
                    ;... we could detect local bindings to literal macros
                    ;and maybe direct calls to literal macros as well
                    ;(as in ((macro ...) arg ...))
                    ;but neh (this is where a 'mc special form is useful,
                    ; 'cause otherwise it's (make-macro) on insane crap...
                    ; eh, wouldn't be too hard... feh)
                    (cons a (map [de-macro _ env] b))
                    (and (sym? a)
                         (bound a)
                         (macro? (symbol-value a)))
                    (de-macro (macex (cons a b)) env)
                    (bound-to? a fn-object)
                    (cons a (let u (car b)
                              (cons u
                                    (let env (append (arglist-argnames u) env)
                                      (map [de-macro _ env] (cdr b))))))
                    (bound-to? a quote-object)
                    (cons a b)
                    (in a '$ 'arc)
                    (cons a b)
                    (cons a (map [de-macro _ env] b)))))))))


;ssyntax-string? appears to be the big waster ;OR WAS

;you know, it'd be pretty useful to keep absolute compatibility between
;dyn-cont (or whatever it'll be called) and the assembly version,
;for reasons of testing with Racket-Arc.

;ok, this will now map closures (expanded) to closures (source) (also macros)
;scratch that, back to sym -> closure/macro.
;--ok, now we use a hash table.
(assign source-code (make-table))
#;(def save-code (src exp)
    (assign source-code (cons (list exp src) source-code)))
#;(def save-code (sym exp)
  (assign source-code (cons (list sym exp) source-code)))
(def save-code (sym exp)
  (table-set source-code sym exp))

(def expand-closure (x)
  (make-closure (closure-env x)
                (closure-args x)
                (map [de-macro _ nil] (closure-body x))))
(def expand-macro (x) ;the definition of a macro
  (make-mac (expand-closure (macro-fn x))))

(def expand-thing (x)
  (if (closure? x)
      (expand-closure x)
      (macro? x)
      (expand-macro x)
      nil))

(mac aif args
  (if (no args)
      nil
      (no (cdr args))
      (car args)
      `(let it ,(car args)
         (if it
             ,(cadr args)
             (aif ,@(cddr args))))))

;not sure about efficiency in bootstrapping... oh well.
#;(mac awhen (test . body)
    `(aif ,test (do ,@body)))

;ok, yeah, this makes a 40x difference... lolz.
(mac awhen (test . body)
  (list 'let 'it test
        (list 'if 'it
              (list* 'do body))))

(def de-macroize (sym)
  (let old (symbol-value sym)
    (awhen (expand-thing old)
      ;(prsn "de-macroized" (sym->string sym))
      (save-code sym old)
      (symbol-set sym it))))

(def alref (xs x) ;unnecessary at the moment
  (if (no xs)
      nil
      (is (caar xs) x)
      (cadr (car xs))
      (alref (cdr xs) x)))

#;(def time-dm () ;lolz unnecessary
    (let u (msec)
      (expand-closure de-macro)
      (- (msec) u)))

(def expand-all (firstly)
  (map de-macroize firstly)
  (map de-macroize (keep [no (mem _ firstly)]
                         (all-bound-symbols)))
  nil)

(assign the-order '(#;ssyntax-string?
                    do decimal-digits
                    chars->string de-macro
                    de-macroize))

(mac xdef (name args . body)
  (w/uniq (gsrc gexp)
    `(let ,gsrc (fn ,args ,@body)
       (let ,gexp (expand-closure ,gsrc)
         (save-code ',name ,gsrc)
         (assign ,name ,gexp)))))
(mac xmac (name args . body)
  (w/uniq (gsrc gexp)
    `(let ,gsrc (make-mac (fn ,args ,@body))
       (let ,gexp (expand-macro ,gsrc)
         (save-code ',name ,gsrc)
         (assign ,name ,gexp)))))


;now, for a while, we will use this...
(assign def-plain def)
(assign mac-plain mac)
;and by the way, wtf am I doing with the original source code
;in that 

(assign def xdef)
(assign mac xmac)

;reordered the below and the above, so that when def and mac are
;reexpanded from source later, they have the "right" source
;(I should define a "reassign" function or something, which also
; alters the source code)

(prn "Expanding everything now")
(expand-all the-order)



(def mac-sp? (x)
  (or (macro? x) (special-object? x)))

(def composeff (a b)
  (fn args
    (a (apply b args))))

;slightly less terrible output than it could be
(mac compose xs
  (if (no xs)
      'idfn
      (no (cdr xs))
      (car xs)
      (with evnames (map [uniq] xs)
        fnames (cons 'idfn (map [uniq] (cdr xs))) ;lel
        (xloop (ev evnames fns fnames xs xs)
          `(let ,(car ev) ,(car xs)
             (if (mac-sp? ,(car ev))
                 (function-macro-rest ,(car fns)
                                      ,(car ev)
                                      ',(cdr xs))
                 ,(if (no (cdr xs))
                      `(composeff ,(car fns) ,(car ev))
                      (is ev evnames)
                      (next (cdr ev) (cons (car ev) (cdr fns)) (cdr xs))
                      `(let ,(cadr fns) (composeff ,(car fns) ,(car ev))
                         ,(next (cdr ev) (cdr fns) (cdr xs))))))))))

(def reversifier (xs)
  (let (r . rest) (rev xs)
    (fn (args)
      (xloop (rxs rest args (cons r args))
        (if (no rxs)
            args
            (next (cdr rxs) (list (car rxs) args)))))))

;oh my god this is so much more beautiful than what I originally
;came up with
(def function-macro-rest (f m xs)
  (reversifier `(',f ',m ,@xs)))

;and now...

(def ssx? (x)
  (and (sym? x)
       (ssx-string? (sym->string x))))

(def ssx-string? (s)
  (let u (string-pos ssx-char? s)
    (and u
         (no (and (is u (- (len s) 1))
                  (in (s u) #\? #\!))))))

(def dss-head (x)
  (if (acons x)
      (if (is (car x) '$)
          x
          (ssx? (car x))
          (let (a an) (ssx-term (car x))
            (if (xloop (a a an an)
                  (if (is an 0)
                      (is a '$)
                      (or (is (a 2) '$)
                          (next (a 1) (dec an)))))
                (ssx-clean a (cdr x) an)
                (ssx-clean a (dss-tail (cdr x)) an)))
          (cons (dss-head (car x)) (dss-tail (cdr x))))
      (ssx? x)
      (ssx x)
      x))

(def dss-tail (x)
  (if (acons x)
      (cons (dss-head (car x)) (dss-tail (cdr x)))
      (ssx? x) ;was still is-ssx
      (ssx x)
      x))
(assign dss dss-head)
(def ssx-char? (x)
  (in x #\: #\? #\& #\. #\!))

(def transitive (f-two xs)
  (if (no xs)
      't
      (transitive-rest f-two (car xs) (cdr xs))))

(def transitive-rest (f-two x xs)
  (if (no xs)
      't
      (f-two x (car xs))
      (transitive-rest f-two (car xs) (cdr xs))
      nil))

(def < args (transitive <2 args))
(def > args (transitive >2 args))
;lolz, <= is inferior to < performance-wise until compilers happen...
(def <=2 (x y) (no (>2 x y)))
(def >=2 (x y) (no (<2 x y)))
(def <= args (transitive <=2 args))
(def >= args (transitive >=2 args))

(def char<= args
  (transitive char<=2 args))

(def char<=2 (x y)
  (<=2 (char->int x) (char->int y)))

(def char->digit (x) ;no unicode digits pls
  (let u (- (char->int x) (char->int #\0))
    (and (<= 0 u 9)
         u)))

(def digit? (x)
  (char<= #\0 x #\9))

;we return nil if is not a pure integer
(def string->decimal (s)
  (xloop (i 0 n 0)
    (if (is i (len s))
        n
        (digit? (s i))
        (next (+ i 1) (+ (char->digit (s i))
                         (* 10 n)))
        nil)))

;(assign string->number string->decimal) ;neh

;string -> symbol or number
(def s->sn (s)
  (or (string->decimal s)
      (string->sym s)))

(def string-copy-* (dst dstn src st ed)
  (if (> st ed)
      (err "Trying to copy negative characters from a string"
           st ed src)
      (> (- ed st) (- (len dst) dstn))
      (err "Trying to copy too many characters into a string"
           (- ed st) dst dstn)
      (xloop (dn dstn st st)
        (if (is st ed) ;is, not >
            dst
            (do (string-set dst dn (src st))
              (next (+ dn 1) (+ st 1)))))))


(def string-cut (s a . b)
  (let b (if b (car b) (len s))
    (let u (make-string (- b a))
      (string-copy-* u 0 s a b))))

(assign substring string-cut)

(def sumlist (f xs)
  (xloop (xs xs n 0)
    (if (no xs)
        n
        (next (cdr xs) (+ (f (car xs)) n)))))

(def string-append args
  (let u (make-string (sumlist len args))
    (xloop (args args i 0)
      (if (no args)
          u
          (let s (car args)
            (string-copy-* u i s 0 (len s))
            (next (cdr args) (+ i (len s))))))))

;the following will need to be improved later with destructuring
;assignment, as well as optional args
(mac ++ (x . n)
  `(assign ,x (+ ,x ,(if (cons? n)
                         (car n)
                         1))))
(mac -- (x . n)
  `(assign ,x (- ,x ,(if (cons? n)
                         (car n)
                         1))))

;why is it not defined like this in arc.arc?
(mac while (test . body)
  (w/uniq gf
    `((rfn ,gf ()
        (when ,test ,@body (,gf))))))

(def dec (x) (- x 1))

(mac when (test . body)
  `(if ,test (do ,@body)))

(def ssx-list (x)
  #;(prn x)
  (withs s (sym->string x)
    slen (len s)
    #;(prsn x s slen)
    (if (is (s 0) #\:)
        (list (s->sn (string-cut s 1)))
        (is (s 0) #\!)
        (ssx-list (string->sym (string-append "get" s)))
        (is 1 slen)
        (list x)
        (do (when (is (s (dec (len s))) #\!)
              (-- slen))
          (xloop (i 0)
            (if (is i slen)
                (err "Empty substring at end of ssyntax" s i)
                (let j i
                  (while (and (< j slen)
                              (no (ssx-char? (s j))))
                    (++ j))
                  (if (is j slen)
                      (list (s->sn (string-cut s i)))
                      (isnt (s j) #\?)
                      (if (is i j)
                          (err "Empty substring in ssyntax" s i j)
                          (cons (s->sn (string-cut s i j))
                                (cons (s j) (next (+ j 1)))))
                      (do (while (and (< j slen)
                                      (is (s j) #\?))
                            (++ j))
                        (if (is j slen)
                            (list (s->sn (string-cut s i)))
                            (ssx-char? (s j))
                            (cons (s->sn (string-cut s i j))
                                  (cons (s j) (next (+ j 1))))
                            (cons (s->sn (string-cut s i j))
                                  (cons #\? (next j)))))))))))))

(def ssx (x) 
  (let (x xn) (ssx-term x)
    x))

(def ssx-term (x) 
  (ssx-reduce (ssx-list x)))

;turns out, the following does involve taking either the car or cdr of nil.
;sigh...
(def ssx-reduce (xs)
  (xloop (xs xs n 0)
    (if (cdr xs)
        (let (a directive b . rest) xs
          (case directive
            #\? (let (x xn) (next (cons b rest) 0)
                  (list (ssx-clean a (list x) n) 0))
            #\: (next (cons `(compose ,a ,b) rest) (+ n 1))
            #\& (next (cons `(andf ,a ,b) rest) 0)
            #\. (next (cons (ssx-clean a `(,b) n) rest) 0)
            #\! (next (cons (ssx-clean a `(',b) n) rest) 0)))
        (list (car xs) n))))

(def ssx-clean (f xs n)
  (if (is n 0)
      (cons f xs)
      (let (cmp a b) f
        (ssx-clean a (list (cons b xs)) (dec n)))))

;(err "Placeholder")

(assign ssyntax? ssx?)
(assign ssexpand ssx)

;ok the above things screw shit up ;prob. fixed now

;oh my god it seems to work
;now... we can make use of it...
;... actually, de-macro already does ssx stuff; we've just
;enabled that crap to actually work.
;let's test it.
(def square (x) (* x x))
(def mod-expt (a n m)
  (xloop (a a n n tt 1)
    (if zero?n
        tt
        even?n
        (next (mod square.a m) (div n 2) tt)
        (next a dec.n (mod (* a tt) m)))))

;yep; looks like I wins.
;next we want optionals, I guess, and then reading and files.

;let's see if I can reuse an old definition.
;yes, from heh-cont-base...

(assign fn-plain fn)
;a slightly dumb hack (I love ssx)
(def plain-arglist? (x)
  (or atom?x
      (and atom?car.x
           plain-arglist:cdr.x)))
(def is-optional (x) ;oh baby
  (and cons?x (is car.x 'o)))

;I see, it probably still won't work to do it like this
;and then just reassign 'fn to 'fn-optional...
;'cause "or" may expand into "fn" crap.
;Is there a way I can get around that...?
;A more advanced kind of recompilation crap might work...
;Eh, feh, neh.
#;(def has-optionals (xs)
    (and cons?xs
         (or (and cons?car.xs
                  (is car:car.xs 'o))
             has-optionals:cdr.xs)))

(def has-optionals (xs)
  (if atom?xs
      nil
      atom?car.xs
      has-optionals:cdr.xs
      (is car:car.xs 'o)
      't
      has-optionals:cdr.xs))


(mac fn-optional (args . body)
  (if has-optionals.args
      (w/uniq gargs
        (xloop (args args plains nil)
          (if is-optional:car.args
              `(fn-plain ,(flip plains gargs)
                         ,(xloop (args args)
                            (if no.args
                                `(do ,@body)
                                (let ((is-o nam . valp) . rest) args
                                  (unless (is is-o 'o)
                                    (err "Bad optional arglist" args))
                                  `(with (,nam (if (cons? ,gargs)
                                                   (car ,gargs)
                                                   ,(if cons?valp
                                                        car.valp
                                                        'nil))
                                               ,gargs (cdr ,gargs))
                                     ,(next cdr.args))))))
              (next cdr.args (cons car.args plains)))))
      `(fn-plain ,args ,@body)))

;ok, and now, I will need to reexpand everything.
;... ...
;that can't really be done nicely and efficiently
;(nicely = get the original source code to ev'thing and then
; reexpand it)
;(efficiently = less than O(n^2))
;without a real table or some kind of dumb hash thing to sort
;closures...
;I guess I should move back to the "sym -> original code" model,
;rather than "closure -> closure".
;ok, and then...

;I guess it would be good if I could sort things or something...
;feh.
;ah...
;I can make some kind of queue structure: insert at the end,
;and verify that certain desired things are first.
;This is without needing to compare two symbols (to see which is greater,
; that is).
;Well, let's see what happens if I just fuck it.

(def reexpand-from-src ((sym src))
  (awhen expand-thing.src
    (symbol-set sym it)))

#;(def reexpand-just (xs)
    (xloop (xs xs ss source-code)
      (if no?xs
          nil
          (mem caar.ss xs)
          (do reexpand-from-src:car.ss
            (next cdr.xs cdr.ss))
          (next xs cdr.ss))))

(def reexpand-all ()
  (no:map reexpand-from-src tablist.source-code))


(assign fn fn-optional)

;Guh.
;Takes .8 seconds to reexpand-all,
;and takes much longer to "reexpand-just" the-order.
;I really should have something that can recompile (/reexpand)
;things "under a new binding".
;That'd make this shit faster.
;Redefining fn and having to reexpand everything at once...
;It's like cutting off all your limbs and having to survive in the
;meantime while they regrow, whereas one would like to be able to
;cut off individual limbs and let each one regrow while you have
;all the other limbs still fully usable to help you survive in the meantime.
;Actually, it'd be more like growing a new limb and then cutting off
;the old one and replacing it in the same movement.
;Perhaps even growing a full new set of limbs and replacing them all
;in immediate succession could be done... that is how it must be for
;some kinds of changes, anyway.
;(As a matter of fact, this whole bootstrapping thing kind of is that.)

;Although it would also make it possible to get into weird situations
;that might be philosophically troubling: e.g. if you go and decide
;to recompile everything... ... well, the idea is that you might not
;be able to reexpand everything, you might get some circular crap...
;But I think that probably isn't ...
;Hmm.
;My task here, for bootstrapping, is to provide a bunch of functions
;and some macros. 


;Btw, another option is to just expand the already-expanded stuff.
;That would work fine on the existing closures.

;Well, anyway.
;.8 seconds ain't bad, especially since it'll probably run faster
;when the base interpreter is written in assembly.
;Plus earlier crap probably takes longer anyway.

(reexpand-all)

;turn on ssyntax
(assign ssyntax? ssx?)
(assign ssexpand ssx)


;... ... Ok, what next?
;I guess I had called for reading and files.
;Oh boy. Oh dear. Oh no. Jez'.
;And maybe tables. I had 

;I remember at some point realizing there was something seriously
;wrong with my implementation of "read"... I suspect it was a
;relatively minor issue, though... hmmph.


;[preamble from the department of random lectures]
;So, a thing to realize is that:
;With the problem described in PG's comment as "A bit gross that
;it depends on the *name* in the car", talking about (= cdr.x val)
;and shit:
;The analogue of it in interpreter semantics is "Does the car of
;this expr evaluate to the cdr function?".
;And then, the analogue of it in "interpreter, deciding to be a
;compile-time jerkass" is "Right now, at compile time, can the
;car of this expr be determined to evaluate to the cdr function?".
;Which is exactly what I've done for other shit.

;Ok, let's put in some conveniences to begin with.
;Let's take the semantics of =.
;Interpreter semantics:
;(= car.x blah-blah)
;-> ssx
;(= (car x) blah-blah)
;->
;(let u (eval-here 'car)
;  (if (is u car)
;      (scar x blah-blah)
;      (sref u x blah-blah)))
;
;If (car x) is actually a macro, should it get expanded first?
;I think not. One who writes such a macro can install a case
;for =.
;Right, then, now, as for the code duplication problem.
;["blah-blah" twice in output? O(2^n)? fuck ass.]

;(def inverse-of (x)
;  (vcase x
;    car scar
;    cdr scdr
;    
;    sref))
;Now, there's a funny case with extra args to hash tables.
;Basically with ++ and what it expands to.
;It is possible, and I like that it is possible, in arc3.1
;to go (++:tb x 0).
;Not really sure what to do.
;I could just say "++ should be careful to expand (++ (a b c))
;to something like (withs g1 a g2 b g3 c (= g1.g2 (+ 1 (g1 g2 g3))))".
;(By the way, with multithreading, PG has = expand to something
; involving "atomic". Feh. Some things need retrying with CMPXCHG,
; some things need try/fail. A global lock is prob. not acceptable.)

;(let u (eval-here 'car)
;  ((if (is u car)
;       [scar _a _b]
;       [sref u _a _b])
;   x blah-blah))
;Would work.
;If I don't mind constructing x and blah-blah before testing ...
;I guess it should probably be fine, 'cause it won't be an error
;no matter what ... well, probably.
;Still feels a bit odd to change the order.
;
;By the way, I really don't like the argument order in sref as it's
;defined in ac.scm.
;Additional indices--maybe.
;[Though if it's nested data structures, e.g. tables or vectors,
; then you certainly should be able to get the inside stuff.
; And additional indices could be supplied as a list, and
; an optimizing compiler might be able to handle that. Wtvr.
; Or it could be (sref xs indexes...+ val).]


(def sref (xs ind val) ;proper arg order by my declaration
  (if cons?xs
      (scar (drop ind xs) val)
      ((if string?xs string-set
           vector?xs vector-set
           table?xs table-set
           error)
       xs ind val)))

;could make it strict-tuples
(mac = args `(do ,@(map [cons '=2 _] (tuples 2 args))))

(mac =2 (x y)
  (if no:cons?x
      `(assign ,x ,y)
      (let (xs ind) x
        `(invert-= ,xs ,ind ,y))))

;f = either an accessor function or a data structure
;...... I should probably have a hash table handy to do this
(def invert-= (f ind val)
  (aif invert-accessor.f
       (it ind val)
       (sref f ind val)))

(def table args
  (let u (make-table)
    (map (fn ((x y)) (table-set u x y)) (tuples 2 args))
    u))

(assign invert-accessor
        (table car scar
               cdr scdr))
    

;By the way, just FYI, on the previous version:
;(grid:sort (compare > cadr) tablist.counts)
;bclos           10278665
;bcall-1         10278520
;ueval            6320681
;lookup           3645573
;map-ueval        3535914
;ucall            2423641
;join-e2          2071661
;base-tag         1978902
;uapply           1911119
;umac?            1609569
;bcall-3          1233203
;ueval-if          877209
;ubegin            662808
;uclos-body        659761
;uclos-env         659761
;uclos-arglist     659761
;join-e            659517
;make-uclos        209736
;ucons             197177
;umac-clos          99885
;utype              67783
;uclos?              4205
;uassign             1153
;usym-set             903
;make-usym            676
;usymb                551
;dextend              145
;dyn-id               145
;ucall-w/param        145
;uify                 145
;make-umac             86
;boot                   1
;uall-bound-syms        1
;
;to run el booto.


;Guru meditation...
;It has occurred to me that it appears that if a compiler
;compiles itself several times deep, and runs a program, the
;program runs acceptably fast and the entire process takes
;about N times, but an interpreter running a program several
;times deep takes an amount of time exponential in the depth.
;This feels somewhat astonishing.

;[BTW ^Z should put curr. on a subthread and bring up REPL,
; and a second ^Z should suspend the whole process.]


;Ok.
;To speed shit up for the reexpansion,
;it should be easy to write a version of de-macro
;to which you pass a global env to look shit up in.
;A hash table.
;And you can incrementally compute the definitions.
;This is completely semantically permissible under the assumption
;that the reason you need to reexpand is that you've added some
;new features that previously you had not made any use of.
;(Empirically: would cut down reexpansion from 13.8 seconds to
; more like 5 seconds. Mebbe worth it.)




