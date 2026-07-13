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

(defvar emacspeak-agent-shell--advice-list)
(defvar emacspeak-agent-shell--lifecycle-subscription)
(defvar emacspeak-agent-shell--permission-action-cache)
(defvar emacspeak-agent-shell--permission-response-subscription)
(defvar emacspeak-agent-shell--permission-subscription)
(defvar emacspeak-agent-shell--tool-call-status-cache)
(defvar emacspeak-agent-shell--tool-call-subscription)
(defvar emacspeak-agent-shell-processing-end-icon)
(defvar emacspeak-agent-shell-processing-start-icon)
(defvar emacspeak-agent-shell-signal-processing)
(defvar emacspeak-agent-shell-speak-permissions)
(defvar emacspeak-agent-shell-speak-tool-calls)
(defvar emacspeak-agent-shell-tool-output-verbosity)

(declare-function emacspeak-agent-shell--execute-delayed-speech
                  "emacspeak-agent-shell" (buffer qualified-ids))
(declare-function emacspeak-agent-shell--handle-permission-request
                  "emacspeak-agent-shell" (event))
(declare-function emacspeak-agent-shell--handle-permission-response
                  "emacspeak-agent-shell" (event))
(declare-function emacspeak-agent-shell--handle-tool-call-update
                  "emacspeak-agent-shell" (event))
(declare-function emacspeak-agent-shell--handle-lifecycle-event
                  "emacspeak-agent-shell" (event))
(declare-function emacspeak-agent-shell--lifecycle-event-cleanup
                  "emacspeak-agent-shell" ())
(declare-function emacspeak-agent-shell--lifecycle-event-setup
                  "emacspeak-agent-shell" ())
(declare-function emacspeak-agent-shell--permission-button-feedback
                  "emacspeak-agent-shell" ())
(declare-function emacspeak-agent-shell--permission-event-cleanup
                  "emacspeak-agent-shell" ())
(declare-function emacspeak-agent-shell--permission-event-setup
                  "emacspeak-agent-shell" ())
(declare-function emacspeak-agent-shell--speak-content
                  "emacspeak-agent-shell" (content block-type))
(declare-function emacspeak-agent-shell--tool-call-block-handled-p
                  "emacspeak-agent-shell" (block-id))
(declare-function emacspeak-agent-shell--tool-call-event-cleanup
                  "emacspeak-agent-shell" ())
(declare-function emacspeak-agent-shell--tool-call-event-setup
                  "emacspeak-agent-shell" ())
(declare-function emacspeak-agent-shell-disable "emacspeak-agent-shell" ())
(declare-function emacspeak-agent-shell-enable "emacspeak-agent-shell" ())
(declare-function emacspeak-agent-shell-speech-setup
                  "emacspeak-agent-shell" ())

(declare-function agent-shell--make-permission-button
                  "agent-shell" (&rest arguments))
(declare-function agent-shell--save-tool-call
                  "agent-shell" (state tool-call-id tool-call))

(defconst emacspeak-agent-shell-test--agent-shell-directory
  (file-name-as-directory
   (expand-file-name
    (or (getenv "AGENT_SHELL_DIR") "~/src/agent-shell")))
  "Agent-shell checkout used for compatibility fixtures.")

