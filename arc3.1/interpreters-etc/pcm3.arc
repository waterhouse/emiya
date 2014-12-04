(def make-signed (x bits)
  (if (bit-set x dec.bits)
      (- x (expt 2 bits))
      x))

(def make-signed2 (x bits)
  (- (mod (+ x (ash 1 dec.bits)) (ash 1 bits)) (ash 1 dec.bits)))

#;(def read-pcm ((o bytes-per-dick 4) (o signed t) (o little-endian t))
  (xloop (xs nil)
    (let u (n-of bytes-per-dick (readb))
      (if (some no u)
          (if (all no u)
              nrev.xs
              (err "The number of bytes in the file isn't a multiple of the number of bytes per sample." u))
          (next (cons (make-signed (digs->num (if little-endian
                                                  nrev.u
                                                  u) 256)
                                   (* 8 bytes-per-dick))
                      xs))))))

(def slow-read-int (bytes signed little-endian)
  (aif (readb)
       ((if signed [make-signed _ (* bytes 8)] id)
        (digs->num ((if little-endian nrev id)
                    (cons it (n-of dec.bytes (readb))))
                   256))))


;little-endian, screw everything else
#;(def read-int ((o bytes 4) (o signed t))
  (aif (readb)
       (xloop (x it n dec.bytes m 8)
         (if (is n 0)
             (if signed
                 (make-signed x m)
                 x)
             (aif (readb)
                  (next (+ x (ash it m))
                        dec.n
                        (+ 8 m))
                  (err:string "Attempted to read "
                              bytes
                              "-byte integer; not enough bytes."
                              x n m))))))

