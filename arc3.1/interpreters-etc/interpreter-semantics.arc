(def s-reduce (f stm (o default))
  (if (no stm)
      default
      (xloop (s stm v s-car.stm)
        (if no.s
            v
            (next s-cdr.s (f v s-car.s))))))

;de-macro
((fn ()
   (sref signatures*
     '(f stm
       (o default))
     's-reduce)
   (sref definitions*
     '(fn (f stm
          (o default))
       (if
         (no stm)
         default
         (xloop
           (s stm v s-car.stm)
           (if no.s v
             (next s-cdr.s
               (f v s-car.s))))))
     's-reduce)
   ((fn ()
      (if
        (bound 's-reduce)
        ((fn ()
           (disp "*** redefining "
             (stderr))
           (disp 's-reduce
             (stderr))
           (disp #\newline
             (stderr)))))
      (assign s-reduce
        (fn (f stm
             (o default))
          (if
            (no stm)
            default
            (((fn (next)
                (assign next
                  (fn (s v)
                    (if
                      (no s)
                      v
                      (next
                        (s-cdr s)
                        (f v
                          (s-car s)))))))
               nil)
              stm
              (s-car stm)))))))))

;but that's not what we do.

(def s-reduce (f stm (o default))
  (if (no stm)
      default
      (xloop (s stm v s-car.stm)
        (if no.s
            v
            (next s-cdr.s (f v s-car.s))))))
;def is a known macro.
;(... to do this properly, it would appear that
; we'll have to splice in the def of "def" each time,
; and each time rederive some stuff... mmm.)

(do
  (sref signatures*
    '(f stm
      (o default))
    's-reduce)
  (sref definitions*
    '(fn (f stm
         (o default))
      (if
        (no stm)
        default
        (xloop
          (s stm v s-car.stm)
          (if no.s v
            (next s-cdr.s
              (f v s-car.s))))))
    's-reduce)
  (safeset s-reduce
    (fn (f stm
         (o default))
      (if
        (no stm)
        default
        (xloop
          (s stm v s-car.stm)
          (if no.s v
            (next s-cdr.s
              (f v s-car.s))))))))
;we don't even do that yet.  splice crap.
;it becomes this:
(eval/lex (($.vector-ref def 2)
           's-reduce
           '(f stm (o default))
           '(if (no stm)
                default
                (xloop (s stm v s-car.stm)
                  (if no.s
                      v
                      (next s-cdr.s (f v s-car.s))))))
          nil)
;and then... since this is being actually _called_ from
;toplevel, it seems we don't need to be uber-cautious.
;we are not compiling a function that calls eval-lex.
;we might compile a thunk which is immediately used and
;then tossed, or we might just plain run eval-lex.
;either way, we don't have to be tricky about side effects
;in the function of def.

(eval-lex
  '(do
    (sref signatures*
      '(f stm
        (o default))
      's-reduce)
    (sref definitions*
      '(fn (f stm
           (o default))
        (if
          (no stm)
          default
          (xloop
            (s stm v s-car.stm)
            (if no.s v
              (next s-cdr.s
                (f v s-car.s))))))
      's-reduce)
    (safeset s-reduce
      (fn (f stm
           (o default))
        (if
          (no stm)
          default
          (xloop
            (s stm v s-car.stm)
            (if no.s v
              (next s-cdr.s
                (f v s-car.s))))))))
  nil)

;now... I guess we macex 'do.
;the srefs are boring; they install a quoted list into a hash table.
;we are interested in s-reduce the fn.

(eval-lex
  '(safeset s-reduce
    (fn (f stm
         (o default))
      (if
        (no stm)
        default
        (xloop
          (s stm v s-car.stm)
          (if no.s v
            (next s-cdr.s
              (f v s-car.s)))))))
  nil)

;now... that will only do crap.
;it will do something like
(safeset s-reduce
  (fn args
    (apply
      (compile
        '(fn (f stm
             (o default))
          (if
            (no stm)
            default
            (xloop
              (s stm v s-car.stm)
              (if no.s v
                (next s-cdr.s
                  (f v s-car.s)))))))
      args)))

;and that function itself will be compiled.
;in doing so, it is conceivable that it would
;analyze and pre-do the call to "compile" there.
;but it might not, and probably will not.
;(if that compilation causes side effects, it must not.)
;anyway, we then become interested basically in that
;call to "compile". (it might need a lexenv argument)

;so...
(compile
  '(fn (f stm
       (o default))
    (if
      (no stm)
      default
      (xloop
        (s stm v s-car.stm)
        (if no.s v
          (next s-cdr.s
            (f v s-car.s)))))))

;we shall go through this...

(fn (f stm
     (o default))
  (eval-lex
    '(if
      (no stm)
      default
      (xloop
        (s stm v s-car.stm)
        (if no.s v
          (next s-cdr.s
            (f v s-car.s)))))
    (obj f f stm stm default default)))

;stuff...

(fn (f stm
       (o default))
  (eval-lex 
    '(if
      (no stm)
      default
      (xloop
        (s stm v s-car.stm)
        (if no.s v
          (next s-cdr.s
            (f v s-car.s)))))
    (obj f f stm stm default default)))

;and

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (eval-lex
      '(if
        (no stm)
        default
        (xloop
          (s stm v s-car.stm)
          (if no.s v
            (next s-cdr.s
              (f v s-car.s)))))
      env)))

;and then this step is basically trivial
;(if we were using cps, we might turn this into
; some form using if3)

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
(eval-lex         '(no stm) env)
(eval-lex         'default env)
(eval-lex         '(xloop
          (s stm v s-car.stm)
          (if no.s v
            (next s-cdr.s
              (f v s-car.s)))) env))))
;bwahaha I can be incredibly lazy about formatting 

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (eval-lex
        '(no stm)
        env)
      (eval-lex 'default env)
      (eval-lex
        '(xloop
          (s stm v s-car.stm)
          (if no.s v
            (next s-cdr.s
              (f v s-car.s))))
        env))))
;now...
;"no" is known to be a fn...
;so I guess we can turn (eval '(known-fn arg arg))
;into (known-fn (eval 'arg) (eval 'arg)).

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no (eval-lex 'stm env))
      (eval-lex 'default env)
      (eval-lex
        '(xloop
          (s stm v s-car.stm)
          (if no.s v
            (next s-cdr.s
              (f v s-car.s))))
        env))))

;and then the lookups.

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (eval-lex
        '(xloop
          (s stm v s-car.stm)
          (if no.s v
            (next s-cdr.s
              (f v s-car.s))))
        env))))

;now xloop is a known macro.

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (eval-lex
        (($.vector-ref xloop 2)
          '(s stm v s-car.stm)
          '(if no.s v
            (next s-cdr.s
              (f v s-car.s))))
        env))))

;now... xloop is a constant we know about.

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (eval-lex
        ('(closure nil
                   (fn (binds . body)
                     `((rfn next
                         ,(map car pair.binds)
                         ,@body)
                       ,@(map cadr pair.binds))))

          '(s stm v s-car.stm)
          '(if no.s v
            (next s-cdr.s
              (f v s-car.s))))
        env))))

;now... a closure can be called...
;oh man. oh god. take a look.

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (eval-lex
        (eval-lex
          '`((rfn next
             ,(map car pair.binds)
             ,@body)
            ,@(map cadr pair.binds))
          '((binds
             (s stm v s-car.stm))
            (body
              ((if no.s v
                 (next s-cdr.s
                   (f v s-car.s)))))))
        env))))

;hoh my god.
;well.

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (eval-lex
        (let env2
            '((binds
               (s stm v s-car.stm))
              (body
                ((if no.s v
                   (next s-cdr.s
                     (f v s-car.s))))))
          (eval-lex
            '`((rfn next
               ,(map car pair.binds)
               ,@body)
              ,@(map cadr pair.binds))
            env2))
        env))))

;... now we anti-bq
;oh boy.
`((rfn next
    ,(map car pair.binds)
    ,@body)
  ,@(map cadr pair.binds))
;now
(cons `(rfn next
         ,(map car pair.binds)
         ,@body)
  (map cadr pair.binds))
;and now
(cons
  (cons 'rfn
    (cons 'next
      (cons
        (map car pair.binds)
        body)))
  (map cadr pair.binds))
;this is all quoted. k.

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (eval-lex
        (let env2
            '((binds
               (s stm v s-car.stm))
              (body
                ((if no.s v
                   (next s-cdr.s
                     (f v s-car.s))))))
          (eval-lex
            '(cons
              (cons 'rfn
                (cons 'next
                  (cons
                    (map car pair.binds)
                    body)))
              (map cadr pair.binds))
            env2))
        env))))

