;;; emacspeak-windows-speech.el --- Native Windows speech integration -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bart Bunting
;; SPDX-License-Identifier: GPL-2.0-or-later

;; This file is not part of GNU Emacs, but the same permissions apply.
;; See the file COPYING in this distribution.

;;; Commentary:
;;
;; Register the native Windows speech servers distributed with
;; emacspeak-support without copying them into Emacspeak.  Friendly server
;; names shown by `dtk-select-server' are translated to absolute support-tree
;; paths immediately before the original command runs.

;;; Code:

(require 'cl-lib)
(require 'emacspeak-preamble)
(require 'dtk-speak)
(require 'emacspeak-sounds)

(defgroup emacspeak-windows-speech nil
  "Native Windows speech and auditory-icon support under WSL."
  :group 'emacspeak)

(defconst emacspeak-windows-speech--directory
  (file-name-directory (or load-file-name buffer-file-name))
  "Directory containing the Emacspeak Windows speech integration.")

(defcustom emacspeak-windows-speech-servers-directory
  (expand-file-name "servers/" emacspeak-windows-speech--directory)
  "Directory containing the native Windows speech server launchers."
  :type 'directory
  :group 'emacspeak-windows-speech)

(defcustom emacspeak-windows-speech-enable-notification-stream t
  "Whether Windows speech servers use a separate notification stream.
The notification stream uses a second server and native bridge process, so
notifications can speak independently of the main speech stream.  Changes
take effect the next time the speech server is selected or restarted."
  :type 'boolean
  :group 'emacspeak-windows-speech)

(defcustom emacspeak-windows-speech-main-pan 0.0
  "Stereo position of the main Windows speech stream.
-1.0 is fully left, 0.0 is centered, and 1.0 is fully right.  Values
outside that range are clamped when the speech process starts.  Changes
take effect the next time the speech server is selected or restarted."
  :type 'number
  :group 'emacspeak-windows-speech)

(defcustom emacspeak-windows-speech-notification-pan 0.65
  "Stereo position of the Windows notification speech stream.
-1.0 is fully left, 0.0 is centered, and 1.0 is fully right.  Values
outside that range are clamped when the notification process starts.
Changes take effect when the speech server is selected or restarted."
  :type 'number
  :group 'emacspeak-windows-speech)

(defconst emacspeak-windows-speech--server-files
  '(("windows-outloud" . "windows-outloud")
    ("windows-dtk" . "windows-dtk"))
  "Friendly speech server names and their launcher file names.")

(defvar emacspeak-windows-speech--enabled nil
  "Non-nil when friendly Windows server translation is enabled.")

(defvar emacspeak-windows-speech--added-server-names nil
  "Server names added to `dtk-servers-alist' by this integration.")

(defvar emacspeak-windows-speech--saved-audio-state nil
  "Audio configuration saved before enabling native Windows playback.")

(defconst emacspeak-windows-speech--notification-device "windows-default"
  "Internal device name that enables Emacspeak's notification process.")

(defconst emacspeak-windows-speech--pan-environment-variable
  "EMACSPEAK_WINDOWS_SPEECH_PAN"
  "Environment variable passed to a native Windows speech bridge.")

(defun emacspeak-windows-speech--server-path (name)
  "Return the absolute support server path for friendly NAME."
  (let ((entry
         (assoc-string
          name emacspeak-windows-speech--server-files)))
    (when entry
      (expand-file-name
       (cdr entry) emacspeak-windows-speech-servers-directory))))

(defun emacspeak-windows-speech--resolve-server-arguments (arguments)
  "Translate a friendly server name in ARGUMENTS to its absolute path."
  (let* ((name (car arguments))
         (path
          (and (stringp name)
               (emacspeak-windows-speech--server-path name))))
    (if path
        (progn
          (unless (file-executable-p path)
            (user-error "Windows speech server is not executable: %s" path))
          (cons path (cdr arguments)))
      arguments)))

