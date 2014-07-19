;Memory.
;Oh boy.
;Get ready.

(= memory-size (* 200 (expt 2 20)))
;just in case...
;do GC later.
;huehuehuehe.
;(even then I don't think it'll be able to get
; up to reexpansion)

(= the-memory (make-bytes memory-size)
   alloc-ptr 8) ;no 0 ptrs

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

(mac bake (x) `(eval ,x)) ;compile-time eval
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
     (fn . 64)
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

(= ssyntax? ssyntax)

;geez, a problem with ssyntax is that I want to use "sym?"
;when I actually mean "lexical or global variable reference?".
;this is one case where it'd be nice for ssyntax to
;get preexpanded.
;anyway: new approach to gensyms. unsafe w/ assignment and threads,
;but that won't be a problem here.
;I want the macro output to look good, so minimizing that crap.
(mac with-sym (x expr)
  (w/uniq (gy rebind)
    `(withs ,rebind (if (or (cons? ,x)
                            (and (sym? ,x)
                                 (ssyntax? ,x)))
                        (uniq))
       ((if ,rebind
            (fn (,gy) `(let ,,rebind ,,x ,,gy))
            idfn)
        (let ,x (or ,rebind ,x) ,expr)))))

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
        

;With no bounds-checking, there can be a uniform interface
;for getting the nth element of the le dick.
;Size...
;Ok, size is the rest argument.
;... On variable-length, only an "m" version defined here.
;The "u" will be generally special-cased for them.

(each (name . fields) struct-list
  (xloop (fs fields off (if user-type?name 8 0))
    (if cons?fs
        (let (fname . rest) fs
          (with base (symb name '- fname)
            offset (+ off (if user-type?name
                              (+ 8 -:type-num!user)
                              -:type-num.name))
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
        ;[hmmph, Arc even mishandles nested qq with ,@] [spec. ,@,]
        
        ;well, I can cheat with another macro
        ;... nah.
        ;ok, I went and fixed Arc. [fuckups]
        ;--hohoho, we must avoid colliding with Arc names or smthg
        (do (prsn name fs fields off)
          (let fields (map uniq:string fields)
            (eval
             (let assignments (map-index
                               (fn (expr n)
                                 ;want to create `(m+= ,var ,expr <n>)
                                 `(m+= ,(list 'unquote 'var)
                                       ,(+ (-:if user-type?name
                                                      type-num!user
                                                      type-num.name)
                                                (* n 8))
                                       ,expr))
                               (if user-type?name
                                   (cons type-num!user fields)
                                   fields))
               `(mac ,(symb 'w/m name) (var ,fields . body) ;hope no dups
                         `(let ,var (+ alloc-ptr ,,(if user-type?name
                                                       type-num!user
                                                       type-num.name))
                            (++ alloc-ptr ,,(+ off (if user-type?name 8 0)))
                            ,@,(list 'quasiquote assignments)
                            ,@body))))
            
            (eval (w/uniq g
                    `(def ,(symb 'm name) ,fields
                       (,(symb 'w/m name) ,g ,fields
                                          ,g)))))
          )
        (when int?fs
          (withs offset (+ off (if user-type?name
                                   -:type-num!user
                                   -:type-num.name))
            mref (case fs
                   64 'm
                   32 'm32
                   8 'm8)
            mset (symb (cut string.mref 0 1) '= (cut string.mref 1)) ;lel
            addr-expr `(+ ,',obj (+ ,(if (is fs 8)
                                         ',n
                                         `(* ,',n ,(/ fs 8)))
                                    ,offset))
            ref-body (list 'quasiquote
                       `(,mref ,addr-expr))
            set-body (list 'quasiquote
                       `(,mset ,addr-expr ,',val))
            (eval `(do
                     (mac ,(symb 'm name '-ref) (obj n)
                       ,ref-body)
                     (mac ,(symb 'm name '-set) (obj n val)
                       ,set-body)))
            
                              
            #;(eval `(do
                     (mac ,(symb 'm name '-ref) (obj n)
                         `(m+ ,obj (+ ,n ,,offset)))
                     (mac ,(symb 'm name '-set) (obj n val)
                       `(m+= ,obj (+ ,n ,,offset) ,val))
                     ;creating will be handled elsewhere
                     )))))))

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
   ucdr ucons-cdr)

(mac w/malloc (var n tag . body)
  `(let ,var (+ alloc-ptr ,tag)
     (++ alloc-ptr ,n)
     ,@body))

;var will be tagged with tag-name's thing
;this will be spliced into a body
(def maybe-tag (var tag-name)
  (if user-type?tag-name
      (list `(m+= ,var ,-:type-num!user
                  ,type-num.tag-name))
      nil))

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
           (-- ,gn 1))))))