;note that it is a plain call to eval-lex, despite being nested.
;it is nothing special to optimize that.
;... issues with inducing extra sharing?
;no. (eval '(cons x y)) is the same as (cons (eval 'x) (eval 'y)).
;... sigh. well, there we go.

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (eval-lex
        (let env2
            '((binds
               (s stm v s-car.stm))
              (body
                ((if no.s v
                   (next s-cdr.s
                     (f v s-car.s))))))
          (cons
            (eval-lex
              '(cons 'rfn
                (cons 'next
                  (cons
                    (map car pair.binds)
                    body)))
              env2)
            (eval-lex
              '(map cadr pair.binds)
              env2)))
        env))))

;and then... cons is known again, let's get those.

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (eval-lex
        (let env2
            '((binds
               (s stm v s-car.stm))
              (body
                ((if no.s v
                   (next s-cdr.s
                     (f v s-car.s))))))
          (cons
            (cons
              (eval-lex ''rfn env2)
              (eval-lex
                '(cons 'next
                  (cons
                    (map car pair.binds)
                    body))
                env2))
            (eval-lex
              '(map cadr pair.binds)
              env2)))
        env))))

;I think I'm doing this right... jesus.
(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (eval-lex
        (let env2
            '((binds
               (s stm v s-car.stm))
              (body
                ((if no.s v
                   (next s-cdr.s
                     (f v s-car.s))))))
          (cons
            (cons 'rfn
              (cons
                (eval-lex ''next env2)
                (eval-lex
                  '(cons
                    (map car pair.binds)
                    body)
                  env2)))
            (eval-lex
              '(map cadr pair.binds)
              env2)))
        env))))
;oh boy.

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (eval-lex
        (let env2
            '((binds
               (s stm v s-car.stm))
              (body
                ((if no.s v
                   (next s-cdr.s
                     (f v s-car.s))))))
          (cons
            (cons 'rfn
              (cons 'next
                (cons
                  (eval-lex
                    '(map car pair.binds)
                    env2)
                  (eval-lex 'body env2))))
            (eval-lex
              '(map cadr pair.binds)
              env2)))
        env))))

;am making use of crap to be lazy about manual formatting
;now map is a known fn

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (eval-lex
        (let env2
            '((binds
               (s stm v s-car.stm))
              (body
                ((if no.s v
                   (next s-cdr.s
                     (f v s-car.s))))))
          (cons
            (cons 'rfn
              (cons 'next
                (cons
                  (map
                    (eval-lex 'car env2)
                    (eval-lex 'pair.binds env2))
                  (eval-lex 'body env2))))
            (eval-lex
              '(map cadr pair.binds)
              env2)))
        env))))

;then car will be a global variable, but... stuff
;ssexpand

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (eval-lex
        (let env2
            '((binds
               (s stm v s-car.stm))
              (body
                ((if no.s v
                   (next s-cdr.s
                     (f v s-car.s))))))
          (cons
            (cons 'rfn
              (cons 'next
                (cons
                  (map
                    car
                    (eval-lex '(pair binds) env2))
                  (eval-lex 'body env2))))
            (eval-lex
              '(map cadr pair.binds)
              env2)))
        env))))
;dick
(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (eval-lex
        (let env2
            '((binds
               (s stm v s-car.stm))
              (body
                ((if no.s v
                   (next s-cdr.s
                     (f v s-car.s))))))
          (cons
            (cons 'rfn
              (cons 'next
                (cons
                  (map
                    car
                    (pair (eval-lex 'binds env2)))
                  (eval-lex 'body env2))))
            (eval-lex
              '(map cadr pair.binds)
              env2)))
        env))))
;finally we get something interesting
;...
;note that, while the quote will appear in a few places,
;(i.e. '((if no.s ...)) )
;they should still refer to the identical list.
;which will be the case if this is running in a compiler.


;btw, if none of this code escapes, then we can afford to allocate
;it just the once. this is just like with gensyms.
;(conses can be used as gensyms as long as you don't expect them
; to have type 'sym)

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (eval-lex
        (let env2
            '((binds
               (s stm v s-car.stm))
              (body
                ((if no.s v
                   (next s-cdr.s
                     (f v s-car.s))))))
          (cons
            (cons 'rfn
              (cons 'next
                (cons
                  (map car
                    (pair
                      '(s stm v s-car.stm)))
                  '((if no.s v
                     (next s-cdr.s
                       (f v s-car.s)))))))
            (eval-lex
              '(map cadr pair.binds)
              env2)))
        env))))

;"pair" will be known too... all of this will be known...
;anyway, now we can clean up that last crap

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (eval-lex
        (let env2
            '((binds
               (s stm v s-car.stm))
              (body
                ((if no.s v
                   (next s-cdr.s
                     (f v s-car.s))))))
          (cons
            (cons 'rfn
              (cons 'next
                (cons
                  (map car
                    (pair
                      '(s stm v s-car.stm)))
                  '((if no.s v
                     (next s-cdr.s
                       (f v s-car.s)))))))
            (map
              (eval-lex 'cadr env2)
              (eval-lex 'pair.binds env2))))
        env))))

;cadr is cadr, and ssexpand

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (eval-lex
        (let env2
            '((binds
               (s stm v s-car.stm))
              (body
                ((if no.s v
                   (next s-cdr.s
                     (f v s-car.s))))))
          (cons
            (cons 'rfn
              (cons 'next
                (cons
                  (map car
                    (pair
                      '(s stm v s-car.stm)))
                  '((if no.s v
                     (next s-cdr.s
                       (f v s-car.s)))))))
            (map cadr
              (eval-lex
                '(pair binds)
                env2))))
        env))))

;pair is known fn

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (eval-lex
        (let env2
            '((binds
               (s stm v s-car.stm))
              (body
                ((if no.s v
                   (next s-cdr.s
                     (f v s-car.s))))))
          (cons
            (cons 'rfn
              (cons 'next
                (cons
                  (map car
                    (pair
                      '(s stm v s-car.stm)))
                  '((if no.s v
                     (next s-cdr.s
                       (f v s-car.s)))))))
            (map cadr
              (pair
                (eval-lex 'binds env2)))))
        env))))

;and look up binds

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (eval-lex
        (let env2
            '((binds
               (s stm v s-car.stm))
              (body
                ((if no.s v
                   (next s-cdr.s
                     (f v s-car.s))))))
          (cons
            (cons 'rfn
              (cons 'next
                (cons
                  (map car
                    (pair
                      '(s stm v s-car.stm)))
                  '((if no.s v
                     (next s-cdr.s
                       (f v s-car.s)))))))
            (map cadr
              (pair
                '(s stm v s-car.stm)))))
        env))))

;now... env2 can be dropped

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (eval-lex
        (cons
          (cons 'rfn
            (cons 'next
              (cons
                (map car
                  (pair
                    '(s stm v s-car.stm)))
                '((if no.s v
                   (next s-cdr.s
                     (f v s-car.s)))))))
          (map cadr
            (pair
              '(s stm v s-car.stm))))
        env))))

;and now...
;somehow we should know that the above code will not escape
;and will not be messed with
;and therefore we can construct those data structures once.

;it seems that, since 'rfn is a macro and basically you can't
;determine without macro-expanding that the above code will
;not do any shenanigans, we will again have to _speculatively_
;compile the above code. if we fail to prove that the code
;will not escape, then it must all be abandoned and the above
;form will be the compiled code.

;I suppose it is conceivable to have the fallback thing be
;either some kind of copy-on-write data structure...
;or some direct "if we go on a code path where this code escapes,
; then copy all the above" if-thing, and maybe eventually that
; if-path will just be found to never be taken.
;(another option is to complain to the user, and for the user
; to be frustrated at how slow everything runs until he teaches
; his compiler to be smarter.)

;ok, um...

;I think the direct if-thing would be very nice.
;how exactly?
;should be a low-level, simple conversion process...

