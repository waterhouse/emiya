

(mac thunkify (expr)
  (w/uniq g
    `(dethunk ,(thunkify-with expr g) ',g)))

;terrible
(def dethunk (thunk g)
  (if (isa thunk 'fn)
      (drain (thunk) g)
      thunk))

(= thunk-sig-table (table))

(def enthunk (xs gs)
  (fn ()
    (if no.xs
        gs
        (do1 car.xs
             (= xs cdr.xs)))))

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
  `(do1 (def ,(symb name '-thunk) ,(join args extra-args) ,@body)
        (= (thunk-sig-table ',name)
           ',(cons args extra-args))))

;I shall dictate that functions are not allowed to have rest args,
;although macros may (but they must be thunk args).
;If there are rest args to a macro, then it is interpreted to be
;the last arguments before the gensym argument.
(def proper-list (xs)
  (or no.xs (and acons.xs proper-list:cdr.xs)))
(= enthunk-loud t)
(def thunkify-with (expr g)
  (if acons.expr
      (let (name . args) expr
        (aif thunk-sig-table.name
             (let (sig-normals . sig-extras) it
               ;currently, assume extras is ([0+ thunk arguments] gs)
               ;or is (thunks . gs).
               ;... with the advent of having the normal args stored,
               ;this becomes trivial.
               (let (normals thunks) (split args len.sig-normals)
                 `(,(symb name '-thunk)
                   ,@normals
                   ,@(map [thunkify-with _ g] thunks)
                   ',g)))
             (enthunkify expr g)))
      (enthunkify expr g)))
(def enthunkify (expr g)
  (when enthunk-loud
    (prsn "; Warning: enthunking" expr)
    (prn "; (set enthunk-loud to nil to silence this warning)"))
  `(enthunk ,expr ',g))


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

;extra-args is either ([thunks ...] gs)
;or (thunks . gs).
;...
;it'd probably be nice if I'd just store the whole
;signature...
;Incidentally, my life might be somewhat easier if
;I decided to put gs before thunks. It is out of a sort of
;stubbornness that I've left it this way.
;I think I'll keep it this way.
;Anyway. 
(mac thunk-mac (name args extra-args . body)
  `(do1 ,(if proper-list.extra-args
             `(mac ,(symb name '-thunk) ,(join args extra-args) ,@body)
             (let (thunks-arg . gs-arg) extra-args ;(thunks . gs) assumed
               (w/uniq gargs
                 `(mac ,(symb name '-thunk) ,(flip rev.args gargs)
                    (with (,thunks-arg (butlast ,gargs)
                           ,gs-arg (last ,gargs))
                      ,@body)))))
        (= (thunk-sig-table ',name)
           ',(cons args extra-args))))

(thunk-mac map (f) (thunks . gs)
  ;(let thunks butlast.args
    ;d'oh, I am having side effects and calling eval
    ;in the body of a macro... oh well
    ;--or not the latter, not directly.
    (with (namea (symb 'map len.thunks)
           nameb (symb 'map len.thunks '-thunk))
      (unless thunk-sig-table.namea
        (define-map-thunk len.thunks))
      `(,nameb ,f ,@thunks ,gs)))

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


;now... 
;sometimes, "range a b" sort of represents what might be called an
;unordered set. it is ordered, but you might not want to access it
;sequentially. you might do binary search, for example.
;

(thunk-def find (f) (thunk gs)
  (let f testify.f
    (xloop ()
      (let u (thunk)
        (if (is u gs)
            nil
            f.u
            u
            (next))))))

;a few ways to do this...
;of varying levels of dickishness
;(thunk-def all-choices* (f xs) (gs)
  ;(

;time to imitate the source code.
;hmm... serious differences...
;(thunk-def all-combos* (xs) (gs)
;  (if no.xs

;so... some sort of stack-ish? hmm...
;I could even do some skillzy sort of thing
;where I make cons cells out of combos of the last half of the choices or smthg
;oh my god, join.
;(thunk-def all-choices* (f xs) (gs)

;hmm. if I plan to repeatedly use join to build things up...
;it probably would be nice to not build up those levels of indirection.
;unfortunately... there... doesn't seem... to be a way...
;maybe a macro. ...
;(thunk-def join () (xs ys gs)
;  (fn ()
;    (if no.xs

;eh, I suppose that it could probably just be the depth.
;so that might be ok.

;LOLOLOLOLOLOLOLOLOL OH MY GOD LOLOLOLOLOLOL
(thunk-def join () (xs ys gs)
  (fn ()
    (let u (xs)
      (if (is u gs)
          (if (is ys gs) ;yes, ys, not (ys)
              gs
              (do (= xs ys ys gs) ;bwahahahaha
                (xs)))
          u))))

;wootz, this becomes an improvement.
;but it is not enough.
#;(thunk-def all-choices* (f xses) (gs)
  (if no.xses
      (enthunk (list:f) gs)
      (no cdr.xses)
      (do (= xses car.xses)
        (fn ()
          (if no.xses
              gs
              (do1 (f car.xses)
                   (= xses cdr.xses)))))
      (no car.xses)
      gs
      (join-thunk (withs (u caar.xses)
                    (all-choices*-thunk (fn args (apply f u args)) cdr.xses gs))
                  (all-choices*-thunk f (cons (cdr car.xses) cdr.xses) gs)
                  gs)))

;completely useless
(defmemo make-caller (n)
  (let arglist (mapn [symb 'x _] 1 n)
    (eval `(fn (f) (fn ,arglist (f ,@arglist))))))

;(thunk-def all-choices* (f xses) (gs)
;  (with (n (thunkify:reduce * (map len xses)) ;lol awesome
;         
;           )
;    (let mergh (eval `(fn (

(thunk-def all-choices2 (f xs ys) (gs)
  (with (uxs xs uys ys x nil y nil)
    (if no.uxs
        gs
        (do (= x car.uxs uxs cdr.uxs)
          (rfn meh ()
            (if no.uys
                (if no.uxs
                    gs
                    (do (= x car.uxs uxs cdr.uxs uys ys)
                      (meh)))
                (do1 (f x car.uys)
                     (= uys cdr.uys))))))))

;we have some O(n^2) code here, which could be
;reduced with some jumps
(thunk-def all-choices3 (f xs ys zs) (gs)
  ;there will be no need for z.
  (if (or no.xs no.ys no.zs)
      gs
      (with (uxs cdr.xs uys cdr.ys uzs zs
             x car.xs y car.ys)
        (fn ()
          (if no.uzs
              (if no.uys
                  (if no.uxs
                      gs
                      (do (= x car.uxs uxs cdr.uxs)
                        (= y car.ys uys cdr.ys)
                        (do1 (f x y car.zs)
                             (= uzs cdr.zs))))
                  (do (= y car.uys uys cdr.uys)
                    (do1 (f x y car.zs)
                         (= uzs cdr.zs))))
              (do1 (f x y car.uzs)
                   (= uzs cdr.uzs)))))))

#;(thunk-def all-choices4 (f xs ys zs us) (gs)
  (if (or no.xs no.ys no.zs no.us)
      gs
      (with (uxs cdr.xs uys cdr.ys uzs cdr.zs uus us
             x car.xs y car.ys z car.zs)
        (withs (reset-z (fn () (= z car.zs uzs cdr.zs))
                reset-yz (fn () (= y car.ys uys cdr.ys) (reset-z))
                        
                snarf-u (fn () (do1 (f x y z car.us)
                                    (= uus cdr.us))))
          (fn ()
            (if no.uus
                (if no.uzs
                    (if no.uys
                        (if no.uxs
                            gs
                            (do (= x car.uxs uxs cdr.uxs)
                              (reset-yz)
                              (snarf-u)))
                        (do (= y car.uys uys cdr.uys)
                          (reset-z)
                          (snarf-u)))
                    (do (= z car.uzs uzs cdr.uzs)
                      (snarf-u)))
                (do1 (f x y z car.uus)
                     (= uus cdr.uus))))))))
;hoo boy
;arc> (time:thunkify:reduce + (all-choices4 + (mapn [* _ 1000] 1 100) (mapn [* _ 100] 1 100) (mapn [* _ 10] 1 10) (mapn [* _ 1] 1 10)))
;time: 291 cpu: 292 gc: 0 mem: 19976
;55610500000
;arc> (time:reduce + (all-choices + (mapn [* _ 1000] 1 100) (mapn [* _ 100] 1 100) (mapn [* _ 10] 1 10) (mapn [* _ 1] 1 10)))
;time: 7354 cpu: 7322 gc: 3484 mem: 84810832
;55610500000

;you go, thunkifier!

;... maybe a best thing to do would be to inline in O(n^2) style the last couple
;and otherwise loop over things.

;resets shall be combined with snarfs.
;because that is simple.
;... oh god. need to handle cases with one var or less.
;well, that should be fairly easy.

#;(thunk-def all-choices4 (f xs ys zs us) (gs)
  (if (or no.xs no.ys no.zs no.us)
      gs
      (with (uxs cdr.xs uys cdr.ys uzs cdr.zs uus us
             x car.xs y car.ys z car.zs)
        (withs (reset-last (fn () (do1 (f x y z car.us)
                                       (= uus cdr.us)))
                reset-z (fn () (= z car.zs uzs cdr.zs) (reset-last))
                reset-y (fn () (= y car.ys uys cdr.ys) (reset-z)))
          (fn ()
            (if no.uus
                (if no.uzs
                    (if no.uys
                        (if no.uxs
                            gs
                            (do (= x car.uxs uxs cdr.uxs)
                              (reset-y)))
                        (do (= y car.uys uys cdr.uys)
                          (reset-z)))
                    (do (= z car.uzs uzs cdr.uzs)
                      (reset-last)))
                (do1 (f x y z car.uus)
                     (= uus cdr.uus))))))))
;oh lol I can reduce indentation, and make slightly more efficient
(thunk-def all-choices4 (f xs ys zs us) (gs)
  (if (or no.xs no.ys no.zs no.us)
      gs
      (with (uxs cdr.xs uys cdr.ys uzs cdr.zs uus us
             x car.xs y car.ys z car.zs)
        (withs (reset-last (fn () (do1 (f x y z car.us)
                                       (= uus cdr.us)))
                reset-z (fn () (= z car.zs uzs cdr.zs) (reset-last))
                reset-y (fn () (= y car.ys uys cdr.ys) (reset-z)))
          (fn ()
            (if uus
                (do1 (f x y z car.uus)
                     (= uus cdr.uus))
                uzs
                (do (= z car.uzs uzs cdr.uzs)
                  (reset-last))
                uys
                (do (= y car.uys uys cdr.uys)
                  (reset-z))
                uxs
                (do (= x car.uxs uxs cdr.uxs)
                  (reset-y))
                gs))))))

;should I use heuristics about inlining, like, up to four calls
;at a time? ... lolz...

(def define-all-choices-thunk (n)
  (with (xses (mapn [symb 'xs _] 1 n)
              xes (mapn [symb 'x _] 1 dec.n)
              uxses (mapn [symb 'uxs _] 1 n)
              resets (join (mapn [symb 'reset-x _] 2 (- n 1))
                           '(reset-last)))
    ;    (map prn (list xses xes uxses resets))
    (eval
     `(thunk-def ,(symb 'all-choices n) (f ,@xses) (gs)
        (if (or ,@(map (fn (x) `(no ,x)) xses))
            gs
            (with ,(join (interleave butlast.uxses (map (fn (x) `(cdr ,x)) butlast.xses))
                         (list last.uxses last.xses)
                         (interleave xes (map (fn (x) `(car ,x)) xses)))
              ;when you reset one variable, you reset var n-1
              ;when you reset two, you reset n-2 and n-1
              ;...
              ;time to combine this crap.
              ;
              (withs (reset-last (fn () (do1 (f ,@xes (car ,last.xses))
                                             (= ,last.uxses (cdr ,last.xses))))
                      ,@(mappend (fn (i)
                                   `(,(symb 'reset-x i)
                                     (fn () (= ,(xes dec.i) (car ,(xses dec.i))
                                               ,(uxses dec.i) (cdr ,(xses dec.i)))
                                       (,(if (is inc.i n)
                                             'reset-last
                                             (symb 'reset-x inc.i))))))
                                 (nrev:range 2 dec.n)))
                (fn ()
                  ;(prsn ,@xes)
                  (if ,last.uxses
                      (do1 (f ,@xes (car ,last.uxses))
                           (= ,last.uxses (cdr ,last.uxses)))
                      ,@(flat1:map (fn (x uxs reset)
                                     `(,uxs
                                       (do (= ,x (car ,uxs) ,uxs (cdr ,uxs))
                                         (,reset))))
                                   rev.xes cdr:rev.uxses
                                   rev.resets)
                      gs)))))))))

;earlier I mentioned no rest args outside macros, and that
;rest args in macros must be thunks.
;well... leaving that that way for now, 'cause I actually
;want all-choices*, not all-choices.

(defmemo which-all-choices-thunk (n)
  (unless (thunk-sig-table (symb 'all-choices n))
    (define-all-choices-thunk n))
  (symbol-value:symb 'all-choices n '-thunk))

(thunk-def all-choices* (f xs) (gs)
  (apply (which-all-choices-thunk len.xs) f (join xs list.gs)))

;arc> (time:repeat 200 (kfp2 '(16 0 -8 0 1)))
;time: 474 cpu: 473 gc: 10 mem: -9693760
;nil
;arc> (time:repeat 200 (kfp '(16 0 -8 0 1)))
;time: 2778 cpu: 2775 gc: 29 mem: -7034848
;nil
;HELLS YEAH
;(kfp2 thunkifies)
;arc> (time:repeat 200 (kfp '(25 0 -10 0 1)))
;time: 4677 cpu: 4672 gc: 50 mem: 2959760
;nil
;arc> (time:repeat 200 (kfp2 '(25 0 -10 0 1)))
;time: 2547 cpu: 2543 gc: 27 mem: -3246928
;nil

;Next version shall have general "either the normal-args or the
;extra-args can contain varargs (rest or optional) (um... probably
;just implemented as "rest or non-simple")".
                                        


        

      

