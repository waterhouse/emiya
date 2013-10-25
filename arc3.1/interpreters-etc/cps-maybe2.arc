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


;Ok, fuck this, we are going to handle quasiquote.
;
(def de-macro (x (o env nil))
  (if ssyntax.x
      (de-macro ssexpand.x env)
      atom.x
      x
      (let (a . b) x
        (let a (de-macro a env)
          (if (mem a env)
              ;... we could detect local bindings to literal macros
              ;and maybe direct calls to literal macros as well
              ;(as in ((macro ...) arg ...))
              ;but neh
              (cons a (map [de-macro _ env] b))
              (and (isa a 'sym)
                   bound.a
                   (isa symbol-value.a 'mac))
              (de-macro (macex:cons a b) env)
              (is a 'fn)
              (cons a (cons car.b
                 (let env (join (arglist-argnames car.b) env)
                   (map [de-macro _ env] cdr.b))))
              (is a 'quote)
              (cons a b)
              (is a 'quasiquote)
              (if cdr.b
                  (err "Quasiquote better" x)
                  (de-macro-qq car.b env 1))
              (is a '$)
              (err "FUCK $")
              (cons a (map [de-macro _ env] b)))))))
;I guess I could kind of treat $ like quote.
;Still...
;This is intended to be used for pre-CPS screening.

;... should detect bindings of dick ;done

;Semantically, I think it is important to have what some call
;"as much structure sharing as possible".
;... So far, no attempts to handle circular code structures...
;... Also, ... one must be sure what quasiquote produces.
;E.g. (bq-cons a b), or (cons a b), or (<unique-name cons> a b).
;I'm going for the first, and having them defined as macros.
;Fortunately, ... ... how was I going to finish that sentence?
;Ah, yes: fortunately, (dick x) that macex's to (quote x) is still
;treated the same in arc3.1 as (quote x) in the first place.

;So.
;This basically should, I think, return an expression made up purely
;of (bq-cons x y) and (bq-quote x).  That is to say:
;expr = (bq-quote <anything>) or (bq-cons expr expr).
;I guess one can be excessively dumb and bq-quote numbers anyway.
;And then have bq-quote macex somewhat nicely.
;(Or not.)
;Anyway, that...
;(... need bq-append too; code we don't control could genuinely
; construct a list that needs to be deconstructed for appending)
;A basic idea 

;I had thought of 

;(def de-macro-qq (x env n) ;n ≥ 1
;  (if atom.x
;      `(bq-quote ,x)
;      (let (f . xs) x
;        (if (is f 'unquote)
;            (if (isnt len.xs 1) ;could raise direct type error if not cons...
;                (err "Bad qq'ing" x)
;                (is n 1)
;                (de-macro car.xs env)
;                (let u (de-macro-qq car.xs 


;... ehyes, you should have n passed around
;in inner things that shouldn't be expanded,
;the thing shouldn't be expanded at all

;so, eh, yeah... the ...
;mmm.
;see if tagging dicks works.
;(the alternative approach is somehow returning multiple
; values, the extra one being "whether this expression is
; one big quoted thing or whether it contains computations";
; or doing something equivalent, like passing around two
; or possibly more continuation arguments)

;...
;what if...
;`(,2 ,3)
;new cons each time?
;hmm...
;Racket sez yes.
;i.e.
;> (define (meh x) `(,x 2 3))
;> (let ((a (meh 1)) (b (meh 1))) (eq? (cdr a) (cdr b)))
;#t
;> (define (meh x) `(,x ,2 3))
;> (let ((a (meh 1)) (b (meh 1))) (eq? (cdr a) (cdr b)))
;#f
;Chicken sez new conses each time even in the first case.
;SBCL sez both pairs are the same.
;arc3.1 agrees with Racket.
;clisp agrees with SBCL.
;mmm...

;... this "asserting that things have a certain length"
;thing is kind of stupid; it would be good if, as in
;picolisp, it was (quote . x) rather than (quote x).
;oh well.

;... or I could allow qq with mult. args or smthg
;... I suppose that would probably work with "multiple values"
;although it would suck w.r.t the ` syntax

(def assert (x)
  (unless x (err "Derf")))

(def de-macro-qq (x env n)
  (if ;(is n 0)
      ;(de-macro x env)
      ;do note that if _this_ expands to a qq...
      ;mmm...
      atom.x
      `(bq-quote ,x)
      (is car.x 'quasiquote)
      (let (qq ex) x ;ahh, that's kind of a nice way
        (list 'quasiquote
              (de-macro-qq ex env inc.n)))
      (is car.x 'unquote)
      (let (qq ex) x
        (if (is n 1) ;with this, will never have direct call w/ n=0
            (de-macro ex env)
            (list 'unquote
                  (de-macro-qq ex env dec.n))))
      (is car.x 'unquote-splicing)
      (if (is n 1)
          (err "Wrong place to use unquote-splicing" x) ;later ;no
          ;(list 'bq-append-me   ;no
          (let (qq ex) x
            (list 'unquote-splicing
                  (de-macro-qq ex env dec.n))))
      ;call to a function
      (with a (de-macro-qq car.x env n)
        b (de-macro-qq-rest cdr.x env n)
        (if (and acons.a
                 acons.b
                 (is car.a 'bq-quote)
                 (is car.b 'bq-quote))
            ;`(bq-quote ,(cons cadr.a cadr.b)) ;lolz
            (list 'bq-quote (cons cadr.a cadr.b))
            ;otherwise it's prob. ...
            ;... it could be 
            ;also, something could macex to this crap
            ;that would be fine here
            ;`(bq-cons ,a ,b)
            (list 'bq-cons a b)))))

(def de-macro-qq-rest (x env n)
  (if ;(is n 0) ;nope
      atom.x
      (list 'bq-quote x)
      ;we do not care if 'qq or 'qq-splicing or wtvr is
      ;an element of this list.
      ;we do care if (qq x) or (qq-splicing x) or wtv is
      ;an element of this list.
      
      ;... if something is a macro call...
      ;... no, there is no case where a macro expanding
      ;directly to (unquote[-splicing] x) would be
      ;useful.
      ;if that expands, then that means it is not held away from
      ;evaluation by a qq, and so it would mean a direct call
      ;to a function called "unquote", which is stupid.
      ;however... if a macro expands to:
      ;(qq (unq ...
      ;no, still not uq-splicing.
      
      ;if I get `(dick ,@...
      ;ok, there is no "..." that I can fill in
      ;that will seem to justify somehow combining things
      ;and eliminating the bq-append.
      (let r (de-macro-qq-rest cdr.x env n)
        (let a car.x
          (if (and acons.a
                   (is car.a 'unquote-splicing)
                   (is n 1))
              (let (uqs ex) a
                (list 'bq-append
                      (de-macro ex env)
                      r))
              (let u (de-macro-qq a env n)
                (if (and acons.u (is car.u 'bq-quote)
                         acons.r (is car.r 'bq-quote))
                    (list 'bq-quote (cons cadr.u cadr.r))
                    (list 'bq-cons u r))))))))
                     
                     


(mac bq-quote args `(quote ,@args))
(mac bq-cons args `(cons ,@args))
(mac bq-append args `(join ,@args))
#;(mac bq-append-me args (err "A lonely bq-append-me." args))
;I could be like Steele or whoever and figure out when
;nconc'ing is permissible, but probably that should be
;left to a ... compiler.

;Wootz, shit seems to work.
;Probably.
;Maybe.
;Next I shall have to address $-ing.
;Btw it would be nice if I could directly inspect compiled code
;output or something, to determine without running the code
;whether it's the same.
;(Though now that I've introduced my own bq-handling,
; I should expect different things anyway.
; Mmm. I really should make it macex the resulting crap.
; ... It is conceivable that I could turn it back into
; a bq form; only use this for expanding the macros within.
; Eh.)
      


;Ok, macros have been removed.
;Only pure raw Arc.
;fn's, quotes, constants, variables.


;Hmm... I thought of something important,
;but now I seem to have forgotten....
;A function that I would write here.
;And would finish cps later.
;Ah, free variables.
;Mmm... that pretty fucking obviously...
;Eh...
;Nah, actually,
;it pretty strongly does _not_ depend
;on whether I've CPS-converted it or not.
;... hmm.
;global calls? primops?
;atm I have no primops, except... closure constructors,
;if3/if, closure dereferencers, idfn, backquote cons ops,
;ar-call, and probably ar-apply.
;I could 


;I want to make my own calling convention...
;Also, in general I may want a bunch of side effects
;to express crap.
;(As you encounter foreign functions, insert them into
;a list of things to create your own bindings for.
;And other things...)
;(def cps (x K)
;  (if ssyntax.x
;      (cps ssexpand.x K)
;      atom.x
;      (list K x)
;      (is car.x 'quote)
;      (list K x)
;      (acons car.x)
      
      
      
      
      
      
      
      
      
      
      
      