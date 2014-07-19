;I need a reliable, dumb pretty-print.

;... dammit, end up imitating pg.

(def dppr (x (o depth 0) (o nosp t))
  (unless nosp (sp:* depth 2))
  (if atom.x
      write.x
      (do (pr "(")
        (dppr car.x inc.depth t)
        (prn)
        (xloop (x cdr.x)
          (if acons:cdr.x
              (do (dppr car.x inc.depth nil)
                (prn)
                next:cdr.x)
              no:cdr.x
              (do (dppr car.x inc.depth nil)
                (pr ")"))
              (do (dppr car.x inc.depth nil)
                (prn)
                (sp:* inc.depth 2)
                (pr ".")
                (prn)
                (sp:* inc.depth 2)
                (dppr cdr.x inc.depth nil)
                (pr ")")))))))

(def dpprn (x)
  (dppr x)
  (prn))
              