;;; compat-28.1.el --- Compatibility Layer for Emacs 28.1  -*- lexical-binding: t; -*-

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

;; Find here the functionality added in Emacs 28.1, needed by older
;; versions.
;;
;; Do NOT load this library manually.  Instead require `compat'.

;;; Code:

(eval-when-compile (require 'compat-macs))
(declare-function compat-maxargs-/= "compat" (func n))

;;;; Defined in fns.c

(compat-defun string-search (needle haystack &optional start-pos)
  "Search for the string NEEDLE in the strign HAYSTACK.

The return value is the position of the first occurrence of
NEEDLE in HAYSTACK, or nil if no match was found.

The optional START-POS argument says where to start searching in
HAYSTACK and defaults to zero (start at the beginning).
It must be between zero and the length of HAYSTACK, inclusive.

Case is always significant and text properties are ignored."
  (when (and start-pos (< start-pos 0))
    (signal 'args-out-of-range (list start-pos)))
  (let ((inhibit-changing-match-data t)
        (case-fold-search nil))
    (string-match (regexp-quote needle) haystack start-pos)))

(compat-defun length= (sequence length)
  "Returns non-nil if SEQUENCE has a length equal to LENGTH."
  (cond
   ((null sequence) (zerop length))
   ((consp sequence)
    (and (null (nthcdr length sequence))
         (nthcdr (1- length) sequence)
         t))
   ((arrayp sequence)
    (= (length sequence) length))
   ((signal 'wrong-type-argument sequence))))

(compat-defun length< (sequence length)
  "Returns non-nil if SEQUENCE is shorter than LENGTH."
  (cond
   ((null sequence) (not (zerop length)))
   ((listp sequence)
    (null (nthcdr (1- length) sequence)))
   ((arrayp sequence)
    (< (length sequence) length))
   ((signal 'wrong-type-argument sequence))))

(compat-defun length> (sequence length)
  "Returns non-nil if SEQUENCE is longer than LENGTH."
  (cond
   ((listp sequence)
    (and (nthcdr length sequence) t))
   ((arrayp sequence)
    (> (length sequence) length))
   ((signal 'wrong-type-argument sequence))))

;;;; Defined in fileio.c

(compat-defun file-name-concat (directory &rest components)
  "Append COMPONENTS to DIRECTORY and return the resulting string.
Elements in COMPONENTS must be a string or nil.
DIRECTORY or the non-final elements in COMPONENTS may or may not end
with a slash -- if they don’t end with a slash, a slash will be
inserted before contatenating."
  (let ((seperator (eval-when-compile
                     (if (memq system-type '(ms-dos windows-nt cygwin))
                         "\\" "/")))
        (last (if components (car (last components)) directory)))
    (mapconcat (lambda (part)
                 (if (eq part last)	;the last component is not modified
                     last
                   (replace-regexp-in-string
                    (concat seperator "+\\'") "" part)))
               (cons directory components)
               seperator)))

;;;; Defined in alloc.c

(compat-defun garbage-collect-maybe (_factor)
  "Call ‘garbage-collect’ if enough allocation happened.
FACTOR determines what \"enough\" means here: If FACTOR is a
positive number N, it means to run GC if more than 1/Nth of the
allocations needed to trigger automatic allocation took place.
Therefore, as N gets higher, this is more likely to perform a GC.
Returns non-nil if GC happened, and nil otherwise."
  ;; Do nothing
  nil)

;;;; Defined in filelock.c

(compat-advise unlock-buffer ()
  "Handle `file-error' conditions:

Handles file system errors by calling ‘display-warning’ and
continuing as if the error did not occur."
  (condition-case error
      (funcall oldfun)
    (file-error
     (display-warning
      '(unlock-file)
      (message "%s, ignored" (error-message-string error))
      :warning))))

;;;; Defined in characters.c