(mac memset8 (addr n x)
  (w/uniq (gaddr gn)
    (with-sym x
      `(with ,gaddr ,addr ,gn ,n
         (while (> ,gn 0)
           (m= ,gaddr ,x)
           (++ ,gaddr 8)
           (-- ,gn 1))))))
(mac memset1 (addr n x)
  (w/uniq (gaddr gn)
    (with-sym x
      `(with ,gaddr ,addr ,gn ,n
         (while (> ,gn 0)
           (m=8 ,gaddr ,x)
           (++ ,gaddr 1)
           (-- ,gn 1))))))

;geez, I use it so much...
(def tag-field-size (s)
  (if user-type?s
      8
      0))

;c = an untagged ....... ?
;nah, c is tagged like a char.
;--and n?
;it probably makes little difference when we're compiling...
;therefore, let's have n be tagged too.
;[even though the memset shit ... assumes a raw integer]
;[... ok, fine, let's change that]
;(mac w/mstring (var n c . body)
;  (with-sym n
;    `(w/malloc ,var
;               (+ (* ,n 4)
;                  ,(if (user-type? 'string)
;                       16 ;len + user-tag
;                       8)) ;len
;               ,(if user-type?!string
;                    type-num!user
;                    type-num!string)
;       ,@(join (maybe-tag var 'string)
;               `(m+= ,var ,(
;               `(memset4 (- 
;               body))))

(def tag-bits (s) ;s = name of the type
  (if user-type?s
      type-num!user
      type-num.s))

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
               #;(+ (div ,n 2) ;must round up
                  ,(+ 8 tag-field-size!string))
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
                (div ,n 8)
                (div ,c 8)) ;the character
       ,@body)))

(def unewstring (n c)
  (type-ck n int
    (type-ck c char
      (w/mstring x n c x))))

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
                  (* 8 (mstring-ref ,s (div ,n 8))))))))))) ;lord have mercy on me

(mac ustring-set (s n c)
  (with-sym s
    (with-sym n
      (with-sym c
        `(type-ck ,s string
           (type-ck ,n int
             (type-ck ,c char
               (massert (and (>= ,n 0) (< ,n (mstring-len ,s)))
                 (mstring-set ,s (div ,n 8) (div ,c 8))))))))))

(def uchar (c)
  (+ type-num!char (* 8 $.char->integer.c))) ;used for type checking purp.
(def uint (n) (* n 8))

(def ustringify (s)
  (let u (unewstring uint:len.s (uchar #\nul))
    (forlen i s 
      ;prn.i
      (ustring-set u uint.i uchar:s.i))
    u))

;this shall have the char ...
;(mac w/mstring (var n c . body)
;  (with-sym n
;    (with-sym c
;      `(let ,var (+ alloc-ptr ,(if user-type?!string
;                                   type-num!user
;                                   type-num!string))
;         (++ alloc-ptr (+ (* ,n 4) ,(if user-type?!string
;                                        16   ;len + user-tag
;                                        8))) ;len
;         ,(w/uniq i
;            `(for ,i 0 (- ,n 1)
;               (m+= 
                  
(def mr (a b (o chunk 8)) ;wonderfully wasteful, debugging ftw
  (if (> a b)
      nil
      (cons (case chunk 8 m.a 4 m32.a 1 m8.a)
            (mr (+ a chunk) b chunk))))

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

;Initialization things...
;Initialize nil string and stuff.

(= unil-string (ustringify "nil")
   unil (msym unil-string unil-string))

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






