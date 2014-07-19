;I need a reliable, dumb pretty-print.

;... dammit, end up imitating pg.

;oh my god...
;to make this stop happening:
; arc> (dppr '(nerf (#t u)))
; (nerfError: "Type: unknown type #t"
;we must do this:
(= functionp $.procedure?
   testify (fn (x)
             (if functionp.x
                 x
                 [is _ x])))
;because (isa x 'fn) -> (is (type x) 'fn)
;and (type #t) -> error.
;not sure how I would want to fix that
;so I am letting it fester.
;terrible.

(def dppr-is-atom (x)
  (or atom.x
      (and (mem car.x '(quote quasiquote unquote unquote-splicing
                        bracket-fn))
           (dppr-is-atom cadr.x))))

(def dppr-is-flat (x)
  (or atom.x
      (and dppr-is-atom:car.x
           dppr-is-flat:cdr.x)))
;that does weird shit in '(dick quote nerf nerf)
;(quote, etc should only be special-cased at head of list)

(def dppr (x (o depth 0) (o nosp t))
  (unless nosp (sp:* depth 2))
  (aif atom.x
       write.x
       (alref '((quote "'")
                (quasiquote "`")
                (unquote ",")
                (unquote-splicing ",@"))
              car.x)
       (do pr.it (dppr cadr.x depth t))
       (is car.x 'bracket-fn)
       (let x cadr.x
         (do (pr "[")
           (dppr car.x inc.depth t)
           (dppr-elms cdr.x inc.depth)
           (pr "]")))
       (is car.x 'fn)
       (do (pr "(")
         (dppr car.x inc.depth t)
         (sp)
         (dppr x.1 inc.depth t)
         (dppr-elms cddr.x inc.depth)
         (pr ")")) ;derf
       (do (pr "(")
         (dppr car.x inc.depth t)
         (dppr-elms cdr.x inc.depth)
         (pr ")"))))

;hmm... if I hack this shit in here...
;then a tail of flat args will get printed.
;that might be nice.

(def dppr-elms (x depth)
  (if no.x
      nil
      atom.x
      (do (pr " . ")
        (dppr x depth t)
        nil)
;      (prn)
;        (sp:* depth 2)
;        (pr ".")
;        (prn)
;        (dppr x depth nil)
;        nil)
      dppr-is-flat.x
      (do (sp)
        (dppr car.x depth t)
        (dppr-elms cdr.x depth)) ;O(n^2 checks in dppr-is-flat
      (do (prn)
        (dppr car.x depth nil)
        (dppr-elms cdr.x depth))))

(def dpprn (x)
  (dppr x)
  (prn))

;all right.  egad.  but that kinda works.
;now to improve.
              
;first with the nice things, _then_ with one-lining things
;and whatever crap.
;ok, first try what happens if you don't indent future lines
;at all to account for '`,@ crap.

;next, brackets, and I think I'll have to accept ...
;neh...
;I think this is probably fine.
;I will probably want to one-line flat lists. (Even if they happen to be
; long.)
;Also maybe the first argument of things, though... let and stuff...
;mmm.

;k, try flat crap next...


;mmm...
;a thing that really annoys me is (fn <args on next line>).
;so I'd probably work on that next...
;also not really sure about that "rest on one line" behavior.
;... time for special-casing fn only. lolz.

;gah, now this shit is really irritating me:
;              ((fn ()
;                  (sp)
;                  (dppr
;                    (car x) depth t)
;the body should be indented one sp less.
;I guess I must ...