(compat-advise string-width (string &optional from to)
  "Handle optional arguments FROM and TO:

Optional arguments FROM and TO specify the substring of STRING to
consider, and are interpreted as in `substring'."
  :cond (compat-maxargs-/= #'string-width 3)
  (funcall oldfun (substring string (or from 0) to)))

;;;; Defined in dired.c

(compat-advise directory-files (directory &optional full match nosort count)
  "Handle additional optional argument COUNT:

If COUNT is non-nil and a natural number, the function will
 return COUNT number of file names (if so many are present)."
  :cond (compat-maxargs-/= #'directory-files 5)
  (let ((files (funcall oldfun directory full match nosort)))
    (when (natnump count)
      (setf (nthcdr count files) nil))
    files))

;;;; Defined in json.c

(compat-advise json-serialize (object &rest args)
  "Handle top-level JSON values."
  :cond (condition-case err
            ;; Use `random' to prevent byte compiler from optimising
            ;; the "pure" `json-serialize' call.
            (ignore (json-serialize (if (random) 0 0)))
          (wrong-type-argument (eq (cadr err) 'json-value-p)))
  :realname compat--json-serialize-handle-tlo
  :min-version "27"
  (if (or (listp object) (vectorp object))
      (apply oldfun object args)
    (substring (json-serialize (list object)) 1 -1)))

(compat-advise json-insert (object &rest args)
  "Handle top-level JSON values."
  :cond (condition-case err
            ;; Use `random' to prevent byte compiler from optimising
            ;; the "pure" `json-serialize' call.
            (ignore (json-serialize (if (random) 0 0)))
          (wrong-type-argument (eq (cadr err) 'json-value-p)))
  :realname compat--json-insert-handle-tlo
  :min-version "27"
  (if (or (listp object) (vectorp object))
      (apply oldfun object args)
    (insert (apply #'compat--json-serialize-handle-tlo oldfun object args))))

(compat-advise json-parse-string (string &rest args)
  "Handle top-level JSON values."
  :cond (condition-case nil
            ;; Use `random' to prevent byte compiler from optimising
            ;; the "pure" `json-serialize' call.
            (ignore (json-parse-string (if (random) "0" "0")))
          (json-parse-error t))
  :realname compat--json-parse-string-handle-tlo
  :min-version "27"
  (if (string-match-p "\\`[[:space:]]*[[{]" string)
      (apply oldfun string args)
    ;; Wrap the string in an array, and extract the value back using
    ;; `elt', to ensure that no matter what the value of `:array-type'
    ;; is we can access the first element.
    (elt (apply oldfun (concat "[" string "]") args) 0)))

(compat-advise json-parse-buffer (&rest args)
  "Handle top-level JSON values."
  :cond (condition-case nil
            ;; Use `random' to prevent byte compiler from optimising
            ;; the "pure" `json-serialize' call.
            (ignore (json-parse-string (if (random) "0" "0")))
          (json-parse-error t))
  :realname compat--json-parse-buffer-handle-tlo
  :min-version "27"
  (if (looking-at-p "[[:space:]]*[[{]")
      (apply oldfun args)
    (catch 'escape
      (atomic-change-group
        (with-syntax-table
            (let ((st (make-syntax-table)))
              (modify-syntax-entry ?\" "\"" st)
              (modify-syntax-entry ?. "_" st)
              st)
          (let ((inhibit-read-only t))
            (save-excursion
            (insert "[")
            (forward-sexp 1)
            (insert "]"))))
        (throw 'escape (elt (apply oldfun args) 0))))))

;;;; Defined in subr.el

(compat-defun string-replace (fromstring tostring instring)
  "Replace FROMSTRING with TOSTRING in INSTRING each time it occurs."
  (when (equal fromstring "")
    (signal 'wrong-length-argument '(0)))
  (let ((case-fold-search nil))
    (replace-regexp-in-string
     (regexp-quote fromstring)
     tostring instring
     t t)))

(compat-defun always (&rest _arguments)
  "Do nothing and return t.
This function accepts any number of ARGUMENTS, but ignores them.
Also see `ignore'."
  t)

(compat-defun insert-into-buffer (buffer &optional start end)
  "Insert the contents of the current buffer into BUFFER.
If START/END, only insert that region from the current buffer.
Point in BUFFER will be placed after the inserted text."
  (let ((current (current-buffer)))
    (with-current-buffer buffer
      (insert-buffer-substring current start end))))

(compat-defun replace-regexp-in-region (regexp replacement &optional start end)
  "Replace REGEXP with REPLACEMENT in the region from START to END.
The number of replaced occurrences are returned, or nil if REGEXP
doesn't exist in the region.

If START is nil, use the current point.  If END is nil, use `point-max'.

Comparisons and replacements are done with fixed case.

REPLACEMENT can use the following special elements:

  `\\&' in NEWTEXT means substitute original matched text.
  `\\N' means substitute what matched the Nth `\\(...\\)'.
       If Nth parens didn't match, substitute nothing.
  `\\\\' means insert one `\\'.
  `\\?' is treated literally."
  (if start
      (when (< start (point-min))
        (error "Start before start of buffer"))
    (setq start (point)))
  (if end
      (when (> end (point-max))
        (error "End after end of buffer"))
    (setq end (point-max)))
  (save-excursion
    (let ((matches 0)
          (case-fold-search nil))
      (goto-char start)
      (while (re-search-forward regexp end t)
        (replace-match replacement t)
        (setq matches (1+ matches)))
      (and (not (zerop matches))
           matches))))

(compat-defun buffer-local-boundp (symbol buffer)
  "Return non-nil if SYMBOL is bound in BUFFER.
Also see `local-variable-p'."
  (catch 'fail
    (condition-case nil
        (buffer-local-value symbol buffer)
      (void-variable nil (throw 'fail nil)))
    t))

(declare-function gensym nil (&optional prefix))
(compat-defmacro with-existing-directory (&rest body)
  "Execute BODY with `default-directory' bound to an existing directory.
If `default-directory' is already an existing directory, it's not changed."
  (declare (indent 0) (debug t))
  (let ((quit (gensym)))
    `(catch ',quit
       (dolist (dir (list default-directory
                          (expand-file-name "~/")
                          (getenv "TMPDIR")
                          "/tmp/"
                          ;; XXX: check if "/" works on non-POSIX
                          ;; system.
                          "/"))
         (when (and dir (file-exists-p dir))
           (throw ',quit (let ((default-directory dir))
                           ,@body)))))))

(compat-defmacro dlet (binders &rest body)
  "Like `let' but using dynamic scoping."
  (declare (indent 1) (debug let))
  `(let (_)
     ,@(mapcar (lambda (binder)
                 `(defvar ,(if (consp binder) (car binder) binder)))
               binders)
     (let ,binders ,@body)))

(compat-defun ensure-list (object)
  "Return OBJECT as a list.
If OBJECT is already a list, return OBJECT itself.  If it's
not a list, return a one-element list containing OBJECT."
  (if (listp object)
      object
    (list object)))

;;;; Defined in subr-x.el

(compat-defun string-clean-whitespace (string)
  "Clean up whitespace in STRING.
All sequences of whitespaces in STRING are collapsed into a
single space character, and leading/trailing whitespace is
removed."
  :feature subr-x
  (let ((blank "[[:blank:]\r\n]+"))
    (replace-regexp-in-string
     "^[[:blank:]\r\n]+\\|[[:blank:]\r\n]+$"
     ""
     (replace-regexp-in-string
      blank " " string))))

(compat-defun string-fill (string length)
  "Clean up whitespace in STRING.
All sequences of whitespaces in STRING are collapsed into a
single space character, and leading/trailing whitespace is
removed."
  :feature subr-x
  (with-temp-buffer
    (insert string)
    (goto-char (point-min))
    (let ((fill-column length)
          (adaptive-fill-mode nil))
      (fill-region (point-min) (point-max)))
    (buffer-string)))

(compat-defun string-lines (string &optional omit-nulls)
  "Split STRING into a list of lines.
If OMIT-NULLS, empty lines will be removed from the results."
  :feature subr-x
  (split-string string "\n" omit-nulls))

(compat-defun string-pad (string length &optional padding start)
  "Pad STRING to LENGTH using PADDING.
If PADDING is nil, the space character is used.  If not nil, it
should be a character.

If STRING is longer than the absolute value of LENGTH, no padding
is done.

If START is nil (or not present), the padding is done to the end
of the string, and if non-nil, padding is done to the start of
the string."
  :feature subr-x
  (unless (natnump length)
    (signal 'wrong-type-argument (list 'natnump length)))
  (let ((pad-length (- length (length string))))
    (if (< pad-length 0)
        string
      (concat (and start
                   (make-string pad-length (or padding ?\s)))
              string
              (and (not start)
                   (make-string pad-length (or padding ?\s)))))))

(compat-defun string-chop-newline (string)
  "Remove the final newline (if any) from STRING."
  :feature subr-x
  (if (and (>= (length string) 1) (= (aref string (1- (length string))) ?\n))
      (substring string 0 -1)
    string))

(compat-defmacro named-let (name bindings &rest body)
  "Looping construct taken from Scheme.
Like `let', bind variables in BINDINGS and then evaluate BODY,
but with the twist that BODY can evaluate itself recursively by
calling NAME, where the arguments passed to NAME are used
as the new values of the bound variables in the recursive invocation."
  :feature subr-x
  (declare (indent 2) (debug (symbolp (&rest (symbolp form)) body)))
  (let ((fargs (mapcar (lambda (b)
                         (let ((var (if (consp b) (car b) b)))
                           (make-symbol (symbol-name var))))
                       bindings))
        (aargs (mapcar (lambda (b) (if (consp b) (cadr b))) bindings))
        rargs)
    (dotimes (i (length bindings))
      (let ((b (nth i bindings)))
        (push (list (if (consp b) (car b) b) (nth i fargs))
              rargs)
        (setf (if (consp b) (car b) b)
              (nth i fargs))))
    (letrec
        ((quit (make-symbol "quit")) (self (make-symbol "self"))
         (total-tco t)
         (macro (lambda (&rest args)
                  (setq total-tco nil)
                  `(apply ,self (list ,@args))))
         ;; Based on `cl--self-tco':
         (tco-progn (lambda (exprs)
                      (append
                       (butlast exprs)
                       (list (funcall tco (car (last exprs)))))))
         (tco (lambda (expr)
                (cond
                 ((eq (car-safe expr) 'if)
                  (append (list 'if
                                (cadr expr)
                                (funcall tco (caddr expr)))
                          (funcall tco-progn (cdddr expr))))
                 ((eq (car-safe expr) 'cond)
                  (cons 'cond
                        (mapcar (lambda (branch)
                                  (list
                                   (car branch)
                                   (funcall tco-progn (cdr expr))))
                                (cdr expr))))
                 ((eq (car-safe expr) 'or)
                  (if (cddr expr)
                      (let ((var (make-symbol "var")))
                        `(let ((,var ,(cadr expr)))
                           (if ,var ,(funcall tco var)
                             ,(funcall tco (cons 'or (cddr expr))))))
                    (funcall tco (cadr expr))))
                 ((memq (car-safe expr) '(and progn))
                  (cons (car expr) (funcall tco-progn (cdr expr))))
                 ((memq (car-safe expr) '(let let*))
                  (append (list (car expr) (cadr expr))
                          (funcall tco-progn (cddr expr))))
                 ((eq (car-safe expr) name)
                  (let (sets)
                    (dolist (farg fargs)
                      (push (list farg (pop (cdr expr)))
                            sets))
                    (cons 'setq (apply #'nconc (nreverse sets)))))
                 (`(throw ',quit ,expr))))))
      (let ((tco-body (funcall tco (macroexpand-all (macroexp-progn body)))))
        (when tco-body
          (setq body `((catch ',quit
                         (while t (let ,rargs ,@(macroexp-unprogn tco-body))))))))
      (let ((expand (macroexpand-all (macroexp-progn body) (list (cons name macro)))))
        (if total-tco
            `(let ,bindings ,expand)
          `(funcall
            (letrec ((,self (lambda ,fargs ,expand))) ,self)
            ,@aargs))))))

