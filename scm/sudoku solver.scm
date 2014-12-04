;To run:
; Open in DrRacket.
; Go Language -> Choose Language... -> Other Languages -> Pretty Big.
; Press Run.

;Usage:
;
;Let's consider this sudoku:
;http://www.websudoku.com/?level=4&set_id=2615932467
;Puzzle looks like:

; 6 . . . . . . 7 .
; . . . . 5 . 9 . 2
; . 4 2 6 . . . . .
; . . . . . 9 4 1 .
; 8 . . . 1 . . . 3
; . 1 6 2 . . . . .
; . . . . . 5 2 3 .
; 4 . 9 . 8 . . . .
; . 7 . . . . . . 1

;We enter it as a string, with all the numbers concatenated, "0" meaning
; an empty square, and a space between each line:
;"600000070 000050902 042600000 000009410 800010003 016200000 000005230 409080000 070000001"
;We parse and solve it with (solve (typnums->sud [that string])),
;and we can display it as well:
;(graph-sud (solve (typnums->sud "600000070 000050902 042600000 000009410 800010003 016200000 000005230 409080000 070000001")))


; 0. When a number is filled in, it goes spartan (the procedure is
;  named go-spartan) and eliminates itself from the possibilities
;  in every slot in the same box, row, and column.
; 1. At the start, I make all the given numbers go spartan.
; 2. I make it look for slots that have only one possibility.
;  When it finds one, it writes that number into the slot and
;  makes it go spartan.
; 3. I make it look for... if, say, there is only one slot that
;  could contain a 4 in a given row, then it fills in the 4
;  and makes it go spartan.
;   Method: Perform 1, then loop 2 and 3 several times. (This sufficed
; to do 40 out of 50 of the puzzles.) After that... Perform a brute-force
; test on possibilities:
; Find a slot that has more than one possibility.  Create a copy
; of the current sudoku, and with that copy, set that slot to
; the first possibility. Recurse and try to solve that sudoku.
; If it finds a contradiction, then it reverts to the first sudoku
; and eliminates that possibility. If it doesn't find a contradiction,
; then it checks whether there's more than one solution by eliminating
; the first possibility from the first sudoku and solving that; if it
; finds that there is more than one solution, then it prints "Very strange."
; Otherwise it returns the solved sudoku.
; So that worked for all the sudokus in the Project Euler question.
; It also worked on a few Mediums and an Evil from websudoku.com.


(load "abbrevs.scm")
(load "math.scm")

;This stuff is basically for parsing the input.
(def char-position (char xt)
  (def slave (n char)
    (if (is n (string-length xt))
        #f
        (char=? (string-ref xt n) char)
        n
        (slave (+ n 1) char)))
  (slave 0 (if (string? char) (string-ref char 0) char)))

(def separate-string (xt separator);would want to make it optional to keep the separator characters in the resulting shite
  (def slave (xt total)
    (let u (char-position separator xt)
      (if u
          (slave (substring xt (1+ u)) (cons (substring xt 0 u) total))
          (rev (cons xt total)))))
  (slave xt nil))


(def stringed-number->list (n)
  (map [string->number (string _)] (string->list n)))

