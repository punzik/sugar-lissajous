#! /usr/bin/env racket
#lang racket/gui

(require racket/gui/base)

(define display-width 240)
(define display-height 320)
(define fb-size (* display-width display-height))

(define (set-pixel! fb x y r g b)
  (let ((i (* 4 (+ x (* y display-width)))))
    (bytes-set! fb (+ i 0) 255)
    (bytes-set! fb (+ i 1) r)
    (bytes-set! fb (+ i 2) g)
    (bytes-set! fb (+ i 3) b)))

(define (clear-screen fb r g b)
  (for-each
   (lambda (n)
     (let ((n (* n 4)))
       (bytes-set! fb (+ n 0) 255)
       (bytes-set! fb (+ n 1) r)
       (bytes-set! fb (+ n 2) g)
       (bytes-set! fb (+ n 3) b)))
   (range fb-size)))

;;; MAIN
(let* ((frame-buffer (make-bytes (* fb-size 4)))
       (frame-bitmap (make-bitmap display-width display-height))

       (frame (new frame%
                   (label "LCD")
                   (min-width display-width)
                   (min-height display-height)
                   (stretchable-width #f)
                   (stretchable-height #f)))

       (canvas (new canvas% (parent frame)
                    (paint-callback
                     (lambda (canvas dc)
                       (send frame-bitmap
                             set-argb-pixels 0 0
                             display-width display-height
                             frame-buffer)
                       (send dc draw-bitmap frame-bitmap 0 0)))))

       (cmdl (current-command-line-arguments))
       (pipe (if (zero? (vector-length cmdl)) #f (vector-ref cmdl 0))))


  (clear-screen frame-buffer 50 100 150)
  (send frame show #t)

  ;; Read pixels data
  (thread (λ ()
            (let ((thunk
                   (lambda ()
                     (let loop ()
                       (let ((s (read-line)))
                         (if (eof-object? s)
                             (loop) ;; (send frame show #f)
                             (let ((l (string-split s)))
                               (when (= 5 (length l))
                                 (let* ((x (string->number (list-ref l 0)))
                                        (y (string->number (list-ref l 1)))
                                        (r (string->number (list-ref l 2)))
                                        (g (string->number (list-ref l 3)))
                                        (b (string->number (list-ref l 4))))
                                   (set-pixel! frame-buffer x y r g b)))
                               (loop))))))))
              (if pipe
                  (with-input-from-file "lcd_pipe" thunk)
                  (thunk)))))

  ;; Refresh screen
  (thread (lambda ()
            (let loop ()
              (send canvas refresh)
              (sleep 0.02)
              (loop)))))
