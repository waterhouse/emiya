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

(def dppr (x (o ind 0) (o nosp t))
  (unless nosp (sp ind))
  (aif atom.x
       write.x
       (alref '((quote "'")
                (quasiquote "`")
                (unquote ",")
                (unquote-splicing ",@"))
              car.x)
       (do pr.it (dppr cadr.x ind t))
       (is car.x 'bracket-fn)
       (let x cadr.x
         (do (pr "[")
           (dppr car.x (+ ind 1) t)
           (dppr-elms cdr.x (+ ind 2))
           (pr "]")))
       (is car.x 'fn)
       (do (pr "(")
         (dppr car.x (+ ind 1) t)
         (sp)
         (dppr x.1 (+ ind 2) t)
         (dppr-elms cddr.x (+ ind 2))
         (pr ")")) ;derf
       (do (pr "(")
         (dppr car.x (+ ind 1) t) ;bwah, here we go
         (dppr-elms cdr.x (+ ind 2))
         (pr ")"))))

;hmm... if I hack this shit in here...
;then a tail of flat args will get printed.
;that might be nice.

(def dppr-elms (x ind)
  (when (and acons.x
             (dppr-is-atom car.x))
    (sp))
  (if #;dppr-is-flat.x
      #;(xloop (x x)
        (if no.x
            nil
            atom.x
            (do (pr " . ")
              (dppr x ind t)
              nil)
            (do (sp)
              (dppr car.x ind t)
              (next cdr.x))))
      ;then we shall find the tail that is flat
      ;and print curvy args on each line
      ;and the flat args on a line at the end
      ;but if no flat args, then don't print the
      ;unnec. line
      ;... I'm going to write code that doesn't exactly
      ;do that, and see how the results look
      ;... hmm...
      ;neh... ok, um...
      ;separate into groups.
      ;alternating (curvy arg) and (0 or more flat args).
      ;bwahaha.
      (xloop (x x)
        (let ys nil
          (while (and acons.x (dppr-is-atom car.x))
            (push pop.x ys))
          (between u rev.ys (sp) (dppr u ind t))
          (if no.x
              nil
              atom.x
              (do (pr " . ") (dppr x ind t) nil)
              ;curvy
              (do (prn)
                (dppr car.x ind nil)
                (when (and acons.x
                           (acons cdr.x)
                           (dppr-is-atom cadr.x))
                  (prn)
                  (sp ind))
                (next cdr.x)))))))
      

#;(def dppr-elms (x ind)
  (if no.x
      nil
      atom.x
      (do (pr " . ")
        (dppr x ind t)
        nil)
;      (prn)
;        (sp:* ind 2)
;        (pr ".")
;        (prn)
;        (dppr x ind nil)
;        nil)
      dppr-is-flat.x
      (do (sp)
        (dppr car.x ind t)
        (dppr-elms cdr.x ind)) ;O(n^2 checks in dppr-is-flat
      (do (prn)
        (dppr car.x ind nil)
        (dppr-elms cdr.x ind))))

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
;                    (car x) ind t)
;the body should be indented one sp less.
;I guess I must ...

;there we go.

;mmm... I think I can have "rest on one line, _after_
; a newline if there have been dicks beforehand" behavior.

;ok, this... seems to work.
;I kinda still want (div (len xs) 2) to print on one line.
;however, I suspect I might do ss-contraction to do that...
;bwahaha. hmm.
;that would work pretty well except for arglists.
;would I pass an extra argument to dppr to say "don't sscontract"?
;derf.
;or use something other than dppr to print the arglist?
;(come to think of it... haven't really addressed "complex arglists"
; in de-macro.  hmmph.  annoying.  oh well.)
;for now: ...
;ok, let's try ss-contracting... hmmmm...
;doesn't work well for calls to macros that happen also to
;pull things into arglists, or other places.
;e.g. (obj (a 1) (derf))
;if that (a 1) becomes a.1, we get suck.
;mmph.
;only really works on de-macro'd stuff.
;bwahaha.
;k, just cleanup, I think.
