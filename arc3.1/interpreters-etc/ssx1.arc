;ssyntax, my style.
;As documented on a piece of paper...
;First we decompose it, then we go left to right.

;1. a?b&c:d.e!f -> (a? ? b & c : d . e ! f) ;the separators are prob'ly chars
;   (Note that this list will necessarily be alternating things,
;    and I need not worry about uniqueness/what if b happens to be 'and.)
;2. Reduce from left to right.
; '(a ? b ...) -> `(a ,(next '(b ...)))
; '(a : b ...) -> (next '((compose a b) ...))
; '(a & b ...) -> (next '((andf a b) ...))
; '(a . b ...) -> (next '((a b) ...))
; '(a ! b ...) -> (next '((a 'b) ...))

;Wonderfully, this yields exactly the behaviors I've wanted.

;Then there's the question of when ((compose mac1 mac2) x y) gets turned
;into (mac1 (mac2 x y)).
;I think it should not happen only as a result of ssexpansion.
;...
;I guess, in particular,
;(let y compose ((y mac1 mac2) a b)) should work.
;If it's done at all, that is.
;Which, uh, ...
;Doesn't seem to work too well... how does that happen?
;(compose a b) should return something.

;...
;I guess the other option is to make it become
;(fn gargs (mac1 (apply mac2 gargs)))
;where, note, (apply mac1 xs) = (mac1 . xs).
;Fug.
;This would probably not work well.
;...
;This "compose" BS is something that works well in the absence of first-class
;macros.
;Sigh.
;I guess I can have a "compose" form return a disjoint type.
;A special kind of function.
;...

;...
;Fug.
;Nope, reverse all that.
;This is ssyntax.
;Only compose's created by this shall be de-compose'd.
;...
;quote? quasiquote?
;fug.
;neh.

;well.
;for the record, I shall do the full initial version.

(def is-ssx (x) ;careless; some things will expand to themselves
  (and (isa x 'sym)
       (find [in _ #\: #\? #\& #\. #\!] string.x)))

(def dss (x)
  (if acons.x
      (cons (dss car.x) (dss cdr.x))
      is-ssx.x
      ssx.x
      x))

;blah? remains.
;single chars remain themselves.
;and :whatever is an escape.

(def ssx (x)
  (let s string.x
    (if (is 1 len.s) ;and note empty string 
        x
        (is s.0 #\:)
        (symb:cut s 1)
        (ssx-reduce ssx-list.s))))

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