(defun emacspeak-windows-speech--server-p (program)
  "Return non-nil when PROGRAM names one of the Windows speech servers."
  (and
   (stringp program)
   (member
    (file-name-nondirectory program)
    (mapcar #'cdr emacspeak-windows-speech--server-files))))

(defun emacspeak-windows-speech--with-notification-stream
    (original &rest arguments)
  "Call ORIGINAL with Windows notification-stream support enabled.
ARGUMENTS are the original arguments to `dtk-initialize'."
  (cl-declare
   (special dtk-program tts-multi-engines tts-notification-device))
  (if
      (not
       (and emacspeak-windows-speech-enable-notification-stream
            (emacspeak-windows-speech--server-p dtk-program)))
      (apply original arguments)
    (let
        ((tts-multi-engines
          (append
           '("windows-outloud" "windows-dtk") tts-multi-engines))
         (tts-notification-device
          (if
              (and
               (stringp tts-notification-device)
               (> (length tts-notification-device) 0)
               (not (string= tts-notification-device "default")))
              tts-notification-device
            emacspeak-windows-speech--notification-device)))
      (apply original arguments))))

(defun emacspeak-windows-speech--clamp-pan (pan)
  "Return numeric PAN constrained to the inclusive range -1.0 to 1.0."
  (setq pan (if (numberp pan) (float pan) 0.0))
  (max -1.0 (min 1.0 pan)))

(defun emacspeak-windows-speech--with-stereo-position
    (original name &rest arguments)
  "Call ORIGINAL to start speech process NAME at its stereo position.
ARGUMENTS are any remaining arguments to `dtk-make-process'."
  (cl-declare (special dtk-program process-environment))
  (if (not (emacspeak-windows-speech--server-p dtk-program))
      (apply original name arguments)
    (let ((process-environment (copy-sequence process-environment))
          (pan
           (if (string= name "Notify")
               emacspeak-windows-speech-notification-pan
             emacspeak-windows-speech-main-pan)))
      (setenv
       emacspeak-windows-speech--pan-environment-variable
       (number-to-string (emacspeak-windows-speech--clamp-pan pan)))
      (apply original name arguments))))

(defun emacspeak-windows-speech--register-server-names ()
  "Add friendly Windows server names to Emacspeak completion."
  (cl-declare (special dtk-servers-alist))
  (unless dtk-servers-alist
    (tts-setup-servers-alist))
  (dolist (entry emacspeak-windows-speech--server-files)
    (let ((name (car entry)))
      (unless (member name dtk-servers-alist)
        (setq dtk-servers-alist
              (append dtk-servers-alist (list name)))
        (push name emacspeak-windows-speech--added-server-names)))))

(defun emacspeak-windows-speech-enable ()
  "Enable friendly selection of native Windows speech servers."
  (interactive)
  (unless emacspeak-windows-speech--enabled
    (setq emacspeak-windows-speech--added-server-names nil)
    (emacspeak-windows-speech--register-server-names))
  (unless
      (advice-member-p
       #'emacspeak-windows-speech--resolve-server-arguments
       'dtk-select-server)
    (advice-add
     'dtk-select-server :filter-args
     #'emacspeak-windows-speech--resolve-server-arguments))
  (unless
      (advice-member-p
       #'emacspeak-windows-speech--with-notification-stream
       'dtk-initialize)
    (advice-add
     'dtk-initialize :around
     #'emacspeak-windows-speech--with-notification-stream))
  (unless
      (advice-member-p
       #'emacspeak-windows-speech--with-stereo-position
       'dtk-make-process)
    (advice-add
     'dtk-make-process :around
     #'emacspeak-windows-speech--with-stereo-position))
  (setq emacspeak-windows-speech--enabled t)
  (when (called-interactively-p 'interactive)
    (emacspeak-icon 'on)
    (message "Enabled native Windows speech server selection")))

(defun emacspeak-windows-speech-disable ()
  "Disable friendly selection of native Windows speech servers."
  (interactive)
  (cl-declare (special dtk-servers-alist))
  (when
      (advice-member-p
       #'emacspeak-windows-speech--resolve-server-arguments
       'dtk-select-server)
    (advice-remove
     'dtk-select-server
     #'emacspeak-windows-speech--resolve-server-arguments))
  (when
      (advice-member-p
       #'emacspeak-windows-speech--with-notification-stream
       'dtk-initialize)
    (advice-remove
     'dtk-initialize
     #'emacspeak-windows-speech--with-notification-stream))
  (when
      (advice-member-p
       #'emacspeak-windows-speech--with-stereo-position
       'dtk-make-process)
    (advice-remove
     'dtk-make-process
     #'emacspeak-windows-speech--with-stereo-position))
  (dolist (name emacspeak-windows-speech--added-server-names)
    (setq dtk-servers-alist (delete name dtk-servers-alist)))
  (setq emacspeak-windows-speech--added-server-names nil
        emacspeak-windows-speech--enabled nil)
  (when (called-interactively-p 'interactive)
    (emacspeak-icon 'off)
    (message "Disabled native Windows speech server selection")))

(defun emacspeak-windows-speech-select-server (server)
  "Select friendly Windows speech SERVER and restart speech."
  (interactive
   (list
    (completing-read
     "Windows speech server:"
     (mapcar #'car emacspeak-windows-speech--server-files)
     nil t)))
  (emacspeak-windows-speech-enable)
  (dtk-select-server server))

(defun emacspeak-windows-speech-select-eloquence ()
  "Select the native Windows Eloquence server."
  (interactive)
  (emacspeak-windows-speech-select-server "windows-outloud"))

(defun emacspeak-windows-speech-select-dectalk ()
  "Select the native Windows DECtalk server."
  (interactive)
  (emacspeak-windows-speech-select-server "windows-dtk"))

(defun emacspeak-windows-speech--audio-player ()
  "Return the absolute native Windows auditory-icon player path."
  (expand-file-name
   "windows-play" emacspeak-windows-speech-servers-directory))

(defun emacspeak-windows-speech-configure-audio (&optional restart)
  "Configure native Windows auditory-icon playback.
With prefix argument RESTART, restart the active speech server afterward."
  (interactive "P")
  (cl-declare (special emacspeak-play-program ems--play-args sox-play))
  (let ((player (emacspeak-windows-speech--audio-player)))
    (unless (file-executable-p player)
      (user-error "Windows auditory-icon player is not executable: %s" player))
    (unless emacspeak-windows-speech--saved-audio-state
      (setq emacspeak-windows-speech--saved-audio-state
            (list
             :emacspeak-play (getenv "EMACSPEAK_PLAY")
             :emacspeak-play-program emacspeak-play-program
             :play-arguments ems--play-args
             :sox-play sox-play)))
    (setenv "EMACSPEAK_PLAY" player)
    (set 'emacspeak-play-program nil)
    (set 'ems--play-args nil)
    (set 'sox-play player)
    (when restart (tts-restart))
    (when (called-interactively-p 'interactive)
      (emacspeak-icon 'on)
      (message
       "Configured native Windows audio%s"
       (if restart " and restarted speech" "")))
    player))

(defun emacspeak-windows-speech-restore-audio (&optional restart)
  "Restore audio settings saved before native Windows configuration.
With prefix argument RESTART, restart the active speech server afterward."
  (interactive "P")
  (cl-declare (special emacspeak-play-program ems--play-args sox-play))
  (unless emacspeak-windows-speech--saved-audio-state
    (user-error "No previous audio configuration has been saved"))
  (let ((state emacspeak-windows-speech--saved-audio-state))
    (setenv "EMACSPEAK_PLAY" (plist-get state :emacspeak-play))
    (set 'emacspeak-play-program
         (plist-get state :emacspeak-play-program))
    (set 'ems--play-args (plist-get state :play-arguments))
    (set 'sox-play (plist-get state :sox-play))
    (setq emacspeak-windows-speech--saved-audio-state nil))
  (when restart (tts-restart))
  (when (called-interactively-p 'interactive)
    (emacspeak-icon 'off)
    (message
     "Restored previous audio configuration%s"
     (if restart " and restarted speech" ""))))

(defun emacspeak-windows-speech--tclx-available-p ()
  "Return non-nil when Tcl can load the Tclx package."
  (let ((tclsh (executable-find "tclsh")))
    (and
     tclsh
     (with-temp-buffer
       (insert "if {[catch {package require Tclx}]} {exit 1}\n")
       (eq
        0
        (call-process-region
         (point-min) (point-max) tclsh nil nil nil))))))

(defun emacspeak-windows-speech--diagnostic-checks ()
  "Return native Windows speech diagnostic checks."
  (let* ((directory emacspeak-windows-speech-servers-directory)
         (emacspeak-root
          (or
           (getenv "EMACSPEAK_DIR")
           (and (boundp 'emacspeak-directory) emacspeak-directory)))
         (tts-library
          (and emacspeak-root
               (expand-file-name "servers/tts-lib.tcl" emacspeak-root))))
    (list
     (list "WSL"
           (or (getenv "WSL_DISTRO_NAME")
               (file-exists-p "/proc/sys/fs/binfmt_misc/WSLInterop")))
     (list "PowerShell" (executable-find "powershell.exe"))
     (list "wslpath" (executable-find "wslpath"))
     (list "SoX" (executable-find "sox"))
     (list "Tclx" (emacspeak-windows-speech--tclx-available-p))
     (list "Emacspeak tts-lib.tcl"
           (and tts-library (file-readable-p tts-library)))
     (list "Windows audio bridge"
           (file-executable-p
            (expand-file-name "windows-audio/bin/WindowsPlay.exe" directory)))
     (list "Windows Eloquence bridge"
           (file-executable-p
            (expand-file-name
             "windows-eloquence/bin/EloquenceBridge.exe" directory)))
     (list "Windows DECtalk bridge"
           (file-executable-p
            (expand-file-name
             "windows-dectalk/bin/DectalkBridge.exe" directory)))
     (list "DECtalk runtime"
           (file-readable-p
            (expand-file-name
             "windows-dectalk/runtime/DECtalk.dll" directory))))))

(defun emacspeak-windows-speech-diagnose ()
  "Display native Windows speech dependency and build status."
  (interactive)
  (let* ((checks (emacspeak-windows-speech--diagnostic-checks))
         (failed (cl-count-if-not #'cadr checks))
         (buffer (get-buffer-create "*Emacspeak Windows Speech Diagnostics*")))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert "Emacspeak Windows speech diagnostics\n\n")
        (dolist (check checks)
          (insert
           (format "[%s] %s\n"
                   (if (cadr check) "OK" "MISSING")
                   (car check))))
        (special-mode)))
    (display-buffer buffer)
    (emacspeak-icon (if (zerop failed) 'task-done 'warn-user))
    (message
     "Windows speech diagnostics: %d passed, %d missing"
     (- (length checks) failed) failed)
    checks))

;; Loading this file is intentionally enough to make the two friendly names
;; available.  It does not switch the active speech server or audio player.
(emacspeak-windows-speech-enable)

(provide 'emacspeak-windows-speech)

;;; emacspeak-windows-speech.el ends here
