;;; emacspeak-support.el --- Easy toggle for Emacspeak extensions -*- lexical-binding: t; -*-
;; Description: Unified loader and toggle mechanism for Emacspeak support extensions
;; Keywords: Emacspeak, Audio Desktop

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
;; This module provides a unified interface for enabling and disabling
;; Emacspeak support extensions for modern Emacs packages. Each extension
;; can be toggled on or off independently.
;;
;; Usage:
;;   M-x emacspeak-support-enable-corfu
;;   M-x emacspeak-support-enable-vertico
;;   M-x emacspeak-support-enable-which-key
;;   M-x emacspeak-support-enable-markdown
;;   M-x emacspeak-support-enable-helm
;;   M-x emacspeak-support-toggle-<extension>
;;   M-x emacspeak-support-enable-all
;;   M-x emacspeak-support-disable-all
;;   M-x emacspeak-support-status

;;; Code:

;;   Required modules:

(require 'emacspeak-preamble)

;;;  State tracking:

(defvar emacspeak-support--directory
  (file-name-directory (or load-file-name buffer-file-name))
  "Directory containing emacspeak-support and its extensions.")

(defvar emacspeak-support--extensions
  '((corfu . "emacspeak-corfu")
    (vertico . "emacspeak-vertico")
    (which-key . "emacspeak-which-key")
    (markdown . "emacspeak-markdown")
    (helm . "emacspeak-helm"))
  "Alist of extension symbols to file names.")

(defvar emacspeak-support--enabled '()
  "List of currently enabled extensions.")

;;;  Core functions:

(defun emacspeak-support--extension-file (extension)
  "Return the file path for EXTENSION."
  (let ((filename (cdr (assq extension emacspeak-support--extensions))))
    (when filename
      (concat emacspeak-support--directory filename ".el"))))

(defun emacspeak-support--extension-enabled-p (extension)
  "Return non-nil if EXTENSION is currently enabled."
  (memq extension emacspeak-support--enabled))

(defun emacspeak-support-enable (extension)
  "Enable Emacspeak support for EXTENSION."
  (interactive
   (list (intern (completing-read "Enable extension: "
                                   (mapcar #'car emacspeak-support--extensions)
                                   nil t))))
  (unless (emacspeak-support--extension-enabled-p extension)
    (let ((file (emacspeak-support--extension-file extension)))
      (if (and file (file-exists-p file))
          (progn
            (load-file file)
            (push extension emacspeak-support--enabled)
            (let ((enable-fn (intern (format "emacspeak-%s-enable" extension))))
              (when (fboundp enable-fn)
                (funcall enable-fn)))
            (emacspeak-icon 'on)
            (message "Enabled emacspeak-%s support" extension))
        (message "Extension file not found: %s" file)))))

(defun emacspeak-support-disable (extension)
  "Disable Emacspeak support for EXTENSION."
  (interactive
   (list (intern (completing-read "Disable extension: "
                                   emacspeak-support--enabled
                                   nil t))))
  (when (emacspeak-support--extension-enabled-p extension)
    (let ((disable-fn (intern (format "emacspeak-%s-disable" extension))))
      (if (fboundp disable-fn)
          (progn
            (funcall disable-fn)
            (setq emacspeak-support--enabled
                  (delq extension emacspeak-support--enabled))
            (emacspeak-icon 'off)
            (message "Disabled emacspeak-%s support" extension))
        (message "Extension %s does not support disabling" extension)))))

(defun emacspeak-support-toggle (extension)
  "Toggle Emacspeak support for EXTENSION."
  (interactive
   (list (intern (completing-read "Toggle extension: "
                                   (mapcar #'car emacspeak-support--extensions)
                                   nil t))))
  (if (emacspeak-support--extension-enabled-p extension)
      (emacspeak-support-disable extension)
    (emacspeak-support-enable extension)))

(defun emacspeak-support-enable-all ()
  "Enable all Emacspeak support extensions."
  (interactive)
  (dolist (ext emacspeak-support--extensions)
    (emacspeak-support-enable (car ext)))
  (emacspeak-icon 'on)
  (message "Enabled all Emacspeak support extensions"))

(defun emacspeak-support-disable-all ()
  "Disable all Emacspeak support extensions."
  (interactive)
  (dolist (extension (copy-sequence emacspeak-support--enabled))
    (emacspeak-support-disable extension))
  (emacspeak-icon 'off)
  (message "Disabled all Emacspeak support extensions"))

(defun emacspeak-support-status ()
  "Display status of all Emacspeak support extensions."
  (interactive)
  (let ((status-lines
         (mapcar
          (lambda (ext)
            (let ((name (car ext))
                  (enabled (memq (car ext) emacspeak-support--enabled)))
              (format "%s: %s"
                      name
                      (if enabled "enabled" "disabled"))))
          emacspeak-support--extensions)))
    (message "Emacspeak support extensions:\n%s"
             (mapconcat #'identity status-lines "\n"))))

;;;  Convenience functions for specific extensions:

(defun emacspeak-support-enable-corfu ()
  "Enable Emacspeak support for Corfu."
  (interactive)
  (emacspeak-support-enable 'corfu))

(defun emacspeak-support-disable-corfu ()
  "Disable Emacspeak support for Corfu."
  (interactive)
  (emacspeak-support-disable 'corfu))

(defun emacspeak-support-toggle-corfu ()
  "Toggle Emacspeak support for Corfu."
  (interactive)
  (emacspeak-support-toggle 'corfu))

(defun emacspeak-support-enable-which-key ()
  "Enable Emacspeak support for Which-Key."
  (interactive)
  (emacspeak-support-enable 'which-key))

(defun emacspeak-support-disable-which-key ()
  "Disable Emacspeak support for Which-Key."
  (interactive)
  (emacspeak-support-disable 'which-key))

(defun emacspeak-support-toggle-which-key ()
  "Toggle Emacspeak support for Which-Key."
  (interactive)
  (emacspeak-support-toggle 'which-key))

(defun emacspeak-support-enable-markdown ()
  "Enable Emacspeak support for Markdown."
  (interactive)
  (emacspeak-support-enable 'markdown))

(defun emacspeak-support-disable-markdown ()
  "Disable Emacspeak support for Markdown."
  (interactive)
  (emacspeak-support-disable 'markdown))

(defun emacspeak-support-toggle-markdown ()
  "Toggle Emacspeak support for Markdown."
  (interactive)
  (emacspeak-support-toggle 'markdown))

(defun emacspeak-support-enable-vertico ()
  "Enable Emacspeak support for Vertico."
  (interactive)
  (emacspeak-support-enable 'vertico))

(defun emacspeak-support-disable-vertico ()
  "Disable Emacspeak support for Vertico."
  (interactive)
  (emacspeak-support-disable 'vertico))

(defun emacspeak-support-toggle-vertico ()
  "Toggle Emacspeak support for Vertico."
  (interactive)
  (emacspeak-support-toggle 'vertico))

(defun emacspeak-support-enable-helm ()
  "Enable Emacspeak support for Helm."
  (interactive)
  (emacspeak-support-enable 'helm))

(defun emacspeak-support-disable-helm ()
  "Disable Emacspeak support for Helm."
  (interactive)
  (emacspeak-support-disable 'helm))

(defun emacspeak-support-toggle-helm ()
  "Toggle Emacspeak support for Helm."
  (interactive)
  (emacspeak-support-toggle 'helm))

;;;  Provide the module:

(provide 'emacspeak-support)

;;; emacspeak-support.el ends here
