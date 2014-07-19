;Tables.
;Need a hash table for the symbols, and therefore
;might as well have a general-purpose table.
;(Also a weak table...)
;(Or, no, just a table where the vals are weak pointer
; wrapper things that say "when gone, (scdr kv DELETED)".)
;(or rather cmpxchg)
;(Btw, it's yet possible to have an iterator thing (a) look
; in the old vec at hash(i), (b) look in the new vec at
; everywhere that the hash there could produce ...
; Well...
; Ok, it's possible for resizing to shrink shit, in which case
; many would map to one.
; So, you look at both the sizes of the old vec and the new
; vec, find all things that could be shared at a certain
; hash value, dedup them, check that the old vec and the new
; vec are still ...........
; Gah...
; Ok, if you _lock_ the thing first, then maybe ...
; Well, some shit can maybe be deduced. If not, then at least
; it seems not too terrible to fall back on a fairly dumb
; approach.)
;Since I've figured out a fairly acceptable approach for
;multithreading, I think I'm fine writing single-threaded
;code here.


;Datatypes probably go at the top. ;Yes, indeed.

(= types-list*
   `(int ,@(randperm '(fn sym cons char
                       string user vector))))

(= type-num (table)
   type-name (table)) ;here we go, good name
(on x types-list*
  (= type-num.x index type-name.index x))

(= user-type-count 0
   user-type-num (table)
   user-type-name (table) ;meh
   user-types-list* nil
   )
(def enumerate-user-type (sm)
  (let u user-type-count
    ++.user-type-count
    (= user-type-num.sm u
       user-type-name.u sm
       user-types-list* (join user-types-list* list.sm))
    u))
;curious how the numbers are assigned much later than the
;procedures are defined; this prob. wouldn't be so in assembly
;[unless I used macros to do that]
;[which in fact I probably would, let's change this]
(map enumerate-user-type '(uclos dyn umac))

($ (struct user-obj (tag val)
           #:transparent))
(= user-obj $.user-obj
   user-obj? ($:lambda (x) (if (user-obj? x) 't 'nil))
   user-obj-tag $.user-obj-tag
   user-obj-val $.user-obj-val)
(= user? user-obj?)
(= user user-obj)



;Oh man.
;I have rediscovered a reason for giving closures arbitrary
;"trace me" code.  At least for running.
;If a closure knows it's saved a cons cell, and it'll ask
;for the car and/or cdr, then it may as well have that be
;traced before execution begins.
;....
;This seems it can be extended pretty far.
;However, note that upon first creation...
;If you extend it into tracing the saved things deeply,
;and have the main code assume they've been traced,
;then note that upon first creation, naively, it might not
;have been traced.
;You could create it with a "trace-exec" ptr, possibly.
;Depends on your use case.
;Interesting...



;Cleanup, as well as making *all* Arc functions be bclos's.
;Will enforce by removing the ability to apply raw Arc fns from
;uapply.
;After this...
;It's all been turned into CPS, so turning it into assembly code
;that "uses a stack" is actually unnecessary as a prereq. for
;exhibiting GC.

(= word-before (table))
;maps code-pointers (memory addresses) to the memory address
;8 before it (the "move me" code-pointer).
;in assembly this mapping would be achieved by subtracting 8.

(= sspace ($.make-weak-hasheq))
;maps objects to what semispace they're in.
;in assembly this mapping would be achieved by bit-testing (or more
; precisely with TEST reg, [current_fromspace_mask] or similar).
;all that's actually important is that the semispace that new objects
;get created in, and that old objects get moved into, is unified and
;is different from the previous semispace.
;so here I might as well use integers.
(= cur-space 0)

;now, unfortunately, "cons" and shit by default will create objects
;whose mapping in that thing is "nil".
;...
;also the implicit "list" that creates rest argses.
;...
;so it seems, if I want to ensure that single important thing, then
;I will have to explicify all list creation.
;(along with all object creation)
;... which is probably doable, but in the meantime, want to establish
;some other stuff first.

(= two-words-before (table))
;i.e. "trace me" code-pointer.

(= three-words-before (table))
;and this is a pointer to information about the closure.
;e.g. its source code, its name.

(= four-words-before (table))
;and this is "trace-exec".
;trace-exec needs no four-words-before itself.
;(though for paranoid safety one could put itself there)

;and there will be a "trace-execute" thing, used by "move me".
;so each closure, and each continuation (I'm going to use separate
; names for them), will have a main code block with three pointers
;behind it, another very short code block with three pointers behind
;it (trace-exec), one short code block (normal -> move me; installs trace-exec),
;one generic code block that just RETs (normal -> trace me),
;one code block that should never be called (trace-exec -> move me),
;and one short code block (trace-exec -> trace me).
;all this shit should be generically creatable with assembly macros.
;and, of course, with Arc macros.
;you'd use it in place of a simple "ueval_k1:".

;so, there are a couple of kinds of things.
;there are closures that will be repeatedly created at runtime by
;usual code.
;I need eight-butts for those.
;there are continuations that will be repeatedly created at runtime
;by usual code.
;I need eight-butts for those.
;there are closures with empty envs that will contain builtin procs
;and will be created once at startup.
;I need eight-butts for those, as well as some startup.
;very well.


(= moved-to ($.make-weak-hasheq))
;in assembly you overwrite word zero of the structure with a neg. addr.






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


;Oh man, btables.
;I'm arbitrarily saying that the minimum size is 4.
;Which shall also be the size upon creation.
;Now... the last element is a work pointer thing.
;Default to 0 is good, and a nice pun.

;btable: user=[is-table new-vec old-vec count lock]
(def make-btable ()
  (user-obj user-type-num!table ;not btable...? sure.
            (list (make-vector 5 0)
                  nil
                  0
                  nil)))
(def btable-new (x) user-obj-val.x.0)
(def btable-old (x) user-obj-val.x.1)
(def btable-count (x) user-obj-val.x.2)
(def btable-lock (x) user-obj-val.x.3) ;useless atm
(def btable-set-new (x v) (= user-obj-val.x.0 v))
(def btable-set-old (x v) (= user-obj-val.x.1 v))
(def btable-set-count (x v) (= user-obj-val.x.2 v))

(enumerate-user-type 'table)
(def btable? (x) (and user-obj?x (is x!tag user-type-num!table)))

;Hashing is about to come up.

;Default comparison function: iso.

;O-k, so, iso....
;Mmmeh.

;How and why did I survive so long without vector-ref shit.

(def find0 (f xs)
  (if (is xs 0)
      nil
      f:car.xs
      car.xs
      (find0 f cdr.xs)))

(def btable-insert (b k v)
  (withs h uhash.k
    (aif (aand btable-old.b
               (find0 [uiso car._ k]
                      (it:bit-and (- len.it 2) h)))
         (= cdr.it v)
         (withs new btable-new.b
           n (bit-and (- len.new 2) h)
           slot new.n
           (aif (find0 [uiso car._ k]
                       slot)
                (= cdr.it v)
                (do (push (cons k v) new.n)
                  (let u (++ user-obj-val.b.2) ;must do it this way
                    (btable-work b u)
                    v)))))))

(def btable-work (b count) ;count = btable-count [wtvr]
  (aif btable-old.b
       (withs h dec:len.it ;lel, var names
         (xloop (wp it.h work-count 2)
           (if (is wp h)
               (btable-set-old b nil)
               (is it.wp 0)
               ;for the moment, just letting tombstone = 0
               (next inc.wp work-count)
               (let (kv . rest) it.wp
                 (let (k . v) kv
                   (let h uhash.k ;could store hash w/ crap
                     ;now we can be bretty unsafe (single-threaded)
                     (push kv (btable-new.b
                               (bit-and h (- len:btable-new.b 2))))
                     ;likewise
                     (= it.wp rest)
                     (when (> work-count 1)
                       (next wp dec.work-count))))))))
       ;in this case, maybe resize
       (withs new btable-new.b
         n dec:len.new
         (when (> count n)
             ;s. t.
           (btable-set-old b new)
           (let new2 (make-vector (+ 1 (* n 2)) 0)
             (btable-set-new b new2))))))

(def rem0 (f xs)
  (if (is xs 0) 0
      f:car.xs cdr.xs
      (cons car.xs (rem0 f cdr.xs))))

;with s.t., no need for DELETED BS
;also can do completely functional updates
(def btable-delete (b k)
  (withs h uhash.k
    old btable-old.b
    new btable-new.b ;in m.t., get new-old-new, check af. done
    (let res
      (if (and old
               (withs n (bit-and h (- len.old 2))
                 (if (find0 [uiso car._ k] old.n)
                     ;double the work!
                     (do (zap [rem0 [uiso car._ k] _] old.n) t)
                     nil)))
          t
          (withs n (bit-and h (- len.new 2))
            (if (find0 [uiso car._ k] new.n)
                (do (zap [rem0 [uiso car._ k] _] new.n) t)
                nil)))
      (if no.res
          nil
          ;maybe shrink
          ;let's say... must always be at least size 4
          (do1 t
               (let count (-- user-obj-val.b.2)
                 (when (and (< count (ash len.new -1))
                            (> len.new 5))
                   (btable-set-old b new)
                   (btable-set-new b (make-vector
                                      (+ 1 (ash len.new -1))
                                      0)))))))))

(def btable-lookup (b k (o fail nil))
  (withs h uhash.k
    old btable-old.b
    new btable-new.b
    (aif (and old (find0 [uiso car._ k]
                         (old:bit-and h (- len.old 2))))
         cdr.it
         (find0 [uiso car._ k]
                (new:bit-and h (- len.new 2)))
         cdr.it
         fail)))

;there should be a btable-for-each, but atm too lazy
;to deal with continuations, so will just do this:
(def btable->list (b)
  (accum a
    (each v ((aif btable-old.b
                  [cons it _]
                  idfn)
             (list btable-new.b))
      (forlen i v
        (xloop (xs v.i)
          (when acons.xs
            (a:list caar.xs cdar.xs)
            next:cdr.xs))))))
         

;Oh boy.
;Do we go unsafe?
;Do we go guaranteed-correct, but O(n^2)?
;Do we go guarnteed-correct-and-O(n[log n]), but garbage-making
; and slow?
;Do we go guaranteed-correct-and-O(n[log n]) and not garbage-
; making unless sufficiently large, but complicated?
;And then there's what fields to look in for dick-objects.

;...
;Do need ucloses and umacs to be supported.
;So, then.
;Ok, this has happened enough that I am going to need a macro
;to do it all.
;So.

;Generic function.
;Takes some set of arguments.
;Dispatches on the types of .......
;Hmm, types of both or of just the first?
;...
;Actually, I think I can make do with the latter.
;A step of checking if the types are identical can
;be in the main body or something.
;So.........

;Let's see.
;I can simply define a function that is "iso up to depth N".
;And declare that that is dick.
;(Also can define one that is unsafe.)
;...
;I think I'll just use "unsafe" for now.
;I think it'll probably be ok.
;If not, I can find that out.

(def uiso (a b)
  (if (is a b)
      t
      (isnt base-tag.a base-tag.b)
      nil
      (uiso-dispatch a b)))

(mac def-dispatch (name args val . cases)
  (withs 
    base-vec (symb name '-base-table)
    user-vec (symb name '-user-table)    
    `(do (def ,(symb name '-dispatch) ,args
           ((,base-vec (base-tag ,val)) ,@args))
         (= ,base-vec (make-vector 8
                        (fn ,args (err "dispatch: unspecified" ,@args)))
            ,user-vec (make-vector 256
                        (fn ,args (err "dispatch (user): unspecified" ,@args)))
            (,base-vec type-num!user)
              (fn ,args ((,user-vec (user-type-tag ,val)) ,@args)))
       (each (tp bd) ',(tuples 2 cases)
         ;(prsn tp bd)
         (= ((if type-num.tp ;see if tp is base or user type
                 ,base-vec
                 ,user-vec)
             (or type-num.tp
                 user-type-num.tp))
            (eval `(fn ,',args ,bd)))))))

(def-dispatch uiso (a b) a
  cons (and (uiso car.a car.b)
            (uiso cdr.a cdr.b))
  int nil
  uclos nil ;fuck it; only eq
  ;bclos nil ;ditto
  fn nil ;ditto ;note fn = bclos
  vector (and (is len.a len.b)
              (no:find-int [no:uiso a._ b._] 0 dec:len.a))
  sym nil
  string nil ;Arc's "is" already checks
  char nil
  umac (uiso umac-clos.a umac-clos.b)
  dyn nil ;yeah
  ;btable ;....... feh ;is named table
  table
    nil
  )

;Hoh man, procedure-rename is in Racket...
  


(= hash-depth* 5) ;arbitrary, don't change in mid-game
(def uhash (x) (uhash-rec x hash-depth*))

;....
;I talk about throwing away performance, but here I
;am probably using two tables, for probably performance
;reasons.  (Or semantics, I guess.)  Oh well.
(def uhash-rec (x n)
  (let u base-tag.x
    (if (is n 0)
        u
        ((vref uhash-base-table u)
         x n))))

(= uhash-base-table
   (make-vector 8 [err "How do I hash this?" __]))

(def uhash-int (x n)
  x)
;Choice:
;When dick reaches 0, either the caller can
;do shallow hashing, or the callee can do it.
;It leads to less code and probably more CPU work
;if the callee does it.  So let's do that.
(def uhash-cons (x n)
  (if (is n 0)
      type-num!cons
      (+ (uhash-rec car.x dec.n)
         (uhash-rec cdr.x dec.n))))


(def uhash-string (x n)
  ;lel
  (reduce + (map int (as cons x))))

(def uhash-vector (x n)
  9001)
(def uhash-char (x n) int.x)
;for this thing, the hash should be stored in the sym itself,
;but ... lolz.
(def uhash-sym (x n)
  (uhash-string usym-name.x n))

;After some random discussion, extra nonce fields for hashing
;seem like maybe not too bad, but... geh.
;Screw them for now.  (Single use: identity hashing.
; How common is it?  Dunno.)

;Actually, I do want identity hashing in the arc-boot for one
;reason: Mapping closures and macros to their source/original
;versions.
;However, those are uclos's.
;Their code portion is supposed to not be mutated...
;(Although they might quote something that does ... mmm.
; Unsafe API for this shit?
; ..........
; Feh, whatever, sure.)
;Meanwhile, yeah, for compiled closures, it should be easy
;to at least distinguish based on the codeptr, which can
;have some nonce sitting behind it.

(def uhash-fn (x n) ;oh boy
  43687) ;lel

(def uhash-user (x n)
  (uhash-user-table:user-obj-tag.x x n))

(= uhash-user-table (make-vector 256 [err "Oh god" __]))

(each (x y)
  '((uclos (fn (x n)
             (uhash-rec (list uclos-arglist.x
                              uclos-body.x) ;no env
                        n)))
    (umac (fn (x n)
            (uhash-rec umac-clos.x dec.n))) ;in case
    (dyn (fn (x n)
           (uhash-rec dyn-id.x n)))) ;should be an integer
  (vset uhash-user-table
        user-type-num.x
        (= (symbol-value:symb 'uhash- x)
           (eval y))))

(each x types-list*
  (vset uhash-base-table
        type-num.x
        (symbol-value:symb 'uhash- x)))



      
      


;(def uhash-int (x)

;Ok.
;We'll be pretty damn dumb.
;Now, to deal with recursion, all functions will take a "recursion"
;argument, even if it's inapplicable.
;An issue is hashing closures.

;Also equal? on closures.
;Or structs.
;Someone could define a struct that has some field that's, like,
;a counter or PRNG result that isn't supposed to be counted for equal?
;purposes.
;'Course, such a person could define a new procedure on top of equal?
;and use that instead.

;Now, one could put a "hash-me" ptr at the head of closures.
;Two observations.
;1. Geez, god-objects.
;2. Similar functionality in the huge list of code-ptrs in front
;   of closures and in the tables of code-ptrs for other kinds of
;   objects.  Duplicated?  Could it be factored out?

;All right, fuck it.  Closures can be as godlike as necessary.
;Waste as much space in the closure-"prototype" object as possible.
;So.
;A field for "number to move", a field for "number to trace",
;a field for "number to hash" or something (better arrange your
; closures so that they have non-hashables to the right), ...
;A field for "equal?" when desired... feh.  Non-scalable approach,
;but shall use it for the moment.  Geez.
  


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
   ;usym-name $.usym-name
   ;^ accually might be nil [which we're halfheartedly using
   ; along with normal usyms]
   usym-name [if (is _ 'nil) "nil" $.usym-name._]
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
($ (struct bclos ((code #:mutable) env) #:transparent))
(= make-bclos $.bclos ;clunky name for clunky operator
   bclos? ($:lambda (x) (if (bclos? x) 't 'nil))
   bclos-code $.bclos-code
   bclos-env $.bclos-env)

(= bclos-set-code ($ set-bclos-code!))

(def bclos (code . args) ;convenient name for convenient operator
  (make-bclos code (apply $.vector args)))

#;(def fn->bclos (f)
  (bclos (fn (self . args) (apply f args))))
;is that acceptable?
;...
;nah
;
;all right:
;fn->bclos ain't happening.
;but an equivalent for functions supplied by their symbolic name
;can exist.
;[ironically, it looks like I never use fn->bclos]

;ok, um...
;hmm...
;must define empty bcloses.
;for these, just need a four-butt, or actually a three-butt.

(def bclos-move-0 (self ptr) (bclos ptr))
(def bclos-trace-0 (self ptr) 1)

#;(mac fn-bclos (args . body)
  (w/uniq name
    (let info `'(,name ,args nil ,body)
      `(do (def ,name ,args ,@body) ;no name, conflict ;ah
         (= (word-before ,name) bclos-move-0
            (two-words-before ,name) bclos-trace-0
            (three-words-before ,name) ,info)
         ,name))))

(mac rfn-bclos (name args . body)
  (let info `'(,name ,args nil ,body)
    `(do (def ,name ,args ,@body) ;no name, conflict ;ah
       (= (word-before ,name) bclos-move-0
          (two-words-before ,name) bclos-trace-0
          (three-words-before ,name) ,info)
       (bclos ,name))))

(mac fn-bclos (args . body)
  `(rfn-bclos ,(uniq) ,args ,@body))

(def bclosify (name)
  (withs n ($.procedure-arity eval.name)
    args (if int?n (n-of n (uniq)) (uniq))
    (eval `(rfn-bclos ,(symb "builtin-" name)
                      ,args
                      ,(if int?n
                           `(,name ,@args)
                           `(apply ,name ,args))))))


;now...


;[strategy 0 w.r.t allocing and saving:
; save all vars on stack, grab memory, retrieve from stack.
; should probably start with that.]


;Oh man.
;I must have thought of this at some point before, but...
;"Forwarding pointer" could = "is pointer and isn't to fromspace".
;No need for negating (or flipping a high bit).
;Yes, I definitely did figure this out before...
;I imagine that it proved a bad idea due to some thing.
;But I think that thing may be absent now.
;...
;Closures...
;Would have to be careful there, for sure.
;Anyway, leave as is for now.

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

#;(def bcall (b . args)
  (apply bclos-code.b b args))
;bcall is never used first-class, so...
(mac bcall (b . args)
  (if (len< args 5)
      `(,(symb 'bcall- len.args) ,b ,@args)
      `(apply bcall-n ,b ,@args)))

;in fact, there is one case of bcall-3, many of bcall-1,
;and none of bcall-n.
(def bcall-1 (b x) (bclos-code.b b x))
(def bcall-3 (b x y z) (bclos-code.b b x y z))
(def bcall-n (b . args) (apply bclos-code.b b args))


;Arbitrarily putting "d e k" at front of arglist to the extent applicable.
;Also shall include user types.
;... Usually "d k", because no e.  Oh boy.  Oh well.

;I do do error handling, but...
;There is a difference between "user error" and "implementation error".
;It is sort of appropriate... well... whatever.
(mac uassert (expr)
  `(unless ,expr
     (err "Assertion failed:" ',expr)))


;;moving definition of ueval down

;note there is technically a change in semantics
;if btwn ueval and ucall, someone modifies cdr.x,
;then we will now see the results of that

;ok, this is the first eight-butt we will create.
;unfortunately we will duplicate the information seen in
;the call to "bclos" above, that those four vars are saved.
;unfortunately this is ............
;ok, maybe some devious macro-defining assembly macros could
;create that shit.
;but actually, 'tis not too bad, 'cause the corresponding
;"bclos" code is actually a bunch of movs, not a clear call.
;so this should be fine.

#;(def ueval-k1 (self _)
  (ucall e.0 e.1 e.2 _ e.3))
;instead...
;we want:
#;(withs the-code (fn (self _)
                  (ucall e.0 e.1 e.2 _ e.3))
  saved-list '(d e k cdr.x)
  saved-n len.saved-list
  move-code (fn (self)
              (move-bclos self saved-n))
  trace-code (fn (self)
                (trace-vector bclos-env.self saved-n)
                (bclos-set-code self the-code))
  info `(ueval-k1 (self _) ,saved-n)
  ;now, in trace-exec, there are a few ways I could get
  ;the the-code.
  ;LEA RIP-relative, or having trace-exec reach into ...
  ;hmm...
  ;with multithreading...
  ;could be accomplished with a great deal of care, but
  ;.............. actually nvm, definitely not.
  ;all right. LEA RIP-relative, as planned.
  trace-exec (fn (self _)
               (trace-code self)
               (the-code _))
  trace-move (fn (self) (err "This should never happen" self))
  neednt-trace (fn (self) nil)
  
  
  (= ueval-k1 the-code
     word-before.the-code move-code
     two-words-before.the-code neednt-trace
     three-words-before.the-code info
     
     ueval-k1-trace-exec trace-exec ;unnecessary, but would appear in asm
     word-before.trace-exec trace-move
     two-words-before.trace-exec trace-code
     three-words-before.trace-exec info)) ;probably overkill
;also need to add four-words-before

;Now, seeing the above:
;- Only trace-code [and maybe the-code] directly references the-code.
;  trace-exec references trace-code.
;  These three things need to be actually defined (though trace-code
;   and trace-exec will be rather short).
;  The only free variables in the rest that are specific to this
;  function are saved-n, and that will likely range from 0 to about 6.
;  These are ripe for reuse.

;........
;Actually, because of my scoring system, tracing should ...
;probably return n, the number of things traced.
;Or 8n for the number of bytes traced.
;...
;There are other possible approaches.
;Like storing n in the corpse.
;But that'd mandate all closures be at least size 3.
;Sigh, tradeoffs...
;Also more memory traffic, possibly.
;K.
;[Though all this n stuff could ........ eh.]

#;(def shouldnt-move (self) (err "This should never happen" self))
;oh man the way to do that is to have the "move" thing be three-words-
; behind, and to omit that from el thingo.
;possibly along with "info".
;oh well. just one word of memory; fine for the moment.

;functions...
;neednt-trace and trace return saved-n + 1, that being total size in words.
;move returns the moved thing, of course.

;I don't need gensyms because ... ok nvm I do.
;... do I accept n-args? ... 
;..............
;this is pretty ...
;restricted. nah. do work to make that happen elsewhere.
;however, the arglist may have destructuring.
;so.

;....
;sometimes code will need to be moved, sometimes not.
;this is why I have this model.
;also btw some closures are empty.
;................................
;ok, so, if we have a nice eight-butt (or wtvr),
;then it can just be a thing that helps out the "move" thing
;if the "move" thing can find the trace-exec ptr by subtracting n
;from the codeptr.
;........ multithreading...
;... it is conceivable I could find ways to fix that.
;but.
;--oh, and........
;hmm.
;... ok, I think.
;... neh. the move really needs to know ...
;actually, it would be easy (but would cost one instruction)
;to save the codeptr in a register before CALLing it.
;(no cost on RISC machines, presumably)
;...............
;actually, really on multithreaded, you will need to CMPXCHG...
;--good lord, that's a lot of effort.
;right ho.
;(and actually you'll want to test if it's negative => fwd beforehand)
;so, yes, this underlying subroutine used by move (not actually move)
;can definitely be passed the codeptr as an argument.

;btw, "fromspace-mask" (i.e. nonzero => fromspace) is the right thing.
;'cause you can then replace fromspace-mask with all 0's when GC is done.
;...
;I'm afraid this will mean it's best to do fromspace-mask and then
;type check.
;Which implies negative integers in data structures will reduce performance
;compared to positive numbers during GC.
;Which might drive me a little crazy. But oh well.
;....... But then there are functions that need to do type-checking
;immediately. Ok, different crap.
;Fuck it all.
;...
;car can be inlined with a read barrier that does stuff.
;k wtvr
;[I mean: load car; TEST dick, FROMSPACE_MASK; jnz grovel; [...]
;  grovel: extract type tag; CALL [polymorphic move + 8*tag]; jmp [...]]
;That shit probably helps best-case at the expense of GC-case.
;Though with high bits, really... the TEST FROMSPACE_MASK thing will
;in fact be really accurate unless you use large integers a lot.
;Kk bretty good move on.

;btw this soul-searching about moves for bclos needn't be global.
;so, proceed...

(def shouldnt-move (self ptr) (err "This shouldn't happen" self))

;(def bclos-move-1 (self ptr) (move-bclos self ptr 1))
;(def bclos-trace-1 (self ptr) (trace-bclos self ptr 1))
;(def neednt-trace-1 (self ptr) 2) ;inconsistent naming ftw [acc...]

(each n '(1 4 3 2 6)
  (map eval
   `((def ,(symb 'bclos-move- n) (self ptr) (move-bclos self ptr ,n))
     (def ,(symb 'bclos-trace- n) (self ptr) (trace-bclos self ptr ,n))
     (def ,(symb 'neednt-trace- n) (self ptr) ,(+ n 1)))))

;ok, it turns out trace should also easily be passed ptr.
;so...
;it can get ...
;...
;oh, good lord.
;...
;ok, so...
;[economizing a good deal on code size here--good]
;if we put the-code four words before the beginning of the trace-exec
;code, then trace can be passed the ptr to trace-exec, and can subtract
;32 to get the-code.
;one may as well minimize abuse of the instruction cache... eh.
;well, ok then.
;[again this need not be done globally]
;[... again, to trace, you'll have to load [it], and call [that - 16]
; or wtvr. therefore addr must be in reg.
; as for trace-exec... fairly simple for it to LEA its start and
; then call [that - 16]. --or call the appropriate trace-n by name, that's
; probably a bit better--cpus are probably more accustomed to that.]

(= closure-statistics (table))

;... oh, right.
;we're bein' fuckin' assembly dickheads.
;so that means anything I name must be named.
(mac def-bclos (name args saved . body)
  (withs n len.saved
    self car.args ;enforced
    gargs (map [uniq] cdr.args)
    trace-exec (symb name '-trace-exec)
    ;neednt-trace (symb name '-neednt-trace) ;really this? wtvr ;not here
    trace-n (symb 'bclos-trace- n)
    move-n (symb 'bclos-move- n)
    neednt-n (symb 'neednt-trace- n)
    shouldnt 'shouldnt-move 
    
    info `'(,name ,args ,saved ,body) ;heh
    
    
    `(do (def ,name ,args ,@body)
       #;(def ,trace (,self)
         (trace-vector (bclos-env ,self) ,n)
         (bclos-set-code ,self ,name)
         ,n)
       (def ,trace-exec (,self ,@gargs)
         (,trace-n ,self ,trace-exec)
         (,name ,self ,@gargs))
       
       (++ (closure-statistics ,n 0))
       
       (= (word-before ,name) ,move-n
          (two-words-before ,name) ,neednt-n
          (three-words-before ,name) ,info
          (four-words-before ,name) ,trace-exec
          
          (word-before ,trace-exec) ,shouldnt
          (two-words-before ,trace-exec) ,trace-n
          (three-words-before ,trace-exec) ,info
          (four-words-before ,trace-exec) ,name))))

;oh boy.


;these things: env vectors, not to be confused with potentially
;large user vectors.
(def trace-vector (v n)
  (unless (is n $.vector-length.v)
    (err "trace-vector: Oh snap, length error" v n))
  (for i 0 dec.n
    (let u (move-obj (vref v i)) ;this might save shit on the stack
      ;btw that would be an inlined "TEST for fromspace and for ptr",
      ;so this won't even try to move integers [or non-fromspaces]
      ;now at this point, we would use CMPXCHG in multithreaded.
      ;could actually do that in Racket. but wtvr. for now:
      (vset v i u))))

(def copy-vector (v n)
  (unless (is n $.vector-length.v)
    (err "trace-vector: Oh snap, length error" v n))
  (apply $.make-vector ($.vector->list v)))

;... Oh, right.
;...
;Actually, never mind.

;is subroutine
(def move-bclos (self self-code n)
  (unless (is n ($.vector-length bclos-env.self))
    (err "move-bclos: Length error!" self n))
  ;so self will be a pointer to a corpse, in fromspace, which may
  ;or may not have a forwarding pointer
  ;(aif moved-to.self ;would be a function of self-code in asm
  ;       it ;is already calculated elsewhere
  (let trace-exec-code ;(two-words-before self-code) ;nope
       four-words-before.self-code
    (let u (make-bclos trace-exec-code (copy-vector bclos-env.self n))
      ;in assembly, it's all one structure, so the above is
             ;kind of correct
             ;at this point--forwarding pointer--we would CMPXCHG,
             ;but for now:
             (= moved-to.self u)
             u)))
;the above is intended for fairly specialized (though generic) use
;the below will indirectly depend on the above
           
(def trace-bclos (self self-code n)
  (trace-vector bclos-env.self n)
  ;in this case, prob. no need for cmpxchg
  (bclos-set-code self four-words-before.self-code)
  (+ n 1)) ;score!
  
  
;ah, yes, I'll need a dispatching table for these... sigh...
;and oh dear lord, perhaps also one for user objects.
;goddammit.
;I guess user objects could just be tag-wrappers.
;But ...
;...
;I guess I could have a facility for 

;Byte strings.
;Is that in my above lists?
;I kinda don't think so.
;It should edge out tables, if they are in.
;--Ok, no space for that.
;Well.
;
;Ok, so, byte strings, either "weak hash" or "weak pointer", and "C object"
;objects will have to be in the "user tag" category, and they will need weird
;ass mothafuckin' ways of tracing and moving them.
;... moving, or just tracing?
;... I guess tracing.
;Anyway, you will need to probably be able to put arbitrary pointers to moving
;and tracing code somewhere.
;.....
;Movable? Immovable?
;This is an annoyingly big sticking point...
;--oh, hey.
;I already need some pointers to things like nil.
;These need to be 
;
;Ah.
;I can have the default function be:
;"if vec is a vec with len > n, and vec.n isn't nil, then call that on this"
;... ... ...
;Um, is that for moving? Fuck.
;Yes, it is.
;(Or dicking. Whatever.)
;Then vec can simply be one of a small number of variables that are explicitly
;GC-moved/traced.

;...
;Ok, fuck it.
;There's a lot of shit that I could add.
;Including shit that enables adding other shit.
;But I can add that later.
;And even small amounts of built-in wrongness can be corrected
;in the next version or whatever.
;For now...
;Eeeanyway.

(def move-obj (x)
  (if (or int?x char?x)
      x
      (aif moved-to.x
           it
           (if bclos?x
               (word-before:bclos-code.x x)
               ;bclos-code.x would have been loaded already to compute moved-to.x
               x)))) ;nothing else moving atm
;there should def. be some kind of table to do that shit
;but atm idk


;ok, so, in this scheme, it's all a bit unnecessary that you have
;special personalized "move me" pointers per closure.
;all that distinguishes them is n, the number of variables they
;have saved.
;however, in a full implementation where you are generating (or loading)
;code at runtime and putting it in GC-managed memory, and possibly doing
;clever things on top of that...
;[and yet also having some closures that rely on code in non-GC memory...
; such as all the startup code]
;that is why I resolved on this scheme. yes, proceed.
           
;ok, back to dicks.
;and now I shall move that definition of ueval down here.

;A more awesome default case.
(def ueval (d e k x)
  ;(when (and cons?x (is car.x 1))
  (if usym?x ;using artificial syms
      (lookup d e k x)
      cons?x
      (with k1 (bclos ueval-k1 d e k cdr.x)
        (ueval d e k1 car.x))
      (bcall k x)))

(def-bclos ueval-k1 (self _) (d e k cdr.x)
  (ucall e.0 e.1 e.2 _ e.3))
    

;no quasiquote, is macro
;Should I segregrate memory allocations? ... This is good enough.
;Should I go for "dlet"?  [I didn't even take account of that in
; my de-macro procedure...] Or "call-with-parameterization"?
;... Meh... Eh... Yeah, screw dynamic variables; let's make this simpler.
;get ready
(def ucall (d e k f xs)
  ;(when (is f 1)
  ;  (prsn 'ucall f xs))
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

(def-bclos ucall-k1 (self _) (d e k x)
  (uassign e.0 e.1 e.2 e.3 _))
;Often they do look like that. But ... ... I *think* not always.
;[Meh.]
;Geez, some of these may actually be identical.
(def-bclos ucall-k2 (self _) (d e k)
  (ueval e.0 e.1 e.2 _))
(def-bclos ucall-k3 (self _) (d k f)
  (uapply e.0 e.1 e.2 _))

;finally, a complex thing
(def map-ueval (d e k xs)
  (if no?xs
      (bcall k xs)
      (let k1 (bclos map-ueval-k1 d e k cdr.xs)
        (ueval d e k1 car.xs))))

(def-bclos map-ueval-k1 (self _) (d e k cdr.xs)
  (let k2 (bclos map-ueval-k2 _ e.2)
    (map-ueval e.0 e.1 k2 e.3)))
;... we have some options.
;we can make the closure "flat", by putting e.2 in the
;map-ueval-k2 closure, which is the obvious thing;
;or we can put a ptr to k1's self in the k2 closure.
;the latter is vaguely worse in a few ways, although it
;would be necessary if these variables could ever be modified.
(def-bclos map-ueval-k2 (self _) (_ e.2) ;could rename, but wtvr
  (let u (cons e.0 _)
    (bcall e.1 u)))

;oh man, remember that we "apply" in diff. order now (d k vs k d)
;"fn?" = builtin [poss. closure], "uclos?" = user closure (i.e. crappy)
;.........
;ok, let's have some jump tables.
;... yes, tags. righto.
;tags are currently syms, although there is still base vs user.
(def uapply (d k f args)
  ;(prsn 'uapply prettify.f)
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
      (bcall f k d args) ;an inlined bcall ;de-inlined
      (err "Fuck you I ain't applyin' this" f args d k)))

(= uapply-base-table
   (make-vector 8 (fn (d k f args) ;dumbass, it's this arg order
                    (uraise d k (list 'apply-unknown-error f args)))))
(map (fn ((x y)) (vset uapply-base-table type-num.x symbol-value.y))
     `((cons apply-cons)
       (string apply-string)
       (user apply-user)
       (fn apply-fn)))


(def apply-uclos (d k f args)
  (with ev uclos-env.f ag uclos-arglist.f bd uclos-body.f
    (let k1 (bclos apply-uclos-k1 d k bd)
      (join-e d ev k1 ag args))))

(def-bclos apply-uclos-k1 (self _) (d k bd)
  (ubegin e.0 _ e.1 e.2))

;here I'll just be lazy
(def apply-btable (d k f args)
  (let u (btable-lookup f car.args
                        (aand cdr.args car.it))
    (bcall k u)))


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
                                 (fn (d k f args) ;dumbass, it's this arg order
                                   (uraise d k (list 'apply-user-unknown-error
                                                     f args)))))

(vset apply-user-table user-type-num!uclos apply-uclos)
(vset apply-user-table user-type-num!dyn apply-dyn)
;no applying umacs
(vset apply-user-table user-type-num!table apply-btable)



(def base-tag (x) ;syms atm
  (type-num
   (if int?x 'int
       fn?x (err "base-tag: This is an Arc fn" x)
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
    (if (is u #;user-type-num!user ;dumbass
            type-num!user)
        (let v user-obj-tag.x
          (aif user-type-name.v
               it
               (err "Unknown user type" v x)))
        type-name.u)))


;ok, types out of the way, jesus [prob. not entirely]

(def ubegin (d e k xs)
  (if no?cdr.xs
      (ueval d e k car.xs) ;tail call elim
      (let k1 (bclos ubegin-k1 d e k cdr.xs)
        (ueval d e k1 car.xs))))
(def-bclos ubegin-k1 (self _) (d e k cdr.xs)
  (ubegin e.0 e.1 e.2 e.3))

(def ueval-if (d e k xs)
  (if no?xs
      (bcall k nil)
      no?cdr.xs
      (ueval d e k car.xs)
      (let (a . more) xs ;changing it a little
        (let k1 (bclos ueval-if-k1 d e k more)
          (ueval d e k1 a)))))
(def-bclos ueval-if-k1 (self _) (d e k more)
  (if _
      (ueval e.0 e.1 e.2 car:e.3)
      (ueval-if e.0 e.1 e.2 cdr:e.3)))

;aw, man, methinks d and k should be together, e not between them...
;'cause some ... well... whatever, meh.

;hide the terrible
(def join-e (d e k pars args)
  (join-e2 d e k pars args pars args))

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
(def-bclos join-e2-k1 (self _) (d k p0 a0 cdr.pars cdr.args)
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


(def ucall-w/param (d k dyn var thunk)
  (let k1 (bclos ucall-w/param-k1 k thunk)
    (dextend d k1 dyn var)))
(def-bclos ucall-w/param-k1 (self _) (k thunk)
  (uapply _ e.0 e.1 nil))

;ok, um... here I must put my foot down about bare fns
;(actually these things didn't work last time, just were never used)

;[moving stuff about empty bcloses up]

(uinstall 'call-w/param 
          (fn-bclos (self k d (dyn var thunk))
            (ucall-w/param d k dyn var thunk)))

;now this is some stuff I decided I wanted
(uinstall 'current-dyn-env (fn-bclos (self k d ignargs)
                             (bcall k d)))

(uinstall 'call/kd (fn-bclos (self k d (k2 d2 thunk))
                     (uapply d2 k2 thunk nil)))
;(uinstall 'safe-call/kd (fn (k d (k2 d2 thunk))
;                          (let k3 [do (prn "You're an idiot, putting a non-cont"
;                                           "where a cont goes")
;                                    (utoplevel)]
;                            (let k4 [uapply 
;                            (uapply d2 k3 
;Neh, that only really applies in the assembly world.

(= uinsult-toplevel (fn-bclos (self _)
                      (prn "You're an idiot, putting a non-cont"
                           "where a cont goes")
                      prn._
                      (utoplevel)))


(def closure->cont (f) ;also just turns conts into eqv. conts
  (bclos closure->cont-k1 f))
(def-bclos closure->cont-k1 (self _) (f)
  (uapply nil uinsult-toplevel e.0 list._))

(uinstall 'safe-call/kd (fn-bclos (self k d (k2 d2 thunk))
                          (uapply d2 closure->cont.k2 thunk nil)))

;this is actually relatively substantial now
#;(def cont->closure (k) ;feh
  (fn (ignk ignd (x)) (bcall k x)))

(def cont->closure (k)
  (bclos cont->closure-c1 k))

(def-bclos cont->closure-c1 (self ignk ignd (x)) (k)
  (bcall e.0 x))

(uinstall 'ccc (fn-bclos (self k d (f))
                 (let u cont->closure.k
                   (uapply d k f list.u))))
(uinstall 'raw-ccc (fn-bclos (self k d (f))
                            (uapply d k f list.k)))

(uinstall 'eval (fn-bclos (self k d (x (o e nil)))
                  (ueval d e k x)))

(uinstall 'apply (fn-bclos (self k d (f . args))
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

(def uarg-tck (tp f)
  (bclos uarg-tck-c1 tp f))

(def-bclos uarg-tck-c1 (self k d args) (tp f)
  (if no:proper-list.args
      (uraise d k (list 'args-error args e.1))
      (all [is utype._ e.0] args)
      (uapply d k e.1 args)
      (uraise d k (list 'type-error e.0 args e.1))))
(uinstall 'arg-type-check (fn-bclos (self k d args)
                                   (bcall k (apply uarg-tck args))))
;moar
(def uarg-nck (n f)
  (bclos uarg-nck-c1 n f))

(def-bclos uarg-nck-c1 (self k d args) (n f)
  (if (and proper-list.args (is e.0 len.args))
      (uapply d k e.1 args) ;not e.0 dumbass
      (uraise d k (list 'args-error e.0 args e.1))))
(uinstall 'arg-num-check (fn-bclos (self k d args)
                           (bcall k (apply uarg-nck args))))

;here I have a choice: create list.obj here and put it in the cont,
;or have the cont create list.obj.
;I shall do the former.
(def uraise (d k obj)
  (let k1 (bclos uraise-k1 d k list.obj)
    (dyn-lookup d k1 uhandler)))
(def uraise-k1 (self _)
  (uapply e.0 e.1 _ e.2))

#;(def default-uhandler (d k (obj)) ;lolz, this was wrong but didn't matter
  (prsn "An exception!" obj)
  (utoplevel))

;or, actually, since that cont is always the same (empty env),
;I don't need to create a new one each time.
(def utoplevel ()
  (pr "heh> ")
  (awhen (read)
    (ueval nil nil utoplevel-kk uify.it)))

#;(def utoplevel-k1 (self _)
  (uinstall 'that _)
  wrn:prettify._
  (utoplevel))
;here, I just need the one instance

;(= utoplevel-kk (bclos utoplevel-k1))
(= utoplevel-kk (fn-bclos (self _)
                  (uinstall 'that _)
                  wrn:prettify._
                  (utoplevel)))
                  
(= utoplevel-cont (fn-bclos (self _) (utoplevel)))

(= default-uhandler (fn-bclos (self k d (obj))
                             (prsn "An exception!" prettify.obj)
                             (utoplevel)))
(= uhandler (make-dyn default-uhandler))
(uinstall 'default-exn-handler uhandler)


(unless bound!safe-to-udef
  (= safe-to-udef (table)))
#;(w/uniq (gignself gk gd gargs)
  (mac udef (name (d-arg k-arg . rest) . body)
    (let arcname (symb 'x name)
      `(if (and (bound ',arcname) (no:safe-to-udef ',arcname))
           (err "Oh crap this is bound" ',arcname)
           (do (def ,arcname (,d-arg ,k-arg ,@rest) ,@body)
             (= (safe-to-udef ',arcname) t)
             (install-uassignment ',name 
                                  (bclos (fn (,gignself ,gk ,gd ,gargs)
                                           (,arcname ,gd ,gk ,gargs)))))))))

(w/uniq (gignself gk gd gargs)
  (mac udef (name (d-arg k-arg . rest) . body)
    (let arcname (symb 'x name)
      `(if (and (bound ',arcname) (no:safe-to-udef ',arcname))
           (err "Oh crap this is bound" ',arcname)
           (do (def ,arcname (,d-arg ,k-arg ,@rest) ,@body)
             (= (safe-to-udef ',arcname) t)
             (install-uassignment
              ',name 
              (rfn-bclos ,(uniq string.arcname) (,gignself ,gk ,gd ,gargs)
                (,arcname ,gd ,gk ,gargs))))))))
;could I use rfn-bclos?
;name collisions... eh.
;--I can make a name.

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

(def-bclos list*-k1 (self _) (d k x)
  (ucons e.0 e.1 e.2 _))

;exercises
;[these really could be defined by the user]
(udef append (d k xses)
  (if no.xses
      (bcall k nil)
      (let (xs . rest) xses
        (let k1 (bclos append-k1 d k xs)
          (xappend d k1 rest)))))

(def-bclos append-k1 (self _) (d k xs)
  (append2-good e.0 e.1 e.2 _))

;recursive, not great; eh
(def append2-good (d k a b)
  (if no.a
      (bcall k b)
      (let (x . rest) a
        (let k1 (bclos append2-good-k1 d k x)
          (append2-good d k1 rest b)))))
(def-bclos append2-good-k1 (self _) (d k x)
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


#;(def proc->ufn (f)
  (fn (k d args)
    (bcall k (apply f args))))
  
#;(def proc->bclos (f)
  (bclos (fn (ignself k d args)
           (bcall k (apply f args)))))

;must .......
;ah. again, name-symbol.

(def proc->bclos (s)
  (withs bname (symb 'builtin- s)
    f symbol-value.s
    n $.procedure-arity.f
    args (if int?n (n-of n (uniq)) (uniq))
    (eval `(rfn-bclos ,(uniq string.s) ;(self k d ,@args)
             ;Arc's qq can't handle `(meh ,@args) when args isn't a list
             ;so...
             ;,(list* 'self 'k 'd args)
             ;actually that ain't even right
             (self k d ,args) ;hells yeah ;... didn't help yet
             (bcall k ;yes, bcall, you idiot
                    ,(if int?n
                         `(,s ,@args)
                         `(apply ,s ,args)))))))
;(= a 'fuck)

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
          ;(fn? (orf uclos? fn?)) ;used in 'testify, obv. means both
          ;actually now that's insulated... do elsewhere
          (table? btable?)
          (make-table make-btable) ;bad name, user should def table
          (table-set btable-insert)
          (table-ref btable-lookup)
          (table-delete btable-delete)
          (tablist btable->list)
          scar scdr
          (sym? usym?)
          string?
          (all-bound-symbols uall-bound-syms)
          (sym->string usym-name)
          
          )
  (with arc-name (if cons?x cadr.x x)
    uname (if cons?x car.x x)
    (uinstall uname #;proc->bclos:eval.arc-name
              ;(eval `(fn-bclos (
              proc->bclos.arc-name
              )))

(udef fn? (d k (x))
  (if fn?x
      (err "No arc fns" x)
      (bcall k (or bclos?x uclos?x))))

;(= a 'ass)


;lolz, just integer arithmetic...
;'cause of how I wrote dick.
;oh well.
(each x '(+ - * / < >
          div mod)
  (uinstall x (uarg-tck 'int proc->bclos.x)))

;(= a 'cock)

#;(each x '(car cdr cadr cddr)
  (uinstall x (uarg-nck 1 (uarg-tck 'cons proc->bclos.x))))
;that's actually not too great
;...
;lel, just drop type check

(each x '(car cdr cadr cddr)
  (uinstall x (uarg-nck 1 proc->bclos.x)))

(each x '(< >)
  (uinstall (symb x 2)
            (uarg-nck 2 (uarg-tck 'int proc->bclos.x))))

(uinstall 'string-length (uarg-tck 'string proc->bclos!len))

(each x '(is)
  (install-uassignment x proc->bclos.x))


;just for convenience
(each x '(prn prsn pr)
  (install-uassignment x proc->bclos.x))

(def uify (x)
  (deep-map [if sym?_ sym->usym._ _] x))

(def usym->sym (x) symb:usym-name.x)
(def de-uify (x)
  (deep-map [if usym?_ usym->sym._ _] x))
(uinstall 'arc-eval (fn-bclos (self k d (x))
                             (bcall k eval:de-uify.x)))

(= idfn-k (fn-bclos (self _) _))

(def ue (x)
  (ueval nil nil ;idfn ;inappropriate use of a cont
         idfn-k
         uify.x))

(def heh () (utoplevel))

(def boot ((o file (string src-directory "arc-boot2.arc")))
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
                      (let hd (bclos boot-c1 n u)
                        (let res (ucall-w/param nil idfn-k uhandler hd
                                                (bclos boot-c2 h))
                          (when (and acons.u (is car.u 'def)
                                     no:uclos?res)
                            (prsn "This probably ain't a function" (= ass res))
                            prn.n
                            (err "Dicks")))))))
          ++.n)))))

(def-bclos boot-c1 (self k d (x)) (n u)
  (prn "Failed to eval expr " e.0 ":")
  pprn:e.1
  (= ass x)
  (prsn "raising exception" prettify.x)
  (err "Fuck"))

(def-bclos boot-c2 (self k d ign) (h)
  (ueval d nil k e.0))

(def prettify (x)
  (deep-map [if usym?_ usym->sym._
                user?_ `(,upcase:user-type-name:user-obj-tag._
                         ,@(prettify user-obj-val._))
                bclos?_ `(BCLOS ,bclos-code._ ,(map prettify
                                                    ($.vector->list
                                                     (bclos-env _))))
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



;Hey.
;It's actually a significant point for long-term runtime health,
;in this kind of interpreter thing, to ... make the thing that interns
;symbols be a weak hash table.
;That, or have "uniq" create non-interned symbols.
;...

;The boot program does introduce ssyntax, which means other means of
;manufacturing symbols.
;So that rules out some sidestepping.
;Everything _that_ creates will have to be interned.

;Racket knows how to use weak tables.
;(Creating a bunch of symbols and letting them die => no increased
; memory use after GC.)
;A weak table is pretty certainly the right answer.
;I just need to figure out about multithreading...

;So...
;Conclusion is, threads using cmpxchg to install corpse pointers in
;their own thread objects (the corpses will have a ptr to "trace the
; heir" and "next-corpse") appears to be acceptable, being a constant-
;factor increase: they must already use cmpxchg to install fwd ptrs,
;as well as do tracing work, and, like with fwd ptrs, little contention
;is expected.  (Note there can be a great amount of contention in the
; case where the program mainly uses one giant list of integers, as
; has been the case in some of my programs experimenting with WAVs.)
;(I wonder if there can be made less contention if there are just
; two giant lists... or a list of pairs... eh.)

;The main thing that needs to be handled is having threads coordinate on
;when GC is finished, so that weak-pointer destruction can engage.

;So, it's fairly funny.
;Basically the only tolerably efficient ways I can think of for
;getting threads to know that they're done fucking around
;is for them to increment a specific-to-them (but publicly visible)
;counter every time they move something, and for them to put a copy
;of that counter into a certain (also specific-to-them) place when
;they're done tracing.
;Then the way a thread can see if everyone's done is to look at
;everyone's secondary counter, then look at everyone's first counter,
;and see if all correspondences are equalities.
;If so, that appears to imply victory.
;[... Might need to look again or something. Not completely sure.]
;This is powerful enough that the full scheme of having the counter
;be "the number of bytes in the shit you just moved" and have the
;certain place contain "the number of bytes you've traced/handled".
;This information is generally useful for other purposes, and also
;it means a checker doesn't need to store each secondary counter
;individually; it need only store the sum.
;
;This is O(n) in number of threads.
;With huge populations of threads... [I'm intending for these "threads"
; to be eqv to "cpu cores", but not necessarily always] it is possible
;to break up the work of adding shit up... and probably want timestamps.
;(At time t, the sum of this group of threads was n.)
;Then victory is if you get a sum of all secondary counters taken before
;time t, and a sum of all primary counters after time t, and they're
;the same.

;Reasoning is 10/10 bretty good:
;1. You have a bunch of independently increasing counters.
;   If you observe them in some order, and then observe them
;   [or some metric that is always ≥ to them] again in some
;   order, and they're all the same, then that implies there
;   was a moment when all those numbers were there.
;2. If there is a moment when sum(traced) = sum(moved), then GC is done.
;3. sum(traced) is always ≤ sum(moved). Hence = or ≥ are eqv in above.
;
;....
;Is that ... sufficient?  Looks like not, but is it wrong?
;Aha.
;It is good.
;4. If you observe the moved counters in a certain order, and the sum is n,
;   then that implies that, when you observed the first counter, the sum
;   of all moveds was ≤ n.

;Aha.
;1. Observe sum(traced).  Is n.  => when you observed the last one,
;   sum(traced) ≥ n.
;2. Observe sum(moved).  Is n.  => when you observed the first one,
;   sum(moved) ≤ n.
;3. The second moment is after the first moment, and therefore, at
;   the first moment, again sum(moved) ≤ n.  (Nondecreasing over time.)
;4. At all moments, sum(traced) ≤ sum(moved).
;5. Thus, at first moment, n ≤ sum(traced) ≤ sum(moved) ≤ n.
;   Hence, all equal n.

;[For future reference, the moving score needs to be more reflexive and
; immediately public than the tracing score. Hence, the former should be
; a thing that directly modifies a thread variable--the code to move a
; cons should have "add [dick], 16"--while the latter can probably
; afford to be an indirect kind of "return 16 in some register".]


;So, the thing I think I want is:
;user=>[tag-weakptr object]
;Which, when traced, will do nothing (but either then or upon creation will
;add to a list of weak ptrs to be dealt with after GC done), and upon later
;examination will preserve the object iff it's been ... dicked.
;.............
;Neh.
;Must have a connection with tables, must delete from table. Or smthg.
;Deleting from an AVL tree seems too expensive an operation to put as
;GC extra work, unless it's "not essential to finish now".
;Then there are other threading issues...

;[Interesting how, when I google for "multithreaded hash table", one of
; the top results is a paper from Azul Systems.]
;[And how the first listed use is for a symbol table.]

;[Regarding above, another thing that works, and doesn't rely on the
; reliability of scores, is, for each thread, to read moved, then read
; the gc-next ptr and verify that it's 0; then go back and see if the
; moveds have changed at all.  (Or add up the moveds.)]

;....
;I think there is ...
;I think I've mentioned it before, but I think there's a (dumb) way to do
;hash tables.
;For the main problem, you basically have to maintain consistency of the
;collision list.
;Ideally, one should be able to perform deletions without allocating
;memory.
;(And ideally other operations too.)
;One strategy is to maintain an immutable list and strictly use CMPXCHG
;to replace it.
;That's a dumb strategy that will work, although it means deletions in
;general will allocate.
;Another strategy is to have deletions:
;(a) overwrite the value with DELETED
;(b) do what you can to remove the item from the list.
;Also, would like replacing an existing value to take no allocation.
;That will have some implications...
;- When you replace an existing value, use CMPXCHG, and if you find
;  that someone put DELETED in there, then you must insert it de novo.
;- When deleting from the front of the list, use CMPXCHG; if someone
;  got there first, look to see if that pair is still in the list,
;  and if so, try deleting again.
;- When deleting from the middle of the list, (a) might as well
;  cmpxchg, in case multiple people delete; more importantly,
;  (b) after installing a new cdr, check if the value in the car
;  is DELETED. If not, then (mem. barrs maybe req'd) it is guaranteed
;  that anyone deleting the previous element will read the updated
;  cdr after deleting it, and will not keep your zombie in there.

;Then there's resizing.
;Basically, with key-value mappings kept as pairs, there isn't any
;problem of maintaining *consistency* between tables.
;Then, basically, you can have a rule of "insert the pair into the
; new table, then remove it from the old table".
;...
;There is still ... it's kind of like I want a forwarding pointer,
;'cause all pointers to the old hash table will have to update to
;point to the new one.
;However, there's no way it can be a real forwarding pointer, 'cause
;GCs don't happen too often... ..... hmm...
;... It could certainly be done, jesus christ.

;A general problem is grabbing n amount of memory and having it
;zeroed out in O(1) time.
;I think this kind of can be done with mmapping in fresh memory,
;or by MADVISE.
;...
;Maybe. Not really sure. (Looks like it's probably not guaranteed
; to zero things out if you go MADV_DONTNEED, and I'm not sure
; exactly what MADV_ZERO_WIRED_PAGES does on OS X, and it doesn't
; exist on Linux...)

;Then an issue is the hash function itself.
;Investigation has shown that SBCL and Clozure CL return the same
;hash for any array.  CLISP at least adds the arraylen to the hash.
;It does kinda make sense.
;Firstly, recursing through a, like, 100-element array just to hash
;it seems pretty stupid. Second, it seems rare to use an array as
;a key to a table anyway.
;The common thing is probably to hash symbols, numbers, strings,
;and lists of the above. Maybe also dinky structs of the above.

;lol it turns out CL doesn't consider vectors "equal",
;that probably requires "equalp".

;Ideas...
;- Racket has extra fields in each object that enable storing, among
;  other things, a hash in each object.  This could be done, but I
;  rather dislike it.  (Would increase by 50% memory usage of a long
;  list of cons cells, and dick.)
;- Could do that to a limited extent.
;- - Could give strings an extra field.
;- - - Could be initially 0, to indicate "not hashed", and have hashers
;      fill it up as necessary, with a hash guaranteed to be nonzero.
;- - - Modifying the string could be req'd to set that field to 0.
;      Not sure if I like that... Then again, modifying chars in a
;      string isn't all that common, except as a way of implementing
;      string appending, which is quite a common operation. (Lel.)
;      Or, generally, creating fresh strings.  Well.
;      Perhaps it could be "optionally, unhash it".
;- - Thought maybe could use high bits in pointers in conses, but...
;    neh, conses containing integers have no room.
;- - Could generally have it as a runtime option or whatever. Would mean
;    recompiling all allocations and whatnot, though. Suck.
;- Default for new struct types could be "just return 0", or, slightly more
;  advanced, "return the type-tag * 93842337 mod whatever".
;- For recursive shit... you probably really don't want shit to take long.
;  So, here you can finally implement the P.T. Withington idea of
;  not doing read-barr work when accessing cars and cdrs in order to hash.
;  (Load cdr, then car, then check for movedness; if so, probably don't
;   even bother to update the pointer you came from.)

;I kind of like the string lazy-hashing extra-field idea, and the
;P.T. Withington shit.  (Probably use BTS to set bit 63 of string hashes;
; this makes all strings have effectively 63-bit hashes; no problem.)

;There are some philosophical issues, that you can get strange, non-crashing
;behavior by screwing with strings... you could deliberately give a string
;a certain hash, then change it and not recompute the hash.
;Well, ah well.
;

;Ok, the department of free-association and of forgetting and coming back
;later has decided:
;- Not caching string hashes is not a problem.
;  People know in other languages that symbols are better than strings for
;  key-ness.
;
;Reading my old notes on "fake-hash" is interesting.
;It probably would be a good thing to put the hash-table-count somewhere
;else, but neh.
;I don't think I need to economize on space in the wrapper thing (and I
; think there must be a wrapper thing).
;No need to lock the main table while someone is resizing.
;In fact, this design of table, without "open addressing", means it's
;technically possible to add and remove keys indefinitely even if it takes
;forever to resize.
;Meanwhile, protocol for "insertion" goes like this:
;- If the key is already in there, then you overwrite the cdr of the
;  key-val pair.  (With CMPXCHG, and if you find it had been overwritten
;   with DELETED, then you must insert a new entry.)
;- If you must insert a new entry, then you go:
;  (cmpxchg slot old-val (cons (cons key val) old-val)).
;  If fail, retry.  If succeed, then go see if someone has resized, and if
;  so, then move your entry to the new table.
;  This ensures that ...
;  Let's see.
;  Lookups should try old table and then new table.
;  .....
;  Um, looks like it might be a good idea (at least convenient for some
;   synchronization) to ....
;  --Idiot. No, there is no need to put the hash-table-count in the vector.
;  After a resize, the hash-table-count will be *exactly the same*.
;  Noob.
;  --I guess new insertions will obviously have to check whether the
;  count becomes too high. Perhaps only when they need to double up.
;  And deletions probably should too.

;Next task.
;Now that I've spelled out all continuations,
;it would seem I at least don't need a stack.
;So I think I can add in memory shit before, uh...
;Before turning into assembly.
;............
;Is there any last-minute shit I want to do before making stuff
;manipulate memory in horrible ways?
;Probably...
;However...


