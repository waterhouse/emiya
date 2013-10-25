;"light and darkness", and then it seems "and darkness" -> "of darkness" in my mind.

;Time to translate butt into using a stack (with return addresses on the stack, as fns).

;;OH MY GOOOOOOOOOOOOOD
;;I can "call" like this:
;(blah)
;(call x)
;(blah)
;=
;(blah)
;(push cdr.the-pc the-stack)
;(x)
;(blah)

;All right.  Now that fucking ass works, I may a) improve it a bit and b) make it
;do all its consing through a GC and its cadring through a read barrier.

;Jesus christ, that was *fast*.  I think that required changing three lines of
;code, and two of them were the same.  (Change: have instruction lists be lists
;of Racket thunks rather than lists of Arc expressions to be eval'd.)

;And that timing test is just amazing.

;arc> (time:ue '((fn (f) (f f 1000 0)) (fn (f n tt) (if (is n 0) tt (f f (- n 1) (+ n tt))))))
;time: 1337 cpu: 1334 gc: 25 mem: -3937864
;500500

;Previously:
;arc> (time:ueval '((fn (f) (f f 1000 0)) (fn (f n tt) (if (is n 0) tt (f f (- n 1) (+ n tt))))) nil)
;time: 102659 cpu: 102125 gc: 3837 mem: -7042216
;500500

;JMP is faster than EVAL.

;Next order of business.  Stack.
;I think I shall use a table for the stack... neeh... neeh?  Is it really an improvement?
;Don't think so.
;Time to butt.

;Now.  We shall use pointers into memory.  They shall be 8-byte aligned, although we
;aren't actually using bytes.

;now for emiya5.
;arc> (time:ut:ue:tu '((fn (f) (f f 1000 0)) (fn (f n tt) (if (is n 0) tt (f f (- n 1) (+ n tt))))))
;[hella gc flips and shit]
;time: 7637 cpu: 6733 gc: 85 mem: 13178008
;500500
;that's actually not too bad.

(= the-memory (table))
(def mm (n) ;memory access
  (unless (isa n 'int)
    (err "IDIOT TRYING TO DEREFERENCE A NON-POINTER" n))
  (unless (is 0 (mod n 8))
    (err "NOOB TRYING TO ACCESS UNALIGNED MEMORY" n))
  (unless (< -1 n memory-top)
    (err "NOOB GETTING MEMORY OUT OF BOUNDS" n))
  ([if (is _ 'HELLA-NIL) nil _]
   (the-memory n (fn () (prn "IDIOT TRYING TO ACCESS UNINITIALIZED MEMORY")))))
(def mm-set (n x)
  (unless (isa n 'int)
    (err "IDIOT SETTING MEMORY AT A NON-INTEGER LOCATION" n x))
  (unless (is 0 (mod n 8))
    (err "IDIOT SETTING MEMORY AT UNALIGNED ADDRESS" n x))
  (unless (< -1 n memory-top)
    (err "NOOB SETTING MEMORY OUT OF BOUNDS" n x))
  (= the-memory.n (or x 'HELLA-NIL)))

;Now I'll have to do "cons", "car", "cdr", "move", and stuff.
;"move" will work on tagged Lisp objects.

;Cons cells have tag 001, integers tag 000.  Integers are 8 x what they usually are.
;Obviously many tags are unclaimed.

;Time to name some quantities... oh god so many
(= word-bits 20 ;arbitrary, lolz; these are signed, so -2^19 through -1+2^19
   word-top (expt 2 (- word-bits 1))
   
   semispace-size-bits 12
   semispace-size (expt 2 semispace-size-bits)
   alloc-pointer 0
   tospace-top semispace-size
   memory-top (* 2 semispace-size)
   
   which-space 0
   fromspace [xor (bit-set _ semispace-size-bits) ;assumes is ptr
                  (is 1 which-space)]
   
   gc-next nil
   
   )
   

(def move-cons (x) ;tagged
  (let x0 (mm (- x 1))
    (if (and is-pointer.x0
             (< x0 0)) ;fwd'd        ;seems like following fwd's should be in 
        (let u (+ x0 word-top) ;the general-purpose "move" code
          #;(prsn "FOLLOWING FWD PTR FROM" x "TO" u)
          u)
        (let u (+ 1 (allocate 16)) ;yes, alloc like that
          #;(prsn "MOVING CONS FROM" x "TO" u)
          (mm-set (- u 1) (mm:- x 1))
          (mm-set (+ u 7) (mm:+ x 7))
          (mm-set (- x 1) (- u word-top)) ;fwd ptr; it might not be necessary that
          ;the fwd-pointer be tagged the same way a cons is tagged, but I'll do it
          ;this way for now.
          (mm-set (+ x 7) gc-next)
          (= gc-next (- x 1)) ;I'm not sure exactly how to handle stuff.
          ;Currently the information that the next thing to be traced is a cons, is
          ;contained in the tag of "fwd". It is thus unnecessary for the tag of gc-next to
          ;contain this too.  OTOH, I could have gc-next have that tag, and then the other
          ;thing would be an untagged pointer.  Wtvr.
          u))))

(def move-words (xt n tg) ;tagged
  (withs (x (- xt tg) x0 mm.x)
    (if (and is-pointer.x0
             (< x0 0)) ;fwd'd        ;seems like following fwd's should be in 
        (let u (+ x0 word-top) ;the general-purpose "move" code
          #;(prsn "FOLLOWING FWD PTR FROM" x "TO" u)
          u)
        (withs (u (allocate 16) ut (+ u tg)) ;yes, alloc like that
          #;(prsn "MOVING STUFF FROM" xt "TO" ut)
          (for i 0 dec.n
            (mm-set (+ u (* 8 i)) (mm:+ x (* 8 i))))
          (mm-set x (- ut word-top)) ;fwd ptr; it might not be necessary that
          ;the fwd-pointer be tagged the same way a cons is tagged, but I'll do it
          ;this way for now.
          (mm-set (+ x 8) gc-next)
          (= gc-next x) ;I'm not sure exactly how to handle stuff.
          ;Currently the information that the next thing to be traced is a cons, is
          ;contained in the tag of "fwd". It is thus unnecessary for the tag of gc-next to
          ;contain this too.  OTOH, I could have gc-next have that tag, and then the other
          ;thing would be an untagged pointer.  Wtvr.
          ut))))

(def is-tagged (x n)
  (and (isa x 'int) (is n (mod x 8))))

(def move (x (o complain t))
  (if (and (is-tagged x 1) (fromspace x))
      (move-cons x)
      (and (is-tagged x 3) (fromspace x))
      (move-words x 2 3)
      complain
      (err "NOOB TRYING TO MOVE SOMETHING THAT'S NOT A FROMSPACE PTR" x)
      x))

(def is-pointer (n)
  ;currently pointers = conses
  (and (isa n 'int) (in (mod n 8) 1 3)))

(def grab-possible-pointer (n (o move-message "READ BARRIER AT WORK"))
  (let u mm.n
    (if (and is-pointer.u fromspace.u)
        (do #;(prsn move-message u)
          (mm-set n (move u)))
        u)))

(mac check-cons (var msg)
  `(unless (is 1 (mod ,var 8))
     (err ,msg ,var)))

(def uscar (n x)
  (check-cons n "NOOB TRYING TO SET-CAR A NON-CONS")
  (mm-set (- n 1) x))
(def uscdr (n x)
  (check-cons n "NOOB TRYING TO SET-CDR A NON-CONS")
  (mm-set (+ n 7) x))

;shall I have (ca/dr nil) = nil? for the moment, nah.
;but anyway, for the moment, nil will still be nil.
(def ucar (n)
  (check-cons n "GET YOUR CAR CHECKED")
  (grab-possible-pointer (- n 1)))
(def ucdr (n)
  (check-cons n "GET YOUR OTHER CAR CHECKED")
  (grab-possible-pointer (+ n 7)))



(= the-pc nil
   the-stack nil
   labels (table)
   meta ($:make-weak-hash)) ;(instruc ...) -> (name ... source)

(def install (body) ;such horrible metadata at the moment
  (xloop (xs rev.body ys nil)
    (if no.xs
        nil
        (isa car.xs 'sym)
        (do (= (labels car.xs) ys)
          (xloop (ys ys)
            (when ys
              (push car.xs meta.ys)
              (next cdr.ys)))
          (next cdr.xs ys))
        (next cdr.xs (cons (let u (eval `(fn () ,car.xs)) #;
                             car.xs
                             (push car.xs meta.u)
                             u) ys)))))

(def jump (lab)
  (= the-pc (labels lab (fn () (err "NOOB TRYING TO JUMP TO NON-INSTRUCTION" lab)))))

(mac buh body
  `(install ',body))

(def run (lab)
  (jump lab)
  (while the-pc
    (step)))

(= step-counter 0)

(def step ()
  #;(eval pop.the-pc)
  (++ step-counter)
  (pop.the-pc))

(= ustep-table (table))
(= ustep-list nil)
(def ustep ()
  (do1 (step)
       (each x ustep-list
         (when (bound x)
           (unless (is symbol-value.x ustep-table.x)
             (prsn x '-> symbol-value.x)
             (= ustep-table.x symbol-value.x))))))
(mac watch args
  `(each x ',args
     (pushnew x ustep-list)))
(mac unwatch args
  `(= ustep-list (rem [mem _ ',args] ustep-list)))

(def ustep-restore ()
  (each x ustep-list
    (= symbol-value.x ustep-table.x)))

(buh gcd
     (if (is b 0)
         (jump 'gcd-done))
     (= a (mod a b))
     (swap a b)
     (jump 'gcd)
     gcd-done
     (= return-value a))


;;All right, so.
;;Procedures are in fact permitted to accept arguments.
;;However, if they call anything else, those lexical bindings will be gone
;;by that time.
;(mac ddef (name args . body)
;Neh, neh.
;Eh, yeh.
;Um, but I'd like to see how else I can do stuff...
;Mmm.

;ARGLIST is a variable.
;VALUE is a variable.  I might have it displace ARGLIST.
(= arglist nil)
;hah hah hah, nope.

(def make-assignments (vars vals)
  (xloop (uvars vars uvals vals)
    (if no.uvars
        (if uvals
            (err "make-assignments: some mismatch" vars vals uvars uvals))
        (isa uvars 'sym)
        (= symbol-value.uvars uvals)
        acons.uvars
        (if acons.uvals
            (do (next car.uvars car.uvals)
              (next cdr.uvars cdr.uvals))
            (err "make-assignments: some mismatch" vars vals uvars uvals))
        (err "What the fuck are you trying to bind?" vars vals uvars uvals))))


(mac ddef (name args . body) ;time to write ddef after using it all below times
  (w/uniq gargs
    `(do (install '(,name ,@body))
       (= ,name (fn ,gargs
                  (make-assignments ',args ,gargs)
                  (push nil the-stack)
                  (run ',name)
                  return)
          ,(symb name '-setup)
          (fn ,gargs
            (make-assignments ',args ,gargs)
            (push arc-return the-stack)
            (jump ',name))))))

(= arc-return '((prn return)))
;So the fucking annoying thing is that I need to convert IFs into GOTOs
;when I need to save things.
;Oh and I need to explicity say "return some value".
;... With the previous thing, I just modified some global variables.
;It'd be nice to continue doing that.  Rather than establish some
;global calling convention.
;With fib, it was so nice, because "n", the name for the arg, was also
;easily obviously the name of the return value.
;Eh, by default, most things will set the "return" thing.  Yes.
;Mmmhmm, explicit jumps and setting stuff and stuff.
;Later I'll have to use car/cdr with fromspace tests, and probably in fact
;with "this is an integer, used as an index into some "memory" table".

;TIME TO USE UCDR FOR EVERYTHING
(ddef eval-if (xs env) ;xs, env are uconses
  (if no.xs
      (do (= return nil) (= the-pc pop.the-stack)) ;return nil, lolz
      (no ucdr.xs)
      (do (= x ucar.xs) (jump 'ueval))) ;fifth, but sameish
  (push env the-stack)
  (push ucdr.xs the-stack)
  (= x ucar.xs) ;sixth...
  (push cdr.the-pc the-stack) ;not a ucons
  (jump 'ueval) ;sets "return"
  (= cdr-xs pop.the-stack env pop.the-stack) ;assume no problem
  (if return
      (do (= x ucar.cdr-xs) (jump 'ueval))) ;fourth names error...
  (= xs ucdr.cdr-xs)
  (jump 'eval-if))

(mac save args
  `(do ,@(map (fn (x) `(push ,x the-stack)) args)))
(mac restore args
  `(= ,@(mappend (fn (x) `(,x pop.the-stack)) args)))

#;(ddef uapply-loop (env exprs) ;DICKASS IDIOT DON'T ELIMINATE TAIL CALLS YOU IDIOT
  (if no.exprs
      (do (= return nil) (= the-pc pop.the-stack)))
  (save env ucdr.exprs)
  (= x ucar.exprs)
  (push cdr.the-pc the-stack)
  (jump 'ueval) ;x env ;goddammit names
  (restore exprs env)
  (if exprs
      (jump 'uapply-loop))
  (= the-pc pop.the-stack))

(ddef uapply-loop (env exprs)
  (if no.exprs
      (do (= return nil) (= the-pc pop.the-stack)))
  uapply-loop-loop
  (if (no ucdr.exprs) ;this is a tail call
      (do (= x ucar.exprs) (jump 'ueval)))
  (save env ucdr.exprs)
  (= x ucar.exprs)
  (push cdr.the-pc the-stack)
  (jump 'ueval) ;x env ;goddammit names
  (restore exprs env)
  (if exprs
      (jump 'uapply-loop-loop))
  (= the-pc pop.the-stack))

;this can be a plain procedure, because it does not malloc at all or do any evaluation
;... ... ... FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF-
;never mind about that
;(ddef join-envs (env arglist xs)
;  (if no.arglist
;      (if no.xs env (err "Too many arguments:" xs)) ;kind of strict
;      acons.arglist
;      (if no:acons.xs
;          (err "Arg!" arglist xs)
;          (join-envs (join-envs env car.arglist car.xs) cdr.arglist cdr.xs))
;      (isa arglist (quote sym))
;      (cons (list arglist xs)
;            #;(rem (bracket-fn (is car._ arglist)) env)
;            env)
;      (err "What kind of argument is this?" arglist)))
;defining this shit later.

;time to bite the bullet
(def call (x)
  (push the-pc the-stack) ;no cdr here because (call blah) is one expr
  (jump x))

(def ucadr (x) (ucar ucdr.x))

(def uassoc (x xs)
  (if no.xs
      nil
      (let u ucar.xs
        (if (is x ucar.u)
            u ;I'm an idiot, this ain't alref
            (uassoc x ucdr.xs)))))

(def ucddr (x) (ucdr ucdr.x))

(ddef eval-= (xs env)
  (save xs env)
  (= x ucadr.xs) ;x. names, names, be careful
  (call 'ueval)
  (restore env xs)
  (aif (uassoc ucar.xs env) ;assoc will not trigger GC flip; it accesses, not allocs
       ;geez, what happens if a user redefines assoc, and calling it causes alloc
       ;to compile, which causes crap? ... there probably must be some primitives.
       (uscar ucdr.it return)
       (= (global-value ucar.xs) (or return 'HELLA-NIL)))
  (if ucddr.xs
      (do (zap ucddr xs) (jump 'eval-=)))
  (= the-pc pop.the-stack))

(def ret ()
  (= the-pc pop.the-stack))

(= gc-work-factor 4)

(ddef gc-work () ;deal NOW with work factor and bytes allocated; shit died without this
  (= n (* (/ n 8) gc-work-factor))
  gc-work-loop
  (if (or (is n 0) no.gc-next)
      (ret)) ;you can't conditional-ret in x86... can't ret at all on other platforms
  (-- n)
  (= fwd (+ word-top mm.gc-next)
     nx (mm:+ gc-next 8))
  ;we must type-dispatch on fwd.
  ;it's seeming like a somewhat silly idea to have a specially tagged gc-jobs
  ;data structure. it's a slight optimization, over having a global variable
  ;for that and a test. ... and it lets you insert gc-jobs whenever you like,
  ;ex. for perverting the GC work towards resizing your hash table.
  ;eh.  I can just add that test later.
  (if (is 1 (mod fwd 8)) ;later -> jump table
      (jump 'trace-cons)
      (is 3 (mod fwd 8))
      (jump 'trace-gc-job)
      (err "How do I trace this?" fwd))
  trace-cons
  (= gc-next nx)
  (grab-possible-pointer (- fwd 1) "GC-WORK AT WORK")
  (grab-possible-pointer (+ fwd 7) "GC-WORK AT WORK")
  (jump 'gc-work-loop)
  
  trace-gc-job ;fwd -> ('job-func-name . (more crap))
  (= func-name (mm (- fwd 3)))
  (= jobs-cdr (mm (+ fwd 5)))
  (call func-name)
  (jump 'gc-work-loop)
  ;massive flexibility; can mess w/ n, jobs-next, gc-next, nx, etc.
  ;I can do all sorts of things like abandon n.
  ;Hmm... If I have some gc-job that does something trivial but allocs,
  ;and then, when it's called, it moves some things, allocs, and wants to
  ;finish moving other things, but if the alloc part and its gc-work finishes
  ;the gc stack and starts handling weak pointers or something... I think the
  ;last gc-job will want to believe it is the last thing done by the gc.
  ;I could disable other gc-work during a gc-job, but... ... I don't know!
  ;Maybe I'll just say "this is only supposed to work when there's only one
  ;gc-job", and defer further stuff to the future.
  ;Note, by the way, that I could have a table that stored tag -> object length
  ;mappings, and then just trace that many words--but--this assumes objects will
  ;be purely tagged Lisp words. I guess I could install 0 for the "length" of
  ;strings, because those shouldn't be traced. And then vectors--would--have their
  ;length stored in their car. You *cannot* get around having to execute different
  ;code to trace different things, even if you don't do things like store untagged
  ;pointers or garbage within objects alongside Lisp pointes that should be traced.
  ;My confidence in this approach should be restored.
  
  ;... So the main needs are a) freeing foreign ptrs and b) weak references.
  ;Also maybe freeing system resources (open files) and anything else that needs
  ;cleaning up once it's GC'd.
  ;These need to be handled after GC tracing, and since there are potentially
  ;a bazillion of these, they need to be handled as a part of regular GC work.
  ;The value in 
  
  
  ;Ok, so I think that there would be a canonical list of foreign pointers (a list of locations of
  ;objects that contain foreign pointers, or simply a list of locations of foreign pointers),
  ;as well as a list of locations of objects that contain weak references.
  ;This, at least, ensures some balance of work: the fact that this displaces memory proportional
  ;to the work it requires, implies that probably the whole gc-work thing will continue to work fine.
  ;How about a weak assoc-table, in which keys are supposed to be weak references?
  ;(I'm thinking of things like that in having different compiled versions of functions.)
  ;(Hmph. It seems difficult or impossible to actually do that. When the key disappears, what do
  ;you do? You want to "remove the key-value pair from the assoc-list". How? Do you (zap scdr) some
  ;pair in the middle of the assoc-list? What if the entry you want to remove is the first element of
  ;the assoc-list? Do you scar/scdr the first pair to be a copy of the second pair? What if there is
  ;no second pair? Seems this would work if you only accessed the assoc-list through a wrapper structure,
  ;which sucks, although it could perhaps be doable... The alternative is for the car of the key-value pair
  ;to be a pointer to the location of a weak reference. In-dee-rection. Though perhaps that's ok...)
  ;So most of this stuff just, by nature, won't alloc at all. It might move objects, but that is acceptable.
  ;Moving objects uses "alloc" rather than "ualloc", which doesn't check for butt.
  ;Maybe someone who writes gc-jobs should be expected to write them using ualloc if necessary.
  ;(Let's say closing a file port means creating a log string somewhere...)
  ;So one solution is to have gc-next be nil while we're doing a gc-job. I feel that's a bit dangerous,
  ;if a gc-job hits an error and then let's hope the error recovery procedure is smart enough to
  ;put gc-next back to what it should be... Oh man, I'm kind of echoing myself below.
  ;Hmm, the idea I have in mind is something I thought of before. What a surprise...
  ;I shall save gc-next in a global variable, like gc-next-backup, before doing gc-jobs.
  ;(That might be worth doing for all gc work, frankly. Meh, maybe, if it happens to be easy to do that.)
  ;As a consequence, there shall be no recursive gc-jobbing.
  ;(One might have a gc-job that said "Recompile all functions to versions that don't use read barriers",
  ;and then change them back at the next gc-flip. I like myself.) (Jesus that would be a slowdown at gc
  ;flip. But it might be worth it. And, um, it might involve nothing more than altering a hundred pointers,
  ;or however many functions you have. There might be applications where this is a good idea.)
  ;What happens if gc-jobs use up too much memory and generally cause memory to fill up before GC is done?
  ;User's responsibility to prevent that. I'll be the first user.
  
  ;So. The gc-jobs object shall basically just be a list. Each element of the list corresponds in some way
  ;to information needed to execute the gc-job. Eventually this might be a thunk to call, or a function
  ;address and a vector of variables that are maintained between iterations of that job. For now...
  ;Now it's-a gonna be a one-element list with the symbol 'prepare-next-gc.
  
  ;(= gc-next-backup gc-next) ;originally gc-next-backup-dont-fuck-with-this
  ;(= gc-next nil)
  ;Screw the above. gc jobs will have to manipulate gc-next themselves.
  ;You might save a few jumps by having this stuff handle n directly. Maybe.
  ;So if your gc job allocs, and you don't want recursive crap, it is your responsibility to temporarily
  ;nilify gc-next.
  ;I'm just going to have my procedure be an Arc procedure for the moment.
  
  
  ;;So. Ideas. One thing I could do is put a variable that has the amount of deferred
  ;;gc work. Then, during execution of gc job, you increment this variable rather than
  ;;performing work. Actually, perhaps 
  )

(= get-more-memory-next-time nil)

(def round-up-int (x m)
  (let u (mod x m)
    (if (is u 0)
        x
        (+ (- x u) m))))

(def arc-prepare-next-gc ()
  (if (< (* (+ 1 gc-work-factor) (- tospace-top alloc-pointer))
         semispace-size)
      (= get-more-memory-next-time t)
      (let u (round-up-int (ceiling:/ semispace-size (+ 1 gc-work-factor)) 8)
        #;(prsn "Reserving" u "bytes")
        (allocate u))))

(ddef prepare-next-gc ()
  #;(prn "Oh man GC'ing is probably done")
  (if (< (* (+ 1 gc-work-factor) (- tospace-top alloc-pointer))
         semispace-size)
      (jump 'prepare-next-gc-need-more))
  (= chunk (round-up-int (ceiling:/ semispace-size (+ 1 gc-work-factor)) 8))
  #;(prsn "Wasting" chunk "bytes")
  (allocate chunk)
  ;with factor 4, this guarantees there will be at most .8 of a semispace of live objects to trace,
  ;and so it will all be traced by the time you have allocated .2 of a semispace of new objects.
  (if jobs-cdr
      (mm-set (+ gc-next 8) (- jobs-cdr word-top))
      (= gc-next nx))
  (ret)
  prepare-next-gc-need-more
  (prn "Oh dear, we'll want more memory.")
  (= get-more-memory-next-time t)
  (if jobs-cdr
      (mm-set (+ gc-next 8) (- jobs-cdr word-top))
      (= gc-next nx))
  (ret))

;So I think what I shall do is have the gc-job data structure get popped from
;the stack before any of its code is executed. Then you don't get some ridiculous
;infinite loop if that code happens to alloc. (It seems there'd be no practical way to turn
;off the GC-work in the (arbitrary) code executed by gc-job.)
;I'll probably have to use some sort of "on-err" thing to back up if, after popping a thing
;from the GC stack, it turns out to be untraceable.
;Semantics... stuff... the gc-work code might like to have some integer representing
;how much GC work to do. If tracing a gc-job causes arbitrary code to be executed,
;then that would probably destroy whatever register held this integer. I guess it may
;be time to introduce my first "callee-saves-something" thing.


;a bunch of this allocation and working and tracing and flipping code...
;seems like it can all be done in Arc, as long as we only want to access
;any of these through "alloc".

;Neh.  Because I'll be executing arbitrary code with a gc-job, I'll have to save things
;on the stack and so forth.  Technically, all I'd be saving is an integer n, or something,
;but... Mmm. Recursive calling of gc-jobs? Maybe I could dangerously "turn off GC'ing" by
;temporarily setting gc-next to nil. Maybe.

#;(def ugc-work ((o n 4))
  (repeat n
    (when gc-next
      (with (fwd (+ word-top mm.gc-next)
             nx (mm:+ gc-next 8))
        (= gc-next nx)
        (if (is 1 (mod fwd 8)) ;cons
            (do ucar.fwd ucdr.fwd)
            (err "How do I trace this?" fwd))))))

;I need a couple of versions of alloc.
;"Move" uses one version that does not need to do gc-work; it _is_ gc-work.
;But I will want a "user-facing" alloc that 

#;(def ualloc (n)
  (when gc-next
    (ugc-work))
  (if (> (+ alloc-pointer n) tospace-top)
      (do (gc-flip nil)
        (when gc-next (ugc-work))
        (allocate n))
      (allocate n)))

(def allocate (n)
  (if (> (+ alloc-pointer n) tospace-top)
      (err "Jesus, are you out of memory?" n)
      (do1 alloc-pointer
           (++ alloc-pointer n))))

;(ddef alloc (n) ;meh meh meh jesus
;  (if gc-next
;      (call 'gc-work))
;  (if (< (+ alloc-pointer n) tospace-top)
;      (jump 'alloc-full))
;  (= return (allocate n))
;  (ret)
;  alloc-full
;  (save n)
;  (call 'gc-flip)
;  (restore n)
;  (unless (< (+ alloc-pointer n) tospace-top)
;    (jump 'alloc))
;  (= get-more-memory-next-time t)
  

(ddef alloc (n)
  (if no.gc-next
      (jump 'alloc-plain))
  (save n)
  (call 'gc-work)
  (restore n)
  alloc-plain
  (if (> (+ alloc-pointer n) tospace-top)
      (jump 'alloc-handle-gc-flip))
  
  (if (isnt 0 (mod n 8)) ;Could silently round up
      (err "Noob align your memory allocations properly" n)
      (< n 16) ;Again, could silently round up...
      (err "Noob allocate bigger objects" n))
  (= return alloc-pointer)
  (++ alloc-pointer n)
  (ret)
  
  alloc-handle-gc-flip
  (save n)
  (gc-flip)
  (restore n)
  alloc-2
  (if no.gc-next
      (jump 'alloc-plain-2))
  (save n)
  (call 'gc-work)
  (restore n)
  alloc-plain-2
  (if (> (+ alloc-pointer n) tospace-top)
      (jump 'alloc-oh-my-god))
  
  (if (isnt 0 (mod n 8)) ;Could silently round up
      (err "Noob align your memory allocations properly" n)
      (< n 16) ;Again, could silently round up...
      (err "Noob allocate bigger objects" n))
  (= return alloc-pointer)
  (++ alloc-pointer n)
  (ret)
  
  alloc-oh-my-god
  (save n)
  (gc-flip t)
  (restore n)
  (jump 'alloc-2))

(def fromspace-pointer (x)
  (and is-pointer.x fromspace.x))

(= gc-flips 0)
(def gc-flip ((o get-more-memory get-more-memory-next-time))
  (= get-more-memory-next-time nil)
  #;(prn "GC-flip!")
  (++ gc-flips)
  (= which-space (- 1 which-space))
  (when get-more-memory
    (unless (< semispace-size-bits (- word-bits 2)) ;need sign bit
      (err "gc-flip: Too much memory for this word size"))
    (++ semispace-size-bits)
    (= semispace-size (expt 2 semispace-size-bits)
       memory-top (* 2 semispace-size)
       which-space 1))
  (= alloc-pointer (* semispace-size which-space)
     tospace-top (* semispace-size (+ 1 which-space))
     gc-next nil)
  
  ;If setting up gc-jobs, do so here.
  (when gc-jobs-list
    #;(prsn "MOVING GC-JOBS-LIST" gc-jobs-list)
    (zap move gc-jobs-list))
  
  ;Move the stack all at once, for now.
  (xloop (x the-stack)
    (when x
      (when (fromspace-pointer car.x)
        #;(prsn "MOVING THING ON STACK" car.x)
        (zap move car.x))
      (next cdr.x)))
  
  ;OH GOD THERE IS A ROOT SET: defined things.
  (each (k v) global-value
    (when fromspace-pointer.v
      #;(prsn "MOVING GLOBAL VARIABLE" k v)
      (= global-value.k (move v nil))))
  t)

(def weird-cons (a b)
  (let u (allocate 16)
    (mm-set u a)
    (mm-set (+ u 8) b)
    (+ u 3)))

(def weird-list args
  (if no.args
      nil
      (weird-cons car.args (apply weird-list cdr.args))))

(def initialize-butt ()
  (= gc-jobs-list (weird-list 'prepare-next-gc))
  (arc-prepare-next-gc)) ;do this anyway for now
  

  

(ddef ucons (x y)
  (save x y)
  (= n 16)
  (call 'alloc) ;untagged
  (restore y x)
  (mm-set return x)
  (mm-set (+ return 8) y)
  (= return (+ return 1))
  (ret))

(ddef uflip (x y) ;oh man x y is convenient with cons
  (if no.x
      (ret)) ;returns y; also returns "return", lolz...
  (save ucdr.x)
  (= x ucar.x)
  (call 'ucons)
  (= y return) ;dumbass forgot this line
  (restore x)
  (jump 'uflip)) ;I could save a jump per 'uflip by duplicating the test at the bottom...
(ddef ucopy-list (x)
  (= y nil)
  (call 'uflip)
  (swap x y)
  (jump 'uflip)) ;return in y; ahhh, the good feeling of garbage
;this is one way to do rest args (last arg at bottom of stack, stacks always
;grow downward):
;;oh geez, no, it's more difficult than this.  CALL will put ret addr at _the_ bottom.
;(ddef ulist (stack-term) ;This shit sucks; ret-addr is not car.the-stack if you jump to this ;aha ;fuck it
;  (= return nil ret-addr pop.the-stack) ;fuck it I'll just require people to (call) this
;  ulist-loop
;  (if (is stack-term the-stack)
;      (= the-pc ret-addr)) ;another way to jump...
;  (= x pop.the-stack y return)
;  (save ret-addr)
;  (call 'ucons)
;  (restore ret-addr) ;jesus this sucks
;  (jump 'ulist-loop))

;AHA!  Finally, something I can be pleased with.
(ddef ulist (n) ;number of args on the stack ;nope
  (if (is n 0)
      (do (= return nil) (ret)))
  (save n)
  (= n (* n 16))
  (call 'alloc)
  (restore n)
  (= ret-addr pop.the-stack)
  (= x nil)
  (for i 0 dec.n ;no allocation, so this is fine
    (mm-set (+ return (* i 16)) pop.the-stack)
    (mm-set (+ return 8 (* i 16)) x)
    (= x (+ 1 return (* i 16))))
  (= return x)
  (= the-pc ret-addr))


#;(ddef hella-cons (return x) ;specialized for awesome power ;derf, wrong arg order
  (= env (cons return x))
  (ret)) ;probably not worth it, given how much work cons already does

(ddef urev (xs)
  (= x xs y nil)
  (call 'uflip)
  (= return y) ;aw, no fun...
  (ret))

(def a-ucons (x)
  (and (isa x 'int) (is 1 (mod x 8))))

(ddef hella-ucons (return env)
  (save return env)
  (= n 16)
  (call 'alloc) ;untagged
  (restore env varval)
  (mm-set return varval)
  (mm-set (+ return 8) env)
  (= env (+ return 1))
  (ret))

#;(mac var-args args ;thought there might be a more clever way, but shall do this
  `(do ,@(map (fn (x) `(push ,x the-stack)))
       (= n ,(len args))))

;hmm, I've reordered the "symbol" vs "cons" things. oh well.
(ddef join-envs (env arg-names xs)
  ;I could localize the "return in env" thing, but actually that's useful to callers
  (if no.arg-names
      (if no.xs
          (ret) ;return in env!
          (err "Too many arguments:" xs))) ;kind of strict
  (if (a-ucons arg-names)
      (jump 'join-envs-b)
      (no:isa arg-names 'sym)
      (err "What kind of argument is this?" arg-names))
  
  ;arg-names = 'var
  (save env)
  (= n 2)
  (push arg-names the-stack)
  (push xs the-stack)
  (call 'ulist)
  (restore env)
  (jump 'hella-ucons) ;specialized; would be inlined by compiler
  
  join-envs-b
  (if (no a-ucons.xs)
      (err "Arg!" arg-names xs))
  (save ucdr.arg-names ucdr.xs)
  (= arg-names ucar.arg-names
     xs ucar.xs)
  (call 'join-envs) ;return in env
  (restore xs arg-names)
  (jump 'join-envs))

(ddef ulist-ref (xs n)
  (if (is n 0)
      (do (= return ucar.xs) (ret)))
  (zap ucdr xs)
  (-- n)
  (jump 'ulist-ref))

(def ulist->list (xs)
  (if no.xs
      nil
      (cons ucar.xs (ulist->list ucdr.xs))))

(def apply-to-ulist (f xs)
  (apply f (ulist->list xs)))

(def a-ulist (xs)
  (or no.xs
      (and a-ucons.xs
           (a-ulist ucdr.xs))))

(mac upop (name)
  (unless (isa name 'sym)
    (err "upop: Too lazy to do generalized assignment" name))
  `(do1 (ucar ,name)
        (= ,name (ucdr ,name))))

(ddef uapply (f xs) ;ahh, here we go
  (if (is-system-proc f)
      (do (= return (apply-to-ulist f xs))
        ;ugh, I expect most system-procs won't cons too much, but...
        ;Eh, it doesn't matter here, 'cause I don't need to save anything anyway.
        ;Later I'll just have to substitute an "apply" that handles the other kind of list.
        ;...neeh... "cons". W... neeh, this seems ok.
        (ret))
      (no a-ulist.f)
      (err "uapply: What is this?" f xs)
      (is ucar.f 'closure)
      (jump 'uapply-a)
      (is ucar.f 'macro)
      (err "Sorry, not sure how to apply a macro" f xs)
      (and a-ucons.xs (no ucdr.xs) (isa ucar.xs 'int))
      (do (= n ucar.xs xs f) (jump 'ulist-ref))
      (err "uapply: What is this?" f xs))
  
  uapply-a ;f = (closure env arglist . bodexprs)
  (zap ucdr f)
  (= env upop.f arg-names upop.f bodexprs f) ;d'oh, forgot "f"
  (save bodexprs)
  (call 'join-envs) ;returns its env in env
  (restore exprs)
  (jump 'uapply-loop))

;xs = (arglist . bodexprs)
;want to return ('closure env arglist bodexprs)
(ddef eval-fn (xs env) ;time to write it with conses
  (= x env y xs)
  (call 'ucons)
  (= x 'closure y return)
  (jump 'ucons))

(ddef ueval (x env)
  (if (and (isa x 'int) (is 0 (mod x 8)))
      (do (= return x) (ret))
      (isa x 'sym)
      (aif (uassoc x env)
           (do (= return ucadr.it) (ret))
           (global-value x)
           (do (= return (if (is it 'HELLA-NIL) 'nil it)) (ret))
           (err "ueval: Not defined:" x))
      (no:a-ulist x)
      (err "What is this?" x))
  (= f ucar.x xs ucdr.x)
  (if (is f 'quote)
      (do (= return ucar.xs) (ret))
      (is f 'if)
      (jump 'eval-if) ;xs env
      (is f '=)
      (jump 'eval-=) ;xs env
      (is f 'fn)
      (jump 'eval-fn) ;xs env
      (is f 'mc)
      (jump 'eval-macro) ;xs env
      (is f 'quasiquote)
      (do (= x ucar.xs n 1) (jump 'eval-qq)) ;xs n env
      (is f 'arc)
      (do (= return (eval ucar.xs)) (ret)))
  (save xs env)
  (= x f)
  (call 'ueval)
  (restore env xs)
  ;oh boy
  (if (no:and a-ucons.return (is ucar.return 'macro))
      (jump 'ueval-b))
  
  ueval-a
  (save env)
  (= f return)
  (call 'apply-mac) ;f xs
  (restore env)
  (= x return)
  (jump 'ueval)
  
  ueval-b ;we evaluate the list of arguments xs, then apply the function 'return to it.
  (if no.xs
      (do (= f return) (jump 'uapply))) ;massive shortcut, and necessary so entry point works
  (save return)
  (= ys nil)
  (save env)
  ;oh man time to do an "entry point" thing
      
  (jump 'ueval-b-loop-entry-point)
  
  ;Two thoughts from the bathroom.
  ;1. I could offload this into an "eval-exprs-in-env" procedure.
  ;2. I could maybe extend the instruction-list interpreter so that
  ; it would have a "splice" instruction, so that you'd go
  ; (inst . (inst . #0=(inst . ((splice 'some-instructions #0#) inst ...))))
  ; and the "splice" instruction would modify the instruction list (and jump back).
  ;Btw, I never did test exactly how overwriting the next few instructions, or
  ; previous instructions and then jumping to the point of overwriting, would work...
  ;does the processor flush some cache? Meh.
  
  ueval-b-loop ;xs is xs, ys is return, env is on stack
  (= ys return env car.the-stack) ;oh man, we use stack w/o popping; oh man not ucar
  
  ueval-b-loop-entry-point
  (save ucdr.xs ys)
  (= x ucar.xs)
  (call 'ueval)
  (restore ys)
  (= x return y ys)
  (call 'ucons)
  (restore xs)
  (if xs
      (jump 'ueval-b-loop))
  ;return = ys, env is on stack, xs is nil
  (pop the-stack) ;dump env, now f on stack
  (= x return y nil)
  (call 'uflip) ;x y -> return y ;defined urev, but neh, don't use
  (= xs y) ;you're an idiot, you said it returned in y
  (restore f)
  (jump 'uapply)) ;jeeeeeeesus christ

(def uatom (x)
  (no is-pointer.x))

(ddef eval-qq (x n env)
  (if uatom.x
      (do (= return x) (ret))
      
      (is ucar.x 'quasiquote)
      (jump 'eval-qq-a)
      
      (is ucar.x 'unquote)
      (if (is n 1)
          (do (= x ucadr.x) (jump 'ueval))
          (jump 'eval-qq-b))
      
      (is ucar.x 'unquote-splicing)
      (if (is n 1)
          (err "Bad use of unquote-splicing" x n env)
          (jump 'eval-qq-c)))
  
  eval-qq-loop
  (save ucdr.x n env)
  (zap ucar x)
  (call 'eval-qq)
  (restore env n xs) ;names
  (save return)
  (call 'eval-qq-tail)
  (restore x)
  (= y return)
  (jump 'ucons)
  
  eval-qq-a
  (= x ucadr.x n (+ n 1))
  (call 'eval-qq)
  (= n 2)
  (push 'quasiquote the-stack)
  (push return the-stack) ;oh man more rest args
  (call 'ulist)
  (ret) ;fuckin' rest args
  
  eval-qq-b
  (= x ucadr.x n (- n 1))
  (call 'eval-qq)
  (= n 2)
  (push 'unquote the-stack)
  (push return the-stack)
  (call 'ulist)
  (ret) ;jesus
  
  eval-qq-c
  (zap ucadr x)
  (-- n)
  (call 'eval-qq)
  (= n 2)
  (push 'unquote-splicing the-stack)
  (push return the-stack)
  (call 'ulist)
  (ret))

(def ucaar (x) (ucar ucar.x))
(def ucadar (x) (ucar:ucdr:ucar x))

(ddef eval-qq-tail (xs n env)
  (if uatom.xs
      (do (= return xs) (ret))
      (no:and (a-ucons ucar.xs)
              (is n 1)
              (is ucaar.xs 'unquote-splicing))
      (do (= x xs) (jump 'eval-qq-loop))) ;LOLOLOLOLZ, cross-function jumping
  (save ucdr.xs n env)
  (= x ucadar.xs)
  (call 'ueval)
  (restore env n xs)
  (save return)
  (call 'eval-qq-tail)
  (= xs pop.the-stack ys return)
  (jump 'ujoin-2))

(ddef ujoin-2 (xs ys)
  (save ys)
  (= x xs y nil)
  (call 'uflip)
  (= x y y pop.the-stack)
  (call 'uflip)
  (= return y)
  (ret))

(mac rest-args args
  `(do (= n ,(len args))
     ,@(map (fn (x) `(push ,x the-stack)) args)))

(ddef eval-macro (xs env)
  (call 'eval-fn)
  (rest-args 'macro return)
  (call 'ulist)
  (ret))

(ddef apply-mac (f xs)
  (zap ucadr f)
  (jump 'uapply))

(def is-system-proc (x)
  (isa x 'fn))

(def num->unum (x)
  (if (isa x 'int)
      (ash x 3)
      x))
(def unum->num (x)
  (if (isa x 'int)
      (if (isnt 0 (mod x 8))
          (do (prsn "Not an integer!" x)
              (err "How do you get a uint like this?" ut.x))
          (ash x -3))
      x))

(each f '(+ - * / expt)
  (= (symbol-value (symb 'u- f))
     (eval `(fn args
              (num->unum (apply ,f (map unum->num args)))))))

(= global-value
   (obj + u-+ - u-- * u-* / u-/ expt u-expt
        cons ucons car ucar cdr ucdr is is < < > >
        scar uscar scdr uscdr uniq uniq
        apply uapply eval ueval apply-mac apply-mac nil 'HELLA-NIL
        acons a-ucons
        ))


(ddef tree->utree (x) ;punts on cycles
  (if (isa x 'int)
      (zap [ash _ 3] x))
  (if atom.x
      (do (= return x) (ret)))
  (save cdr.x)
  (zap car x)
  (call 'tree->utree)
  (restore x)
  (save return)
  (call 'tree->utree)
  (restore x)
  (= y return)
  (jump 'ucons))

(def utree->tree (x)
  (if a-ucons.x
      (cons (utree->tree ucar.x)
            (utree->tree ucdr.x))
      (and (isa x 'int) (is 0 (mod x 8)))
      (ash x -3)
      x))

(def ue (x)
  (ueval x nil))

(= ut utree->tree
   tu tree->utree)


(def em ()
  (while t
    (pr "emiya> ")
    (prn:utree->tree:ue:tree->utree:read)))

(def mm-range (a b)
  (mapn [mm:ash _ 3] (ash a -3) (ash b -3)))

(def h ()
  (ustep) (pprn car.the-pc) cdr.the-pc)

(initialize-butt)

(no:ueval (tu '((fn ()
                  (= list (fn args args)
                     no (fn (x) (is x 'nil))
                     list* (fn args (if (no (cdr args))
                                        (car args)
                                        (cons (car args) (apply list* (cdr args)))))
                     mac (mc (name args . body)
                             (list '= name (list* 'mc args body)))
                     fifty (list 1 2 3 4))
                  (mac def (name args . body)
                    `(= ,name (fn ,args ,@body)))
                  (def cadr (x) (car (cdr x)))
                  (def macex1 (xs)
                    (apply-mac (eval (car xs) nil) (cdr xs)))
                  (mac let (var val . body)
                    (list (list* 'fn (list var) body) val))
                  (mac or args
                    (if (no args)
                        ''t
                        (no (cdr args))
                        (car args)
                        (let u (uniq)
                          (list 'let u (car args)
                                (list 'if u u (list* 'or (cdr args)))))))
                  (mac bracket-fn (body)
                    (list 'fn '(_) body))
                  (mac do body (list (list* 'fn () body))) ;aha, error
                  (def accumulate (comb f xs init next done)
                    (if (done xs)
                        init
                        (accumulate comb f
                                    (next xs) (comb (f xs) init)
                                    next done)))
                  ;              (def take (n xs)
                  ;                (if (or (no xs) (is n 0))
                  ;                    nil
                  ;                    (cons (car xs) (take (- n 1) (cdr xs)))))
                  ;              (def drop (n xs)
                  ;                (if (or (no xs) (is n 0))
                  ;                    xs
                  ;                    (drop (- n 1) (cdr xs))))
                  ;              (def tuples (n xs)
                  ;                (if (no xs)
                  ;                    nil
                  ;                    (cons (take n xs) (tuples n (drop n xs)))))
                  ;              (def map1 (f xs)
                  ;                (if (no xs)
                  ;                    nil
                  ;                    (cons (f (car xs)) (map1 f (cdr xs)))))
                  (def id (x) x)
                  (def rev (xs)
                    (accumulate cons car xs nil cdr no))
                  (mac -- (n . d)
                    (list '= n (list '- n (if d (list 'quote d) 1))))
                  (def take (n xs)
                    (rev (accumulate cons car xs nil cdr [or (no _) (> 0 (-- n))])))
                  (def drop (n xs)
                    (if (or (is n 0) (no xs))
                        xs
                        (drop (- n 1) (cdr xs))))
                  (def tuples (n xs)
                    (rev (accumulate cons [take n _] xs nil [drop n _] no)))
                  (def map1 (f xs)
                    (rev (accumulate cons [f (car _)] xs nil cdr no)))
                  (mac rfn (name args . body) ;oh man, circular data structure
                    (list 'let name 'nil
                          (list '= name
                                (list* 'fn args body))))
                  (mac xloop (varvals . body)
                    (list* (list* 'rfn 'next (map1 car (tuples 2 varvals)) body)
                           (map1 cadr (tuples 2 varvals))))
                  (def map (f . xses)
                    (if (no xses)
                        nil
                        (cons (apply f (map1 car xses))
                              (apply map f (map1 cdr xses))))))))
          nil)