(defmacro emacspeak-agent-shell-test--capture-events (&rest body)
  "Run BODY and return ordered speech, stop, icon, and message events."
  (declare (indent 0) (debug t))
  (let ((event-log (make-symbol "event-log")))
    `(let ((,event-log nil))
       (cl-letf (((symbol-function 'dtk-speak)
                  (lambda (text)
                    (push (list 'speak text) ,event-log)))
                 ((symbol-function 'dtk-stop)
                  (lambda (&optional all)
                    (push (list 'stop all) ,event-log)))
                 ((symbol-function 'emacspeak-icon)
                  (lambda (icon)
                    (push (list 'icon icon) ,event-log)))
                 ((symbol-function 'message)
                  (lambda (format-string &rest arguments)
                    (push (list 'message
                                (apply #'format-message
                                       format-string arguments))
                          ,event-log))))
         ,@body
         (nreverse ,event-log)))))

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

(defun emacspeak-agent-shell-test--normalized-tool-call (raw-tool-call)
  "Normalize RAW-TOOL-CALL into the public event representation."
  (list (cons :title (map-elt raw-tool-call 'title))
        (cons :status (map-elt raw-tool-call 'status))
        (cons :kind (map-elt raw-tool-call 'kind))
        (cons :description
              (map-nested-elt raw-tool-call '(rawInput description)))
        (cons :command (map-nested-elt raw-tool-call '(rawInput command)))
        (cons :content (map-elt raw-tool-call 'content))))

(defun emacspeak-agent-shell-test--tool-call-events (filename)
  "Replay public tool-call events from upstream traffic FILENAME."
  (let ((state '((:tool-calls . nil)))
        events)
    (dolist (item (emacspeak-agent-shell-test--read-traffic filename))
      (let* ((object (map-elt item :object))
             (method (map-elt object 'method))
             (update (map-nested-elt object '(params update)))
             (update-kind (map-elt update 'sessionUpdate))
             (raw-tool-call
              (cond
               ((equal method "session/request_permission")
                (map-nested-elt object '(params toolCall)))
               ((and (equal method "session/update")
                     (member update-kind
                             '("tool_call" "tool_call_update")))
                update)))
             (tool-call-id (map-elt raw-tool-call 'toolCallId)))
        (when tool-call-id
          (agent-shell--save-tool-call
           state tool-call-id
           (emacspeak-agent-shell-test--normalized-tool-call raw-tool-call))
          (when (member update-kind '("tool_call" "tool_call_update"))
            (push
             (list
              (cons :event 'tool-call-update)
              (cons :data
                    (list
                     (cons :tool-call-id tool-call-id)
                     (cons :tool-call
                           (copy-tree
                            (map-nested-elt
                             state (list :tool-calls tool-call-id)))))))
             events)))))
    (nreverse events)))

(defun emacspeak-agent-shell-test--tool-call-event
    (tool-call-id status title &optional content kind)
  "Make a public tool event with TOOL-CALL-ID, STATUS, TITLE, CONTENT, and KIND."
  (list
   (cons :event 'tool-call-update)
   (cons :data
         (list
          (cons :tool-call-id tool-call-id)
          (cons :tool-call
                (list (cons :status status)
                      (cons :title title)
                      (cons :content content)
                      (cons :kind kind)))))))

(defun emacspeak-agent-shell-test--permission-event (request)
  "Convert fixture permission REQUEST to a public agent-shell event."
  (let* ((object (map-elt request :object))
         (tool-call (map-nested-elt object '(params toolCall)))
         (tool-call-id (map-elt tool-call 'toolCallId))
         (title (map-elt tool-call 'title))
         (options (append (map-nested-elt object '(params options)) nil))
         (actions (agent-shell--make-permission-actions options)))
    (list
     (cons :event 'permission-request)
     (cons :data
           (list (cons :request-id (map-elt object 'id))
                 (cons :tool-call-id tool-call-id)
                 (cons :tool-call
                       (list (cons :title title)
                             (cons :permission-actions actions))))))))

(defun emacspeak-agent-shell-test--expected-permission-events (events)
  "Return the desired speech events for permission EVENTS."
  (apply #'append
         (mapcar
          (lambda (event)
            (let* ((tool-call (map-nested-elt event '(:data :tool-call)))
                   (title (map-elt tool-call :title))
                   (actions (map-elt tool-call :permission-actions))
                   (choices
                    (cl-loop
                     for action in actions
                     for index from 1
                     collect (format "Choice %d: %s."
                                     index (map-elt action :option)))))
              (list (list 'stop nil)
                    (list 'icon 'warn-user)
                    (list 'speak
                          (string-join
                           (append (list (format "Permission request. %s."
                                                      title))
                                   choices)
                           " ")))))
          events)))

(defun emacspeak-agent-shell-test--permission-response-event
    (request-event &optional kind cancelled)
  "Make a response for REQUEST-EVENT selecting KIND or CANCELLED."
  (let* ((data (map-elt request-event :data))
         (actions (map-nested-elt request-event
                                  '(:data :tool-call :permission-actions)))
         (action (and kind
                      (seq-find
                       (lambda (candidate)
                         (equal (map-elt candidate :kind) kind))
                       actions))))
    (list
     (cons :event 'permission-response)
     (cons :data
           (list (cons :request-id (map-elt data :request-id))
                 (cons :tool-call-id (map-elt data :tool-call-id))
                 (cons :option-id (map-elt action :option-id))
                 (cons :cancelled cancelled))))))

(defun emacspeak-agent-shell-test--insert-permission-buttons ()
  "Insert three navigatable permission buttons for focus tests."
  (insert
   (mapconcat
    #'identity
    (list
     (agent-shell--make-permission-button
      :text "Allow (y)" :help "Allow (y)" :action #'ignore
      :navigatable t :char "y" :option "Allow")
     (agent-shell--make-permission-button
      :text "Reject (n)" :help "Reject (n)" :action #'ignore
      :navigatable t :char "n" :option "Reject")
     (agent-shell--make-permission-button
      :text "Always Allow (!)" :help "Always Allow (!)" :action #'ignore
      :navigatable t :char "!" :option "Always Allow"))
    " ")))

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
          (should (memq #'emacspeak-agent-shell--permission-event-setup
                        agent-shell-mode-hook))
          (should (memq #'emacspeak-agent-shell--lifecycle-event-setup
                        agent-shell-mode-hook))
          (should (memq #'emacspeak-agent-shell--tool-call-event-setup
                        agent-shell-mode-hook))
          (dolist (entry emacspeak-agent-shell--advice-list)
            (when (fboundp (car entry))
              (should (ad-is-active (car entry)))))
          (emacspeak-agent-shell-disable)
          (should-not (memq #'emacspeak-agent-shell-speech-setup
                            agent-shell-mode-hook))
          (should-not (memq #'emacspeak-agent-shell--permission-event-setup
                            agent-shell-mode-hook))
          (should-not (memq #'emacspeak-agent-shell--lifecycle-event-setup
                            agent-shell-mode-hook))
          (should-not (memq #'emacspeak-agent-shell--tool-call-event-setup
                            agent-shell-mode-hook))
          (dolist (entry emacspeak-agent-shell--advice-list)
            (should-not (ad-is-active (car entry)))))
      (setq agent-shell-mode-hook saved-hook)
      (emacspeak-agent-shell-test--restore-advice-state saved-advice))))

(ert-deftest emacspeak-agent-shell-permission-fixture-is-urgent ()
  "A fixture permission should interrupt and be spoken in full."
  (let* ((requests
          (emacspeak-agent-shell-test--permission-requests
           "gemini-permission.traffic"))
         (events (mapcar #'emacspeak-agent-shell-test--permission-event
                         requests)))
    (should (= 1 (length events)))
    (should
     (equal
      (emacspeak-agent-shell-test--capture-events
        (dolist (event events)
          (emacspeak-agent-shell--handle-permission-request event)))
      (emacspeak-agent-shell-test--expected-permission-events events)))))

(ert-deftest emacspeak-agent-shell-multiple-permission-fixture-is-complete ()
  "Each permission in a fixture should get a complete announcement."
  (let* ((requests
          (emacspeak-agent-shell-test--permission-requests
           "gemini-multiple-permissions.traffic"))
         (events (mapcar #'emacspeak-agent-shell-test--permission-event
                         requests)))
    (should (= 2 (length events)))
    (should
     (equal
      (emacspeak-agent-shell-test--capture-events
        (dolist (event events)
          (emacspeak-agent-shell--handle-permission-request event)))
      (emacspeak-agent-shell-test--expected-permission-events events)))))

(ert-deftest emacspeak-agent-shell-permission-subscription-is-idempotent ()
  "The public permission subscription should install once and clean up."
  (let ((buffer (generate-new-buffer " *agent-shell-permission-test*"))
        timer)
    (unwind-protect
        (with-current-buffer buffer
          (setq major-mode 'agent-shell-mode)
          (setq-local agent-shell--state
                      (list (cons :buffer buffer)
                            (cons :event-subscriptions nil)))
          (let* ((request
                  (car (emacspeak-agent-shell-test--permission-requests
                        "gemini-permission.traffic")))
                 (event
                  (emacspeak-agent-shell-test--permission-event request))
                 (data (map-elt event :data)))
            (emacspeak-agent-shell--permission-event-setup)
            (let ((token emacspeak-agent-shell--permission-subscription))
              (emacspeak-agent-shell--permission-event-setup)
              (should (equal token
                             emacspeak-agent-shell--permission-subscription))
              (should (= 2 (length (map-elt
                                    agent-shell--state
                                    :event-subscriptions)))))
            (setq timer (run-with-timer 3600 nil #'ignore))
            (setq-local emacspeak-agent-shell--pending-speech-timer timer
                        emacspeak-agent-shell--pending-speech-qualified-ids
                        '("fixture-permission"))
            (setq-local emacspeak-agent-shell--pending-bodies
                        (make-hash-table :test #'equal))
            (puthash "fixture-permission" "duplicate"
                     emacspeak-agent-shell--pending-bodies)
            (should
             (equal
              (emacspeak-agent-shell-test--capture-events
                (cl-letf (((symbol-function
                            'agent-shell--sync-system-sleep)
                           #'ignore))
                  (agent-shell--emit-event
                   :event 'permission-request :data data)))
              (emacspeak-agent-shell-test--expected-permission-events
               (list event))))
            (should-not emacspeak-agent-shell--pending-speech-timer)
            (should-not emacspeak-agent-shell--pending-speech-qualified-ids)
            (should (= 0 (hash-table-count
                          emacspeak-agent-shell--pending-bodies)))
            (should (= 1 (hash-table-count
                          emacspeak-agent-shell--permission-action-cache)))
            (emacspeak-agent-shell--permission-event-cleanup)
            (should-not emacspeak-agent-shell--permission-subscription)
            (should-not
             emacspeak-agent-shell--permission-response-subscription)
            (should-not emacspeak-agent-shell--permission-action-cache)
            (should-not (map-elt agent-shell--state
                                 :event-subscriptions))))
      (when (timerp timer)
        (cancel-timer timer))
      (when (buffer-live-p buffer)
        (kill-buffer buffer)))))

(ert-deftest emacspeak-agent-shell-permission-announcement-can-be-disabled ()
  "Disabling permission speech should also suppress the delayed duplicate."
  (let ((emacspeak-agent-shell-speak-permissions nil))
    (with-temp-buffer
      (setq-local emacspeak-agent-shell--pending-bodies
                  (make-hash-table :test #'equal))
      (puthash "fixture-permission" "duplicate"
               emacspeak-agent-shell--pending-bodies)
      (setq-local emacspeak-agent-shell--pending-speech-qualified-ids
                  '("fixture-permission"))
      (should-not
       (emacspeak-agent-shell-test--capture-events
         (emacspeak-agent-shell--handle-permission-request
          '((:event . permission-request)
            (:data (:tool-call-id . "tool-id")
                   (:tool-call (:title . "Run command")
                               (:permission-actions
                                ((:option . "Allow")))))))))
      (should-not emacspeak-agent-shell--pending-speech-qualified-ids)
      (should (= 0 (hash-table-count
                    emacspeak-agent-shell--pending-bodies))))))

(ert-deftest emacspeak-agent-shell-permission-responses-are-semantic ()
  "Allow, reject, and cancel responses should identify their outcomes."
  (with-temp-buffer
    (let* ((requests
            (emacspeak-agent-shell-test--permission-requests
             "gemini-multiple-permissions.traffic"))
           (events (mapcar #'emacspeak-agent-shell-test--permission-event
                           requests))
           (first (nth 0 events))
           (second (nth 1 events)))
      (ignore
       (emacspeak-agent-shell-test--capture-events
         (dolist (event events)
           (emacspeak-agent-shell--handle-permission-request event))))
      (should (= 2 (hash-table-count
                    emacspeak-agent-shell--permission-action-cache)))
      (should
       (equal
        (emacspeak-agent-shell-test--capture-events
          (emacspeak-agent-shell--handle-permission-response
           (emacspeak-agent-shell-test--permission-response-event
            first "allow_always")))
        '((icon select-object)
          (speak "Permission granted: Always Allow git, head."))))
      (should (= 1 (hash-table-count
                    emacspeak-agent-shell--permission-action-cache)))
      (should
       (equal
        (emacspeak-agent-shell-test--capture-events
          (emacspeak-agent-shell--handle-permission-response
           (emacspeak-agent-shell-test--permission-response-event
            second "reject_once")))
        '((icon close-object)
          (speak "Permission denied: Reject."))))
      (should (= 0 (hash-table-count
                    emacspeak-agent-shell--permission-action-cache)))
      (ignore
       (emacspeak-agent-shell-test--capture-events
         (emacspeak-agent-shell--handle-permission-request first)))
      (should
       (equal
        (emacspeak-agent-shell-test--capture-events
          (emacspeak-agent-shell--handle-permission-response
           (emacspeak-agent-shell-test--permission-response-event
            first nil t)))
        '((icon close-object)
          (speak "Permission cancelled.")))))))

(ert-deftest emacspeak-agent-shell-lifecycle-transitions-are-semantic ()
  "Public lifecycle events should distinguish processing transitions."
  (let ((emacspeak-agent-shell-signal-processing t)
        (emacspeak-agent-shell-processing-start-icon 'progress)
        (emacspeak-agent-shell-processing-end-icon 'task-done))
    (should
     (equal
      (emacspeak-agent-shell-test--capture-events
        (dolist (event '(((:event . init-started))
                         ((:event . init-finished))
                         ((:event . input-submitted))
                         ((:event . turn-complete)
                          (:data (:stop-reason . "end_turn")))))
          (emacspeak-agent-shell--handle-lifecycle-event event)))
      '((icon progress)
        (icon task-done)
        (icon progress)
        (icon task-done))))))

(ert-deftest emacspeak-agent-shell-exceptional-lifecycle-is-spoken ()
  "Exceptional turn completions and ACP errors should be unambiguous."
  (let ((emacspeak-agent-shell-signal-processing t))
    (should
     (equal
      (emacspeak-agent-shell-test--capture-events
        (dolist (event '(((:event . turn-complete)
                          (:data (:stop-reason . "cancelled")))
                         ((:event . turn-complete)
                          (:data (:stop-reason . "max_tokens")))
                         ((:event . turn-complete)
                          (:data (:stop-reason . "max_turn_requests")))
                         ((:event . turn-complete)
                          (:data (:stop-reason . "refusal")))
                         ((:event . turn-complete)
                          (:data (:stop-reason . "agent_shutdown")))
                         ((:event . turn-complete))
                         ((:event . error)
                          (:data (:code . 500)
                                 (:message . "Connection lost.")))))
          (emacspeak-agent-shell--handle-lifecycle-event event)))
      '((icon close-object)
        (speak "Agent turn cancelled.")
        (icon warn-user)
        (speak "Agent stopped: maximum token limit reached.")
        (icon warn-user)
        (speak "Agent stopped: request limit reached.")
        (icon warn-user)
        (speak "Agent refused the request.")
        (icon warn-user)
        (speak "Agent stopped: agent shutdown.")
        (icon warn-user)
        (speak "Agent stopped for an unknown reason.")
        (icon warn-user)
        (speak "Agent error: Connection lost."))))))

(ert-deftest emacspeak-agent-shell-lifecycle-subscription-is-idempotent ()
  "Lifecycle events should subscribe once, dispatch, and clean up."
  (let ((buffer (generate-new-buffer " *agent-shell-lifecycle-test*"))
        (emacspeak-agent-shell-signal-processing t))
    (unwind-protect
        (with-current-buffer buffer
          (setq major-mode 'agent-shell-mode)
          (setq-local agent-shell--state
                      (list (cons :buffer buffer)
                            (cons :event-subscriptions nil)))
          (emacspeak-agent-shell--lifecycle-event-setup)
          (let ((token emacspeak-agent-shell--lifecycle-subscription))
            (emacspeak-agent-shell--lifecycle-event-setup)
            (should (equal token
                           emacspeak-agent-shell--lifecycle-subscription))
            (should (= 1 (length (map-elt
                                  agent-shell--state
                                  :event-subscriptions)))))
          (should
           (equal
            (emacspeak-agent-shell-test--capture-events
              (cl-letf (((symbol-function 'agent-shell--sync-system-sleep)
                         #'ignore))
                (agent-shell--emit-event :event 'input-submitted)
                (agent-shell--emit-event
                 :event 'turn-complete
                 :data '((:stop-reason . "end_turn")))))
            '((icon progress)
              (icon task-done))))
          (emacspeak-agent-shell--lifecycle-event-cleanup)
          (should-not emacspeak-agent-shell--lifecycle-subscription)
          (should-not (map-elt agent-shell--state :event-subscriptions)))
      (when (buffer-live-p buffer)
        (kill-buffer buffer)))))

(ert-deftest emacspeak-agent-shell-lifecycle-suppresses-rendered-duplicate ()
  "Public error feedback should preserve content but drop its visual duplicate."
  (let ((emacspeak-agent-shell-signal-processing t)
        timer)
    (unwind-protect
        (with-temp-buffer
          (setq-local emacspeak-agent-shell--pending-bodies
                      (make-hash-table :test #'equal))
          (puthash "1-agent_message_chunk" "Useful partial response"
                   emacspeak-agent-shell--pending-bodies)
          (puthash "1-failed-1-id:?-code:500" "Connection lost"
                   emacspeak-agent-shell--pending-bodies)
          (setq-local emacspeak-agent-shell--pending-speech-qualified-ids
                      '("1-agent_message_chunk"
                        "1-failed-1-id:?-code:500"))
          (setq timer (run-with-timer 3600 nil #'ignore))
          (setq-local emacspeak-agent-shell--pending-speech-timer timer)
          (should
           (equal
            (emacspeak-agent-shell-test--capture-events
              (emacspeak-agent-shell--handle-lifecycle-event
               '((:event . error)
                 (:data (:message . "Connection lost")))))
            '((icon warn-user)
              (speak "Agent error: Connection lost"))))
          (should (gethash "1-agent_message_chunk"
                           emacspeak-agent-shell--pending-bodies))
          (should-not (gethash "1-failed-1-id:?-code:500"
                               emacspeak-agent-shell--pending-bodies))
          (should
           (equal emacspeak-agent-shell--pending-speech-qualified-ids
                  '("1-agent_message_chunk")))
          (should (timerp emacspeak-agent-shell--pending-speech-timer)))
      (when (timerp timer)
        (cancel-timer timer)))))

(ert-deftest emacspeak-agent-shell-lifecycle-feedback-can-be-disabled ()
  "The lifecycle option should suppress all lifecycle feedback."
  (let ((emacspeak-agent-shell-signal-processing nil))
    (should-not
     (emacspeak-agent-shell-test--capture-events
       (emacspeak-agent-shell--handle-lifecycle-event
        '((:event . input-submitted)))
       (emacspeak-agent-shell--handle-lifecycle-event
        '((:event . error)
          (:data (:message . "Connection lost"))))))))

(ert-deftest emacspeak-agent-shell-tool-fixture-announces-transitions ()
  "Fixture tool transitions should be concise, ordered, and deduplicated."
  (let ((events
         (emacspeak-agent-shell-test--tool-call-events
          "gemini-wrong-output-grouping.traffic"))
        (emacspeak-agent-shell-speak-tool-calls t)
        (emacspeak-agent-shell-tool-output-verbosity 'summary))
    (should (= 6 (length events)))
    (with-temp-buffer
      (should
       (equal
        (emacspeak-agent-shell-test--capture-events
          (dolist (event events)
            (emacspeak-agent-shell--handle-tool-call-update event)))
        '((icon progress)
          (speak "Tool started: search.")
          (icon task-done)
          (speak "Tool completed: search.")
          (icon progress)
          (speak "Tool started: README.org.")
          (icon task-done)
          (speak "Tool completed: README.org.")
          (icon progress)
          (speak "Tool started: acp.el.")
          (icon task-done)
          (speak "Tool completed: acp.el.")))))))

(ert-deftest emacspeak-agent-shell-tool-status-verbosity-is-icon-only ()
  "Status verbosity should cue each real status without speaking titles."
  (let ((emacspeak-agent-shell-speak-tool-calls t)
        (emacspeak-agent-shell-tool-output-verbosity 'status))
    (with-temp-buffer
      (should
       (equal
        (emacspeak-agent-shell-test--capture-events
          (dolist (entry '(("pending" "one")
                           ("in_progress" "two")
                           ("completed" "three")
                           ("failed" "four")))
            (emacspeak-agent-shell--handle-tool-call-update
             (emacspeak-agent-shell-test--tool-call-event
              (cadr entry) (car entry) (cadr entry))))
          (emacspeak-agent-shell--handle-tool-call-update
           (emacspeak-agent-shell-test--tool-call-event
            "future" "waiting_for_agent" "Future status")))
        '((icon item)
          (icon progress)
          (icon task-done)
          (icon warn-user))))
      (should-not
       (emacspeak-agent-shell--tool-call-block-handled-p "future")))))

(ert-deftest emacspeak-agent-shell-tool-full-verbosity-speaks-output ()
  "Full verbosity should speak terminal text after its status summary."
  (let ((emacspeak-agent-shell-speak-tool-calls t)
        (emacspeak-agent-shell-tool-output-verbosity 'full))
    (with-temp-buffer
      (should
       (equal
        (emacspeak-agent-shell-test--capture-events
          (dolist
              (event
               (list
                (emacspeak-agent-shell-test--tool-call-event
                 "calculator" "in_progress" "Calculate total")
                (emacspeak-agent-shell-test--tool-call-event
                 "calculator" "completed" "Calculate total"
                 '[((type . "content")
                    (content (type . "text") (text . "Total: 42")))])
                (emacspeak-agent-shell-test--tool-call-event
                 "compiler" "failed" "Compile project"
                 '[((type . "content")
                    (content (type . "text")
                             (text . "Undefined function")))])))
            (emacspeak-agent-shell--handle-tool-call-update event)))
        '((icon progress)
          (speak "Tool started: Calculate total.")
          (icon task-done)
          (speak "Tool completed: Calculate total.")
          (speak "Output: Total: 42")
          (icon warn-user)
          (speak "Tool failed: Compile project.")
          (speak "Output: Undefined function")))))))

(ert-deftest emacspeak-agent-shell-tool-updates-speak-once-per-status ()
  "Repeated streaming updates should not repeat an unchanged tool status."
  (let ((event
         (emacspeak-agent-shell-test--tool-call-event
          "reader" "in_progress" "Read README"))
        (emacspeak-agent-shell-speak-tool-calls t)
        (emacspeak-agent-shell-tool-output-verbosity 'summary))
    (with-temp-buffer
      (should
       (equal
        (emacspeak-agent-shell-test--capture-events
          (emacspeak-agent-shell--handle-tool-call-update event)
          (emacspeak-agent-shell--handle-tool-call-update event))
        '((icon progress)
          (speak "Tool started: Read README."))))
      (should (= 1 (hash-table-count
                    emacspeak-agent-shell--tool-call-status-cache)))
      (should (emacspeak-agent-shell--tool-call-block-handled-p "reader")))))

(ert-deftest emacspeak-agent-shell-tool-subscription-cleans-state ()
  "Tool subscriptions and status state should install and clean up once."
  (let ((buffer (generate-new-buffer " *agent-shell-tool-test*"))
        (emacspeak-agent-shell-speak-tool-calls t)
        (emacspeak-agent-shell-tool-output-verbosity 'summary))
    (unwind-protect
        (with-current-buffer buffer
          (setq major-mode 'agent-shell-mode)
          (setq-local agent-shell--state
                      (list (cons :buffer buffer)
                            (cons :event-subscriptions nil)))
          (emacspeak-agent-shell--tool-call-event-setup)
          (let ((token emacspeak-agent-shell--tool-call-subscription))
            (emacspeak-agent-shell--tool-call-event-setup)
            (should (equal token
                           emacspeak-agent-shell--tool-call-subscription))
            (should (= 1 (length (map-elt
                                  agent-shell--state
                                  :event-subscriptions)))))
          (should
           (equal
            (emacspeak-agent-shell-test--capture-events
              (cl-letf (((symbol-function 'agent-shell--sync-system-sleep)
                         #'ignore))
                (agent-shell--emit-event
                 :event 'tool-call-update
                 :data
                 (map-elt
                  (emacspeak-agent-shell-test--tool-call-event
                   "reader" "completed" "Read README")
                  :data))))
            '((icon task-done)
              (speak "Tool completed: Read README."))))
          (should (= 1 (hash-table-count
                        emacspeak-agent-shell--tool-call-status-cache)))
          (let ((emacspeak-agent-shell-signal-processing nil))
            (emacspeak-agent-shell--handle-lifecycle-event
             '((:event . turn-complete)
               (:data (:stop-reason . "end_turn")))))
          (should (= 0 (hash-table-count
                        emacspeak-agent-shell--tool-call-status-cache)))
          (emacspeak-agent-shell--tool-call-event-cleanup)
          (should-not emacspeak-agent-shell--tool-call-subscription)
          (should-not emacspeak-agent-shell--tool-call-status-cache)
          (should-not (map-elt agent-shell--state :event-subscriptions)))
      (when (buffer-live-p buffer)
        (kill-buffer buffer)))))

(ert-deftest emacspeak-agent-shell-tool-feedback-can-be-disabled ()
  "Disabling tool speech should retain status state without feedback."
  (let ((emacspeak-agent-shell-speak-tool-calls nil))
    (with-temp-buffer
      (should-not
       (emacspeak-agent-shell-test--capture-events
         (emacspeak-agent-shell--handle-tool-call-update
          (emacspeak-agent-shell-test--tool-call-event
           "reader" "in_progress" "Read README"))))
      (should (= 1 (hash-table-count
                    emacspeak-agent-shell--tool-call-status-cache))))))

(ert-deftest emacspeak-agent-shell-permission-button-feedback-is-semantic ()
  "Focused permission feedback should include choice position and key."
  (with-temp-buffer
    (emacspeak-agent-shell-test--insert-permission-buttons)
    (goto-char (point-min))
    (should (agent-shell-next-permission-button))
    (should
     (equal
      (emacspeak-agent-shell-test--capture-events
        (emacspeak-agent-shell--permission-button-feedback))
      '((icon item)
        (speak "Allow, choice 1 of 3. Press Return or y."))))
    (should (agent-shell-next-permission-button))
    (should
     (equal
      (emacspeak-agent-shell-test--capture-events
        (emacspeak-agent-shell--permission-button-feedback))
      '((icon item)
        (speak "Reject, choice 2 of 3. Press Return or n."))))))

(ert-deftest emacspeak-agent-shell-permission-button-advice-observes-boundary ()
  "Interactive choice navigation should speak moves but not failed moves."
  (with-temp-buffer
    (setq major-mode 'agent-shell-mode)
    (emacspeak-agent-shell-test--insert-permission-buttons)
    (goto-char (point-min))
    (should
     (equal
      (emacspeak-agent-shell-test--capture-events
        (call-interactively #'agent-shell-next-permission-button))
      '((icon item)
        (speak "Allow, choice 1 of 3. Press Return or y."))))
    (ignore
     (emacspeak-agent-shell-test--capture-events
       (call-interactively #'agent-shell-next-permission-button)
       (call-interactively #'agent-shell-next-permission-button)))
    (should-not
     (emacspeak-agent-shell-test--capture-events
       (call-interactively #'agent-shell-next-permission-button)))
    (should
     (equal
      (emacspeak-agent-shell-test--capture-events
        (call-interactively #'agent-shell-previous-permission-button))
      '((icon item)
        (speak "Reject, choice 2 of 3. Press Return or n."))))))

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