(def typnums->sud (xx)
  (vectorize (map [map [if (is _ 0) '(1 2 3 4 5 6 7 8 9) _]
                       _]
                  (map stringed-number->list (separate-string xx #\space)))))


(def jazz->numbers (jazz)
  (map stringed-number->list (map [substring _ 0 9](but-every-n (separate-string jazz #\newline)
                                                                10
                                                                0))))
(def numbers->numses (hh)
  (into-groups (map [map [if (is _ 0) '(1 2 3 4 5 6 7 8 9) _]
                         _]
                    hh)
               9))

(def vectorize (nums)
  (list->vector (map list->vector nums)))

(def shite->sudokus (shite)
  (map vectorize
       (numbers->numses (jazz->numbers shite))))


;a sudoku grid is a 9-vector of 9-vectors.  solved numbers are numbers, while possibilities are lists.
;find the sum of the 3-digit numbers found in the top left corner of each solution grid; for example, 483 is the 3-digit number found in the top left corner of the solution grid above.          

(qmac sudoku-ref (sud i j)
  (vector-ref (vector-ref sud (1- i)) (1- j)))
(abbrev sr sudoku-ref)
(qmac sudoku-set! (sud i j val)
  (vector-set! (vector-ref sud (1- i)) (1- j) val))
(abbrev ss! sudoku-set!)
(qmac eliminate-possibility! (sud i j poss)
  (when (list? (sr sud i j))
    (ss! sud i j (rem poss (sr sud i j)))))
(abbrev elim eliminate-possibility!)

(def num? (thing)
  (if (list? thing)
      #f
      thing))

(qmac to-row (sud proc i)
  (for j 1 9
    (proc sud i j)))
(qmac to-column (sud proc j)
  (for i 1 9
    (proc sud i j)))

(qmac elim-within-row (sud i elm)
  (for j 1 9
    (elim sud i j elm)))
(qmac elim-within-column (sud j elm)
  (for i 1 9
    (elim sud i j elm)))
(def upper-left-coordinates-of-box (box)
  (list (1+ (* 3 (quotient (1- box) 3))) (1+ (* 3 (remainder (1- box) 3)))))
(abbrev ulcob upper-left-coordinates-of-box)
(qmac elim-within-box (sud box elm)
  (with (u (ulcob box) ii (car u) jj (cadr u))
    (for i ii (+ ii 2)
      (for j jj (+ jj 2)
        (elim sud i j elm)))))
;boxes:
;1 2 3
;4 5 6
;7 8 9

(def in-what-box (i j)
  (+ (quotient (1- j) 3) (* 3 (quotient (1- i) 3)) 1))


(qmac go-spartan (sud i j)
  (let u (sr sud i j)
    (elim-within-row sud i u)
    (elim-within-column sud j u)
    (elim-within-box sud (in-what-box i j) u)))

(def kill-at-start (sud)
  (for i 1 9
    (for j 1 9
      (when (num? (sr sud i j))
        (go-spartan sud i j))))
  sud)

(def put-down-singles (sud)
  (for i 1 9
    (for j 1 9
      (when (and (list? (sr sud i j))
                 (not (no (sr sud i j)))
                 (no (cdr (sr sud i j))))
        (ss! sud i j (car (sr sud i j)))
        (go-spartan sud i j)))))

(abbrevs vr vector-ref vs! vector-set!)


(def find-single-in-row (sud i)
  ;like, if there's only one slot with 2 as a poss.
  (let u (make-vector 10 nil)
    (for j 1 9
      (when (list? (sr sud i j))
        (each [vs! u _ (cons j (vr u _))]
              (sr sud i j))))
    ;u now contains the number of n's in (vr u); it also has 0...
    (for k 1 9
      (let h (vr u k)
        (when (and (not (no h)) (no (cdr h)))
          (ss! sud i (car h) k)
          (go-spartan sud i (car h)))))
    ))

(def find-single-in-column (sud j)
  (let u (make-vector 10 nil)
    (for i 1 9
      (when (list? (sr sud i j))
        (each [vs! u _ (cons i (vr u _))]
              (sr sud i j))))
    (for k 1 9
      (let h (vr u k)
        (when (and (not (no h)) (no (cdr h)))
          (ss! sud (car h) j k)
          (go-spartan sud (car h) j))))
    ))

(def find-single-in-box (sud box)
  (with (u (ulcob box) ii (car u) jj (cadr u))
    (let u (make-vector 10 nil)
      (for i ii (+ ii 2)
        (for j jj (+ jj 2)
          (when (list? (sr sud i j))
            (each [vs! u _ (cons (list i j) (vr u _))]
                  (sr sud i j)))))
      (for k 1 9
        (let h (vr u k)
          (when (and (not (no h)) (no (cdr h)))
            (ss! sud (caar h) (cadar h) k)
            (go-spartan sud (caar h) (cadar h)))))
      )))

(def find-singles-everywhere (sud)
  (for mm 1 9
    (find-single-in-row sud mm)
    (find-single-in-column sud mm)
    (find-single-in-box sud mm)))



(def print-sud (sud)
  (for i 1 9
    (for j 1 9
      (pr (let u (sr sud i j)
            (if (list? u)
                "_"
                u))
          " "))
    (newline))
  (newline)
  sud)
(def db-sud (sud)
  (for i 1 9
    (for j 1 9
      (pr (sr sud i j) " "))
    (newline))
  (newline))

(require (lib "graphics.ss" "graphics"))
(open-graphics)

;(= vp (open-viewport "sudoku" 500 500))

(def graph-sud (sud)
  (let vp (open-viewport (symbol->string (gensym)) 300 300)
    ((clear-viewport vp))
    (for i 1 3
      (for j 1 3
        ((draw-rectangle vp) (make-posn (- (* 90 j) 61) (- (* 90 i) 61))
                             90
                             90)))
    
    (for i 1 9
      (for j 1 9
        ((draw-string vp) (make-posn (+ 10 (* j 30)) (+ 20 (* i 30))) ([if (number? _) (number->string _) ""] (sr sud i j)))))))

;7,013,809,609
;(graph-sud (try-to-do (car suds)))



(def contradiction? (sud)
  (not (true-within? (fn (i) (true-within? (fn (j) (not (no (sr sud i j)))) 1 9)) 1 9)))

(def new-sudoku ()
  (list->vector (genlist [list->vector (genlist [zero? 1] 1 9)] 1 9)))

(def copy-sudoku (sud)
  (let u (new-sudoku)
    (for i 1 9
      (for j 1 9
        (ss! u i j (sr sud i j))))
    u))
(def find-poss (sud i j);find slot with possibilities
  (if (list? (sr sud i j))
      (list i j)
      (is j 9)
      (find-poss sud (1+ i) 1)
      (find-poss sud i (1+ j))))


(def twbf (sud);try with brute force
  (normal-work sud)
  (if (solved? sud)
      sud
      (contradiction? sud)
      #f
      (with (place (find-poss sud 1 1) ii (car place) jj (cadr place) posses (sr sud ii jj))
        (let sud-poss (copy-sudoku sud)
          (ss! sud-poss ii jj (car posses))
          (go-spartan sud-poss ii jj)
          (let u (twbf sud-poss)
            (if (not u)
                (do (elim sud ii jj (car posses))
                  (twbf sud))
                (solved? u)
                (if (let just-check (copy-sudoku sud)
                      (elim just-check ii jj (car posses))
                      (twbf just-check))
                    (do (prn "Very strange.") #f)
                    u)))))))


(= thing (kill-at-start (typnums->sud
                         "070049650 040037200 012060000 800003900 000020000 001700006 000080720 009370060 067950040")))


(def do-all-i-can (sud)
  (put-down-singles sud)
  (find-singles-everywhere sud)
  sud)

(def normal-work (sud)
  (repeat 6 (do-all-i-can sud))
  sud)

;(def try-to-do (sud)
;  (kill-at-start sud)
;  (while (not (solved? sud))
;    (do-all-i-can sud)
;    (print-sud sud)
;    (newline))
;  sud)
;(def do-with-narration (sud)
;  (print-sud sud)
;  (kill-at-start sud)
;  (print-sud sud)
;  (while (not (solved? sud))
;    (do-all-i-can sud)
;    (db-sud sud))
;  sud)
;
;(def try (sud)
;  (kill-at-start sud)
;  (repeat 6 (do-all-i-can sud))
;  (graph-sud sud)
;  sud)
;
;(def cautious-try (sud)
;  (kill-at-start sud)
;  (repeat 6 (do-all-i-can sud))
;  sud)

(def solve (sud)
  (kill-at-start sud)
  (twbf sud))

(def silence (hh)
  (do hh (void)))

(def true-within? (pred a b)
  (or (> a b)
      (and (pred a)
           (true-within? pred (1+ a) b))))
(def solved? (sud)
  (true-within? [true-within? (fn (x) (not (list? (sr sud x _)))) 1 9] 1 9))



;(load "throwaway.scm")
;(= suds (shite->sudokus jazz))


;(sum-list (map (compose [sum (fn (j) (* (expt 10 (- 3 j)) (sr _ 1 j))) 1 3]
;                         solve)
;               suds))