;;;; Defined in files.el

(declare-function compat--string-trim-left "compat-26.1" (string &optional regexp))
(declare-function compat--directory-name-p "compat-25.1" (name))
(compat-defun file-name-with-extension (filename extension)
  "Set the EXTENSION of a FILENAME.
The extension (in a file name) is the part that begins with the last \".\".

Trims a leading dot from the EXTENSION so that either \"foo\" or
\".foo\" can be given.

Errors if the FILENAME or EXTENSION are empty, or if the given
FILENAME has the format of a directory.

See also `file-name-sans-extension'."
  (let ((extn (compat--string-trim-left extension "[.]")))
    (cond
     ((string= filename "")
      (error "Empty filename"))
     ((string= extn "")
      (error "Malformed extension: %s" extension))
     ((compat--directory-name-p filename)
      (error "Filename is a directory: %s" filename))
     (t
      (concat (file-name-sans-extension filename) "." extn)))))

(compat-defun directory-empty-p (dir)
  "Return t if DIR names an existing directory containing no other files.
Return nil if DIR does not name a directory, or if there was
trouble determining whether DIR is a directory or empty.

Symbolic links to directories count as directories.
See `file-symlink-p' to distinguish symlinks."
  (and (file-directory-p dir)
       (null (directory-files dir nil directory-files-no-dot-files-regexp t))))

