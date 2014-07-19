;I need a reliable, dumb pretty-print.

;... dammit, end up imitating pg.

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
       (do (pr "(")
         (dppr car.x inc.depth t)
         (xloop (x cdr.x)
           (if no.x
               (pr ")")
               atom.x
               (do (prn)
                 (sp:* inc.depth 2)
                 (pr ".")
                 (prn)
                 (dppr x inc.depth nil)
                 (pr ")"))
               (do (prn)
                 (dppr car.x inc.depth nil)
                 next:cdr.x))))))

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