;;; compat-25.1.el --- Compatibility Layer for Emacs 25.1  -*- lexical-binding: t; -*-

;; Copyright (C) 2021 Free Software Foundation, Inc.

;; Author: Philip Kaludercic <philipk@posteo.net>
;; Keywords: lisp

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Find here the functionality added in Emacs 25.1, needed by older
;; versions.
;;
;; Do NOT load this library manually.  Instead require `compat'.

;;; Code:

(eval-when-compile (require 'compat-macs))
(declare-function compat-maxargs-/= "compat" (func n))

;;;; Defined in fns.c

(compat-advise sort (seq predicate)
  "Handle SEQ of type vector."
  :cond (condition-case nil
            (ignore (sort [] #'ignore))
          (wrong-type-argument t))
  (cond
   ((listp seq)
    (funcall oldfun seq predicate))
   ((vectorp seq)
    (let ((cseq (sort (append seq nil) predicate)))
      (dotimes (i (length cseq))
        (setf (aref seq i) (nth i cseq)))
      (apply #'vector cseq)))
   ((signal 'wrong-type-argument 'list-or-vector-p))))

;;;; Defined in editfns.c

(compat-defun format-message (string &rest objects)
  "Format a string out of a format-string and arguments.
The first argument is a format control string.
The other arguments are substituted into it to make the result, a string.

This implementation is equivalent to `format'."
  (apply #'format string objects))

;;;; Defined in minibuf.c

;; TODO advise read-buffer to handle 4th argument

;;;; Defined in fileio.c

(compat-defun directory-name-p (name)
  "Return non-nil if NAME ends with a directory separator character."
  (eq (eval-when-compile
        (if (memq system-type '(cygwin windows-nt ms-dos))
            ?\\ ?/))
      (aref name (1- (length name)))))

;;;; Defined in subr.el

(compat-defun string-greaterp (string1 string2)
  "Return non-nil if STRING1 is greater than STRING2 in lexicographic order.
Case is significant.
Symbols are also allowed; their print names are used instead."
  (string-lessp string2 string1))

(compat-defmacro with-file-modes (modes &rest body)
  "Execute BODY with default file permissions temporarily set to MODES.
MODES is as for `set-default-file-modes'."
  (declare (indent 1) (debug t))
  (let ((umask (make-symbol "umask")))
    `(let ((,umask (default-file-modes)))
       (unwind-protect
           (progn
             (set-default-file-modes ,modes)
             ,@body)
         (set-default-file-modes ,umask)))))

(compat-defun alist-get (key alist &optional default remove testfn)
  "Find the first element of ALIST whose `car' equals KEY and return its `cdr'.
If KEY is not found in ALIST, return DEFAULT.
Equality with KEY is tested by TESTFN, defaulting to `eq'."
  :max-version "24.5"
  :realname compat--alist-get-full-elisp
  (ignore remove)
  (let (entry)
    (cond
     ((or (null testfn) (eq testfn 'eq))
      (setq entry (assq key alist)))
     ((eq testfn 'equal)
      (setq entry (assoc key alist)))
     ((catch 'found
        (dolist (ent alist)
          (when (and (consp ent) (funcall testfn (car ent) key))
            (throw 'found (setq entry ent))))
        default)))
    (if entry (cdr entry) default)))

;;;; Defined in subr-x.el

(compat-defmacro if-let* (varlist then &rest else)
  "Bind variables according to VARLIST and evaluate THEN or ELSE.
This is like `if-let' but doesn't handle a VARLIST of the form
\(SYMBOL SOMETHING) specially."
  :feature subr-x
  (declare (indent 2)
           (debug ((&rest [&or symbolp (symbolp form) (form)])
                   body)))
  (let ((empty (make-symbol "s"))
        (last t) list)
    (dolist (var varlist)
      (push `(,(if (cdr var) (car var) empty)
              (and ,last ,(or (cadr var) (car var))))
            list)
      (when (or (cdr var) (consp (car var)))
        (setq last (caar list))))
    `(let* ,(nreverse list)
       (if ,(caar list) ,then ,@else))))

(compat-defmacro when-let* (varlist &rest body)
  "Bind variables according to VARLIST and conditionally evaluate BODY.
This is like `when-let' but doesn't handle a VARLIST of the form
\(SYMBOL SOMETHING) specially."
  :feature subr-x
  (declare (indent 1) (debug if-let*))
  `(compat--if-let* ,varlist ,(macroexp-progn body)))

(compat-defmacro and-let* (varlist &rest body)
  "Bind variables according to VARLIST and conditionally evaluate BODY.
Like `when-let*', except if BODY is empty and all the bindings
are non-nil, then the result is non-nil."
  :feature subr-x
  (declare (indent 1) (debug if-let*))
  `(compat--when-let* ,varlist ,@(or body '(t))))

(compat-defmacro if-let (spec then &rest else)
  "Bind variables according to SPEC and evaluate THEN or ELSE.
Evaluate each binding in turn, as in `let*', stopping if a
binding value is nil.  If all are non-nil return the value of
THEN, otherwise the last form in ELSE.

Each element of SPEC is a list (SYMBOL VALUEFORM) that binds
SYMBOL to the value of VALUEFORM.  An element can additionally be
of the form (VALUEFORM), which is evaluated and checked for nil;
i.e. SYMBOL can be omitted if only the test result is of
interest.  It can also be of the form SYMBOL, then the binding of
SYMBOL is checked for nil.

As a special case, interprets a SPEC of the form \(SYMBOL SOMETHING)
like \((SYMBOL SOMETHING)).  This exists for backward compatibility
with an old syntax that accepted only one binding."
  :feature subr-x
  (declare (indent 2)
           (debug ([&or (symbolp form)
                        (&rest [&or symbolp (symbolp form) (form)])]
                   body)))
  (when (and (<= (length spec) 2)
             (not (listp (car spec))))
    ;; Adjust the single binding case
    (setq spec (list spec)))
  `(compat--if-let* ,spec ,then ,@(macroexp-unprogn else)))

(compat-defmacro when-let (spec &rest body)
  "Bind variables according to SPEC and conditionally evaluate BODY.
Evaluate each binding in turn, stopping if a binding value is nil.
If all are non-nil, return the value of the last form in BODY.

The variable list SPEC is the same as in `if-let'."
  :feature subr-x
  (declare (indent 1) (debug if-let))
  `(compat-if-let ,spec ,(macroexp-progn body)))

(compat-defmacro thread-first (&rest forms)
  "Thread FORMS elements as the first argument of their successor.
Example:
    (thread-first
      5
      (+ 20)
      (/ 25)
      -
      (+ 40))
Is equivalent to:
    (+ (- (/ (+ 5 20) 25)) 40)
Note how the single `-' got converted into a list before
threading."
  :feature subr-x
  (declare (indent 1)
           (debug (form &rest [&or symbolp (sexp &rest form)])))
  (let ((body (car forms)))
    (dolist (form (cdr forms))
      (when (symbolp form)
        (setq form (list form)))
      (setq body (append (list (car form))
                         (list body)
                         (cdr form))))
    body))

(compat-defmacro thread-last (&rest forms)
  "Thread FORMS elements as the last argument of their successor.
Example:
    (thread-last
      5
      (+ 20)
      (/ 25)
      -
      (+ 40))
Is equivalent to:
    (+ 40 (- (/ 25 (+ 20 5))))
Note how the single `-' got converted into a list before
threading."
  :feature subr-x
  (declare (indent 1) (debug thread-first))
  (let ((body (car forms)))
    (dolist (form (cdr forms))
      (when (symbolp form)
        (setq form (list form)))
      (setq body (append form (list body))))
    body))

;;;; Defined in macroexp.el

(declare-function macrop nil (object))
(compat-defun macroexpand-1 (form &optional environment)
  "Perform (at most) one step of macro expansion."
  :feature macroexp
  (cond
   ((consp form)
    (let* ((head (car form))
           (env-expander (assq head environment)))
      (if env-expander
          (if (cdr env-expander)
              (apply (cdr env-expander) (cdr form))
            form)
        (if (not (and (symbolp head) (fboundp head)))
            form
          (let ((def (autoload-do-load (symbol-function head) head 'macro)))
            (cond
             ;; Follow alias, but only for macros, otherwise we may end up
             ;; skipping an important compiler-macro (e.g. cl--block-wrapper).
             ((and (symbolp def) (macrop def)) (cons def (cdr form)))
             ((not (consp def)) form)
             (t
              (if (eq 'macro (car def))
                  (apply (cdr def) (cdr form))
                form))))))))
   (t form)))

(provide 'compat-25.1)
;;; compat-25.1.el ends here
