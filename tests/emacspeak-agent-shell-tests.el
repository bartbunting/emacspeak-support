;;; emacspeak-agent-shell-tests.el --- Tests for agent-shell speech -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Deterministic speech tests for emacspeak-agent-shell.  Known defects are
;; encoded as expected failures so they remain visible without making the
;; baseline test command fail.

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'map)
(require 'seq)
(require 'subr-x)
(require 'emacspeak-agent-shell)

(defconst emacspeak-agent-shell-test--agent-shell-directory
  (file-name-as-directory
   (expand-file-name
    (or (getenv "AGENT_SHELL_DIR") "~/src/agent-shell")))
  "Agent-shell checkout used for compatibility fixtures.")

(defmacro emacspeak-agent-shell-test--capture-events (&rest body)
  "Run BODY and return ordered speech, stop, icon, and message events."
  (declare (indent 0) (debug t))
  `(let ((events nil))
     (cl-letf (((symbol-function 'dtk-speak)
                (lambda (text)
                  (push (list 'speak text) events)))
               ((symbol-function 'dtk-stop)
                (lambda (&optional all)
                  (push (list 'stop all) events)))
               ((symbol-function 'emacspeak-icon)
                (lambda (icon)
                  (push (list 'icon icon) events)))
               ((symbol-function 'message)
                (lambda (format-string &rest arguments)
                  (push (list 'message
                              (apply #'format-message
                                     format-string arguments))
                        events))))
       ,@body
       (nreverse events))))

(defun emacspeak-agent-shell-test--speak-pending (entries)
  "Speak pending ENTRIES and return captured events.
ENTRIES is an alist of qualified block IDs to body strings."
  (let ((buffer (generate-new-buffer " *emacspeak-agent-shell-test*")))
    (unwind-protect
        (with-current-buffer buffer
          (setq-local emacspeak-agent-shell--pending-bodies
                      (make-hash-table :test #'equal))
          (dolist (entry entries)
            (puthash (car entry) (cdr entry)
                     emacspeak-agent-shell--pending-bodies))
          (setq-local emacspeak-agent-shell--pending-speech-qualified-ids
                      (mapcar #'car entries))
          (emacspeak-agent-shell-test--capture-events
            (emacspeak-agent-shell--execute-delayed-speech
             buffer
             emacspeak-agent-shell--pending-speech-qualified-ids)))
      (when (buffer-live-p buffer)
        (kill-buffer buffer)))))

(defun emacspeak-agent-shell-test--fixture-path (filename)
  "Return the agent-shell traffic fixture path for FILENAME."
  (let ((path (expand-file-name
               (concat "tests/" filename)
               emacspeak-agent-shell-test--agent-shell-directory)))
    (unless (file-readable-p path)
      (ert-fail (format "Unreadable agent-shell fixture: %s" path)))
    path))

(defun emacspeak-agent-shell-test--read-traffic (filename)
  "Read agent-shell traffic fixture FILENAME as Lisp data."
  (with-temp-buffer
    (insert-file-contents
     (emacspeak-agent-shell-test--fixture-path filename))
    (goto-char (point-min))
    (read (current-buffer))))

(defun emacspeak-agent-shell-test--permission-requests (filename)
  "Return incoming permission requests from traffic fixture FILENAME."
  (seq-filter
   (lambda (item)
     (and (eq (map-elt item :direction) 'incoming)
          (equal (map-nested-elt item '(:object method))
                 "session/request_permission")))
   (emacspeak-agent-shell-test--read-traffic filename)))

(defun emacspeak-agent-shell-test--session-updates (filename update-type)
  "Return UPDATE-TYPE notifications from traffic fixture FILENAME."
  (seq-filter
   (lambda (item)
     (and (eq (map-elt item :direction) 'incoming)
          (equal (map-nested-elt item '(:object method)) "session/update")
          (equal (map-nested-elt
                  item '(:object params update sessionUpdate))
                 update-type)))
   (emacspeak-agent-shell-test--read-traffic filename)))

(defun emacspeak-agent-shell-test--permission-entry (request)
  "Convert fixture permission REQUEST to a pending speech entry."
  (let* ((object (map-elt request :object))
         (tool-call (map-nested-elt object '(params toolCall)))
         (tool-call-id (map-elt tool-call 'toolCallId))
         (title (map-elt tool-call 'title))
         (options (append (map-nested-elt object '(params options)) nil))
         (choices (mapcar (lambda (option)
                            (map-elt option 'name))
                          options))
         (body (string-join (cons title choices) "\n")))
    (cons (format "fixture-permission-%s" tool-call-id) body)))

(defun emacspeak-agent-shell-test--permission-events (entries)
  "Return the desired permission announcement events for ENTRIES."
  (apply #'append
         (mapcar (lambda (entry)
                   (list (list 'icon 'warn-user)
                         (list 'speak (cdr entry))))
                 entries)))

(defun emacspeak-agent-shell-test--saved-advice-state ()
  "Return active state for each configured agent-shell advice target."
  (mapcar (lambda (entry)
            (list (car entry) (cadr entry) (ad-is-active (car entry))))
          emacspeak-agent-shell--advice-list))

(defun emacspeak-agent-shell-test--restore-advice-state (states)
  "Restore legacy advice activation from STATES."
  (dolist (state states)
    (if (nth 2 state)
        (ad-enable-advice (car state) (cadr state) 'emacspeak)
      (ad-disable-advice (car state) (cadr state) 'emacspeak))
    (ad-activate (car state))))

(ert-deftest emacspeak-agent-shell-speak-content-orders-feedback ()
  "Speech and icon calls should be observable in their delivery order."
  (should
   (equal
    (emacspeak-agent-shell-test--capture-events
      (emacspeak-agent-shell--speak-content "hello" 'user-message)
      (emacspeak-agent-shell--speak-content "approve?" 'permission))
    '((icon item)
      (speak "User: hello")
      (icon warn-user)
      (speak "approve?")))))

(ert-deftest emacspeak-agent-shell-delayed-agent-message-speaks-once ()
  "A complete agent message should be delivered once."
  (should
   (equal
    (emacspeak-agent-shell-test--speak-pending
     '(("request-agent_message_chunk" . "Complete response")))
    '((speak "Complete response")))))

(ert-deftest emacspeak-agent-shell-user-message-fixture-is-semantic ()
  "A restored user-message fixture should retain its speaker identity."
  (let* ((updates
          (emacspeak-agent-shell-test--session-updates
           "user-message-chunk.traffic" "user_message_chunk"))
         (text (map-nested-elt
                (car updates) '(:object params update content text))))
    (should (= 1 (length updates)))
    (should
     (equal
      (emacspeak-agent-shell-test--speak-pending
       (list (cons "fixture-user_message_chunk" text)))
      (list (list 'icon 'item)
            (list 'speak (concat "User: " text)))))))

(ert-deftest emacspeak-agent-shell-enable-disable-manages-current-targets ()
  "Enable and disable should manage the hook and existing advice targets."
  (let ((saved-hook agent-shell-mode-hook)
        (saved-advice (emacspeak-agent-shell-test--saved-advice-state)))
    (unwind-protect
        (progn
          (emacspeak-agent-shell-enable)
          (should (memq #'emacspeak-agent-shell-speech-setup
                        agent-shell-mode-hook))
          (dolist (entry emacspeak-agent-shell--advice-list)
            (when (fboundp (car entry))
              (should (ad-is-active (car entry)))))
          (emacspeak-agent-shell-disable)
          (should-not (memq #'emacspeak-agent-shell-speech-setup
                            agent-shell-mode-hook))
          (dolist (entry emacspeak-agent-shell--advice-list)
            (should-not (ad-is-active (car entry)))))
      (setq agent-shell-mode-hook saved-hook)
      (emacspeak-agent-shell-test--restore-advice-state saved-advice))))

(ert-deftest emacspeak-agent-shell-permission-fixture-is-urgent ()
  "A fixture permission should be classified and spoken in full."
  :expected-result :failed
  (let* ((requests
          (emacspeak-agent-shell-test--permission-requests
           "gemini-permission.traffic"))
         (entries (mapcar #'emacspeak-agent-shell-test--permission-entry
                          requests)))
    (should (= 1 (length entries)))
    (should
     (equal (emacspeak-agent-shell-test--speak-pending entries)
            (emacspeak-agent-shell-test--permission-events entries)))))

(ert-deftest emacspeak-agent-shell-multiple-permission-fixture-is-complete ()
  "Each permission in a fixture should get a complete announcement."
  :expected-result :failed
  (let* ((requests
          (emacspeak-agent-shell-test--permission-requests
           "gemini-multiple-permissions.traffic"))
         (entries (mapcar #'emacspeak-agent-shell-test--permission-entry
                          requests)))
    (should (= 2 (length entries)))
    (should
     (equal (emacspeak-agent-shell-test--speak-pending entries)
            (emacspeak-agent-shell-test--permission-events entries)))))

(ert-deftest emacspeak-agent-shell-unknown-block-uses-fallback ()
  "Unknown non-empty content should reach the fallback speaker."
  :expected-result :failed
  (should
   (equal
    (emacspeak-agent-shell-test--speak-pending
     '(("request-mystery" . "Unrecognized but useful content")))
    '((speak "Unrecognized but useful content")))))

(ert-deftest emacspeak-agent-shell-advice-targets-exist ()
  "Every configured advice target should exist in current agent-shell."
  :expected-result :failed
  (should-not
   (seq-remove (lambda (entry) (fboundp (car entry)))
               emacspeak-agent-shell--advice-list)))

(ert-deftest emacspeak-agent-shell-configured-faces-exist ()
  "Every agent-shell face named by this integration should exist."
  :expected-result :failed
  (should (facep 'agent-shell-mode-line)))

(ert-deftest emacspeak-agent-shell-disable-cleans-existing-buffer-state ()
  "Disabling support should cancel pending work in existing shell buffers."
  :expected-result :failed
  (let ((buffer (generate-new-buffer " *agent-shell-cleanup-test*"))
        (saved-hook agent-shell-mode-hook)
        (saved-advice (emacspeak-agent-shell-test--saved-advice-state))
        timer)
    (unwind-protect
        (progn
          (emacspeak-agent-shell-enable)
          (with-current-buffer buffer
            (setq major-mode 'agent-shell-mode)
            (setq-local emacspeak-agent-shell--pending-bodies
                        (make-hash-table :test #'equal))
            (puthash "request-agent_message_chunk" "pending"
                     emacspeak-agent-shell--pending-bodies)
            (setq-local emacspeak-agent-shell--pending-speech-qualified-ids
                        '("request-agent_message_chunk"))
            (setq timer (run-with-timer 3600 nil #'ignore))
            (setq-local emacspeak-agent-shell--pending-speech-timer timer))
          (emacspeak-agent-shell-disable)
          (with-current-buffer buffer
            (should-not emacspeak-agent-shell--pending-speech-timer)
            (should-not emacspeak-agent-shell--pending-speech-qualified-ids)
            (should (or (null emacspeak-agent-shell--pending-bodies)
                        (= 0 (hash-table-count
                              emacspeak-agent-shell--pending-bodies))))))
      (when (timerp timer)
        (cancel-timer timer))
      (when (buffer-live-p buffer)
        (kill-buffer buffer))
      (setq agent-shell-mode-hook saved-hook)
      (emacspeak-agent-shell-test--restore-advice-state saved-advice))))

(provide 'emacspeak-agent-shell-tests)
;;; emacspeak-agent-shell-tests.el ends here
