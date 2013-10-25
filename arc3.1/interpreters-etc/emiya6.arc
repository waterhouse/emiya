;J. F. C., this seems to work. And be pretty horrible.
;Next it'll be time to ... put in symbols, oh god...


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


;All right. Time to handle strings. Later build symbols on top of strings.
;Don't actually handle strings much. Probably string-append as proof of
;concept and whatever.

;Do I break strings up now? ... Yeah, sure. Must test with large strings.

;Do I use the technique of having a string pointer, its length field being the
;first word, point to the second word (i.e. the start of the data)?
;(Probably I'll have a word before that that might be a fromspace ptr, or
;perhaps generally a string-continuation ptr.)
;Eh... For the moment... Yes; when moved, the fwd ptr is at data bytes 0-7 ...
;Fuck, no, that doesn't work well when bytes are arbitrary and anything might
;look like a fwd ptr. Also, I can be like
;reg1 = arr; reg2 = arr + n; mov reg3, [reg2 + 16] if data is off by 16.
;So.
;String:
;ptr -> [fwd/backwd ptr, or 0] [length] [data ...]
;There we are. And, length = length of data presently there.
;String-ref/set will check length. If less, then it works fine.
;If greater, check backwd ptr. If 0, then bounds error.
;Otherwise, look in unmoved part. Check len there.
;If greater, then genuine bounds error. Otherwise, works.

