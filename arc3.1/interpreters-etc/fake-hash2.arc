

;imul dest, a, b-byte = an instruction.
;so that is ok.

(def trnc (n)
  (- (mod (+ n (ash 1 63)) (ash 1 64)) (ash 1 63)))

(def hash-thing (x)
  (case type.x
    sym hash-sym.x
    string hash-string.x
    int hash-int.x
    cons hash-cons.x
    (err "How do I hash this?" x)))
;don't bother hashing tables (or vectors) for now

(def hash-string (s)
  (xloop (i 0 n 1)
    (if (is i len.s)
        n
        (next inc.i (trnc:+ 3 int:s.i (* 7 n))))))

(def hash-sym (x)
  (trnc:* 5 hash-string:string.x))

(def hash-cons (x)
  (trnc:+ (* 11 hash-thing:car.x) (* 13 hash-thing:cdr.x)))

(def hash-int (x)
  (trnc:+ 5 (* x 17)))

(= vec $.vector
   make-vec $.make-vector
   vec-len $.vector-length
   vec? ($:lambda (x) (if (vector? x) 't 'nil))
   vref $.vector-ref
   vset ($ vector-set!))

(def a-fake-table (x)
  (and acons.x (is car.x 'fake-table))) ;lel

;this shit can be made thread-safe with judicious use of
;CMPXCHG, although deletions are a bit funky...

;should I store the exact key with each element as well?
;...
;the advantage of that would be resolving shit faster
;...
;according to below interlude, if n=N+1, then you should expect
;two elements to appear in any lookup.
;anyway, it appears that "double when n = N, halve when 2n < N" is good.

;meanwhile, I have realized that that hash function is absolutely stupid.
;e.g. hash(cons(odd, odd)) = odd.
;it seems likely that you'll get a whole bunch of odd hashes, and
;probably other crap.
;next version, then. lelz.

(def fake-table ()
  (let n 4
    `(fake-table ,(make-vec n 'nil) 0)))

;guh... resizing in a thread-friendly way is actually more irritating than I thought.
;looks like those who modify the table will have to check if someone
;actually started resizing it in the meantime.
;well, oh well, don't really need to handle that now.

;fake-table vec-len is always a power of 2
(def fake-table-insert (ftab key val (o test is))
  (prsn key val)
  (withs u hash-thing.key
    vec ftab.1
    n vec-len.vec
    ind (bit-and dec.n u)
    xs (vref vec ind)
    (xloop (ys xs)
      (prsn 'ys ys 'key key 'ind ind)
      (if no.ys
          (do #;(prn "Inserting!")
            (vset vec ind (cons (cons key val) xs))
            (let k (++ ftab.2)
              (when ;(is 0 (bit-and k dec.k)) ;pow of 2 ;fuckhead
                  (is n k)
                (prn "Resizing!")
                (= ftab.1 (fake-table-copy-vec
                           vec
                           (make-vec (* 2 n) 'nil))))))
          (test key caar.ys)
          (scdr car.ys val)
          next:cdr.ys))))

(def fake-table-copy-vec (old new)
  (withs n vec-len.new mask dec.n
    #;(prsn n mask)
    (for i 0 dec:vec-len.old
      #;(prn (vref old i))
      (each (k . v) (vref old i)
        (prsn k v)
        (let ind (bit-and mask hash-thing.k)
          (vset new ind (cons (cons k v) (vref new ind)))))))
  new)
  
(def fake-table-ref (ftab key (o fail nil) (o test is))
  (withs u hash-thing.key
    vec ftab.1
    n vec-len.vec
    ind (bit-and dec.n u)
    xs (vref vec ind)
    (xloop (ys xs)
      (if no.ys
          fail
          (test key caar.ys)
          cdar.ys
          next:cdr.ys))))

(def fake-table-delete (ftab key (o test is))
  (withs u hash-thing.key
    vec ftab.1
    n vec-len.vec
    ind (bit-and dec.n u)
    xs (vref vec ind)
    (if (and xs (test key caar.xs))
        (do (vset vec ind cdr.xs)
          (let k (-- ftab.2)
            (when (< (+ k k) n)
              (= ftab.1 (fake-table-copy-vec
                         vec (make-vec (ash n -1) 'nil))))
            t))
        (xloop (pv xs ys cdr.xs)
          (if no.ys
              fail
              (test key caar.ys)
              (do (scdr pv cdr.ys)
                (let k (-- ftab.2)
                  (when (< (+ k k) n)
                    (= ftab.1 (fake-table-copy-vec
                               vec (make-vec (ash n -1) 'nil))))
                  t))
              (next ys cdr.ys))))))
;resizing now.

(def fake-table-keys (ftab)
  (let v ftab.1
    (accum a (for i 0 dec:vlen.v
               (each x (vref v i)
                 a:car.x)))))

(def fake-table-vals (ftab)
  (let v ftab.1
    (accum a (for i 0 dec:vlen.v
               (each x (vref v i)
                 a:cdr.x)))))

(def fake-table-map (func ftab)
  (let v ftab.1
    (for i 0 dec:vlen.v
      (each (k . v) (vref v i)
        (func k v)))))


;Due to concerns similar to those remaining about vectors
;(many threads might try to move the dick all at once,
; and most of them end up wasting a bunch of space)
;it seems that resizing will have to be done with a lock.
;And then anyone who modifies the table must check ...
;

;- Thing should be locked by negating the ptr to the vec.
;  (Neg. installed with cmpxchg, even if lock neg works.)
;- The hash-table-count should be stored in the vec too.
;  Otherwise that's a terrible nother thing to synchronize.
;- When doing anything with it, you get the vec ptr, then
;  determine whether it's "locked".
;- - If you're impatient, then you can make your own copy
;    and install it with cmpxchg before the other thread
;    does... um. Incremental crap might then be obviously
;    a good thing to do here... mmm... that carries its
;    own synch. problems, presumably...
  
  
  
; interlude of mathematics and stupidity, pasted in
;Expected length of each hash-entry
;in a hash table of size m containing n elements.
;
;
;E.g. with 8 in 12...
;Prob. of one entry containing 8: dick.
;...
;Prob. of one entry containing 5: ass.
;Prob. of one entry containing 4: ...
;Prob. of two entries containing 4: ...
;
;Appears to become more complicated if crap...
;
;--Neh, no.
;Just look at one slot.
;Then crap adds nicely.
;
;f(m,n) = ∑ (1/m)^i * (m-1 / m)^n-i * ...
;
;Well, if slot Bob contained k,
;then that would mean that, for k out of n,
;the len is k.
;Thus f(m,n) = 0/n * 0 * ass + 1/n * 1 * ass + 2/n * 2 * ass + ... .
;
;f(m,n) = ∑[ (1/m)^k * (m-1/m)^n-k * [k/n * k + (n-k)/n * f(m-1,n-k)] ]
;
;or
;∑[ 1/m^n * [
;ah, I need a choose term.
;  
;... now I am getting m / n...
;m=10.
;n=1, k.
;n=2, k.
;n=3...
;p(3) = 1/1000 ... no, 10/1000.
;p(2 1) = ... one way => 1 * 1/10 * 9/10 + 1 * 9/10 * 1/10 = 9/100 + 9/100 = 18/100
;no.
;1*1/10*9/10 + 1*9/10*2/10 = [9 + 18]/100 = 27/100.
;
;p(1 1 1) = 1 * 9/10 * 8/10 = 72/100
;
;res:
;3/100 + 54/100 + 72/100 = 129/100...
;
;ok, turns out I am a dumbass and the computer is right.
;answer is:
;look at element Bob.
;imagine looking up element Bob.
;what is the expected number of neighbors of element Bob?
;obviously, each other element has a 1/m chance of being in
;Bob's slot; hence n-1 / m.
;btw a better choice of var. names is n elms, N size.   
  
  
  
  