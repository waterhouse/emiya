;Closures: (list 'closure <closure-fn> <env>)
;closure-fn: (fn (ev k . args) ...)
;env: (list (list 'name val) ...)
;Usually, closure-fn:
;(fn (ev k . args)
;  (eval '(body) (new-env '(env) args arglist) k))
;However, call-cc's fn will be:
;(fn (ev k f)
;  (f k))
;Normally, k is a cont-closure.
;cont-closure: (list 'closure (fn (ev v) ...))


;Now that stuff works... things I can do.
;0. Example with amb. Pure user code. Meh.
;1. Threads, faked by screwing with ccall or smthg to sometimes
;   save the closure and call something else for a while. Screw
;   that for the moment.
;2. Serializing everything. [done, maybe want cleanup]

;Btw, "alist" should be renamed, perhaps to "a-list", and "alist"
;should construct an alist.
;... Next will... um... dhnumb.

;Time to make safe-mapping-write less verbose.
;I.e. eliminate unnecessary datum labels.
;('Tis el baddo.)
;... hmm.
;It is indeed a good idea to separate dicks out...
;safe-replace is probably sufficient.

(def safe-mapping-write (x p f) ;sigh
  (with (numb ($:make-hasheq)
         n 0)
    (xloop (x x)
      (aif numb.x
           (pr "#" it "#")
           (do (= numb.x ++.n)
             (pr "#" n "=")
             (let x (if p.x f.x x)
               (if acons.x
                   (do (pr "(")
                     (next car.x)
                     (pr " . ")
                     (next cdr.x)
                     (pr ")"))
                   (or ($.number? x)
                       (isa x 'sym)
                       (isa x 'string))
                   write.x
                   no.x
                   write.nil
                   ($.vector? x)
                   (do (pr "#(")
                     (let first t
                       (for i 0 (dec $.vector-length.x)
                         (next ($.vector-ref x i))
                         (unless first (pr " "))
                         (= first nil)))
                     (pr ")"))
                   ($.hash? x)
                   (do (pr "#hash(")
                     (let first t
                       (each (k v) x
                         (pr "(")
                         (next k)
                         (pr " . ")
                         (next v)
                         (pr ")")
                         (unless first (pr " "))
                         (= first nil)))
                     (pr ")"))
                   (err "What is this?" x)))))))
  nil)

(mac ret (x val . body)
  `(let ,x ,val ,@body ,x))

;nondestructive version
;... but you gotta be careful that f doesn't produce
;something that satisfies p indefinitely.
(def safe-replace2 (x p f)
  (with fakenil (uniq)
    fail (uniq)
    value ($:make-hasheq)
    (xloop (x x)
      (let u (value x fail)
        (if (isnt u fail)
            (if (is u fakenil)
                nil
                u)
            (let v (if p.x
                       f.x
                       x)
              (if acons.v
                  (ret u (cons nil nil)
                    (= value.x u)
                    (scar u (next car.v))
                    (scdr u (next cdr.v)))
                  (or (isa v 'string)
                      (isa v 'sym)
                      ($.number? v)
                      (isa v 'fn))
                  (do (= value.x (or v fakenil))
                    v)
                  ($.hash? v)
                  (ret u (if $.hash-eq?.v
                             ($.make-hasheq)
                             (table))
                    (= value.x u)
                    (each (key val) v
                      (= (u next.key) next.val)))
                  ($.vector? v)
                  (ret u ($.make-vector $.vector-length.v)
                    (= value.x u)
                    (for i 0 (dec $.vector-length.v)
                      (($ vector-set!) u i (next ($.vector-ref v i)))))
                  (err "What is this?" v x))))))))

;Hmm...
;Dick.
;Recognize the things by position.
;Plain symbols.
;(I am addressing the problem that, if I print the x chunk of code
; as the symbol "meh", then that could be ambiguous with the actual
; symbol "meh".  My "solution" is to ignore it, and to trust that
; when someone serializes a whole system, they'll probably print out
; a table in some recognized form. Therefore, the symbol "meh" as
; printed in the global-value table will probably refer to the code;
; then ... ok, not necessarily, but whatever. I could just add a
; known table as well. Note that the symbol "meh" and the meh-code
; object will be different objects and will have different numbers
; associated with them; the task is then to figure out which is which.
; So print a list where the first item is a list of code dicks.
; Fuck. Anyway.)

(def if3 (v th el) ;the single use of this is unnec.
  (if v (th) (el)))
(def make-alist xs
  (tuples 2 xs))

(= obj-table ($.make-hasheq) ;was code-table, but need if-objs, etc.
   obj-table!HELLA-NIL nil)

;named global fn: further demonstrates success.
(mac nfn (name args . body)
  (let u (eval `(fn ,args ,@body))
    (= obj-table.u name)
    `',u))

(mac ndef (name args . body) ;might need
  `(do (def ,name ,args ,@body)
     (= (obj-table ,name) ',name)))

(= override-object (cons 'override 'nova))

(w/uniq g
  (def uwrite (x)
    (safe-mapping-write
     x [isnt g (obj-table _ g)]
     [list override-object obj-table._]))) ;;teh lazy ;oh man

(def save-world (k (o file)
                   (o uwrite uwrite))
  ([if file
       (tofile file (_))
       (_)]
   (fn ()
     (uwrite (list override-object global-value k)))))

(w/uniq g
  (def uwrite2 (x)
    (safe-mapping-write2
     x [isnt g (obj-table _ g)]
     [list override-object obj-table._])))

#;(def safe-mapping-write2 (x p f)
  (write (safe-replace2 x p f)))

;No.  Dumbass.
;Scheme doesn't ... oh.
;Oh man.
;OHHHHHHHHHHHHHHHHH man.

(def circular-list args
  (and args
       (ret u copylist.args
         (scdr last-pair.u u))))

;THIS IS SO TERRIBLE OH MY GOD
(def safe-mapping-write2 (x p f)
  (disp:let u (tostring ($.write (list circular-list.0 
                                       (safe-replace2 x
                                                      [obj-table _]
                                                      [list override-object
                                                            obj-table._]))))
            u
            (cut u (len "(#0=(0 . #0#) ")
                 (- len.u (len " . nil)")))))
;Turns out there is another method...
(= write-graph
   ($ (lambda (x)
        (parameterize ((print-graph #t))
          (write x)
          'nil))))
(def safe-mapping-write3 (x p f)
  (write-graph:safe-replace2 x p f))
(def uwrite3 (x)
  (safe-mapping-write3 x [obj-table _]
                       [list override-object obj-table._]))
            

;oh boy, now I have to replace crap
;... solution is to have a "unique" object somewhere.
;it shall be a certain dick thing.

(def safe-replace (x p f) ;hella destructive
  (with fakenil (uniq)
    fail (uniq)
    value ($:make-hasheq) ;even if not replaced ;indisc; lolz
    (xloop (x x)
      #;(prsn "next" x)
      (let u (value x fail)
        (if (isnt u fail)
            (if (is u fakenil)
                nil
                u)
            (let v (if p.x
                       f.x
                       x)
              #;(prsn "v" v)
              (= value.x (or v fakenil))
              (if acons.v
                  (do (scar v (next car.v))
                    (scdr v (next cdr.v)))
                  (or (isa v 'string)
                      (isa v 'sym)
                      ($.number? v)
                      (isa v 'fn))
                  nil
                  ($.hash? v)
                  (let v2 (if $.hash-eq?.v
                              ($.make-hasheq)
                              (table))
                    (= value.x v2)
                    (each (key val) v
                      (= (v2 next.key) next.val))
                    (= v v2))
                  ($.vector? v)
                  (for i 0 (dec $.vector-length.v)
                    (($ vector-set!) v i (next ($.vector-ref v i))))
                  
                  (err "What is this?" v x))
              v))))))

; dickass #hash(...) reads as an immutable hash
; fuckin'... mmm...
; can I distinguish...
; hashes print as #hash, hasheqs print as #hasheq, so read/write does
;preserve that. question is, can I tell.
;... ok, the "is this a hasheq?" procedure is named "hash-eq?".
;d'oh.
;anyway.

;the special forms are conses.
;they must be recognized nicely...
;... goddammit. the error seems to be that `(meh dick) is ()-term'd.
;... ... this must be fixed at the obj-table end.

;... sigh. must alter the vals but not the keys in gv.
;... acually they were altered in above.
;will fix...
;ah. it is mapping of dick.

(def load-world (x)
  (= rev-obj-table (table))
  (each (k v) obj-table
    (= rev-obj-table.v k))
  (let (ovr gv k) x
    #;(prsn "= dick"
          =-object
          (rev-obj-table =-object)
          gv!=
          keys.gv
          (rev-obj-table gv!=))
    (let f [safe-replace _
                         [and acons._
                              (is car._ ovr)]
                         [rev-obj-table cadr._]]
      (= global-value (table))
      (each (k v) gv
        #;(prsn k v)
        (= global-value.k f.v))
      (f k))))
  

(def ccall (f . args)
  (apply f.1 f.2 args))
(def capply (f . args)
  (apply apply f.1 f.2 args)) ;lol

(def is-system-proc (x)
  (isa x 'fn))

#;(mac arc-obj (x)
  `(do (= (obj-table ,x) ',x)
     ,x))
(= global-value (table))
(each (x y) (tuples 2 '(+ + - - * * / / cons cons car car cdr cdr is is < < > >
                          scar scar scdr scdr uniq uniq acons acons))
  (= global-value.x symbol-value.y
     (obj-table symbol-value.y) x))

(each s '(quote if = fn mc quasiquote arc unquote)
  (let obj-name (symb s '-object)
    (= symbol-value.obj-name (list 'special-form (string s))
       global-value.s symbol-value.obj-name
       (obj-table symbol-value.obj-name) s)))
(def eval-if (xs env k)
  (if no.xs
      (ccall k nil)
      (let (a . axs) xs
        (if no.axs
            (ueval a env k)
            ;... and I think I shall not go too far in pre-grabbing
            (ueval a env
                   (list 'closure
                         (nfn if-cont (ev v)
                           (if v
                               (ueval (car:alref ev 'axs)
                                      (alref ev 'env)
                                      (alref ev 'k))
                               (eval-if (cdr:alref ev 'axs)
                                        (alref ev 'env)
                                        (alref ev 'k))))
                         (make-alist 'env env 'axs axs 'k k)))))))
                         
(def ueval-progn (env exprs k)
  (unless acons.exprs ;note we've already tested for nil
    (err "What kind of function body is this?" exprs))
  (let (x . rest) exprs
    (if no.rest
        (ueval x env k) ;tail call!
        (ueval x env
               (list 'closure
                     (nfn progn-cont (ev ignored)
                       (ueval-progn (alref ev 'env)
                                    (alref ev 'rest)
                                    (alref ev 'k)))
                     (make-alist 'env env 'rest rest 'k k))))))
(def join-envs (env arglist xs k)
  (if no.arglist
      (if no.xs
          (ccall k env)
          (err "Too many arguments:" xs)) ;kind of strict
      acons.arglist
      (if no:acons.xs
          (err "Arg!" arglist xs)
          (join-envs env car.arglist car.xs
                     (list 'closure
                           (nfn join-envs-cont (ev u)
                             (join-envs u (cdr:alref ev 'arglist)
                                        (cdr:alref ev 'xs)
                                        (alref ev 'k)))
                           (make-alist 'arglist arglist
                                       'xs xs 'k k))))
      (isa arglist 'sym)
      (ccall k (cons (list arglist xs) env))
      (err "What kind of argument is this?" arglist)))
(def eval-= (xs env k)
  (let (v x . rest) xs
    (if no.rest
        (eval-=1 v x env k)
        (eval-=1 v x env
                 (list 'closure
                       (nfn eval-=-cont (ev ign)
                         (eval-= (alref ev 'rest)
                                 (alref ev 'env)
                                 (alref ev 'k)))
                       (make-alist 'rest rest 'env env 'k k))))))
(def eval-=1 (v x env k)
  (ueval x env
         (list 'closure
               (nfn eval-=1-cont (ev u)
                 (aif (assoc (alref ev 'v)
                             (alref ev 'env))
                      (ccall (alref ev 'k)
                             (= cadr.it u))
                      (ccall (alref ev 'k)
                             (= (global-value (alref ev 'v))
                                (or u 'HELLA-NIL)))))
               (make-alist 'v v 'env env 'k k))))
(def uapply (f k xs) ;making things less terrible with k
  (if (is-system-proc f)
      (ccall k (apply f xs)) ;either this or wrappers around all sysfuncs
      (and acons.f (is car.f 'closure))
      (capply f k xs)
      ;if not prim proc or closure, then string, table, or list
      ;(must err on macros, though) (uapply is user-exposed)
      (and acons.f (is car.f 'macro))
      (err "Can't apply a macro." f xs)
      (in type.f 'string 'cons 'table)
      (ccall k (apply f xs))
      (err "uapply: What is this?" f 'with 'args xs)))
;NOOB YOU'RE AN IDIOT
;YOU DON'T NEED TO DO SHADOWED NOR USED VARS
;(SO SUGGESTS WHOSIT, AND IT's PROBABLY RIGHT)

(def eval-fn (xs env)
  (let (arglist . body) xs
    (list 'closure
          eval-body
          (make-alist 'arglist arglist
                      'env env 'body body))))

(ndef eval-body (ev k . args)
  (join-envs (alref ev 'env)
             (alref ev 'arglist)
             args
             (list 'closure
                   (nfn eval-body-cont (ev u)
                        (ueval-progn u
                                     (alref ev 'body)
                                     (alref ev 'k)))
                   (make-alist 'body (alref ev 'body)
                               'k k))))

;join-envs really could be a primitive. oh well.
;... yes, this does not need a cont argument...
;the uclosure could very well go back to the toplevel.
;this thing shall fake an idfn thing.
(= idfn-cont (list 'closure
                   (nfn idfn-cont-code (ev x) x)
                   nil))

(def ueval (x (o env nil) (o k idfn-cont))
  (if (isa x 'int)
      (ccall k x)
      (isa x 'sym)
      (aif (assoc x env)
           (ccall k (cadr it))
           global-value.x
           (if (is it 'HELLA-NIL)
               (ccall k 'nil)
               (ccall k it)) ;DISMAL HACK (actually not too bad)
           (err "ueval: Not defined:" x))
      (and acons.x (is car.x 'special-object))
      (ccall k x)
      (alist x) ;hmmm... could make "acons" so that ((fn x x) . 1) would work,
                ;but then would have to look at the destructuring of arglist
                ;to see how to eval the args...
      (let (f . xs) x ;this is pretty explicitly inspired by lis.py
        (ueval f env
               (list 'closure
                      (nfn eval-cont (ev u)
                        (ueval-call u (alref ev 'xs)
                                    (alref ev 'env)
                                    (alref ev 'k)))
                      (make-alist 'xs xs 'env env 'k k))))
      (err "What is this?" x)))

(def ueval-call (u xs env k)
  (if (is u quote-object)
      (ccall k (car xs))
      (is u if-object)
      (eval-if xs env k)
      (is u =-object)
      (eval-= xs env k)
      (is u fn-object)
      (ccall k (eval-fn xs env))
      (is u mc-object)
      (ccall k (eval-macro xs env))
      (is u quasiquote-object)
      (eval-qq (car xs) 1 env k)
      (is u arc-object)
      (ccall k (eval car.xs))
      (and acons.u (is car.u 'macro))
      (apply-mac u xs
        (list 'closure
              (nfn macex-cont (ev expr)
                (ueval expr (alref ev 'env)
                       (alref ev 'k)))
              (make-alist 'env env 'k k)))
      (map-eval xs env
                (list 'closure
                      (nfn call-cont (ev args)
                           (uapply (alref ev 'u)
                                   (alref ev 'k)
                                   args))
                      (make-alist 'u u 'k k)))))

;sharing env here boss
(def map-eval (xs env k)
 (if no.xs
   (ccall k nil)
   (let (x . rest) xs
     (ueval x env
       (list 'closure
         (nfn map-eval-cont1 (ev a)
           (map-eval
             (alref ev 'rest)
             (alref ev 'env)
             (list 'closure
               (nfn map-eval-cont2 (ev b)
                 (ccall (alref ev 'k)
                        (cons (alref ev 'a)
                              b)))
               (cons (list 'a a) cddr.ev))))
         (make-alist 'rest rest 'env env 'k k))))))

;hmm, special objects make this a little weird
;should the reader have turned the `,,@ crap
;into special objects? ... no, could be quoted.
;well then, must do it this way. oh well.
;ignore error-checking
(def eval-qq (x n env k)
 (if atom.x
   (ccall k x)
   (let (f . xs) x
     (if (is f 'quasiquote)
       (eval-qq car.xs inc.n env
         (list 'closure
           (nfn eval-qq-cont1 (ev h)
             (ccall (alref ev 'k)
                    (list 'quasiquote h)))
           (make-alist 'k k)))
       (is f 'unquote)
       (if (is n 1)
         (ueval car.xs env k)
         (eval-qq car.xs dec.n env
           (list 'closure
             (nfn eval-qq-cont2 (ev h)
               (ccall (alref ev 'k)
                      (list 'unquote h)))
             (make-alist 'k k))))
       (is f 'unquote-splicing)
       (if (is n 1)
         (err "Bad use of unquote-splicing")
         (eval-qq car.xs dec.n env
           (list 'closure
             (nfn eval-qq-cont3 (ev h)
               (ccall (alref ev 'k)
                      (list 'unquote-splicing h)))
             (make-alist 'k k))))
       (eval-qq f n env
         (list 'closure
           (nfn eval-qq-cont4 (ev a)
             (eval-qq-tail
               (alref ev 'xs)
               (alref ev 'n)
               (alref ev 'env)
               (list 'closure
                 (nfn eval-qq-cont5 (ev b)
                   (ccall (alref ev 'k)
                          (cons (alref ev 'a) b)))
                 (make-alist
                  'k (alref ev 'k)
                  'a a))))
           (make-alist 'xs xs 'n n 'env env 'k k)))))))

;I see.  It is the difference between flattening closures and sharing
;them. In *this* code, the eval code is completely functional except
;for the effects to the global-value table, so it makes no difference.
;(If it did make a difference, it should be shared.)
(def eval-qq-tail (xs n env k)
 (if atom.xs
   (ccall k xs)
   (let (x . rest) xs
     (if (and (acons x)
              (is n 1)
              (is car.x 'unquote-splicing))
       (ueval cadr.x env
         (list 'closure
           (nfn eval-qq-tail-cont1 (ev a)
             (eval-qq-tail
               (alref ev 'rest)
               (alref ev 'n)
               (alref ev 'env)
               (list 'closure
                 (nfn eval-qq-tail-cont2 (ev b)
                   (ccall (alref ev 'k)
                          (join (alref ev 'a) b)))
                 (make-alist 'a a 'k (alref ev 'k)))))
           (make-alist 'rest rest 'n n 'env env 'k k)))
       (eval-qq x n env
         (list 'closure
           (nfn eval-qq-tail-cont3 (ev a)
             (eval-qq-tail
               (alref ev 'rest)
               (alref ev 'n)
               (alref ev 'env)
               (list 'closure
                 (nfn eval-qq-tail-cont4 (ev b)
                   (ccall (alref ev 'k)
                          (cons (alref ev 'a) b)))
                 (make-alist 'a a 'k (alref ev 'k)))))
           (make-alist 'rest rest 'n n 'env env 'k k)))))))

(def eval-macro (xs env) ;a macro is (mc (arg arg ...) body ...)
  (list 'macro (eval-fn xs env)))
(def apply-mac (f xs k)
  (uapply (cadr f) k xs))
(w/uniq g
  (def heh ()
    (let u (read (stdin) g)
      (unless (is u g)
        (let v ueval.u
          (= global-value!that v)
          wrn.v
          (heh))))))

;why do I do the above like that? I think I didn't like having
;one line have multiple things be read in. however, I have
;gotten used to the usual state of affairs.
;screw that. change in next.

(each (x y) (tuples
             2
             (list 
             'apply (fn (f . xs)
                      (apply uapply f idfn-cont xs))
             'eval ueval
             'apply-mac (fn (f xs) (apply-mac f xs idfn-cont))
             'write uwrite
             'ccc
             (list 'closure
                   (nfn ucall/cc (ev k f)
                     (ccall f k
                            (list 'closure
                                  (nfn call/cc-cont (ev k x)
                                    (ccall (alref ev 'k) x))
                                  (make-alist 'k k))))
                   nil)))
  (= global-value.x y
     (obj-table y) x))

;so the issue with call/cc is that there are two kinds of closures,
;user closures and conts, with diff. calling conventions (conts
; take no cont argument, closures take one cont argument), and
;if they have equal status, so that a given variable x could be
;bound to either a cont or a user closure, then that is problematic.
;me solves this by making call/cc wrap its cont in a user-closure.
;now time to check the Appel.

(no:ueval '((fn ()
              (= list (fn args args)
                 no (fn (x) (is x 'nil))
                 nil 'nil
                 list* (fn args (if (no (cdr args))
                                    (car args)
                                    (cons (car args) (apply list* (cdr args)))))
                 mac (mc (name args . body)
                         (list '= name (list* 'mc args body))))
              (mac def (name args . body)
                `(= ,name (fn ,args ,@body)))
              (def cadr (x) (car (cdr x)))
              (def macex1 (xs)
                (apply-mac (eval (car xs)) (cdr xs)))
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
              (mac do body (list (list* 'fn () body)))
              (def accumulate (comb f xs init next done)
                (if (done xs)
                    init
                    (accumulate comb f
                                (next xs) (comb (f xs) init)
                                next done)))
              (def take (n xs)
                (if (or (no xs) (is n 0))
                    nil
                    (cons (car xs) (take (- n 1) (cdr xs)))))
              (def drop (n xs)
                (if (or (no xs) (is n 0))
                    xs
                    (drop (- n 1) (cdr xs))))
              (def tuples (n xs)
                (if (no xs)
                    nil
                    (cons (take n xs) (tuples n (drop n xs)))))
              (def map1 (f xs)
                (if (no xs)
                    nil
                    (cons (f (car xs)) (map1 f (cdr xs)))))
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
              (mac for (v a b . body)
                (w/uniq (gf gb)
                  `(let ,v ,a
                     (let ,gb ,b
                       ((fn (,gf) (,gf ,gf ,v))
                        (fn (,gf ,v)
                          (if (> ,v ,gb)
                              nil
                              (do ,@body
                                (,gf ,gf (+ ,v 1))))))))))
              (mac w/uniq (v . body) ;wootz we are defining this after
                (if (acons v)        ;its use in for
                    `((fn ,v ,@body) ,@(map1 (fn (x) `',(uniq)) v))
                    `(let ,v (uniq) ,@body))))))