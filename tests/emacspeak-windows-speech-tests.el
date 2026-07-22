;;; emacspeak-windows-speech-tests.el --- Windows speech tests -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Deterministic tests for native Windows speech-server integration.

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'emacspeak-windows-speech)

(ert-deftest emacspeak-windows-speech-recognizes-both-servers ()
  "Friendly and absolute Windows server names should be recognized."
  (dolist
      (program
       '("windows-outloud"
         "windows-dtk"
         "/tmp/support/servers/windows-outloud"
         "/tmp/support/servers/windows-dtk"))
    (should (emacspeak-windows-speech--server-p program)))
  (should-not (emacspeak-windows-speech--server-p "outloud"))
  (should-not (emacspeak-windows-speech--server-p nil)))

(ert-deftest emacspeak-windows-speech-enables-notifications-for-both-servers ()
  "Both Windows servers should satisfy Emacspeak's multistream contract."
  (dolist
      (dtk-program
       '("/tmp/support/servers/windows-outloud"
         "/tmp/support/servers/windows-dtk"))
    (let ((emacspeak-windows-speech-enable-notification-stream t)
          (tts-multi-engines '("outloud" "dtk-soft"))
          (tts-notification-device nil))
      (should
       (equal
        '("windows-default" t)
        (emacspeak-windows-speech--with-notification-stream
         (lambda (&rest _)
           (list
            tts-notification-device
            (and (tts-multistream-p dtk-program) t)))))))))

(ert-deftest emacspeak-windows-speech-initializes-both-notification-processes ()
  "Advised `dtk-initialize' should initialize both Windows notify streams."
  (dolist
      (dtk-program
       '("/tmp/support/servers/windows-outloud"
         "/tmp/support/servers/windows-dtk"))
    (let ((dtk-speaker-process nil)
          (emacspeak-windows-speech-enable-notification-stream t)
          (tts-multi-engines '("outloud" "dtk-soft"))
          (tts-notification-device nil)
          notification-devices)
      (cl-letf
          (((symbol-function 'dtk-make-process)
            (lambda (&rest _) 'test-speaker))
           ((symbol-function 'dtk-notify-initialize)
            (lambda ()
              (push tts-notification-device notification-devices)))
           ((symbol-function 'voice-setup) #'ignore))
        (dtk-initialize))
      (should (equal '("windows-default") notification-devices)))))

(ert-deftest emacspeak-windows-speech-preserves-named-notification-device ()
  "A user-specified notification device should remain dynamically visible."
  (let ((dtk-program "/tmp/support/servers/windows-dtk")
        (emacspeak-windows-speech-enable-notification-stream t)
        (tts-multi-engines '("outloud" "dtk-soft"))
        (tts-notification-device "named-device"))
    (should
     (equal
      "named-device"
      (emacspeak-windows-speech--with-notification-stream
      (lambda (&rest _) tts-notification-device))))))

(ert-deftest emacspeak-windows-speech-positions-main-and-notify-processes ()
  "Main and notification processes should receive independent pan values."
  (let ((dtk-program "/tmp/support/servers/windows-dtk")
        (emacspeak-windows-speech-main-pan 0.0)
        (emacspeak-windows-speech-notification-pan 0.65)
        (process-environment (copy-sequence process-environment)))
    (setenv emacspeak-windows-speech--pan-environment-variable nil)
    (dolist (entry '(("Speaker" . 0.0) ("Notify" . 0.65)))
      (let
          ((actual
            (emacspeak-windows-speech--with-stereo-position
             (lambda (&rest _)
               (string-to-number
                (getenv
                 emacspeak-windows-speech--pan-environment-variable)))
             (car entry))))
        (should (= (cdr entry) actual))))))

(ert-deftest emacspeak-windows-speech-clamps-process-pan ()
  "Out-of-range custom pan values should be safely clamped."
  (let ((dtk-program "/tmp/support/servers/windows-outloud")
        (emacspeak-windows-speech-main-pan -4.0)
        (emacspeak-windows-speech-notification-pan 3.0)
        (process-environment (copy-sequence process-environment)))
    (dolist (entry '(("Speaker" . -1.0) ("Notify" . 1.0)))
      (should
       (=
        (cdr entry)
        (emacspeak-windows-speech--with-stereo-position
         (lambda (&rest _)
           (string-to-number
            (getenv emacspeak-windows-speech--pan-environment-variable)))
         (car entry)))))))

(ert-deftest emacspeak-windows-speech-exports-pan-across-wsl-boundary ()
  "The Tcl launcher should export pan from WSL to its Windows child."
  (let
      ((common
        (expand-file-name
         "servers/windows-speech-common.tcl"
         emacspeak-windows-speech--directory))
       (process-environment (copy-sequence process-environment)))
    (setenv "WSLENV" "KEEP_ME/w:EMACSPEAK_WINDOWS_SPEECH_PAN/u")
    (with-temp-buffer
      (insert
       (format
        (concat
         "source {%s}\n"
         "windows_speech_export_to_windows "
         "EMACSPEAK_WINDOWS_SPEECH_PAN\n"
         "puts $env(WSLENV)\n")
        common))
      (should
       (zerop
        (call-process-region
         (point-min) (point-max) "tclsh" t t nil)))
      (should
       (equal
        "KEEP_ME/w:EMACSPEAK_WINDOWS_SPEECH_PAN/w\n"
        (buffer-string))))))

(ert-deftest emacspeak-windows-speech-leaves-other-servers-unchanged ()
  "Notification setup should not alter non-Windows speech servers."
  (let ((dtk-program "/tmp/emacspeak/servers/espeak")
        (emacspeak-windows-speech-enable-notification-stream t)
        (tts-multi-engines '("outloud" "dtk-soft"))
        (tts-notification-device nil))
    (should
     (equal
      '(nil ("outloud" "dtk-soft"))
      (emacspeak-windows-speech--with-notification-stream
       (lambda (&rest _)
         (list tts-notification-device tts-multi-engines)))))))

(provide 'emacspeak-windows-speech-tests)

;;; emacspeak-windows-speech-tests.el ends here
