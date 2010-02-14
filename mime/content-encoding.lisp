;;; -*- Package: de.setf.utility.implementation; -*-

;;;  This file defines stream/buffer character set codecs. it is part of the 'de.setf.utility.mime'
;;;  library component.
;;;  (c) 2008, 2009, 2010 james anderson
;;;
;;;  'de.setf.utility.mime' is free software: you can redistribute it and/or modify
;;;  it under the terms of the GNU Lesser General Public License as published by
;;;  the Free Software Foundation, either version 3 of the License, or
;;;  (at your option) any later version.
;;;
;;;  'de.setf.utility.mime' is distributed in the hope that it will be useful,
;;;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;;;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;;  GNU Lesser General Public License for more details.
;;;
;;;  You should have received a copy of the GNU Lesser General Public License
;;;  along with 'de.setf.utility'.  If not, see the GNU <a href='http://www.gnu.org/licenses/'>site</a>.

(in-package :de.setf.utility.implementation)

;;;
;;; The names are taken from the IANA document with character set names:
;;;   [http://www.iana.org/assignments/character-sets]
;;; The codec logic is from de.setf.xml. There are alternatives, but they were not suitable
;;; - net.common-lisp.babel concerns sequence codecs
;;; - clozure cl's l1-unicode includes stream codecs, but would mean extracting them from
;;;   a much more extensive library.
;;; as the (ultimate) goal is to en/decode to/from network buffers, just the stream operators
;;; from de.setf.xml suffice.


;;;
;;; contents

(defparameter *content-encodings* (make-hash-table ))

(defclass content-encoding ()
  ((name
    :initarg :name :initform (error "name required.")
    :reader content-encoding-name
    :type keyword)
   (encoded-code-point-size
    :initform (error "encoded-code-point-size required.") :initarg :encoded-code-point-size
    :reader content-encoding-encoded-code-point-size
    :type (or integer null)
    :documentation "Specified the number of octets required to encode a code point with this
 encoding iff that is a constant. Otherwise nil.")
   (byte-decoder
    :initarg :byte-decoder :initform (error "byte-decoder required")
    :reader content-encoding-byte-decoder
    :documentation "A function of two arguments (source byte-reader),
 where the byte-reader applied to the source returns an unsigned byte,
 or NIL, for EOF")
   (byte-encoder
    :initarg :byte-encoder :initform (error "byte-encoder required")
    :reader content-encoding-byte-encoder
    :documentation "A function of two arguments (source byte-reader),
 where the byte-reader applied to the source returns an unsigned byte,
 or NIL, for EOF")))


(def-class-constructor content-encoding
  (:method ((keyword symbol) &rest initargs)
    (declare (dynamic-extent initargs))
    (flet ((define-encoding (encoding)
             ;; check the type
             (setf encoding (content-encoding encoding))
             ;; define it
             (setf (content-encoding (content-encoding-name encoding)) encoding)))
      (if (keywordp keyword)
        ;; iff additional arguments follow the initial keyword, make the instance
        ;; otherwise - for a single keyword, treat it as an encoding designator
        (if initargs
          (define-encoding (apply #'make-instance *class.content-encoding* keyword initargs))
          (content-encoding (or (gethash keyword *content-encodings*)
                                (error "Invalid character encoding: ~s." keyword))))
        (define-encoding (apply #'make-instance keyword initargs))))))

(defun (setf content-encoding) (encoding name)
  (when (gethash name *content-encodings*)
    (warn "redefining encoding: ~s." name))
  (setf (gethash name *content-encodings*) encoding))


;;;
;;; http://en.wikipedia.org/wiki/Utf-8

(flet ((utf-8-encode (char put-byte destination)
         (macrolet ((emit (code) `(funcall put-byte destination ,code)))
           (let ((code (char-code char)))
             (declare (type (mod #x100) code))
             (cond ((<= code 255)
                    (emit code))
                   ((<= code #x03ff)
                    (emit (logior #b11000000 (ash code -6)))
                    (emit (logior #b10000000 (logand code #b00111111))))
                   ((<= code #xffff)
                    (emit (logior #b11100000 (ash code -12)))
                    (emit (logior #b10000000 (logand (ash code -6) #b00111111)))
                    (emit (logior #b10000000 (logand code #b00111111))))
                   (t
                    (emit (logior #b111100000 (ash code -18)))
                    (emit (logior #b10000000 (logand (ash code -12) #b00111111)))
                    (emit (logior #b10000000 (logand (ash code -6) #b00111111)))
                    (emit (logior #b10000000 (logand code #b00111111))))))))
       (utf-8-decode (get-byte source &aux byte1)
         (flet ((read-byte-code ()
                  (or (funcall get-byte source)
                      (return-from utf-8-decode nil))))
           (declare (type fixnum byte1)
                    (ftype (function () fixnum) read-byte-code)
                    (optimize (speed 3) (safety 0)))
           (setf byte1 (read-byte-code))
           (code-char
            (cond ((= 0 (logand #x80 byte1))
                   byte1)
                  ((= #xc0 (logand #xe0 byte1))
                   (logior (ash (logand byte1 #x1f) 6)
                           (logand (read-byte-code) #x3f)))
                  ((= #xe0 (logand #xf0 byte1))
                   (logior (logior (ash (logand byte1 #x0f) 12)
                                   (ash (logand (read-byte-code) #x3f) 6))
                           (logand (read-byte-code) #x3f)))
                  ((= #xf0 (logand #xf8 byte1))
                   (logior (ash (logand #x07 byte1) 18)
                           (ash (logand #x3f (read-byte-code)) 12)
                           (ash (logand #x3f (read-byte-code)) 6)
                           (logand (read-byte-code) #x3f)))
                  (t
                   (error "Illegal UTF-8 data: x~2,'0x." byte1)))))))
  (content-encoding :name :utf-8
                    :encoded-code-point-size nil
                    :byte-decoder #'utf-8-decode
                    :byte-encoder #'utf-8-encode))


;;;
;;; http://en.wikipedia.org/wiki/ISO/IEC_8859-1

(flet ((iso-8859-1-encode (char put-byte destination)
         (let ((code (char-code char)))
           (declare (type (mod #x100) code))
           (assert (< code #x100) () "Cannot be encoded as iso-8859-1: ~s" char)
           (funcall put-byte destination code)))
       (iso-8859-1-decode (get-byte source)
         (code-char (or (funcall get-byte source)
                        (return-from iso-8859-1-decode nil)))))
  (content-encoding :name :iso-8859-1
                    :encoded-code-point-size 1
                    :byte-decoder #'iso-8859-1-decode
                    :byte-encoder #'iso-8859-1-encode))

(setf (content-encoding :us-ascii) :iso-8859-1)
(setf (content-encoding :ascii) :iso-8859-1)

;;; (eq (content-encoding :iso-8859-1) (content-encoding :us-ascii))

(defgeneric compute-charset-codecs (mime-type)
  (:method ((charset null))
    (compute-charset-codecs :iso-8859-1))
  (:method ((charset symbol))
    (compute-charset-codecs (content-encoding charset)))
  (:method ((type mime:*/*))
    (compute-charset-codecs (mime-type-charset type)))
  (:method ((encoding content-encoding))
    (values (content-encoding-byte-decoder encoding)
            (content-encoding-byte-encoder encoding))))