;raw Racket
;turns out the extra checking is cheap
(def read-int-expr (bytes signed little-endian)
  (let vars (mapn [symb 'byte _] 0 dec.bytes)
    (let (var . rest) vars
      `($:let ((,var (read-byte)))
              (if (eof-object? ,var)
                  'nil
                  (let ,(map (fn (v) `(,v (read-byte))) rest)
                    (if (eof-object? ,(last vars))
                        (error ,(string "Expected to read " bytes " bytes:")
                               ,@vars)
                        ,((if signed
                              (fn (x)
                                `(let ((u ,x))
                                   (if (bitwise-bit-set? u ,(dec:* bytes 8))
                                       (- u ,(ash 1 (* bytes 8)))
                                       u)))
                              (fn (x) x))
                          `(bitwise-ior
                            ,@(map (let n 0
                                     (fn (v)
                                       (do1 (if (is n 0)
                                                v
                                                `(arithmetic-shift ,v ,n))
                                            (++ n 8))))
                                   (if little-endian vars rev.vars)))))))))))

(defmemo int-reader ((o bytes 4) (o signed t) (o little-endian t))
  (eval `(fn () ,(read-int-expr bytes signed little-endian))))

(def constant-expr (x) ;technically need lexenv to do this properly
  (or (in x t nil)
      (mem type.x '(int num string))))
;an optimizing compiler should do this shit
(mac read-int ((o bytes 4) (o signed t) (o little-endian t))
  (let args (list bytes signed little-endian)
    (if (all constant-expr args)
        (apply read-int-expr args)
        `(slow-read-int ,@args))))

(def read-pcm ((o bytes-per-int 4) (o signed t) (o little-endian t))
  (unless little-endian
    (err "Not little-endian? Fuck you"))
  #;(drain:slow-read-int bytes-per-int signed little-endian)
  #;(drain:$:read-4int 'meh)
  #;(drain:arc-read4int)
  (let f (int-reader bytes-per-int signed little-endian)
      (drain:f))
  #;(drain:rup))

(def write-int (x n) ;n-byte little-endian signed int
  (if (is n 1)
      (writeb:mod x 256)
      (do (writeb:bit-and x 255)
        (write-int (ash x -8) (- n 1)))))

(def real-mod (x m)
  (let u (floor (/ x m))
    (- x (* u m))))
(= default-hz 44100)
;(= us nil)

(def write-func (f secs (o vol-factor 1) (o start 0))
  (let end (floor:- (* secs default-hz) 1)
    (for i start end
      (write-int (round:* vol-factor (f:/ i default-hz))
                 4))
    inc.end))

(def sine-func (hz (o vol (expt 2 29)))
  (fn (x)
    (* vol (sin:* tau hz (real-mod x /.hz)))))

(def write-sine (vol hz secs (o start 0))
  (write-func (sine-func hz vol) secs 1 start))

(def double-up (file)
  (fromfile file
    (tofile (string file 2)
      (awhile (read-int)
        (write-int it 4)
        (write-int it 4)))))
(def file-length (f)
  (read:sys "wc -c " f))

(def write-wav-header((o length (- (expt 2 31) 256))
                      (o num-channels 1)
                      (o sampling-rate default-hz)
                      (o bytes-per-int 4))
  (with (w write-int)
    (pr "RIFF")
    (w (+ 40 length) 4)
    (pr "WAVE")
    (pr "fmt ")
    (w 16 4) ;16 more bytes
    (w 1 2) ;this is pcm
    (w num-channels 2)
    (w sampling-rate 4)
    (w (* sampling-rate num-channels bytes-per-int) 4) ;bytes/sec
    (w (* bytes-per-int num-channels) 2) ; "data block size"
    (w (* 8 bytes-per-int) 2) ; bits per sample
    (pr "data")
    (w length 4)))

(def wavify (f (o num-channels 1)
               (o sampling-rate default-hz)
               (o bytes-per-int 4)
               (o outf (string f ".wav")))
  (with (n file-length.f)
    (tofile outf
      (write-wav-header n num-channels sampling-rate bytes-per-int))
    (system:string "cat " f " >> " outf)))

(def play-hz (n (o init 1) (o vol (expt 2 29)))
  (thread sleep.init (system "open fuckyou.wav"))
  (tofile "fuckyou.wav"
    (write-wav-header)
    (write-sine vol n 15)))

(= wavs-dir (home "wavs/")) ;ensure it exists or something?
(def play-note (n (o length 1.5) (o delay t) (o reterm t))
  (let u (msec)
    (let f (string wavs-dir n "-" length)
      (unless (file-exists f)
        (thread:tofile f
                       (write-wav-header) ;(* length default-hz 4)) ;or over 9000
                       (write-sine (expt 2 30)
                                   (* 440 (expt 2 (/ n 12)))
                                   length))
        sleep.1)
      (system:string "open -a VLC.app " f (if reterm " && open -a Terminal.app")))
    (if delay
        (sleep:/ ([if (> _ 0) _ 0]
                  (- (+ u (* length 1000)) (msec))) 1000))))

(def play-notes (xs)
  (let f (string wavs-dir "last-notes.wav")
    (thread:system:string "sleep 1 && open -a VLC.app " f " && open -a Terminal.app")
    (tofile f
      (write-wav-header)
      (each (note secs) xs
        (write-sine (if note (expt 2 30) 0)
                    (* 440 (expt 2 (/ (or note 0) 12)))
                    secs))
      (write-sine 0 440 .5)))) ;VLC ignores the last .5 sec or so

(def play-sounds (xs)
  (let f (string wavs-dir "last-sounds.wav")
    (thread:system:string "sleep 1 && open -a VLC.app " f " && open -a Terminal.app")
    (tofile f
      (write-wav-header)
      (each (f secs) xs
        (write-func f
                    (expt 2 29)
                    secs))
      (write-func [id 0] 0 .5))))

(def add-func args
  (fn (x)
    (sumlist [_ x] args)))

(= p play-note)

(def read-wav ((o filename))
  ([if filename
       (fromfile filename (_))
       (_)]
   (fn ()
     (repeat 16 (readb))
     (let u (read-int 4) (unless (is u 16) (err "Oh god the header is not of expected size" u)))
     (read-int 2)
     (withs (num-channels (read-int 2)
                          sampling-rate (read-int 4)
                          bytes-per-int (/ (read-int 4) num-channels sampling-rate))
       (unless (is (* bytes-per-int num-channels) (read-int 2))
         (err "Noob"))
       (unless (is (* bytes-per-int 8) (read-int 2))
         (err "Nooob"))
       (repeat 8 (readb))
       (prsn num-channels "channels," sampling-rate "hz," bytes-per-int "byte ints")
       ([if (is num-channels 1) _ separate._]
        (read-pcm bytes-per-int))))))

(def separate (xs)
  (xloop (xs xs a nil b nil)
    (if no.xs
        (list nrev.a nrev.b)
        (let u cdr.xs
          (scdr xs a)
          (next u b xs)))))

(def meh (f xs)
  (let n 0
      (on x xs
        (++ n (* x f.index)))
      n))

(def blah (sample-rate hz)
  (let u (* tau (/ hz sample-rate))
    (list [sin:* u _] [cos:* u _])))

(def heh (n xs (o sample-rate 44100))
  (let (f g) (blah sample-rate (* 440 (expt 2 (/ n 12))))
    (sqrt:+ (square:meh f xs) (square:meh g xs))))

(defmemo mheh (n xs a b (o sample-rate 44100))
  (let (f g) (blah sample-rate (* 440 (expt 2 (/ n 12))))
    (let xs (cut xs a b)
      (round:sqrt:+ (square:meh f xs) (square:meh g xs)))))

(def make-blah (sample-rate hz)
  (let u (* tau (/ hz sample-rate))
    (let n -1
      (fn () (sin:* u ++.n)))))

(def nerf (xs (o dt 3000)) ;no volume ctrl
  (xloop (last-x nil xs xs)
    (when xs
      (let x (map [list _ (or (alref last-x _) (make-blah 44100 (* 440 (expt 2 (/ _ 12)))))]
                  (map car car.xs))
        (repeat dt
          (write-int (round:* (expt 2 28) (sumlist [cadr._] x)) 4)) ;((cadr _)), lolz
        (next x #;nil cdr.xs)))) ;it does help to make notes continuous
  len.xs)

(def the-matrix (fs n)
  (let fs (map cadr fs)
    (map (fn (f)
           (map (fn (g)
                  (sum [* f._ g._] 0 dec.n)) ;might eventually want to normalize by n and stuff
                fs))
         fs)))

;Now, of course, it is possible to compute this fuckin' crap using actual math.
;(defmemo the-matrix2 (fs-specs n)
;  (map (fn (f)
         

(with (scale (fn (row x)
               (map [* _ x] row))
       sub (fn (a b)
             (map [- _a _b] a b)))
  (def mat-invert (xs) ;FUCK YOU YOU'RE WRONG YOU SUCK
    (let sx mat-id:len.xs
      (forlen n xs
        (let f (fn (x)
                 (zaps [scale _ x] xs.n sx.n)
                 (for i inc.n dec:len.xs
                   ((fn (f) (f xs) (f sx))
                    (fn (xs)
                      (zap [sub _ (scale xs.n _.n)] xs.i)))))
          (aif ([and (isnt _ 0) /._] xs.n.n);(inv xs.n.n m)
               f.it
               (pos [isnt _.n 0] xs n)
               (do (swap xs.n xs.it)
                 (swap sx.n sx.it)
                 (zaps [scale _ -1] xs.n sx.n)
                 (f:/ xs.n.n))
               (err "No inverse?" n xs sx))))
      (for- n dec:len.xs 1
        (for- i dec.n 0
          ((fn (f) (f xs) (f sx))
           (fn (xs)
             (zap [sub _ (scale xs.n _.n)] xs.i)))))
      sx)))

;note that modular arithmetic must optimally follow a different algorithm,
;because there are things between "is zero" and "has an inverse". e.g.:
;(2 3)
;(5 7): invert mod 10.
;that can be done.
;-> ((2 3) (1 1))
;-> ((1 1) (-2 -3))
;-> ((1 1) (0 -1))
;-> ((1 0) (0 -1))
;-> ((1 0) (0 1))
;for mod, the success and failure conditions may involve manipulating multiple rows,
;not just one.

;btw: realized I've been an idiot.
;believed the bullshit about "switching rows", in the real-number case.
;that is merely an optimization.
;in general, you "make the current row have a leading term of 1".
;if this row, a, leads with 0, and the next row, b, leads with something else (say 1),
;then it works just as well to set the current row to a+b, then work with that.
;this involves more subtractions and numerical instability, but it's not too common
;anyway. ... if I wanted, I could even have the "interact with futher rows" involve
;possibly modifying the further rows, and then swapping could be a subcase.
;anyway, won't bother to do the really general case for now.

;JESUS CHRIST this is horrible. 
(def generic-mat-nsolve-linear (a y plus minus times divide invert zerop neg);destructive
  ;ax = y; solve for x; set y=identity to invert a
  (let n len.a
    (forlen i a
      (when (zerop a.i.i)
        (aif (pos [no:zerop _.i] a i)
             (do (let tmp a.i
                   (= a.i a.it
                      a.it (map neg tmp)))
               (let tmp y.i
                 (= y.i y.it
                    y.it (map neg tmp))))
             (err "Can't invert, too much zero" a i)))
      (let u (invert a.i.i)
        (with (ar (map [times _ u] a.i)
               yr (map [times _ u] y.i))
          (= a.i ar y.i yr)
          (for r inc.i dec:len.a
            (let u a.r.i
              (= a.r (map minus a.r (map [times _ u] a.i))
                 y.r (map minus y.r (map [times _ u] y.i))))))))
    (forlen i a
      (let i (- n i 1)
        (let u a.i.i ;it should be 1, but I am being dumb
          (for r 0 dec.i
            (let c (divide a.r.i u)
              (= a.r (map minus a.r (map [times _ c] a.i)) ;should be a 1 row; shouldn't even need this
                 y.r (map minus y.r (map [times _ c] y.i))))))))
    y))

;Since all that shit is parameterized... we may as well write the driving code in Racket...
;Now I'm not sure whether to use a vector or a vector of vectors.
;I wonder if this can be easily changed. Jech.
;Time for a big vector.
(def mat->vector (m)
  (let u ($.make-vector (* len.m len:car.m))
    (on x flat1.m
      (($ vector-set!) u index x))
    u))
(def vector->mat (x)
  (let n (safe-isqrt $.vector-length.x)
    (unless n (err "WTF not square" x))
    (tuples n $.vector->list.x)))
  
(def generic-mat-solve-linear (a y . rest)
  (unless (is len:car.a len.y)
    (err "Incompatible matrix and vector arguments:" a y))
  (let u (map join a y)
    (let u (apply generic-gaussian-elimination
                  (mat->vector u)
                  len.u
                  len:car.u
                  rest)
      (map list:last (tuples inc:len.a $.vector->list.u)))))
(def mat-inv (a)
  (generic-mat-invert a + - * / / [is _ 0] -))
(def generic-mat-invert (a . rest)
  (unless (is len.a len:car.a)
    (err "Not a square matrix" a))
  (let u (map join a mat-id:len.a)
    ([map cadr (tuples 2 (tuples len.a $.vector->list._))]
     (apply generic-gaussian-elimination
            mat->vector.u
            len.u
            len:car.u
            rest))))
(= aa nil)
(def show-aa ((o message))
  (when message prn.message)
  (grid:tuples 4 (map [if _ _ nil] $.vector->list.aa)))

(= generic-gaussian-elimination ;just a giant vector, not 2+ distinc
   ; need to tell how long row is (and row len; redund.)
   ($:lambda (a rn rlen plus minus times divide invert zerop neg)
     (let loop ((i 0) (ind 0))
       (when (< i rn)
         (when (not (ar-false? (zerop (vector-ref a ind))))
           (let loop ((j i) (jnd ind))
             (cond ((= j rn) (error "Too much zero" a))
                   ((ar-false? (zerop (vector-ref a jnd)))
                    (let ((stop (* (+ i 1) rlen)))
                      (let loop ((ind ind) (jnd jnd)) ;avoid touching old stuff
                        (when (< ind stop)
                          (let ((u (vector-ref a ind)))
                            (vector-set! a ind (vector-ref a jnd))
                            (vector-set! a jnd (neg u)))
                          (loop (+ ind 1) (+ jnd 1))))))
                   (#t (loop (+ j 1) (+ jnd rlen))))))
         
         ;I could defer "scale this row to make head 1" until later...
         ;also, for exactness... I could insist on a "one" that I could
         ;insert somewhere. x/x yields BS. though I guess
         ;OH MY GOD
         ;I could be like, in "(iv-/ x y)", (if (eq x y) 1 <proceed>).
         ;For now, screw everything. Eh, use "one".
         ;... Hmm, should I also put "zero" in empty places? Jesus christ.
         ;Actually it shouldn't matter. I throw away the left matrix anyway.
         ;All right, be careful and I can just write my algorithm to assume the
         ;values zero and one.
         (let ((stop (* (+ i 1) rlen)))
           (let ((u (invert (vector-ref a ind))))
             (vector-set! a ind (not #t)) ;lolz; asserting that I won't touch it no more
             ;fuck I need to tell Arc not to touch it
             (let loop ((ind (+ ind 1)))
               (when (< ind stop)
                 (vector-set! a ind (times u (vector-ref a ind)))
                 (loop (+ ind 1)))))
           (let loop ((j (+ i 1)) (jnd (+ ind rlen)))
             (when (< j rn)
               (let ((u (vector-ref a jnd)))
                 (vector-set! a jnd (not #t))
                 (let loop ((ind (+ ind 1)) (jnd (+ jnd 1)))
                   (when (< ind stop)
                     (vector-set! a jnd (minus (vector-ref a jnd)
                                               (times u (vector-ref a ind))))
                     (loop (+ ind 1) (+ jnd 1))))
                 (loop (+ j 1) (+ jnd rlen))))))
         (loop (+ i 1) (+ ind rlen 1))))
     (let loop ((ind (* (+ rlen 1) (- rn 1)))
                (istart (+ rn (* rlen (- rn 1))))
                (stop (* rn rlen)))
       (when (> stop rlen)
         (let loop ((jnd (- ind rlen)) (jstart (- istart rlen)))
           (when (> jnd 0)
             (let ((u (vector-ref a jnd)))
               (vector-set! a jnd (not #t))
               ;now actually we only touch stuff east of original matrix
               (let loop ((ind istart) (jnd jstart))
                 (when (< ind stop)
                   (vector-set! a jnd (minus (vector-ref a jnd)
                                             (times u (vector-ref a ind))))
                   (loop (+ ind 1) (+ jnd 1)))))
             (loop (- jnd rlen) (- jstart rlen))))
         (loop (- ind rlen 1) (- istart rlen) (- stop rlen))))
     a))


(def float-solve (a y (o tolerance 10));destructive
  ;ax = y; solve for x; set y=identity to invert a
  (with (careful-plus (fn (x y) (let u (+ x y) (if (< tolerance (- size.x size.u)) (prsn "Warning, bad shit" '+ x y u)) u))
   careful-minus (fn (x y) (let u (- x y) (if (and (< tolerance (- size.x size.u)) (isnt u 0.0)) (prsn "Warning, bad shit" '- x y u)) u))
   plus + minus - times *
   careful-divide (fn (x y) (if (< abs.y (expt 2 -.tolerance)) (prsn "Warning, bad shit" '/ x y)) (/ x y))
   careful-invert [do (if (< abs._ (expt 2 -.tolerance)) (prsn "Warning, bad shit" 'inverted _)) /._]
   zerop [is _ 0] neg -)
  (let n len.a
    (forlen i a
      (when (zerop a.i.i)
        (aif (pos [no:zerop _.i] a i)
             (do (let tmp a.i
                   (= a.i a.it
                      a.it (map neg tmp)))
               (let tmp y.i
                 (= y.i y.it
                    y.it (map neg tmp))))
             (err "Can't invert, too much zero" a i)))
      (let u (careful-invert a.i.i)
        (with (ar (map [times _ u] a.i)
               yr (map [times _ u] y.i))
          (= a.i ar y.i yr)
          (for r inc.i dec:len.a
            (let u a.r.i
              (= a.r (map careful-minus a.r (map [times _ u] a.i))
                 y.r (map minus y.r (map [times _ u] y.i))))))))
    (forlen i a
      (let i (- n i 1)
        (let u a.i.i ;it should be 1, but I am being dumb
          (for r 0 dec.i
            (let c (careful-divide a.r.i u)
              (= a.r (map careful-minus a.r (map [times _ c] a.i)) ;should be a 1 row; shouldn't even need this
                 y.r (map minus y.r (map [times _ c] y.i))))))))
    y)))

;need things that watch taint... need things that do butt
;represent a number as (cons x [history of x])
;history of x = computation that produced x
;computation that produced x: e.g. (+ [number] [number])

(def historical (symbol)
  (let f symbol-value.symbol
    (fn args
      `(,(apply f (map [if number._ _ car._] args)) (,symbol ,@args)))))

(= dangerous (table)
   deadly (table))

;(def careful (symbol tolerance)
;  (let f historical.symbol
;    (fn (x y) ;oh dear
;      (let u (f x y)
;        (if (< tolerance (- (max size.x size.y) size.u)

(def hist-solve (a y (o tolerance 10));destructive
  ;ax = y; solve for x; set y=identity to invert a
  (withs (
   plus historical!+ minus historical!- times historical!*
   careful-plus (fn (x y) (let u (plus x y) (if (< tolerance (- size.x size.u)) (prsn "Warning, bad shit" '+ x y u)) u))
   careful-minus (fn (x y) (let u (minus x y) (if (and (< tolerance (- size.x size.u)) (isnt car.u 0.0)) (prsn "Warning, bad shit" '- x y u)) u))
   careful-divide (fn (x y) (if (< abs.y (expt 2 -.tolerance)) (prsn "Warning, bad shit" '/ x y)) (/ x y))
   careful-invert [do (if (< abs._ (expt 2 -.tolerance)) (prsn "Warning, bad shit" 'inverted _)) /._]
   zerop [is _ 0] neg historical!-)
  (let n len.a
    (forlen i a
      (when (zerop a.i.i)
        (aif (pos [no:zerop _.i] a i)
             (do (let tmp a.i
                   (= a.i a.it
                      a.it (map neg tmp)))
               (let tmp y.i
                 (= y.i y.it
                    y.it (map neg tmp))))
             (err "Can't invert, too much zero" a i)))
      (let u (careful-invert a.i.i)
        (with (ar (map [times _ u] a.i)
               yr (map [times _ u] y.i))
          (= a.i ar y.i yr)
          (for r inc.i dec:len.a
            (let u a.r.i
              (= a.r (map careful-minus a.r (map [times _ u] a.i))
                 y.r (map minus y.r (map [times _ u] y.i))))))))
    (forlen i a
      (let i (- n i 1)
        (let u a.i.i ;it should be 1, but I am being dumb
          (for r 0 dec.i
            (let c (careful-divide a.r.i u)
              (= a.r (map careful-minus a.r (map [times _ c] a.i)) ;should be a 1 row; shouldn't even need this
                 y.r (map minus y.r (map [times _ c] y.i))))))))
    y)))

;Floating point arithmetic operations that introduce massive losses of accuracy:
; - add high number to low number and then subtract high number...
;Subtract high number from high number and get low number. That is el problemo.
;Multiplication and division is all fine.  For some reason.
;I can check just one number, because things work out like that.
(def size (x)
  (if acons.x (zap car x))
  (if (is x 0) -300 (log abs.x 2)))
(def sl (a y (o tolerance 10)) ;binary digits lost in one go
  (generic-mat-nsolve-linear
   a y
   (fn (x y) (let u (+ x y) (if (< tolerance (- size.x size.u)) (prsn "Warning, bad shit" x '+ y u)) u))
   (fn (x y) (let u (- x y) (if (< tolerance (- size.x size.u)) (prsn "Warning, bad shit" x '- y u)) u))
   * / / [is _ 0] -))
   

(def fuck-mat-nsolve-linear (x y (o n (expt 10 30)))
  (deep-map [inex:/ _ n]
            (generic-mat-nsolve-linear
             (deep-map [floor:* _ n] x)
             (deep-map [floor:* _ n] y)
             + - (fn (x y) (div (* x y) n)) (fn (x y) (div (* x n) y))
             [div (* n n) _]
             [is _ 0] -)))

(def float-mat-nsolve-linear (a y) ;dumb hack
  (with (plus + minus - times * divide / zerop [is _ 0] neg -)
  ;ax = y; solve for x; set y=identity to invert a
    (let n len.a
      (forlen i a
        (when t #;(zerop a.i.i)
          (let it (car:best (compare < cadr)
                             (mapn [list _
                                         (let u a._.i
                                           (if (is u 0)
                                               +inf.0
                                               (abs:log:abs u)))]
                                   i dec.n))
            (do (let tmp a.it
                  (= a.it (map neg a.i)
                     a.i tmp)) ;if i = it, this is correct
              (let tmp y.it
                (= y.it (map neg y.i)
                   y.i tmp)))))
        (let u (divide 1 a.i.i)
          (with (ar (map [times _ u] a.i)
                    yr (map [times _ u] y.i))
            (= a.i ar y.i yr)
            (for r inc.i dec:len.a
              (let u a.r.i
                (= a.r (map minus a.r (map [times _ u] a.i))
                   y.r (map minus y.r (map [times _ u] y.i))))))))
      (forlen i a
        (let i (- n i 1)
          (let u a.i.i ;it should be 1, but I am being dumb
            (for r 0 dec.i
              (let c (divide a.r.i u)
                (= a.r (map minus a.r (map [times _ c] a.i)) ;should be a 1 row; shouldn't even need this
                   y.r (map minus y.r (map [times _ c] y.i))))))))
      y)))


;all right, time for butt.
;I need a finite-precision representation for numbers.
;I'll implement this essentially as rational numbers, where the denominator
;will probably always be a power of 10.
;I'll perform arithmetic in such a way that I get a conservative estimate as to
;the accuracy of each number.  I'll use interval arithmetic where the numbers are
;finite-precision butts.
;It'll be sort of "fixed-point".  1.38 * 10 -> 13.80. 1.38 / 10 = .13.
;And I shall do interval arithmetic.
;Division by an interval containing 0 shall not be allowed. Heuristics for recomputation
;and printing "Fuck fuck fuck".
;Differing fixed-points -> use the maximum accuracy.
;For the moment, no attempt to be like "x - x = exact 0, not 0 within a big interval".

;Mmm, so.  Interval, fixed-point.  Shall I be modular, as in:
;iv: (fp fp hist)
;fp: (num shift)
;Or shall I be integrated, as in:
;iv: (bottom top shift hist)
;... Modular is probably easier, I suppose.

;fp: (cons num shift).
;if the number x = (cons num shift),
;then x = num / 10^shift.
;I will satisfy my urges for efficiency.
(def fp-fix (x n) ;geez, could make destructive and shit
  (if (is cdr.x n)
      x
      (let u (- n cdr.x)
        (cons (if (< u 0)
                  (div car.x (expt 10 -.u))
                  (* car.x (expt 10 u)))
              n))))
(def fp-promote (x n)
  (cons (* car.x (expt 10 (- n cdr.x))) n))

(mac fp-def2 (op (arg1 arg2 shf-name) . body)
  (let f (symb "fp-" op "2")
    `(def ,f (,arg1 ,arg2)
       (if (is (cdr ,arg1) (cdr ,arg2))
           (let ,shf-name (cdr ,arg1) ,@body)
           (< (cdr ,arg1) (cdr ,arg2))
           (,f (fp-promote ,arg1 (cdr ,arg2)) ,arg2)
           (,f ,arg1 (fp-promote ,arg2 (cdr ,arg1)))))))

(fp-def2 + (a b n)
  (cons (+ car.a car.b) n))
(fp-def2 - (a b n)
  (cons (- car.a car.b) n))
;geez, promoting is silly with *, because double shift... Oh fucking well.
(fp-def2 * (a b n)
  (cons (div (* car.a car.b) (expt 10 n)) n))
(fp-def2 *-floor (a b n)
  (cons (floor-div (* car.a car.b) (expt 10 n)) n))
(fp-def2 *-ceiling (a b n)
  (cons (ceiling-div (* car.a car.b) (expt 10 n)) n))
(fp-def2 / (a b n)
  (cons (div (* car.a (expt 10 n)) car.b) n))
(fp-def2 /-floor (a b n)
  (cons (floor-div (* car.a (expt 10 n)) car.b) n))
(fp-def2 min (a b n)
  (cons (min car.a car.b) n))
(fp-def2 max (a b n)
  (cons (max car.a car.b) n))
(fp-def2 < (a b n)
  (< car.a car.b))
(fp-def2 > (a b n)
  (> car.a car.b))

(def fp-sign (x)
  (sign car.x))
(def fp-negative (x)
  (< car.x 0))

(def fp-invert (x)
  (cons (div (expt 10 (* 2 cdr.x)) car.x) cdr.x))



;so div has round-towards-zero semantics...
;OMFG I NEED FLOOR/CEILING VERSIONS OF EVERYTHING
;WELL JUST MUL/DIV ACTUALLY, NOT ADD/SUB
;STILL
(def fp-invert-floor (x)
  (cons (floor-div (expt 10 (* 2 cdr.x)) car.x) cdr.x))

(def fp-invert-ceiling (x)
  (cons (ceiling-div (expt 10 (* 2 cdr.x)) car.x) cdr.x))

;Say, what about that coercion thing? ... Nvm.

;Now for interval fuck.
;Should I try to make something to do interval arithmetic where
;the numbers that comprise the bottom and top are arbitrary things,
;and have the fact that it's a fixed-point number be essentially a
;parameter?  Or just hardcode shit?

;I now face the problem that I also want comparison functions.
;At the very least, I need sign functions.

;iv: (cons bottom top)

(def iv-+2 (a b)
  (cons (fp-+2 car.a car.b)
        (fp-+2 cdr.a cdr.b)))
(def iv--2 (a b)
  (cons (fp--2 car.a cdr.b)
        (fp--2 cdr.a car.b)))

;now multiplication is a bitch...
;if something is pure positive or negative, that's simple...ish.
(def iv-*2 (a b)
  (if (<= 0 fp-sign:car.a)
      (if (<= 0 fp-sign:car.b)
          (cons (fp-*-floor2 car.a car.b)
                (fp-*-ceiling2 cdr.a cdr.b))
          (cons (fp-*-floor2 cdr.a car.b)
                (if (< fp-sign:cdr.b 0)
                    (fp-*-ceiling2 car.a cdr.b)
                    (fp-*-ceiling2 cdr.a cdr.b))))
      (<= 0 fp-sign:car.b)
      (cons (fp-*-floor2 car.a cdr.b)
            (if (< fp-sign:cdr.a 0)
                (fp-*-ceiling2 cdr.a car.b)
                (fp-*-ceiling2 cdr.a cdr.b)))
      (>= fp-sign:cdr.a 0) ;(neg neg) * (neg ?)
      (cons (if (> fp-sign:cdr.b 0)
                (fp-*-floor2 car.a cdr.b)
                (fp-*-floor2 cdr.a cdr.b))
            (fp-*-ceiling2 car.a car.b))
      ;(neg pos) * (neg pos)
      (cons (fp-min2 (fp-*-floor2 car.a cdr.b)
                     (fp-*-floor2 cdr.a car.b))
            (fp-max2 (fp-*-ceiling2 car.a car.b)
                     (fp-*-ceiling2 cdr.a cdr.b)))))
;hmm, should I allow +inf and -inf? ... no, they fuck with add/sub.
;maybe eventually later. for now, spoilsport.
;could just invert b and call multiply...
;yes. laziness wins. division is hard. propagate nils or smthg? yes.
;this is low-level. a bigger thing will test for nil and do recomputation.
;this interval code is unaware of the recomputation.
;heh heh. (-2 -1) -> (-1/1 -1/2); (1 2) -> (1/2 1/1).
(def iv-invert (x)
    (if (or (> fp-sign:car.x 0) (< fp-sign:cdr.x 0))
        (cons fp-invert-floor:cdr.x ;damn, forgot to floor/ceiling
              fp-invert-ceiling:car.x)
        nil))

;ok here we get into iffy issues.
;if you keep div-ing an integer to make it smaller, you expect it to
;reach zero eventually. that is a useful termination condition.
;but will that happen with interval numbers?
;it can't exactly, unless you do some kind of zero sem... FUCK.
;this is the thing I anticipated earlier. when computing an upper
;bound, you want to take a ceiling, not a floor.
;so.. -1 getting divided -> [-1 0]
;1 getting divided -> [0 1]
;starting at 0 -> [0 0]
;butt getting divided -> [-1 1]
(def iv-zerop (x)
  (and (< -2 car:car.x) (< car:cdr.x 2)))

;oh crap should not lose more accuracy than necessary
;neh, leave that to higher-level interfaces
(def iv-/2 (a b)
  #;(if (< cdar.b cdar.a)
      (zap [iv-promote _ cdar.a] b))
  (aif iv-invert.b
       (iv-*2 a it)
       nil))

;All right, goddammit.
;I want to generate some nice, fast-ish-in-the-case-of-2-args code
;that uses case-lambda. I will need to get butt.
;This shall be done right.
;We will want to promote all arguments to the most accurate version.
;Normally, for all args, I'd write something like:
;(let xn (reduce max (map accuracy args))
;  (let args (map [promote _ xn] args)
;
;combiner, mapper, combiner... coercer...

;`(let xn ,(combiner 'max (mapper 'shift))
;   ,(combiner 'iv-+2 (mapper '[promote _ xn])))

;from-left semantics
;shall automatic names be arg0 arg1, or arg1 arg2? 
(def apply-combiner-from-left (n comb expr arg-name)
  (xloop (n n)
    (if (is n 1)
        (expr:arg-name dec.n);`(,expr (arg-name dec.n))
        `(,comb ,(apply-combiner-from-left dec.n comb expr arg-name)
                ,(expr (arg-name dec.n))))))
(def acfl args (apply apply-combiner-from-left args))
;(acfl 3 '+ [list 'abs _] [symb 'arg _])

;The "mapper" thing should therefore take a function that takes n and
;returns the (possibly) altered nth argument, and return a function that
;takes n and returns the (definitely) altered nth argument.
;So I'm an idiot.
(def apply-combiner-from-left (n comb arg-name)
  (xloop (n n)
    (if (is n 1)
        (arg-name dec.n);`(,expr (arg-name dec.n))
        `(,comb ,(apply-combiner-from-left dec.n comb arg-name)
                ,(arg-name dec.n)))))
;(acfl 3 '+ (compose [list 'abs _] [symb 'arg _]))

;Now for some consistency.

(def apply-combiner-from-left (n comb arg-name)
  (if (is n 1)
      (arg-name dec.n);`(,expr (arg-name dec.n))
      (comb (apply-combiner-from-left dec.n comb arg-name)
            (arg-name dec.n))))

;(acfl 3 (fn (a b) `(+ ,a ,b)) (compose [list 'abs _] [symb 'arg _]))
;(acfl 3 (compose [cons '+ _] list)
;        (compose [list 'abs _] [symb 'arg _]))

;Oh, and, the n case.
;Jesus, how do you do n case?  Mmm.  The arg-name needs to be separate
;from the mapper, because 
(def apply-combiner-from-left (n comb expr (o arg-name [symb 'arg _])
                                 (o coercer nil))
  (with (comb (if (isa comb 'sym)
                  (fn (x y) (list comb x y))
                  comb)
         expr (if (isa expr 'sym)
                  (fn (x) (list expr x))
                  expr))
    ([if coercer
         `(with ,(if (isa n 'sym)
                     `(,n (map ,coercer ,n))
                     (mappend (compose coercer arg-name) (range 0 dec.n)))
            ,_)
         _]
     (if (isa n 'sym)
         `(reduce ,(w/uniq (x y)
                     `(fn (,x ,y) ,(comb x y)))
                  (map ,(w/uniq x (fn (,x) ,(expr x))) ,n))
         (xloop (n n)
           (if (is n 1)
               (expr:arg-name dec.n);`(,expr (arg-name dec.n))
               (comb (next dec.n)
                     (expr:arg-name dec.n))))))))

;no, the coercer goes in the main function, not subroutines.

(def code-ify (f)
  (if (isa f 'fn)
      f
      (fn args (cons f args))))

;performance quandary... macros!
(def iv-int (x)
  (cons (cons x 0) (cons x 0)))
(mac iv (x (o n))
  (if (isa x 'int)
      `',(iv-int x)
      `(iv-ify ,x ,n)))
(= iv-zero iv.0
   iv-one iv.1)
      
      

(def apply-combiner-from-left (n comb expr (o arg-name [symb 'arg _]))
  (with (comb code-ify.comb
         expr code-ify.expr)
    (if (isa n 'sym)
        `(reduce ,(w/uniq (x y)
                    `(fn (,x ,y) ,(comb x y)))
                 (map ,(w/uniq x (fn (,x) ,(expr x))) ,n))
        (xloop (n n)
          (if (is n 1)
              (expr:arg-name dec.n);`(,expr (arg-name dec.n))
              (comb (next dec.n)
                    (expr:arg-name dec.n)))))))



(def coercify (n coercer (o arg-name [symb 'arg _]))
  (zap code-ify coercer)
  (fn body
    `(with ,(if (isa n 'sym)
                `(,n (map ,coercer ,n))
                (mappend (compose coercer arg-name) (range 0 dec.n)))
       ,@body)))

;NOOB YOU'RE AN IDIOT
;SUPPLY THE ARGLIST AS AN ARGUMENT.
;I DOUBT IF THERE IS ANYTHING WRONG WITH THAT APPROACH

;Hmm, so... choice.
;The "f" argument to make-map could be a function that takes a symbol
;and returns an expression, or it could be just an expression (usually symbol).
;Given the former choice, the explicit-args case is natural, and the rest-args
;case can be handled by the map code making `(fn (gs) ,(f 'gs)). Given the latter
;choice, the rest-args case is natural, and the explicit-args case can be handled
;by the programmer writing '[f _ xn]. The former offers more flexibility (optimization?),
;but the latter is conceptually simpler. I think latter for now.
;They should be equivalent given a good compiler: ([f _ xn] x) should = (f x xn),
;and likewise (fn (gs) (func gs)) should = func.

;Hmmph, obviously I do not have a good compiler. Doesn't lambda-lift.
;(let y 5 ([+ _ y] 2)) allocates a closure every time.  Fuck it.
;All right, time for polymorphism. code-ify.

;... Fuck. This is difficult. But in the n-arg case, you are necessarily
;already allocating garbage, so I guess I'll tolerate that. Also it would
;be good for error-reporting, I guess.

(def dick-ify (f)
  (fn args
    (if no.args
        f
        (isa f 'sym)
        (cons f args)
        (apply eval.f args))))
(def make-funcall (f . args)
  `(fn ,args ,(apply f args)))

(def make-apply (f xs) ;maybe dickify f ;yes ;but not here
  (if (isa xs 'sym)
      `(apply ,f ,xs)
      `(,f ,@xs)))
(def make-map (f xs)
  (zap code-ify f)
  (if (isa xs 'sym)
      `(map ,(make-funcall f (uniq)) ,xs)
      (map f xs)))
(def make-reduce (f xs)
  (zap code-ify f)
  (if (isa xs 'sym)
      `(reduce ,(make-funcall f (uniq) (uniq)) ,xs)
      no.xs
      (err "Fuck, handle zero case specially.")
       #;(xloop (x car.xs xs cdr.xs)
        (if no.xs
            x
            (next (list f x car.xs) cdr.xs)))
      (reduce f xs)))
(def make-len (xs)
  (if (isa x 'sym)
      `(len ,xs)
      len.xs))
(def make-uniq (xs)
  (if (isa x 'sym)
      (uniq)
      (map [uniq] xs)))
(def make-bind (var val . body)
  (if (isa var 'sym)
      `(let ,var ,val ,@body)
      `(with ,(flat1:map list var val) ,@body)))
(def pairwise (f xs)
  (if no:cdr.xs
      t
      (and (f car.xs cadr.xs)
           (pairwise f cdr.xs))))
(def make-pairwise (f xs) ;f = (fn (x y))
  (zap code-ify f)
  (if (isa xs 'sym)
      `(pairwise ,(make-funcall f (uniq) (uniq)) ,xs)
      `(and ,@(map f xs cdr.xs))))

(def iv-coerce (x)
  (if acons.x x
      (isa x 'int) (cons (cons x 0) (cons x 0))
      (err "iv-coerce: How?" x)))
(def iv-len (x)
  (max cdar.x cddr.x))

(def iv-len2 (x)
  (if (isa x 'int)
      0
      (max cdar.x cddr.x)))

#;(def c-a-p (arglist . body)
  (make-bind arglist (make-map 'iv-coerce arglist)
    (w/uniq xn
      `(let ,xn ,(make-apply 'max (make-map 'iv-len arglist))
         ,(apply make-bind arglist (make-map `[iv-promote _ ,xn] arglist)
                 body)))))
(def c-a-p2 (arglist . body) ;winrar
  (w/uniq xn
    `(let ,xn ,(make-apply 'max (make-map 'iv-len2 arglist))
       ,(apply make-bind arglist (make-map (fn (x)
                                             `(iv-ify2 ,x ,xn))
                                           arglist)
               body))))

(def iv-ify2 (x n)
  (if acons.x
      (iv-promote2 x n)
      (iv-ify x n)))
(def iv-promote2 (x n)
  (if (and (is cdar.x n) (is cddr.x n))
      x
      (iv-promote x n)))

#;(def make-iv++ (arglist)
  (c-a-p arglist
    (make-reduce 'iv-+2 arglist)))

;Testing indicates it is better to do (reduce / args) than (/ car.args (reduce * cdr.args)).
;So I can treat all this crap uniformly.
(each op '(+ - * /)
  (= (symbol-value:symb 'make-iv- op)
     (eval `(fn (arglist)
              (c-a-p2 arglist
                      (make-reduce ',(symb 'iv- op '2) arglist))))))

;Note: Apart from putting a bit of stress on the compiler, there seems to be no problem
;whatsoever with, say, nesting a bazillion "do"s.  (Compilation time appears quadratic in
;the number of "do"s.)

(each (op nerfs) (tuples 2 '(+ ((() iv.0)
                                1 2 3)
                             - ((() (err "No arguments"))
                                ((x) (iv-negate x))
                                2 3)
                             * ((() iv.1)
                                1 2 3)
                             / ((() (err "No arguments"))
                                ((x) (iv-invert x))
                                2 3)))
  (= (symbol-value:symb 'iv- op)
     (let expander (symbol-value:symb 'make-iv- op)
       (eval `(case-fn
               ,@(mappend (fn (x)
                            (if acons.x
                                (let (arglist . body) x
                                  (list arglist `(do ,@body)))
                                (let arglist (if (isa x 'sym)
                                                 x
                                                 (mapn [symb 'arg _] 1 x))
                                  (list arglist (expander arglist)))))
                          (join nerfs '(args))))))))

(def max2 (x y)
  (if (> y x)
      y
      x))

(= max
   (let expander (fn (arglist)
                   (make-reduce 'max2 arglist))
     (eval `(case-fn
             ,@(mappend (fn (x)
                          (let arglist (if (isa x 'sym)
                                           x
                                           (mapn [symb 'arg _] 1 x))
                            (list arglist (expander arglist))))
                        '(2 3 args))))))
(def iv-<=2 (x y)
  (no:fp->2 cdr.x car.y))
(def iv->=2 (x y)
  (no:fp-<2 car.x cdr.y))
(= code (table))
(def install-code (name source-code)
  (= symbol-value.name (eval source-code)
     code.name source-code))
(each (op nerfs) (tuples 2 '(< (2 3)
                             > (2 3)
                             <= (2 3)
                             >= (2 3)))
  (withs (op (symb 'iv- op) op-2 (symb op 2))
    (install-code op
                  `(case-fn ,@(mappend (fn (x)
                                         (let arglist (if (isa x 'sym)
                                                          x
                                                          (mapn [symb 'arg _] 1 x))
                                           (list arglist (c-a-p2 arglist
                                                                 (make-pairwise op-2 arglist)))))
                                       (join nerfs '(args)))))))

;All right, so, after all this, iv-+ is 3x slower than iv-+2, and 2x slower than in
;(def iv-+ args (reduce iv-+2 args)).  Mmm... But iv-+ also does this coercion stuff,
;so that is probably to be expected.


#;(def make-iv+ (arglist)
  (make-bind arglist (make-map 'iv-coerce arglist)
    `(let xn ,(make-apply 'max (make-map 'iv-len arglist))
       ,(make-reduce 'iv-+2 (make-map '[iv-promote _ xn] arglist)))))
#;(def make-iv- (arglist)
  (make-bind arglist (make-map 'iv-coerce arglist)
    `(let xn ,(make-apply 'max (make-map 'iv-len arglist))
       ,(make-reduce 'iv-+2 (make-map '[iv-promote _ xn] arglist)))))

;Hmm, I need coercion, to avoid repeatedly converting numbers to things.

'((0 () 0)
  (1 (n) n)
  2
  3)

'((0 () 0)
  (1 (n) (iv-negate n))
  2 3)

;'((0 () 1)
;  
;
;(def make-case-fn (expr)
;  
;
;(def apply-combiner-
;
;
;  (if (is n 1)
;      (expr arg-name.0)
;      `(,comb ,(apply-combiner-from-left (expr arg-name.0 arglist.1)
;              arglist.0
;              ,(apply-combiner
;
;(let xn (reduce 
;(def iv-+ args
;  (let xn (reduce max (map cdar args))
;    (
;
;(with 
;(def buh-expr (
;(each x 


;Ok, now for some examples.
(def fp-ify (x n)
  (cons (floor:* x (expt 10 n)) n))
(def iv-ify (x n)
  (let u (* x (expt 10 n))
    (cons (cons floor.u n)
          (cons ceiling.u n))))
(def iv-drop (x n)
  (cons (cons (floor-div caar.x (expt 10 (- cdar.x n))) n)
        (cons (ceiling-div cadr.x (expt 10 (- cddr.x n))) n)))
(def fp->rat (x)
  (/ car.x (expt 10 cdr.x)))
(def de-iv (x) ;this is the worst use of "compare" ever
  (* 1/2 ((compare + fp->rat) car.x cdr.x)))
(def deiv (x)
  inex:de-iv.x)

;now how do we calculate tau.
;c-x c-g u, btw, -> τ
;two methods in mind. one is euler acceleration, the other is
;arctan 1/2 + arctan 1/3.
;the latter is nicer, easier, etc. so.
;first, show that 45 degrees = arctan 1/2 + arctan 1/3.
;tan a = 1/2, tan b = 1/3
;tan(a+b) = tana+tanb / 1-tanatanb = 1/2+1/3 / 1-1/2*1/3
; = 5/6 / 5/6 = 1.
;so tan(a+b) = 1, so a+b is 45 degrees mod 180 degrees, so it's
;pretty obviously 45 degrees indeed.
;So tau = 8 * (arctan 1/2 + arctan 1/3).
;Now, supposedly taylor series for arctan looks like:
;x/1 - x^3/3 + x^5/5 - ...
;If so, this gives a nicely convergent series at 1/2 and 1/3.
;It remains to establish that this series is correct.
;f = tan
;f^-1 = arctan
;d(f^-1)/dx = d(f^-1) / df(f^-1) = 1 / df(f^-1)/df^-1 = 1/f'(f^-1)
;arctan' = 1/tan'(arctan)
;tan' = sin/cos ' = cos/cos + sin * (1/cos)'
;= 1 + sin * cos' * -1/cos^2 = 1 + sin * -sin / -cos^2
;= 1 + tan^2 = sec^2
;sec(arctan): 1, x, √(1+x^2) --> sec(arctan x) = 1/(1+x^2)
;f = arctan; f(0) = 0
;f' = 1/(1+x^2); f'(0) = 1
;now how can we try to generalize this crap...
;maybe it would help to use a relation with ln. probably, yeah.
;ln x -> 1/x -> -1/x^2 -> 2/x^3 -> ... -> (-1)^n-1 * (n-1)! / x^n
;at x=1, all x^n are 1, and ln 1 = 0, so:
;ln(x) = (x-1) - (x-1)^2/2 + (x-1)^3/3 - (x-1)^4/4 + ...
;ln(x+1) = x - x^2/2 + x^3/3 - ...
;1/2 [ln(x+1) - ln(-x+1)] = x + x^3/3 + x^5/5 + ...
;1/2 [ln(ix+1) - ln(-ix+1)] = ix - ix^3/3 + ix^5/5 - ...
;hmm, I expected to need to think about all four x, ix, -x, -ix, but
;it seems I just need two.  Oh well.
;-i/2 [ln(ix+1) - ln(-ix+1)] = x - x^3/3 + x^5/5 - ... = "arctan x"

;x will probably be real. note that if e^(r+iy) = a+bi, then
; r^2 = a^2+b^2 and tan y = b/a. so ln(a+bi) = r+iy (mod iτ)
; = √(a^2+b^2) + i*arctan(b/a) (mod iτ). that formula is probably
;still correct even if a and b aren't purely real.
;"arctan x" =? -i/2 [ln(1+ix) - ln(1-ix)]
;= -i/2 [(√(x^2+1) + i*arctan x) - (√(x^2+1) - i*arctan x) mod iτ]
;= -i/2 [2i * arctan x (mod iτ)]
;= arctan x (mod τ/2)
;which is absolutely, absolutely, absolutely perfect.

;OH MY GOOOOOOOOOOOOOOOOOOOOOOOOOOD
;(arctan x)' = 1/(1+x^2) = 1 / [1 - (-x^2))
; = 1 - x^2 + x^4 - x^6 + ...
;arctan x = ∫ 1 - x^2 + x^4 - ...
; = x/1 - x^3/3 + x^5/5 - ...
;So much simpler. Only possible issue is convergence.

;very well. τ = 8(arctan 1/2 + arctan 1/3)
;= 8((1/2) - (1/2)^3/3 + (1/2)^5/5 - ...) + 8((1/3) - (1/3)^3/3 + ...).

(def iv-tau (n #;(o maxi 101))
  (when (< n 0)
    (err "WTF negative decimal places?" n))
  ;now let's be hella unthinkingly conservative
  (let xn (+ n 2 (ceiling-log (+ n 1) 10))
    (xloop (two (iv-ify 8/2 xn)
            three (iv-ify 8/3 xn)
            i 1 tt (iv-ify 0 xn))
      (if (iv-zerop two)
          (iv-drop tt n)
          #;(is i maxi)
          #;(list n xn two three i tt)
          (next (iv-/2 two (iv-ify -4 xn))
                (iv-/2 three (iv-ify -9 xn))
                (+ i 2)
                (iv-+2 tt (let u (iv-ify i xn)
                            (iv-+2 (iv-/2 two u)
                                   (iv-/2 three u)))))))))

(def iv-square (x)
  (iv-*2 x x))
(def iv-negate (x)
  (cons (cons -:cadr.x cddr.x)
        (cons -:caar.x cdar.x)))
(def iv-promote (x n)
  (cons (fp-promote car.x n)
        (fp-promote cdr.x n)))
(def iv-abs (x)
  (if (> caar.x 0)
      x
      (< cadr.x 0)
      iv-negate.x
      (cons (cons 0 cdar.x)
            (cons (max -:caar.x cadr.x) cddr.x))))
;this is strict
(def iv-<2 (a b)
  (fp-<2 cdr.a car.b))
(def iv->2 (a b)
  (fp->2 car.a cdr.b))

;taylor series... hellza convergent.
;i wonder if you might try modding out by tau. assuming you had tau
;precomputed, which is pretty likely.
;for the moment, screw that.
;x - x^3/3! + x^5/5! - ...
(def iv-sin (x)  ;Hm. Defined like this, sin([-ε,ε]) = [0,0]. Is this
  (if iv-zerop.x ;a problem? Not sure.
      x
      (withs (n (max cdar.x cddr.x)
              xn (+ n 2 (ceiling-log (+ n 1) 10))
              x (iv-promote x xn)
              nub (iv-*2 (iv-ify -1 xn) (iv-square x)))
        #;(prsn x n xn nub)
        (xloop (tm x i 1 tt (iv-ify 0 xn))
          (let f (iv-/2 nub (iv-*2 (iv-ify (+ i 1) xn)
                                   (iv-ify (+ i 2) xn)))
            #;(prsn tm i tt)
            #;(prsn 'f f)
            (if (and iv-zerop.tm
                     (iv-<2 iv-abs.f (iv-ify 1 xn)))
                (iv-drop tt n)
                (next (iv-*2 tm f)
                      (+ i 2)
                      (iv-+2 tm tt))))))))

;1 - x^2/2! + ...
;could also define by subtracting butt from 90 deg or smthg but fuck
(def iv-cos (x)
  (if iv-zerop.x
      x
      (withs (n (max cdar.x cddr.x)
              xn (+ n 2 (ceiling-log (+ n 1) 10))
              x (iv-promote x xn)
              nub (iv-*2 (iv-ify -1 xn) (iv-square x)))
        #;(prsn x n xn nub)
        (xloop (tm (iv-ify 1 xn) i 0 tt (iv-ify 0 xn))
          (let f (iv-/2 nub (iv-*2 (iv-ify (+ i 1) xn)
                                   (iv-ify (+ i 2) xn)))
            #;(prsn tm i tt)
            #;(prsn 'f f)
            (if (and iv-zerop.tm
                     (iv-<2 iv-abs.f (iv-ify 1 xn)))
                (iv-drop tt n)
                (next (iv-*2 tm f)
                      (+ i 2)
                      (iv-+2 tm tt))))))))

(def striv (x)
  (let ((a . n) . (b . m)) x
    (if (isnt n m)
        (err "Wtf? Diff acc" x)
        (withs ((a b)
                (map (fn (x)
                       (let u num->digs:abs.x
                         ([let (a b) (split _ (- len._ n))
                            (join a '(#\.) b)]
                          (join (if (< x 0) '(-))
                                (n-of (- n len.u) 0)
                                u))))
                     (list a b)))
          #;(prsn a b)
          (aif (mismatch a b)
               (string (cut a 0 it) "{"
                       (cut a it) ","
                       (cut b it) "}")
               string.a)))))
(= str-iv striv)

;hmmph, cos tau/6 seemed to yield something without .5 within the interval.
;how? fuck. shit is supposed to be absolutely conservative.

#;(def fuck (a y)
  (generic-mat-solve-linear a y iv-+ iv-- iv-* iv-/ iv-invert no:iv-invert iv-negate))

(def ufuck (xs)
  (= hh xs uu (the-matrix xs 3000) uuinv mat-inv.uu aa (mat-mul uu uuinv) aa2 (mat-mul uuinv uu))
  (bestn 6 (compare > car)
         (join (map [list _ 1] (invq uu uuinv)) (map [list _ 2] (invq uuinv u)))))
(def fuck (a b)
  (join (mapn [make-note t _] a b) (mapn [make-note nil _] a b)))
(def fuck-sin (a b)
  (join (mapn [make-note nil _] a b)))
(def fuck-cos (a b)
  (join (mapn [make-note t _] a b)))

(def invq (a b (o n 5))
  (bestn n > (map abs (map [- _a _b] (flat:mat-mul a b) flat:mat-id:len.a))))

(def generic-sum (f a b plus zero)
  (xloop (a a tt zero)
    (if (> a b)
        tt
        (next (+ a 1) (plus f.a tt)))))

(def generic-the-matrix (fs n (o plus +) (o times *) (o zero 0))
  (let fs (map cadr fs)
    (map (fn (f)
           (map (fn (g)
                  (generic-sum [times f._ g._] 0 dec.n plus zero))
                fs))
         fs)))

;Generic Newton's method.
;g -> g - (f(g) - v) / f'(g)
;f = x^n
;as for the error...
;we want to bound guess, not to bound f(guess), by some error.
;we could be like "assume f is roughly sloped by that much"
;and so compute err(guess) = err(f(guess)) / f'(guess).
;However... if f'(guess) rapidly decreases as you approach the
;correct guess, then... that would suck.
;Eh... maybe leave some complexity to the user.
;The user may know what f'' is like, and then g is useful.
(def generic-newton (f f-prime value guess minus divide close-enough)
  (let off-by (minus f.guess value)
    (if (close-enough guess off-by)
        guess
        (generic-newton f f-prime value
                        (minus guess (divide off-by f-prime.guess))
                        minus divide close-enough))))
;this is with positive integers n...
;f' is n*x^n-1. f' > n for x>1. hmmph.
;OH GOD NO
;the right way to actually do this with intervals is to have something compute
;an upper bound and something compute a lower bound.
;Or I could do what I did before and just increase accuracy for the duration of
;this computation. I'd probably have to do that anyway.
;It is a stupid idea to accumulate errors as you go g -> g - ass.
;So...
;... What I did for int-nthroot was to use Newton's method until steps were at most 1,
;then degrade to binary search. And there was no "tolerance"...
(def generic-nthroot (x n tol exponentiate minus times divide magnitude less one)
  (generic-newton [exponentiate _ n]
                  [times n (exponentiate _ dec.n)]
                  x
                  one
                  minus divide
                  (fn (g off)
                    (less (magnitude off) (times n (times (exponentiate g dec.n) tol))))))

;for x^n, g -> g - (g^n - v)/(ng^n) = g - g/n + v/ng^n-1 = (g*n-1 + v/g^n-1)/n
;... can I do something simple and piggyback off int-nthroot?
;Would that be prohibitively expensive?

;DUMB VERSION
(def fp-nthroot-floor (x n)
  (let (x . xn) x
    (cons (int-nthroot (* x (expt 10 (* xn dec.n)))) ;integer size xn*n
          xn)))

;HELLA AWESOME VERSION
;do something like doubling accuracy each time (Wiki says you can do that)

;... Time to embrace our inner base 2.
;For finding nthroot(2^an):
;If our guess is 2^b, then our next is [(n-1)*2^b + 2^((a-b)n+b)]/n
; = 2^b * [(n-1) + 2^((a-b)n)] / n
;As b -> infinity, h -> g * (n-1)/n, which is horrible. One bit per step when n=2,
;(g = guess, h = next guess, x = number we want)
;.58 bits per step when n=3... log_2(1 - 1/n) when n=n...
;As b -> -infinity, h -> g^n-1 * 


;;All right, time to do what I discuss in newt-testing.
;;First...
;(def fp-nthroot (fpx n)
;  (let (x . xn) fpx
;    (let 
;
;(def fp-nthroot-floor (x n)
;  (let (x . xn) x
;    (if (< x (expt 10 xn)) ;jesu christo
;        
;    (xloop (g (expt 10 (+ xn (div (* 3 int-len.x) n))))
;      (let u (div (+ 

;Fast exponentiation is more accurate.
(def iv-fast-expt (x n)
  (fast-expt-* x n iv-one iv-*))


;... I had written some plans somewhere. Don't know if they were lost.
;Anyway, the gist is:
;- use binary search as base case (~2 digits of accuracy) for nthroot.
;- use small integers, keep doubling in size.
;  with small integers, having several steps in the binary search part
;  is not much of a problem. no need to do crazy memoization crap.
;- fork into upper and lower when the half-chunks diverge.
;  (like, upper and lower will likely agree up to n/2 or at least n/4 digits,
;  so split into two operations then.)

;For this part, I permit myself to use binary. Here it is just math.
;... Let's see... the shift part... also ubersmall numbers...
;IIIIIIIIIIDIOT just extend the number.
;e.g. sqrt (5000 . 3) => sqrt (50000 . 4) if desired.
;Floor and ceiling need to be computed correctly; that's it.
;... I suppose we are just maintaining "output has same fixed-point
;precision as input" semantics...
;Fuck, no, that isn't really how it should go.
;Eventually, it should be "as exact as necessary", specified at endpoints,
;and then carried backwards.
;I'm afraid that'll come with a reworking of things. (so that iv's come with
;history closures and you can make them make themselves more accurate)
;For the moment, I can afford to do this...
(def iv-nthroot (x n)
  (

;So, let's see. 

;(def iv-nthroot (x n)
;  (generic-nthroot (iv-promote x n 
;                   iv-fast-expt 
                   

;There are two obvious methods to computing (expt-rat x a/b).
;One is to compute (nthroot x b) and use that directly.
;The other is to repeatedly take square roots and find convergence.
;The latter is good (and workable) for inexact exponents.
;Probably the former is good for exact exponents.
(def iv-expt-rat (x n)
  (if (isa n 'int)
      (iv-fast-expt x n)
      (with (a numer.n b denom.n)
        (iv-* (iv-fast-expt (iv-nthroot x b) (mod a b))
              (iv-fast-expt x (div a b))))))
(def iv-expt (x n)
  (if (iv-<2 n 0)
      
      
(def make-iv-sin (xn actually-cos (o n 0) (o sample-rate 44100))
  (let u (iv-/ (iv-* iv-tau.xn ) sample-rate)
    (if actually-cos
        [iv-cos:iv-* u _]
        [iv-sin:iv-* u _])))
(def make-iv-note (xn is-cos (o n 0) (o sample-rate 44100))
  `((,(if is-cos 'cos 'sin) ,n ,xn)
    ,(make-iv-sin is-cos (* 440 (

(def mat-nsolve-linear (a y)
  (generic-mat-nsolve-linear a y + - * / / [is _ 0] -))

(def make-sin (actually-cos (o freq 440) (o sample-rate 44100))
  (let u (/ (* tau freq) sample-rate)
    (if actually-cos
        [cos:* u _]
        [sin:* u _])))

(def make-note (is-cos (o n 0) (o sample-rate 44100))
  `((,(if is-cos 'cos 'sin) ,n)
    ,(make-sin is-cos (* 440 (expt 2 (/ n 12))) sample-rate)))


;sin(a+t) = sinacost + cosasint
;cos(a+t) = cosacost - sinasint
(def change-phase ((a b) dθ)
  (list (- (* a cos.dθ) (* b sin.dθ))
        (+ (* a sin.dθ) (* b cos.dθ))))

(defmemo glob2 ((o xs b) (o n 0) (o intv 3000))
  (map (fn (sin x) (list car.sin car.x))
       fs
       (mat-mul am (map [list:meh cadr._ (take intv (drop n xs))] fs))))
(defmemo herp ((o xs b) (o n 0) (o intv 3000))
  (map [list:meh cadr._ (take intv (drop n xs))] fs))






;Time for Tsukihime...
;Skipping first four bars or something for now.