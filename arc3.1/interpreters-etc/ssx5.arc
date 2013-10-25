;ssyntax, my style.
;As documented on a piece of paper...
;First we decompose it, then we go left to right.

;As discussed earlier... now...
;We shall avoid generating composes in the cases where we can
;eliminate them...

;I had considered having (a?b c) be like (a? (b c)),
;but I think not.
;Use a fucking colon, it's not too bad.

(def is-ssx (x) ;careless; some things will expand to themselves
  (and (isa x 'sym)
       (find ssx-char string.x)))

(def dss-head (x)
  (if acons.x
      (if (is-ssx car.x)
          (ssx-call car.x (dss-tail cdr.x))
          (cons (dss-head car.x) (dss-tail cdr.x)))
      is-ssx.x
      ssx-term.x
      x))

(def dss-tail (x)
  (if acons.x
      (cons (dss-head car.x) (dss-tail cdr.x))
      is-ssx.x
      ssx-term.x
      x))

(= dss dss-head)

;blah? remains.
;single chars remain themselves.
;and :whatever is an escape.

(def ssx-char (x)
  (in x #\: #\? #\& #\. #\!))

;a?[char]b => 
(def ssx-list (s)
  (xloop (i 0)
    (if (is i len.s)
        (err "Empty substring at end of ssyntax" s i)
        (let j i
          (while (and (< j len.s)
                      (no:ssx-char s.j))
            ++.j)
          (if (is j len.s)
              (list:symb:cut s i j)
              (isnt s.j #\?)
              (if (is i j)
                  (err "Empty substring in ssyntax" s i j)
                  (cons (symb:cut s i j)
                        (cons s.j (next:+ j 1))))
              (do (while (and (< j len.s)
                              (is s.j #\?))
                    ++.j)
                (if (is j len.s)
                    (list (symb:cut s i j))
                    (ssx-char s.j)
                    (cons (symb:cut s i j)
                          (cons s.j (next:+ j 1)))
                    (cons (symb:cut s i j)
                          (cons #\? (next j))))))))))

;ok, it seems like...
;all I need to do is go from right to left looking for
;compose operations,
;and when I've exhausted them, I just need to go left
;to right like usual.

;... um, (a?b:c d) ?
;not quite.
;must ... dick...
;we must first ... um...
;oh boy. well, yeah. should be ok...
;fix in next try.

;oh man, turns out all we need to do is check for ?.
;if there is one, then it will be ((blah? whatever) xs).
;no opportunity for composition.
;ok.

;...
;all terrible.
;gar.

;ok, next strategy.
;do just do things.
;and then deconstruct, afterward, forms that happen to be like
;((compose ...) ...).
;this will be achieved exactly.
;in particular, results of crap will be cached...

;ok, I am making : ssyntax for the empty symbol.
;also I should avoid empty sub-things.

(def ssx-call (f args)
  (let s string.f
    (if (is s.0 #\:)
        (cons (symb:cut s 1) args)
        (is 1 len.s)
        f
        (let (x n) (ssx-reduce ssx-list.s)
          (ssx-clean x args n)))))
           
(def ssx-term (x)
  (let s string.x
    (if (is s.0 #\:)
        (symb:cut s 1)
        (is 1 len.s)
        x
        (car:ssx-reduce ssx-list.s))))

;partial eval should make this cons less

;so this returns (list expr n)
;where n is the number of (compose f g) things that make up the
;outermost layer.
(def ssx-reduce (xs)
  (xloop (xs xs n 0)
    ;(prsn 'ssx-reduce xs n)
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

;all right, I think this actually works...

;oh man. yep.
;next is cleanup.




