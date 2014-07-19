;Memory.
;Oh boy.
;Get ready.

;This iteration... need fake calls.

;Fake function calls.
;Let's see.
;I think I'll skip over the first 1024 bytes of memory, for
;debugging and maybe other reasons, then devote the addresses
;up until 16384 to machine code addresses, and then objects
;from there on.
;Code will have to reference some dicks like nil.
;Canonical.
;So those will be values marked as mutable, but still in
;the machine address range.
;E.g. there'll be a "ptr to nil" thing in the machine address
;range, which will contain the ptr to the nil object.
;The nil object will actually be in the 16K+ range.
;The "ptr to nil" thing must be moved at GC flip, before any
;work can be resumed.

(= memory-size (* 100 (expt 2 20)))
;just in case...
;do GC later.
;huehuehuehe.
;(even then I don't think it'll be able to get
; up to reexpansion)

(= the-memory (make-bytes memory-size)
   machine-code-alloc-ptr 1024
   alloc-ptr 16384)

;Due to the way macros work, it seems I shall have to define
;the macro things here, and then define the functions later.
;This is how it'll have to be in assembly, too.
;But I can define absolute primitives here...

;(= machine-code-pos (table)) ;symbol -> address ;lel, better name
(= address-to-function (table)
   label-to-address (table))

(def label->address (x)
  (or label-to-address.x
      (err "Not a known label" x)))
(def address->function (x)
  (or address-to-function.x (err "Not a known machine-code address" x)))

(def reserve-machine-code-address (s)
  (do1 (= label-to-address.s machine-code-alloc-ptr)
       (++ machine-code-alloc-ptr (rand 8 100))))

;^ soon we'll want that to align to multiples of 8, but needn't have
;it yet.

;Runtime.
;We will run "functions".
;(Might ]

;(def install-\"function\" ;lel
(def install-fn (s f)
  (= (address-to-function label->address.s) f))

;We'll need a "program counter".
;In the future might even want to go instruction by instruction or
;something, but probably not.
(= program-counter 'lolz)


;Actually not sure if we'll need that.
;Only needed for stepping purposes, ess. debugging.
;However.
;Will need to call things.

;There will be a couple of kinds of calls.
;Calls to other builtins, machine code known at compile time.
;Calls to bclos's, objects created at runtime (usually continuations).
;Calls to uclos's, created at runtime.
;Calls to strings and lists, at runtime.
;Now, the last two will be calls to builtins like "ucall".
;The first two must be done, though.
;--Oh, and, bclos's are called fns.

(= ssyntax? ssyntax)
;geez, a problem with ssyntax is that I want to use "sym?"
;when I actually mean "lexical or global variable reference?".
;this is one case where it'd be nice for ssyntax to
;get preexpanded.
;anyway: new approach to gensyms. unsafe w/ assignment and threads,
;but that won't be a problem here.
;I want the macro output to look good, so minimizing that crap.
(mac with-sym (x . body)
  (w/uniq (gy rebind)
    `(withs ,rebind (if (or (cons? ,x)
                            (and (sym? ,x)
                                 (ssyntax? ,x)))
                        (uniq))
       ((if ,rebind
            (fn (,gy) `(let ,,rebind ,,x ,,gy))
            idfn)
        (let ,x (or ,rebind ,x) ,@body)))))

