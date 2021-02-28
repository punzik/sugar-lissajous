#lang racket

(define (gen-circle-quadrant len)
  (map (lambda (n)
         (let ((angle (/ (* 2 pi n) len)))
           (cons (sin angle)
                 (cos angle))))
       (range (/ len 4))))

(define (print-xy-table table)
  (define (->hex x)
    (~a (number->string (inexact->exact (round x)) 16)
        #:min-width 2 #:align 'right #:pad-string "0"))
  (for-each
   (lambda (c)
     (printf "~a~a\n"
             (->hex (* 255 (car c)))
             (->hex (* 255 (cdr c)))))
   table))

;;; MAIN
(let ((x0 0)
      (y0 0)
      (len 1024))

  (with-output-to-file (format "quadrant_~a.rom" (/ len 4))
    (lambda ()
      (print-xy-table
       (gen-circle-quadrant len)))))
