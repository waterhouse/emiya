;"light and darkness", and then it seems "and darkness" -> "of darkness" in my mind.

;Time to translate butt into using a stack (with return addresses on the stack, as fns).

;;OH MY GOOOOOOOOOOOOOD
;;I can "call" like this:
;(blah)
;(call x)
;(blah)
;=
;(blah)
;(push cdr.the-pc the-stack)
;(x)
;(blah)


(= the-pc nil
   the-stack nil
   labels (table))

(def install (body)
  (xloop (xs rev.body ys nil)
    (if no.xs
        nil
        (isa car.xs 'sym)
        (do (= (labels car.xs) ys)
          (next cdr.xs ys))
        (next cdr.xs (cons car.xs ys)))))

(def jump (lab)
  (= the-pc labels.lab))

(mac buh body
  `(install ',body))

(def run (lab)
  (jump lab)
  (while the-pc
    (eval pop.the-pc)))

(def step ()
  (eval pop.the-pc))

(= ustep-table (table))
(= ustep-list nil)
(def ustep ()
  (do1 (step)
       (each x ustep-list
         (when (bound x)
           (unless (is symbol-value.x ustep-table.x)
             (prsn x '-> symbol-value.x)
             (= ustep-table.x symbol-value.x))))))
(mac watch args
  `(each x ',args
     (pushnew x ustep-list)))
(mac unwatch args
  `(= ustep-list (rem [mem _ ',args] ustep-list)))

(def ustep-restore ()
  (each x ustep-list
    (= symbol-value.x ustep-table.x)))

(buh gcd
     (if (is b 0)
         (jump 'gcd-done))
     (= a (mod a b))
     (swap a b)
     (jump 'gcd)
     gcd-done
     (= return-value a))


;;All right, so.
;;Procedures are in fact permitted to accept arguments.
;;However, if they call anything else, those lexical bindings will be gone
;;by that time.
;(mac ddef (name args . body)
;Neh, neh.
;Eh, yeh.
;Um, but I'd like to see how else I can do stuff...
;Mmm.

;ARGLIST is a variable.
;VALUE is a variable.  I might have it displace ARGLIST.
(= arglist nil)

(def make-assignments (vars vals)
  (xloop (uvars vars uvals vals)
    (if no.uvars
        (if uvals
            (err "make-assignments: some mismatch" vars vals uvars uvals))
        (isa uvars 'sym)
        (= symbol-value.uvars uvals)
        acons.uvars
        (if acons.uvals
            (do (next car.uvars car.uvals)
              (next cdr.uvars cdr.uvals))
            (err "make-assignments: some mismatch" vars vals uvars uvals))
        (err "What the fuck are you trying to bind?" vars vals uvars uvals))))


(mac ddef (name args . body) ;time to write ddef after using it all below times
  (w/uniq gargs
    `(do (install '(,name ,@body))
       (= ,name (fn ,gargs
                  (make-assignments ',args ,gargs)
                  (push nil the-stack)
                  (run ',name)
                  return)
          ,(symb name '-setup)
          (fn ,gargs
            (make-assignments ',args ,gargs)
            (push arc-return the-stack)
            (jump ',name))))))

(= arc-return '((prn return)))
;So the fucking annoying thing is that I need to convert IFs into GOTOs
;when I need to save things.
;Oh and I need to explicity say "return some value".
;... With the previous thing, I just modified some global variables.
;It'd be nice to continue doing that.  Rather than establish some
;global calling convention.
;With fib, it was so nice, because "n", the name for the arg, was also
;easily obviously the name of the return value.
;Eh, by default, most things will set the "return" thing.  Yes.
;Mmmhmm, explicit jumps and setting stuff and stuff.
;Later I'll have to use car/cdr with fromspace tests, and probably in fact
;with "this is an integer, used as an index into some "memory" table".
(ddef eval-if (xs env)
  (if no.xs
      (do (= return nil) (= the-pc pop.the-stack)) ;return nil, lolz
      no:cdr.xs
      (do (= x car.xs) (jump 'ueval))) ;fifth, but sameish
  (push env the-stack)
  (push cdr.xs the-stack)
  (= x car.xs) ;sixth...
  (push cdr.the-pc the-stack)
  (jump 'ueval) ;sets "return"
  (= cdr-xs pop.the-stack env pop.the-stack)
  (if return
      (do (= x car.cdr-xs) (jump 'ueval))) ;fourth names error...
  (= xs cdr.cdr-xs)
  (jump 'eval-if))

(mac save args
  `(do ,@(map (fn (x) `(push ,x the-stack)) args)))
(mac restore args
  `(= ,@(mappend (fn (x) `(,x pop.the-stack)) args)))

(ddef uapply-loop (env exprs)
  (if no.exprs
      (do (= return nil) (= the-pc pop.the-stack)))
  (save env cdr.exprs)
  (= x car.exprs)
  (push cdr.the-pc the-stack)
  (jump 'ueval) ;x env ;goddammit names
  (restore exprs env)
  (if exprs
      (jump 'uapply-loop))
  (= the-pc pop.the-stack))

;this can be a plain procedure, because it does not malloc at all or do any evaluation
;... ... ... FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF-
;never mind about that
;(ddef join-envs (env arglist xs)
;  (if no.arglist
;      (if no.xs env (err "Too many arguments:" xs)) ;kind of strict
;      acons.arglist
;      (if no:acons.xs
;          (err "Arg!" arglist xs)
;          (join-envs (join-envs env car.arglist car.xs) cdr.arglist cdr.xs))
;      (isa arglist (quote sym))
;      (cons (list arglist xs)
;            #;(rem (bracket-fn (is car._ arglist)) env)
;            env)
;      (err "What kind of argument is this?" arglist)))
;defining this shit later.

;time to bite the bullet
(def call (x)
  (push the-pc the-stack) ;no cdr here because (call blah) is one expr
  (jump x))

(ddef eval-= (xs env)
  (save xs env)
  (= x cadr.xs) ;x. names, names, be careful
  (call 'ueval)
  (restore env xs)
  (aif (assoc car.xs env) ;assoc will not trigger GC flip; it accesses, not allocs
       ;geez, what happens if a user redefines assoc, and calling it causes alloc
       ;to compile, which causes crap? ... there probably must be some primitives.
       (= cadr.it return)
       (= (global-value car.xs) (or return 'HELLA-NIL)))
  (if cddr.xs
      (do (zap cddr xs) (jump 'eval-=)))
  (= the-pc pop.the-stack))

(def ret ()
  (= the-pc pop.the-stack))


(ddef ucons (x y) ;will do more shit later
  (= return (cons x y))
  (ret))
(ddef uflip (x y) ;oh man x y is convenient with cons
  (if no.x
      (ret)) ;returns y
  (save cdr.x)
  (= x car.x)
  (call 'ucons)
  (= y return) ;dumbass forgot this line
  (restore x)
  (jump 'uflip)) ;I could save a jump per 'uflip by duplicating the test at the bottom...
(ddef ucopy-list (x)
  (= y nil)
  (call 'uflip)
  (swap x y)
  (jump 'uflip)) ;return in y; ahhh, the good feeling of garbage
(ddef ulist args;oh god how do I butt butt butt
  ;lolololololololololz: I'll give it an arglist, using 'list.
  (= x args)
  (call 'ucopy-list)
  (= return y)
  (ret)) ;d'oh

(ddef hella-cons (return x) ;specialized for awesome power ;derf, wrong arg order
  (= env (cons return x))
  (ret))

(ddef urev (xs)
  (= x xs y nil)
  (call 'uflip)
  (= return y) ;aw, no fun...
  (ret))
  

;hmm, I've reordered the "symbol" vs "cons" things. oh well.
(ddef join-envs (env arg-names xs)
  ;I could localize the "return in env" thing, but actually that's useful to callers
  (if no.arg-names
      (if no.xs
          (do (= return env) (ret)) ;I might even just return its thing in env...
          (err "Too many arguments:" xs))) ;kind of strict
  (if (acons arg-names)
      (jump 'join-envs-b)
      (no:isa arg-names 'sym)
      (err "What kind of argument is this?" arg-names))
  
  ;arg-names = 'var
  (save env)
  (= args (list arg-names xs))
  (call 'ulist)
  (restore x)
  (jump 'hella-cons) ;lolololololz, specialized code that expects args
  ;and returns results in different places
  
  join-envs-b
  (if (no acons.xs)
      (err "Arg!" arg-names xs))
  (save cdr.arg-names cdr.xs)
  (= arg-names car.arg-names
     xs car.xs)
  (call 'join-envs) ;return in env
  (restore xs arg-names)
  (jump 'join-envs))

(ddef ulist-ref (xs n)
  (if (is n 0)
      (do (= return car.xs) (ret)))
  (zap cdr xs)
  (-- n)
  (jump 'ulist-ref))

(ddef uapply (f xs) ;ahh, here we go
  (if (is-system-proc f)
      (do (= return (apply f xs))
        ;ugh, I expect most system-procs won't cons too much, but...
        ;Eh, it doesn't matter here, 'cause I don't need to save anything anyway.
        ;Later I'll just have to substitute an "apply" that handles the other kind of list.
        ;...neeh... "cons". W... neeh, this seems ok.
        (ret))
      (no alist.f)
      (err "uapply: What is this?" f xs)
      (is car.f 'closure)
      (jump 'uapply-a)
      (is car.f 'macro)
      (err "Sorry, not sure how to apply a macro" f xs)
      (and acons.xs (no cdr.xs) (isa car.xs 'int))
      (do (= n car.xs xs f) (jump 'ulist-ref))
      (err "uapply: What is this?" f xs))
  
  uapply-a ;f = (closure env arglist . bodexprs)
  (pop f)
  (= env pop.f arg-names pop.f bodexprs f) ;d'oh, forgot "f"
  (save bodexprs)
  (call 'join-envs) ;returns its env in env
  (restore exprs)
  (jump 'uapply-loop))

;xs = (arglist . bodexprs)
;want to return ('closure env arglist bodexprs)
(ddef eval-fn (xs env) ;time to write it with conses
  (= x env y xs)
  (call 'ucons)
  (= x 'closure y return)
  (jump 'ucons))

(ddef ueval (x env)
  (if (isa x 'int)
      (do (= return x) (ret))
      (isa x 'sym)
      (aif (assoc x env)
           (do (= return cadr.it) (ret))
           (global-value x)
           (do (= return (if (is it 'HELLA-NIL) 'nil it)) (ret))
           (err "ueval: Not defined:" x))
      (no:alist x)
      (err "What is this?" x))
  (= f car.x xs cdr.x)
  (if (is f 'quote)
      (do (= return car.xs) (ret))
      (is f 'if)
      (jump 'eval-if) ;xs env
      (is f '=)
      (jump 'eval-=) ;xs env
      (is f 'fn)
      (jump 'eval-fn) ;xs env
      (is f 'mc)
      (jump 'eval-macro) ;xs env
      (is f 'quasiquote)
      (do (= x car.xs n 1) (jump 'eval-qq)) ;xs n env
      (is f 'arc)
      (do (= return (eval car.xs)) (ret)))
  (save xs env)
  (= x f)
  (call 'ueval)
  (restore env xs)
  ;oh boy
  (if (no:and acons.return (is car.return 'macro))
      (jump 'ueval-b))
  
  ueval-a
  (save env)
  (= f return)
  (call 'apply-mac) ;f xs
  (restore env)
  (= x return)
  (jump 'ueval)
  
  ueval-b ;we evaluate the list of arguments xs, then apply the function 'return to it.
  (if no.xs
      (do (= f return) (jump 'uapply))) ;massive shortcut, and necessary so entry point works
  (save return)
  (= ys nil)
  (save env)
  ;oh man time to do an "entry point" thing
      
  (jump 'ueval-b-loop-entry-point)
  
  ;Two thoughts from the bathroom.
  ;1. I could offload this into an "eval-exprs-in-env" procedure.
  ;2. I could maybe extend the instruction-list interpreter so that
  ; it would have a "splice" instruction, so that you'd go
  ; (inst . (inst . #0=(inst . ((splice 'some-instructions #0#) inst ...))))
  ; and the "splice" instruction would modify the instruction list (and jump back).
  ;Btw, I never did test exactly how overwriting the next few instructions, or
  ; previous instructions and then jumping to the point of overwriting, would work...
  ;does the processor flush some cache? Meh.
  
  ueval-b-loop ;xs is xs, ys is return, env is on stack
  (= ys return env car.the-stack) ;oh man, we use stack w/o popping
  
  ueval-b-loop-entry-point
  (save cdr.xs ys)
  (= x car.xs)
  (call 'ueval)
  (restore ys)
  (= x return y ys)
  (call 'ucons)
  (restore xs)
  (if xs
      (jump 'ueval-b-loop))
  ;return = ys, env is on stack, xs is nil
  (pop the-stack) ;dump env, now f on stack
  (= x return y nil)
  (call 'uflip) ;x y -> return y ;defined urev, but neh, don't use
  (= xs return)
  (restore f)
  (jump 'uapply)) ;jeeeeeeesus christ

(ddef eval-qq (x n env)
  (if atom.x
      (do (= return x) (ret))
      
      (is car.x 'quasiquote)
      (jump 'eval-qq-a)
      
      (is car.x 'unquote)
      (if (is n 1)
          (do (= x cadr.x) (jump 'ueval))
          (jump 'eval-qq-b))
      
      (is car.x 'unquote-splicing)
      (if (is n 1)
          (err "Bad use of unquote-splicing" x n env)
          (jump 'eval-qq-c)))
  
  eval-qq-loop
  (save cdr.x n env)
  (zap car x)
  (call 'eval-qq)
  (restore env n xs) ;names
  (save return)
  (call 'eval-qq-tail)
  (restore x)
  (= y return)
  (jump 'ucons)
  
  eval-qq-a
  (= x cadr.x n (+ n 1))
  (call 'eval-qq)
  (= args (list 'quasiquote return))
  (jump 'ulist)
  
  eval-qq-b
  (= x cadr.x n (- n 1))
  (call 'eval-qq)
  (= args (list 'unquote return))
  (jump 'ulist)
  
  eval-qq-c
  (zap cadr x)
  (-- n)
  (call 'eval-qq)
  (= args (list 'unquote-splicing return))
  (jump 'ulist))

(ddef eval-qq-tail (xs n env)
  (if atom.xs
      (do (= return xs) (ret))
      (no:and (acons car.xs)
              (is n 1)
              (is caar.xs 'unquote-splicing))
      (do (= x xs) (jump 'eval-qq-loop))) ;LOLOLOLOLZ, cross-function jumping
  (save cdr.xs n env)
  (= x cadar.xs)
  (call 'ueval)
  (restore env n xs)
  (save return)
  (call 'eval-qq-tail)
  (= xs pop.the-stack ys return)
  (jump 'ujoin-2))

(ddef ujoin-2 (xs ys)
  (save ys)
  (= x xs y nil)
  (call 'uflip)
  (= x y y pop.the-stack)
  (call 'uflip)
  (= return y)
  (ret))

(ddef eval-macro (xs env)
  (call 'eval-fn)
  (= args (list 'macro return))
  (jump 'ulist))

(ddef apply-mac (f xs)
  (zap cadr f)
  (jump 'uapply))

(def is-system-proc (x)
  (isa x 'fn))

(= global-value
   (obj + + - - * * / / cons cons car car cdr cdr is is < < > >
        scar scar scdr scdr uniq uniq
        apply uapply eval ueval apply-mac apply-mac nil 'HELLA-NIL))
  
(no:ueval '((fn ()
              (= list (fn args args)
                 no (fn (x) (is x 'nil))
                 list* (fn args (if (no (cdr args))
                                    (car args)
                                    (cons (car args) (apply list* (cdr args)))))
                 mac (mc (name args . body)
                         (list '= name (list* 'mc args body))))
              (mac def (name args . body)
                `(= ,name (fn ,args ,@body)))
              (def cadr (x) (car (cdr x)))
              (def macex1 (xs)
                (apply-mac (eval (car xs) nil) (cdr xs)))
              (mac let (var val . body)
                (list (list* 'fn (list var) body) val))
              (mac or args
                (if (no args)
                    ''t
                    (no (cdr args))
                    (car args)
                    (let u (uniq)
                      (list 'let u (car args)
                            (list 'if u u (list* 'or (cdr args)))))))
              (mac bracket-fn (body)
                (list 'fn '(_) body))
              (mac do body (list (list* 'fn () body))) ;aha, error
              (def accumulate (comb f xs init next done)
                (if (done xs)
                    init
                    (accumulate comb f
                                (next xs) (comb (f xs) init)
                                next done)))
;              (def take (n xs)
;                (if (or (no xs) (is n 0))
;                    nil
;                    (cons (car xs) (take (- n 1) (cdr xs)))))
;              (def drop (n xs)
;                (if (or (no xs) (is n 0))
;                    xs
;                    (drop (- n 1) (cdr xs))))
;              (def tuples (n xs)
;                (if (no xs)
;                    nil
;                    (cons (take n xs) (tuples n (drop n xs)))))
;              (def map1 (f xs)
;                (if (no xs)
;                    nil
;                    (cons (f (car xs)) (map1 f (cdr xs)))))
              (def id (x) x)
              (def rev (xs)
                (accumulate cons car xs nil cdr no))
              (mac -- (n . d)
                (list '= n (list '- n (if d (list 'quote d) 1))))
              (def take (n xs)
                (rev (accumulate cons car xs nil cdr [or (no _) (> 0 (-- n))])))
              (def drop (n xs)
                (if (or (is n 0) (no xs))
                    xs
                    (drop (- n 1) (cdr xs))))
              (def tuples (n xs)
                (rev (accumulate cons [take n _] xs nil [drop n _] no)))
              (def map1 (f xs)
                (rev (accumulate cons [f (car _)] xs nil cdr no)))
              (mac rfn (name args . body) ;oh man, circular data structure
                (list 'let name 'nil
                      (list '= name
                            (list* 'fn args body))))
              (mac xloop (varvals . body)
                 (list* (list* 'rfn 'next (map1 car (tuples 2 varvals)) body)
                        (map1 cadr (tuples 2 varvals))))))
          nil)

(def ue (x)
  (ueval x nil))

(def em ()
  (while t
    (pr "emiya> ")
    (prn:ue:read)))