;...Fuck. Only problem is, the way I thread the stack through object corpses,
;I would clobber the length there.
;Fuck it. Hmm. Some options:
;- redesign string, put length later (extra whole-length field?)
;- make GC look elsewhere for next ptr in string (jes')
;- ... Going with first option, and maybe there will be a use for the extra field.

(= type-tag (obj int 0 cons 1 string 3 gc-work-cons 7))

(= the-memory (table))
(def mm (n) ;memory access
  (unless (isa n 'int)
    (err "IDIOT TRYING TO DEREFERENCE A NON-POINTER" n))
  (unless (is 0 (mod n 8))
    (err "NOOB TRYING TO ACCESS UNALIGNED MEMORY" n))
  (unless (< -1 n memory-top)
    (err "NOOB GETTING MEMORY OUT OF BOUNDS" n))
  ([if (is _ 'HELLA-NIL) nil _]
   (the-memory n (fn () (err "IDIOT TRYING TO ACCESS UNINITIALIZED MEMORY" n)))))
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

;fwd ptrs tagged by most significant (i.e. sign) bit.
(def fwdify (x)
  (unless (<= 0 x memory-top)
    (err "What are you fwdifying?" x))
  (- x word-top))
(def is-fwd (x)
  (and (isa x 'int)
       (isnt 0 (bit-and x word-top))))
(def is-fwd-ptr (x)
  (and is-fwd.x is-pointer.x))
(def de-fwd (x)
  (let u (+ x word-top)
    (unless (and (< x 0) (<= 0 u memory-top))
      (err "What are you de-fwding?" x))
    u))
(def un-fwd (x)
  (de-fwd x))
   

;jesus, I'm now parameterizing type tags.
;oh well. not like speed should be an issue for the moment.

;goddammit, all those "move-___" procedures are stupid. Jesus.  Killing.
;oh hey, I forgot about gc-next. D'oh.
;... no, gc-next is a ptr. An aligned, untagged ptr.

(def copy-words (src dest n)
  (when (> n 0)
    (mm-set dest mm.src) ;oh god I had args reversed
    (copy-words (+ src 8) (+ dest 8) (- n 1))))

;so, been thinking about multithreading.
;... for a later time.

;Usual pattern for things you copy all at once. fwd ptr = first word of orig
(def move-n-and-leave-fwd (src n tg)
  (let dest (allocate (* n 8))
    (copy-words src dest n)
    (let tdest (+ dest tg)
      (mm-set src fwdify.tdest)
      (mm-set (+ src 8) gc-next)
      (= gc-next src)
      tdest)))

(def is-tagged (x n)
  (and (isa x 'int) (is n (mod x 8))))

;hmm, when this only checked for "fromspace" not "fromspace-ptr",
;it seemed this could cause weird shit given a large integer. --or not this.
;hmm, what is causing this?
;ah, it is fwd/de-fwd.
(def move (x (o complain t))
  (if (or (no:isa x 'int) no:fromspace-pointer.x)
      (if complain
          (err "NOOB TRYING TO MOVE SOMETHING THAT'S NOT A FROMSPACE PTR" x)
          x)
      ;all things put fwd ptr at first word.
      (is-fwd-ptr:mm:- x (mod x 8))
      (let y (de-fwd:mm:- x (mod x 8))
        (if (isnt 0 (mod (- x y) 8))
            (err (string "We have a serious philosophical issue, with one thing "
                         "forwarding to another thing of a different type.")
                 x y)
            y))
      
      (is-tagged x type-tag!cons)
      (move-cons x)
      ;now this is where I wonder; if we know the string is short enough,
      ;compared to how much gc work we want to do, to be moved all at once,
      ;then we might do something kind of different.
      ;in that case, I'd need to handle accepting "the amount of work I want
      ;to do" as an argument, or decide indeed to keep that as a global var
      ;(in a register, possibly).
      ;however, I think I can just do "minimum amount of work" here (this is
      ;probably the read barrier), and the deliberate gc work will monitor
      ;its own crap.
      (is-tagged x type-tag!string)
      (move-string x)
      (is-tagged x type-tag!gc-work-cons)
      (move-gc-work-cons x)
      (err "WTF PTR IS THIS?" x)))
(def move-cons (xt)
  (withs (tg (mod xt 8) x (- xt tg))
    (move-n-and-leave-fwd x 2 tg)))

;ok, so, for the moment, a string has one character per CPU word.
;lolz.
;this would even work...
;[fwd/backwd] [dunno] [len] [data ...]
(def move-string (xt)
  (withs (tg (mod xt 8) src (- xt tg))
    (let dest (allocate (+ 24 (* 8 (mm:+ src 16)))) ;3 extra fields... ;noob src not x
      (mm-set dest xt) ;backwd ptr
      (mm-set (+ dest 8) #x676E697274732061) ;lolololz, useless field
      (mm-set (+ dest 16) 0) ;len=0 so far
      (let tdest (+ dest tg)
        (mm-set src fwdify.tdest) ;fwd ptr
        (mm-set (+ src 8) gc-next)
        (= gc-next src)
        tdest))))
(def move-gc-work-cons (xt)
  (withs (tg (mod xt 8) x (- xt tg))
    (move-n-and-leave-fwd x 2 tg)))

(def is-pointer (n)
  ;currently pointers = conses
  (and (isa n 'int) (in (mod n 8) type-tag!cons type-tag!string type-tag!gc-work-cons)))

(= loud-read-barrier nil)

;This is the read barrier.
(def grab-possible-pointer (n (o move-message "READ BARRIER AT WORK"))
  (let u mm.n
    (if (and is-pointer.u fromspace.u)
        (do (when loud-read-barrier
              (prsn move-message u))
          (mm-set n (move u)))
        u)))

(mac check-cons (var msg)
  `(unless (and (isa ,var 'int)
                (is type-tag!cons (mod ,var 8)))
     (err ,msg ,var)))

;the "typ" is an expression, so must be quoted
(mac let-untag (var val typ . body)
  (w/uniq g
    `(let ,g ,val
       (let ,var (and (isa ,g 'int)
                      (- ,g (type-tag ,typ)))
         (unless (and (isa ,g 'int)
                      (is 0 (mod ,var 8)))
           (err:string "Expected ptr of type " ,typ
                       " with tag " (type-tag ,typ)
                       ", but found " (+ ,var (type-tag ,typ))))
         ,@body))))

(def uscar (n x)
  (check-cons n "NOOB TRYING TO SET-CAR A NON-CONS")
  (mm-set (- n type-tag!cons) x))
(def uscdr (n x)
  (check-cons n "NOOB TRYING TO SET-CDR A NON-CONS")
  (mm-set (- (+ n 8) type-tag!cons) x))

;shall I have (ca/dr nil) = nil? for the moment, nah.
;but anyway, for the moment, nil will still be nil.
(def ucar (n (o no-barrier))
  (if (is n nil)
      (err "Taking car of nil"))
  (check-cons n "GET YOUR CAR CHECKED")
  (if no-barrier
      (mm:- n type-tag!cons)
      (grab-possible-pointer (- n type-tag!cons))))
(def ucdr (n (o no-barrier))
  (if (is n nil)
      (err "Taking cdr of nil"))
  (check-cons n "GET YOUR OTHER CAR CHECKED")
  (if no-barrier
      (mm:- (+ n 8) type-tag!cons)
      (grab-possible-pointer (- (+ n 8) type-tag!cons))))

;strings: one char per cpu word. chars are probably Racket chars.
;though this actually doesn't care.
;note that n is a uint!
(def ustring-ref (xt n)
  (let n (/ n 8)
    (let-untag x xt 'string
      (if (< n 0)
          (err "NEGATIVE STRING INDEX" n)
          (< n (mm:+ x 16)) ;length, or # copied
          (mm:+ x 24 (* n 8))
          (let possible-fwd (mm x)
            (if (is possible-fwd 0)
                (err "STRING INDEX OUT OF BOUNDS" xt n)
                (let-untag y un-fwd.possible-fwd 'string
                  (if (< n (mm:+ y 16))
                      (mm:+ y 24 (* n 8))
                      (err "STRING INDEX OUT OF BOUNDS (FWD'D)" xt y n)))))))))
(def ustring-set (xt n val)
  (let n (/ n 8)
    (let-untag x xt 'string
      (if (< n 0)
          (err "NEGATIVE STRING INDEX" n)
          (< n (mm:+ x 16)) ;length, or # copied
          (mm-set (+ x 24 (* n 8)) val)
          (let possible-fwd (mm x)
            (if (is possible-fwd 0)
                (err "STRING INDEX OUT OF BOUNDS" xt n)
                (let-untag y un-fwd.possible-fwd 'string
                  (if (< n (mm:+ y 16))
                      (mm-set (+ y 24 (* n 8)) val)
                      (err "STRING INDEX OUT OF BOUNDS (FWD'D)" xt y n)))))))))


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

;why doesn't this list n as an argument? mmm.
(ddef gc-work (n) ;deal NOW with work factor and bytes allocated; shit died without this
  ;ok, so, n is inputted as # bytes of work to do, and becomes # words of work to do.
  (= n (* (/ n 8) gc-work-factor))
  gc-work-loop
  (if (or (<= n 0) no.gc-next)
      (ret)) ;you can't conditional-ret in x86... can't ret at all on other platforms
  #;(-- n) ;amt work done will be seen
  (= fwd (de-fwd mm.gc-next)
     nx (mm:+ gc-next 8))
  ;we must type-dispatch on fwd.
  ;it's seeming like a somewhat silly idea to have a specially tagged gc-jobs
  ;data structure. it's a slight optimization, over having a global variable
  ;for that and a test. ... and it lets you insert gc-jobs whenever you like,
  ;ex. for perverting the GC work towards resizing your hash table.
  ;eh.  I can just add that test later.
  
  ;looking now, it seems pretty wasteful, especially consuming one of the 0-7
  ;type tags... though it could be made into a user tag. then no overhead.
  ;all right, that should be fine. (don't want to slow down alloc when gc work
  ;is done, for the most part) (though "-1" or "8" as a "finished, doing gc
  ;jobs" value wd be good) (feh)
  (if (is type-tag!cons (mod fwd 8)) ;later -> jump table
      (jump 'trace-cons)
      (is type-tag!gc-work-cons (mod fwd 8))
      (jump 'trace-gc-job)
      (is type-tag!string (mod fwd 8))
      (jump 'trace-string)
      (err "How do I trace this?" fwd))
  trace-cons
  (= gc-next nx)
  (grab-possible-pointer (- fwd type-tag!cons) "GC-WORK AT WORK")
  (grab-possible-pointer (- (+ fwd 8) type-tag!cons) "GC-WORK AT WORK")
  (-- n 2) ;words traced
  (jump 'gc-work-loop)
  
  trace-gc-job ;fwd -> ('job-func-name . (more crap))
  (= func-name (mm (- fwd type-tag!gc-work-cons)))
  (= jobs-cdr (mm (- (+ fwd 8) type-tag!gc-work-cons)))
  (call func-name) ;which... will decrement n how it wishes, I guess
  (jump 'gc-work-loop)
  
  trace-string ;i.e. finish copying (a vector must actually trace)
  ;[back] [dick] [len] [data ...] ;note back is a normal string-tagged ptr
  ;btw, is len in words or bytes, and is it a uint (<< 3) or an int?
  ;currently len is in words and is an int.
  (= x (- fwd type-tag!string)) ;the dest
  (if (is mm.x 0) ;the backptr
      (do (-- n (+ 3 (mm:+ x 16)))
        (= gc-next nx)
        (jump 'gc-work-loop)))
  (= y (- mm.x type-tag!string) ;the src
     x-len (mm:+ x 16))
  (unless (is y gc-next)
    (err (string "Philosophical problem: following a fwd ptr to a backptr hasn't"
                 " brought us back to the start.") gc-next x y))
  (= extra-words (- (mm:+ y 16) x-len)) ;char = word...
  (if (>= n extra-words)
      (jump 'trace-whole-string))
  ;only partial string here
  (copy-words (+ y 24 (* 8 x-len))
              (+ x 24 (* 8 x-len))
              n)
  (mm-set (+ x 16) (+ x-len n))
  (ret)
  
  trace-whole-string
  (= gc-next nx)
  (copy-words (+ y 24 (* 8 x-len))
              (+ x 24 (* 8 x-len))
              extra-words)
  (mm-set (+ x 16) (+ x-len extra-words))
  (mm-set x 0) ;done copying
  (-- n extra-words)
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


;"User-facing" alloc = alloc, low-level "get me memory" = allocate

(def allocate (n)
  (if (> (+ alloc-pointer n) tospace-top)
      (err "Jesus, are you out of memory?" n)
      (do1 alloc-pointer
           (++ alloc-pointer n))))

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

(def utype (x)
  (if a-uint.x 'uint
      a-ucons.x 'ucons
      a-ustring.x 'ustring
      (is (mod x 8) type-tag!gc-work-cons) 'gc-work-cons
      (err "Unknown utype:" x)))

(= gc-flips 0)
(= loud-gc-flip nil)
(= stack-loud nil)
(def gc-flip ((o get-more-memory get-more-memory-next-time))
  (= get-more-memory-next-time nil)
  (when loud-gc-flip (prn "GC-flip!"))
  (++ gc-flips)
  (when (is gc-flips 8)
    #;(err "Noob")
    #;(= stack-loud t))
  (= which-space (- 1 which-space))
  (when get-more-memory
    (prsn "Doubling memory used to" (* 2 semispace-size) "bytes")
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
        (when stack-loud (prsn "MOVING THING ON STACK" car.x))
        (zap move car.x))
      (next cdr.x)))
  (when stack-loud (prn "DONE WITH STACK"))
  
  ;OH GOD THERE IS A ROOT SET: defined things.
  (each (k v) global-value
    (when fromspace-pointer.v
      #;(prsn "MOVING GLOBAL VARIABLE" k v)
      (= global-value.k (move v nil))))
  
  (when loud-gc-flip (prn "Flipping done!"))
  (= after-flip-pc the-pc after-flip-stack the-stack)
  t)

(def weird-cons (a b)
  (let u (allocate 16)
    (mm-set u a)
    (mm-set (+ u 8) b)
    (+ u type-tag!gc-work-cons)))

(def weird-list args
  (if no.args
      nil
      (weird-cons car.args (apply weird-list cdr.args))))

(def initialize-butt ()
  (= gc-jobs-list (weird-list 'prepare-next-gc))
  (arc-prepare-next-gc)) ;do this anyway for now
  



;hmm... if saved on stack, must be a uint.
;for now, no specification of char for initialization.
(ddef umake-string (n) ;uint
  (save n)
  (= n (+ 24 (* (/ n 8) 8))) ;not * 16 wtf
  (call 'alloc)
  (restore n)
  (= n (/ n 8)) ;int; be safe now
  (mm-set return 0)
  (mm-set (+ return 8) #x676E697274732061) ;lolz
  (mm-set (+ return 16) n)
  (for i 0 dec.n
    (mm-set (+ return 24 (* i 8)) #\∅))
  (= return (+ return type-tag!string))
  (ret))

(def string-length (xt)
  (let-untag x xt 'string
    (if (is 0 mm.x)
        (mm:+ x 16)
        (let-untag y mm.x 'string
          (mm:+ y 16)))))

(def ustring-length (xt)
  (* 8 string-length.xt))

;user can define string-append, lolz


(ddef ucons (x y)
  (save x y)
  (= n 16)
  (call 'alloc) ;untagged
  (restore y x)
  (mm-set return x)
  (mm-set (+ return 8) y)
  (= return (+ return type-tag!cons))
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
    (= x (+ type-tag!cons return (* i 16))))
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
  (and (isa x 'int) (is type-tag!cons (mod x 8))))

(ddef hella-ucons (return env)
  (save return env)
  (= n 16)
  (call 'alloc) ;untagged
  (restore env varval)
  (mm-set return varval)
  (mm-set (+ return 8) env)
  (= env (+ return type-tag!cons))
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

(def a-uint (x)
  (and (isa x 'int) (is 0 (mod x 8))))

(ddef ulist-ref (xs n) ;n is a uint!
  (unless a-uint.n
    (err "list-ref: not an integer index" xs n))
  (if (< n 0)
      (err "list-ref: negative index" xs n))
  ulist-ref-loop
  (if (is n 0)
      (do (= return ucar.xs) (ret)))
  (zap ucdr xs)
  (-- n 8) ;i.e. "1"
  (jump 'ulist-ref-loop))

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

(def a-ustring (x)
  (and (isa x 'int) (is (mod x 8) type-tag!string)))

(ddef uapply (f xs) ;ahh, here we go
  (if (is-system-proc f)
      (do (= return (apply-to-ulist f xs))
        ;ugh, I expect most system-procs won't cons too much, but...
        ;Eh, it doesn't matter here, 'cause I don't need to save anything anyway.
        ;Later I'll just have to substitute an "apply" that handles the other kind of list.
        ;...neeh... "cons". W... neeh, this seems ok.
        (ret))
      (a-ustring f)
      (jump 'uapply-string)
      (no a-ulist.f)
      (err "uapply: What is this?" f xs)
      (is ucar.f 'closure)
      (jump 'uapply-a)
      (is ucar.f 'macro)
      (err "Sorry, not sure how to apply a macro" f xs)
      (jump 'uapply-list))
  
  uapply-a ;f = (closure env arglist . bodexprs)
  (zap ucdr f)
  (= env upop.f arg-names upop.f bodexprs f) ;d'oh, forgot "f"
  (save bodexprs)
  (call 'join-envs) ;returns its env in env
  (restore exprs)
  (jump 'uapply-loop)
  
  uapply-string
  (unless (and (a-uint ucar.xs)
               (no ucdr.xs))
    (err "Bad implicit string-ref:" f xs))
  (= return (ustring-ref f ucar.xs))
  (ret)
  
  uapply-list
  (unless (and (a-uint ucar.xs)
               (no ucdr.xs))
    (err "Bad implicit list-ref:" f xs))
  (= n ucar.xs xs f)
  (jump 'ulist-ref)
  )

;xs = (arglist . bodexprs)
;want to return ('closure env arglist bodexprs)
(ddef eval-fn (xs env) ;time to write it with conses
  (= x env y xs)
  (call 'ucons)
  (= x 'closure y return)
  (jump 'ucons))

;Aw m'gaw, I need to use uints not ints for qq, else it fucks with stack.
;I suppose I completely knew that.

(ddef ueval (x env)
  (if (and (isa x 'int) (is 0 (mod x 8)))
      (do (= return x) (ret))
      (isa x 'sym)
      (aif (uassoc x env)
           (do (= return ucadr.it) (ret))
           (global-value x)
           (do (= return (if (is it 'HELLA-NIL) 'nil it)) (ret))
           (err "ueval: Not defined:" x))
      (isa x 'char)
      (do (= return x) (ret))
      (a-ustring x)
      (do (= return x) (ret))
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
      (do (= x ucar.xs n 8) (jump 'eval-qq)) ;xs n env
      (is f 'arc)
      (do (= return (tu:eval ut:ucar.xs)) (ret)))
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
      (if (is n 8)
          (do (= x ucadr.x) (jump 'ueval))
          (jump 'eval-qq-b))
      
      (is ucar.x 'unquote-splicing)
      (if (is n 8)
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
  (= x ucadr.x n (+ n 8))
  (call 'eval-qq)
  (= n 2)
  (push 'quasiquote the-stack)
  (push return the-stack) ;oh man more rest args
  (call 'ulist)
  (ret) ;fuckin' rest args
  
  eval-qq-b
  (= x ucadr.x n (- n 8))
  (call 'eval-qq)
  (= n 2)
  (push 'unquote the-stack)
  (push return the-stack)
  (call 'ulist)
  (ret) ;jesus
  
  eval-qq-c
  (zap ucadr x)
  (-- n 8)
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
              (is n 8)
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
      ;(if (> int-len.x (- word-bits 3))
       ;   (err "Integer too large" x)
          (ash x 3)
        ;  )
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


(def usteps ()
  (* 8 step-counter))

(= global-value
   (obj + u-+ - u-- * u-* / u-/ expt u-expt
        cons ucons car ucar cdr ucdr is is < < > >
        scar uscar scdr uscdr uniq uniq
        apply uapply eval ueval apply-mac apply-mac nil 'HELLA-NIL
        acons a-ucons
        make-string umake-string string-length ustring-length
        string-ref ustring-ref string-set ustring-set
        steps usteps
        ))


(ddef string->ustring (x)
  (save x)
  (= n (* 8 len.x)) ;uint
  (call 'umake-string)
  (restore x)
  (forlen i x
    (mm-set (+ (- return type-tag!string) 24 (* i 8)) x.i))
  (ret))
(def ustring->string (xt)
  (let-untag x xt 'string
    (withs (ulen string-length.xt
            blen (mm:+ x 16))
      (let u (newstring string-length.xt)
        (for i 0 dec.blen
          (= u.i (mm:+ x 24 (* i 8))))
        (when (isnt ulen blen) ;ha, a different invariant!
          (let-untag y mm.x 'string
            (for i blen dec.ulen
              (= u.i (mm:+ y 24 (* i 8))))))
        u))))

(ddef tree->utree (x) ;still punts on cycles (I could do better pretty easily now)
  (if (isa x 'int)
      (zap [ash _ 3] x))
  (if (isa x 'string)
      (jump 'string->ustring))
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

(def utree->tree (x (o depth -1))
  (if (is depth 0)
      x
      a-ucons.x
      (cons (utree->tree ucar.x dec.depth)
            (utree->tree ucdr.x dec.depth))
      a-uint.x
      (ash x -3)
      a-ustring.x
      ustring->string.x
      x))

(def u-evaluate (x)
  (ueval x nil))
(def ue (x (o env nil))
  (ueval tu.x tu.env))

(= ut utree->tree
   tu tree->utree)


(def em ()
  (while t
    (pr "emiya> ")
    (= ass (read)
       ass tree->utree.ass
       ass u-evaluate.ass
       ass utree->tree.ass
       ass wrn.ass)))

(def mm-range (a b)
  (mapn [mm:ash _ 3] (ash a -3) (ash b -3)))
(def mms (a n)
  (mapn [mm:ash _ 3] (ash a -3) (+ (ash a -3) dec.n)))

(def h ()
  (ustep) (pprn car.the-pc) cdr.the-pc)

(initialize-butt)

(def uin-tospace (x)
  (and no:fromspace-pointer.x
       (if a-ucons.x
           (and (uin-tospace (ucar x t))
                (uin-tospace (ucdr x t)))
           a-ustring.x
           t
           t)))

(def fromspace-frontier (x)
  (if fromspace-pointer.x
      list.x
      (if a-ucons.x
          (join (fromspace-frontier:ucar x t)
                (fromspace-frontier:ucdr x t))
          nil)))


(= stdlib-list
   '((fn ()
       (= list (fn args args)
          no (fn (x) (is x 'nil))
          list* (fn args (if (no (cdr args))
                             (car args)
                             (cons (car args) (apply list* (cdr args)))))
          mac (mc (name args . body)
                  (list '= name (list* 'mc args body)))
          fifty (list 1 2 3 4)
          alph '(#\a #\b #\c #\d #\e))
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
                   (apply map f (map1 cdr xses)))))
       (def list-len (x)
         (if (no x) 0 (+ 1 (list-len (cdr x)))))
       (def str args
         (let u (make-string (list-len args))
           (xloop (args args i 0)
             (if (no args)
                 u
                 (do (string-set u i (car args))
                   (next (cdr args) (+ i 1)))))))
       (def nstring-copy (a astart b bstart n)
         (if (is n 0)
             nil
             (do (string-set a astart (string-ref b bstart))
               (nstring-copy a (+ astart 1) b (+ bstart 1) (- n 1)))))
       (def string-append2 (a b)
         (let u (make-string (+ (string-length a) (string-length b)))
           (nstring-copy a 0 u 0 (string-length a))
           (nstring-copy b 0 u (string-length a) (string-length b))
           u)))))

;(def memory-is-consistent ()
;  (let roots (join vals.global-value the-stack) ;also gc-next
;    (with (stack nil seen (table))
;      (

(def stdlib ()
  (no:ueval (tu stdlib-list)
            nil))

(def stdlib-setup ()
  (no:ueval-setup (tu stdlib-list)
                  nil))

(mac gv (x)
  `(global-value ,(if (and acons.x (is car.x 'quote))
                      x
                      (isa x 'sym)
                      `',x
                      x)))

(stdlib)