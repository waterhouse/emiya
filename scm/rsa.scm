;To run:
; Open in DrRacket.
; Go Language -> Choose Language... -> Other Languages -> Pretty Big.
; Press Run.

;Usage:
;Jake wants to send a message to John.
;John runs (john-prepare 1000) to set up an RSA key using 1000-bit primes.
;John pastes the output, (jake-prepare [number] [number]), to Jake.
; (This is the RSA public key.)
;Jake runs that command, (jake-prepare [number] [number]).
;Jake chooses a password that isn't too long, like "thing and stuff".
; (Various extant programs may be used to encrypt/decrypt a file with a
;  symmetric key, given a password.  Rarely is RSA used in practice to
;  directly encrypt large files.)
;Jake runs (jake-encrypt "thing and stuff").
;Jake pastes the output, (john-decrypt [number]), to John.
;John runs that command, (john-decrypt [number]), and gets back "thing and stuff".


(load "math.scm")
(abbrev mod modulo)

;(def inv (a m) ;Space-consuming recursive implementation
;  (if (is a 1)
;      1
;      (is a 0)
;      0+i
;      (let b (inv (mod (- m) a) a)
;        (/ (1+ (* b m))
;           a))))

(def bezout (a b) ;Constant space
  (def slave (a x1 y1 b x2 y2)
    (if (is b 0)
        (list x1 y1)
        (with (q (quotient a b) r (remainder a b))
          (slave b x2 y2
                 r (- x1 (* q x2)) (- y1 (* q y2))))))
  (slave a 1 0
         b 0 1))

(def inv (a m)
  (mod (car (bezout a m)) m))

(def make-key (p q)
  (with (m (* p q) phim (* (1- p) (1- q)) e (big-random phim))
    (while (not (is 1 (gcd e phim)))
      (set! e (big-random phim)))
    (let d (inv e phim)
      (prn "e:" e)
      (prn "d:" d)
      (prn "m:" m)
      (list e d m))))

(def fermat-prime? (p)
  (def test (i)
    (if (is i 20)
        #t
        (not (is 1 (mod-expt (1+ (big-random (1- p))) (1- p) p)))
        #f
        (test (1+ i))))
  (test 0))

(def quick-prime? (p) ;product of primes up to 1000; speed hack
  (is 1 (gcd p 19590340644999083431262508198206381046123972390589368223882605328968666316379870661851951648789482321596229559115436019149189529725215266728292282990852649023362731392404017939142010958261393634959471483757196721672243410067118516227661133135192488848989914892157188308679896875137439519338903968094905549750386407106033836586660683539201011635917900039904495065203299749542985993134669814805318474080581207891125910)))

(def get-prime (bits)
  (let n (expt 2 (1- bits))
    (def slave ()
      (let cand (+ n (big-random n))
        (if (and (quick-prime? cand) (fermat-prime? cand))
            cand
            (slave))))
    (slave)))

(abbrev a-s arithmetic-shift)

(def big-random (n)
  (if (> n 2147483647)
      (+ (a-s (big-random (a-s n -31)) 31)
         (random 2147483647))
      (random n)))
(= flr (compose inexact->exact floor))
(def halve (n)
  (a-s n -1))

(def make-rsa (bits)
  (make-key (get-prime bits) (get-prime bits)))


;> (= x (make-rsa 100))
;e: 49772188276251460435866026041 d: 445895166945274930997826104089 m: 480399892234933551652529075873 
;> (= e (car x))
;> (= d (cadr x))
;> (= m (caddr x))
;> e
;49772188276251460435866026041
;> (= a 873242387485498)
;> (= aenc (show (mod-expt a e m)))
;71570101059415593462624080102
;> (= adec (show (mod-expt aenc d m)))
;873242387485498
;> (is adec a)
;#t



(def str->num (str);chars -> 0-127
  (digs->num (map char->integer (string->list str))
             128))
(def num->str (n)
  (list->string
   (map integer->char
        (num->digs n 128))))
(= enc-key nil)
(= dec-key nil)
(= key-mod nil)

(def jake-prepare (e m)
  (set! enc-key e)
  (set! key-mod m))

(def jake-encrypt (password)
  (let u (str->num password)
    (if (> u key-mod)
        "pick a smaller password"
        `(john-decrypt ,(mod-expt u enc-key key-mod)))))

(def john-decrypt (crypt)
  (num->str (mod-expt crypt dec-key key-mod)))

(def john-prepare (bits)
  (let u (make-rsa bits)
    (set! enc-key (car u))
    (set! dec-key (cadr u))
    (set! key-mod (caddr u))
    (list 'jake-prepare enc-key key-mod)))