;(I think I'll be basically getting CIRCULARIZE to work)

;... gensym seems a bit different... if you make a new gs,
;it won't be eq to the old... I suppose you could make updated
;env structures or smthg.

;this would be so amusing.
;you'd write code with gensym, and according to my semantics,
;you'd get code that ran efficiently, with no reference to gensyms,
;except for a little statement that incremented a gensym counter.
;bwahaha. kind of awesome. built-in gensym should somehow avoid that.
;maybe it's possible for someone to build a gensym that, according
;to this scheme, automatically avoids that, but still works fine.

;...
;ok, so...
;closest thing that corresponds to crap is lazy evaluation, um...

;seems like I probably want a version of eval
;which takes, as well as an expression, a "fresh copy" of the
;expression.
;or perhaps a thunk that, when called, produces that expression.
;(memoized. delay/force semantics.)
;that would still involve an unacceptable bit of overhead.
;(allocating memory where that should not be required)
;so I think I shall start with just strictly constructing crap.

;btw, prob. should not construct more than is necessary.
;e.g. don't construct a full expression when you actually err out
;of it before most of the code would need to be compiled.
;

;(I am thinking of an analogy with instruction caches...)

;semantics: the runtime is executing a copy of the expression, though
;it will ensure that if code was written that modified the expression,
;then it will work with the modified expression.
;this "copy" may have been constructed earlier, of course.
;or constructed partially of old things and partially of new things.
;jesus christ.


;k, um...

;gw'oh, fuck.
;must keep track of scar/scdrs that modify the
;canonical copy of the code, or something... ?
;hmm...
;with an interpreter, certainly, if you modify the code,
;it will affect later executions... even with a closure...
;this goes even if you (scdr '(1 2) '(2)), because that may
;have implications if that '(2) pair is modified from smwhr else.
;so... I guess, if you wanted to check whether code had been changed,
;you would have to list out every object and compare them eq-wise.
;which is quite expensive...
;...
;maybe you could at least just separate out the checks...
;hmm...
;everything must be inlined.
;this stuff can only happen with inlined/known functions.
;otherwise they might modify things.
;(this is a conclusion I repeatedly come to)
;... well...
;damn. what might be modified is the source code.
;i.e. before macroexpansion.
;what is this macroexpansion shit?
;it might be arbitrarily complicated (e.g. version of xloop doing
; smthg diff depending on how many 'fns there are inside "body"),
;unless you inline that.
;in that case... jesus christ, I must inline everything.
;and record what things I assume with every computation.
;...
;shall I do that now, or shall I just proceed with dicks?
;...
;I think if I proceed, I'll encounter more issues...
;well, gargh; for now let's practice and let's assume that no one
;will ever modify code. though we must still do all the "extra argument
;that is a proper version of code to be returned if necessary" thing.

;then...
;function: (eval-lc expr expr-copy env).

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (let expr-copy
          (cons
            (cons 'rfn
              (cons 'next
                (cons
                  (map car
                    (pair
                      '(s stm v s-car.stm)))
                  '((if no.s v
                     (next s-cdr.s
                       (f v s-car.s)))))))
            (map cadr
              (pair
                '(s stm v s-car.stm))))
        (eval-lc
          '((rfn next
             (s v)
             (if no.s v
               (next s-cdr.s
                 (f v s-car.s))))
            stm s-car.stm)
          expr-copy env)))))

;now... jez' chriz'...
;that expr-copy thing is to pass around to subsequent evals.
;in case there are macex's.

;... what if the macex compares cons cells for equality with some
;that exist elsewhere?
;... no, silly.
;if macros are expanded, then you hand them the expr-copy.
;that is the rule.
;it's just that ...
;hmm.
;ok:
;if you are unable to do all macro expansion safely at compile time
;(e.g. because it has side effects that you cannot isolate, or...
; more like, because it reads information from elsewhere and writes
; information to elsewhere),
;then you leave it with a call that uses expr-copy.
;... well, let's try.

;... guh, this is too difficult.
;I shall write it in terms of expr-copy,
;and only then do weird crap.

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (with xc
        (cons
          (cons 'rfn
            (cons 'next
              (cons
                (map car
                  (pair
                    '(s stm v s-car.stm)))
                '((if no.s v
                   (next s-cdr.s
                     (f v s-car.s)))))))
          (map cadr
            (pair
              '(s stm v s-car.stm))))
        x
        '((rfn next
           (s v)
           (if no.s v
             (next s-cdr.s
               (f v s-car.s))))
          stm s-car.stm)
        (let
            (f . xs)
            xc
          (let u
              (eval-lex f env)
            (if is-macro.u
              (eval-lex
                (apply
                  ($.vector-ref u 2)
                  xs)
                env)
              ;ignoring other cases
              (apply u
                (map
                  [ueval _ env]
                  xs)))))))))

;that is what we basically get by inlining eval a bit.
;now, retroactively, we can do a little dicking...
;...
;...
;...
;...
;um. do I even necessarily need to screw around?
;it feels like not.  I'll leave the binding of x in
;for the moment, but dick.
;now, to combine several steps, we can throw away
;the binding of xc and directly bind f and xs.

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (with f
        (cons 'rfn
          (cons 'next
            (cons
              (map car
                (pair
                  '(s stm v s-car.stm)))
              '((if no.s v
                 (next s-cdr.s
                   (f v s-car.s)))))))
        xs
        (map cadr
          (pair
            '(s stm v s-car.stm)))
        x
        '((rfn next
           (s v)
           (if no.s v
             (next s-cdr.s
               (f v s-car.s))))
          stm s-car.stm)
        (let u
            (eval-lex f env)
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))

;hmm... it is inlining eval-lex that may lead to interesting
;things...
;really, in CPS or in ANF, there would be names for all the
;intermediate structures there. I wouldn't have to invent
;new names and crap.
;ok, time to drop x, as well as absolutely decomposing the f
;and xs crap.
;tempted to suggest doing that by machine, but... mmm...

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (withs a1 '(s stm v s-car.stm)
        a2 (pair
                  a1)
          a3 (map car
                a2)
        a4 '((if no.s v
                 (next s-cdr.s
                   (f v s-car.s))))
        a5 (cons
              a3
              a4)
        a6 (cons 'next
            a5)
        
        
          f  (cons 'rfn
          a6)
        
        a7 '(s stm v s-car.stm)
        a8 (pair
            a7)
        
        xs
        (map cadr
          a8)
        
        (let u
            (eval-lex f env)
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))
;hohohoh, cut and paste and typing.
;take expr, cut it and write a[n], then add "a[n] <paste>" above.
;relatively nice.
;now cleanup with dpprn.

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (withs a1
        '(s stm v s-car.stm)
        a2
        (pair a1)
        a3
        (map car a2)
        a4
        '((if no.s v
           (next s-cdr.s
             (f v s-car.s))))
        a5
        (cons a3 a4)
        a6
        (cons 'next a5)
        f
        (cons 'rfn a6)
        a7
        '(s stm v s-car.stm)
        a8
        (pair a7)
        xs
        (map cadr a8)
        (let u
            (eval-lex f env)
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))

;hohohoh. now, since f is constructed like this,
;we shall be able to expand some stuff at compile time
;as we are doing.
;there are kind of two rules, then.
;you can rely on quoted exprs to have the structure they have
;(e.g. the car is this and the cdr is that)
;and you can rely on just-constructed exprs to have the
;structure they have.
;...
;these can kind of be equivocated and kind of not.
;in general, there probably will be a certain amount of quoted
;expressions. mmm. anyway.
;... if a macro stores a copy of its args somewhere, but
;otherwise does some behavior that we should know how to optimize,
;will we be able to figure out how to optimize it?
;we may see.

;so, we will expand (eval-lex f env).
;we will ... do some conditionalizing in our heads.
;we find f, which will be called x in ueval (heh6.arc),
;is a list and is not a special object... so.

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (withs a1
        '(s stm v s-car.stm)
        a2
        (pair a1)
        a3
        (map car a2)
        a4
        '((if no.s v
           (next s-cdr.s
             (f v s-car.s))))
        a5
        (cons a3 a4)
        a6
        (cons 'next a5)
        f
        (cons 'rfn a6)
        a7
        '(s stm v s-car.stm)
        a8
        (pair a7)
        xs
        (map cadr a8)
        (let u
            (let (f2 . xs2) f
              (let u2 (eval-lex f2 env)
                (if ...)))
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))

;now, f is ('rfn . a6). so.

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (withs a1
        '(s stm v s-car.stm)
        a2
        (pair a1)
        a3
        (map car a2)
        a4
        '((if no.s v
           (next s-cdr.s
             (f v s-car.s))))
        a5
        (cons a3 a4)
        a6
        (cons 'next a5)
        f
        (cons 'rfn a6)
        a7
        '(s stm v s-car.stm)
        a8
        (pair a7)
        xs
        (map cadr a8)
        (let u
            (with f2 'rfn xs2 a6
              (let u2 (eval-lex f2 env)
                (if ...)))
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))

;that (if ...) actually contains an "err "... no, it doesn't.
;so we can drop the binding of f itself.

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (withs a1
        '(s stm v s-car.stm)
        a2
        (pair a1)
        a3
        (map car a2)
        a4
        '((if no.s v
           (next s-cdr.s
             (f v s-car.s))))
        a5
        (cons a3 a4)
        a6
        (cons 'next a5)
        a7
        '(s stm v s-car.stm)
        a8
        (pair a7)
        xs
        (map cadr a8)
        (let u
            (with f2 'rfn xs2 a6
              (let u2 (eval-lex f2 env)
                (if ...)))
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))

;now, replace refs to f2 with 'rfn (there is only one;
; there will be many refs to u2 and to xs2)

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (withs a1
        '(s stm v s-car.stm)
        a2
        (pair a1)
        a3
        (map car a2)
        a4
        '((if no.s v
           (next s-cdr.s
             (f v s-car.s))))
        a5
        (cons a3 a4)
        a6
        (cons 'next a5)
        a7
        '(s stm v s-car.stm)
        a8
        (pair a7)
        xs
        (map cadr a8)
        (let u
            (with f2 'rfn xs2 a6
              (let u2 (eval-lex 'rfn env)
                (if ...)))
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))

;combining into two steps: drop the f2 binding, and...
;'rfn. oh boy. known global dick.
;expand (if ...) a little.

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (withs a1
        '(s stm v s-car.stm)
        a2
        (pair a1)
        a3
        (map car a2)
        a4
        '((if no.s v
           (next s-cdr.s
             (f v s-car.s))))
        a5
        (cons a3 a4)
        a6
        (cons 'next a5)
        a7
        '(s stm v s-car.stm)
        a8
        (pair a7)
        xs
        (map cadr a8)
        (let u
            (with xs2 a6
              (let u2 rfn
                (if is-macro.u2
                    (eval-lex (apply-mac u2 xs2) env)
                    (...))))
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))

