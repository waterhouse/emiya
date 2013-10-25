;Absolute purity.

;We will use uber-ssyntax, so that I can coddle myself as
;much as possible as I write this.
;Let's see...

(= globval (table))

(= cons? ($:lambda (x) (if (pair? x) 't 'nil))
   atom? ($:lambda (x) (if (pair? x) 'nil 't))
   sym?  ($:lambda (x) (if (symbol? x) 't 'nil))
   string? ($:lambda (x) (if (string? x) 't 'nil))
   num? ($:lambda (x) (if (number? x) 't 'nil))
   fn?  ($:lambda (x) (if (procedure? x) 't 'nil))
   no? no)


;Macro: (macro <closure>)
(def macro? (x)
  (and cons?x (is car.x 'macro)))
(def macro-clos (x)
  cadr.x)

(def clos? (x)
  (and cons?x (is car.x 'closure)))

;A dynamic environment...
;;A dynvar = (dynvar <integer>)
;A dynvar = (dynvar <integer> <value>) [value used for default]
;The dynamic env = ((<integer> <value>) ...)

(def dynvar? (x)
  (and cons?x (is car.x 'dynvar)))
(def dynvar-num (x)
  cadr.x)
(def dynvar-val (x)
  x.2)

;currently no attempt made to dedup things,
;to clean up the education system or the dynenv
(def dyn-extend (xs x v)
  (cons (list dynvar-num.x v) xs))

#;(= failure* (cons 'failure 'value))

;hmm. do we want the sort of thing where ...
;hmm.
;... I definitely don't want it to be illegal to assign to a dynvar.
;that would be totally giving up functionality.
;but...
;do I want "global" values for them?
;that is actually a separate question.
;I am inclined to say no, because it is easier.
;bwahaha.
;right ho.
;--actually no.

;hmm...
;exact semantics...
;it is possible for another thread to create a dynvar and
;pass it to this thread while it's doing whatever in the routine
;course of events.
;such a lookup should then produce whatever the other thread
;assigned to that dynvar.
;which would appear to imply that I should use a global table
;that it can assign to...
;or: have a value in the dynvar structure itself.
;methinks that is the thing to do.

;it would seem that dynvars s

(def dyn-lookup (xs x)
  (aif (assoc dynvar-num.x xs)
       cadr.it
       #;failure*
       dynvar-val.x))

(def dyn-assign (xs x v)
  (aif (assoc dynvar-num.x xs)
       (scar cdr.it v)
       #;(err "dyn-assign: not found" x v xs)
       (= x.2 v)))

(= dynvar-count 0)

#;(def make-dynvar ()
  (list 'dynvar ++.dynvar-count))

(def make-dynvar ((o val nil))
  (list 'dynvar ++.dynvar-count val))

(= lexenvd (make-dynvar))
;destructuring
(def lex-extend* (e vars vals)
  (let complain (fn () (err "lex-extend: You suck" vars vals))
    (xloop (e e x vars v vals)
      (if no?x
          (if no?v
              e
              (complain))
          cons?x
          (if cons?v
              (next (next e car.x car.v) cdr.x cdr.v)
              (complain))
          sym?x
          (cons (list x v) e)
          (complain)))))

(def lex-lookup (e x)
  (aif (assoc x e)
       cadr.it
       globval.x
       (and (isnt it 'HELLA-NIL) it)
       (err "Unbound variable" x)))

(def lex-assign (e x v)
  (aif (assoc x e)
       (scar cdr.it v)
       (= globval.x (or v 'HELLA-NIL))))
;heh. I could go as far as representing symbols themselves,
;in which case I wouldn't need a globval table or associated ridic'ness.
;same as looking up inside dynvars...

(def ueval (x (o d nil))
  (if (or num?x string?x)
      x
      sym?x
      (lex-lookup (dyn-lookup d lexenvd) x)
      #;(or dynvar?x macro?x clos?x fn?x)
      #;x
      cons?x
      (let (f . xs) x
        (let u (ueval f d)
          (ucall u xs d)))
      (err "What is this?" x)))

;Hmm... dynvars themselves...
;Call them with no args.
;As for assignment... sure, call them with an arg.

(def ucall (f xs d)
  (if macro?f
      (ueval (apply-mac f xs d) d)
      (let args (map [ueval _ d] xs)
        (if clos?f
            (call-clos f args d)
            dynvar?f
            (if no.args
                (dyn-lookup d f)
                (dyn-assign d f car.args))
            fn?f
            (apply f args)
            (err "call: What is this?" f xs)))))

;to make it a tad easier on myself, will permit the closure of a macro
;to be a raw fn.
;maybe improve on that in later versions.
(def apply-mac (f xs d)
  (let u macro-clos.f
    (if fn?u
        (apply u xs)
        (call-clos u xs d))))

(def call-clos (f args d)
  (let (cls ev ag . bd) f
    (let d (dyn-extend d lexenvd ;hohoho, space safety? hohoho
                       (lex-extend* ev
                                    ag args))
      ;(prsn f args d)
      (ueval-begin bd d))))

(def ueval-begin (body d)
  (if no?body
      nil
      (xloop (body body)
        (if no?cdr.body
            (ueval car.body d)
            (do (ueval car.body d)
                (ueval-begin cdr.body d))))))

;wow, is that really it?
;that just leaves the standard library.
;which will include some crap.
;oh boy.

;... calling convention?
;jeez.

;it begins.
(= globval!lexenv lexenvd)

(= globval!lex-assign lex-assign)

(= =-macro-func
   (fn (x v)
     `(lex-assign (lexenv) ',x ,v))
   =-macro
   `(macro ,=-macro-func)
   globval!= =-macro)

(= object-number ($:make-hasheq)
   number-object (table)
   quote-object-count 0
   globval!number-object number-object)

(def get-object-number (x)
  (aif object-number.x
       it
       (let n ++.quote-object-count
         (= number-object.n (or x 'HELLA-NIL)
            object-number.x n)
         n)))

(def terrible-hashref (x k)
  (aif x.k
       (and (isnt it 'HELLA-NIL) it)
       (err "terrible: Didn't find it" k x)))

(= globval!terrible-hashref terrible-hashref)

(= quote-macro-func
   (fn (x)
     `(terrible-hashref number-object ,(get-object-number x)))
   quote-macro
   `(macro ,quote-macro-func)
   globval!quote
   quote-macro)

;oh dear god
;welp, we proceed
#;(def %if (x ta tb) ;too bad
  (if x
      (ta)
      (tb)))

;the above requires ...
;the above doesn't work, because (blah) from raw Arc isn't
;how you call a closure in the interpreted Arc.
;we'd really need eval.
;which would suck.
;so we will use the absolute minimum.
(def %if (x a b)
  (if x a b))

(= globval!%if %if
   if-macro-func
   (fn args
     (if no?args
         'nil
         no?cdr.args
         car.args
         #;`(%if ,car.args
               (fn () ,cadr.args)
               (fn () (if ,@cddr.args)))
         `((%if ,car.args
                (fn () ,cadr.args)
                (fn () (if ,@cddr.args))))))
   if-macro
   `(macro ,if-macro-func)
   globval!if if-macro)

;good lord
;oh god

;OH god
;oh wait need it earlier
#;(= globval!lexenv lexenvd
   ;globval!lex-extend* lex-extend*
   )

(= fn-macro-func
   (fn (arglist . bodexprs)
     `(list* 'closure (lexenv) ',arglist ',bodexprs))
   fn-macro
   `(macro ,fn-macro-func)
   globval!fn fn-macro)

(def umacex1 (x)
  (apply-mac (ueval car.x nil) cdr.x nil))
(= globval!umacex1 macex1)
            
;welp, here we go.
;arc> (time:ueval '((fn (f) (f f 10 0)) (fn (f x n) (if (is x 0) n (f f (- x 1) (+ x n))))))
;time: 3 cpu: 3 gc: 0 mem: 214232
;55
;amaising.
;haven't done quasiquote or compose or ssyntax or creating macros.
;also, the stuff that creates closures and maybe other stuff
;should perhaps have specific names.
;but oh well.








(each x '(+ - * / car cdr cadr cddr list cons no list* < > is)
  (= globval.x symbol-value.x))

