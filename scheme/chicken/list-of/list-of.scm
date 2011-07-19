;;;; list-of.scm - by Phil Bewig


(module list-of (fold-of list-of)

(import scheme)

(define-syntax fold-of
  (syntax-rules (range in is)
    ((_ "aux" op acc expr) (set! acc (op acc expr)))
    ((_ "aux" op acc expr (var range first past step) clause ...)
     (let* ((f first) (p past) (s step) (le? (if (positive? s) <= >=)))
       (do ((var f (+ var s))) ((le? p var) acc)
	 (fold-of "aux" op acc expr clause ...))))
    ((_ "aux" op acc expr (var range first past) clause ...)
     (let* ((f first) (p past) (s (if (< f p) 1 -1)))
       (fold-of "aux" op acc expr (var range f p s) clause ...)))
    ((_ "aux" op acc expr (v in vs) clause ...)
     (do ((lst vs (cdr lst))) ((null? lst) acc)
       (let ((v (car lst))) (fold-of "aux" op acc expr clause ...))))
    ((_ "aux" op acc expr (x is y) clause ...)
     (let ((x y)) (fold-of "aux" op acc expr clause ...)))
    ((_ "aux" op acc expr pred? clause ...)
     (if pred? (fold-of "aux" op acc expr clause ...)))
    ((_ op base expr clause ...)
     (let ((acc base)) (fold-of "aux" op acc expr clause ...)))))

(define-syntax list-of
  (syntax-rules () 
    ((_ arg ...)
     (reverse (fold-of (lambda (d a) (cons a d)) '() arg ...)))))

)
