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
;but I think not. Just use a colon.

;--Oh and one more thing (dammit).
;Maybe two.
;Must be careful to not reach within $.

(def is-ssx (x) ;careless; some things will expand to themselves
  (and ($.symbol? x)
       (find ssx-char string.x)))

(def dss-head (x)
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

;ok, the next remaining problem seems to be !sym syntax.

(def dss-tail (x)
  (if acons.x
      (cons (dss-head car.x) (dss-tail cdr.x))
      is-ssx.x
      ssx.x
      x))

(= dss dss-head)

;blah? remains.
;single chars remain themselves.
;and :whatever is an escape.

(def ssx-char (x)
  (in x #\: #\? #\& #\. #\!))

;need "0" to become a number and "s" to become a symbol...
;reverse of "str" (lolz)
(def rts (s)
  (if (is 0 len.s)
      (symb "")
      (read s)))

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

(def ssx-list (x)
  (let s string.x
    (if (is s.0 #\:)
        (list:rts:cut s 1)
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
                              (no:ssx-char s.j))
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
                              (ssx-char s.j)
                              (cons (rts:cut s i j)
                                    (cons s.j (next:+ j 1)))
                              (cons (rts:cut s i j)
                                    (cons #\? (next j)))))))))))))
;strategy.
;do just do things.
;and then deconstruct, afterward, forms that happen to be like
;((compose ...) ...).
;this will be achieved exactly.
;in particular, results of crap will be cached...

;ok, I am making : ssyntax for the empty symbol.
;also I should avoid empty sub-things.

(def ssx (x)
  (let (x xn) ssx-term.x
    x))

#;(def ssx-call (f args)
  (let (x xn) ssx-term.f
    (ssx-clean x args xn)))

(def ssx-term (x)
  (ssx-reduce ssx-list.x))

;partial eval should make this cons less

;so this returns (list expr n)
;where n is the number of (compose f g) things that make up the
;outermost layer.
(def ssx-reduce (xs)
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

(def ssx-clean (f xs n)
  (if (is n 0)
      (cons f xs)
      (let (cmp a b) f
        (ssx-clean a (list:cons b xs) dec.n))))