;;;; Defined in minibuffer.el

(compat-defun format-prompt (prompt default &rest format-args)
  "Format PROMPT with DEFAULT.
If FORMAT-ARGS is nil, PROMPT is used as a plain string.  If
FORMAT-ARGS is non-nil, PROMPT is used as a format control
string, and FORMAT-ARGS are the arguments to be substituted into
it.  See `format' for details.

If DEFAULT is a list, the first element is used as the default.
If not, the element is used as is.

If DEFAULT is nil or an empty string, no \"default value\" string
is included in the return value."
  (concat
   (if (null format-args)
       prompt
     (apply #'format prompt format-args))
   (and default
        (or (not (stringp default))
            (not (null default)))
        (format " (default %s)"
                (if (consp default)
                    (car default)
                  default)))
   ": "))

;;;; Defined in windows.el

(compat-advise count-windows (&optional minibuf all-frames)
  "Handle optional argument ALL-FRAMES:

If ALL-FRAMES is non-nil, count the windows in all frames instead
just the selected frame."
  :cond (compat-maxargs-/= #'count-windows 2)
  (if all-frames
      (let ((sum 0))
        (dolist (frame (frame-list))
          (with-selected-frame frame
            (setq sum (+ (funcall oldfun minibuf)
                         sum))))
        sum)
    (funcall oldfun minibuf)))

;;;; Defined in thingatpt.el

(declare-function mouse-set-point "mouse" (event &optional promote-to-region))
(compat-defun thing-at-mouse (event thing &optional no-properties)
  "Return the THING at mouse click.
Like `thing-at-point', but tries to use the event
where the mouse button is clicked to find a thing nearby."
  :feature thingatpt
  (save-excursion
    (mouse-set-point event)
    (thing-at-point thing no-properties)))

