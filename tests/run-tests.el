;;; run-tests.el --- Batch runner for emacspeak-support tests -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Run from the repository root with:
;;
;;   emacs --batch -Q -l tests/run-tests.el
;;
;; EMACSPEAK_DIR and AGENT_SHELL_DIR can override the default sibling
;; worktree locations.

;;; Code:

(require 'package)
(package-initialize)

(defconst emacspeak-support-test--repository-directory
  (expand-file-name "../" (file-name-directory load-file-name)))

(defconst emacspeak-support-test--emacspeak-directory
  (file-name-as-directory
   (expand-file-name
    (or (getenv "EMACSPEAK_DIR") "~/emacs/src/emacspeak"))))

(defconst emacspeak-support-test--agent-shell-directory
  (file-name-as-directory
   (expand-file-name
    (or (getenv "AGENT_SHELL_DIR") "~/src/agent-shell"))))

(dolist (directory
         (reverse
          (list emacspeak-support-test--repository-directory
                (expand-file-name "lisp"
                                  emacspeak-support-test--emacspeak-directory)
                emacspeak-support-test--agent-shell-directory)))
  (unless (file-directory-p directory)
    (error "Required test directory does not exist: %s" directory))
  (add-to-list 'load-path directory))

(load (expand-file-name "emacspeak-agent-shell-tests.el"
                        (file-name-directory load-file-name))
      nil nil t)
(load (expand-file-name "emacspeak-windows-speech-tests.el"
                        (file-name-directory load-file-name))
      nil nil t)

(ert-run-tests-batch-and-exit)

;;; run-tests.el ends here
