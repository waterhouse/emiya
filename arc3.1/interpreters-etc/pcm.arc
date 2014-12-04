
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
(= us nil)

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
(def play-note (n (o length 3) (o delay t) (o reterm t))
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





;Time for Tsukihime...
;Skipping first four bars or something for now.