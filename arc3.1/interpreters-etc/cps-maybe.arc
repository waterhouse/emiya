;Let's see if I can rederive crap from scratch...
;crap being CPS.

;...
;I... shall I use Shivers's thing,
;where ((fn dicks ass) nerf) is an acceptable CPS
;expression?
;I suppose I might as well.
;The alternatives involve either potentially-infinite
;expansion, global analysis to extract things,
;or some semi-silly FIX form that isn't global.

;We shall assume (and, separately, ensure)
;input that is a fully macex'd and desyntax'd Arc expression.
;(... Yes, that can be done in essentially a single pass;
; if a macro generates ssyntax output somehow, at least it'll
; only be in the resulting expression.  --This assumes no one
; mutates the source code while you're examining it. Hoo boy.)

;Eh... I guess it's even possible that I could
;interleave these two things.
;But eh.

;I decided that QUOTE things should be perceived as constants.
;If the structure must be constructed at runtime, then someone
;will have to figure out about that.
;(Like, if the procedure will construct a new one every time
;it's called, then that violates the semantics of QUOTE.
;If you want to quote some nontrivial data structure, like a
;list, and if your runtime doesn't support lists being in
;some kind of file-mmap'd, read-only portion of memory that
;gets mmap'd when you execute a file or load a shared library,
;then your runtime had better figure out how to deal with that,
;allocating such a list in a place of memory that it can handle
;at the time that the code is compiled or loaded--perhaps when
;it's run for the first time (perhaps that also means compiled
;with JIT compilation)--and storing a pointer to it in a place
;that the code can access, and maintaining such a pointer
;when/if the list is moved by the GC.
;If your runtime doesn't support QUOTE, then certainly I don't
;have to handle it here.)

;Ok, so, here I face the question:
;((actually-fn) (x) (+ x 3))
; where (actually-fn) = (macro () 'fn)
;leads to what?
;In my interpreter, that is definitely the same
;as (fn (x) (+ x 3)).
;In arc3.1 and Racket and Chicken
;[lolz, I go about 5 things up in rlwrap csi history and I find
; this exact example]
;and sbcl, that is an error.
;A macro that simply expands to the name of a macro is an error,
;in these languages.
;I dislike this...
;However, I seem to be giving in to having macros locked in at
;compile time, and needing to hack in the proper behavior
;through other means in some other way.
;Mmm...
;I think I shall hold fast to that.
;So.

;... Conservative approximation.
;... Fuck.
(def arglist-argnames (xs)
  (keep [isa _ 'sym] flat.xs))
;Yar, there we go.

(def de-macro (x (o env nil))
  (if ssyntax.x
      (de-macro ssexpand.x env)
      atom.x
      x
      (let (a . b) x
        (let a (de-macro a env)
          (if (and (isa a 'sym)
                   bound.a
                   (no:mem a env)
                   (isa symbol-value.a 'mac))
              (de-macro (macex:cons a b) env)
              (is a 'fn)
              (cons a (cons car.b
                 (let env (join (arglist-argnames car.b) env)
                   (map [de-macro _ env] cdr.b))))
              (is a 'quote)
              (cons a b)
              (is a 'quasiquote)
              (err "Fuck me no quasiquotes" a b)
              (is a '$)
              (err "FUCK $")
              (cons a (map [de-macro _ env] b)))))))
;I guess I could kind of treat $ like quote.
;Still...
;This is intended to be used for pre-CPS screening.

;Ok, macros have been removed.
;Only pure raw Arc.
;fn's, quotes, constants, variables.

;I want to make my own calling convention...
;Also, in general I may want a bunch of side effects
;to express crap.
;(As you encounter foreign functions, insert them into
;a list of things to create your own bindings for.
;And other things...)
(def cps (x K)
  (if ssyntax.x
      (cps ssexpand.x K)
      atom.x
      (list K x)
      (is car.x 'quote)
      (list K x)
      (acons car.x)
      
      
      
      
      
      
      
      
      
      
      
      