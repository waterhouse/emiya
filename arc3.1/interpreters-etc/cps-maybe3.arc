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

;Oh god, it turns out I have to handle the "compose in func.
; position" behavior as well.
;... probably really would not be a problem with first class
;macros...
(def de-macro (x (o env nil))
  (if ssyntax.x
      (de-macro ssexpand.x env)
      atom.x
      x
      (let (a . b) x
        (when ssyntax.a
          (zap ssexpand a))
        (if (and acons.a (is car.a 'compose))
            (de-macro (xloop (a cdr.a b b)
                        ;non-tail-rec way from decompose is easiest
                        (if no.a ;composition of nothing shd be idfn
                            (if cdr.b ;multiple values
                                (err "Wat" x) ;are not allowed
                                car.b)
                            no:cdr.a
                            (cons car.a b)
                            (list car.a
                                  (next cdr.a b))))
                            
                      env)
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
                      (de-macro (de-macro-qq car.b env 1)
                                env)) ;bwahaha
                  (is a '$)
                  (cons a b)
                  (cons a (map [de-macro _ env] b))))))))
;I guess I could kind of treat $ like quote.
;Still...
;This is intended to be used for pre-CPS screening.

;Ok, separating things out.
;We should detect uses of $ and maybe other unsupported shit
;as a separate step.

