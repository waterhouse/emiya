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
        (prsn "WTF" s i)
        (let j i
          (while (and (< j len.s)
                      (no:ssx-char s.j))
            ++.j)
          (if (is j len.s)
              (list:symb:cut s i j)
              (isnt s.j #\?)
              (cons (symb:cut s i j)
                    (cons s.j (next:+ j 1)))
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

(def ssx-call (f args)
  (let s string.f
    (if (is 1 len.s)
        x
        (is s.0 #\:)
        (cons (symb:cut s 1) args)
        (xloop (rxs (rev ssx-list.s) args args)
          (if (and cdr.rxs (is cadr.rxs #\:))
              (next cddr.rxs (list (cons car.rxs args)))
              (cons (ssx-reduce rev.rxs) args))))))

(def ssx-term (x)
  (let s string.x
    (if (is 1 len.s)
        x
        (is s.0 #\:)
        (symb:cut s 1)
        (ssx-reduce ssx-list.s))))

;partial eval should make this cons less
(def ssx-reduce (xs)
  (let next ssx-reduce
    (if cdr.xs
        (let (a directive b . rest) xs
          (case directive
            #\? (list a (next:cons b rest))
            #\: (next:cons `(compose ,a ,b) rest)
            #\& (next:cons `(andf ,a ,b) rest)
            #\. (next:cons `(,a ,b) rest)
            #\! (next:cons `(,a ',b) rest)))
        car.xs)))








