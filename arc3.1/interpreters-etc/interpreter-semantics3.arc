;Insight from the free-association department:
;"apply-loop", or what I'll probably call "eval-progn",
;should say:
; (let (x . rest) exprs
;   (if no.rest
;       (eval x env) ;tail call
;       (do (eval x env)
;           (eval-progn rest env))))

;Rather than the current:
;(def uapply-loop (env exprs)
;  (if no.exprs
;      nil
;      no:cdr.exprs
;      (ueval car.exprs env) ;tail call!
;      (do (ueval car.exprs env)
;        (uapply-loop env cdr.exprs))))

;This is because...
;In the second version, technically, the first expression
;could modify the cdr of "exprs".  Therefore, you would never
;know that something was a tail call--tail UNTIL YOU EXECUTE IT.
;Now...
;This can kind of be semantically justified like this:
;(let rest cdr.exprs
;  (eval car.exprs env (fn () (eval-progn rest env))))
;As in CPS.
;You first construct the return continuation,
;then you execute the first expr with that as its continuation
;argument.


;This was brought to mind by...
;(a) tail call elimination, consistency
;(b) remembering how I was kind of puzzled by "cdr.p[n]"
;    persisting in that form for rather a long time



;To do.
;1. Loops. See how beta-expansion, and finite beta-expansion, works.
;2. Side effects.
;3. Loops with side effects. Can we still compile?
;4. xloop the way it is currently defined.
;5. Compilation and whatever crap.

;Whatever.  Just do 1 for now.

;eval-lex -> eval

(eval '((fn (f) (f f 1000 0))
        (fn (f n tt)
          (if (is n 0)
              tt
              (f f (- n 1) (+ n tt)))))
      nil)

;oh man

(withs
  p0 '((fn (f) (f f 1000 0))
        (fn (f n tt)
          (if (is n 0)
              tt
              (f f (- n 1) (+ n tt)))))
  (eval p0 nil))

;hoo boy

(withs
  p1 '(fn (f) (f f 1000 0))
  p2 '((fn (f n tt)
         (if (is n 0)
             tt
             (f f (- n 1) (+ n tt)))))
  p0 `(,p1 ,@p2)
  (eval p0 nil))

;oh man
;(oh dear there was an error on p2 before; forgot it's cdr not cadr)

(withs
  p1 '(fn (f) (f f 1000 0))
  p2 '((fn (f n tt)
        (if (is n 0)
            tt
            (f f (- n 1) (+ n tt)))))
  p0 `(,p1 ,@p2)
  (if (and (is car.p0 p1)
           (is cdr.p0 p2))
      (let u (eval p1 nil)
        (eval-call u p2 nil))))

;oh man...

(withs
  p3 'fn
  p4 '((f) (f f 1000 0))
  p1 '(fn ,@p4)
  p2 '((fn (f n tt)
        (if (is n 0)
            tt
            (f f (- n 1) (+ n tt)))))
  p0 `(,p1 ,@p2)
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4))
      (let u (let u (ueval 'fn nil)
               (ueval-call u p4 nil))
        (eval-call u p2 nil))))

;now...

(withs
  p3 'fn
  p4 '((f) (f f 1000 0))
  p1 '(fn ,@p4)
  p2 '((fn (f n tt)
        (if (is n 0)
            tt
            (f f (- n 1) (+ n tt)))))
  p0 `(,p1 ,@p2)
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object))
      (let u (let u fn-object
               (ueval-call u p4 nil))
        (eval-call u p2 nil))))

;mmm

(withs
  p3 'fn
  p4 '((f) (f f 1000 0))
  p1 '(fn ,@p4)
  p2 '((fn (f n tt)
        (if (is n 0)
            tt
            (f f (- n 1) (+ n tt)))))
  p0 `(,p1 ,@p2)
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object))
      (let u (let u fn-object
               (eval-fn p4 nil))
        (eval-call u p2 nil))))

;el droppo (felt like being slow)
(withs
  p3 'fn
  p4 '((f) (f f 1000 0))
  p1 '(fn ,@p4)
  p2 '((fn (f n tt)
        (if (is n 0)
            tt
            (f f (- n 1) (+ n tt)))))
  p0 `(,p1 ,@p2)
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object))
      (let u (eval-fn p4 nil)
        (eval-call u p2 nil))))

;and now

(withs
  p3 'fn
  p4 '((f) (f f 1000 0))
  p1 '(fn ,@p4)
  p2 '((fn (f n tt)
        (if (is n 0)
            tt
            (f f (- n 1) (+ n tt)))))
  p0 `(,p1 ,@p2)
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object))
      (let u (closure nil p4)
        (eval-call u p2 nil))))

;mmm... "closure" is sort of undefined right now
;I will treat it axiomatically.
;Undefined terms in formal mathematics.

(withs
  p3 'fn
  p4 '((f) (f f 1000 0))
  p1 '(fn ,@p4)
  p2 '((fn (f n tt)
        (if (is n 0)
            tt
            (f f (- n 1) (+ n tt)))))
  p0 `(,p1 ,@p2)
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object))
      (let u (closure nil p4)
        (apply u (map [eval _ nil] p2)))))

;Oh boy.  Now we shall see and dick...
;Definition of map used:
#;(def map (f xs)
  (if no.xs
      nil
      (let (x . rest) xs
        (cons (f x) (map f rest)))))

(withs
  p3 'fn
  p4 '((f) (f f 1000 0))
  p1 '(fn ,@p4)
  p2 '((fn (f n tt)
        (if (is n 0)
            tt
            (f f (- n 1) (+ n tt)))))
  p0 `(,p1 ,@p2)
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object))
      (let u (closure nil p4)
        (let args (map [eval _ nil] p2)
          (apply u args)))))

;Now.

(withs
  p5 '(fn (f n tt)
        (if (is n 0)
            tt
            (f f (- n 1) (+ n tt))))
  p6 'nil
  p4 '((f) (f f 1000 0))
  p1 '(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object))
      (let u (closure nil p4)
        (let args (map [eval _ nil] p2)
          (apply u args)))))

;And.

(withs
  p5 '(fn (f n tt)
        (if (is n 0)
            tt
            (f f (- n 1) (+ n tt))))
  p6 'nil
  p4 '((f) (f f 1000 0))
  p1 '(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p2 p5)
           (is cdr.p2 'nil))
      (let u (closure nil p4)
        (let args (cons (eval p5 nil)
                        (map [eval _ nil] 'nil))
          (apply u args)))))

;Now... we should be able to say, regardless of how p5 evals,
;that (map [eval _ nil] 'nil) will be nil.
;(Am I really taking the right approach here?  Getting car/cdr
; at once, as opposed to holding the cons cell and getting the
; cdr later?  Tail call elimination forces me to do that in at
; least one case.  I think it's _probably_ permissible to do
; this in general.)

(withs
  p5 '(fn (f n tt)
        (if (is n 0)
            tt
            (f f (- n 1) (+ n tt))))
  p6 'nil
  p4 '((f) (f f 1000 0))
  p1 '(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p2 p5)
           (is cdr.p2 'nil))
      (let u (closure nil p4)
        (let args (cons (eval p5 nil)
                        'nil)
          (apply u args)))))

;And now.

(withs
  p7 'fn
  p8 '((f n tt)
       (if (is n 0)
           tt
           (f f (- n 1) (+ n tt))))
  p5 `(fn ,p8)
  p4 '((f) (f f 1000 0))
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p2 p5)
           (is cdr.p2 'nil))
      (let u (closure nil p4)
        (let args (cons (eval p5 nil)
                        'nil)
          (apply u args)))))

;Mmm.

(withs
  p7 'fn
  p8 '((f n tt)
       (if (is n 0)
           tt
           (f f (- n 1) (+ n tt))))
  p5 `(fn ,p8)
  p4 '((f) (f f 1000 0))
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8))
      (let u (closure nil p4)
        (let args (cons (let u (ueval 'fn nil)
                          (ueval-call u p8 nil))
                        'nil)
          (apply u args)))))

;And... (... god... time for light and darkness)

(withs
  p7 'fn
  p8 '((f n tt)
       (if (is n 0)
           tt
           (f f (- n 1) (+ n tt))))
  p5 `(fn ,p8)
  p4 '((f) (f f 1000 0))
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object))
      (let u (closure nil p4)
        (let args (cons (let u fn-object
                          (ueval-call u p8 nil))
                        'nil)
          (apply u args)))))

;then

(withs
  p7 'fn
  p8 '((f n tt)
       (if (is n 0)
           tt
           (f f (- n 1) (+ n tt))))
  p5 `(fn ,p8)
  p4 '((f) (f f 1000 0))
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object))
      (let u (closure nil p4)
        (let args (cons (let u fn-object
                          (ueval-call fn-object p8 nil))
                        'nil)
          (apply u args)))))

;then can drop before eval-calling; permuting is permissible

(withs
  p7 'fn
  p8 '((f n tt)
       (if (is n 0)
           tt
           (f f (- n 1) (+ n tt))))
  p5 `(fn ,p8)
  p4 '((f) (f f 1000 0))
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object))
      (let u (closure nil p4)
        (let args (cons (ueval-call fn-object p8 nil)
                        'nil)
          (apply u args)))))

;then we make dick

(withs
  p7 'fn
  p8 '((f n tt)
       (if (is n 0)
           tt
           (f f (- n 1) (+ n tt))))
  p5 `(fn ,p8)
  p4 '((f) (f f 1000 0))
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object))
      (let u (closure nil p4)
        (let args (cons (closure nil p8)
                        'nil)
          (apply u args)))))

;oh man... and now...

;weh mast be loyal to zeh king.
;we will be applying a closure...

#;(withs
  p7 'fn
  p8 '((f n tt)
       (if (is n 0)
           tt
           (f f (- n 1) (+ n tt))))
  p5 `(fn ,p8)
  p4 '((f) (f f 1000 0))
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object))
      (let u (closure nil p4)
        (let args (cons (closure nil p8)
                        'nil)
          (let (env arglist . bodexprs) u
          (apply u args))))))

;Gw'oh, fuck. These closure things...
;They should have arglist and bodexprs as separate fields.
;Therefore, I should check that shit when creating a closure.


;sigh. looks like it'll be similarly difficult as before
;to say things like "yeah, this closure is generated from
; this expression".
;on the other hand... this general framework of "I can
; introduce any assumption I want as long as I check it"
;can make it possible to do genuinely "speculative" optimizations.
;like "if x < N, then this loop deals purely with fixnums" even
;if that is impossible to determine at compile-time.
;however, doing that reliably well seems a really difficult kind
;of problem. I'd rather rely on deterministic things.

(withs
  p14 '(if (is n 0)
           tt
           (f f (- n 1) (+ n tt)))
  p13 `(,p14)
  p12 '(f n tt)
  p11 '(f f 1000 0)
  p10 `(,p11)
  p9 '(f)
  p7 'fn
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let u (closure nil p9 p10)
        (let args (cons (closure nil p12 p13)
                        'nil)
          (apply u args)))))

;and we can ANF this.
(withs
  p14 '(if (is n 0)
           tt
           (f f (- n 1) (+ n tt)))
  p13 `(,p14)
  p12 '(f n tt)
  p11 '(f f 1000 0)
  p10 `(,p11)
  p9 '(f)
  p7 'fn
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ1 (closure nil p9 p10)
        (let λ2 (closure nil p12 p13)
          (let args (cons λ2 'nil)
            (apply λ1 args))))))

