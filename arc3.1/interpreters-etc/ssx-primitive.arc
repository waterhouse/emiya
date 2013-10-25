;ssyntax, my style.
;First we decompose a.b!c:d... into (a #\. b #\! c #\: d ...),
;then go left to right, to produce a thing.
;On top of that, we eliminate composes that we created.
;E.g. (a:b c) => (a (b c)),
;     a:b.c   => (a (b c)),
;     f:g?c   => (f (g? c)).

;As discussed earlier... now...
;We shall avoid generating composes in the cases where we can
;eliminate them...

;I had considered having (a?b c) be like (a? (b c)),
;but I think not. Just use a colon. [Or a period in this case, foo'.]

;--Oh and one more thing (dammit).
;Maybe two.
;Must be careful to not reach within $.

#;(def is-ssx (x) ;careless; some things will expand to themselves
  (and ($.symbol? x)
       (find ssx-char string.x)))

;this is very sure
(def ssx? (x)
  (and (sym? x)
       (ssx-string? (sym->string x))))

(def ssyntax-string? (s)
  (let u (string-pos ssx-char? s)
    (and u
         ;(isnt (s 0) #\:) ;you're retarded, that is ssx, just special
         (no (and (is u (- (len s) 1))
                  (in (s u) #\? #\!))))))

#;(def dss-head (x) ;version 0
  (if acons.x
      (if (is car.x '$)
          x
          (is-ssx car.x)
          (let (a an) (ssx-term car.x)
            (if (xloop (a a an an)
                  (if (is an 0)
                      (is a '$)
                      (or (is a.2 '$)
                          (next a.1 dec.an))))
                (ssx-clean a cdr.x an)
                (ssx-clean a (dss-tail cdr.x) an)))
          (cons (dss-head car.x) (dss-tail cdr.x)))
      is-ssx.x
      ssx.x
      x))

;version 1: dss, is-ssx -> ssx?
(def dss-head (x)
  (if (acons x)
      (if (is (car x) '$)
          x
          (ssx? (car x))
          (let (a an) (ssx-term (car x))
            (if (xloop (a a an an)
                  (if (is an 0)
                      (is a '$)
                      (or (is (a 2) '$)
                          (next (a 1) (dec an)))))
                (ssx-clean a (cdr x) an)
                (ssx-clean a (dss-tail (cdr x)) an)))
          (cons (dss-head (car x)) (dss-tail (cdr x))))
      (ssx? x)
      (ssx x)
      x))

;ok, the next remaining problem seems to be !sym syntax.

#;(def dss-tail (x) ;version 0
  (if acons.x
      (cons (dss-head car.x) (dss-tail cdr.x))
      is-ssx.x
      ssx.x
      x))

;version 1: dss, is-ssx -> ssx?
(def dss-tail (x)
  (if (acons x)
      (cons (dss-head (car x)) (dss-tail (cdr x)))
      (is-ssx x)
      (ssx x)
      x))

#;(= dss dss-head)

(assign dss dss-head)

;blah? remains.
;single chars remain themselves.
;and :whatever is an escape.

(def ssx-char? (x)
  (in x #\: #\? #\& #\. #\!))

;need "0" to become a number and "s" to become a symbol...
;reverse of "str" (lolz)
#;(def rts (s)
  (if (is 0 len.s)
      (symb "")
      (read s)))

;must use something simpler...
;string->number, which shall return ...

;aha, string->decimal.
;a.0b10 ... feh.
;hmm.
;well...
;eh.
;for the moment, only supporting decimal numbers in ssx.

;oh, god, n-ary comparisons...
;I guess <2 and >2 should be provided, and the rest probably
;... yeah. Rest defined as user code, fuck yeah.
;CPS compilation and crap can handle BS.
;... so far I haven't tried to do type dispatching on anything...

(def transitive (f-two xs)
  (if (no xs)
      't
      (transitive-rest f-two (car xs) (cdr xs))))

(def transitive-rest (f-two x xs)
  (if (no xs)
      't
      (f-two x (car xs))
      (transitive-rest f-two (car xs) (cdr xs))
      nil))

(def < args (transitive <2 args))
(def > args (transitive >2 args))
;lolz, <= is inferior to < performance-wise until compilers happen...
(def <=2 (x y) (no (>2 x y)))
(def >=2 (x y) (no (<2 x y)))
(def <= args (transitive <=2 args))
(def >= args (transitive >=2 args))

(def char<= args
  (transitive char<=2 args))

(def char<=2 (x y)
  (<=2 (char->int x) (char->int y)))

(def char->digit (x) ;no unicode digits pls
  (let u (- (char->int x) (char->int #\0))
    (and (<= 0 u 9)
         u)))

(def digit? (x)
  (char<= #\0 x #\9))

;we return nil if is not a pure integer
(def string->decimal (s)
  (xloop (i 0 n 0)
    (if (is i (len s))
        n
        (digit? (s i))
        (next (+ i 1) (+ (char->digit (s i))
                         (* 10 n)))
        nil)))

;(assign string->number string->decimal) ;neh

;string -> symbol or number
(def s->sn (s) ;s not x you ninny
  (or (string->decimal s)
      (string->sym s)))

;a?[ssx-char]b => treat the ? in "a?" like a normal char

;returns a list of stuff.
;a one-element list means no weird stuff--is treated normally.
;note that x is known to have at least 1 char.
;And a special case: $.
;For my convenience, $.set! should work fine.
;Actually, as a matter of fact...
;It should always be fine to terminate a symbol with !.
;Even the ridiculous "get" syntax is !b rather than b!, as the
;latter would not make sense.
;Therefore, $ need not be a special case here.
;... Ok, it shall be true for both ! and ? that you can define
;symbols that look like them, and you can use compose and wtvr...
;Also ?! and !? and ???! will work.
;... um... rly? no.
;no.

;Will use a cheap trick to make this work...

#;(def ssx-list (x) ;version 0
  (let s string.x
    (if (is s.0 #\:)
        (list:rts:cut s 1)
        (is s.0 #\!)
        (ssx-list:symb "get" s)
        (is 1 len.s)
        list.x
        (let slen len.s
          (when (is (s:dec len.s) #\!)
            --.slen)
          (xloop (i 0)
            (if (is i slen)
                (err "Empty substring at end of ssyntax" s i)
                (let j i
                  (while (and (< j slen)
                              (no:ssx-char? s.j))
                    ++.j)
                  (if (is j slen)
                      (list:rts:cut s i)
                      (isnt s.j #\?)
                      (if (is i j)
                          (err "Empty substring in ssyntax" s i j)
                          (cons (rts:cut s i j)
                                (cons s.j (next:+ j 1))))
                      (do (while (and (< j slen)
                                      (is s.j #\?))
                            ++.j)
                          (if (is j slen)
                              (list (rts:cut s i))
                              (ssx-char? s.j)
                              (cons (rts:cut s i j)
                                    (cons s.j (next:+ j 1)))
                              (cons (rts:cut s i j)
                                    (cons #\? (next j)))))))))))))

;copies from 
;guh
#;(def string-copy (dst src i j)
  (xloop (n 0 i i)
    (if (> i j)
        dst
        (do (string-set dst n (src i))
          (next (+ n 1) (+ i 1))))))

;oh boy
;...
;fuck
;all right, yes; my arg order
(def string-copy-* (dst dstn src st ed)
  (if (> st ed)
      (err "Trying to copy negative characters from a string"
           st ed src)
      (> (- ed st) (- (len dst) dstn))
      (err "Trying to copy too many characters into a string"
           (- ed st) dst dstn)
      (xloop (dn dstn st st)
        (if (is st ed) ;is, not >
            dst
            (do (string-set dst dn (src st))
                (next (+ dn 1) (+ st 1)))))))
  

(def string-cut (s a . b)
  (let b (if b (car b) (len s))
    (let u (make-string (- b a))
      (string-copy-* u 0 s a b))))

(assign substring string-cut)

#;(def string-append2 (x y)
  (with lx (len x) ly (len y)
    (let u (make-string (+ lx ly))
      (string-copy-* u 0 x 0 lx)
      (string-copy-* u lx y 0 ly))))

(def sumlist (f xs)
  (xloop (xs xs n 0)
    (if (no xs)
        n
        (next (cdr xs) (+ (f (car xs)) n)))))

(def string-append args
  (let u (make-string (sumlist len args))
    (xloop (args args i 0)
      (if (no args)
          u
          (let s (car args)
            (string-copy-* u i s 0 (len s))
            (next (cdr args) (+ i (len s))))))))

;the following will need to be improved later with destructuring
;assignment, as well as optional args
(mac ++ (x . n)
  `(assign ,x (+ ,x ,(if (cons? n)
                         (car n)
                         1))))
(mac -- (x . n)
  `(assign ,x (- ,x ,(if (cons? n)
                         (car n)
                         1))))

;why is it not defined like this in arc.arc?
(mac while (test . body)
  (w/uniq gf
    `((rfn ,gf ()
        (when ,test ,@body (,gf))))))

(def dec (x) (- x 1))

;version 1: s->sn rather than rts, dss, sym->string rather than string,
;string-cut rather than cut; btw note we need the (cut s start) opt-arg
;behavior, or eqv, because I used slen in a terrible way.
;string -> sym->string.
(def ssx-list (x)
  (withs s (sym->string x)
    slen (len s)
    (if (is (s 0) #\:)
        (list (s->sn (string-cut s 1)))
        (is (s 0) #\!)
        (ssx-list (string->sym (string-append "get" s)))
        (is 1 slen)
        (list x)
        (do
          (when (is (s (dec (len s))) #\!)
            (-- slen))
          (xloop (i 0)
            (if (is i slen)
                (err "Empty substring at end of ssyntax" s i)
                (let j i
                  (while (and (< j slen)
                              (no (ssx-char? (s j))))
                    (++ j))
                  (if (is j slen)
                      (list (s->sn (string-cut s i)))
                      (isnt (s j) #\?)
                      (if (is i j)
                          (err "Empty substring in ssyntax" s i j)
                          (cons (s->sn (string-cut s i j))
                                (cons (s j) (next (+ j 1)))))
                      (do (while (and (< j slen)
                                      (is (s j) #\?))
                            (++ j))
                          (if (is j slen)
                              (list (s->sn (string-cut s i)))
                              (ssx-char? (s j))
                              (cons (s->sn (string-cut s i j))
                                    (cons (s j) (next (+ j 1))))
                              (cons (s->sn (string-cut s i j))
                                    (cons #\? (next j)))))))))))))

;strategy.
;do just do things.
;and then deconstruct, afterward, forms that happen to be like
;((compose ...) ...).
;this will be achieved exactly.
;in particular, results of crap will be cached...

;ok, I am making : ssyntax for the empty symbol.
;also I should avoid empty sub-things.

#;(def ssx (x)
  (let (x xn) ssx-term.x
    x))

(def ssx (x) 
  (let (x xn) (ssx-term x)
    x))

#;(def ssx-term (x)
  (ssx-reduce ssx-list.x))

(def ssx-term (x) 
  (ssx-reduce (ssx-list x)))

;so this returns (list expr n)
;where n is the number of (compose f g) things that make up the
;outermost layer.
#;(def ssx-reduce (xs) ;version 0
  (xloop (xs xs n 0)
    (if cdr.xs
        (let (a directive b . rest) xs
          (case directive
            #\? (let (x xn) (next (cons b rest) 0)
                  (list (ssx-clean a list.x n) 0))
            #\: (next (cons `(compose ,a ,b) rest) (+ n 1))
            #\& (next (cons `(andf ,a ,b) rest) 0)
            #\. (next (cons (ssx-clean a `(,b) n) rest) 0)
            #\! (next (cons (ssx-clean a `(',b) n) rest) 0)))
        (list car.xs n))))

;version 1: dss
(def ssx-reduce (xs)
  (xloop (xs xs n 0)
    (if (cdr xs)
        (let (a directive b . rest) xs
          (case directive
            #\? (let (x xn) (next (cons b rest) 0)
                  (list (ssx-clean a (list x) n) 0))
            #\: (next (cons `(compose ,a ,b) rest) (+ n 1))
            #\& (next (cons `(andf ,a ,b) rest) 0)
            #\. (next (cons (ssx-clean a `(,b) n) rest) 0)
            #\! (next (cons (ssx-clean a `(',b) n) rest) 0)))
        (list (car xs) n))))

#;(def ssx-clean (f xs n)
  (if (is n 0)
      (cons f xs)
      (let (cmp a b) f
        (ssx-clean a (list:cons b xs) dec.n))))

(def ssx-clean (f xs n)
  (if (is n 0)
      (cons f xs)
      (let (cmp a b) f
        (ssx-clean a (list (cons b xs)) (dec n)))))

;beh. much of the above library crap has some errors, it seems.
;I'll be working on that within dyn-cont6.
;maybe I'll put that in a second version of this file... I dunno.

;... and as for the things that talk about reading and files?
;... not yet.

(def ssx-load (f)
  (fromfile f (whilet x (read) (eval dss.x))))

(def sl-fn (x)
  (stfu:ssx-load:find file-exists
             (all-choices (fn args
                            (reduce (fn (x f) (f x))
                                    (cons x args)))
                          (list idfn [string src-directory _])
                          (list idfn [string _ ".arc"]))))

(mac sl (x)
  (if (is x 'sl)
      (= x last-sl)
      (= last-sl x))
  `(sl-fn ',(string x)))

;note I'm using the same symbols for ssx-cp, but not for sl.
;note that if you sl a file, you probably won't want to l it,
;and vice versa
(def ssx-cp ()
  (let u (readall:clipboard)
    (do1 (if (len> u 1)
             (do (prn "Multiple expressions cp'd")
                 (map eval:dss u))
             (eval:dss car.u))
         (= cp3 cp2 cp2 cp1 cp1 u))))