;and, of course, rfn is a macro.

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (withs a1
        '(s stm v s-car.stm)
        a2
        (pair a1)
        a3
        (map car a2)
        a4
        '((if no.s v
           (next s-cdr.s
             (f v s-car.s))))
        a5
        (cons a3 a4)
        a6
        (cons 'next a5)
        a7
        '(s stm v s-car.stm)
        a8
        (pair a7)
        xs
        (map cadr a8)
        (let u
            (with xs2 a6
              (eval-lex (apply ($.vector-ref rfn 2) xs2) env))
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))

;replace xs2 with a6; drop binding

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (withs a1
        '(s stm v s-car.stm)
        a2
        (pair a1)
        a3
        (map car a2)
        a4
        '((if no.s v
           (next s-cdr.s
             (f v s-car.s))))
        a5
        (cons a3 a4)
        a6
        (cons 'next a5)
        a7
        '(s stm v s-car.stm)
        a8
        (pair a7)
        xs
        (map cadr a8)
        (let u
            (eval-lex
              (apply
                ($.vector-ref rfn 2)
                a6)
              env)
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))

;oh boy. the n-args behavior of apply is nice. can be incremental
;and stupid. (apply f (cons x xs)) -> (apply f x xs).

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (withs a1
        '(s stm v s-car.stm)
        a2
        (pair a1)
        a3
        (map car a2)
        a4
        '((if no.s v
           (next s-cdr.s
             (f v s-car.s))))
        a5
        (cons a3 a4)
        a6
        (cons 'next a5)
        a7
        '(s stm v s-car.stm)
        a8
        (pair a7)
        xs
        (map cadr a8)
        (let u
            (eval-lex
              (apply
                ($.vector-ref rfn 2)
                'next a5)
              env)
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))
;drop a6, also put a5 in

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (withs a1
        '(s stm v s-car.stm)
        a2
        (pair a1)
        a3
        (map car a2)
        a4
        '((if no.s v
           (next s-cdr.s
             (f v s-car.s))))
        a5
        (cons a3 a4)
        a7
        '(s stm v s-car.stm)
        a8
        (pair a7)
        xs
        (map cadr a8)
        (let u
            (eval-lex
              (apply
                ($.vector-ref rfn 2)
                'next a3 a4)
              env)
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))
;drop a5, put a4 in, drop a4

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (withs a1
        '(s stm v s-car.stm)
        a2
        (pair a1)
        a3
        (map car a2)
        a7
        '(s stm v s-car.stm)
        a8
        (pair a7)
        xs
        (map cadr a8)
        (let u
            (eval-lex
              (apply
                ($.vector-ref rfn 2)
                'next a3
                '((if no.s v
                   (next s-cdr.s
                     (f v s-car.s)))))
              env)
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))

;time to [go in the refrigerator] substitute rfn in.
;oh boy.
;rfn is this:
'(macro
  (closure nil
    (fn (name parms . body)
      `(let ,name nil
        (assign ,name
          (fn ,parms ,@body))))))

;hoo boy... now... we got some damned nested shit

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (withs a1
        '(s stm v s-car.stm)
        a2
        (pair a1)
        a3
        (map car a2)
        a7
        '(s stm v s-car.stm)
        a8
        (pair a7)
        xs
        (map cadr a8)
        (let u
            (eval-lex
              (apply
                '(closure nil
                  (fn (name parms . body)
                    `(let ,name nil
                      (assign ,name
                        (fn ,parms ,@body)))))
                'next a3
                '((if no.s v
                   (next s-cdr.s
                     (f v s-car.s)))))
              env)
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))

;and now...

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (withs a1
        '(s stm v s-car.stm)
        a2
        (pair a1)
        a3
        (map car a2)
        a7
        '(s stm v s-car.stm)
        a8
        (pair a7)
        xs
        (map cadr a8)
        (let u
            (eval-lex
              (let env2
                  (cons
                    (list 'name 'next)
                    (cons
                      (list 'parms a3)
                      (cons
                        (list 'body
                          '((if no.s v
                             (next s-cdr.s
                               (f v s-car.s)))))
                        env)))
                (eval-lex
                  '`(let ,name nil
                    (assign ,name
                      (fn ,parms ,@body)))
                  env2))
              env)
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))

;hwoah my god.
;different env formats... anyway.
;derr. must. this is still cheating a little but anyway:

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (withs a1
        '(s stm v s-car.stm)
        a2
        (pair a1)
        a3
        (map car a2)
        a7
        '(s stm v s-car.stm)
        a8
        (pair a7)
        xs
        (map cadr a8)
        (let u
            (eval-lex
              (withs b1
                (list 'body
                  '((if no.s v
                     (next s-cdr.s
                       (f v s-car.s)))))
                ev1
                (cons b1 env)
                b2
                (list 'parms a3)
                ev2
                (cons b2 ev1)
                b3
                (list 'name 'next)
                env2
                (cons b3 ev2)
                (eval-lex
                  '`(let ,name nil
                    (assign ,name
                      (fn ,parms ,@body)))
                  env2))
              env)
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))

;would really be vectors with parent ptrs but eh.
;now we un-bq.
`(let ,name nil
  (assign ,name
    (fn ,parms ,@body)))
;-> ...
(cons 'let
      `(,name nil
  (assign ,name
    (fn ,parms ,@body))))

(cons 'let
      (cons name
      `(nil
  (assign ,name
    (fn ,parms ,@body)))))

(cons 'let
      (cons name
      (cons 'nil `(
  (assign ,name
    (fn ,parms ,@body))))))