(mac with-sym-list (xs . body)
  #;(if no.xs
      `(do ,@body)
      atom:car.xs
      `(with-syms ,cdr.xs ,@body)
      `(with-sym ,car.xs
         (with-syms ,cdr.xs ,@body)))
  #;(w/uniq (gxs gu)
    `(let ,gxs ,xs
       ((if (all atom ,gxs)
            idfn
            (fn (,gu) `(with 
            ()))))))
  (w/uniq (vars vals newxs expr)
  `(let (,vars ,vals ,newxs) (sym-bindings ,xs)
     ((if (no ,vars)
          idfn
          (fn (,expr) `(with ,(mappend list ,vars ,vals)
                         ,,expr)))
      (let ,xs (if (no ,vars) ,xs ,newxs)
        ,@body)))))

(def sym-bindings (xs)
  (xloop (xs xs ys nil vars nil vals nil)
    (if no.xs
        (list rev.vars rev.vals rev.ys)
        (if atom?car.xs
            (next cdr.xs (cons car.xs ys) vars vals)
            (let u (uniq)
              (next cdr.xs (cons u ys) (cons u vars) (cons car.xs vals)))))))

;b = probably a var, created at runtime
(mac call-fn (f . args)
  (with-sym f
    #;(unless (all atom args)
      ;That lets through ssyntax. K.
      ;[Though ssyntax gets expanded by ssx beforehand. Mmmph.]
      ;Ok, fine.
      (err "call-fn: Non-atomic arg" args))
    (with-sym-list args
      `((address->function (mfn-code ,f)) ,f ,@args))))
;let's see...
;hmm, it looks like, if I want code to actually refer to each other,
;I would have to construct some circular structures, which would
;be pretty diff .................. actually, I guess it wouldn't be.
;but.  machine code has addresses in it.  Therefore.
(mac call-code (lab . args)
  (aif label->address.lab
       (with-sym-list args
         `((address->function ,it) ,@args))
       (err "Oh god what label is this" lab)))
;^ Probably go for a two-pass thing later.



;The rnrs-bytevectors-6 crap provides (endianness big/little),
;but that probably means a runtime check of some sort.
;Fuck that.
;[Btw: signed 64-bit integers.]

;WTF, Racket doesn't err on misaligned shit.
;Fuck.
;.........
;Well, then.
(each n '(32 64)
  (withs align (/ n 8) mask (- align 1)
    (eval `($:begin
       (define (,(symb 'aligned- n '-ref) bv n)
         (if (zero? (bitwise-and n ,mask))
             (,(symb 'bytevector-s n '-native-ref) bv n)
             (error "Misaligned load:" n ,align)))
       (define (,(symb 'aligned- n '-set) bv n v)
         (if (zero? (bitwise-and n ,mask))
             (,(symb 'bytevector-s n "-native-set!") bv n v)
             (error "Misaligned store:" n ,align v))
         v)))))
($:define (8-set bv n v)
  (bytevector-s8-set! bv n v)
  v)
;might think about .......
;signed versus unsigned--fuck whatever, not actually using.

(mac m= (x v)   `(funcall $.aligned-64-set the-memory ,x ,v))
(mac m (x)      `(funcall $.aligned-64-ref the-memory ,x))
(mac m=8 (x v)  `(funcall $.8-set the-memory ,x ,v))
(mac m8 (x)     `(funcall $.bytevector-s8-ref the-memory ,x))
(mac m32 (x)    `(funcall $.aligned-32-ref the-memory ,x))
(mac m=32 (x v) `(funcall $.aligned-32-set the-memory ,x ,v))
;32-bit and 8-bit refs/sets are used for and only for:
;byte-strings and strings.

;(mac bake (x) `(eval ,x)) ;compile-time eval ;you're completely retarded
(mac bake (x)
  (let u (eval x)
    (if (or sym?u cons?u)
        (err "bake: I don't like symbols or conses" x u)
        u)))
(def m- (x n) (m:- x n))
(def m+ (x n) (m:+ x n))
(def m-= (x n v) (m= (- x n) v))
(def m+= (x n v) (m= (+ x n) v))

;General procedure:
;m[procedure] = unchecked
;u[procedure] = checked
;(barred will come later)
;(mac mcar (x) `(m- ,x (bake type-num!cons)))
;(mac mcar (x) `(m+ ,x (bake (- 8 type-num!cons))))
;(mac mscar (x v) `(m-= ,x bake:type-num!cons ,v))
;(mac mscdr (x v) `(m+= ,x (bake:- 8 type-num!cons) ,v))
;should be made redundant later

;ok, a vector is (how many times have I been through this?)
;...
;ok, atm, with no GC, it is vec=[len v0 ...].
;(and no attempts at fractionally moved vectors)
;note n will be a fake-Arc integer, so no need to shift.
(mac mvref (x n)
  `(m+ ,x (+ ,n (bake:- 8 type-num!vector))))
(mac mvset (x n v)
  `(m+= ,x (+ ,n (bake:- 8 type-num!vector)) ,v))

;oh boy... how about ev'thing that has a bunch of little
;fields?
;I guess I can have some kind of hash table that expands
;these things at compile-time.
;Can't say much about variable-length stuff, but the rest...
;Mmm... could have OFFp-like stuff... eh.
;Meanwhile, about the separation between base types and user
;types... that should be in a dick.



(= type-cat
   '((int char)
     (cons sym vector
      user fn string)
     (uclos umac dyn table bytes))
   struct-list 
   '((cons car cdr) ;must give syns to cons-car and cons-cdr
     (sym name value)
     (uclos env args body)
     (umac clos)
     (dyn id val)
     (table new old count) ;no lock for now
     ;int, char, fn, vector, string special-cased
     (string len . 32)
     (vector len . 64)
     (fn code . 64)
     (bytes len . 8)
     ))
;^ could combine into one taxonomy.
;just not sure if that'd make shit inflexible

(zaps randperm type-cat.1 type-cat.2) ;hohohoho

(def base-type? (x) (mem x (flat:take 2 type-cat))) ;lol money
(def user-type? (x) (mem x type-cat.2))
(def base-pointer-type? (x) (mem x type-cat.1))
(= type-nums (flat:take 2 type-cat))
(def type-num (x) (or (pos x type-nums) (pos x type-cat.2)))

(def tag-bits (s) ;s = name of the type
  (if user-type?s
      type-num!user
      type-num.s))
;is useful
(def tag-field-size (s)
  (if user-type?s
      8
      0))


(mac base-tag (x) `(bit-and ,x 7))
(mac muser-tag (x) `(m+ ,x ,-:type-num!user)) ;unchecked
(mac user-tag (x)
  (with-sym x
    `(if (is (base-tag ,x) ,type-num!user)
         (muser-tag ,x)
         (err "Not user-tagged:" ,x))))
;^ that shit would be inlined, and jumped away to a generic thing

;...
;must I do the new gensym approach always?
;feh, wtvr.
;--mmm, can be liberal in what we accept a bit.
(mac base-ck (x n (o then nil))
  (with-sym x
    `(if (is (base-tag ,x) ,(if sym?n 
                                (or type-num.n ;you fuckup, type-num!n again
                                    (err "Not a known type" n))
                                ;actually that makes error reporting worse,
                                ;oh well
                                n))
         ,then
         (err "Not base-tagged:" ,x))))
(mac user-ck (x n (o then nil))
  (with-sym x
     `(if (is (user-tag ,x) ,(if sym?n
                                 (or type-num.n
                                     (err "Not a known type" n))
                                 n))
          ,then
          (err "Not user-tagged:" ,x))))
(mac type-ck (x name (o then nil))
  (with-sym x
    `(,(if user-type?name 'user-ck 'base-ck) ,x ,name ,then)))


;The following will be extremely useful.
;I guess this is essentially Appel's RECORD
(mac w/struct (var tp words . body)
  (let dicks (if user-type?tp
                 (cons type-num.tp words)
                 words)
    (with-sym var
      `(w/malloc ,var
                 ,(* 8 len.dicks)
                 ,tag-bits.tp
         ,@(map-index
            (fn (expr n)
              `(m+= ,var ,(- (* 8 n) #;type-num.tp tag-bits.tp)
                    ,expr))
            dicks)
         ,@body))))

(mac w/malloc (var n tag . body)
  `(let ,var (+ alloc-ptr ,tag)
     (++ alloc-ptr ,n)
     ,@body))

;With no bounds-checking, there can be a uniform interface
;for getting the nth element of the le dick.
;Size...
;Ok, size is the rest argument.
;... On variable-length, only an "m" version defined here.
;The "u" will be generally special-cased for them.

;Debugging shit
(= brx-n 0
   brx-table (table))
(mac brx (expr)
  (let (name . rest) expr
    (let u ++.brx-n
      (= brx-table.u expr)
      `(do (prsn ',(symb name u) 'enter)
         (do1 ,expr
              (prsn ',(symb name u) 'ret))))))

(mac dbg (expr)
  (let (name . rest) expr
    (let u ++.brx-n
      (= brx-table.u expr)
      (with args (map [uniq] rest)
        gexpr (uniq)
        `(withs ,gexpr ,expr
           ,@(interleave args rest)
           (prsn ',(symb expr u) ,@args)
           (do1 (,gexpr ,@args)
                (prsn ',(symb expr u) 'ret)))))))

(each (name . fields) struct-list
  (xloop (fs fields off tag-field-size.name)
    (if cons?fs
        (let (fname . rest) fs
          (with base (symb name '- fname)
            offset (+ off -:tag-bits.name)
            (eval `(do
                     (mac ,(symb 'm base) (obj)
                       `(m+ ,obj ,,offset))
                     (mac ,(symb 'u base) (obj)
                       (with-sym obj
                         `(type-ck ,obj ,,type-num.name
                            (,',(symb 'm base) ,obj))))
                     (mac ,(symb 'sm base) (obj val)
                       (with-sym obj
                         `(m+= ,obj ,,offset ,val)))
                     (mac ,(symb 'us base) (obj val)
                       (with-sym obj
                         `(type-ck ,obj ,,type-num.name
                            (,',(symb 'sm base) ,obj ,val))))))
            (next cdr.fs (+ off 8))))
        no?fs
        ;nil ;actually might make a thing
        ;oh boy, close to cps [mebbe user can generate this shit]
        ;.............. I think nested quasiquotes may have the
        ;wrong choice of semantics, or else be the wrong thing...

        ;--hohoho, we must avoid colliding with Arc names or smthg
        (do ;(prsn name fs fields off)
          (let fields (map uniq:string fields)
            (eval
             (let bd (list 'quasiquote
                      `(w/struct ,',var ,name ,(map [list 'unquote _] fields)
                                 ,',@body))
               `(mac ,(symb 'w/m name) (var ,fields . body) ;hope no dups
                  (if (no:in nil ,@fields)
                      ,bd
                      (err "Bad constructor arguments"
                           ',name ,@fields)))))
            ;sigh, the above doesn't catch a wrong number of field arguments.
            ;that be a problem with Arc...
            ;..........
            ;actually, that appears to be described, perhaps as a feature.
            ;welp.
            (eval (w/uniq g
                    `(def ,(symb 'm name) ,fields
                       (,(symb 'w/m name) ,g ,fields
                                          ,g))))))
        (when int?fs
          ;prn.fs
          (withs offset (+ off -:tag-bits.name)
            mref (case fs
                   64 'm
                   32 'm32
                   8 'm8)
            mset (symb (cut string.mref 0 1) '= (cut string.mref 1)) ;lel
            addr-expr `(+ ,',obj (+ #;,(if (is fs 8)
                                         ',n
                                         `(* ,',n ,(/ fs 8)))
                                    ,(if (is fs 64)
                                         ',n
                                         `(/ ,',n ,(/ 64 fs)))
                                    ,offset))
            ref-body (list 'quasiquote
                       `(,mref ,addr-expr))
            set-body (list 'quasiquote
                       `(,mset ,addr-expr ,',val))
            (eval `(do
                     (mac ,(symb 'm name '-ref) (obj n)
                       ,ref-body)
                     (mac ,(symb 'm name '-set) (obj n val)
                       ,set-body))))))))

;Now, u{vector,fn,string,bytes?}-ref need to be
;implemented. Should they possibly be functions rather than
;macros? ... They should probably have some of the unusual-case
;work go and call a function.
;[Also no read barriers in the above.]

(mac massert (test expr)
  `(if ,test
       ,expr
       (err "Assertion failed:" ',test)))

(mac uvector-ref (obj n)
  (with-sym obj
    (with-sym n
      (w/uniq glen
        `(type-ck ,obj vector
           (let ,glen (mvector-len ,obj)
             (massert (and (>= ,n 0) (< ,n ,glen))
               (mvector-ref ,obj ,n))))))))

(= mcar mcons-car
   mcdr mcons-cdr
   ucar ucons-car
   ucdr ucons-cdr
   smcar smcons-car
   smcdr smcons-cdr)



;var will be tagged with tag-name's thing
;this will be spliced into a body
(def maybe-tag (var tag-name)
  (if user-type?tag-name
      (list `(m+= ,var ,-:type-num!user
                  ,type-num.tag-name))
      nil))

;Ok, so, general purpose.
;For "w/memory" or other shit that happens at compile time,
;it doesn't seem like a serious purpose is served by having the
;integers be smaller.
;Meanwhile, anything called at runtime will almost certainly use
;tagged uints.
;So.
;It shall all use uints.

;I want to write "memset", but it's not bytes I want...
;right, then, versions of memset
;......
;ok, fairly raw ones
;[btw there are x86 dicks for this shit]
;ok, not that raw, n is n*8 [i.e. tagged]
;actually, nah, n is n [not tagged]
(mac memset4 (addr n x)
  (w/uniq (gaddr gn)
    (with-sym x
      `(with ,gaddr ,addr ,gn ,n
         (while (> ,gn 0)
           (m=32 ,gaddr ,x)
           (++ ,gaddr 4)
           (-- ,gn 8))))))
(mac memset8 (addr n x)
  (w/uniq (gaddr gn)
    (with-sym x
      `(with ,gaddr ,addr ,gn ,n
         (while (> ,gn 0)
           (m= ,gaddr ,x)
           (++ ,gaddr 8)
           (-- ,gn 8))))))
(mac memset1 (addr n x)
  (w/uniq (gaddr gn)
    (with-sym x
      `(with ,gaddr ,addr ,gn ,n
         (while (> ,gn 0)
           (m=8 ,gaddr ,x)
           (++ ,gaddr 1)
           (-- ,gn 8))))))


;mallocs are all to a multiple of 8.
;thus...
;eh, there are only a couple of things that alloc non-mults of 8.
;so I think I can do the rounding there.
;--how about the halfword of padding that will thus be
;sometimes created?  zero it, clobber it, or what?
;I guess actually I could take the opportunity to set shit using
;memset8, making "c OR (c SHL 32)".
;but meh for now.
;[also it'd be possible to store the chars in tagged form in the
; string, but neh; would interfere with C compatibility a bit more]

(mac w/mstring (var n c . body)
  (with-sym n
    `(w/malloc ,var
               (bit-and -8
                        (+ (div ,n 2) ;must round up
                           ,(+ 7 (+ 8 tag-field-size!string))))
               ,tag-bits!string
       ,@(maybe-tag var 'string)
       ;len field [tagged I guess]
       (m+= ,var ,(+ tag-field-size!string
                     -:tag-bits!string)
            ,n)
       ;contents
       (memset4 (+ ,var
                   ,(+ -:tag-bits!string
                       tag-field-size!string
                       8))
                ,n
                (div ,c 8)) ;the character
       ,@body)))

;atm: vector=[len . elts]
;... for convenience for me, imma require the initial value
;to be an integer or smthg
(mac w/mvector (var n v . body)
  (with-sym n
    `(w/malloc ,var
               (+ ,n
                  ,(+ 8 tag-field-size!vector))
               ,tag-bits!vector
       ,@(maybe-tag var 'vector)
       (m+= ,var ,(+ tag-field-size!vector
                     -:tag-bits!vector)
            ,n)
       (memset8 (+ ,var
                   ,(+ -:tag-bits!vector
                       tag-field-size!vector
                       8))
                ,n
                ,v)
       ,@body)))                
               

(def unewstring (n c)
  (type-ck n int
    (type-ck c char
      (w/mstring x n c x))))

;we probably assume fns are not .......
;do we?
;geh.
;ok, we don't.


(mac w/mfn (var f saved . body)
  `(w/struct ,var fn (,(label->address f) ,@saved) ,@body))
(= w/fn w/mfn)
;"It seemed to us a bad idea to have a feature so fragile
; that its own implementors couldn't use it properly."


;I must now face the ugly reality that mstring-ref actually yields
;unboxed characters. sigh, sigh, all sigh.
;..... oh god, would I need to untag n so mstring-ref can retag it?
;idiot.
;that's going a bit too far.  inlining.
;... wait, never mind, can't be bothered to know how many fields
;between the head of the string and index 0.

;actually, I fucked up mstring-ref and mstring-set anyway,
;due to the alignment...
;at least *that* can be fixed.
;[also that's fucked up because I also forgot the offset due to fields]

(mac ustring-ref (s n)
  (with-sym s
    (with-sym n
      `(type-ck ,s string
         (type-ck ,n int
           (massert (>= ,n 0)
             (massert (< ,n (mstring-len ,s))
               (+ ,tag-bits!char
                  ;(* 8 (mstring-ref ,s (div ,n 8))))))))))) ;lord have mercy on me
                  (* 8 (mstring-ref ,s ,n)))))))))) ;lord have mercy on me


(mac ustring-set (s n c)
  (with-sym s
    (with-sym n
      (with-sym c
        `(type-ck ,s string
           (type-ck ,n int
             (type-ck ,c char
               (massert (and (>= ,n 0) (< ,n (mstring-len ,s)))
                 (mstring-set ,s ,n (div ,c 8))))))))))

(def uchar (c)
  (+ type-num!char (* 8 $.char->integer.c))) ;used for type checking purp.
(def uint (n) (* n 8))

(def ustringify (s)
  (let u (unewstring uint:len.s (uchar #\nul))
    (forlen i s 
      ;prn.i
      (ustring-set u uint.i uchar:s.i))
    u))

#;(def mr (a ln (o chunk 8)) ;wonderfully wasteful, debugging ftw
  (zap [bit-and _ -8] a)
  (xloop (a a ln ln)
    (if (< ln 0)
        nil
        (cons (case chunk 8 m.a 4 m32.a 1 m8.a)
              (next (+ a chunk) (- ln chunk))))))

(def mr (a words (o wordsize 8)) ;wonderfully wasteful, debugging ftw ;convenienter
  (zap [bit-and _ -8] a)
  (xloop (a a words words)
    (if (<= words 0)
        nil
        (cons (case wordsize 8 m.a 4 m32.a 1 m8.a)
              (next (+ a wordsize) (- words 1))))))



;so, for now, we'll reserve addresses in advance.
;later, I should have a thing that ...
;Collects the definitions of the machine code craps,
;where the unlabeled things have a side-effect as their
;macex thing to add it to a list of "pls define me",
;then assign addresses to each label, then rerun all
;the definitions.
;[Things that define objects ............
; Those can go at the back or something. I dunno.]

(map reserve-machine-code-address
     '(fib
       fib-a
       fib-b
       print-me
       
       fib-thing
       fib-thing2
       fib-thing3
       
       ureduce-thing
       ureduce-thing2
       ureduce-thing3
       
       plus2-thing
       jump-table-unknown
       
       mtable-insert-new
       mtable-insert-old
       mtable-insert
       mtable-insert-new-search
       mtable-work
       mtable-work-loop
       mtable-incr-count
       mtable-delete-new
       mtable-decr-count
       mtable-try-delete-vec
       mtable-delete
       mtable-delete-vec-list
       mtable-try-delete-vec-list
       mtable-ref-new
       mtable-ref-search
       mtable-ref
       mtable-ref-search-loop
       
       ))

(mac def-code (name args . body)
  `(do (def ,name ,args ,@body)
     (install-fn ',name ,name)))

(def uiso (a b)
  (if (is a b)
      t
      (isnt base-tag.a base-tag.b)
      nil
      (uiso-dispatch a b)))

#;(mac def-dispatch (name args val . cases)
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

;The above must now be translated into a jump table in machine-code
;address space.
;Sheeeeeit.
;Right, then...

;Right, so, we need a label for each thing-to-jump-to.
;In that case, we need a thing that calls things other than
;labels known at compile-time.
;We also need to decide on the sizes of the jump tables. 256?
;That amounts to 4K per jump table.
;........
;Whatever, have it be a fucking constant.

(= USER-TAG-LIMIT 64) ;that'll be the size of the table things
;I could enforce that with a BIT-AND of the index and 63.
;Eh.
;[Then there's also the question of whether the user-types are
; tagged ints or not.  I guess that's currently "not".]

;There's an issue of alignment.
;Will do it here.

;This is used by the gods who can do what they like at compile time.
;......
;I guess I need a name, too.
(def fake-uvector (name . args)
  (zap [bit-and -8 (+ _ 7)] machine-code-alloc-ptr)
  (let u machine-code-alloc-ptr
    (= label-to-address.name u)
    (++ machine-code-alloc-ptr (* 8 len.args))
    (on x args (m+= u (* index 8) x))
    ;(when bound.name (warn "Redefining" name))
    (= symbol-value.name u)
    u))
;Note that these lack a length field, and so aren't real uvectors.
(def fake-make-uvector (name n init)
  (zap [bit-and -8 (+ _ 7)] machine-code-alloc-ptr)
  (let u machine-code-alloc-ptr
    (= label-to-address.name u)
    (++ machine-code-alloc-ptr (* 8 n))
    (for i 0 n (m+= u (* i 8) init))
    ;(when bound.name (warn "Redefining" name))
    (= symbol-value.name u)
    u))

(def-code jump-table-unknown args
  (err "jump-table-unknown: Called." args))

;lol I'm pretty good
;[was thinking of how to do this, looked back at what I did,
; and found that I just created two vectors full of the default
; case and then updated them]
(mac def-dispatch (name args val . cases)
  (withs base-vec (symb name '-base-table)
    user-vec (symb name '-user-table)
    `(do
       (fake-make-uvector ',base-vec 8 label->address!jump-table-unknown)
       (fake-make-uvector ',user-vec USER-TAG-LIMIT
                          label->address!jump-table-unknown)
       ,@(mappend (fn ((tp bd))
                    (let casename (symb name '-dispatch- tp)
                      `((reserve-machine-code-address ',casename)
                        (def ,casename ,args ,bd)
                        (= (address-to-function
                            (label->address ',casename))
                           ,casename))))
                  (tuples 2 cases))
       (each (tp bd) ',(tuples 2 cases)
         (m+= (if user-type?tp
                  ,user-vec
                  ,base-vec)
              (* 8 type-num.tp)
              (label->address (symb ',name '-dispatch- tp))))
       (map reserve-machine-code-address
            '(,(symb name '-dispatch)
              ,(symb name '-user-dispatch)))
            
       (eval
        '(def-code ,(symb name '-dispatch) ,args
           (call-unknown (m+ (bake:label->address ',base-vec)
                             (* 8 (base-tag ,val)))
                         ,@args)))
       (eval
        '(def-code ,(symb name '-user-dispatch) ,args
           (call-unknown (m+ (bake:label->address ',user-vec)
                             (* 8 (user-tag ,',val)))
                         ,@args))))))

;there should be room for a default case
;esp. default for user shit [useful for hash, anyway]

(mac call-unknown (addr . args)
  `((address->function ,addr) ,@args))

                                  

(def-dispatch uiso (a b) a
  cons (and (uiso mcar.a mcar.b)
            (uiso mcdr.a mcdr.b))
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

(def-dispatch lel (x) x
  cons 1
  int 2
  uclos 3
  fn 4
  sym 5
  vector 6
  string 7
  umac 8
  char 9)

;All right, now for a half-serious function.
;It'll suck on closures for now.

(def uhash (x)
  (hash-d x 5))

(def hash-d (x n)
  (if (is n 0) ;prob. not the most efficient but wtvr
      23
      (hash-dispatch x n)))

(def hash-combine (x y)
  ;(+ x y)) ;lelelelelel
  ;actually, I want to guarantee a 64-bit integer result
  ;that is a multiple of 8.
  ;the args will be those things, so I just need to mod out.
  ;[this would be one ADD instr., not that I'd use it]
  (bit-and (+ x y) 64b-mask))

(= 64b-mask (- (expt 2 64) 1))


;Let's see.
;Do I return a tagged int, or not?
;Sure.
;Slightly more convenient for a couple of purposes.
(def-dispatch hash (x n) x
  int x ;har
  char (ash x 3) ;har
  cons (hash-combine (hash-d mcar.x dec.n)
                     (hash-d mcdr.x dec.n))
  sym (hash-d msym-name.x dec.n) ;could cache the hash in a sym field
  vector (hash-d mvector-len.x dec.n) ;lel
  fn 72 ;nerf; do better next time
  string (xloop (i 0 tt 80) ;eval-poly-mod
           (if (< i mstring-len.x)
               (next inc.i (mod (+ (* tt 48723)
                                   (bit-and (mstring-ref x i)
                                            -8))
                                49389480)) ;a multiple of 8
               tt))
  uclos (hash-combine (hash-d muclos-env.x dec.n)
                      (hash-d muclos-body.x dec.n))
  umac (hash-d mumac-clos.x dec.n)
  dyn (hash-d mdyn-id.x dec.n)
  table 80 ;oh boy
  bytes (hash-d mbytes-len.x dec.n)
  )
;Probably should have default case, as probably mentioned earlier.
;Oh well.
;Btw, the above actually generates no garbage in Racket.
;Bretty good.

;And now..........
;Hash tables themselves?
;Or shall I postpone that until I'm doing GC?
;Eh, they'd be good.

;... I currently find "def-code" and stuff a bit confusing...
;Create executable code, with an Arc name, give it an "address",
;and give the "address" a "label".
;Right.

;Going for it.
;... Now do I make this a def, or a def-code, or a macro, or what?
;Whatever.
;Actually it'd probably make sense to ........
;...
;At least the majority of it should not be inlined.
;

;...
;oh man.
;OH man.
;Passing byte-arrays into assembly functions is easy.
;Thus, I could actually progressively rewrite this shit in assembly.
;Mostly.
;Welp, maybe later.

;Single-threaded, as before.

;Oh, boy, time to think like a compiler.
(def-code mtable-insert (b k v)
  (withs h (uhash k) ;could make that call-code
    old mtable-old.b
    (if (is old 0)
        (call-code mtable-insert-new b k v h)
        ;must not allocate a closure
        (withs index (bit-and (- mvector-len.old 16) h)
          xs (mvector-ref old index)
          (call-code mtable-insert-old b k v h xs)))))

(def-code mtable-insert-old (b k v h xs)
  (if (is xs 0)
      (call-code mtable-insert-new b k v h)
      (let u mcar.xs
        (if (uiso k mcar.u) ;and how "nice" is that procedure? oh well
            (smcdr u v)
            (let rest mcdr.xs
              (call-code mtable-insert-old b k v h rest))))))

(def-code mtable-insert-new (b k v h)
  (withs new mtable-new.b
    n (bit-and (- mvector-len.new 16) h)
    xs (mvector-ref new n)
    ;search for (k . anyth) in slot, then mebbe make new
    (call-code mtable-insert-new-search
               b k v new n xs)))
;oh boy, lots of registers to save

;Must remember to use uints.

(def-code mtable-insert-new-search (b k v new n xs)
  (if (is xs 0)
      (let slot (mvector-ref new n)
        (w/mcons x (k v)
          (w/mcons ys (x slot)
            (mvector-set new n ys)
            (call-code mtable-incr-count b)
            ;must return the right value
            v)))
      (let u mcar.xs
        (if (uiso k mcar.u)
            (smcdr u v)
            (let rest mcdr.xs
              (call-code mtable-insert-new-search
                         b k v new n rest))))))

;doesn't return anything interesting
(def-code mtable-incr-count (b)
  (let u (+ 8 mtable-count.b)
    (smtable-count b u)
    (withs old mtable-old.b
      new mtable-new.b
      n (- mvector-len.new 8)
      (if (is old 0)
          (when (> u n)
            ;in mult., use locks for resizing
            (smtable-old b new)
            (let new-size (+ 8 (* n 2))
              (w/mvector new-new new-size 0
                (smtable-new b new-new))))
          (call-code mtable-work b)))))

(def-code mtable-work (b)
  (with old mtable-old.b
    new mtable-new.b
    ;move shit
    ;if vec. is e.g. size 256, then vec[256] = work ptr
    ;and the vector-len is 257
    (if (is old 0) ;shouldn't happen in normal use w/o multithreading
        (err "mtable-work called with no work to do on" b)
        (withs h (- mvector-len.old 8)
          wp (mvector-ref old h)
          (call-code mtable-work-loop
                     wp h
                     old new
                     b 2)))))
;the workn is the only non-u int.

;could divide the work up slightly more intelligently,
;having wp incrementation count as work.  but.
;if that's screwed up, hash tables are probably not O(1) anyway.
(def-code mtable-work-loop (wp h old new b workn)
  (if (is wp h)
      (smtable-old b 0) ;would CAS
      (let xs (mvector-ref old wp)
        (if (is xs 0)
            (let u (+ wp 8)
              (call-code mtable-work-loop u h old new b workn))
            (withs kv mcar.xs
              rest mcdr.xs
              k mcar.kv
              hsh uhash.k
              ind (bit-and hsh (- mvector-len.new 16))
              slot (mvector-ref new ind)
              (w/mcons new-slot (kv slot)
                (mvector-set new ind new-slot)
                (mvector-set old wp rest)
                ;both of those would be cmpxchg...
                ;um... and they'd have to search "slot".
                ;actually in n-threaded you'd want semi-random
                ;work, probably.
                (when (> workn 1)
                  (let u dec.workn
                    (call-code mtable-work-loop wp h old new b u)))))))))

;note single-threaded, see comm. in dyn-cont14
;...
;returns t or nil depending on whether it finds dick
;... should I use subroutines?
;mmmaybe.

(def-code mtable-delete (b k)
  (withs h uhash.k
    old mtable-old.b
    new mtable-new.b
    (if (is old 0)
        (call-code mtable-delete-new b k h new)
        (withs n (bit-and h (- mvector-len.old 16))
          ;I can use a subroutine
          res (call-code mtable-try-delete-vec k old n)
          (if (is res 0)
              ;failed, must look in new
              (call-code mtable-delete-new b k h new)
              (call-code mtable-decr-count b))))))

;Actually, it's easier now to remove destructively.
(def-code mtable-try-delete-vec (k vec n)
  (withs xs (mvector-ref vec n)
    (if (is xs 0)
        0
        (withs kv mcar.xs
          rest mcdr.xs
          x mcar.kv
          (if (uiso k x)
              ;would cmpxchg in mult.
              (do (mvector-set vec n rest)
                8) ;"1" used as true for internal thing
              (call-code mtable-delete-vec-list k xs rest))))))

;would need vec and n for retrying in mult.
;or, actually, it could return a "retry" value.
(def-code mtable-try-delete-vec-list (k prev xs)
  (if (is xs 0)
      0
      (withs kv mcar.xs
        rest mcdr.xs
        x car.kv
        (if (uiso k x)
            (do (smcdr prev rest)
              8)
            (call-code mtable-try-delete-vec-list
                       k xs rest)))))

(def-code mtable-delete-new (b k h new)
  (withs n (bit-and h (- mvector-len.new 16))
    res (call-code mtable-try-delete-vec k new n)
    (if (is res 0)
        unil
        (call-code mtable-decr-count b))))

;must return true to indicate success
(def-code mtable-decr-count (b)
  (withs old mtable-old.b
    new mtable-new.b
    u (- mtable-count.b 8)
    (smtable-count b u) ;CAS, as always; also would reorder above
    (if (is old 0)
        ;maybe shrink table
        (let n mvector-len.new
          (when (< (max u 32) (ash n -2))
            ;ar-bitrary, be more sensical later
            (w/mvector new-new (+ 8 (ash n -1)) 0
              (smtable-old b new)
              (smtable-new b new-new))))
        (call-code mtable-work b))
    ut))

(def utable ()
  (w/mvector new 40 0 ;32 as in uint.4 ;you fuckup, need uint.5
    (mtable new 0 0)))

;Lelz, last to care about.
(def-code mtable-ref (b k fail)
  (withs h uhash.k
    old mtable-old.b
    new mtable-new.b
    (if (is old 0)
        (call-code mtable-ref-new b k h new fail)
        (withs 
          res (call-code mtable-ref-search k h old)
          (if (is res 0)
              (call-code mtable-ref-new b k h new fail)
              mcdr.res)))))

(def-code mtable-ref-new (b k h new fail)
  (let res (call-code mtable-ref-search k h new)
    (if (is res 0)
        fail ;in mult., would recheck b for movement
        mcdr.res)))

(def-code mtable-ref-search (k h vec)
  (withs n (- mvector-len.vec 16)
    ind (bit-and n h)
    xs (mvector-ref vec ind)
    (call-code mtable-ref-search-loop k h xs)))
;mmm, similar code written a bunch of times...
;not exactly sure how to make strict improvements, though
(def-code mtable-ref-search-loop (k h xs)
  (if (is xs 0)
      0
      (withs kv mcar.xs
        rest mcdr.xs
        x mcar.kv
        (if (uiso k x)
            kv
            (call-code mtable-ref-search-loop k h rest)))))        

;Finally looked inside racket for what they do.
;scheme_make_pair or something eventually traces back
;to gc2/newgc.c.
;This is written as a C function, a subroutine.
;So, indeed, it tries to alloc, checks if a GC flip or eqv
;is needed, and if so, puts its arguments in a "gc park",
;then retrieves them and appears to move them or something.
;[Actually, retrieves them and zeroes where they came from.
; Makes sense.  They should have gotten moved.]
;Now, the question is.
;This is a subroutine.
;What about its callers?
;Is it assumed that any local variables of theirs get put
;on the stack?
;Do they do checking?  Is that visible in the code?
;Does their GC scheme work so that they don't have to do that?
;Let's see.

;Interesting.
;They also appear to use a stack of object corpses as a
;GC work list...

;I am puzzled.
;I cannot find a definition of GC_fixup2_variable_stack ...
;I see, they #define GC_X_variable_stack to be it, and then
;give a function definition for GC_X_variable_stack.
;Sneaky.
;[I used iosnoop while running Racket to find the dylib it was
; using, and verified that such a function was defined.]
;Actually, they use it to generate two mostly-similar blocks of code.


;Time for a version bump.  Next will have symbols in a table.




;The set of code is ...
;Imagine some assembly where you do x, do y, do z, then
;maybe jump back to where you're about to do y.
;Let's suppose that doing z involves putting a useful pointer
;into a register that is initially garbage.
;And that pointer may be used in the future, possibly depending
;on complicated runtime information.
;But suppose that, at time of GC flip, it is impossible to
;deduce whether that register contains garbage or whether a
;pointer might have been put into it.
;(You could, for example, be faithfully following instructions
; that are encrypted and not fully sent...)
;(But a mundane example of iterating through a list would also
; work.)
;Anyway, that could basically be determined illegal, if it is
;known that an interrupt or its eqv may happen at that point.


(def-code print-me (self x)
  prn.x)

(def-code fib-thing (k n)
  ;(prsn 'fib-thing k n)
  (if (or (is n 0) (is n 8)) ;oh man tagged
      (call-fn k n)
      (w/mfn k1 fib-thing2 (n k)
        (let dick (- n 16)
          ;(prsn 'ft 'calling k1 dick)
          (call-code fib-thing k1 dick)))))

(def-code fib-thing2 (self x)
  ;(prsn 'fib-thing2 self x)
  (with n (mfn-ref self 0)
        k (mfn-ref self 1)
    (w/mfn k1 fib-thing3 (x k)
      (let dick (- n 8)
        ;(prsn 'ft2 'calling k1 dick)
        (call-code fib-thing k1 dick)))))

(def-code fib-thing3 (self x)
  ;(prsn 'fib-thing3 self x)
  (with y (mfn-ref self 0)
        k (mfn-ref self 1)
    (let dick (+ x y)
      ;(prsn 'ft3 'calling-fn k dick)
      (call-fn k dick))))

(def-code plus2-thing (self k x y)
  (call-fn k (+ x y)))

;Initialization things...
;Initialize nil string and stuff.

(= unil-string (ustringify "nil")
   unil (msym unil-string unil-string)
   ut-string (ustringify "t")
   ut (msym ut-string ut-string))

;Some closures must appear.
(= print-me-closure
   (w/mfn x print-me nil x))

(= plus-closure (w/fn x plus2-thing nil x))

;[Problem that I'm using "u" and "m"?  Actually a problem with msym,
; whose name should be a string.]

;Example programs...
(def uno (x) (is x unil))

(def urev (xs)
  (uflip xs unil))
(def uflip (xs ys)
  (if uno.xs ys
      (uflip ucdr.xs (mcons ucar.xs ys))))

(def ulist args
  (if no.args
      unil
      (mcons car.args (apply ulist cdr.args))))

(def urange (a b)
  (if (> a b)
      unil
      (mcons a (urange (+ a 8) b))))

;now a CPS thing...
;I am unfortunately forced to confront something annoying.
;Each iteration, during which you call f, must create a
;continuation, at least in the fully general case.
;Which means certainly in the interpreter case.
;(def ureduce (f xs)
;  (if uno.xs
;      (call-fn 

;Sigh, oh well.

;Given that I'm doing it that way.
;Ok, there are two ways to do this.
;Putting f and k in a deeper thing or not.
;Doing so allows less mallocing, at the cost of some indirection.
;[This is the question of making "flat closures" or not.]
(def-code ureduce-thing (k f xs)
  (if uno.xs
      (call-fn f k)
      (call-code ureduce-thing2 k f ucar.xs ucdr.xs)))

(def-code ureduce-thing2 (k f x xs)
  (if uno.xs
      (call-fn k x)
      (w/fn k2 ureduce-thing3 (k f ucdr.xs)
        (call-fn f k2 x ucar.xs))))

(def-code ureduce-thing3 (self x)
  (call-code ureduce-thing2
             (mfn-ref self 0)
             (mfn-ref self 8) ;updating how "-ref" things work... not sure if good idea
             x
             (mfn-ref self 16)))

(when (> machine-code-alloc-ptr alloc-ptr)
  (err "Too much machine code, you fuck"))


(def usym->sym (x)
  (symb:ustring->string usym-name.x))
(def ustring->string (x)
  (string:mapn [uchar->char:ustring-ref x (* _ 8)]
               0 (dec:ash ustring-len.x -3)))

(def uchar->char (x)
  (type-ck x char (char:div x 8)))

(def make-hollow (u)
  (make-hollow-dispatch u))

(mac d (x) (no:dpprn definitions*.x))

;atoms are handled immediately
;you want a pointer to the thing, so that the thing
;can later be filled in without changing the pointers to it.
;...
;Actually, no, atoms must not be handled immediately.
;Keeping some aspects of it simple.
;A hollow cons might be (8 . 16785), and the 8 will
;get turned into a 1 by filling in, and the 16785 will get
;turned into whatever it points to (corresponds to).

;Goddammit, this doesn't work.
;....
;Ok, just because you leave 8 in the hollow cons doesn't mean you
;don't put the right dick in the table.
(def-dispatch make-hollow (u) u
  cons (cons mcar.u mcdr.u)
  int (/ u 8)
  char (char:div u 8)
  sym usym->sym.u)

(def contents (u) contents-dispatch.u)
(def-dispatch contents (u) u
  cons (list mcar.u mcdr.u)
  int nil
  char nil
  sym nil)

(def fill-in (h id->h)
  (case type.h
    cons (zaps id->h car.h cdr.h)
    int nil
    char nil
    sym nil))

;Ok, strategy...
;First, trace graph, find all objects, make hollow versions of them.
;Second, fill up the hollow versions.
;...
;I really don't need to generate new names, because I already get
;fed integers, bit-patterns, that are unique.
(def deuify (x)
  (withs worklist list.x
    id->h (table)
    seen (table)
    (= seen.x t)
    (while worklist
      (let x pop.worklist
        ;x is already seen
        (= id->h.x make-hollow.x)
        (each y contents.x
          (unless seen.y
            (= seen.y t)
            (push y worklist)))))
    (each (x h) id->h
      (fill-in h id->h))
    id->h.x))

;Here, we will be lazier.
;... The below will fuck things up with GC; a new set of roots.
;Meh.
;Can later write a thing 
(= sym->usym-table (table)
   sym->usym-table.nil unil)
;Oh, dear, do I have an "undefined" value?
;Meh.
(= undefined (ustringify "UNDEFINED"))
(def sym->usym (x)
  (or sym->usym-table.x
      (= sym->usym-table.x
         (let u ustringify:string.x
           (w/msym h (u undefined)
             h)))))

(def uify (x)
  (case type.x
    int uint.x
    char uchar.x
    sym sym->usym.x
    cons (mcons uify:car.x uify:cdr.x)
    (err "uify: Fuck, what type is this" type.x)))

(def show-table (b)
  (prsn b (mr b 5))
  (with new mtable-new.b old mtable-old.b
    (prsn new (mr new inc:deuify:mvector-len.new))
    (unless (is 0 old)
      (prsn old (mr old inc:deuify:mvector-len.old))))
  nil)
  
            

