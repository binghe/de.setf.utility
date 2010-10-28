;;; -*- Mode: lisp; Syntax: ansi-common-lisp; Base: 10; Package: de.setf.utility.meta; -*-

;;; This file is float parser for the codec module for the 'de.setf.utility' Common Lisp library.
;;;
;;; Copyright 2010 [james anderson](mailto:james.anderson@setf.de) All Rights Reserved
;;; `de.setf.utility` is free software: you can redistribute it and/or modify it under the terms of version 3
;;; of the the GNU Lesser General Public License as published by the Free Software Foundation.
;;;
;;; `de.setf.utility` is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
;;; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
;;; See the the GNU Lesser General Public License for more details.
;;;
;;;  A copy of the GNU Lesser General Public License should be included with `de.setf.utility`, as `lgpl.txt`.
;;; If not, see the GNU [site](http://www.gnu.org/licenses/).


(in-package :de.setf.utility.meta)


(defun meta:parse-float (string &aux (s +1) (es +1) (i 0) (f 0) (e 0) (m #\e) (f-count 0) (i-count 0) (e-count 0) (v 0) d)
  (with-string-meta (string)
      (and
       (match
        "[{#\\+ [#\\- !(setq s -1)] []}
          *[@(\"0123456789\" d) !(setf i (+ (* i 10) (digit-char-p d)) i-count (1+  i-count))]
          {#\\. []}
          *[@(\"0123456789\" d) !(setf f (+ (* f 10) (digit-char-p d)) f-count (1+ f-count))]
          {@(\"eEsSdDfFlL\" m) []}
          {#\\+ [#\\- !(setq es -1)] []}
          *[@(\"0123456789\" d) !(setf e (+ (* e 10) (digit-char-p d)) e-count (1+ e-count))]
          ]")
       (when (> (+ f-count i-count) 0)
         (when (> f-count 0) (setf f (/ f (expt 10 f-count))))
         (setf v (+ i f))
         (when (plusp e-count) (setf v (* v (expt 10 (* es e)))))
         (when (< s 0) (setf v (- v)))
         (case m
           ((#\E #\e) (float v 0.0e0))
           ((#\S #\s) (float v 0.0s0))
           ((#\D #\d) (float v 0.0d0))
           ((#\F #\f) (float v 0.0s0))
           ((#\L #\l) (float v 0.0s0)))))))