(cons 'let
      (cons name
      (cons 'nil
       (cons `(assign ,name
    (fn ,parms ,@body)) 'nil))))
;cleanup
(cons 'let
  (cons name
    (cons 'nil
      (cons
        `(assign ,name
          (fn ,parms ,@body))
        'nil))))
;nerf...
(cons 'let
  (cons name
    (cons 'nil
      (cons
        (cons 'assign
              (cons name
                    `(fn ,parms ,@body)))
        'nil))))

(cons 'let
  (cons name
    (cons 'nil
      (cons
        (cons 'assign
          (cons name
            (cons 'fn
              (cons parms body))))
        'nil))))

;kk.



(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (withs a1
        '(s stm v s-car.stm)
        a2
        (pair a1)
        a3
        (map car a2)
        a7
        '(s stm v s-car.stm)
        a8
        (pair a7)
        xs
        (map cadr a8)
        (let u
            (eval-lex
              (withs b1
                (list 'body
                  '((if no.s v
                     (next s-cdr.s
                       (f v s-car.s)))))
                ev1
                (cons b1 env)
                b2
                (list 'parms a3)
                ev2
                (cons b2 ev1)
                b3
                (list 'name 'next)
                env2
                (cons b3 ev2)
                (eval-lex
                  '(cons 'let
                    (cons name
                      (cons 'nil
                        (cons
                          (cons 'assign
                            (cons name
                              (cons 'fn
                                (cons parms body))))
                          'nil))))
                  env2))
              env)
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))

;hohhhh boy.
;but this is all plain code, so...
;once again:
;(eval-lex '(cons a b) env) -> (cons (eval-lex 'a env) (eval-lex 'b env))

;for convenience, going to be sloppy with envs.

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (withs a1
        '(s stm v s-car.stm)
        a2
        (pair a1)
        a3
        (map car a2)
        a7
        '(s stm v s-car.stm)
        a8
        (pair a7)
        xs
        (map cadr a8)
        (let u
            (eval-lex
              (let env2
                  (obj name 'next parms a3 body
                    '((if no.s v
                       (next s-cdr.s
                         (f v s-car.s))))
                    parent env)
                (eval-lex
                  '(cons 'let
                    (cons name
                      (cons 'nil
                        (cons
                          (cons 'assign
                            (cons name
                              (cons 'fn
                                (cons parms body))))
                          'nil))))
                  env2))
              env)
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))

;would be nice if obj printed with alternating, but anyway.
;now we expand that cons crap.

(eval-lex
  '(cons 'let
    (cons name
      (cons 'nil
        (cons
          (cons 'assign
            (cons name
              (cons 'fn
                (cons parms body))))
          'nil))))
  env2)
;becomes, no _matter_ what name and parms and body are--because
;they're arguments, not callers--this:

(cons
  (eval-lex ''let env2)
  (eval-lex
    '(cons name
      (cons 'nil
        (cons
          (cons 'assign
            (cons name
              (cons 'fn
                (cons parms body))))
          'nil)))
    env2))

;eval ''x = 'x

(cons 'let
  (cons
    (eval-lex 'name env2)
    (eval-lex
      '(cons 'nil
        (cons
          (cons 'assign
            (cons name
              (cons 'fn
                (cons parms body))))
          'nil))
      env2)))

(cons 'let
  (cons
    (lookup 'name env2)
    (cons
      (eval-lex ''nil env2)
      (eval-lex
        '(cons
          (cons 'assign
            (cons name
              (cons 'fn
                (cons parms body))))
          'nil)
        env2))))

(cons 'let
  (cons
    (lookup 'name env2)
    (cons 'nil
      (cons
        (eval-lex
          '(cons 'assign
            (cons name
              (cons 'fn
                (cons parms body))))
          env2)
        (eval-lex ''nil env2)))))

(cons 'let
  (cons
    (lookup 'name env2)
    (cons 'nil
      (cons
        (cons 'assign ;skip
          (eval-lex
            '(cons name
              (cons 'fn
                (cons parms body)))
            env2))
        'nil))))

(cons 'let
  (cons
    (lookup 'name env2)
    (cons 'nil
      (cons
        (cons 'assign
          (cons
            (lookup 'name env2)
            (eval-lex
              '(cons 'fn
                (cons parms body))
              env2)))
        'nil))))
;close
(cons 'let
  (cons
    (lookup 'name env2)
    (cons 'nil
      (cons
        (cons 'assign
          (cons
            (lookup 'name env2)
            (cons 'fn
              (eval-lex
                '(cons parms body)
                env2))))
        'nil))))
;and finally
(cons 'let
  (cons
    (lookup 'name env2)
    (cons 'nil
      (cons
        (cons 'assign
          (cons
            (lookup 'name env2)
            (cons 'fn
              (cons
                (lookup 'parms env2)
                (lookup 'body env2)))))
        'nil))))

;jesus christ. ok.


(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (withs a1
        '(s stm v s-car.stm)
        a2
        (pair a1)
        a3
        (map car a2)
        a7
        '(s stm v s-car.stm)
        a8
        (pair a7)
        xs
        (map cadr a8)
        (let u
            (eval-lex
              (let env2
                  (obj name 'next parms a3 body
                    '((if no.s v
                       (next s-cdr.s
                         (f v s-car.s))))
                    parent env)
                (cons 'let
                  (cons
                    (lookup 'name env2)
                    (cons 'nil
                      (cons
                        (cons 'assign
                          (cons
                            (lookup 'name env2)
                            (cons 'fn
                              (cons
                                (lookup 'parms env2)
                                (lookup 'body env2)))))
                        'nil)))))
              env)
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))

;then we can fill some things in.
;the bindings.
;methinks this strategy of not working with quoted crap,
;but of working with just-created crap
;should have been started earlier.
;oh well.

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (withs a1
        '(s stm v s-car.stm)
        a2
        (pair a1)
        a3
        (map car a2)
        a7
        '(s stm v s-car.stm)
        a8
        (pair a7)
        xs
        (map cadr a8)
        (let u
            (eval-lex
              (let env2
                  (obj name 'next parms a3 body
                    '((if no.s v
                       (next s-cdr.s
                         (f v s-car.s))))
                    parent env)
                (cons 'let
                  (cons 'next
                    (cons 'nil
                      (cons
                        (cons 'assign
                          (cons 'next
                            (cons 'fn
                              (cons a3
                                '((if no.s v
                                   (next s-cdr.s
                                     (f v s-car.s))))))))
                        'nil)))))
              env)
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))

;now env2 is unused.
;oh, by the way, the parent env for env2 should have been nil
;all this time.
;d'oh. oh well, no diff.

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (withs a1
        '(s stm v s-car.stm)
        a2
        (pair a1)
        a3
        (map car a2)
        a7
        '(s stm v s-car.stm)
        a8
        (pair a7)
        xs
        (map cadr a8)
        (let u
            (eval-lex
              (cons 'let
                (cons 'next
                  (cons 'nil
                    (cons
                      (cons 'assign
                        (cons 'next
                          (cons 'fn
                            (cons a3
                              '((if no.s v
                                 (next s-cdr.s
                                   (f v s-car.s))))))))
                      'nil))))
              env)
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))

;sigh... I think that, to make things nicely rigorous,
;I'm gonna have to invert that whole chain of conses so
;everything has a name. hmm.
;time for a binding form that prints better.
;as I've used before: [or, not quite]
(mac binds (vars vals . body)
  (if no.vars
      `(do ,@body)
      `(let ,car.vars ,car.vals
         (binds ,cdr.vars ,cdr.vals ,@body))))

;this is not a form that a human should use when inverting things,
;because when you insert a new binding, the var and the expr
;go in separate places, separated by O(n).
;however, it will print nicer.
;so a human can convert after inverting.
;convert orig. stuff:

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (binds
        (a1 a2 a3 a7 a8 xs)
        ('(s stm v s-car.stm)
          (pair a1)
          (map car a2)
          '(s stm v s-car.stm)
          (pair a7)
          (map cadr a8))
        (let u
            (eval-lex
              (cons 'let
                (cons 'next
                  (cons 'nil
                    (cons
                      (cons 'assign
                        (cons 'next
                          (cons 'fn
                            (cons a3
                              '((if no.s v
                                 (next s-cdr.s
                                   (f v s-car.s))))))))
                      'nil))))
              env)
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))

;hmm. not so good, but... it'll occupy less space, and
;I won't expect to touch it much for a while.
;(don't want to work on a subexpr)
;now, invert.

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (binds
        (a1 a2 a3 a7 a8 xs)
        ('(s stm v s-car.stm)
          (pair a1)
          (map car a2)
          '(s stm v s-car.stm)
          (pair a7)
          (map cadr a8))
        (let u
            (eval-lex
             (withs a9 (cons a3
                              '((if no.s v
                                 (next s-cdr.s
                                   (f v s-car.s)))))
               a10 (cons 'fn
                            a9)
               a11 (cons 'next
                          a10)
               a12 (cons 'assign
                        a11)
               a13 (cons
                      a12
                      'nil)
               a14 (cons 'nil
                    a13)
               a15 (cons 'next
                  a14)
               
              (cons 'let
                a15))
              env)
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))

;hoo boy. "clean".

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (binds
        (a1 a2 a3 a7 a8 xs)
        ('(s stm v s-car.stm)
          (pair a1)
          (map car a2)
          '(s stm v s-car.stm)
          (pair a7)
          (map cadr a8))
        (let u
            (eval-lex
              (withs a9
                (cons a3
                  '((if no.s v
                     (next s-cdr.s
                       (f v s-car.s)))))
                a10
                (cons 'fn a9)
                a11
                (cons 'next a10)
                a12
                (cons 'assign a11)
                a13
                (cons a12 'nil)
                a14
                (cons 'nil a13)
                a15
                (cons 'next a14)
                (cons 'let a15))
              env)
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))

;now invert the binds and the eval.

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (binds
        (a1 a2 a3 a7 a8 xs)
        ('(s stm v s-car.stm)
          (pair a1)
          (map car a2)
          '(s stm v s-car.stm)
          (pair a7)
          (map cadr a8))
        (let u
            (withs a9
              (cons a3
                '((if no.s v
                   (next s-cdr.s
                     (f v s-car.s)))))
              a10
              (cons 'fn a9)
              a11
              (cons 'next a10)
              a12
              (cons 'assign a11)
              a13
              (cons a12 'nil)
              a14
              (cons 'nil a13)
              a15
              (cons 'next a14)
              a16
              (cons 'let a15)
              (eval-lex a16 env))
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))

;oh boy. now... hah, we can reuse the names f2 and xs2.

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (binds
        (a1 a2 a3 a7 a8 xs)
        ('(s stm v s-car.stm)
          (pair a1)
          (map car a2)
          '(s stm v s-car.stm)
          (pair a7)
          (map cadr a8))
        (let u
            (withs a9
              (cons a3
                '((if no.s v
                   (next s-cdr.s
                     (f v s-car.s)))))
              a10
              (cons 'fn a9)
              a11
              (cons 'next a10)
              a12
              (cons 'assign a11)
              a13
              (cons a12 'nil)
              a14
              (cons 'nil a13)
              a15
              (cons 'next a14)
              (withs f2 'let xs2 a15
                (let u2 (eval-lex f2 env)
                  (if is-macro.u2
                      ...))))
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))

;now this u2 crap ...
;partial partial evaluation or something. Futamura.
;with most macros, I would probably want some pre-"compiled"
;whatever thing that would represent a guaranteedly
;nondestructive portion of macroexpansion; frequently this
;would be most or all of the macro.
;otherwise I end up substituting bodies of "let" every time...
;well, oh well. figure _that_ out later.
;substitute crap, let is known, drop f2...

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (binds
        (a1 a2 a3 a7 a8 xs)
        ('(s stm v s-car.stm)
          (pair a1)
          (map car a2)
          '(s stm v s-car.stm)
          (pair a7)
          (map cadr a8))
        (let u
            (withs a9
              (cons a3
                '((if no.s v
                   (next s-cdr.s
                     (f v s-car.s)))))
              a10
              (cons 'fn a9)
              a11
              (cons 'next a10)
              a12
              (cons 'assign a11)
              a13
              (cons a12 'nil)
              a14
              (cons 'nil a13)
              a15
              (cons 'next a14)
              (withs xs2 a15
                (let u2 let
                  (if is-macro.u2
                      ...))))
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))

;now let is in fact a macro, and so on.

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (binds
        (a1 a2 a3 a7 a8 xs)
        ('(s stm v s-car.stm)
          (pair a1)
          (map car a2)
          '(s stm v s-car.stm)
          (pair a7)
          (map cadr a8))
        (let u
            (withs a9
              (cons a3
                '((if no.s v
                   (next s-cdr.s
                     (f v s-car.s)))))
              a10
              (cons 'fn a9)
              a11
              (cons 'next a10)
              a12
              (cons 'assign a11)
              a13
              (cons a12 'nil)
              a14
              (cons 'nil a13)
              a15
              (cons 'next a14)
              (withs xs2 a15
                (let u2 let
                  (eval-lex (apply ($.vector-ref let 2) xs2)
                            env))))
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))

;aw my gawd...
(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (binds
        (a1 a2 a3 a7 a8 xs)
        ('(s stm v s-car.stm)
          (pair a1)
          (map car a2)
          '(s stm v s-car.stm)
          (pair a7)
          (map cadr a8))
        (let u
            (withs a9
              (cons a3
                '((if no.s v
                   (next s-cdr.s
                     (f v s-car.s)))))
              a10
              (cons 'fn a9)
              a11
              (cons 'next a10)
              a12
              (cons 'assign a11)
              a13
              (cons a12 'nil)
              a14
              (cons 'nil a13)
              a15
              (cons 'next a14)
              (withs xs2 a15
                (let u2 let
                  (eval-lex
                    (apply
                      (closure nil
                        (fn (var val . body)
                          `(with
                            (,var ,val)
                            ,@body)))
                      xs2)
                    env))))
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))

;OH my GOD
;I think I am going to intervene at this point
;and substitute an eqv but less TERRIBLE definition of let.
(closure nil
         (fn (var val . body)
           `((fn (,var) ,@body) ,val)))
;which it probably was before I fucked with it somehow. ... no,
;it's from arc.arc.
;well, anyway.
;this further is eqv to:
(closure nil
         (fn (var val . body)
           (list `(fn (,var) ,@body) val)))