;In the current ac, (let $ + ($ 1 2)) uses the global meaning
;of $; the fact that $ is bound is irrel.
;So... 
;<below>
      
      

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
      ;--except that (bq-append x 'nil) can become x.
      (let r (de-macro-qq-rest cdr.x env n)
        (let a car.x
          (if (and acons.a
                   (is car.a 'unquote-splicing)
                   (is n 1))
              (let (uqs ex) a
                (if (iso r '(bq-quote nil))
                    (de-macro ex env)
                    (list 'bq-append
                          (de-macro ex env)
                          r)))
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

;If someone rebinds cons or quote or join,
;the above will make `(dicks) look weird.
;Oh well.
;I also don't have "quasiquote is in env" override anything.
;Oh well.

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


;currently just looks for $
;since I'm given de-qq'd output, in which that will be
;calls to cons or join or quote, things are nice
;... eh, yeah, (list $ dick) is fine
;also (fn ($) (list $ dick))
;but not (fn ($) ($ dick))
#;(def cps-friendly (x)
  (if atom.x
      t
      (is car.x '$)
      nil
      (is car.x 'fn)
      (let (_ args . body) x
        (all cps-friendly body))
      (all cps-friendly x)))
;ahhh...

;k, got a tolerable printing thing. see dppr9.

;oh, right, dumbass. quote.
(def cps-friendly (x)
  (if atom.x
      t
      (is car.x '$)
      nil
      (is car.x 'fn)
      (let (_ args . body) x
        (all cps-friendly body))
      (is car.x 'quote)
      t
      (all cps-friendly x)))

;wootz. it can handle ev'thing in "a" w/o error.



;I want to make my own calling convention...
;Also, in general I may want a bunch of side effects
;to express crap.
;(As you encounter foreign functions, insert them into
;a list of things to create your own bindings for.
;And other things...)
;Ok, so, I will probably want to use the short name "cps"...
(def cps (x (o K 'idfn))
  (cps2 (de-macro x) K))

;ok, um...
;fns?
;am being fine with ((fn dicks ass) (fn nerf) (fn (x) derf))
;being valid CPS.
;for the moment.
;that would also be executable.
;but only if I do bind my own versions
;of global functions and bs.
;mmm...
;for the purposes of this function,
;I can assume someone else is taking care
;of binding + and things to cps-+.

(= gensym-count 0
   uniq (fn ((o name "gs"))
          (symb name ++.gensym-count)))

;in this step, we refer to constants and variables directly,
;and do not 
;we also refer to functions directly.
;(any alternative will complicate things, and I do want this
; to be executable)
;as for quoted things? ... they'll probably have to be lifted
;out eventually.
;the most likely thing to do with them in a full impl. is to
;store them in closures. (a global func. that refers to '(meh)
; will have a name generated, gs5, that will be bound to the list
; (meh) in the closure's env, and refs to '(meh) will become refs
; to gs5.)
;which makes it difficult to put them in serialized compiled code.
;quote is clearly an advanced feature...
;anyway, leave quotes as are
;btw note we haven't yet converted var names to be all diff.
(def cps-atom-like (x)
  (or atom.x
      #;(is car.x 'fn) ;handle separately
      (is car.x 'quote)))
(def cps2 (x K)
  (let cps cps2 ;bwahahaha
    (if atom.x
        (list K x)
        (is car.x 'quote)
        (list K x)
        (is car.x 'fn)
        #;(let (f arglist . body) x
          ;cps a begin thing
          ;no need to factor this out
          ;because all begins are turned into ((fn () ...)).
          ;... hmm... interesting...
          ;ok, I assume fns are written normally here
          ;(with no reference to continuations).
          ;... 
          ;methinks renaming will be... another step?
          ;I think I may have to deal with complex args.
          ;Might even find it a good idea to make ev'thing
          ;be (fn args (withs x args.0 y args.1 ...)).
          ;Like my ML brothas.
          ;Then rely on later flattening optimizations to get rid
          ;of all that junk.
          ;Hmm...
          ;Shall I...?
          ;This shit be so terrible...
          ;Mmm... I'm thinking it doesn't really
          ;add much. Could just declare that args are
          ;passed in a certain number of registers.
          ;With some way of handling extras.
          ;[sleep cycle]
          ;I think 
          ;[actually now see dppr11; also I want to kill (join xs 'nil)s]
          ;[done]
          ;I think I _should_ expect upstream to handle "o" args.
          ;Rest args are difficult to eliminate, though.
          ;ok, so, this should be a seq of funcalls.
          
          ;... eeyes:
          ;when handling a complex call, like (dick (ass) (ass)),
          ;I may need to bind multiple variables to results.
          ;however, figuring out one binding can be arbitrarily complicated.
          ;therefore, I must have some data structure to store the second
          ;binding while I figure stuff out.
          ;it is conceivable that I could pick things out one at a time,
          ;like <that> -> (ass (fn (var1) >(dick var1 (ass))))
          ;and then extract the second ass.
          ;I suppose I could even, like, store the head of the list
          ;somewhere else... as in ys := (cons <dick> ys).
          ;
          
          ;so I have been enlightened.
          ;- all "fn"s shall be converted, by themselves.
          ;- separately, all funcalls shall be given a cont argument.
          ;and, meanwhile,
          ;fns can be either in func. position
          ;or in arg. position.
          ;the latter should be converted to closures eventually.
          ;the _former_ can be beta-contracted immediately.
          ;...
          ;...
          ;eeh...
          ;'cept with literal fn arguments.
          ;'cause duplicating those may be bad.
          ;ok, the beta-contraction shall happen after closure
          ;conversion, or at least after splitting.
          ;in the meantime...
          ())
        (list K (convert-fn x))
        ;quote and fn are, I think,
        ;the only special forms...
        ;(there's also set! or smthg like that,
        ; but that shouldn't do much)
        ;hmmm...
        ;a thing Appel mentions.
        ;side-effecting primitives.
        ;how they don't bind anything in his design
        ;and this makes it easy to be dumb about
        ;dropping dead-variable-creating operations
        ;without worrying about deleting a side-effect.
        ;... the Arc side-effecting primitives definitely
        ;return a value.
        ;[and note that machine primitives, the STORE operation
        ; or equivalent, do not return a value]
        ;I could have them separate.
        ;you can only store a value that you've already
        ;bound to a variable, after all.
        ;(except maybe this SELp crap, which I might find
        ; useful for my own purposes... but that is likewise
        ; accessible directly anyway. and any benefit from
        ; caching the SELp lookup is a general problem.)
        
        ;anyway, I shall repeat my previous approach.
        ;use side effects to construct lists of exprs
        ;and vars to which they will be bound.
        ;(some of these will be nonces, as in begin-exprs)
        ;(but that will be in "convert-fn")
        
        ;so this must be a function call... OR, since this is
        ;Arc, a lookup into a compound data structure.
        ;I could write "ar-apply" or something.
        ;But there is no need for such disambiguation yet.
        ;I can just leave it like this...
        ;(the code would be _run_ with a CPS version of ar-apply)
        ;oh, right, there's also "if".
        (is car.x 'if)
        (xloop (x x)
          (if no:cdr.x
              (list K nil)
              no:cddr.x
              (list K cadr.x)
              ;now, here...
              ;oh man, I can be extremely fucking lazy
              ;and pass the work off to others
              #;(cps `(if3 ,x.1
                         (fn () ,x.2)
                         (fn () (if ,@cdddr.x)))
                   K)
              ;OR NOT
              #;(withs fname (uniq "f")
                v (uniq "var")
                f `(if3 ,v
                        (fn () ,x.1)
                        ))
              ;nope
              ;so, we must have a single instance of K.
              ;therefore, we must create a wrapper function
              ;that will use it.
              ;hmmm...
              ;'course, if K is already just a var, then
              ;there is little point.
              ;also, if I did this uber-recursively,
              ;then a deeply nested if would create
              ;multiple "(let new-K (fn (v) (K v)) ...)" things.
              ;which would be eventually eliminated by beta-contraction
              ;of some sort. but. mmm...
              ;eh...
              ;could be dumb here and trust in later,
              ;or could be smart here...
              ;I think my aesthetics demand being smart here.
              ;(not too smart, as I'll still create a new thing
              ; even if K is a plain var... ok, my aesthetics
              ; have changed.)
              (withs fname (uniq "f")
                val (uniq "var")
                f `(fn (,val) (,K ,val))
                then-expr (cps x.2 fname)
                else-expr (cps `(if ,@cdddr.x)
                               fname)
                v (uniq "v")
                test-expr (cps x.1
                               `(fn (,v)
                                  (if3 ,v
                                       (fn () ,then-expr)
                                       (fn () ,else-expr))))
                `((fn (,fname)
                    ,test-expr)
                  ,f))))
        ;I may think about call/cc later
        ;but that'd prob. req. thinking about the stack
        ;or about not using a stack
        ;both of which are intimidating.
        ;anyway, now we shall have a funcall.
        (with exprs nil vars nil
          (let u (join (map [if cps-atom-like._
                                _
                                ;not atom, safe to car
                                (is car._ 'fn)
                                (convert-fn _)
                                (let v (uniq "var")
                                  (push _ exprs)
                                  (push v vars)
                                  v)]
                            x)
                       list.K) ;aha
            ;hmm... this doesn't seem to really
            ;leave room for primops that bind multiple
            ;values... but the user would have to handle
            ;them specially anyway, either passing them
            ;a continuation taking multiple arguments or using
            ;some kind of "multiple-value-bind" form that expands
            ;to the same thing
            ;k so these are... um...
            ;actually, each of them might be a complex "if" expr
            ;or some such.
            ;I would want to call cps on each of them with a K
            ;argument that meant the continuation that would
            ;compute the final expression.
            ;now, I could take a "FIX f; f" approach,
            ;or I could take the "(fn ...)" approach.
            ;I have previously said I'll do the latter.
            ;in that case I would probably bind K to "(fn ...)".
            ;in cases of a foreign call, (func x) -> (func x (fn ...)),
            ;this is fine.
            ;in cases of what turns out to be an atom eventually,
            ;n -> ((fn ...) n)
            ;which is kind of ok, but kind of annoying to be creating
            ;work.
            ;but oh well.
            ;closure mucking can happen later, and until then,
            ;dicks are fine.
            ;... hmm. it would appear that this form can be
            ;arbitrarily top-heavy.
            ;... that is true, but ((fn ...) (+ x y)) is still
            ;not allowed.
            (while exprs
              #;(prsn 'while exprs vars u)
              (withs v pop.vars
                ;ex pop.exprs
                uu `(fn (,v) ,u)
                nex (map [if cps-atom-like._
                             _
                             (is car._ 'fn)
                             (convert-fn _)
                             (let v (uniq "var")
                               (push _ exprs)
                               (push v vars)
                               v)]
                         pop.exprs)
                #;(prsn 'withs v uu nex)
                (= u (cps nex uu))))
            u)))))