;ok, that looks pretty good.
;... so... hmm...
;really?  can't replace the body of a closure
;with another body?
;it kind of makes sense that fn-object acts kind of like
;a function (or a macro), so it would destructure shit at
;compile time.
;Actually, 'fn could be implemented like this:
#;(mac fn (arglist . body)
  `(make-closure-with-current-env
    ,arglist
    ,body))
;And that make-closure-with-current-env thing could be a
;primitive procedure, or it could be a very intelligent
;macro that does closure conversion and generates code that
;manipulates vectors or whatever.
;Hmm...
;Interesting... that could have implications about how I handle
;this stuff.
;Well...
;Probably such a macro would be completely side-effect-free
;and I don't need to expand it here.

;So, now.
;...
;Do I start "partially evaluating the closures"?
;I think what I would probably do is split things,
;into λ2-ex and λ2-code [e.g.], and then fuck around with λ2-code.

;It is possible that the closure-constructing procedures would
;make their own copies of function bodies.
;(That would not necessarily suffice to do butts...)
;...
;Let us assume that the arglists would become immutable,
;but the bodies would not.
;Teh properz.

(withs
  p14 '(if (is n 0)
           tt
           (f f (- n 1) (+ n tt)))
  p13 `(,p14)
  p12 '(f n tt)
  p11 '(f f 1000 0)
  p10 `(,p11)
  p9 '(f)
  p7 'fn
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ1 (closure nil p9 p10)
        (let λ2 (closure nil p12 p13)
          (let args (cons λ2 'nil)
            (apply λ1 args))))))

;Mmm, or the closure can be an Appel style closure (with compiled body)
;with compiled body that says:
;(eval <body> <env>)
;Or rather:
;(fn (x y) (eval '<body> (table 'x x 'y y 'parent '<env>)))
;The "'<env>" is kind of a misnomer or something...
;It'll be stored somewhere, for sure.
;--Oh, duh.
;(fn (env x y) (eval '<body> (table 'x x 'y y 'parent env)))
;And that's λ. λ-ex would be (fn (env x y) ...) ... hmm, whatever.

;Hmm...
;About correctness...
;If someone else modifies one of the things we check halfway through
;our checklist, then it is permissible for us to go all the way back
;to the beginning, rather than continuing directly from where we
;left off.
;This is because no other thread is, according to protocol, able to
;tell that we had been checking these things.
;This is because we are not performing any side effects, except for
;moving objects that we touch (in real-time GC) and possibly allocating
;memory, neither of which is a thing that, according to protocol,
;other threads should depend on as an indicator.
;I have commented on this before.

;K, so.
;This is kind of el baddo, because I didn't do this before, but...
;--No, I think I'll... hmm...
;--No, too much duplication.
;--Could use some ccc crap.  Eh.  Fuck.
;--Ok, duplication for this step.
;... And damn, it looks like the way I'm doing it,
;I'll be checking the whole arglist...

(withs
  p14 '(if (is n 0)
           tt
           (f f (- n 1) (+ n tt)))
  p13 `(,p14)
  p12 '(f n tt)
  p11 '(f f 1000 0)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ1-code (fn (ev1 f1)
            (let ev2 (table 'f f1 'parent ev1) ;should that go in ex?
              (eval-progn p10 ev2)))       ;whatever
  λ1-ex (fn (ev1 f1)
          (λ1-code ev1 f1))
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (eval-progn p13 ev4)))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10))
      (let λ1 (list 'closure λ1-code nil)
        (if (and (is car.p2 p5)
                 (is cdr.p2 'nil)
                 (is car.p5 'fn)
                 (is cdr.p5 p8)
                 (is (symbol-value 'fn) fn-object)
                 (is car.p8 p12)
                 (is cdr.p8 p13))
            (let λ2 (list 'closure λ2-code nil)
              (let args (cons λ2 'nil)
                (apply λ1 args)))
            (eval p0 nil)))
      (eval p0 nil)))

;Mmm, hmm...
;So...
;I can most certainly beta-contract the "apply λ1".
;I don't know if I know that yet, though.
;... Yes.  λ1 is completely not, um... hmm...
;λ1 is mentioned in a single place in this code,
;and it is not bound in an env.
;Therefore it should be a contraction.
;... Meanwhile, I can certainly work on pre-eval'ing the λ1-code
;and λ2-code.

(withs
  p14 '(if (is n 0)
           tt
           (f f (- n 1) (+ n tt)))
  p13 `(,p14)
  p12 '(f n tt)
  p11 '(f f 1000 0)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ1-code (fn (ev1 f1)
            (let ev2 (table 'f f1 'parent ev1)
              (if (and (is cdr.p10 'nil)
                       (is car.p10 p11))
                  (eval p11 ev2)
                  (eval-progn p10 ev2))))
  λ1-ex (fn (ev1 f1)
          (λ1-code ev1 f1))
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14))
                  (eval p14 ev4)
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10))
      (let λ1 (list 'closure λ1-code nil)
        (if (and (is car.p2 p5)
                 (is cdr.p2 'nil)
                 (is car.p5 'fn)
                 (is cdr.p5 p8)
                 (is (symbol-value 'fn) fn-object)
                 (is car.p8 p12)
                 (is cdr.p8 p13))
            (let λ2 (list 'closure λ2-code nil)
              (let args (cons λ2 'nil)
                (apply λ1 args)))
            (eval p0 nil)))
      (eval p0 nil)))

;oh boy. fuck.
;well, here goes nothing...

(withs
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 '(if (is n 0)
           tt
           (f f (- n 1) (+ n tt)))
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ1-code (fn (ev1 f1)
            (let ev2 (table 'f f1 'parent ev1)
              (if (and (is cdr.p10 'nil)
                       (is car.p10 p11))
                  (eval p11 ev2)
                  (eval-progn p10 ev2))))
  λ1-ex (fn (ev1 f1)
          (λ1-code ev1 f1))
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14))
                  (eval p14 ev4)
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10))
      (let λ1 (list 'closure λ1-code nil)
        (if (and (is car.p2 p5)
                 (is cdr.p2 'nil)
                 (is car.p5 'fn)
                 (is cdr.p5 p8)
                 (is (symbol-value 'fn) fn-object)
                 (is car.p8 p12)
                 (is cdr.p8 p13))
            (let λ2 (list 'closure λ2-code nil)
              (let args (cons λ2 'nil)
                (apply λ1 args)))
            (eval p0 nil)))
      (eval p0 nil)))

;and then

(withs
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 '(if (is n 0)
           tt
           (f f (- n 1) (+ n tt)))
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ1-code (fn (ev1 f1)
            (let ev2 (table 'f f1 'parent ev1)
              (if (and (is cdr.p10 'nil)
                       (is car.p10 p11)
                       (is car.p11 'f)
                       (is cdr.p11 p15))
                  (let u (eval 'f ev2)
                    (eval-call u p15 ev2))
                  (eval-progn p10 ev2))))
  λ1-ex (fn (ev1 f1)
          (λ1-code ev1 f1))
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14))
                  (eval p14 ev4)
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10))
      (let λ1 (list 'closure λ1-code nil)
        (if (and (is car.p2 p5)
                 (is cdr.p2 'nil)
                 (is car.p5 'fn)
                 (is cdr.p5 p8)
                 (is (symbol-value 'fn) fn-object)
                 (is car.p8 p12)
                 (is cdr.p8 p13))
            (let λ2 (list 'closure λ2-code nil)
              (let args (cons λ2 'nil)
                (apply λ1 args)))
            (eval p0 nil)))
      (eval p0 nil)))

;and then (phew, slightly)

(withs
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 '(if (is n 0)
           tt
           (f f (- n 1) (+ n tt)))
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ1-code (fn (ev1 f1)
            (let ev2 (table 'f f1 'parent ev1)
              (if (and (is cdr.p10 'nil)
                       (is car.p10 p11)
                       (is car.p11 'f)
                       (is cdr.p11 p15))
                  (eval-call f1 p15 ev2)
                  (eval-progn p10 ev2))))
  λ1-ex (fn (ev1 f1)
          (λ1-code ev1 f1))
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14))
                  (eval p14 ev4)
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10))
      (let λ1 (list 'closure λ1-code nil)
        (if (and (is car.p2 p5)
                 (is cdr.p2 'nil)
                 (is car.p5 'fn)
                 (is cdr.p5 p8)
                 (is (symbol-value 'fn) fn-object)
                 (is car.p8 p12)
                 (is cdr.p8 p13))
            (let λ2 (list 'closure λ2-code nil)
              (let args (cons λ2 'nil)
                (apply λ1 args)))
            (eval p0 nil)))
      (eval p0 nil)))

;and now... it is conceivable that we could inline the "eval-call"
;and speculatively inline the "if is not a special thing" part
;and say (if (isnt f a macro or a dick or wtvr) (nice-code) (eval)).
;would rather not rely on that shit.

;anyway, we should be able to basically beta-contract λ1.
;this by inlining "apply".
;...
;now that we're using λ1-code,
;inlining the "apply" actually just means...
;substituting in like this.

(withs
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 '(if (is n 0)
           tt
           (f f (- n 1) (+ n tt)))
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ1-code (fn (ev1 f1)
            (let ev2 (table 'f f1 'parent ev1)
              (if (and (is cdr.p10 'nil)
                       (is car.p10 p11)
                       (is car.p11 'f)
                       (is cdr.p11 p15))
                  (eval-call f1 p15 ev2)
                  (eval-progn p10 ev2))))
  λ1-ex (fn (ev1 f1)
          (λ1-code ev1 f1))
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14))
                  (eval p14 ev4)
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10))
      (let λ1 (list 'closure λ1-code nil)
        (if (and (is car.p2 p5)
                 (is cdr.p2 'nil)
                 (is car.p5 'fn)
                 (is cdr.p5 p8)
                 (is (symbol-value 'fn) fn-object)
                 (is car.p8 p12)
                 (is cdr.p8 p13))
            (let λ2 (list 'closure λ2-code nil)
              (let args (cons λ2 'nil)
                (apply λ1.1 λ1.2 args)))
            (eval p0 nil)))
      (eval p0 nil)))

;Which means.
;(Being a little glib about different kinds of "apply"...)

(withs
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 '(if (is n 0)
           tt
           (f f (- n 1) (+ n tt)))
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ1-code (fn (ev1 f1)
            (let ev2 (table 'f f1 'parent ev1)
              (if (and (is cdr.p10 'nil)
                       (is car.p10 p11)
                       (is car.p11 'f)
                       (is cdr.p11 p15))
                  (eval-call f1 p15 ev2)
                  (eval-progn p10 ev2))))
  λ1-ex (fn (ev1 f1)
          (λ1-code ev1 f1))
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14))
                  (eval p14 ev4)
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10))
      (let λ1 (list 'closure λ1-code nil)
        (if (and (is car.p2 p5)
                 (is cdr.p2 'nil)
                 (is car.p5 'fn)
                 (is cdr.p5 p8)
                 (is (symbol-value 'fn) fn-object)
                 (is car.p8 p12)
                 (is cdr.p8 p13))
            (let λ2 (list 'closure λ2-code nil)
              (let args (cons λ2 'nil)
                (apply λ1-code nil args)))
            (eval p0 nil)))
      (eval p0 nil)))

;Then we can be like dick.

(withs
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 '(if (is n 0)
           tt
           (f f (- n 1) (+ n tt)))
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ1-code (fn (ev1 f1)
            (let ev2 (table 'f f1 'parent ev1)
              (if (and (is cdr.p10 'nil)
                       (is car.p10 p11)
                       (is car.p11 'f)
                       (is cdr.p11 p15))
                  (eval-call f1 p15 ev2)
                  (eval-progn p10 ev2))))
  λ1-ex (fn (ev1 f1)
          (λ1-code ev1 f1))
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14))
                  (eval p14 ev4)
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10))
      (let λ1 (list 'closure λ1-code nil)
        (if (and (is car.p2 p5)
                 (is cdr.p2 'nil)
                 (is car.p5 'fn)
                 (is cdr.p5 p8)
                 (is (symbol-value 'fn) fn-object)
                 (is car.p8 p12)
                 (is cdr.p8 p13))
            (let λ2 (list 'closure λ2-code nil)
              (let args (cons λ2 'nil)
                (apply λ1-code nil λ2 'nil)))
            (eval p0 nil)))
      (eval p0 nil)))

;And drop ass.

(withs
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 '(if (is n 0)
           tt
           (f f (- n 1) (+ n tt)))
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ1-code (fn (ev1 f1)
            (let ev2 (table 'f f1 'parent ev1)
              (if (and (is cdr.p10 'nil)
                       (is car.p10 p11)
                       (is car.p11 'f)
                       (is cdr.p11 p15))
                  (eval-call f1 p15 ev2)
                  (eval-progn p10 ev2))))
  λ1-ex (fn (ev1 f1)
          (λ1-code ev1 f1))
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14))
                  (eval p14 ev4)
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10))
      (let λ1 (list 'closure λ1-code nil)
        (if (and (is car.p2 p5)
                 (is cdr.p2 'nil)
                 (is car.p5 'fn)
                 (is cdr.p5 p8)
                 (is (symbol-value 'fn) fn-object)
                 (is car.p8 p12)
                 (is cdr.p8 p13))
            (let λ2 (list 'closure λ2-code nil)
              (apply λ1-code nil λ2 'nil))
            (eval p0 nil)))
      (eval p0 nil)))

;Also (apply ... 'nil) = (...).

(withs
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 '(if (is n 0)
           tt
           (f f (- n 1) (+ n tt)))
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ1-code (fn (ev1 f1)
            (let ev2 (table 'f f1 'parent ev1)
              (if (and (is cdr.p10 'nil)
                       (is car.p10 p11)
                       (is car.p11 'f)
                       (is cdr.p11 p15))
                  (eval-call f1 p15 ev2)
                  (eval-progn p10 ev2))))
  λ1-ex (fn (ev1 f1)
          (λ1-code ev1 f1))
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14))
                  (eval p14 ev4)
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10))
      (let λ1 (list 'closure λ1-code nil)
        (if (and (is car.p2 p5)
                 (is cdr.p2 'nil)
                 (is car.p5 'fn)
                 (is cdr.p5 p8)
                 (is (symbol-value 'fn) fn-object)
                 (is car.p8 p12)
                 (is cdr.p8 p13))
            (let λ2 (list 'closure λ2-code nil)
              (λ1-code nil λ2))
            (eval p0 nil)))
      (eval p0 nil)))

;And now we can inline ... oh, dammit, all those closures
;should refer to λ-ex. Oh well.  Can fix. Anyway, inline λ1-ex.

(withs
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 '(if (is n 0)
           tt
           (f f (- n 1) (+ n tt)))
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ1-code (fn (ev1 f1)
            (let ev2 (table 'f f1 'parent ev1)
              (if (and (is cdr.p10 'nil)
                       (is car.p10 p11)
                       (is car.p11 'f)
                       (is cdr.p11 p15))
                  (eval-call f1 p15 ev2)
                  (eval-progn p10 ev2))))
  λ1-ex (fn (ev1 f1)
          (λ1-code ev1 f1))
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14))
                  (eval p14 ev4)
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10))
      (let λ1 (list 'closure λ1-ex nil)
        (if (and (is car.p2 p5)
                 (is cdr.p2 'nil)
                 (is car.p5 'fn)
                 (is cdr.p5 p8)
                 (is (symbol-value 'fn) fn-object)
                 (is car.p8 p12)
                 (is cdr.p8 p13))
            (let λ2 (list 'closure λ2-ex nil)
              (λ1-code nil λ2))
            (eval p0 nil)))
      (eval p0 nil)))

;And oh man we can drop λ1 now.

(withs
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 '(if (is n 0)
           tt
           (f f (- n 1) (+ n tt)))
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ1-code (fn (ev1 f1)
            (let ev2 (table 'f f1 'parent ev1)
              (if (and (is cdr.p10 'nil)
                       (is car.p10 p11)
                       (is car.p11 'f)
                       (is cdr.p11 p15))
                  (eval-call f1 p15 ev2)
                  (eval-progn p10 ev2))))
  λ1-ex (fn (ev1 f1)
          (λ1-code ev1 f1))
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14))
                  (eval p14 ev4)
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10))
      (if (and (is car.p2 p5)
                 (is cdr.p2 'nil)
                 (is car.p5 'fn)
                 (is cdr.p5 p8)
                 (is (symbol-value 'fn) fn-object)
                 (is car.p8 p12)
                 (is cdr.p8 p13))
            (let λ2 (list 'closure λ2-ex nil)
              (λ1-code nil λ2))
            (eval p0 nil))
      (eval p0 nil)))

;And now this redundant "eval p0 nil" thing.  Combine the ifs.
;(Should have been combinable before, if I'm fine about a thing
; mallocing before it discovers its cheese has been moved.)

(withs
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 '(if (is n 0)
           tt
           (f f (- n 1) (+ n tt)))
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ1-code (fn (ev1 f1)
            (let ev2 (table 'f f1 'parent ev1)
              (if (and (is cdr.p10 'nil)
                       (is car.p10 p11)
                       (is car.p11 'f)
                       (is cdr.p11 p15))
                  (eval-call f1 p15 ev2)
                  (eval-progn p10 ev2))))
  λ1-ex (fn (ev1 f1)
          (λ1-code ev1 f1))
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14))
                  (eval p14 ev4)
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (λ1-code nil λ2))
      (eval p0 nil)))

;Ok, now we can drop λ1-ex, and we can basically beta-contract
;λ1-code.

(withs
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 '(if (is n 0)
           tt
           (f f (- n 1) (+ n tt)))
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14))
                  (eval p14 ev4)
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (bind (ev1 f1) (nil λ2)
          (let ev2 (table 'f f1 'parent ev1)
            (if (and (is cdr.p10 'nil)
                     (is car.p10 p11)
                     (is car.p11 'f)
                     (is cdr.p11 p15))
                (eval-call f1 p15 ev2)
                (eval-progn p10 ev2)))))
      (eval p0 nil)))

;Now we use earlier bindings...

(withs
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 '(if (is n 0)
           tt
           (f f (- n 1) (+ n tt)))
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14))
                  (eval p14 ev4)
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (bind (ev1 f1) (nil λ2)
          (let ev2 (table 'f λ2 'parent nil)
            (if (and (is cdr.p10 'nil)
                     (is car.p10 p11)
                     (is car.p11 'f)
                     (is cdr.p11 p15))
                (eval-call λ2 p15 ev2)
                (eval-progn p10 ev2)))))
      (eval p0 nil)))

;And now we can drop the bindings of ev1 and f1, and also
;drop "'parent nil".

(withs
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 '(if (is n 0)
           tt
           (f f (- n 1) (+ n tt)))
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14))
                  (eval p14 ev4)
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (and (is cdr.p10 'nil)
                   (is car.p10 p11)
                   (is car.p11 'f)
                   (is cdr.p11 p15))
              (eval-call λ2 p15 ev2)
              (eval-progn p10 ev2))))
      (eval p0 nil)))

;Ok, so, now...
;It would be nice to justify turning that "if" thing whose else
;clause is "eval-progn p10 ev2" into just "eval p0 nil".
;It is conceivable that I'd be able to do that in general...
;Specially tag the if-crap and the oh-well crap.
;But neh.
;Anyway... two ways to proceed. eval-call λ2, and eval p14.
;I kinda like the first, I guess.
;It'll probably make progress without requiring more checks or crap.

(withs
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 '(if (is n 0)
           tt
           (f f (- n 1) (+ n tt)))
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14))
                  (eval p14 ev4)
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (and (is cdr.p10 'nil)
                   (is car.p10 p11)
                   (is car.p11 'f)
                   (is cdr.p11 p15))
              (apply λ2 (map-eval p15 ev2))
              (eval-progn p10 ev2))))
      (eval p0 nil)))

;Or maybe not.  Hmmph.  Terrible dicks...
;Well, time for λ2-code's p14.

(withs
  p22 '(f f (- n 1) (+ n tt))
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 '(is n 0)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14)
                       (is car.p14 'if)
                       (is cdr.p14 p18))
                  (let u (eval 'if ev4)
                    (eval-call u p18 ev4))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (and (is cdr.p10 'nil)
                   (is car.p10 p11)
                   (is car.p11 'f)
                   (is cdr.p11 p15))
              (apply λ2 (map-eval p15 ev2))
              (eval-progn p10 ev2))))
      (eval p0 nil)))

;And then we can do that part...

(withs
  p22 '(f f (- n 1) (+ n tt))
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 '(is n 0)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14)
                       (is car.p14 'if)
                       (is cdr.p14 p18))
                  (eval-call if-object p18 ev4)
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (and (is cdr.p10 'nil)
                   (is car.p10 p11)
                   (is car.p11 'f)
                   (is cdr.p11 p15))
              (apply λ2 (map-eval p15 ev2))
              (eval-progn p10 ev2))))
      (eval p0 nil)))

;Then this.

(withs
  p22 '(f f (- n 1) (+ n tt))
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 '(is n 0)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14)
                       (is car.p14 'if)
                       (is cdr.p14 p18))
                  (eval-if p18 ev4)
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (and (is cdr.p10 'nil)
                   (is car.p10 p11)
                   (is car.p11 'f)
                   (is cdr.p11 p15))
              (apply λ2 (map-eval p15 ev2))
              (eval-progn p10 ev2))))
      (eval p0 nil)))

;And then ohmgaw.  We will have interleaved things.

(withs
  p22 '(f f (- n 1) (+ n tt))
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 '(is n 0)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14)
                       (is car.p14 'if)
                       (is cdr.p14 p18))
                  (let (a . axs) p18
                    (if no.axs
                        (eval a ev4)
                        (eval a ev4)
                        (eval car.axs ev4)
                        (eval cdr.axs ev4)))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (and (is cdr.p10 'nil)
                   (is car.p10 p11)
                   (is car.p11 'f)
                   (is cdr.p11 p15))
              (apply λ2 (map-eval p15 ev2))
              (eval-progn p10 ev2))))
      (eval p0 nil)))

;Just because it's a little easier to do it in that way.

(withs
  p22 '(f f (- n 1) (+ n tt))
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 '(is n 0)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14)
                       (is car.p14 'if)
                       (is cdr.p14 p18)
                       (is car.p18 p19)
                       (is cdr.p18 p20))
                  (if no.p20
                      (eval p19 ev4)
                      (eval p19 ev4)
                      (eval car.p20 ev4)
                      (eval cdr.p20 ev4))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (and (is cdr.p10 'nil)
                   (is car.p10 p11)
                   (is car.p11 'f)
                   (is cdr.p11 p15))
              (apply λ2 (map-eval p15 ev2))
              (eval-progn p10 ev2))))
      (eval p0 nil)))

;Then we know at compile time that p20 is not nil.
;Then... we figure out dick...
;We will not be able to...
;Well, we can immediately replace "car.p20"
;with "(if (is car.p20 'tt) 'tt car.p20)", but only really useful
;when we can bring that into the main checklist.

(withs
  p24 '(0)
  p23 `(n ,@p24)
  p22 '(f f (- n 1) (+ n tt))
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14)
                       (is car.p14 'if)
                       (is cdr.p14 p18)
                       (is car.p18 p19)
                       (is cdr.p18 p20))
                  (if (eval p19 ev4)
                      (eval car.p20 ev4)
                      (eval cdr.p20 ev4))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (and (is cdr.p10 'nil)
                   (is car.p10 p11)
                   (is car.p11 'f)
                   (is cdr.p11 p15))
              (apply λ2 (map-eval p15 ev2))
              (eval-progn p10 ev2))))
      (eval p0 nil)))

;Now...
;Oh, god, I had forgotten a couple of things.
;Need to check (symbol-value 'if) to get if-object.
;Also, need to verify that 'if is not rebound in ev4.
;That may be a bit difficult to do and to justify or smthg...
;Hmm... Feh.

(withs
  p24 '(0)
  p23 `(n ,@p24)
  p22 '(f f (- n 1) (+ n tt))
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14)
                       (is car.p14 'if)
                       (not-in 'if ev4)
                       (is (symbol-value 'if) if-object)
                       (is cdr.p14 p18)
                       (is car.p18 p19)
                       (is cdr.p18 p20))
                  (if (eval p19 ev4)
                      (eval car.p20 ev4)
                      (eval cdr.p20 ev4))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (and (is cdr.p10 'nil)
                   (is car.p10 p11)
                   (is car.p11 'f)
                   (is cdr.p11 p15))
              (apply λ2 (map-eval p15 ev2))
              (eval-progn p10 ev2))))
      (eval p0 nil)))

;Well, that's better... [hah] [but srsly] Now we eval p19.

(withs
  p24 '(0)
  p23 `(n ,@p24)
  p22 '(f f (- n 1) (+ n tt))
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14)
                       (is car.p14 'if)
                       (is cdr.p14 p18)
                       (not-in 'if ev4) ;accually correct order
                       (is (symbol-value 'if) if-object)
                       (is car.p18 p19)
                       (is cdr.p18 p20)
                       (is car.p19 'is)
                       (is cdr.p19 p23))
                  (if (eval-call (eval 'is ev4)
                                 p23 ev4)
                      (eval car.p20 ev4)
                      (eval cdr.p20 ev4))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (and (is cdr.p10 'nil)
                   (is car.p10 p11)
                   (is car.p11 'f)
                   (is cdr.p11 p15))
              (apply λ2 (map-eval p15 ev2))
              (eval-progn p10 ev2))))
      (eval p0 nil)))

;Now we look up dicks... oh and we can at least reduce the "not-in"
;thing to looking in ev3, because we can see the fringe in ev4.

(withs
  p24 '(0)
  p23 `(n ,@p24)
  p22 '(f f (- n 1) (+ n tt))
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14)
                       (is car.p14 'if)
                       (is cdr.p14 p18)
                       (not-in 'if ev3)
                       (is (symbol-value 'if) if-object)
                       (is car.p18 p19)
                       (is cdr.p18 p20)
                       (is car.p19 'is)
                       (is cdr.p19 p23)
                       (not-in 'is ev4)
                       (is (symbol-value 'is) is-function))
                  (if (eval-call is-function
                                 p23 ev4)
                      (eval car.p20 ev4)
                      (eval cdr.p20 ev4))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (and (is cdr.p10 'nil)
                   (is car.p10 p11)
                   (is car.p11 'f)
                   (is cdr.p11 p15))
              (apply λ2 (map-eval p15 ev2))
              (eval-progn p10 ev2))))
      (eval p0 nil)))

;ok, now...
;is-function is a system-func.
;also, later, we'll use the fact that it is side effect free.
;(probably use that.)

(withs
  p24 '(0)
  p23 `(n ,@p24)
  p22 '(f f (- n 1) (+ n tt))
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14)
                       (is car.p14 'if)
                       (is cdr.p14 p18)
                       (not-in 'if ev3)
                       (is (symbol-value 'if) if-object)
                       (is car.p18 p19)
                       (is cdr.p18 p20)
                       (is car.p19 'is)
                       (is cdr.p19 p23)
                       (not-in 'is ev4)
                       (is (symbol-value 'is) is-function))
                  (if (apply is-function
                             (map-eval p23 ev4))
                      (eval car.p20 ev4)
                      (eval cdr.p20 ev4))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (and (is cdr.p10 'nil)
                   (is car.p10 p11)
                   (is car.p11 'f)
                   (is cdr.p11 p15))
              (apply λ2 (map-eval p15 ev2))
              (eval-progn p10 ev2))))
      (eval p0 nil)))

;now we reduce the map-eval p23...
;we can imagine increasing the scope of the result of that map-eval expr.
;then we'd get some dicks...

(withs
  p24 '(0)
  p23 `(n ,@p24)
  p22 '(f f (- n 1) (+ n tt))
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14)
                       (is car.p14 'if)
                       (is cdr.p14 p18)
                       (not-in 'if ev3)
                       (is (symbol-value 'if) if-object)
                       (is car.p18 p19)
                       (is cdr.p18 p20)
                       (is car.p19 'is)
                       (is cdr.p19 p23)
                       (not-in 'is ev4)
                       (is (symbol-value 'is) is-function)
                       (is cdr.p23 p24)
                       (is car.p23 'n))
                  (if (apply is-function
                             (cons (eval 'n ev4)
                                   (map-eval p24 ev4)))
                      (eval car.p20 ev4)
                      (eval cdr.p20 ev4))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (and (is cdr.p10 'nil)
                   (is car.p10 p11)
                   (is car.p11 'f)
                   (is cdr.p11 p15))
              (apply λ2 (map-eval p15 ev2))
              (eval-progn p10 ev2))))
      (eval p0 nil)))

;see, now we can imm. put p24 rather than cdr.p23.
;now... evaling 'n will not do side effects, as we will find out now.

(withs
  p24 '(0)
  p23 `(n ,@p24)
  p22 '(f f (- n 1) (+ n tt))
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14)
                       (is car.p14 'if)
                       (is cdr.p14 p18)
                       (not-in 'if ev3)
                       (is (symbol-value 'if) if-object)
                       (is car.p18 p19)
                       (is cdr.p18 p20)
                       (is car.p19 'is)
                       (is cdr.p19 p23)
                       (not-in 'is ev4)
                       (is (symbol-value 'is) is-function)
                       (is cdr.p23 p24)
                       (is car.p23 'n))
                  (if (apply is-function
                             (cons n1
                                   (map-eval p24 ev4)))
                      (eval car.p20 ev4)
                      (eval cdr.p20 ev4))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (and (is cdr.p10 'nil)
                   (is car.p10 p11)
                   (is car.p11 'f)
                   (is cdr.p11 p15))
              (apply λ2 (map-eval p15 ev2))
              (eval-progn p10 ev2))))
      (eval p0 nil)))

;so now we decomp. p24.
;incidentally, in this case we really should be asking
;for the car before the cdr.
;changing.

(withs
  p24 '(0)
  p23 `(n ,@p24)
  p22 '(f f (- n 1) (+ n tt))
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14)
                       (is car.p14 'if)
                       (is cdr.p14 p18)
                       (not-in 'if ev3)
                       (is (symbol-value 'if) if-object)
                       (is car.p18 p19)
                       (is cdr.p18 p20)
                       (is car.p19 'is)
                       (is cdr.p19 p23)
                       (not-in 'is ev4)
                       (is (symbol-value 'is) is-function)
                       (is car.p23 p24)
                       (is cdr.p23 'n)
                       (is car.p24 '0)
                       (is cdr.p24 'nil))
                  (if (apply is-function
                             (cons n1
                                   (cons (eval '0 ev4)
                                         (map-eval 'nil ev4))))
                      (eval car.p20 ev4)
                      (eval cdr.p20 ev4))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (and (is cdr.p10 'nil)
                   (is car.p10 p11)
                   (is car.p11 'f)
                   (is cdr.p11 p15))
              (apply λ2 (map-eval p15 ev2))
              (eval-progn p10 ev2))))
      (eval p0 nil)))

;And now we get some crap...

(withs
  p24 '(0)
  p23 `(n ,@p24)
  p22 '(f f (- n 1) (+ n tt))
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14)
                       (is car.p14 'if)
                       (is cdr.p14 p18)
                       (not-in 'if ev3)
                       (is (symbol-value 'if) if-object)
                       (is car.p18 p19)
                       (is cdr.p18 p20)
                       (is car.p19 'is)
                       (is cdr.p19 p23)
                       (not-in 'is ev4)
                       (is (symbol-value 'is) is-function)
                       (is car.p23 p24)
                       (is cdr.p23 'n)
                       (is car.p24 '0)
                       (is cdr.p24 'nil))
                  (if (apply is-function
                             (cons n1
                                   (cons '0
                                         'nil)))
                      (eval car.p20 ev4)
                      (eval cdr.p20 ev4))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (and (is cdr.p10 'nil)
                   (is car.p10 p11)
                   (is car.p11 'f)
                   (is cdr.p11 p15))
              (apply λ2 (map-eval p15 ev2))
              (eval-progn p10 ev2))))
      (eval p0 nil)))

;And we can reduce that apply right down.

(withs
  p24 '(0)
  p23 `(n ,@p24)
  p22 '(f f (- n 1) (+ n tt))
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14)
                       (is car.p14 'if)
                       (is cdr.p14 p18)
                       (not-in 'if ev3)
                       (is (symbol-value 'if) if-object)
                       (is car.p18 p19)
                       (is cdr.p18 p20)
                       (is car.p19 'is)
                       (is cdr.p19 p23)
                       (not-in 'is ev4)
                       (is (symbol-value 'is) is-function)
                       (is car.p23 p24)
                       (is cdr.p23 'n)
                       (is car.p24 '0)
                       (is cdr.p24 'nil))
                  (if (apply is-function
                             n1
                             (cons '0
                                   'nil))
                      (eval car.p20 ev4)
                      (eval cdr.p20 ev4))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (and (is cdr.p10 'nil)
                   (is car.p10 p11)
                   (is car.p11 'f)
                   (is cdr.p11 p15))
              (apply λ2 (map-eval p15 ev2))
              (eval-progn p10 ev2))))
      (eval p0 nil)))

;And again.  Heh heh...

(withs
  p24 '(0)
  p23 `(n ,@p24)
  p22 '(f f (- n 1) (+ n tt))
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14)
                       (is car.p14 'if)
                       (is cdr.p14 p18)
                       (not-in 'if ev3)
                       (is (symbol-value 'if) if-object)
                       (is car.p18 p19)
                       (is cdr.p18 p20)
                       (is car.p19 'is)
                       (is cdr.p19 p23)
                       (not-in 'is ev4)
                       (is (symbol-value 'is) is-function)
                       (is car.p23 p24)
                       (is cdr.p23 'n)
                       (is car.p24 '0)
                       (is cdr.p24 'nil))
                  (if (apply is-function
                             n1
                             '0
                             'nil)
                      (eval car.p20 ev4)
                      (eval cdr.p20 ev4))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (and (is cdr.p10 'nil)
                   (is car.p10 p11)
                   (is car.p11 'f)
                   (is cdr.p11 p15))
              (apply λ2 (map-eval p15 ev2))
              (eval-progn p10 ev2))))
      (eval p0 nil)))

;I am simultaneously dropping an implicit binding of the cons
;and reaching back for parts of the cons.
;Mmmph.

(withs
  p24 '(0)
  p23 `(n ,@p24)
  p22 '(f f (- n 1) (+ n tt))
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14)
                       (is car.p14 'if)
                       (is cdr.p14 p18)
                       (not-in 'if ev3)
                       (is (symbol-value 'if) if-object)
                       (is car.p18 p19)
                       (is cdr.p18 p20)
                       (is car.p19 'is)
                       (is cdr.p19 p23)
                       (not-in 'is ev4)
                       (is (symbol-value 'is) is-function)
                       (is car.p23 p24)
                       (is cdr.p23 'n)
                       (is car.p24 '0)
                       (is cdr.p24 'nil))
                  (if (is-function n1 '0)
                      (eval car.p20 ev4)
                      (eval cdr.p20 ev4))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (and (is cdr.p10 'nil)
                   (is car.p10 p11)
                   (is car.p11 'f)
                   (is cdr.p11 p15))
              (apply λ2 (map-eval p15 ev2))
              (eval-progn p10 ev2))))
      (eval p0 nil)))

;Now we find out that "(is-function n1 '0)" will not cause side effects,
;and so any implicit "(if ... <compiled> (eval car.p20 ev4))"
;can have its if-crap merged into the top of λ2-code.
;That should not be necessary, though, and I should be able to work
;without it.
;Oh turns out I should have been saying "eval-if cdr.p20".
;Btw the branches of the if are independent, so even if
;"eval car.p20" turns out to screw with cdr.p20, that is
;not a problem.
;...
;Hmm...
;Actually, hoisting more comparisons before the if is kind of
;a pessimization.
;Will avoid.

(withs
  p24 '(0)
  p23 `(n ,@p24)
  p22 '(f f (- n 1) (+ n tt))
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14)
                       (is car.p14 'if)
                       (is cdr.p14 p18)
                       (not-in 'if ev3)
                       (is (symbol-value 'if) if-object)
                       (is car.p18 p19)
                       (is cdr.p18 p20)
                       (is car.p19 'is)
                       (is cdr.p19 p23)
                       (not-in 'is ev4)
                       (is (symbol-value 'is) is-function)
                       (is car.p23 p24)
                       (is cdr.p23 'n)
                       (is car.p24 '0)
                       (is cdr.p24 'nil))
                  (if (is-function n1 '0)
                      (if (is car.p20 'tt)
                          (eval 'tt ev4)
                          (eval car.p20 ev4))
                      (if (is cdr.p20 p21)
                          (eval-if p21 ev4)
                          (eval-if cdr.p20 ev4)))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (and (is cdr.p10 'nil)
                   (is car.p10 p11)
                   (is car.p11 'f)
                   (is cdr.p11 p15))
              (apply λ2 (map-eval p15 ev2))
              (eval-progn p10 ev2))))
      (eval p0 nil)))

;Sigh, this sucks terribly...

(withs
  p24 '(0)
  p23 `(n ,@p24)
  p22 '(f f (- n 1) (+ n tt))
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14)
                       (is car.p14 'if)
                       (is cdr.p14 p18)
                       (not-in 'if ev3)
                       (is (symbol-value 'if) if-object)
                       (is car.p18 p19)
                       (is cdr.p18 p20)
                       (is car.p19 'is)
                       (is cdr.p19 p23)
                       (not-in 'is ev4)
                       (is (symbol-value 'is) is-function)
                       (is car.p23 p24)
                       (is cdr.p23 'n)
                       (is car.p24 '0)
                       (is cdr.p24 'nil))
                  (if (is-function n1 '0)
                      (if (is car.p20 'tt)
                          tt1
                          (eval car.p20 ev4))
                      (if (and (is cdr.p20 p21)
                               (is car.p21 p22)
                               (is cdr.p21 'nil))
                          (eval p22 ev4)
                          (eval-if cdr.p20 ev4)))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (and (is cdr.p10 'nil)
                   (is car.p10 p11)
                   (is car.p11 'f)
                   (is cdr.p11 p15))
              (apply λ2 (map-eval p15 ev2))
              (eval-progn p10 ev2))))
      (eval p0 nil)))

;Awmgaw.  p22 now.

(withs
  p29 '(+ n tt)
  p28 `(,p29)
  p27 '(- n 1)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14)
                       (is car.p14 'if)
                       (is cdr.p14 p18)
                       (not-in 'if ev3)
                       (is (symbol-value 'if) if-object)
                       (is car.p18 p19)
                       (is cdr.p18 p20)
                       (is car.p19 'is)
                       (is cdr.p19 p23)
                       (not-in 'is ev4)
                       (is (symbol-value 'is) is-function)
                       (is car.p23 p24)
                       (is cdr.p23 'n)
                       (is car.p24 '0)
                       (is cdr.p24 'nil))
                  (if (is-function n1 '0)
                      (if (is car.p20 'tt)
                          tt1
                          (eval car.p20 ev4))
                      (if (and (is cdr.p20 p21)
                               (is car.p21 p22)
                               (is cdr.p21 'nil)
                               (is car.p22 'f)
                               (is cdr.p22 p25))
                          (eval-call (eval 'f ev4)
                                     p25 ev4)
                          (eval-if cdr.p20 ev4)))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (and (is cdr.p10 'nil)
                   (is car.p10 p11)
                   (is car.p11 'f)
                   (is cdr.p11 p15))
              (apply λ2 (map-eval p15 ev2))
              (eval-progn p10 ev2))))
      (eval p0 nil)))

;I may need drastic measures to save vertical space or smthg...
;(oh and fix up "not-in 'is ev4")

(withs
  p29 '(+ n tt)
  p28 `(,p29)
  p27 '(- n 1)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14)
                       (is car.p14 'if)
                       (is cdr.p14 p18)
                       (not-in 'if ev3)
                       (is (symbol-value 'if) if-object)
                       (is car.p18 p19)
                       (is cdr.p18 p20)
                       (is car.p19 'is)
                       (is cdr.p19 p23)
                       (not-in 'is ev3)
                       (is (symbol-value 'is) is-function)
                       (is car.p23 p24)
                       (is cdr.p23 'n)
                       (is car.p24 '0)
                       (is cdr.p24 'nil))
                  (if (is-function n1 '0)
                      (if (is car.p20 'tt)
                          tt1
                          (eval car.p20 ev4))
                      (if (and (is cdr.p20 p21)
                               (is car.p21 p22)
                               (is cdr.p21 'nil)
                               (is car.p22 'f)
                               (is cdr.p22 p25))
                          (eval-call f2 p25 ev4)
                          (eval-if cdr.p20 ev4)))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (and (is cdr.p10 'nil)
                   (is car.p10 p11)
                   (is car.p11 'f)
                   (is cdr.p11 p15))
              (apply λ2 (map-eval p15 ev2))
              (eval-progn p10 ev2))))
      (eval p0 nil)))

;Now I confront that thing about "if f2 is a dick"...
;I could have some heuristic about "insert if-crap and whatever you need
; to remove all "eval-" functions".

;So... That λ2-code must know about the code it is called from
;so it'll know about its ev3 argument and therefore know how
;to drop it and whatever.
;We must inevitably do something like inlining λ2.
;Perhaps inline a little and do some kind of CFA.

(withs
  p29 '(+ n tt)
  p28 `(,p29)
  p27 '(- n 1)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14)
                       (is car.p14 'if)
                       (is cdr.p14 p18)
                       (not-in 'if ev3)
                       (is (symbol-value 'if) if-object)
                       (is car.p18 p19)
                       (is cdr.p18 p20)
                       (is car.p19 'is)
                       (is cdr.p19 p23)
                       (not-in 'is ev3)
                       (is (symbol-value 'is) is-function)
                       (is car.p23 p24)
                       (is cdr.p23 'n)
                       (is car.p24 '0)
                       (is cdr.p24 'nil))
                  (if (is-function n1 '0)
                      (if (is car.p20 'tt)
                          tt1
                          (eval car.p20 ev4))
                      (if (and (is cdr.p20 p21)
                               (is car.p21 p22)
                               (is cdr.p21 'nil)
                               (is car.p22 'f)
                               (is cdr.p22 p25))
                          (eval-call f2 p25 ev4)
                          (eval-if cdr.p20 ev4)))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (and (is cdr.p10 'nil)
                   (is car.p10 p11)
                   (is car.p11 'f)
                   (is cdr.p11 p15))
              (apply λ2.1 λ2.2 (map-eval p15 ev2))
              (eval-progn p10 ev2))))
      (eval p0 nil)))

;Then directly encode the λ2.1 and λ2.2...

(withs
  p29 '(+ n tt)
  p28 `(,p29)
  p27 '(- n 1)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14)
                       (is car.p14 'if)
                       (is cdr.p14 p18)
                       (not-in 'if ev3)
                       (is (symbol-value 'if) if-object)
                       (is car.p18 p19)
                       (is cdr.p18 p20)
                       (is car.p19 'is)
                       (is cdr.p19 p23)
                       (not-in 'is ev3)
                       (is (symbol-value 'is) is-function)
                       (is car.p23 p24)
                       (is cdr.p23 'n)
                       (is car.p24 '0)
                       (is cdr.p24 'nil))
                  (if (is-function n1 '0)
                      (if (is car.p20 'tt)
                          tt1
                          (eval car.p20 ev4))
                      (if (and (is cdr.p20 p21)
                               (is car.p21 p22)
                               (is cdr.p21 'nil)
                               (is car.p22 'f)
                               (is cdr.p22 p25))
                          (eval-call f2 p25 ev4)
                          (eval-if cdr.p20 ev4)))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (and (is cdr.p10 'nil)
                   (is car.p10 p11)
                   (is car.p11 'f)
                   (is cdr.p11 p15))
              (apply λ2-ex nil (map-eval p15 ev2))
              (eval-progn p10 ev2))))
      (eval p0 nil)))

;Then we can drop the λ2...

(withs
  p29 '(+ n tt)
  p28 `(,p29)
  p27 '(- n 1)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14)
                       (is car.p14 'if)
                       (is cdr.p14 p18)
                       (not-in 'if ev3)
                       (is (symbol-value 'if) if-object)
                       (is car.p18 p19)
                       (is cdr.p18 p20)
                       (is car.p19 'is)
                       (is cdr.p19 p23)
                       (not-in 'is ev3)
                       (is (symbol-value 'is) is-function)
                       (is car.p23 p24)
                       (is cdr.p23 'n)
                       (is car.p24 '0)
                       (is cdr.p24 'nil))
                  (if (is-function n1 '0)
                      (if (is car.p20 'tt)
                          tt1
                          (eval car.p20 ev4))
                      (if (and (is cdr.p20 p21)
                               (is car.p21 p22)
                               (is cdr.p21 'nil)
                               (is car.p22 'f)
                               (is cdr.p22 p25))
                          (eval-call f2 p25 ev4)
                          (eval-if cdr.p20 ev4)))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let ev2 (table 'f λ2)
        (if (and (is cdr.p10 'nil)
                 (is car.p10 p11)
                 (is car.p11 'f)
                 (is cdr.p11 p15))
            (apply λ2-ex nil (map-eval p15 ev2))
            (eval-progn p10 ev2)))
      (eval p0 nil)))

;Now we'll have to map-eval...
;Jesus, I'm resorting to using a terminal window with less to
;inspect the list of bindings.

(withs
  p29 '(+ n tt)
  p28 `(,p29)
  p27 '(- n 1)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14)
                       (is car.p14 'if)
                       (is cdr.p14 p18)
                       (not-in 'if ev3)
                       (is (symbol-value 'if) if-object)
                       (is car.p18 p19)
                       (is cdr.p18 p20)
                       (is car.p19 'is)
                       (is cdr.p19 p23)
                       (not-in 'is ev3)
                       (is (symbol-value 'is) is-function)
                       (is car.p23 p24)
                       (is cdr.p23 'n)
                       (is car.p24 '0)
                       (is cdr.p24 'nil))
                  (if (is-function n1 '0)
                      (if (is car.p20 'tt)
                          tt1
                          (eval car.p20 ev4))
                      (if (and (is cdr.p20 p21)
                               (is car.p21 p22)
                               (is cdr.p21 'nil)
                               (is car.p22 'f)
                               (is cdr.p22 p25))
                          (eval-call f2 p25 ev4)
                          (eval-if cdr.p20 ev4)))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let ev2 (table 'f λ2)
        (if (and (is cdr.p10 'nil)
                 (is car.p10 p11)
                 (is car.p11 'f)
                 (is cdr.p11 p15)
                 (is car.p15 'f)
                 (is cdr.p15 p16))
            ;time for ANF
            (with v1 (eval 'f ev2)
                  v2 (map-eval p16 ev2)
              (let v3 (cons v1 v2)
                (apply λ2-ex nil v3)))
            (eval-progn p10 ev2)))
      (eval p0 nil)))

;Hoo boy.

(withs
  p29 '(+ n tt)
  p28 `(,p29)
  p27 '(- n 1)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14)
                       (is car.p14 'if)
                       (is cdr.p14 p18)
                       (not-in 'if ev3)
                       (is (symbol-value 'if) if-object)
                       (is car.p18 p19)
                       (is cdr.p18 p20)
                       (is car.p19 'is)
                       (is cdr.p19 p23)
                       (not-in 'is ev3)
                       (is (symbol-value 'is) is-function)
                       (is car.p23 p24)
                       (is cdr.p23 'n)
                       (is car.p24 '0)
                       (is cdr.p24 'nil))
                  (if (is-function n1 '0)
                      (if (is car.p20 'tt)
                          tt1
                          (eval car.p20 ev4))
                      (if (and (is cdr.p20 p21)
                               (is car.p21 p22)
                               (is cdr.p21 'nil)
                               (is car.p22 'f)
                               (is cdr.p22 p25))
                          (eval-call f2 p25 ev4)
                          (eval-if cdr.p20 ev4)))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let ev2 (table 'f λ2)
        (if (and (is cdr.p10 'nil)
                 (is car.p10 p11)
                 (is car.p11 'f)
                 (is cdr.p11 p15)
                 (is car.p15 'f)
                 (is cdr.p15 p16))
            ;time for ANF
            (with v1 λ2
                  v2 (map-eval p16 ev2)
              (let v3 (cons v1 v2)
                (apply λ2-ex nil v3)))
            (eval-progn p10 ev2)))
      (eval p0 nil)))

;oh god, I shouldn't have dropped the binding of λ2...

(withs
  p29 '(+ n tt)
  p28 `(,p29)
  p27 '(- n 1)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14)
                       (is car.p14 'if)
                       (is cdr.p14 p18)
                       (not-in 'if ev3)
                       (is (symbol-value 'if) if-object)
                       (is car.p18 p19)
                       (is cdr.p18 p20)
                       (is car.p19 'is)
                       (is cdr.p19 p23)
                       (not-in 'is ev3)
                       (is (symbol-value 'is) is-function)
                       (is car.p23 p24)
                       (is cdr.p23 'n)
                       (is car.p24 '0)
                       (is cdr.p24 'nil))
                  (if (is-function n1 '0)
                      (if (is car.p20 'tt)
                          tt1
                          (eval car.p20 ev4))
                      (if (and (is cdr.p20 p21)
                               (is car.p21 p22)
                               (is cdr.p21 'nil)
                               (is car.p22 'f)
                               (is cdr.p22 p25))
                          (eval-call f2 p25 ev4)
                          (eval-if cdr.p20 ev4)))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (and (is cdr.p10 'nil)
                   (is car.p10 p11)
                   (is car.p11 'f)
                   (is cdr.p11 p15)
                   (is car.p15 'f)
                   (is cdr.p15 p16))
              ;time for ANF
              (with v1 λ2
                v2 (map-eval p16 ev2)
                (let v3 (cons v1 v2)
                  (apply λ2-ex nil v3)))
              (eval-progn p10 ev2))))
      (eval p0 nil)))

;ok so dick

(withs
  p29 '(+ n tt)
  p28 `(,p29)
  p27 '(- n 1)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14)
                       (is car.p14 'if)
                       (is cdr.p14 p18)
                       (not-in 'if ev3)
                       (is (symbol-value 'if) if-object)
                       (is car.p18 p19)
                       (is cdr.p18 p20)
                       (is car.p19 'is)
                       (is cdr.p19 p23)
                       (not-in 'is ev3)
                       (is (symbol-value 'is) is-function)
                       (is car.p23 p24)
                       (is cdr.p23 'n)
                       (is car.p24 '0)
                       (is cdr.p24 'nil))
                  (if (is-function n1 '0)
                      (if (is car.p20 'tt)
                          tt1
                          (eval car.p20 ev4))
                      (if (and (is cdr.p20 p21)
                               (is car.p21 p22)
                               (is cdr.p21 'nil)
                               (is car.p22 'f)
                               (is cdr.p22 p25))
                          (eval-call f2 p25 ev4)
                          (eval-if cdr.p20 ev4)))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (and (is cdr.p10 'nil)
                   (is car.p10 p11)
                   (is car.p11 'f)
                   (is cdr.p11 p15)
                   (is car.p15 'f)
                   (is cdr.p15 p16)
                   (is car.p16 '1000)
                   (is cdr.p16 p17))
              ;time for ANF
              (withs
                v4 (eval '1000 ev2)
                v5 (map-eval p17 ev2)
                v6 (cons v4 v5)
                v3 (cons λ2 v6)
                (apply λ2-ex nil v3))
              (eval-progn p10 ev2))))
      (eval p0 nil)))

;hoo boy. now.
;the eval-ing of 1000 does nothing, and we can proc.
;--say, um, actually, order of evaluation is left to right, so...
;--time to try again at that.

(withs
  p29 '(+ n tt)
  p28 `(,p29)
  p27 '(- n 1)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14)
                       (is car.p14 'if)
                       (is cdr.p14 p18)
                       (not-in 'if ev3)
                       (is (symbol-value 'if) if-object)
                       (is car.p18 p19)
                       (is cdr.p18 p20)
                       (is car.p19 'is)
                       (is cdr.p19 p23)
                       (not-in 'is ev3)
                       (is (symbol-value 'is) is-function)
                       (is car.p23 p24)
                       (is cdr.p23 'n)
                       (is car.p24 '0)
                       (is cdr.p24 'nil))
                  (if (is-function n1 '0)
                      (if (is car.p20 'tt)
                          tt1
                          (eval car.p20 ev4))
                      (if (and (is cdr.p20 p21)
                               (is car.p21 p22)
                               (is cdr.p21 'nil)
                               (is car.p22 'f)
                               (is cdr.p22 p25))
                          (eval-call f2 p25 ev4)
                          (eval-if cdr.p20 ev4)))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (and (is cdr.p10 'nil)
                   (is car.p10 p11)
                   (is car.p11 'f)
                   (is cdr.p11 p15)
                   (is car.p15 'f)
                   (is cdr.p15 p16)
                   (is car.p16 '1000)
                   (is cdr.p16 p17)
                   (is car.p17 '0)
                   (is cdr.p17 'nil))
              ;time for ANF
              (withs
                v1 λ2
                v2 (map-eval p15 ev2)
                v3 (cons v1 v2)
                (apply λ2-ex nil v3))
              (eval-progn p10 ev2))))
      (eval p0 nil)))

;then

(withs
  p29 '(+ n tt)
  p28 `(,p29)
  p27 '(- n 1)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14)
                       (is car.p14 'if)
                       (is cdr.p14 p18)
                       (not-in 'if ev3)
                       (is (symbol-value 'if) if-object)
                       (is car.p18 p19)
                       (is cdr.p18 p20)
                       (is car.p19 'is)
                       (is cdr.p19 p23)
                       (not-in 'is ev3)
                       (is (symbol-value 'is) is-function)
                       (is car.p23 p24)
                       (is cdr.p23 'n)
                       (is car.p24 '0)
                       (is cdr.p24 'nil))
                  (if (is-function n1 '0)
                      (if (is car.p20 'tt)
                          tt1
                          (eval car.p20 ev4))
                      (if (and (is cdr.p20 p21)
                               (is car.p21 p22)
                               (is cdr.p21 'nil)
                               (is car.p22 'f)
                               (is cdr.p22 p25))
                          (eval-call f2 p25 ev4)
                          (eval-if cdr.p20 ev4)))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (and (is cdr.p10 'nil)
                   (is car.p10 p11)
                   (is car.p11 'f)
                   (is cdr.p11 p15)
                   (is car.p15 'f)
                   (is cdr.p15 p16)
                   (is car.p16 '1000)
                   (is cdr.p16 p17)
                   (is car.p17 '0)
                   (is cdr.p17 'nil))
              ;time for ANF
              (withs
                v1 λ2
                v2 (withs v4 '1000
                     v5 (map-eval p17 ev2)
                     v6 (cons v4 v5)
                     v6)
                v3 (cons v1 v2)
                (apply λ2-ex nil v3))
              (eval-progn p10 ev2))))
      (eval p0 nil)))

;then

(withs
  p29 '(+ n tt)
  p28 `(,p29)
  p27 '(- n 1)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14)
                       (is car.p14 'if)
                       (is cdr.p14 p18)
                       (not-in 'if ev3)
                       (is (symbol-value 'if) if-object)
                       (is car.p18 p19)
                       (is cdr.p18 p20)
                       (is car.p19 'is)
                       (is cdr.p19 p23)
                       (not-in 'is ev3)
                       (is (symbol-value 'is) is-function)
                       (is car.p23 p24)
                       (is cdr.p23 'n)
                       (is car.p24 '0)
                       (is cdr.p24 'nil))
                  (if (is-function n1 '0)
                      (if (is car.p20 'tt)
                          tt1
                          (eval car.p20 ev4))
                      (if (and (is cdr.p20 p21)
                               (is car.p21 p22)
                               (is cdr.p21 'nil)
                               (is car.p22 'f)
                               (is cdr.p22 p25))
                          (eval-call f2 p25 ev4)
                          (eval-if cdr.p20 ev4)))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (and (is cdr.p10 'nil)
                   (is car.p10 p11)
                   (is car.p11 'f)
                   (is cdr.p11 p15)
                   (is car.p15 'f)
                   (is cdr.p15 p16)
                   (is car.p16 '1000)
                   (is cdr.p16 p17)
                   (is car.p17 '0)
                   (is cdr.p17 'nil))
              ;time for ANF
              (withs
                v1 λ2
                v4 '1000
                v5 (map-eval p17 ev2)
                v6 (cons v4 v5)
                v2 v6
                v3 (cons v1 v2)
                (apply λ2-ex nil v3))
              (eval-progn p10 ev2))))
      (eval p0 nil)))

;and lolz

(withs
  p29 '(+ n tt)
  p28 `(,p29)
  p27 '(- n 1)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14)
                       (is car.p14 'if)
                       (is cdr.p14 p18)
                       (not-in 'if ev3)
                       (is (symbol-value 'if) if-object)
                       (is car.p18 p19)
                       (is cdr.p18 p20)
                       (is car.p19 'is)
                       (is cdr.p19 p23)
                       (not-in 'is ev3)
                       (is (symbol-value 'is) is-function)
                       (is car.p23 p24)
                       (is cdr.p23 'n)
                       (is car.p24 '0)
                       (is cdr.p24 'nil))
                  (if (is-function n1 '0)
                      (if (is car.p20 'tt)
                          tt1
                          (eval car.p20 ev4))
                      (if (and (is cdr.p20 p21)
                               (is car.p21 p22)
                               (is cdr.p21 'nil)
                               (is car.p22 'f)
                               (is cdr.p22 p25))
                          (eval-call f2 p25 ev4)
                          (eval-if cdr.p20 ev4)))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (and (is cdr.p10 'nil)
                   (is car.p10 p11)
                   (is car.p11 'f)
                   (is cdr.p11 p15)
                   (is car.p15 'f)
                   (is cdr.p15 p16)
                   (is car.p16 '1000)
                   (is cdr.p16 p17)
                   (is car.p17 '0)
                   (is cdr.p17 'nil))
              ;time for ANF
              (withs
                v1 λ2
                v4 '1000
                v5 (withs v7 '0
                     v8 (map-eval 'nil ev2)
                     v9 (cons v7 v8)
                     v9)
                v6 (cons v4 v5)
                v2 v6
                v3 (cons v1 v2)
                (apply λ2-ex nil v3))
              (eval-progn p10 ev2))))
      (eval p0 nil)))

;and

(withs
  p29 '(+ n tt)
  p28 `(,p29)
  p27 '(- n 1)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14)
                       (is car.p14 'if)
                       (is cdr.p14 p18)
                       (not-in 'if ev3)
                       (is (symbol-value 'if) if-object)
                       (is car.p18 p19)
                       (is cdr.p18 p20)
                       (is car.p19 'is)
                       (is cdr.p19 p23)
                       (not-in 'is ev3)
                       (is (symbol-value 'is) is-function)
                       (is car.p23 p24)
                       (is cdr.p23 'n)
                       (is car.p24 '0)
                       (is cdr.p24 'nil))
                  (if (is-function n1 '0)
                      (if (is car.p20 'tt)
                          tt1
                          (eval car.p20 ev4))
                      (if (and (is cdr.p20 p21)
                               (is car.p21 p22)
                               (is cdr.p21 'nil)
                               (is car.p22 'f)
                               (is cdr.p22 p25))
                          (eval-call f2 p25 ev4)
                          (eval-if cdr.p20 ev4)))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (and (is cdr.p10 'nil)
                   (is car.p10 p11)
                   (is car.p11 'f)
                   (is cdr.p11 p15)
                   (is car.p15 'f)
                   (is cdr.p15 p16)
                   (is car.p16 '1000)
                   (is cdr.p16 p17)
                   (is car.p17 '0)
                   (is cdr.p17 'nil))
              ;time for ANF
              (withs
                v1 λ2
                v4 '1000
                v7 '0
                v8 'nil
                v9 (cons v7 v8)
                v5 v9
                v6 (cons v4 v5)
                v2 v6
                v3 (cons v1 v2)
                (apply λ2-ex nil v3))
              (eval-progn p10 ev2))))
      (eval p0 nil)))

;bwahaha. now. earlier dicks.

(withs
  p29 '(+ n tt)
  p28 `(,p29)
  p27 '(- n 1)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14)
                       (is car.p14 'if)
                       (is cdr.p14 p18)
                       (not-in 'if ev3)
                       (is (symbol-value 'if) if-object)
                       (is car.p18 p19)
                       (is cdr.p18 p20)
                       (is car.p19 'is)
                       (is cdr.p19 p23)
                       (not-in 'is ev3)
                       (is (symbol-value 'is) is-function)
                       (is car.p23 p24)
                       (is cdr.p23 'n)
                       (is car.p24 '0)
                       (is cdr.p24 'nil))
                  (if (is-function n1 '0)
                      (if (is car.p20 'tt)
                          tt1
                          (eval car.p20 ev4))
                      (if (and (is cdr.p20 p21)
                               (is car.p21 p22)
                               (is cdr.p21 'nil)
                               (is car.p22 'f)
                               (is cdr.p22 p25))
                          (eval-call f2 p25 ev4)
                          (eval-if cdr.p20 ev4)))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (and (is cdr.p10 'nil)
                   (is car.p10 p11)
                   (is car.p11 'f)
                   (is cdr.p11 p15)
                   (is car.p15 'f)
                   (is cdr.p15 p16)
                   (is car.p16 '1000)
                   (is cdr.p16 p17)
                   (is car.p17 '0)
                   (is cdr.p17 'nil))
              ;time for ANF
              (withs
                v1 λ2
                v4 '1000
                v7 '0
                v8 'nil
                v9 (cons '0 'nil)
                v5 v9
                v6 (cons '1000 v9)
                v2 v6
                v3 (cons λ2 v6)
                (apply λ2-ex nil v3))
              (eval-progn p10 ev2))))
      (eval p0 nil)))

;And.

(withs
  p29 '(+ n tt)
  p28 `(,p29)
  p27 '(- n 1)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14)
                       (is car.p14 'if)
                       (is cdr.p14 p18)
                       (not-in 'if ev3)
                       (is (symbol-value 'if) if-object)
                       (is car.p18 p19)
                       (is cdr.p18 p20)
                       (is car.p19 'is)
                       (is cdr.p19 p23)
                       (not-in 'is ev3)
                       (is (symbol-value 'is) is-function)
                       (is car.p23 p24)
                       (is cdr.p23 'n)
                       (is car.p24 '0)
                       (is cdr.p24 'nil))
                  (if (is-function n1 '0)
                      (if (is car.p20 'tt)
                          tt1
                          (eval car.p20 ev4))
                      (if (and (is cdr.p20 p21)
                               (is car.p21 p22)
                               (is cdr.p21 'nil)
                               (is car.p22 'f)
                               (is cdr.p22 p25))
                          (eval-call f2 p25 ev4)
                          (eval-if cdr.p20 ev4)))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (and (is cdr.p10 'nil)
                   (is car.p10 p11)
                   (is car.p11 'f)
                   (is cdr.p11 p15)
                   (is car.p15 'f)
                   (is cdr.p15 p16)
                   (is car.p16 '1000)
                   (is cdr.p16 p17)
                   (is car.p17 '0)
                   (is cdr.p17 'nil))
              ;time for ANF
              (withs
                v9 (cons '0 'nil)
                v6 (cons '1000 v9)
                v3 (cons λ2 v6)
                (apply λ2-ex nil v3))
              (eval-progn p10 ev2))))
      (eval p0 nil)))

;Wootz.  That is pretty fun.  Now we can dick.
;Will collapse all those applying steps into one.

(withs
  p29 '(+ n tt)
  p28 `(,p29)
  p27 '(- n 1)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14)
                       (is car.p14 'if)
                       (is cdr.p14 p18)
                       (not-in 'if ev3)
                       (is (symbol-value 'if) if-object)
                       (is car.p18 p19)
                       (is cdr.p18 p20)
                       (is car.p19 'is)
                       (is cdr.p19 p23)
                       (not-in 'is ev3)
                       (is (symbol-value 'is) is-function)
                       (is car.p23 p24)
                       (is cdr.p23 'n)
                       (is car.p24 '0)
                       (is cdr.p24 'nil))
                  (if (is-function n1 '0)
                      (if (is car.p20 'tt)
                          tt1
                          (eval car.p20 ev4))
                      (if (and (is cdr.p20 p21)
                               (is car.p21 p22)
                               (is cdr.p21 'nil)
                               (is car.p22 'f)
                               (is cdr.p22 p25))
                          (eval-call f2 p25 ev4)
                          (eval-if cdr.p20 ev4)))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (and (is cdr.p10 'nil)
                   (is car.p10 p11)
                   (is car.p11 'f)
                   (is cdr.p11 p15)
                   (is car.p15 'f)
                   (is cdr.p15 p16)
                   (is car.p16 '1000)
                   (is cdr.p16 p17)
                   (is car.p17 '0)
                   (is cdr.p17 'nil))
              ;time for ANF
              (withs
                v9 (cons '0 'nil)
                v6 (cons '1000 v9)
                v3 (cons λ2 v6)
                (λ2-ex nil λ2 '1000 '0))
              (eval-progn p10 ev2))))
      (eval p0 nil)))

;And then we can drop dicks.

(withs
  p29 '(+ n tt)
  p28 `(,p29)
  p27 '(- n 1)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14)
                       (is car.p14 'if)
                       (is cdr.p14 p18)
                       (not-in 'if ev3)
                       (is (symbol-value 'if) if-object)
                       (is car.p18 p19)
                       (is cdr.p18 p20)
                       (is car.p19 'is)
                       (is cdr.p19 p23)
                       (not-in 'is ev3)
                       (is (symbol-value 'is) is-function)
                       (is car.p23 p24)
                       (is cdr.p23 'n)
                       (is car.p24 '0)
                       (is cdr.p24 'nil))
                  (if (is-function n1 '0)
                      (if (is car.p20 'tt)
                          tt1
                          (eval car.p20 ev4))
                      (if (and (is cdr.p20 p21)
                               (is car.p21 p22)
                               (is cdr.p21 'nil)
                               (is car.p22 'f)
                               (is cdr.p22 p25))
                          (eval-call f2 p25 ev4)
                          (eval-if cdr.p20 ev4)))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (and (is cdr.p10 'nil)
                   (is car.p10 p11)
                   (is car.p11 'f)
                   (is cdr.p11 p15)
                   (is car.p15 'f)
                   (is cdr.p15 p16)
                   (is car.p16 '1000)
                   (is cdr.p16 p17)
                   (is car.p17 '0)
                   (is cdr.p17 'nil))
              (λ2-ex nil λ2 '1000 '0)
              (eval-progn p10 ev2))))
      (eval p0 nil)))

;Oh dang, even after that, we don't get much...

(withs
  p29 '(+ n tt)
  p28 `(,p29)
  p27 '(- n 1)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (and (is cdr.p13 'nil)
                       (is car.p13 p14)
                       (is car.p14 'if)
                       (is cdr.p14 p18)
                       (not-in 'if ev3)
                       (is (symbol-value 'if) if-object)
                       (is car.p18 p19)
                       (is cdr.p18 p20)
                       (is car.p19 'is)
                       (is cdr.p19 p23)
                       (not-in 'is ev3)
                       (is (symbol-value 'is) is-function)
                       (is car.p23 p24)
                       (is cdr.p23 'n)
                       (is car.p24 '0)
                       (is cdr.p24 'nil))
                  (if (is-function n1 '0)
                      (if (is car.p20 'tt)
                          tt1
                          (eval car.p20 ev4))
                      (if (and (is cdr.p20 p21)
                               (is car.p21 p22)
                               (is cdr.p21 'nil)
                               (is car.p22 'f)
                               (is cdr.p22 p25))
                          (eval-call f2 p25 ev4)
                          (eval-if cdr.p20 ev4)))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (and (is car.p0 p1)
           (is cdr.p0 p2)
           (is car.p1 'fn)
           (is cdr.p1 p4)
           (is (symbol-value 'fn) fn-object)
           (is car.p4 p9)
           (is car.p9 'f)
           (is cdr.p9 'nil)
           (is cdr.p4 p10)
           (is car.p2 p5)
           (is cdr.p2 'nil)
           (is car.p5 'fn)
           (is cdr.p5 p8)
           (is (symbol-value 'fn) fn-object)
           (is car.p8 p12)
           (is cdr.p8 p13))
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (and (is cdr.p10 'nil)
                   (is car.p10 p11)
                   (is car.p11 'f)
                   (is cdr.p11 p15)
                   (is car.p15 'f)
                   (is cdr.p15 p16)
                   (is car.p16 '1000)
                   (is cdr.p16 p17)
                   (is car.p17 '0)
                   (is cdr.p17 'nil))
              (λ2-code nil λ2 '1000 '0)
              (eval-progn p10 ev2))))
      (eval p0 nil)))

;Ok, now. This is as much as we can do without beta-expanding
;the call to λ2-code, which is usually to be desired.
;...
;Guuuuuuuuuuuuuuuuuuuuuhhhhhhhhhhhhhhhhhhhh....

;...
;It's not even possible to do too much, because someone could alter
;the dicks in mid-loop.
;So CFA would be useless without the known dicks.

;Let's see.  How do I want to handle the "someone changed the rug
; under your feet" sort of thing?
;The most anyone will probably want to ask for is "A thread will
; perceive that the rug has been changed in up to a small constant
; number of instructions."
;In that case, it works to have a check at the beginning of every
;function call.
;(Note that a "loop" must be a function call that is repeatedly
; made.)
;After that, if you do a bunch of beta-expansion or -contraction,
;you can take any "chk <small number of instructions> chk" and
;turn it into "chk <small number of instructions>".
;Furthermore, if you want a group of mutually recursive functions
;to be registered and sufficient and not needing chk's, then you
;should call them with a wrapper function (perhaps the original
; code of those functions) that says "chk <call real func>" (if
; this checking code is right before the main unwrapped code,
; then the call can be deleted [it should be a jmp]).
;In a good system, the toplevel may be the only thing needing a
;wrapper function (or smthg).

;... Oh boy... Well, let's give that a try...

(withs
  p29 '(+ n tt)
  p28 `(,p29)
  p27 '(- n 1)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (mailbox)
                  (eval-progn p13 ev4)
                  (and t
                       t
                       t
                       t
                       (not-in 'if ev3)
                       t
                       t
                       t
                       t
                       t
                       (not-in 'is ev3)
                       t
                       t
                       t
                       t
                       t)
                  (if (is-function n1 '0)
                      (if (mailbox)
                          (eval car.p20 ev4)
                          tt1)
                      (if (mailbox)
                          (eval-if cdr.p20 ev4)
                          (and t
                               t
                               t
                               t
                               t)
                          (eval-call f2 p25 ev4)
                          (eval-if cdr.p20 ev4)))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (mailbox) ;modifications of globvars as well as of code
      (eval p0 nil)
      (and t
           t
           t
           t
           t
           t
           t
           t
           t
           t
           t
           t
           t
           t
           t
           t)
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (mailbox)
              (eval-progn p10 ev2)
              (and t
                   t
                   t
                   t
                   t
                   t
                   t
                   t
                   t
                   t)
              (λ2-code nil λ2 '1000 '0))))
      (eval p0 nil)))

;aw m'gaw

(withs
  p29 '(+ n tt)
  p28 `(,p29)
  p27 '(- n 1)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (mailbox)
                  (eval-progn p13 ev4)
                  (and (not-in 'if ev3)
                       (not-in 'is ev3))
                  (if (is-function n1 '0)
                      (if (mailbox)
                          (eval car.p20 ev4)
                          tt1)
                      (if (mailbox)
                          (eval-if cdr.p20 ev4)
                          t
                          (eval-call f2 p25 ev4)
                          (eval-if cdr.p20 ev4)))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (mailbox) ;modifications of globvars as well as of code
      (eval p0 nil)
      t
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (mailbox)
              (eval-progn p10 ev2)
              t
              (λ2-code nil λ2 '1000 '0))))
      (eval p0 nil)))

;so much better

(withs
  p29 '(+ n tt)
  p28 `(,p29)
  p27 '(- n 1)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (mailbox)
                  (eval-progn p13 ev4)
                  (and (not-in 'if ev3)
                       (not-in 'is ev3))
                  (if (is-function n1 '0)
                      (if (mailbox)
                          (eval car.p20 ev4)
                          tt1)
                      (if (mailbox)
                          (eval-if cdr.p20 ev4)
                          (eval-call f2 p25 ev4)))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (mailbox) ;modifications of globvars as well as of code
      (eval p0 nil)
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if (mailbox)
              (eval-progn p10 ev2)
              (λ2-code nil λ2 '1000 '0))))))

;and now I'm going to say I can kill those extra sub-mailboxes
;in λ2-code, based on principle:
;(mailbox (fn (x) (if3 x ... (... (mailbox (fn (v) ...))) ...)))
;= (mailbox (fn (x) (if3 x ... (... (quote nil (fn (v) ...))) ...)))

(withs
  p29 '(+ n tt)
  p28 `(,p29)
  p27 '(- n 1)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (mailbox)
                  (eval-progn p13 ev4)
                  (and (not-in 'if ev3)
                       (not-in 'is ev3))
                  (if (is-function n1 '0)
                      (if nil
                          (eval car.p20 ev4)
                          tt1)
                      (if nil
                          (eval-if cdr.p20 ev4)
                          (eval-call f2 p25 ev4)))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (mailbox) ;modifications of globvars as well as of code
      (eval p0 nil)
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (if nil
              (eval-progn p10 ev2)
              (λ2-code nil λ2 '1000 '0))))))

;and now...

(withs
  p29 '(+ n tt)
  p28 `(,p29)
  p27 '(- n 1)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (mailbox)
                  (eval-progn p13 ev4)
                  (and (not-in 'if ev3)
                       (not-in 'is ev3))
                  (if (is-function n1 '0)
                      tt1
                      (eval-call f2 p25 ev4))
                  (eval-progn p13 ev4))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (mailbox) ;modifications of globvars as well as of code
      (eval p0 nil)
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (λ2-code nil λ2 '1000 '0)))))

;Aw man.
;Now this terrible horrible crap is down to something manageable.
;I wonder if I can put the binding of ev4 directly outside those
;calls to eval-progn.  And/or if I can eliminate some dicks.
;Somehow that crap should be collapsed into one.
;But meh.
;So.
;Now...
;Neh, fine.
;If I did this with (mailbox)es from the start, I would probably
;have dicks combined like this.

(withs
  p29 '(+ n tt)
  p28 `(,p29)
  p27 '(- n 1)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (or (mailbox)
                      (no:and (not-in 'if ev3)
                              (not-in 'is ev3)))
                  (eval-progn p13 ev4)
                  (if (is-function n1 '0)
                      tt1
                      (eval-call f2 p25 ev4)))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (mailbox) ;modifications of globvars as well as of code
      (eval p0 nil)
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (λ2-code nil λ2 '1000 '0)))))

;And now it is advantageous to hoist the binding down.
;--Or not.

(withs
  p29 '(+ n tt)
  p28 `(,p29)
  p27 '(- n 1)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (or (mailbox)
                      (no:and (not-in 'if ev3)
                              (not-in 'is ev3)))
                  (eval-progn p13 ev4) ;accually is recompile
                  (if (is-function n1 '0) ;(shouldn't keep having
                      tt1                ; to call eval if "is" really
                      (eval-call f2 p25 ev4))))) ; is rebound)
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (mailbox) ;modifications of globvars as well as of code
      (eval p0 nil)
      (let λ2 (list 'closure λ2-ex nil)
        (let ev2 (table 'f λ2)
          (λ2-code nil λ2 '1000 '0)))))

;Ok, so.
;It certainly seems possible that I could prove by induction that
;the f2 argument to λ2-code is always not a macro.  (Spec., it is
; a closure over λ2-ex.)
;For this shit to work properly so that there is no mallocing,
;I'm going to have to eliminate the "let ev2" thing.
;This cannot be done without inlining ...
;Oh.
;Dumbass.  It _can._  Right _now._

(withs
  p29 '(+ n tt)
  p28 `(,p29)
  p27 '(- n 1)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (or (mailbox)
                      (no:and (not-in 'if ev3)
                              (not-in 'is ev3)))
                  (eval-progn p13 ev4) ;accually is recompile
                  (if (is-function n1 '0) ;(shouldn't keep having
                      tt1                ; to call eval if "is" really
                      (eval-call f2 p25 ev4))))) ; is rebound)
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (mailbox) ;modifications of globvars as well as of code
      (eval p0 nil)
      (let λ2 (list 'closure λ2-ex nil)
        (λ2-code nil λ2 '1000 '0))))

;Ok, so.
;As I've felt before, I think I want some kind of CFA rather than
;some kind of "induction" analysis, because the former seems more
;powerful and would probably supersede the latter.

;So... can we do it?
;Ok, so,
;upon the first evaluation of this whole expression,
;we would simulate eval-ing this thing.
;We would not allow any side effects to actually happen.
;We would probably also mostly avoid reading things from
;memory, except some segregated places (globvars, env, tables we
; suspect might be not changed).
;We might pretend to read from memory sometimes. Also pretend to
;write to it. We'd read/write an abstract location or a few.
;... So...

;I can say that, on the conventional path, λ2-code's f2 argument
;will only ever be bound to a closure from λ2... hmm...
;Can I demonstrate this?
;Let me try.

;(λ2-code nil λ2 1000 0)
;(if nil
;    derf
;    (if (is-function 1000 0)
;        0
;        (eval-call λ2 p25 ev4)))
;(eval-call λ2 '(f (- n 1) (+ n tt)) (obj f λ2 n 1000 tt 0))
;(apply λ2 (list λ2 999 1000))
;(λ2-ex nil λ2 999 1000)
;(λ2-code nil λ2 999 1000)

;Yep.  Ok, so...
;Let us imagine this crap.
;That the f2 is determined to be (closure λ2-ex ???).

(withs
  p29 '(+ n tt)
  p28 `(,p29)
  p27 '(- n 1)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (or (mailbox)
                      (no:and (not-in 'if ev3)
                              (not-in 'is ev3)))
                  (eval-progn p13 ev4) ;accually is recompile
                  (if (is-function n1 '0) ;(shouldn't keep having
                      tt1                ; to call eval if "is" really
                      (apply λ2-ex f2.2
                             (map-eval p25 ev4)))))) ; is rebound)
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (mailbox) ;modifications of globvars as well as of code
      (eval p0 nil)
      (let λ2 (list 'closure λ2-ex nil)
        (λ2-code nil λ2 '1000 '0))))

;Hoh boy.  Well, then.

(withs
  p33 '(tt)
  p32 `(n ,@p33)
  p31 '(1)
  p30 `(n ,@p31)
  p29 `(+ ,@p32)
  p28 `(,p29)
  p27 `(- ,@p30)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (or (mailbox)
                      (no:and (not-in 'if ev3)
                              (not-in 'is ev3)))
                  (eval-progn p13 ev4) ;accually is recompile
                  (if (is-function n1 '0)
                      tt1                
                      (let args (map-eval p25 ev4)
                        (apply λ2-ex f2.2
                               args))))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (mailbox) ;modifications of globvars as well as of code
      (eval p0 nil)
      (let λ2 (list 'closure λ2-ex nil)
        (λ2-code nil λ2 '1000 '0))))

;Now... --Could possibly figure out env crap.  But neh.
;Harder to do that in general with nontrivial envs.

(withs
  p33 '(tt)
  p32 `(n ,@p33)
  p31 '(1)
  p30 `(n ,@p31)
  p29 `(+ ,@p32)
  p28 `(,p29)
  p27 `(- ,@p30)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (or (mailbox)
                      (no:and (not-in 'if ev3)
                              (not-in 'is ev3)))
                  (eval-progn p13 ev4) ;accually is recompile
                  (if (is-function n1 '0)
                      tt1
                      ;assuming (no (mailbox)), which is appropriate
                      (let args (withs v1 (eval 'f ev4)
                                  v2 (map-eval p26 ev4)
                                  v3 (cons v1 v2)
                                  v3)
                        (apply λ2-ex f2.2
                               args))))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (mailbox) ;modifications of globvars as well as of code
      (eval p0 nil)
      (let λ2 (list 'closure λ2-ex nil)
        (λ2-code nil λ2 '1000 '0))))

;Ahhh, this strategy.  Because of no:mailbox, we don't need to
;bother introducing a bunch of terrible tests.
;I still want a partial-evaluator thingy that introduces all
;the terrible tests, which would tell me what I needed to do to
;eliminate them.
;I guess it'd use a speculative inlining heuristic.
;Inline until you get code paths that eliminate all evals.
;(Code paths on which there are no evals, at least not of anything
; but runtime data.)

(withs
  p33 '(tt)
  p32 `(n ,@p33)
  p31 '(1)
  p30 `(n ,@p31)
  p29 `(+ ,@p32)
  p28 `(,p29)
  p27 `(- ,@p30)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (or (mailbox)
                      (no:and (not-in 'if ev3)
                              (not-in 'is ev3)))
                  (eval-progn p13 ev4) ;accually is recompile
                  (if (is-function n1 '0)
                      tt1
                      ;assuming (no (mailbox)), which is appropriate
                      (let args (withs v1 f2
                                  v2 (map-eval p26 ev4)
                                  v3 (cons v1 v2)
                                  v3)
                        (apply λ2-ex f2.2
                               args))))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (mailbox) ;modifications of globvars as well as of code
      (eval p0 nil)
      (let λ2 (list 'closure λ2-ex nil)
        (λ2-code nil λ2 '1000 '0))))

;

(withs
  p33 '(tt)
  p32 `(n ,@p33)
  p31 '(1)
  p30 `(n ,@p31)
  p29 `(+ ,@p32)
  p28 `(,p29)
  p27 `(- ,@p30)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (or (mailbox)
                      (no:and (not-in 'if ev3)
                              (not-in 'is ev3)))
                  (eval-progn p13 ev4) ;accually is recompile
                  (if (is-function n1 '0)
                      tt1
                      ;assuming (no (mailbox)), which is appropriate
                      (let args (withs v1 f2
                                  v2 (withs v4 (eval p27 ev4)
                                       v5 (map-eval p28 ev4)
                                       v6 (cons v4 v5)
                                       v6)
                                  v3 (cons v1 v2)
                                  v3)
                        (apply λ2-ex f2.2
                               args))))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (mailbox) ;modifications of globvars as well as of code
      (eval p0 nil)
      (let λ2 (list 'closure λ2-ex nil)
        (λ2-code nil λ2 '1000 '0))))

;Oh man now.
;ANF-ify.

(withs
  p33 '(tt)
  p32 `(n ,@p33)
  p31 '(1)
  p30 `(n ,@p31)
  p29 `(+ ,@p32)
  p28 `(,p29)
  p27 `(- ,@p30)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (or (mailbox)
                      (no:and (not-in 'if ev3)
                              (not-in 'is ev3)))
                  (eval-progn p13 ev4) ;accually is recompile
                  (if (is-function n1 '0)
                      tt1
                      ;assuming (no (mailbox)), which is appropriate
                      (withs v1 f2
                        v2 (withs v4 (eval p27 ev4)
                             v5 (map-eval p28 ev4)
                             v6 (cons v4 v5)
                             v6)
                        v3 (cons v1 v2)
                        (let args v3
                          (apply λ2-ex f2.2
                                 args)))))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (mailbox) ;modifications of globvars as well as of code
      (eval p0 nil)
      (let λ2 (list 'closure λ2-ex nil)
        (λ2-code nil λ2 '1000 '0))))

;Cleanup, then must do weird things...

(withs
  p33 '(tt)
  p32 `(n ,@p33)
  p31 '(1)
  p30 `(n ,@p31)
  p29 `(+ ,@p32)
  p28 `(,p29)
  p27 `(- ,@p30)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (or (mailbox)
                      (no:and (not-in 'if ev3)
                              (not-in 'is ev3)))
                  (eval-progn p13 ev4) ;accually is recompile
                  (if (is-function n1 '0)
                      tt1
                      ;assuming (no (mailbox)), which is appropriate
                      (withs
                        v4 (eval p27 ev4)
                        v5 (map-eval p28 ev4)
                        v6 (cons v4 v5)
                        v3 (cons f2 v6)
                        (apply λ2-ex f2.2
                               v3))))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (mailbox) ;modifications of globvars as well as of code
      (eval p0 nil)
      (let λ2 (list 'closure λ2-ex nil)
        (λ2-code nil λ2 '1000 '0))))

;So, must ... aw gawd.
;Well...
;

;I think Shivers and mothafuckas talk about distinguishing envs.
;But now I have a real use case.

;So the CFA or smthg (almost certainly CFA) must be able to tell me
;that (a) f2 is a λ2 closure and (b) λ2-closures are only created
;with envs that were created in the textually apparent creation of
;the λ2-closure.

;I guess I must reach some fixed point thing...
;(because what text will exist is not known until all macros--or,
; in particular, things that might be macros--are expanded...
; but eh, I am probably working with all-expanded crap...)

;Anyway, let us imagine I can discover that the env field
;of the λ2 things will be a nil env.
;In general, what I can discover is the names of the bound variables.
;Their values will of course be unknown, but the names of the vars
;will be knowable and is useful information.  (Also useful is what
;are not names of bound vars.)

;Anyway, [sleep cycle] let's say I can do that.
;I'll be able to resolve ...
;A real closure should use a vector to store things.
;The information about which symbol => which vector index could be
;stored in a separate table, and that table could be basically
;immutable.
;Now...
;Btw it looks like creating a closure will in fact compile a bit of
;code, and that code is guaranteed to be equiv to:
;(fn args (let ev (new-env stored-ev args [poss. arglist])
;           (eval-progn body ev))).
;Um...
;Probably that's the "ex" code or something.
;Whatever, anyway.

;CFA of some sort (prob. 0CFA adapted to general Lisp)

(withs
  p33 '(tt)
  p32 `(n ,@p33)
  p31 '(1)
  p30 `(n ,@p31)
  p29 `(+ ,@p32)
  p28 `(,p29)
  p27 `(- ,@p30)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent ev3)
              (if (or (mailbox)
                      (no:and (not-in 'if ev3)
                              (not-in 'is ev3)))
                  (eval-progn p13 ev4) ;accually is recompile
                  (if (is-function n1 '0)
                      tt1
                      ;assuming (no (mailbox)), which is appropriate
                      (withs
                        v4 (eval p27 ev4)
                        v5 (map-eval p28 ev4)
                        v6 (cons v4 v5)
                        v3 (cons f2 v6)
                        (apply λ2-ex nil
                               v3))))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (mailbox) ;modifications of globvars as well as of code
      (eval p0 nil)
      (let λ2 (list 'closure λ2-ex nil)
        (λ2-code nil λ2 '1000 '0))))

;Hmm.  Hmm...

;Is it that the only instances of closures made with λ2-ex have
;nil environments?  Or is it that the only closures called with
;"apply ... v3" up there are λ2-ex's with nil environments?
;Or is it that the only closures called at "apply ... v3" are
;λ2's created at that "let λ2"?
;'Cause it would be nice if I could say from the start that ev3
;was nil.
;Hmm...
;How can I be sure about this "shit is diff." business?
;I can't even compare things with eq. The same closure code could
;be used in multiple places, as in:
#;(let x '(fn (y) (+ y))
  `(list ,x
         (let + (macro (var) `(- ,var z))
           (let z 5
             ,x))))

;In that example, the eq data structure x absolutely must have
;different kinds of lexenvs saved.
;So it is labels introduced by the pseudo-compiler that we must deal with.

;... Hmm...
;Let's see.
;We are compiling one expression: the main expression.
;In general, we might have several closures that we are compiling
;all at once.
;[Must think about trees, btw.]
;

;[sleep cycle]
;So, if I were to evaluate this:

#;(fn (n)
  (list (fn (x) (+ x n))
        (fn (x) (+ x n))))

;Then I would basically get this:

#;(FIX λ1-code (fn (n)
               (let λ2 (list 'closure λ2-ex (obj n n))
                 (let λ3 (list 'closure λ3-ex (obj n n))
                   (list λ2 λ3))))
     λ1-ex (fn (ev n) (λ1-code n))
     λ2-code (fn (ev x) (+ x ev!n))
     λ2-ex (fn (ev x) (λ2-code ev x))
     λ3-code (fn (ev x) (+ x ev!n))
     λ3-ex (fn (ev x) (λ3-code ev x))
     
     (list 'closure λ1-ex nil))

;In that case... the only closures whose envs I'd be ambig. about
;would be those who'd be like

#;(fn (n)
  ((macro (x) (if (oracle)
                  `(let + -
                     ,x)
                  x))
   (fn (u) (+ n u))))

;And in that case... there would be little I could do.
;(In general, code may inevitably lead to macro-expansion at runtime.)
;I could expand each branch of it, I guess, but mmm...
;So. Anyway.
;(... Hmm. Can I rely on the path actually taken to store a compiled
; version of that branch? Mmm...)
;(Ok, in _that_ case, the macro is at least known at compile time, so
; that's a bad example. Both branches would be expanded and it'd be
; easy to create separate closures. In that example, we'd get:)

#;(FIX λ1-code (fn (ev u) (ev!+ ev!n u))
     ;or even
             (fn (ev u) (--function ev!n u))
     ;because that'd be known at closure creation time.
     λ2-code (fn (ev u) (+ ev!n u))
     ...)

;A more terrifying example is:

#;(fn (n)
  ((oracle)
   (fn (u) (+ n u))))

;In that case, I might still use teh heuristics.

#;(fn (n)
  (let v1 (oracle)
    (if (isa v1 'mac)
        (eval (apply-mac v1 '(fn (u) (+ n u))) (current-ev))
        (let λ1 (list 'closure (fn (ev u) (+ ev!n u)) (current-ev))
          (funcall v1 λ1)))))

;funcall separate from apply... mmm...
;that shit should happen whenn I get "(apply ... 'nil)".
;anyway.
;I guess, uh...
;I guess closures' "ex" code can know what kind of envs
;they are passed.  ... hmm...
;that is certainly a true statement.
;it'll just be difficult to eliminate envs completely without
;completely compiling the closure.
;e.g. in:

#;(fn (n)
  (prn n)
  (fn (u) (dick ass u)))

;we must figure out what (dick ass u) expands to, and discover that
;it does not contain any references to n, to be sure.
;in fact, we must also know that won't change btwn closure creation
;(which is when we'd check our mailbox first) and when it's called
;at any point in the future. actually that is prob. impossible.
;well, at least this is already allocating a closure anyway.
;so allocating a bit more for an env is tolerable.

;now...
;dick will know.

(withs
  p33 '(tt)
  p32 `(n ,@p33)
  p31 '(1)
  p30 `(n ,@p31)
  p29 `(+ ,@p32)
  p28 `(,p29)
  p27 `(- ,@p30)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  λ2-code (fn (f2 n1 tt1)
            (let ev4 (table 'f f2 'n n1 'tt tt1 'parent nil)
              (if (or (mailbox)
                      (no:and (not-in 'if nil)
                              (not-in 'is nil)))
                  (eval-progn p13 ev4) ;accually is recompile
                  (if (is-function n1 '0)
                      tt1
                      ;assuming (no (mailbox)), which is appropriate
                      (withs
                        v4 (eval p27 ev4)
                        v5 (map-eval p28 ev4)
                        v6 (cons v4 v5)
                        v3 (cons f2 v6)
                        (apply f2.0 f2.1
                               v3))))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code f2 n1 tt1))
  (if (mailbox) ;modifications of globvars as well as of code
      (eval p0 nil)
      (let λ2 (list 'closure λ2-ex nil)
        (λ2-code nil λ2 '1000 '0))))

;that's more like how it should go.
;actually, um.
;it should be like this.
;vectors and info table.

(withs
  p33 '(tt)
  p32 `(n ,@p33)
  p31 '(1)
  p30 `(n ,@p31)
  p29 `(+ ,@p32)
  p28 `(,p29)
  p27 `(- ,@p30)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  ev3-info (table)
  ev4-info (table 'parent 1 'f 2 'n 3 'tt 4)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (vector ev4-info ev3 f2 n1 tt1)
              (if (or (mailbox)
                      (no:and (not-in 'if ev4)
                              (not-in 'is ev4)))
                  (eval-progn p13 ev4) ;accually is recompile
                  (if (is-function n1 '0)
                      tt1
                      ;assuming (no (mailbox)), which is appropriate
                      (withs
                        v4 (eval p27 ev4)
                        v5 (map-eval p28 ev4)
                        v6 (cons v4 v5)
                        v3 (cons f2 v6)
                        (apply f2.0 f2.1
                               v3))))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (mailbox) ;modifications of globvars as well as of code
      (eval p0 nil)
      (let λ2 (list 'closure λ2-ex (vector ev3-info))
        (λ2-code (vector ev3-info) λ2 '1000 '0))))

;ok, and now... I guess we can have a rule that ...
;Goddammit, no. "info" data is single and you should not need
;multiple copies of it. Well, we don't make multiple copies
;of it. But you should not even need to have multiple pointers to
;it. As long as there's something that identifies λ2-code with the
;ev3-info it gets, then extra paths to ev3-info are redundant.

;So, then, how about...

(withs
  p33 '(tt)
  p32 `(n ,@p33)
  p31 '(1)
  p30 `(n ,@p31)
  p29 `(+ ,@p32)
  p28 `(,p29)
  p27 `(- ,@p30)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  ev3-info (table)
  ev4-info (table 'parent 0 'f 1 'n 2 'tt 3 'parent-info ev3-info)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (vector ev3 f2 n1 tt1)
              (if (or (mailbox)
                      (no:and (not-in 'if ev4 ev4-info)
                              (not-in 'is ev4 ev4-info)))
                  (eval-progn p13 ev4) ;accually is recompile
                  (if (is-function n1 '0)
                      tt1
                      ;assuming (no (mailbox)), which is appropriate
                      (withs
                        v4 (eval p27 ev4)
                        v5 (map-eval p28 ev4)
                        v6 (cons v4 v5)
                        v3 (cons f2 v6)
                        (apply f2.0 f2.1
                               v3))))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (mailbox) ;modifications of globvars as well as of code
      (eval p0 nil)
      (let λ2 (list 'closure λ2-ex nil)
        (λ2-code nil λ2 '1000 '0))))

;Hey, actually. I can go back around and have the info things be
;the arglists, in list form isomorphic to the vectors.

(withs
  p33 '(tt)
  p32 `(n ,@p33)
  p31 '(1)
  p30 `(n ,@p31)
  p29 `(+ ,@p32)
  p28 `(,p29)
  p27 `(- ,@p30)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  ev3-info 'nil
  ev4-info `(,ev3-info f n tt)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (vector ev3 f2 n1 tt1)
              (if (or (mailbox)
                      (no:and (not-in 'if ev4 ev4-info)
                              (not-in 'is ev4 ev4-info)))
                  (eval-progn p13 ev4 ev4-info) ;accually is recompile
                  (if (is-function n1 '0)
                      tt1
                      ;assuming (no (mailbox)), which is appropriate
                      (withs
                        v4 (eval p27 ev4 ev4-info)
                        v5 (map-eval p28 ev4 ev4-info)
                        v6 (cons v4 v5)
                        v3 (cons f2 v6)
                        (apply f2.0 f2.1
                               v3))))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (mailbox) ;modifications of globvars as well as of code
      (eval p0 nil nil)
      (let λ2 (list 'closure λ2-ex nil)
        (λ2-code nil λ2 '1000 '0))))

;Egad, clogging up eval.  This is so terrible.
;Ok, then where is eval going to find the ev-info?
;It probably really should be a part of the ev structure.
;Hmm... ugliness, ugliness...
;Oh, hey, maybe a closure should compile to code that
;creates a dumb env as the interpreter would like it.
;... And if there are side effects?  No.

;Hmm, how about this.

(withs
  p33 '(tt)
  p32 `(n ,@p33)
  p31 '(1)
  p30 `(n ,@p31)
  p29 `(+ ,@p32)
  p28 `(,p29)
  p27 `(- ,@p30)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  ev3-info 'nil
  ev4-info `(,ev3-info f n tt)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (vector ev3 f2 n1 tt1)
              (let ev4+info (cons ev4 ev4-info)
                (if (or (mailbox)
                        (no:and (not-in 'if ev4+info)
                                (not-in 'is ev4+info)))
                    (eval-progn p13 ev4+info) ;accually is recompile
                    (if (is-function n1 '0)
                        tt1
                        ;assuming (no (mailbox)), which is appropriate
                        (withs
                          v4 (eval p27 ev4+info)
                          v5 (map-eval p28 ev4+info)
                          v6 (cons v4 v5)
                          v3 (cons f2 v6)
                          (apply f2.0 f2.1
                                 v3)))))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (mailbox) ;modifications of globvars as well as of code
      (eval p0 nil)
      (let λ2 (list 'closure λ2-ex nil)
        (λ2-code nil λ2 '1000 '0))))

;this still sucks...
;jesus...
;it seems that either I use an efficient (vector) data structure
;in the interpreter, so that it would create its closures
;using vectors always, or I figure out about replacing one
;data structure with another as an optimization.

;I guess I could also do:
;--no...

;an option: have the interpreter's env be a list of locations,
;as in ((a v1 0) (b v1 1) (x v2 0) ...).
;or (x v1 2 0)...
;somewhat terrible.
;(also somewhat raw and awesome)
;mmm... but the interpreter must still get el informationo
;somehow. two arguments somehow, which is what I objected to
;before. ... is it really so bad? it's how I'd handle dynamic
;variables like stdin. (truly it'd be "thread-local crap",
; although if a thread creates another thread or saves a
; continuation or closure, then... eh, I suppose it's smthg else)

;Ok, I have an idea I like.
;(def eval (x (o env nil) (o env-info))
;  (if ($.vector? env)
;      (if env-info
;          (real-eval x env env-info)
;          (err "How does I read this shit?" x env))
;      ;otherwise it is assumed to be ((var1 val1) ...)
;      ;and is converted
;      ;and our preferred rep. is a list mimicking the
;      ;structure of the environment.
;      ;(less effic. at runtime than a hash table, prob., but
;      ; simpler and we expect to optimize it out anyway)
;      (with env-info 
;--

;I guess maybe it should be possible to make unholy things...
;like an env with two parent envs.
;(oh god cyclic)
;well, feh, whatever.
;how about optional and keyword args?
;... they don't belong in the env representation.
;by the time variables are bound in an env, all destructuring
;should be done.
;anyway, should the user have to supply a flat env to eval?
;it doesn't seem to really make sense to do anything else...
;... user probably wouldn't gain access to the envs of existing
;closures... but wtvr
;... feh, whatever, flat env, sure.

;--
;      (with env-info (map car env)
;            env ($.list->vector (map cadr env))
;        (real-eval x env env-info))))

;Welp.
;There we go.
;Well then.
;"lookup x env env-info" will look like this:
;env-info is either nil or a list of vars (symbols) and
;possibly a parent env.
;... will I assume only one parent env?
;mmm...
;I think I will not.
;d'oh, this is kind of terrible.
;vars bound at the current level must shadow vars bound in parents.
;how about vars bound in a couple of parent branches?
;obvious thing is to take a left-first search.
;likewise, if x is bound twice, I'll get the first.
#;(w/uniq failure
  (def lookup (x env env-info)
    (let u (lookup1 x env env-info)
      (if (is u failure)
          (symbol-value x)
          u)))
  (def lookup1 (x env env-info)
    (aif (pos x env-info)
         ($.vector-ref env it)
         (xloop (i 0 ei env-info)
           (if no.ei
               failure
               acons:car.ei
               (let u (lookup1 x ($.vector-ref env i) car.ei)
                 (if (is u failure)
                     (next (+ i 1) cdr.ei)
                     u))
               (next (+ i 1) cdr.ei))))))

;Jesus christ.
;That's bad.
;How about:
(def lookup (x env env-info)
  (aif (pos x env-info)
       ($.vector-ref env it)
       (pos acons env-info)
       (lookup x ($.vector-ref env it) env-info.it)
       (symbol-value x)))

;Or, if we get to assume that parent is env.0 if anything, then:
(def lookup (x env env-info)
  (aif (pos x env-info)
       ($.vector-ref env it)
       (and acons.env-info acons:car.env-info)
       (lookup x ($.vector-ref env 0) car.env-info)
       (symbol-value x)))

;Or, if we get to assume that envs always have (poss. nil) parent
;ptrs, then:
(def lookup (x env env-info)
  (aif (pos x env-info)
       ($.vector-ref env it)
       no.env-info
       (symbol-value x)
       (lookup x ($.vector-ref env 0) car.env-info)))

;At any rate, they should all get inlined into the same thing--
;except that the first one requires slightly sophisticated
;reasoninng to determine that gensyms are unique and that
;(w/uniq failure ... (is x failure)) can only happen with dick.
;Sigh... CPS time?
;Or perhaps even construction time.

#;(def lookup (x env env-info)
  (lookup1 x env env-info
           (fn (v) v) (fn () (symbol-value x))))

#;(def lookup1 (x env env-info ret fail)
  (aif (pos x env-info)
       (ret ($.vector-ref env it))
       (xloop (i 0 ei env-info)
         (if no.ei
             (fail)
             acons:car.ei
             (lookup1 x ($.vector-ref env i) car.ei
                      ret (fn () (next inc.i cdr.ei)))
             (next inc.i cdr.ei)))))

;Actually can be done better.  Noob.
#;(def lookup (x env env-info)
  (lookup1 x env env-info
           (fn () (symbol-value x))))

#;(def lookup1 (x env env-info fail)
  (aif (pos x env-info)
       ($.vector-ref env it)
       (xloop (i 0 ei env-info)
         (if no.ei
             (fail)
             acons:car.ei
             (lookup1 x ($.vector-ref env i) car.ei
                      (fn () (next inc.i cdr.ei)))
             (next inc.i cdr.ei)))))

;I think that should not be any problem to inline, but...
;If absolutely necessary, I can use the version that assumes
;no dicks.
;... Or I can do the construction version.

#;(def lookup (x env env-info)
  (lookup1 x env env-info
           nil))

#;(def lookup1 (x env env-info nexts)
  (aif (pos x env-info)
       ($.vector-ref env it)
       (let nexts (join (accum a
                          (on xs env-info
                            (when acons.xs
                              (a:list ($.vector-ref env index) xs))))
                        nexts)
         (if no.nexts
             (symbol-value x)
             (lookup1 x nexts.0.0 nexts.0.1 cdr.nexts)))))

;Just tested that last shit and it works.
;Anyway, dick should be eqv to this.

;(Incidentally, env-info could conceivably be a field in the
; closure, but suck. Closure should have a field pointing to
; some central repository of info on closures of that type,
; and that in itself could contain that info. I've been over
; that before. However, eval must still be passed the info
; somehow, and I don't think it would appreciate being passed
; the closure. So this is the right approach.)

;So.  That method of lookup, and so on.
       

(withs
  p33 '(tt)
  p32 `(n ,@p33)
  p31 '(1)
  p30 `(n ,@p31)
  p29 `(+ ,@p32)
  p28 `(,p29)
  p27 `(- ,@p30)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  ev3-info 'nil
  ev4-info `(,ev3-info f n tt)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (vector ev3 f2 n1 tt1)
              (if (or (mailbox)
                      (no:and (not-in 'if ev4 ev4-info)
                              (not-in 'is ev4 ev4-info)))
                  (eval-progn p13 ev4 ev4-info) ;accually is recompile
                  (if (is-function n1 '0)
                      tt1
                      ;assuming (no (mailbox)), which is appropriate
                      (withs
                          v4 (eval p27 ev4 ev4-info)
                        v5 (map-eval p28 ev4 ev4-info)
                        v6 (cons v4 v5)
                        v3 (cons f2 v6)
                        (apply f2.0 f2.1
                               v3))))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (mailbox) ;modifications of globvars as well as of code
      (eval p0 nil nil)
      (let λ2 (list 'closure λ2-ex nil)
        (λ2-code nil λ2 '1000 '0))))

;Actually it should look like:

(withs
  p33 '(tt)
  p32 `(n ,@p33)
  p31 '(1)
  p30 `(n ,@p31)
  p29 `(+ ,@p32)
  p28 `(,p29)
  p27 `(- ,@p30)
  p26 `(,p27 ,@p28)
  p25 `(f ,@p26)
  p24 '(0)
  p23 `(n ,@p24)
  p22 `(f ,@p25)
  p21 `(,p22)
  p20 `(tt ,@p21)
  p19 `(is ,@p23)
  p18 `(,p19 ,@p20)
  p17 '(0)
  p16 `(1000 ,@p17)
  p15 `(f ,@p16)
  p14 `(if ,@p18)
  p13 `(,p14)
  p12 '(f n tt)
  p11 `(f ,@p15)
  p10 `(,p11)
  p9 '(f)
  p8 `(,p12 ,@p13)
  p5 `(fn ,p8)
  p4 `(,p9 ,@p10)
  p1 `(fn ,@p4)
  p2 `(,p5)
  p0 `(,p1 ,@p2)
  ev3-info 'nil
  ev4-info `(,ev3-info f n tt)
  λ2-code (fn (ev3 f2 n1 tt1)
            (let ev4 (vector ev3 f2 n1 tt1)
              (if (or (mailbox)
                      (isnt if-object (lookup 'if ev4 ev4-info))
                      (isnt is-function (lookup 'is ev4 ev4-info)))
                  (eval-progn p13 ev4 ev4-info) ;accually is recompile
                  (if (is-function n1 '0)
                      tt1
                      ;assuming (no (mailbox)), which is appropriate
                      (withs
                          v4 (eval p27 ev4 ev4-info)
                        v5 (map-eval p28 ev4 ev4-info)
                        v6 (cons v4 v5)
                        v3 (cons f2 v6)
                        (apply f2.0 f2.1
                               v3))))))
  λ2-ex (fn (ev3 f2 n1 tt1)
          (λ2-code ev3 f2 n1 tt1))
  (if (mailbox) ;modifications of globvars as well as of code
      (eval p0 nil nil)
      (let λ2 (list 'closure λ2-ex nil)
        (λ2-code nil λ2 '1000 '0))))

;[sleep cycle] Sigh, it would appear that for consistency we must
;put checks even after "CALL" things or the equivalent.
;(It happens that nothing I've done so far requires non-tail calls
; to non-primitives.)
;That until I can make stuff sophisticated enough to modify things
;on the stack.
;Or maybe I can assume that either it'll be sophisticated enough, or
;things will be fine if... ... ... or ....
;Neh, works to not have checks at return addresses on stack iff
;the code that updates/invalidates/modifies code manages to
;mess with things on stack.

;How do I do that sort of thing... It is conceivable that I could
;modify only the bottommost thing on the stack, to be something
;that says "modify the next thing on the stack to be this, as well
;as recompiling this function".
;That by itself would be insufficient if I had continuation-y stuff
;that was capable of doing "escape continuations".
;Though ...

;Read barriers on updated crap?
;Awmgaw.

;Maybe the 

;I rather dislike the idea of allocating return-closures on the heap,
;because that means that code that seems to me like it should not
;allocate any memory will allocate memory.  Also it might perform less
;efficiently, but in particular it will pollute the reports about
;memory allocation.  I guess it is conceivable that I could have it
;report allocations of different kinds of objects... and dicks...

;Still, at least as an exercise (and as something useful for programs
; that use crazy amounts of full general-purpose continuations),
;it would be a good thing to have something that alloc'd continuations
;on the heap to do everything.
;I could take the Appel approach... 

;Let's consider this stuff from the point of view of full continuations.
;The continuations I create will possibly lead to other continuations...

;Allocating objects on the stack is certainly nubbish.
;But... CALL and stuff... on x86 these are special forms.
;Also, when things are adjacently alloc'd on the stack, you don't need
;a pointer to the previous thing: it's the next thing on the stack.
;Allocating these pointers may be dick...
;Maybe I can come up with some compromise where if it happens to be
;alloc'd adjacently, then I don't need a pointer... and maybe crap
;can be overwritten later without a GC... that's basically what it
;would be.  Mmmph.

;Well... pointers, no stack, to begin with.
;Guh, such a concession.
;... Maybe I can use a stack for little dicks...
;(could even serve as an indicator of atomicity)
;--Hey.
;Can I have shit get specialized into using a stack within known loops?
;That would be the awesome.
;I guess that could depend on "escape analysis" or smthg.
;Control flow analysis.
;Hmm... overflow?
;Analysis must prove use of small-constant-bounded amount of stack space?
;Mmm...
;If you call an unknown closure, then it probably doesn't make too much
;difference to do this dicking with pointers and conts.
;So, it is probably fine if I have dicking be default and hope to make
;things work well with loops over all-known functions.

;Ok. Continuations are allocated.
;PG will be happy, at any rate.
;Now.
;Invalidation and dicks.
;...
;Calling the return continuation is unknown if you may have checked
;your mailbox.
;Inlined dick on the stack could eliminate this kind of, but ass.
;

;[sleep cycle]

;Thing I thought.
;Probably makes sense to try to not compile too much at once.
;This is probably pretty doable with continuations...


;Random idea.  Make reader continuation-safe.
;In case someone defines a read-macro that leaks continuations.
;Subsequent calls to the same continuation may produce structures
;that share structure, but one call may not mutate things returned
;by a previous call.

























