;;; example-config.el --- Example Emacspeak support configuration -*- lexical-binding: t; -*-

;; Add the checkout to `load-path' after Emacspeak has been initialized.
(add-to-list 'load-path "/path/to/emacspeak-support")
(require 'emacspeak-support)

;; Enable integrations selectively after their target packages load.  Remove
;; entries for packages you do not use.
(with-eval-after-load 'corfu
  (emacspeak-support-enable-corfu))

(with-eval-after-load 'vertico
  (emacspeak-support-enable-vertico))

(with-eval-after-load 'which-key
  (emacspeak-support-enable-which-key))

(with-eval-after-load 'markdown-mode
  (emacspeak-support-enable-markdown))

(with-eval-after-load 'helm
  (emacspeak-support-enable-helm))

(with-eval-after-load 'agent-shell
  (emacspeak-support-enable-agent-shell))

;; If every target package is installed, this can replace the selective setup:
;; (emacspeak-support-enable-all)

;; Use M-x emacspeak-support-status to list enabled integrations.  Every
;; extension also has emacspeak-support-enable-, -disable-, and -toggle-
;; commands, such as M-x emacspeak-support-toggle-agent-shell.

;; Optional native Windows speech and auditory icons under WSL.  Loading this
;; file registers windows-outloud and windows-dtk with dtk-select-server, but
;; does not select an engine or change the audio route.
;; (require 'emacspeak-windows-speech)
;; (emacspeak-windows-speech-configure-audio)
;; Use M-x dtk-select-server, or one of these direct commands:
;; M-x emacspeak-windows-speech-select-eloquence
;; M-x emacspeak-windows-speech-select-dectalk
;; Run M-x emacspeak-windows-speech-diagnose to check the installation.

;;; example-config.el ends here