;oh boy... here we do butts...
;would be easier if I had the cont argument first,
;but I am stubborn.
(def convert-fn (x)
  (with k (uniq "k") gargs (uniq "args") cps cps2
    `(fn ,gargs
       ;demonstrate with "with", then comment out and convert
       ;to raw fns
       #;(with (,x.1 (butlast ,gargs) ,k (last ,gargs))
         ;now we get to deal with "begin"
         ;time to riff on prev. and rebind k
         ;... no, don't do that inside qq's
         ;... hmm... could I win by writing (last (list ...))?
         ;that'd be cool.
         ;oh well.
         
         ;... can't really riff on it.
         ;that shit should be factored out.
         ;but for the moment, terrible things.
         ,(xloop (exprs (cdr:rev cddr.x)
                  res (cps (last cddr.x) k)) ;if (fn ()), fine
            (if no.exprs
                res
                (next cdr.exprs (cps car.exprs
                                     `(fn (,(uniq "ign")) ,res))))))
       ((fn (,x.1 ,k)
          ,(xloop (exprs (cdr:rev cddr.x)
                   res (cps (last cddr.x) k)) ;if (fn ()), fine
             (if no.exprs
                 res
                 (next cdr.exprs (cps car.exprs
                                      `(fn (,(uniq "ign")) ,res))))))
        (butlast ,gargs) (last ,gargs)))))

;oh man, but that shit ain't in cps.
;time to fix.
;next version.
    

(def K (x) (list 'K x))
(def if3 (a b c)
  (if a (b) (c)))
;oh god it's so terrible but it works
;arc> (cps '(if t 1 0) 'K)
;((fn (f26) ((fn (v28) (if3 v28 (fn nil (f26 1)) (fn nil (f26 0)))) t)) (fn (var27) (K var27)))
;arc> eval.that
;(K 1)

#;(def cps-eval (x)
  ;... hoh hoh hoh
  ;... was gonna bind everything in (namespace-mapped-symbols)
  ;or at least in (arc-namespace)
  ;but neh
  ;also that would clobber my if3
  ;hmmph
  )

(= cps-func-table (table))
(= cps-func-list
   '(+ - * / is isnt
       sqrt prn pr prs prsn
       ))
(each f cps-func-list
  (= cps-func-table.f
     (let uf symbol-value.f
       (fn args (last.args (apply uf butlast.args))))))

(def cps-eval (x)
  (eval
   `(with ,(mappend (fn (f)
                      `(,f (cps-func-table ',f)))
                    cps-func-list)
      ,x)))

(mac ce (x) `(cps-eval ,x))

;ok, this fuckin' terrible shit works now
;jesus christ
;I would want to beta-reduce fuckin' crap
;but I think I should closure-convert before I do that
;and to closure-convert, I shall need to know about free variables
;and speaking of which, I should figure out about renaming dicks.
;let us do that.

;we will let the first binding of "v" remain "v",
;and subsequent bindings should become "v1", "v2", ... .
;now, if someone happens to have named a variable "v1"
;already, then this will cause a little problem.
;we would then rename _that_ variable "v3" or wtvr.
;thus, we need to parse out the last number from an
;existing var.
;we shall have a hash table of renamings.
;... shall I do this destructively?
;mmm...

;free vars will be left alone.
;(like constants and shit)
;be careful not to rename nil.

;to compute the renaming for vn,
;we simply find the first v[n+k]
;for which there isn't a binding in the table.
;hmm...
;ok.
;hmm... in this...
;fn and quote are the special forms.
;(interestingly, both will eventually imply entries in a FIX)
;I suppose there's also assign, which hasn't been conv'd yet.
;oh well.
;... if no renaming is needed, I think I can just rename
;a variable to itself. bweheheh.
;... I think I shall have no var0's,
;and I think I shall never rename var[n] to var[m < n].
;so, given var[], I compute n to be 0,
;and given var and n, I look at var[n] and then var[n+1]
;and so on.
;if there's a fuckton of renaming, this could be O(n^2)...
;oh well.
;(I guess I could map "var" to "next unused n")
;(and given N > n, just bump that up to N+1, skipping over
; n+1 through N-1)

(def map-notpicky (f xs)
  (if no.xs
      nil
      atom.xs
      f.xs
      (cons (f car.xs) (map-notpicky f cdr.xs))))

(def name-num (v)
  (withs vs string.v
         n len.vs
    (while (and (> n 0) ;empty sym! or not
                (digit:vs:- n 1))
      --.n)
    (list (sym:cut vs 0 n)
          (if (is n len.vs)
              0
              (read:cut vs n)))))

#;(def rename-vars (x)
  (with rn (table)
    (xloop (x x)
      (if atom.x
          (or rn.x x)
          (is car.x 'quote)
          x
          (is car.x 'fn)
          ;it is guaranteed that there will be
          ;exactly one body-expression
          (let new-arglist
               (map-notpicky
                [if (no rn._)
                    (= rn._ _)
                    (let (v n) name-num._
                      ++.n ;elim var[0]; rm this to not elim var[0]
                      (while (rn:symb v n)
                        ++.n)
                      (= rn._ (symb v n)))]
                x.1)
            `(fn ,new-arglist
               ;ok, you know what,
               ;there is no actual need not to be more general
               ,@(map next cddr.x)))
          (map next x)))))
;^ oh boy that's the first xloop I've written where next is actually
;returned as a value to an external procedure
;and that would not work with my CL version

;AWP NAWP that fuckin' don't work
;must use either nondestructive tables
;or alists
;or smthg
(def rename-vars (x (o rn nil))
  (if atom.x
      (or (alref rn x) x)
      (is car.x 'quote)
      x
      (is car.x 'fn)
      ;it is guaranteed that there will be
      ;exactly one body-expression
      (withs new-rn rn
        new-arglist
        (map-notpicky
         [if (no:alref new-rn _)
             (do (push (list _ _) new-rn)
               _)
             (let (v n) name-num._
               ++.n ;elim var[0]; rm this to not elim var[0]
               (while (alref new-rn (symb v n)) ;oh boy pot. O(n^3) prob.
                 ++.n)
               (push (list _ (symb v n)) new-rn)
               (symb v n))]
         x.1)
        `(fn ,new-arglist
           ;ok, you know what,
           ;there is no actual need not to be more general
           ,@(map [rename-vars _ new-rn] cddr.x)))
      (map [rename-vars _ rn] x)))

;ok, next...
;closure conversion would probably be 
;oh right, free variables.
;k.

;oh man, here I can afford to be a dumbass
;and, like, ... ... ... ... ... [use a table and nev' delete bindings]
;no, not exactly, because a free var could coincidentally
;be named the same thing as something bound in an arglist;
;my renaming doesn't change that shit.
;... a compiled function's [closure or extra dicks] should
;contain ptrs to the symbol objects (which are also found in an
; interned symbol table), and refs to glob vars should go through
;that shit.
;(def free-vars (x)
;  (with bound (table) ;shadowing the "bound" function
;        fvars nil
;    (xloop (x x)
;      (if atom.x
;          (when (and x (isa x 'sym) (no bound.x))
;            (push x fvars)) ;clean up with dedup at end, space is cheap
;          (is car.x 'fn)
;          (

;mmm... not exactly the same.
(def free-vars (x)
  (let fvars nil
    (xloop (x x bnd nil)
      (if atom.x
          (unless (mem x bnd)
            (push x fvars)) ;ddp at end, spc is chp
          (is car.x 'quote) ;sort of like a free var but not now
          nil
          (is car.x 'fn)
          (let new-bnd (join (arglist-argnames x.1) bnd)
            (map [next _ new-bnd] cddr.x))
          (map [next _ bnd] x)))
    dedup.fvars))

;all right...
;closure conversion next? or what?
;jesus christ...
;I think I can do assignment conversion here.
;
          
            
        
        
      
      
      
      
      
      
      
      
      
      
      
      