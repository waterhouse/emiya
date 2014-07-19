;I need a reliable, dumb pretty-print.

;... dammit, end up imitating pg.

(def dppr (x (o depth 0) (o nosp t))
  (unless nosp (sp:* depth 2))
  (if atom.x
      write.x
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