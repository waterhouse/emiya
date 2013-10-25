; Pretty-Printing.  Spun off 4 Aug 06.

; todo: indentation of long ifs; quasiquote, unquote, unquote-splicing
           
(= bodops* (fill-table (table)
   '(let 2 with 1 while 1 def 2 fn 1 rfn 2 afn 1 mac 2 define 1 whiler 4
     when 1 unless 1 after 1 whilet 2 for 3 each 2 whenlet 2 awhen 1
     on 2 lambda 1 λ 1
     whitepage 0 tag 1 form 1 aform 1 aformh 1 w/link 1 textarea 3
   )))

(= oneline* 35) ; print exprs less than this long on one line

(= ppr-uwrite (fn (x) ;lolz a name conflict
            (aif (or atom.x atom:cdr.x)
                write.x
                (and no:cddr.x
                     (assoc car.x '((quote "'") ;###FIX###
                                    (quasiquote "`")
                                    (unquote ",")
                                    (unquote-splicing ",@"))))
                (do (pr cadr.it) (write cadr.x))
                (and (is car.x 'fn) ;gah, bracket-fn makes this not even very good
                     (iso cadr.x '(_))
                     acons:cddr.x
                     no:cdr:cddr.x)
                (do (pr "[") write:car:cddr.x (pr "]"))
                write.x)))
                

; If returns nil, can assume it didn't have to break expr.
  
(def ppr (expr (o col 0) (o noindent nil))
  (aif (or (atom expr) (dotted expr)) ;#aif
       (do (unless noindent (sp col))
           (write expr)
           nil)
      (and acons:cdr.expr
           no:cddr.expr
           (assoc car.expr '((quote "'") ;###FIX###
                             (quasiquote "`")
                             (unquote ",")
                             (unquote-splicing ",@"))))
      (do (unless noindent (sp col)) ;#add
          (pr cadr.it)
          (ppr (cadr expr) (+ col len.it) t))
;      (is (car expr) 'quote) 
;       (do (unless noindent (sp col))
;           (pr "'")
;           (ppr (cadr expr) (+ col 1) t))
      (bodops* (car expr))
       (do (unless noindent (sp col))
           (let whole (tostring (ppr-uwrite expr)) ;ppr-uwrite
             (if (< (len whole) oneline*)
                 (do (pr whole) nil)
                 (ppr-progn expr col noindent))))
      (do (unless noindent (sp col))
          (let whole (tostring (ppr-uwrite expr)) ;ppr-uwrite
            (if (< (len whole) oneline*)
                (do (pr whole) nil)
                (ppr-call expr col noindent))))))

(def ppr-progn (expr col noindent)
  (lpar)
  (let n (bodops* (car expr))
    (let str (tostring (write-spaced (firstn n expr)))
      (unless (is n 0) (pr str) (sp))
      (ppr (expr n) (+ col (len str) 2) t))
    (map (fn (e) (prn) (ppr e (+ col 2)))
         (nthcdr (+ n 1) expr)))
  (rpar)
  t)
             
(def ppr-call (expr col noindent)
  (lpar)
  (let carstr (tostring (ppr-uwrite (car expr))) ;ppr-uwrite
    (pr carstr)
    (if (cdr expr)
        (do (sp)
            (let broke (ppr (cadr expr) (+ col (len carstr) 2) t)
              (pprest (cddr expr)
                      (+ col (len carstr) 2)
                      (no broke)))
            t)
        (do (rpar) t))))
       
(def pprest (exprs col (o oneline t))
  (if (and oneline
           (all (fn (e)
                  (or (atom e) (and (is (car e) 'quote) (atom (cadr e)))))
                exprs))
      (do (map (fn (e) (pr " ") (ppr-uwrite e)) ;ppr-uwrite
               exprs)
          (rpar))
      (do (when exprs
            (each e exprs (prn) (ppr e col)))
          (rpar))))
                
(def write-spaced (xs)
  (when xs
    (ppr-uwrite (car xs)) ;ppr-uwrite
    (each x (cdr xs) (pr " ") (ppr-uwrite x)))) ;ppr-uwrite
  
(def sp ((o n 1)) (repeat n (pr " ")))
(def lpar () (pr "("))
(def rpar () (pr ")"))