;and
(closure nil
  (fn (var val . body)
    (list
      (list* 'fn
        (list var)
        body)
      val)))
;fuck.
;hikari to yami.

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (binds
        (a1 a2 a3 a7 a8 xs)
        ('(s stm v s-car.stm)
          (pair a1)
          (map car a2)
          '(s stm v s-car.stm)
          (pair a7)
          (map cadr a8))
        (let u
            (withs a9
              (cons a3
                '((if no.s v
                   (next s-cdr.s
                     (f v s-car.s)))))
              a10
              (cons 'fn a9)
              a11
              (cons 'next a10)
              a12
              (cons 'assign a11)
              a13
              (cons a12 'nil)
              a14
              (cons 'nil a13)
              a15
              (cons 'next a14)
              (withs xs2 a15
                (let u2 let
                  (eval-lex
                    (apply
                      (closure nil
                        (fn (var val . body)
                          (list
                            (list* 'fn
                              (list var)
                              body)
                            val)))
                      xs2)
                    env))))
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))

;now, applying a closure is easy...
;use env2 again.
;but first let's turn that explicit "apply",
;which is atrocious, into a call.
;probably can drop stupid shit.
;ok:
;xs2 -> a15
;drop xs2
;"apply ... a15" -> 'next a14
;drop a15 (geez, this'd be probably much nicer
; if I had used "list" instead of so much "cons")
;a14 -> 'nil a13
;a13 -> a12 'nll
;drop a13 a14

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (binds
        (a1 a2 a3 a7 a8 xs)
        ('(s stm v s-car.stm)
          (pair a1)
          (map car a2)
          '(s stm v s-car.stm)
          (pair a7)
          (map cadr a8))
        (let u
            (withs a9
              (cons a3
                '((if no.s v
                   (next s-cdr.s
                     (f v s-car.s)))))
              a10
              (cons 'fn a9)
              a11
              (cons 'next a10)
              a12
              (cons 'assign a11)
              (let u2 let
                (eval-lex
                  (apply
                    (closure nil
                      (fn (var val . body)
                        (list
                          (list* 'fn
                            (list var)
                            body)
                          val)))
                    'next 'nil a12 'nil)
                  env)))
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))

;oh boy. now the apply can be made better.

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (binds
        (a1 a2 a3 a7 a8 xs)
        ('(s stm v s-car.stm)
          (pair a1)
          (map car a2)
          '(s stm v s-car.stm)
          (pair a7)
          (map cadr a8))
        (let u
            (withs a9
              (cons a3
                '((if no.s v
                   (next s-cdr.s
                     (f v s-car.s)))))
              a10
              (cons 'fn a9)
              a11
              (cons 'next a10)
              a12
              (cons 'assign a11)
              (let u2 let
                (eval-lex
                  (funcall
                    (closure nil
                      (fn (var val . body)
                        (list
                          (list* 'fn
                            (list var)
                            body)
                          val)))
                    'next 'nil a12)
                  env)))
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))

;heh. now evaluate closure. env2.
;heh, and we can drop u2.
;hmm, do that first.

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (binds
        (a1 a2 a3 a7 a8 xs)
        ('(s stm v s-car.stm)
          (pair a1)
          (map car a2)
          '(s stm v s-car.stm)
          (pair a7)
          (map cadr a8))
        (let u
            (withs a9
              (cons a3
                '((if no.s v
                   (next s-cdr.s
                     (f v s-car.s)))))
              a10
              (cons 'fn a9)
              a11
              (cons 'next a10)
              a12
              (cons 'assign a11)
              (eval-lex
                (funcall
                  (closure nil
                    (fn (var val . body)
                      (list
                        (list* 'fn
                          (list var)
                          body)
                        val)))
                  'next 'nil a12)
                env))
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))

;now.

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (binds
        (a1 a2 a3 a7 a8 xs)
        ('(s stm v s-car.stm)
          (pair a1)
          (map car a2)
          '(s stm v s-car.stm)
          (pair a7)
          (map cadr a8))
        (let u
            (withs a9
              (cons a3
                '((if no.s v
                   (next s-cdr.s
                     (f v s-car.s)))))
              a10
              (cons 'fn a9)
              a11
              (cons 'next a10)
              a12
              (cons 'assign a11)
              (eval-lex
                (withs a13
                  (list a12)
                  env2
                  (obj var 'next val 'nil body a13)
                  (eval-lex
                    '(list
                      (list* 'fn
                        (list var)
                        body)
                      val)
                    env2))
                env))
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))

;oh man, this'll be somewhat easier
;list and list* are known...

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (binds
        (a1 a2 a3 a7 a8 xs)
        ('(s stm v s-car.stm)
          (pair a1)
          (map car a2)
          '(s stm v s-car.stm)
          (pair a7)
          (map cadr a8))
        (let u
            (withs a9
              (cons a3
                '((if no.s v
                   (next s-cdr.s
                     (f v s-car.s)))))
              a10
              (cons 'fn a9)
              a11
              (cons 'next a10)
              a12
              (cons 'assign a11)
              (eval-lex
                (withs a13
                  (list a12)
                  env2
                  (obj var 'next val 'nil body a13)
                  (list
                    (eval-lex
                      '(list* 'fn
                        (list var)
                        body)
                      env2)
                    (eval-lex 'val env2)))
                env))
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))

;parallel...

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (binds
        (a1 a2 a3 a7 a8 xs)
        ('(s stm v s-car.stm)
          (pair a1)
          (map car a2)
          '(s stm v s-car.stm)
          (pair a7)
          (map cadr a8))
        (let u
            (withs a9
              (cons a3
                '((if no.s v
                   (next s-cdr.s
                     (f v s-car.s)))))
              a10
              (cons 'fn a9)
              a11
              (cons 'next a10)
              a12
              (cons 'assign a11)
              (eval-lex
                (withs a13
                  (list a12)
                  env2
                  (obj var 'next val 'nil body a13)
                  (list
                   (list* (eval-lex ''fn env2)
                          (eval-lex '(list var) env2)
                          (eval-lex 'body env2))
                    'nil))
                env))
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))

;and.

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (binds
        (a1 a2 a3 a7 a8 xs)
        ('(s stm v s-car.stm)
          (pair a1)
          (map car a2)
          '(s stm v s-car.stm)
          (pair a7)
          (map cadr a8))
        (let u
            (withs a9
              (cons a3
                '((if no.s v
                   (next s-cdr.s
                     (f v s-car.s)))))
              a10
              (cons 'fn a9)
              a11
              (cons 'next a10)
              a12
              (cons 'assign a11)
              (eval-lex
                (withs a13
                  (list a12)
                  env2
                  (obj var 'next val 'nil body a13)
                  (list
                   (list* 'fn
                          (list (eval-lex 'var env2))
                          a13)
                    'nil))
                env))
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))

;and.

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (binds
        (a1 a2 a3 a7 a8 xs)
        ('(s stm v s-car.stm)
          (pair a1)
          (map car a2)
          '(s stm v s-car.stm)
          (pair a7)
          (map cadr a8))
        (let u
            (withs a9
              (cons a3
                '((if no.s v
                   (next s-cdr.s
                     (f v s-car.s)))))
              a10
              (cons 'fn a9)
              a11
              (cons 'next a10)
              a12
              (cons 'assign a11)
              (eval-lex
                (withs a13
                  (list a12)
                  env2
                  (obj var 'next val 'nil body a13)
                  (list
                   (list* 'fn
                          (list 'next)
                          a13)
                    'nil))
                env))
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))

;and now env2 is unnecessary

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (binds
        (a1 a2 a3 a7 a8 xs)
        ('(s stm v s-car.stm)
          (pair a1)
          (map car a2)
          '(s stm v s-car.stm)
          (pair a7)
          (map cadr a8))
        (let u
            (withs a9
              (cons a3
                '((if no.s v
                   (next s-cdr.s
                     (f v s-car.s)))))
              a10
              (cons 'fn a9)
              a11
              (cons 'next a10)
              a12
              (cons 'assign a11)
              (eval-lex
                (withs a13
                  (list a12)
                  (list
                    (list* 'fn
                      (list 'next)
                      a13)
                    'nil))
                env))
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))

;and we can extend the scope of a13

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (binds
        (a1 a2 a3 a7 a8 xs)
        ('(s stm v s-car.stm)
          (pair a1)
          (map car a2)
          '(s stm v s-car.stm)
          (pair a7)
          (map cadr a8))
        (let u
            (withs a9
              (cons a3
                '((if no.s v
                   (next s-cdr.s
                     (f v s-car.s)))))
              a10
              (cons 'fn a9)
              a11
              (cons 'next a10)
              a12
              (cons 'assign a11)
              a13
              (list a12)
              (eval-lex
                (list
                  (list* 'fn
                    (list 'next)
                    a13)
                  'nil)
                env))
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))

;and invert a little more

(fn (f stm
     (o default))
  (let env
      (obj f f stm stm default default)
    (if
      (no stm)
      default
      (binds
        (a1 a2 a3 a7 a8 xs)
        ('(s stm v s-car.stm)
          (pair a1)
          (map car a2)
          '(s stm v s-car.stm)
          (pair a7)
          (map cadr a8))
        (let u
            (withs a9
              (cons a3
                '((if no.s v
                   (next s-cdr.s
                     (f v s-car.s)))))
              a10
              (cons 'fn a9)
              a11
              (cons 'next a10)
              a12
              (cons 'assign a11)
              a13
              (list a12)
              a14
              (list 'next)
              a15
              (list* 'fn a14 a13)
              a16
              (list a15 'nil)
              (eval-lex a16 env))
          (if is-macro.u
            (eval-lex
              (apply
                ($.vector-ref u 2)
                xs)
              env)
            (apply u
              (map
                [ueval _ env]
                xs))))))))

;ok, we're about to want to do some code that will be
;creating a closure. a16 looks like:
;((fn (smthg) ...) 'nil)

;[sleep cycle]
;I suspect that, lazy evaluation-like, you will want to have a preallocated
;place to store a "successor tree" thing in an immutable tree.

;[sleep]
;According to a scheme laid out in my notebook, I shall maintain maximally-
; connected interpreter semantics, and I guess I will do the checks ...
;_Oh_ god.  There is still the issue of someone modifying code.
;I guess it is still possible to do this.
;It will be done at a very fine granularity... with many checks...
;And ...
;But.  
; I think I can guarantee that bad things will never happen.
;When I compile one function that makes assumptions about another function,
;even if someone modifies the second function, the results either
;will be felt completely, by something that recompiles
;everything (or interprets); or they'll be
;not felt at all, because the first function was
;compiled along with the second function and makes direct
;jumps to access the second function.
;It goes from an issue of unsafety to an issue of not
;having updated yet.

;... continuations may be a problem (incl' stack return stuff).
;If f calls g as a subroutine, expecting an integer,
;and everything is redefined... that continuation would be invalid.
;At least, must not call that continuation on a result from
;the new g subroutine.  The whole call
;structure becomes unusable. Either that thread must dieee,
;or it must continue with old dicks.

;... I am reminded of SBCL's comment.
;(Also they seem responsible for the presence of "eval-with-lexenv"
; in my brain.)
;SBCL's manual somewhere says "Version n will refuse to run
;any things compiled by version m ≠ n.  This is obviously
;suboptimal, but we find it the best approach."
;Closures... Closures can maybe persist fine; they are probably written (i.e. compiled) to assume
;that they escape, and ... mmm.
;(Yeah, continuations and closures and returns from the stack are supposed to be
; the same thing.  Mostly.  Maybe.
;But I think I will want the optimizations that come from assuming the stack
;doesn't escape.)
;An old closure will probably be written to assume old code.
;If a new thread calls it, it will run old versions of global variables.
;That shall be fine.
;Also kind of cool.
;But ... there will be some shared global variables.
;(I have the HN server specifically in mind...)
;
;Semantics: A saved closure can do whatever the fuck...
;No. That disallows crap.
;A saved closure will have its source code with it.
;It maybbe "old" source code.
;But it will be analyzable.  Usable.
;And it will have its global variable tree effectively as part of it...
;Will that have to be an actual part?
;Or just inherent in the shared bits of compiled code?
;(Btw it'd be very nice if the GC could get rid of
;unused portions of old code... possible?  Probably with some
;effort; currently the GC need not move all code at once, and...
;I guess it could ... move code around and ercompile.
;Reassemble, more like.
;I guess cached could be a representation of assembly code
;with labels in it but nothing generated yet.
;Mmm...
;Correspondences?  Mmmph.)
;How about closures deciding to update/recompile themselves?
;That seems to be necessary for avoiding the problem of multiple
;bindings of ... hmm...
;Multiple bindings, sure.  But not modification of an existing object
;that is bound to a variable.
;However, that is still a use case: "n" as a global variable.
;(Say gensym counter.)
;Would be catastrophic if that were reset without warning... so...
;It seems closures will need to recompile themselves.
;Or do they?
;...
;Incidentally, if n is eliminated from a program... say, accidentally...
;and then n is brought back as a vector var... nah.
;If n is always in a program, but a thing that modifies it is eliminated,
;and then something that modifies it is brought back...
;It would seem that the first n and the last n should be the same.
;In that case, ...
;Seems like we should have a weak hash table mapping the symbol n to any
;cell used for it as a vector var (if applicable).
;So, can only be thrown away if ... um, hmm.
;...
;I think it works to use a "symbol-value" field of the symbol for this
;stuff.
;If n happens to be not modified by the program, or only set to a
;constant [this should be the case for most fns and macros, I guess],
;then things that are compiled may assume that the value of n will
;always be the current contents of the symbol-value field of 'n.
;... ... ...
;How about that idea for a tree?  Oh yeah, that's because you need
;an atomic installation of a group of new definitions or smthg.
;(It would technically work just as well, although performance would
; be different, to have a "linked list" of events and use CMPXCHG
; to install those.  In that case, it's just that multiple threads
; would have to go through O(# events) things in one big chunk
; to get to the updated thing.)
;Compilation... How about a function (perhaps closure) that creates
;closures?  Am I gonna have to compile every one?  That would be
;terrible.  Well, then...?
;Why are some closures (bound to global vars) compiled together,
;and others just created?  Because the first ones were assumed to
;be constant closures.
;[There is some portion of my train of thought that may be missing.]
;Ok, so, it would be a bad thing if every instance of (make-counter)
;created something that needed to be compiled.
;Those should be kind-of-raw closures. They should have an env and
;a pointer to _compiled_ code and perhaps some additional stuff.
;(Lazily compiled, I guess, but all these closures should point to
; the _same_ compiled code.)
;(Then it is scalable to have ... mmm.)
;Code that creates a closure and binds it to a global variable...
;Let's say some code creates a global variable that is a list of
;closures, and then some other code takes one of those closures
;and binds a global variable to it. (I've noticed repeatedly that
; "x is bound to y" and "y is bound to x" appear to be used
; interchangeably...)
;Upon recompilation of everything, the source-code body of that
;closure will be used to inline calls to that global variable.
;That closure itself will ...
;Hmm...
;When called, that closure may check whether the tree is obsolete,
;and if so, it may update to use the new tree (and possibly new
;compiled code), or it may persist in using the old, or it may
;throw an error of some sort.  I may not have decided exactly about
;this.
;Internal calls to "that closure" are not to be understood as such.
;They may be inlined and optimized beyond recognition.
;... really?
;Well, I decided before, there will be some API for notifying an
;executing thread of changes you've made; this may include
;sending a signal, or merely setting a flag that that thread is
;expected to check.  A mutator must wait for executors to respond
;before it "knows" that they've updated.
;Of course, a mutator could proceed anyway; it just can't complain
;to me if it has problems because an executor hadn't updated.
;... Closures and continuations...
;Ok, I guess it's all pretty well to declare that a mutator may
;have to wait for all executing threads to update.
;(And I would probably want to figure out what should happen if
; it doesn't want to wait.)
;(But I don't have to yet.)
;Even after updating, threads may have left closures behind.
;How should those be... _interpreted?_
;Well, in an interpreter, it is obvious.  They use new code.
;Therefore, these closures, when executed, must "recompile",
;i.e. they must update to use the new tree and possibly new
;compiled code.
;How is this to be accomplished?
;Well, either the closures can begin with code that says "check",
;or code that is used to call an unknown closure can check,
;or execution may be kind of suspended until all closures are
;found and updated, _or_ the single copy of code that may be
;used in n closures can be overwritten with "check and recomp.".
;This last is most awesome. And if threads are suspended while
;this shit happens, then there should probably be no problems with
;bytes overlapping and whatever (like, maybe a thread was executing
;a (multi-byte) instruction that has been partially overwritten).
;That actually seems pretty doable and stuff.  Just ambitious, and
;probably I'll just have closures begin with "check" at the start.

;A thread will have a tree it is effectively using.
;It must be able to find that tree, anyway, because that will
;contain information used to compile lazily compiled functions
;and perhaps contain a successor tree and perhaps other things.
;This is a tree of things that are assumed to be constant.
;Normally this is all global variables such that nothing else
;in the tree modifies anything in the tree.
;People who use any macros at all will probably have to do this...
;It is conceivable that someone would include, say, a hash table
;used basically to represent a namespace or a module in the cat.
;of constant things (and likely include all its mappings).
;In that case, any assignments to hash tables will have to check
;whether they're modifying this hash table.
;I guess you could (a) create a type of hash table used for this
;purpose, and have a different word for modifying such a thing,
;or (b) have a flag in the hash table that says whether it's
;"expensive to mutate" (not immutable, nothing is immutable except
; maybe compiled code).
;Likewise, you could include the car of a certain cons cell (as well
;as, presumably, the cell itself) in the cat. of constant things.
;But that would mean:
;- making all cons cells fatter to have an "exp. to mutate" tag
;- making a new type of cons cell, probably a user-tag one
;- forcing prog. to use different words...
;- making set-car perform some check (is it cons cell X? no? proceed)
;Which would suck and probably no one would want to do it, so I
;would probably just not support it.
;The hash table thing is useful, and I'd probably use a different
;type thing for it.  --Um.  Whether a thread considers X table constant
;is a property of that thread, not of that table.  Mmmph.
;Fine, just use a fucking whatever.
;--Oh, and it's not outsiders that'd have to worry about modifying that
;table, 'cause the thread will just assume the contents haven't changed.
;It's the thread itself.  It's also the thread accidentally using
;table accessors on something that turns out to be that table...
;Hmm, this is kind of interesting...
;The thread itself also doesn't necessarily have to worry about
;modifying that table.  It'll just assume the contents haven't changed.
;One might say it should check, _when_ it performs that assignment,
;whether it needs to update things.
;This could be considered kind of a holdover from global variables...
;I mean, the two don't necessarily need to be correlated.
;Glob vars are kind of degenerate and special-ish; it is generally
;O(0) to figure out which global var you're assigning to, and also
;they're kind of assumed to behave a certain (maximally-connected) way.
;A table would only be assumed constant if the programmer said so.
;In that case, if the program happens to modify that table, that is
;the programmer's responsibility, and the programmer can be instructed
;to write "assign-_and-update-everything_-to-this-hash-table".

;... In that case, I guess that could... sort of... be considered to
;also explain the case of us neglecting to check whether code has
;been modified.
;"If you want to modify this cons cell of code, it is your resp. to
; notify any threads of your changes and get them to update.
; (And maybe do the invalidation and tree-installing yourself.)
; We will provide the notification mechanism, but it is your resp.
; to activate it."
;... How can that be justified?
;"You asked for compilation."
;That is used to justify so much terrible stuff...
;What about quoted things, are they immutable?
;Nawp; it seems a fine thing to generate code like `(blah ',(nerf))
;where (nerf) evaluates to some mutable data structure.
;(One could argue that an object should evaluate to itself, and so
; that code should just be written as `(blah ,(nerf)). However, I
; do not consider this decided.)
;I guess one could imagine an interpreter... and then a flag that
;says "Assume code will not be modified".
;What happens if someone modifies it anyway?
;And then you use that copy for inlining purposes?
;Terrible things.
;You must construct your own private copy when you do this stuff.
;... I think that'll work.
;And those who modify must notify if they expect their effects to be seen.
;Configuration table of how-to-choose-things-to-recognize-as-constant.
;Flag for "tree of code".
;Maybe a list of global vars programmer spec. says don't inline.
;Maybe a list of tables prog. says do inline.
;Mmm...
;Probably implicit: the definitions of builtins like eval-lex.
;Also call.

;Exhibit below from earlier:

;How about not completely compiling?
;That would solve CIRCULARIZE, and nothing else would.
;(That is...)
;(Ok, it would work to simultaneously check for cycles and construct
; your own private copy of all the code.)
;

;Looks like "private copy" seems actually the way to go.

;... Sigh...
;Just for the exercise, I think I should illustrate compiling
;(and optimizing) without the "assume code is not modified" assumption.
;It does, at least, have the implicit "Interpreter is not modified" and
;"The different ways to call data structures in func. position are not
; modified."
;Also, it is an advantage to remove jumps except a bunch that will prob.
;be branch-predicted out.

;I shall do that exercise later.






















;








            

