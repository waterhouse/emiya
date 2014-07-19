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
       (is car.x 'bracket-fn)
       (let x cadr.x
         (do (pr "[")
           (dppr car.x inc.depth t)
           (dppr-elms cdr.x inc.depth)
           (pr "]")))
       (do (pr "(")
         (dppr car.x inc.depth t)
         (dppr-elms cdr.x inc.depth)
         (pr ")"))))

(def dppr-elms (x depth)
  (if no.x
      nil
      atom.x
      (do (prn)
        (sp:* depth 2)
        (pr ".")
        (prn)
        (dppr x depth nil)
        nil)
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