;;;; Defined in macroexp.el

(compat-defun macroexp-file-name ()
  "Return the name of the file from which the code comes.
Returns nil when we do not know.
A non-nil result is expected to be reliable when called from a macro in order
to find the file in which the macro's call was found, and it should be
reliable as well when used at the top-level of a file.
Other uses risk returning non-nil value that point to the wrong file."
  :feature macroexp
  (let ((file (car (last current-load-list))))
    (or (if (stringp file) file)
        (bound-and-true-p byte-compile-current-file))))

;;;; Defined in env.el

(compat-defmacro with-environment-variables (variables &rest body)
  "Set VARIABLES in the environent and execute BODY.
VARIABLES is a list of variable settings of the form (VAR VALUE),
where VAR is the name of the variable (a string) and VALUE
is its value (also a string).

The previous values will be be restored upon exit."
  (declare (indent 1) (debug (sexp body)))
  (unless (consp variables)
    (error "Invalid VARIABLES: %s" variables))
  `(let ((process-environment (copy-sequence process-environment)))
     ,@(mapcar (lambda (elem)
                 `(setenv ,(car elem) ,(cadr elem)))
               variables)
     ,@body))

;;;; Defined in button.el

(compat-defun button-buttonize (string callback &optional data)
  "Make STRING into a button and return it.
When clicked, CALLBACK will be called with the DATA as the
function argument.  If DATA isn't present (or is nil), the button
itself will be used instead as the function argument."
  :feature button
  (propertize string
              'face 'button
              'button t
              'follow-link t
              'category t
              'button-data data
              'keymap button-map
              'action callback))

(provide 'compat-28.1)
;;; compat-28.1.el ends here
