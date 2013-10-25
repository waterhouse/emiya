

(mac thunkify (expr)
  (w/uniq g
    `(dethunk ,(thunkify-with expr g) ',g)))

;terrible
(def dethunk (thunk g)
  (if (isa thunk 'fn)
      (drain (thunk) g)
      thunk))

(= thunk-sig-table (table))

;Game plan regarding n args.
;(map-thunk f args ... g) will be a macro, as it has
;theoretically general use outside of (thunkify ...).
;thunkify-with can then just macex to get that, and needn't
;know anything more.
;I shall have "extra args = a symbol" (rather than list)
;mean that it's an n-args and should be macex'd.
;It appears that the most natural way to do this is to have
;general support for thunk-macros.
;lol nvm, thunkify-with will need something. n can be the atom.

(mac thunk-def (name args extra-args . body)
  (if atom.extra-args ;gs
      (and `(thunk-n-ary-def ,name ,args ,extra-args ,@body) (err "Narf"))
      `(do1 (def ,(symb name '-thunk) ,(join args extra-args) ,@body)
            (= (thunk-sig-table ',name)
               ',extra-args))))

(def thunkify-with (expr g)
  (if acons.expr
      (let (name . args) expr
        (aif thunk-sig-table.name
             ;currently, assume is ([0+ thunk arguments] gs)
             ;or is an atom => n.
             ;... lolz, at this point it could probably become always n.
             ;if I settled on my current approach and didn't allow more new crap.
;             (if acons.it
             (let (normals thunks) (split args (if acons.it
                                                   (- len.args dec:len.it)
                                                   it))
;                   (prsn name normals thunks)
                   `(,(symb name '-thunk)
                     ,@normals
                     ,@(map [thunkify-with _ g] thunks)
                     ',g))
;                 `(,(symb n(thunkify-with (ma(cons (symb name '-thunk) args)) g))
             (err "Don't know how to thunkify" expr)))
      expr))



(thunk-def map1 (f) (thunk gs)
  (fn ()
    (let u (thunk)
      (if (is u gs)
          gs
          (f u)))))

(thunk-def map2 (f) (x1 x2 gs)
  (fn ()
    (with (v1 (x1) v2 (x2))
      (if (in gs v1 v2)
          gs
          (f v1 v2)))))

;lol what I actually want is thunk-mac.
;(thunk-n-ary-def map (f n)
;  (let 
  
(mac map-thunk (f . args)
  (let thunks butlast.args
    ;d'oh, I am having side effects and calling eval
    ;in the body of a macro... oh well
    ;--or not the latter, not directly.
    (with (namea (symb 'map len.thunks)
           nameb (symb 'map len.thunks '-thunk))
      (unless thunk-sig-table.namea
        (define-map-thunk len.thunks))
      `(,nameb ,f ,@args))))

(= thunk-sig-table!map 1) ;one normal arg

(def define-map-thunk (n)
  (eval
   (with (thunks (mapn [symb 'thunk _] 1 n)
          vals (mapn [symb 'v _] 1 n))
     `(thunk-def ,(symb 'map n) (f) (,@thunks gs)
        (fn ()
          (with ,(interleave vals (map list thunks))
            (if (in gs ,@vals)
                gs
                (f ,@vals))))))))

;(mac thunk-mac (name args extra-args . body)
;  (w/uniq gargs
;    `(do1 (mac ,(symb name '-thunk) ,gargs
;            (let ,(join args ...
;        (= (thunk-sig-table ',name) ,(len args))

(thunk-def take (n) (thunk gs)
  (fn ()
    (if (is n 0)
        gs
        (let u (thunk)
          (if (is u gs)
              gs
              (do (= n (- n 1)) u))))))

(thunk-def drop (n) (thunk gs)
  (fn ()
    (until (or (is n 0) (is (thunk) gs))
      (= n (- n 1)))
    (thunk)))

(thunk-def range (a b) (gs)
  (fn ()
    (if (> a b)
        gs
        (do1 a ++.a))))

;egah, this kind of sucks...
;either I make it call the thunk once at the start, which is ugly,
;or I introduce a layer of indirection where I check whether we're
;at the start, every time. ... I suppose the cost is probably small,
;but j... wait, no. reduce doesn't produce a sequence. thank god.
(thunk-def reduce (f) (thunk gs)
  (let val (thunk)
    (if (is val gs)
        (f)
        (xloop (val val)
          (let u (thunk)
            (if (is u gs)
                val
                (next:f val u)))))))

;ok, here I actually can't use len.
;good, good.
;now. ... maybe some sort of double recursion
;will help, because that is sort of the equivalent
;of building up a stack of things to handle later.
;at least, I recall them serving equivalent purposes in flatten.

(def ufl (xs)
  (nrev:xloop (xs xs ys nil)
              (if no.xs
                  ys
                  atom.xs
                  (cons xs ys)
                  (next cdr.xs (next car.xs ys)))))

;hmmph. but there is the problem of returning multiple values or
;some equivalent: both 
;I could rely on (thunk) repeatedly returning gs, which kind of sucks.
;I could make a local variable used as a flag, and check it.
;I could use pseudo-continuations, or real continuations, or multiple
;values.
;I suppose I'll use the flag...

;(nerf val n)
;(let u (n dicks)
;  (if flag
;      u
;      (let v (nerf nothing n)
;        (let u (f u v)
;          (if flag
;              u
;              ()))))))


(thunk-def binary-reduce (f) (thunk gs)
  (let flag nil
    (let a-chunk (rfn a-chunk (n)
                   (if (is n 1)
                       (thunk)
                       (let u (a-chunk:ash n -1)
                         (if flag
                             u
                             (let v (a-chunk:ash n -1)
                               (if (is v gs)
                                   (do (= flag t) u)
                                   (f u v)))))))
      (let u (thunk)
        (if (is u gs)
            (f)
            (xloop (left u n 1) ;left is 2^n; we make a 2^n, combine.
              (let u (a-chunk n)
                (if (is u gs)
                    left
                    (let v (f left u)
                      (if flag
                          v
                          (next v (ash n 1))))))))))))
;lolz, I could replace that shl/ring with add/subing. oh well.

;can I make map handle many thunks?
;... I have a terrible idea for n-ary things.
;... I suppose I must make it.
;... would I go for something that _produces_ n thunks?
;terrible.
#;(thunk-def map (f) (thunk gs)
  (fn ()
    (let u (thunk)
      (if (is u gs)
          gs
          (f u)))))
  
  
  
  
  
  