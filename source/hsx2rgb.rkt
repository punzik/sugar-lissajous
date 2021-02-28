#lang racket

(define (hsl2rgb h s l)
  (define (color q p h)
    (let ((tc (cond
               ((> h 1) (- h 1))
               ((< h 0) (+ h 1))
               (else h))))
      (cond
       ((< tc 1/6) (+ p (* (- q p) tc 6)))
       ((< tc 1/2) q)
       ((< tc 2/3) (+ p (* (- q p) (- 2/3 tc) 6)))
       (else p))))
  (let* ((q (if (< l 0.5)
                (* l (+ 1 s))
                (+ l s (- (* l s)))))
         (p (- (* 2 l) q)))
    (values
     (inexact->exact (round (* 256 (color q p (+ h 1/3)))))
     (inexact->exact (round (* 256 (color q p h))))
     (inexact->exact (round (* 256 (color q p (- h 1/3))))))))

(define (hsl2rgb-ref h s l)
  (hsl2rgb (/ h 256) (/ s 256) (/ l 256)))

(define (hsv2rgb h s v)
  (let* ((hi (modulo (floor (/ h 256/6)) 6))
         (vmin (/ (* v (- 256 s)) 256))
         (a (* (- v vmin) (/ (modulo h 43) 256/6)))
         (vinc (+ vmin a))
         (vdec (- v a))

         (vmin (inexact->exact (round vmin)))
         (vinc (inexact->exact (round vinc)))
         (vdec (inexact->exact (round vdec))))
    (cond
     ((= hi 0) (values v vinc vmin))
     ((= hi 1) (values vdec v vmin))
     ((= hi 2) (values vmin v vinc))
     ((= hi 3) (values vmin vdec v))
     ((= hi 4) (values vinc vmin v))
     ((= hi 5) (values v vmin vdec)))))

(define (hsv2rgb-int h s v)
  (define (byte-div-43-mod-6 x)
    (cond
     ((< x 43) 0)
     ((< x 86) 1)
     ((< x 128) 2)
     ((< x 171) 3)
     ((< x 214) 4)
     (else 5)))

  (define (byte-mod-43 x)
    (cond
     ((< x 43) x)
     ((< x 86) (- x 43))
     ((< x 128) (- x 86))
     ((< x 171) (- x 128))
     ((< x 214) (- x 171))
     (else (- x 214))))

  (define (*6 a) (+ (arithmetic-shift a 1)
                    (arithmetic-shift a 2)))

  (let* ((hi (byte-div-43-mod-6 h))
         (vmin (arithmetic-shift
                (* (- 255 s) v) -8))
         (a (arithmetic-shift
             (* (- v vmin)
                (*6 (byte-mod-43 h))) -8))
         (vinc (+ vmin a))
         (vdec (- v a)))
    (printf "hi=~a, vmin=~a, a=~a, vinc=~a, vdec=~a\n" hi vmin a vinc vdec)
    (cond
     ((= hi 0) (values v vinc vmin))
     ((= hi 1) (values vdec v vmin))
     ((= hi 2) (values vmin v vinc))
     ((= hi 3) (values vmin vdec v))
     ((= hi 4) (values vinc vmin v))
     ((= hi 5) (values v vmin vdec)))))

(define (hsl2rgb-int h s l)
  (define (*fp8 a b) (arithmetic-shift (* a b) -8))
  (define (*2 a) (arithmetic-shift a 1))
  (define (*6 a) (+ (arithmetic-shift a 1)
                    (arithmetic-shift a 2)))

  (define c1/6 43)
  (define c1/3 85)
  (define c1/2 128)
  (define c2/3 171)
  (define c1 256)

  (let* ((l*s (*fp8 l s))
         (q (if (< l c1/2)
                (+ l l*s)
                (+ l s (- l*s))))
         (p (- (*2 l) q))
         (q-p ;;(- q p)
          (*2 (- q l)))
         (tr (if (< h c2/3) [+ h c1/3] [- c1/3 (- c1 h)]))
         (tg h)
         (tb (if (>= h c1/3) [- h c1/3] [- c1 h]))
         (q-p*6 (*6 q-p))

         (r (cond
             ((< tr c1/6) [+ p (*fp8 q-p*6 tr)])
             ((< tr c1/2) q)
             ((< tr c2/3) [+ p (*fp8 q-p*6 (- c2/3 tr))])
             (else p)))

         (g (cond
             ((< tg c1/6) [+ p (*fp8 q-p*6 tg)])
             ((< tg c1/2) q)
             ((< tg c2/3) [+ p (*fp8 q-p*6 (- c2/3 tg))])
             (else p)))

         (b (cond
             ((< tb c1/6) [+ p (*fp8 q-p*6 tb)])
             ((< tb c1/2) q)
             ((< tb c2/3) [+ p (*fp8 q-p*6 (- c2/3 tb))])
             (else p))))
    ;;    (printf "q=~a p=~a q-p=~a tr=~a tg=~a tb=~a\n" q p q-p tr tg tb)
    (values r g b)))

(define (p f h s x)
  (let-values (((r g b) (f h s x)))
    (printf "HSX ~a ~a ~a -> " h s x)
    (printf "RGB ~a ~a ~a\n\n" r g b)))

;;(p 20 255 100)
(p hsv2rgb-int  50 100 150)
(p hsv2rgb-int 111 222 33)
(p hsv2rgb-int 200 150 50)
