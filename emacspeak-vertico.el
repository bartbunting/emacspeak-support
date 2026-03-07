;;; emacspeak-vertico.el --- Speech-enable Vertico -*- lexical-binding: t; -*-
;; Description: Speech-enable Vertico, a vertical minibuffer completion UI
;; Keywords: Emacspeak, Audio Desktop, Vertico, completion

;;;   Copyright:
;; This file is not part of GNU Emacs, but the same permissions apply.
;;
;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.
;;
;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:
;; Vertico is a vertical minibuffer completion UI that powers M-x,
;; find-file, consult commands, etc.  This module speech-enables Vertico
;; so that Emacspeak speaks the current candidate during navigation and
;; announces candidate count changes while the user types to filter.
;;
;; Behaviour:
;;   - Opening a Vertico session announces the total candidate count.
;;   - Typing to filter announces the new count when it changes.
;;   - Navigation (next/previous/first/last/scroll) speaks the current
;;     candidate with its position ("3 of 47: describe-function ...").
;;   - Annotations from marginalia (or any annotation-function) are
;;     appended to the spoken text.
;;   - Selecting or exiting plays a confirmation icon.

;;; Code:

;;   Required modules:

(eval-when-compile (require 'cl-lib))
(require 'emacspeak-preamble)
(require 'vertico nil 'noerror)

;;;  Silence byte-compiler about internal Vertico variables:

(defvar vertico--candidates)
(defvar vertico--index)
(defvar vertico--total)

;;;  Forward declarations:

(declare-function vertico--update "vertico" ())

;;;  Face to voice mapping:

(voice-setup-add-map
 '((vertico-current voice-bolden)
   (vertico-group-title voice-annotate)
   (vertico-group-separator voice-monotone)))

;;;  State tracking:

(defvar emacspeak-vertico--navigating nil
  "Non-nil when a Vertico navigation command is executing.
Used to prevent double-speaking from `vertico--update' advice
when navigation internally triggers an update.
This is a dynamically-bound variable; navigation advice wraps
`ad-do-it' in a `let' binding so `vertico--update' sees it as t.")

(defvar emacspeak-vertico--prev-total nil
  "Candidate total from the previous `vertico--update' call.
Made buffer-local in each minibuffer session so nested minibuffers
each track their own count independently.")

;;;  Helper functions:

(defun emacspeak-vertico--current-candidate ()
  "Return the currently selected candidate string, or nil."
  (when (and (bound-and-true-p vertico--candidates)
             (bound-and-true-p vertico--index)
             (>= vertico--index 0)
             (< vertico--index (length vertico--candidates)))
    (nth vertico--index vertico--candidates)))

(defun emacspeak-vertico--annotation (candidate)
  "Return annotation string for CANDIDATE via completion metadata, or nil."
  (when (and candidate (minibufferp))
    (let* ((md (completion-metadata
                (buffer-substring-no-properties
                 (minibuffer-prompt-end) (point))
                minibuffer-completion-table
                minibuffer-completion-predicate))
           (aff (completion-metadata-get md 'affixation-function))
           (ann (completion-metadata-get md 'annotation-function)))
      (cond
       (aff
        ;; affixation-function returns ((candidate prefix suffix) ...) for each candidate
        (let* ((entry (car (funcall aff (list candidate))))
               (prefix (and (consp entry) (nth 1 entry)))
               (suffix (and (consp entry) (nth 2 entry)))
               (combined (string-trim (concat (or prefix "") " " (or suffix "")))))
          (unless (string-empty-p combined) combined)))
       (ann
        (let ((raw (funcall ann candidate)))
          (when raw
            (let ((s (string-trim raw)))
              (unless (string-empty-p s) s)))))))))

(defun emacspeak-vertico--speak-candidate ()
  "Speak current candidate with position count and annotation."
  (let* ((candidate (emacspeak-vertico--current-candidate))
         (total (or (bound-and-true-p vertico--total) 0))
         (index (when (and (bound-and-true-p vertico--index)
                           (>= vertico--index 0))
                  (1+ vertico--index)))
         (annotation (when candidate (emacspeak-vertico--annotation candidate))))
    (dtk-speak
     (string-trim
      (concat
       (or candidate (format "%d candidates" total))
       (when annotation (concat " " annotation))
       (when (and candidate index)
         (format " %d of %d" index total)))))))

;;;  Advice navigation commands (around, to set navigating flag):

(cl-loop
 for (f icon) in
 '((vertico-next select-object)
   (vertico-previous select-object)
   (vertico-first large-movement)
   (vertico-last large-movement)
   (vertico-scroll-up scroll)
   (vertico-scroll-down scroll))
 do
 (eval
  `(defadvice ,f (around emacspeak pre act comp)
     "Speak the newly selected candidate."
     (let ((emacspeak-vertico--navigating t))
       ad-do-it)
     (when (ems-interactive-p)
       (emacspeak-icon ',icon)
       (emacspeak-vertico--speak-candidate)))))

;;;  Advice exit commands:

(dolist (f '(vertico-exit vertico-exit-input))
  (eval
   `(defadvice ,f (after emacspeak pre act comp)
      "Play confirmation sound on selection."
      (when (ems-interactive-p)
        (emacspeak-icon 'select-object)))))

(defadvice vertico-insert (after emacspeak pre act comp)
  "Speak inserted candidate text."
  (when (ems-interactive-p)
    (emacspeak-icon 'complete)
    (emacspeak-speak-line)))

;;;  Advice internal update to announce filter changes:

(defadvice vertico--update (after emacspeak pre act comp)
  "Speak candidate count when it changes due to user input (not navigation)."
  (unless emacspeak-vertico--navigating
    (when (bound-and-true-p vertico--total)
      (let ((new-total vertico--total))
        (cond
         ;; First update in this session: announce total
         ((null emacspeak-vertico--prev-total)
          (dtk-speak (format "%d candidates" new-total)))
         ;; Total changed (user typed): announce new count or no-match
         ((not (= new-total emacspeak-vertico--prev-total))
          (dtk-speak (if (zerop new-total) "no match"
                       (format "%d candidates" new-total)))))
        (setq emacspeak-vertico--prev-total new-total)))))

;;;  Minibuffer setup:

(defun emacspeak-vertico--minibuffer-setup ()
  "Initialize per-session Vertico speech state."
  (make-local-variable 'emacspeak-vertico--prev-total)
  (setq emacspeak-vertico--prev-total nil))

(defun emacspeak-vertico-setup ()
  "Setup Emacspeak support for Vertico."
  (add-hook 'minibuffer-setup-hook #'emacspeak-vertico--minibuffer-setup))

(eval-after-load "vertico" #'emacspeak-vertico-setup)

;;;  Enable/Disable support:

(defvar emacspeak-vertico--advice-list
  '((vertico-next around)
    (vertico-previous around)
    (vertico-first around)
    (vertico-last around)
    (vertico-scroll-up around)
    (vertico-scroll-down around)
    (vertico-exit after)
    (vertico-exit-input after)
    (vertico-insert after)
    (vertico--update after))
  "List of advised functions for Emacspeak Vertico support.")

(defun emacspeak-vertico-enable ()
  "Enable Emacspeak support for Vertico."
  (interactive)
  (dolist (advice emacspeak-vertico--advice-list)
    (ad-enable-advice (car advice) (cadr advice) 'emacspeak)
    (ad-activate (car advice)))
  (emacspeak-vertico-setup)
  (message "Enabled Emacspeak Vertico support"))

(defun emacspeak-vertico-disable ()
  "Disable Emacspeak support for Vertico."
  (interactive)
  (dolist (advice emacspeak-vertico--advice-list)
    (ad-disable-advice (car advice) (cadr advice) 'emacspeak)
    (ad-activate (car advice)))
  (remove-hook 'minibuffer-setup-hook #'emacspeak-vertico--minibuffer-setup)
  (message "Disabled Emacspeak Vertico support"))

;;;  Provide the module:

(provide 'emacspeak-vertico)

;;; emacspeak-vertico.el ends here
