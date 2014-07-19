;I need a reliable, dumb pretty-print.

;... dammit, end up imitating pg.
;NOT ANYMORE

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

;hmm, two things to fix.
;one: dicks on one line.
;two: (dppr '[])
;also I would like to unify things...
;mmm. can I dppr-elms ev'thing in a list.
;prob'.
;just that the ind of the first element
;must be a little phunky.
;also fn will ...
;hmmph.
;maybe I can have flats followed by complex.
;neh... major indentation.
;mmm.
;do want to special-case fn.
;and maybe other shit.
;hmm...
;proper handling of "let"...
;(let some-variable
;     (giant dicks and ass)
;  (expr))
;^ ^  ^
;0 2  5
;I could really construct a list of (expr ind) things.
;would probably be good...
;and methinks it's fine to not account for ind of prefixed `',@ crap.
;I think I prefer it that way.

;hmm... fn specifically wants dick on the same line.
;let does not necessarily.
;mmm.

;this special handling of crap will probably go terribly
;for complex arglists with multiple-lined expressions.
;that shall suck for now.

;wootz. now that I've done stuff in certain ways,
;I can remove the nosp argument.
;and clean up other crap.

(def map-imp (f xs) ;improper
  (if no.xs
      nil
      atom.xs
      f.xs
      (cons f:car.xs (map-imp f cdr.xs))))

;should genuinely indent complex arglists in case they occur
;(fn ((nub)
;     x y)
;^    ^
;0    5 ;5-2=3
;think later about doing thot for def and wtvr as well

(def dppr (x (o ind 0))
  (aif atom.x
       write.x
       (alref '((quote "'")
                (quasiquote "`")
                (unquote ",")
                (unquote-splicing ",@"))
              car.x)
       (do pr.it (dppr cadr.x ind))
       (is car.x 'bracket-fn)
       (let x cadr.x
         (do (pr "[")
           (dppr-list x (map-imp [+ _ ind] '(1 . 2)))
           (pr "]")))
       (is car.x 'fn)
       (do (pr "(")
         (dppr car.x 1) ;no matter
         (sp)
         (dppr-list cdr.x (map-imp [+ _ ind] '(3 . 2)) nil)
         (pr ")")) ;derf
       (is car.x 'let)
       (do (pr "(")
         (dppr-list x (map-imp [+ _ ind] '(4 4 4 . 2)))
         (pr ")"))
       (mem car.x '(def mac))
       (do (pr "(")
         (each n '(0 1)
           (dppr x.n (+ ind 1))
           (sp))
         (dppr-list (drop 2 x) (+ ind 1) nil)
         (pr ")"))
       (do (pr "(")
         (dppr-list x (cons (+ ind 1) (+ ind 2)))
         (pr ")"))))

;assumes sp'd, of course
;lastpr = nil, flat, or curve
(def dppr-list (xs inds (o lastpr nil))
  (if no.xs
      nil
      (and acons.xs no:dppr-is-atom:car.xs) ;curve
      (let ind (if acons.inds pop.inds inds)
        (unless (is lastpr nil) (prn) (sp ind))
        (dppr pop.xs ind) ;dumbass forgot dick
        (dppr-list xs inds 'curve))
      ;otherwise flat
      (let ind (if acons.inds pop.inds inds)
        (when (is lastpr 'curve) (prn) (sp ind))
        (when (is lastpr 'flat) (sp))
        (when atom.xs (pr ". "))
        (dppr (if acons.xs car.xs xs) ind) ;no popping, must keep info
        (when acons.xs (dppr-list cdr.xs inds 'flat)))))

;ok, I think I need a more sophisticated model now.
;basically:
;each thing will either get printed on the current line,
;in which case any information about how it "should" be indented
;is irrelevant,
;or we will start a new line and print it on that line.
;in that case, we want to know how far it should be indented;
;we will print exactly that many spaces.
;my current model can be understood in this model thus:
;"if this is the first element printed, no need for newline.
; if the prev elm printed was flat and this is flat, no need for newline.
; if prev elm was curvy and this is flat, newline;
; if prev elm was flat and this is curvy, newline.
; if prev elm was curvy and this is curvy, newline."
;also, " . " <atom> is treated as one flat elm.
;so...
;each elm should know how far it should be indented if need for nl.
;also, the thing should prob' keep track of last elm printed.
;finally, this thing with fn...
;I could probably actually just print 'fn, sp, and tell the thing
;that the last elm was nil.
;no need yet for a third list containing instructions about
;whether each elm should be "no abs. do not start a new line here".

;hmm... if I hack this shit in here...
;then a tail of flat args will get printed.
;that might be nice.

;mmm... bwahaha.
;we shall have a separate (but equal) list of inds.
;(not actually equal)
;that list of inds shall be improper.
;the terminating atom will be used as ind for all elms.
;oh dammit
;I think I need extra ind...
;ok, we assume we've been sp'd up to "ind".
;or higher...
;hmmph...

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

;AWP NAWP
;    ((fn ()
;       (atomic-invoke
;         (fn nil
;           ((fn (gs13339 gs13341 gs13342)
;              ((fn (gs13340)
;                 (sref gs13339 gs13340 gs13341)) gs13342)) u a
;             (/ aa 8))))))
;must fix; eh, I see how it could be easily fixed

;next, we shall do def and mac or smthg
;and clean up.

