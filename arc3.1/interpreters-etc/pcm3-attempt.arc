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

(defmemo the-matrix (fs n)
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
  (def mat-invert (xs)
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

(def careful (symbol tolerance)
  (let f historical.symbol
    (fn (x y) ;oh dear
      (let u (f x y)
        (if (< tolerance (- (max size.x size.y) size.u)

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