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
(defvar emacspeak-agent-shell--pending-bodies)
(defvar emacspeak-agent-shell--pending-speech-qualified-ids)
(defvar emacspeak-agent-shell--pending-speech-timer)
(defvar emacspeak-agent-shell--tool-call-status-cache)
(defvar emacspeak-agent-shell--tool-call-subscription)
(defvar emacspeak-agent-shell-background-speech-level)
(defvar emacspeak-agent-shell-foreground-speech-level)
(defvar emacspeak-agent-shell--table-navigation-active)
(defvar emacspeak-agent-shell--table-navigation-map)
(defvar emacspeak-agent-shell--table-navigation-table-start)
(defvar emacspeak-agent-shell--speech-control-active)
(defvar emacspeak-agent-shell--speech-control-map)
(defvar emacspeak-agent-shell-processing-end-icon)
(defvar emacspeak-agent-shell-processing-start-icon)
(defvar emacspeak-agent-shell-signal-processing)
(defvar emacspeak-agent-shell-speak-permissions)
(defvar emacspeak-agent-shell-speak-tool-calls)
(defvar emacspeak-agent-shell-table-data-position)
(defvar emacspeak-agent-shell-table-titles)
(defvar emacspeak-agent-shell-tool-output-verbosity)
(defvar emacspeak-agent-shell-speech-level)
(defvar emacspeak-comint-autospeak)
(defvar agent-shell-mode-map)
(defvar agent-shell-viewport-edit-mode-hook)
(defvar agent-shell-viewport-view-mode-hook)

(declare-function emacspeak-agent-shell--execute-delayed-speech
                  "emacspeak-agent-shell" (buffer qualified-ids))
(declare-function emacspeak-agent-shell--effective-speech-level
                  "emacspeak-agent-shell" (&optional buffer))
(declare-function emacspeak-agent-shell--buffer-cleanup
                  "emacspeak-agent-shell" ())
(declare-function emacspeak-agent-shell--buffer-setup
                  "emacspeak-agent-shell" ())
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
(declare-function emacspeak-agent-shell--markdown-table-region-at-point
                  "emacspeak-agent-shell" ())
(declare-function emacspeak-agent-shell--permission-button-feedback
                  "emacspeak-agent-shell" ())
(declare-function emacspeak-agent-shell--permission-event-cleanup
                  "emacspeak-agent-shell" ())
(declare-function emacspeak-agent-shell--permission-event-setup
                  "emacspeak-agent-shell" ())
(declare-function emacspeak-agent-shell--session-focused-p
                  "emacspeak-agent-shell" (&optional buffer))
(declare-function emacspeak-agent-shell--install-speech-control-bindings
                  "emacspeak-agent-shell" ())
(declare-function emacspeak-agent-shell-cycle-speech-level
                  "emacspeak-agent-shell" (&optional reset))
(declare-function emacspeak-agent-shell-select-background-speech-level
                  "emacspeak-agent-shell" ())
(declare-function emacspeak-agent-shell-select-speech-level
                  "emacspeak-agent-shell" ())
(declare-function emacspeak-agent-shell--speak-content
                  "emacspeak-agent-shell" (content block-type))
(declare-function emacspeak-agent-shell--tool-call-block-handled-p
                  "emacspeak-agent-shell" (block-id))
(declare-function emacspeak-agent-shell--tool-call-event-cleanup
                  "emacspeak-agent-shell" ())
(declare-function emacspeak-agent-shell--tool-call-event-setup
                  "emacspeak-agent-shell" ())
(declare-function emacspeak-agent-shell--table-cell-feedback
                  "emacspeak-agent-shell" ())
(declare-function emacspeak-agent-shell--table-navigation-cleanup
                  "emacspeak-agent-shell" ())
(declare-function emacspeak-agent-shell--table-navigation-post-command
                  "emacspeak-agent-shell" ())
(declare-function emacspeak-agent-shell--table-navigation-pre-command
                  "emacspeak-agent-shell" ())
(declare-function emacspeak-agent-shell--table-navigation-setup
                  "emacspeak-agent-shell" ())
(declare-function emacspeak-agent-shell--table-between
                  "emacspeak-agent-shell" (origin destination direction))
(declare-function emacspeak-agent-shell-disable "emacspeak-agent-shell" ())
(declare-function emacspeak-agent-shell-enable "emacspeak-agent-shell" ())
(declare-function emacspeak-agent-shell-speech-setup
                  "emacspeak-agent-shell" ())
(declare-function emacspeak-agent-shell-table-select-speaking-method
                  "emacspeak-agent-shell" ())
(declare-function emacspeak-agent-shell-table-copy-cell
                  "emacspeak-agent-shell" ())
(declare-function emacspeak-agent-shell-table-exit-backward
                  "emacspeak-agent-shell" ())
(declare-function emacspeak-agent-shell-table-exit-forward
                  "emacspeak-agent-shell" ())
(declare-function emacspeak-agent-shell-table-next-column
                  "emacspeak-agent-shell" (&optional count))
(declare-function emacspeak-agent-shell-table-next-row
                  "emacspeak-agent-shell" (&optional count))
(declare-function emacspeak-agent-shell-table-previous-column
                  "emacspeak-agent-shell" (&optional count))
(declare-function emacspeak-agent-shell-table-previous-row
                  "emacspeak-agent-shell" (&optional count))
(declare-function emacspeak-agent-shell-table-speak-cell
                  "emacspeak-agent-shell" ())
(declare-function emacspeak-agent-shell-table-speak-column
                  "emacspeak-agent-shell" ())
(declare-function emacspeak-agent-shell-table-speak-context
                  "emacspeak-agent-shell" ())
(declare-function emacspeak-agent-shell-table-speak-dimensions
                  "emacspeak-agent-shell" ())
(declare-function emacspeak-agent-shell-table-speak-row
                  "emacspeak-agent-shell" ())

(declare-function agent-shell--make-permission-button
                  "agent-shell" (&rest arguments))
(declare-function agent-shell--save-tool-call
                  "agent-shell" (state tool-call-id tool-call))
(declare-function agent-shell-markdown-replace-markup
                  "agent-shell-markdown" (&rest arguments))

(defconst emacspeak-agent-shell-test--agent-shell-directory
  (file-name-as-directory
   (expand-file-name
    (or (getenv "AGENT_SHELL_DIR") "~/src/agent-shell")))
  "Agent-shell checkout used for compatibility fixtures.")

(defmacro emacspeak-agent-shell-test--capture-events (&rest body)
  "Run BODY and return ordered speech, stop, icon, and message events."
  (declare (indent 0) (debug t))
  (let ((event-log (make-symbol "event-log")))
    `(let ((emacspeak-agent-shell-foreground-speech-level 'full)
           (emacspeak-agent-shell-background-speech-level 'full)
           (,event-log nil))
       (cl-letf (((symbol-function 'dtk-speak)
                  (lambda (text)
                    (push (list 'speak text) ,event-log)))
                 ((symbol-function 'dtk-notify)
                  (lambda (text &optional _dont-log)
                    (push (list 'notify text) ,event-log)))
                 ((symbol-function 'dtk-notify-icon)
                  (lambda (icon)
                    (push (list 'notify-icon icon) ,event-log)))
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
                          ,event-log)))
                 ((symbol-function 'emacspeak-agent-shell--session-focused-p)
                  (lambda (&optional _buffer) t)))
         ,@body
         (nreverse ,event-log)))))

(defun emacspeak-agent-shell-test--speak-pending (entries)
  "Speak pending ENTRIES and return captured events.
ENTRIES is an alist of qualified block IDs to body strings."
  (let ((buffer (generate-new-buffer " *emacspeak-agent-shell-test*")))
    (unwind-protect
        (with-current-buffer buffer
          (setq-local emacspeak-comint-autospeak t)
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

(defmacro emacspeak-agent-shell-test--with-rendered-table (source &rest body)
  "Render Markdown table SOURCE in a temporary buffer, then run BODY."
  (declare (indent 1) (debug t))
  `(with-temp-buffer
     (insert ,source)
     (agent-shell-markdown-replace-markup)
     ,@body))

(defun emacspeak-agent-shell-test--table-entry (command mode direction)
  "Navigate with COMMAND in MODE across a real block containing a table.
Return speech events plus the target character.  DIRECTION is `forward' or
`backward'."
  (with-temp-buffer
    (let ((response-start (point))
          response-end next-start)
      (insert "thinking\nbefore\n| A | B |\n|---|---|\n| 1 | 2 |\nafter\n")
      (setq response-end (point))
      (insert "\n")
      (setq next-start (point))
      (insert "next item\n")
      (put-text-property
       response-start response-end 'agent-shell-ui-state
       '((:qualified-id . "response") (:navigatable . t)))
      (put-text-property
       next-start (point-max) 'agent-shell-ui-state
       '((:qualified-id . "next") (:navigatable . t))))
    (agent-shell-markdown-replace-markup)
    (goto-char (point-min))
    (let ((emacspeak-agent-shell-table-titles '(column))
          (emacspeak-agent-shell-table-data-position 'first))
      (setq major-mode mode)
      (if (eq direction 'forward)
          (goto-char (point-min))
        (goto-char (point-min))
        (search-forward "next item")
        (backward-char (length "next item")))
      (cl-letf (((symbol-function 'shell-maker-busy) (lambda () t))
                ((symbol-function 'comint-next-prompt) (lambda (&rest _) nil))
                ((symbol-function 'agent-shell-next-permission-button)
                 (lambda () nil))
                ((symbol-function 'agent-shell-previous-permission-button)
                 (lambda () nil))
                ((symbol-function 'agent-shell-viewport--prompt-start)
                 (lambda () nil))
                ((symbol-function 'agent-shell-viewport--response-start)
                 (lambda () nil)))
        (let ((events
               (emacspeak-agent-shell-test--capture-events
                 (call-interactively command))))
          (list events (char-after)))))))

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
        (saved-viewport-edit-hook agent-shell-viewport-edit-mode-hook)
        (saved-viewport-view-hook agent-shell-viewport-view-mode-hook)
        (saved-advice (emacspeak-agent-shell-test--saved-advice-state)))
    (unwind-protect
        (progn
          (emacspeak-agent-shell-enable)
          (should (memq #'emacspeak-agent-shell-speech-setup
                        agent-shell-mode-hook))
          (should (memq #'emacspeak-agent-shell--buffer-setup
                        agent-shell-mode-hook))
          (should
           (memq #'emacspeak-agent-shell--table-navigation-setup
                 agent-shell-viewport-edit-mode-hook))
          (should
           (memq #'emacspeak-agent-shell--table-navigation-setup
                 agent-shell-viewport-view-mode-hook))
          (should-not
           (memq #'emacspeak-agent-shell--permission-event-setup
                 agent-shell-mode-hook))
          (should-not
           (memq #'emacspeak-agent-shell--lifecycle-event-setup
                 agent-shell-mode-hook))
          (should-not
           (memq #'emacspeak-agent-shell--tool-call-event-setup
                 agent-shell-mode-hook))
          (dolist (entry emacspeak-agent-shell--advice-list)
            (when (fboundp (car entry))
              (should (ad-is-active (car entry)))))
          (emacspeak-agent-shell-disable)
          (should-not (memq #'emacspeak-agent-shell-speech-setup
                            agent-shell-mode-hook))
          (should-not (memq #'emacspeak-agent-shell--buffer-setup
                            agent-shell-mode-hook))
          (should-not
           (memq #'emacspeak-agent-shell--table-navigation-setup
                 agent-shell-viewport-edit-mode-hook))
          (should-not
           (memq #'emacspeak-agent-shell--table-navigation-setup
                 agent-shell-viewport-view-mode-hook))
          (should-not (memq #'emacspeak-agent-shell--permission-event-setup
                            agent-shell-mode-hook))
          (should-not (memq #'emacspeak-agent-shell--lifecycle-event-setup
                            agent-shell-mode-hook))
          (should-not (memq #'emacspeak-agent-shell--tool-call-event-setup
                            agent-shell-mode-hook))
          (dolist (entry emacspeak-agent-shell--advice-list)
            (should-not (ad-is-active (car entry)))))
      (setq agent-shell-mode-hook saved-hook)
      (setq agent-shell-viewport-edit-mode-hook saved-viewport-edit-hook
            agent-shell-viewport-view-mode-hook saved-viewport-view-hook)
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

(ert-deftest emacspeak-agent-shell-focus-includes-associated-viewport ()
  "A selected shell or its viewport should be the focused session."
  (let ((shell (generate-new-buffer "Codex Agent @ focus-test"))
        (viewport (generate-new-buffer
                   "Codex Agent @ focus-test [viewport]"))
        (other (generate-new-buffer " *agent-shell-other*"))
        (emacspeak-agent-shell-foreground-speech-level 'response)
        (emacspeak-agent-shell-background-speech-level 'notify))
    (unwind-protect
        (save-window-excursion
          (with-current-buffer shell
            (setq major-mode 'agent-shell-mode))
          (with-current-buffer viewport
            (setq major-mode 'agent-shell-viewport-view-mode))
          (switch-to-buffer shell)
          (should (emacspeak-agent-shell--session-focused-p shell))
          (should (eq (emacspeak-agent-shell--effective-speech-level shell)
                      'response))
          (switch-to-buffer other)
          (should-not (emacspeak-agent-shell--session-focused-p shell))
          (should (eq (emacspeak-agent-shell--effective-speech-level shell)
                      'notify))
          (switch-to-buffer viewport)
          (should (emacspeak-agent-shell--session-focused-p shell))
          (should (eq (emacspeak-agent-shell--effective-speech-level shell)
                      'response)))
      (dolist (buffer (list shell viewport other))
        (when (buffer-live-p buffer)
          (kill-buffer buffer))))))

(ert-deftest emacspeak-agent-shell-speech-level-cycle-is-session-local ()
  "Cycling should reduce speech, cancel queued content, and reset to auto."
  (let ((buffer (generate-new-buffer "Codex Agent @ cycle-test"))
        timer)
    (unwind-protect
        (with-current-buffer buffer
          (setq major-mode 'agent-shell-mode)
          (setq-local emacspeak-agent-shell-speech-level 'auto)
          (setq-local emacspeak-agent-shell--pending-bodies
                      (make-hash-table :test #'equal))
          (puthash "1-agent_message_chunk" "Pending response"
                   emacspeak-agent-shell--pending-bodies)
          (setq timer (run-with-timer 3600 nil #'ignore))
          (setq-local emacspeak-agent-shell--pending-speech-timer timer
                      emacspeak-agent-shell--pending-speech-qualified-ids
                      '("1-agent_message_chunk"))
          (should
           (equal
            (emacspeak-agent-shell-test--capture-events
              (let ((emacspeak-agent-shell-foreground-speech-level 'response)
                    (emacspeak-agent-shell-background-speech-level 'notify))
                (call-interactively
                 #'emacspeak-agent-shell-cycle-speech-level)))
            '((icon select-object)
              (speak
               "Agent speech notify for Codex Agent @ cycle-test."))))
          (should (eq emacspeak-agent-shell-speech-level 'notify))
          (should-not emacspeak-agent-shell--pending-speech-timer)
          (should-not emacspeak-agent-shell--pending-speech-qualified-ids)
          (should (= 0 (hash-table-count
                        emacspeak-agent-shell--pending-bodies)))
          (should
           (equal
            (emacspeak-agent-shell-test--capture-events
              (call-interactively
               #'emacspeak-agent-shell-cycle-speech-level))
            '((icon off)
              (speak "Agent speech quiet for Codex Agent @ cycle-test."))))
          (should (eq emacspeak-agent-shell-speech-level 'quiet))
          (should
           (equal
            (emacspeak-agent-shell-test--capture-events
              (call-interactively
               #'emacspeak-agent-shell-cycle-speech-level))
            '((icon select-object)
              (speak "Agent speech full for Codex Agent @ cycle-test."))))
          (should (eq emacspeak-agent-shell-speech-level 'full))
          (should
           (equal
            (emacspeak-agent-shell-test--capture-events
              (let ((emacspeak-agent-shell-foreground-speech-level 'response)
                    (emacspeak-agent-shell-background-speech-level 'notify))
                (emacspeak-agent-shell-cycle-speech-level t)))
            '((icon select-object)
              (speak "Agent speech automatic: response when focused, notify in background."))))
          (should (eq emacspeak-agent-shell-speech-level 'auto)))
      (when (timerp timer)
        (cancel-timer timer))
      (when (buffer-live-p buffer)
        (kill-buffer buffer)))))

(ert-deftest emacspeak-agent-shell-speech-bindings-upgrade-live-map ()
  "Reloading support should replace cycling and install the shifted selector."
  (let* ((map emacspeak-agent-shell--speech-control-map)
         (current-key (kbd "C-c C-q"))
         (background-key (kbd "C-c C-S-q"))
         (saved-current (lookup-key map current-key))
         (saved-background (lookup-key map background-key)))
    (unwind-protect
        (progn
          (define-key map current-key
                      #'emacspeak-agent-shell-cycle-speech-level)
          (define-key map background-key nil)
          (emacspeak-agent-shell--install-speech-control-bindings)
          (should
           (eq (lookup-key map current-key)
               #'emacspeak-agent-shell-select-speech-level))
          (should
           (eq (lookup-key map background-key)
               #'emacspeak-agent-shell-select-background-speech-level)))
      (define-key map current-key saved-current)
      (define-key map background-key saved-background))))

(ert-deftest emacspeak-agent-shell-speech-level-control-works-in-viewport ()
  "Viewport selectors should target the shell and remain active in tables."
  (let ((shell (generate-new-buffer "Codex Agent @ viewport-level"))
        (viewport
         (generate-new-buffer "Codex Agent @ viewport-level [viewport]")))
    (unwind-protect
        (progn
          (with-current-buffer shell
            (setq major-mode 'agent-shell-mode)
            (setq-local emacspeak-agent-shell-speech-level 'auto))
          (with-current-buffer viewport
            (setq major-mode 'agent-shell-viewport-view-mode)
            (emacspeak-agent-shell--table-navigation-setup)
            (should emacspeak-agent-shell--speech-control-active)
            (should
             (eq (key-binding (kbd "C-c C-q"))
                 #'emacspeak-agent-shell-select-speech-level))
            (should
             (eq (key-binding (kbd "C-c C-S-q"))
                 #'emacspeak-agent-shell-select-background-speech-level))
            (setq emacspeak-agent-shell--table-navigation-active t)
            (should
             (eq (key-binding (kbd "C-c C-q"))
                 #'emacspeak-agent-shell-select-speech-level))
            (should
             (eq (key-binding (kbd "C-c C-S-q"))
                 #'emacspeak-agent-shell-select-background-speech-level))
            (should
             (equal
              (emacspeak-agent-shell-test--capture-events
                (cl-letf (((symbol-function 'completing-read)
                           (lambda (&rest _) "notify")))
                  (call-interactively
                   #'emacspeak-agent-shell-select-speech-level)))
              '((icon select-object)
                (speak
                 "Agent speech notify for Codex Agent @ viewport-level."))))
            (emacspeak-agent-shell--table-navigation-cleanup)
            (should-not emacspeak-agent-shell--speech-control-active))
          (with-current-buffer shell
            (should (eq emacspeak-agent-shell-speech-level 'notify))))
      (dolist (buffer (list shell viewport))
        (when (buffer-live-p buffer)
          (kill-buffer buffer))))))

(ert-deftest emacspeak-agent-shell-background-selector-cancels-auto-sessions ()
  "Selecting a quiet background default should cancel only affected queues."
  (let ((foreground (generate-new-buffer "Codex Agent @ selector-front"))
        (background (generate-new-buffer "Codex Agent @ selector-back"))
        (forced (generate-new-buffer "Codex Agent @ selector-forced"))
        background-timer forced-timer selected-level)
    (unwind-protect
        (progn
          (dolist (buffer (list foreground background forced))
            (with-current-buffer buffer
              (setq major-mode 'agent-shell-mode)
              (setq-local emacspeak-agent-shell--pending-bodies
                          (make-hash-table :test #'equal))
              (puthash "1-agent_message_chunk" "Pending"
                       emacspeak-agent-shell--pending-bodies)
              (setq-local emacspeak-agent-shell--pending-speech-qualified-ids
                          '("1-agent_message_chunk"))))
          (with-current-buffer background
            (setq-local emacspeak-agent-shell-speech-level 'auto)
            (setq background-timer (run-with-timer 3600 nil #'ignore))
            (setq-local emacspeak-agent-shell--pending-speech-timer
                        background-timer))
          (with-current-buffer forced
            (setq-local emacspeak-agent-shell-speech-level 'full)
            (setq forced-timer (run-with-timer 3600 nil #'ignore))
            (setq-local emacspeak-agent-shell--pending-speech-timer
                        forced-timer))
          (with-current-buffer foreground
            (should
             (equal
              (emacspeak-agent-shell-test--capture-events
                (cl-letf
                    (((symbol-function 'completing-read)
                      (lambda (&rest _) "quiet"))
                     ((symbol-function 'buffer-list)
                      (lambda (&optional _frame)
                        (list foreground background forced)))
                     ((symbol-function
                       'emacspeak-agent-shell--session-focused-p)
                      (lambda (&optional buffer)
                        (eq (or buffer (current-buffer)) foreground))))
                  (call-interactively
                   #'emacspeak-agent-shell-select-background-speech-level)
                  (setq selected-level
                        emacspeak-agent-shell-background-speech-level)))
              '((icon off)
                (speak "Background agent speech quiet.")))))
          (should (eq selected-level 'quiet))
          (with-current-buffer background
            (should-not emacspeak-agent-shell--pending-speech-timer)
            (should-not emacspeak-agent-shell--pending-speech-qualified-ids)
            (should (= 0 (hash-table-count
                          emacspeak-agent-shell--pending-bodies))))
          (with-current-buffer forced
            (should (eq emacspeak-agent-shell--pending-speech-timer
                        forced-timer))
            (should emacspeak-agent-shell--pending-speech-qualified-ids)
            (should (= 1 (hash-table-count
                          emacspeak-agent-shell--pending-bodies)))))
      (dolist (timer (list background-timer forced-timer))
        (when (timerp timer)
          (cancel-timer timer)))
      (dolist (buffer (list foreground background forced))
        (when (buffer-live-p buffer)
          (kill-buffer buffer))))))

(ert-deftest emacspeak-agent-shell-session-override-beats-focus-default ()
  "A concrete per-session level should apply in foreground or background."
  (with-temp-buffer
    (setq-local emacspeak-agent-shell-speech-level 'full)
    (let ((emacspeak-agent-shell-background-speech-level 'quiet))
      (cl-letf (((symbol-function
                  'emacspeak-agent-shell--session-focused-p)
                 (lambda (&optional _buffer) nil)))
        (should (eq (emacspeak-agent-shell--effective-speech-level) 'full))))))

(ert-deftest emacspeak-agent-shell-response-level-reduces-focused-chatter ()
  "The default focused level should retain responses and completion only."
  (let ((emacspeak-agent-shell-foreground-speech-level 'response)
        (emacspeak-agent-shell-signal-processing t)
        (emacspeak-agent-shell-speak-tool-calls t))
    (with-temp-buffer
      (should
       (equal
        (emacspeak-agent-shell-test--capture-events
          (let ((emacspeak-agent-shell-foreground-speech-level 'response))
            (emacspeak-agent-shell--speak-content
             "Useful response" 'agent-message)
            (emacspeak-agent-shell--speak-content "Reasoning" 'thought)
            (emacspeak-agent-shell--handle-tool-call-update
             (emacspeak-agent-shell-test--tool-call-event
              "reader" "in_progress" "Read README"))
            (emacspeak-agent-shell--handle-lifecycle-event
             '((:event . input-submitted)))
            (emacspeak-agent-shell--handle-lifecycle-event
             '((:event . turn-complete)
               (:data (:stop-reason . "end_turn"))))))
        '((speak "Useful response")
          (icon task-done)))))))

(ert-deftest emacspeak-agent-shell-background-notifies-without-content ()
  "Background sessions should drop pending content and identify completion."
  (let ((buffer (generate-new-buffer "Codex Agent @ background-test"))
        (emacspeak-agent-shell-background-speech-level 'notify)
        (emacspeak-agent-shell-signal-processing t)
        (emacspeak-agent-shell-speak-tool-calls t))
    (unwind-protect
        (with-current-buffer buffer
          (setq-local emacspeak-comint-autospeak t)
          (setq-local emacspeak-agent-shell--pending-bodies
                      (make-hash-table :test #'equal))
          (puthash "1-agent_message_chunk" "Do not speak this response"
                   emacspeak-agent-shell--pending-bodies)
          (should
           (equal
            (emacspeak-agent-shell-test--capture-events
              (let ((emacspeak-agent-shell-background-speech-level 'notify))
                (cl-letf
                    (((symbol-function
                       'emacspeak-agent-shell--session-focused-p)
                      (lambda (&optional _buffer) nil)))
                  (emacspeak-agent-shell--execute-delayed-speech
                   buffer '("1-agent_message_chunk"))
                  (emacspeak-agent-shell--handle-tool-call-update
                   (emacspeak-agent-shell-test--tool-call-event
                    "reader" "completed" "Read README"))
                  (emacspeak-agent-shell--handle-lifecycle-event
                   '((:event . input-submitted)))
                  (emacspeak-agent-shell--handle-lifecycle-event
                   '((:event . turn-complete)
                     (:data (:stop-reason . "end_turn")))))))
            '((notify-icon task-done)
              (notify "Codex Agent @ background-test finished."))))
          (should (= 0 (hash-table-count
                        emacspeak-agent-shell--pending-bodies)))
          (should (= 0 (hash-table-count
                        emacspeak-agent-shell--tool-call-status-cache))))
      (when (buffer-live-p buffer)
        (kill-buffer buffer)))))

(ert-deftest emacspeak-agent-shell-quiet-retains-urgent-background-events ()
  "Quiet sessions should still identify errors and blocking permissions."
  (let ((buffer (generate-new-buffer "Codex Agent @ quiet-test"))
        (emacspeak-agent-shell-background-speech-level 'quiet)
        (emacspeak-agent-shell-signal-processing t)
        (emacspeak-agent-shell-speak-permissions t))
    (unwind-protect
        (with-current-buffer buffer
          (should
           (equal
            (emacspeak-agent-shell-test--capture-events
              (let ((emacspeak-agent-shell-background-speech-level 'quiet))
                (cl-letf
                    (((symbol-function
                       'emacspeak-agent-shell--session-focused-p)
                      (lambda (&optional _buffer) nil)))
                  (emacspeak-agent-shell--handle-lifecycle-event
                   '((:event . error)
                     (:data (:message . "Connection lost"))))
                  (emacspeak-agent-shell--handle-permission-request
                   '((:event . permission-request)
                     (:data (:tool-call-id . "tool-id")
                            (:tool-call
                             (:title . "Run command")
                             (:permission-actions
                              ((:option . "Allow"))))))))))
            '((notify-icon warn-user)
              (notify "Codex Agent @ quiet-test. Agent error: Connection lost")
              (stop nil)
              (notify-icon warn-user)
              (notify "Codex Agent @ quiet-test. Permission request. Run command. Choice 1: Allow.")))))
      (when (buffer-live-p buffer)
        (kill-buffer buffer)))))

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

(ert-deftest emacspeak-agent-shell-table-cell-feedback-is-customizable ()
  "Table feedback should support every title set and both orderings."
  (emacspeak-agent-shell-test--with-rendered-table
      "| Name | Role |\n|---|---|\n| Alice | Engineer |\n"
    (goto-char (point-min))
    (search-forward "Engineer")
    (backward-char (length "Engineer"))
    (dolist (case '(((column) first "Engineer, Role.")
                    ((row) first "Engineer, Alice.")
                    ((column row) first "Engineer, Alice, Role.")
                    (nil first "Engineer.")
                    ((column row) last "Alice, Role, Engineer.")))
      (let ((emacspeak-agent-shell-table-titles (nth 0 case))
            (emacspeak-agent-shell-table-data-position (nth 1 case)))
        (should
         (equal
          (emacspeak-agent-shell-test--capture-events
            (emacspeak-agent-shell--table-cell-feedback))
          `((icon item) (speak ,(nth 2 case)))))))))

(ert-deftest emacspeak-agent-shell-table-speaking-method-is-interactive ()
  "The table selector should toggle each setting and announce full state."
  (let ((emacspeak-agent-shell-table-titles '(column))
        (emacspeak-agent-shell-table-data-position 'first)
        (keys '(?c ?r ?o ?c)))
    (cl-letf (((symbol-function 'read-char-choice)
               (lambda (prompt choices)
                 (should (string-prefix-p "Toggle table speech" prompt))
                 (should (equal choices '(?c ?r ?o)))
                 (pop keys))))
      (should
       (equal
        (emacspeak-agent-shell-test--capture-events
          (call-interactively
           #'emacspeak-agent-shell-table-select-speaking-method))
        '((icon button)
          (speak
           "Table speech: data first; column titles off; row titles off."))))
      (should-not emacspeak-agent-shell-table-titles)
      (should
       (equal
        (emacspeak-agent-shell-test--capture-events
          (call-interactively
           #'emacspeak-agent-shell-table-select-speaking-method))
        '((icon button)
          (speak
           "Table speech: data first; column titles off; row titles on."))))
      (should (equal emacspeak-agent-shell-table-titles '(row)))
      (should
       (equal
        (emacspeak-agent-shell-test--capture-events
          (call-interactively
           #'emacspeak-agent-shell-table-select-speaking-method))
        '((icon button)
          (speak
           "Table speech: titles first; column titles off; row titles on."))))
      (should (eq emacspeak-agent-shell-table-data-position 'last))
      (should
       (equal
        (emacspeak-agent-shell-test--capture-events
          (call-interactively
           #'emacspeak-agent-shell-table-select-speaking-method))
        '((icon button)
          (speak
           "Table speech: titles first; column titles on; row titles on."))))
      (should (equal emacspeak-agent-shell-table-titles '(column row)))
      (should-not keys))))

(ert-deftest emacspeak-agent-shell-table-context-describes-header-and-data ()
  "Manual table context should distinguish headers from one-based data rows."
  (emacspeak-agent-shell-test--with-rendered-table
      (concat "| Name | Role | Notes |\n"
              "|---|---|---|\n"
              "| Alice | Engineer | Builds |\n"
              "| Bob | Reviewer | Checks |\n")
    (goto-char (point-min))
    (search-forward "Role")
    (backward-char (length "Role"))
    (should
     (equal
      (emacspeak-agent-shell-test--capture-events
        (call-interactively #'emacspeak-agent-shell-table-speak-context))
      '((icon item)
        (speak
         "Header row, column 2 of 3; table has 2 data rows."))))
    (search-forward "Engineer")
    (backward-char (length "Engineer"))
    (should
     (equal
      (emacspeak-agent-shell-test--capture-events
        (call-interactively #'emacspeak-agent-shell-table-speak-context))
      '((icon item)
        (speak "Data row 1 of 2, column 2 of 3."))))))

(ert-deftest emacspeak-agent-shell-table-context-handles-headerless-and-outside ()
  "Manual context should count headerless rows and reject non-table text."
  (emacspeak-agent-shell-test--with-rendered-table
      "| hello | world |\n| goodbye | moon |\n"
    (goto-char (point-min))
    (search-forward "world")
    (backward-char (length "world"))
    (should
     (equal
      (emacspeak-agent-shell-test--capture-events
        (call-interactively #'emacspeak-agent-shell-table-speak-context))
      '((icon item) (speak "Row 1 of 2, column 2 of 2."))))
    (goto-char (point-max))
    (insert "\noutside")
    (should-not
     (emacspeak-agent-shell-test--capture-events
       (should-error
        (call-interactively #'emacspeak-agent-shell-table-speak-context)
        :type 'user-error)))))

(ert-deftest emacspeak-agent-shell-table-entry-is-directional-in-both-views ()
  "Real item navigation should find embedded tables in both directions."
  (dolist (case
           `((agent-shell-next-item
              agent-shell-mode forward
              ((icon open-object)
               (speak "Table, 1 data row, 2 columns. A."))
              ,?A)
             (agent-shell-previous-item
              agent-shell-mode backward
              ((icon open-object)
               (speak "Table, 1 data row, 2 columns. 2, B."))
              ,?2)
             (agent-shell-viewport-next-item
              agent-shell-viewport-view-mode forward
              ((icon open-object)
               (speak "Table, 1 data row, 2 columns. A."))
              ,?A)
             (agent-shell-viewport-previous-item
              agent-shell-viewport-view-mode backward
              ((icon open-object)
               (speak "Table, 1 data row, 2 columns. 2, B."))
              ,?2)))
    (should
     (equal
      (emacspeak-agent-shell-test--table-entry
       (nth 0 case) (nth 1 case) (nth 2 case))
      (list (nth 3 case) (nth 4 case))))))

(ert-deftest emacspeak-agent-shell-prompt-letters-do-not-discover-tables ()
  "Typing n or p at the live prompt should insert without moving focus."
  (dolist (key '("n" "p"))
    (let ((buffer (generate-new-buffer " *agent-shell-prompt-table-test*")))
      (unwind-protect
          (save-window-excursion
            (switch-to-buffer buffer)
            (insert "before\n| A |\n|---|\n| 1 |\nafter\n\nCodex> ")
            (agent-shell-markdown-replace-markup)
            (setq major-mode 'agent-shell-mode)
            (use-local-map agent-shell-mode-map)
            (goto-char (point-max))
            (let ((origin (point))
                  events)
              (cl-letf
                  (((symbol-function 'shell-maker-busy) (lambda () nil))
                   ((symbol-function 'shell-maker-point-at-last-prompt-p)
                    (lambda () t)))
                (setq events
                      (emacspeak-agent-shell-test--capture-events
                        (execute-kbd-macro (kbd key)))))
              (should (= (point) (point-max) (1+ origin)))
              (should (string-suffix-p (concat "Codex> " key)
                                       (buffer-string)))
              (should-not
               (get-text-property
                (point) 'agent-shell-markdown-table-source))
              (should-not
               (seq-some
                (lambda (event)
                  (and (eq (car event) 'speak)
                       (string-match-p
                        "Table"
                        (substring-no-properties (cadr event)))))
                events))))
        (when (buffer-live-p buffer)
          (kill-buffer buffer))))))

(ert-deftest emacspeak-agent-shell-table-discovery-selects-nearest-visible ()
  "Discovery should visit multiple tables in order and ignore hidden tables."
  (emacspeak-agent-shell-test--with-rendered-table
      (concat "before\n| A |\n|---|\n| 1 |\nbetween\n"
              "| B |\n|---|\n| 2 |\nafter\n")
    (let* ((first
            (next-single-property-change
             (point-min) 'agent-shell-markdown-table-source nil (point-max)))
           (first-region
            (progn
              (goto-char first)
              (emacspeak-agent-shell--markdown-table-region-at-point)))
           (second
            (next-single-property-change
             (cdr first-region)
             'agent-shell-markdown-table-source nil (point-max))))
      (should
       (= first
          (emacspeak-agent-shell--table-between
           (point-min) (point-max) 'forward)))
      (should
       (equal
        (get-text-property
         (emacspeak-agent-shell--table-between
          (point-max) (point-min) 'backward)
         'agent-shell-markdown-table-source)
        "| B |\n|---|\n| 2 |"))
      (put-text-property (car first-region) (cdr first-region) 'invisible t)
      (should
       (= second
          (emacspeak-agent-shell--table-between
           (point-min) (point-max) 'forward))))))

(ert-deftest emacspeak-agent-shell-table-sequential-boundaries-exit ()
  "Sequential table commands should leave at either edge in both views."
  (dolist (case
           '((agent-shell-next-item agent-shell-mode "2"
              ((icon close-object) (speak "After table. after")) "after")
             (agent-shell-previous-item agent-shell-mode "A"
              ((icon close-object) (speak "Before table. before")) "before")
             (agent-shell-viewport-next-item
              agent-shell-viewport-view-mode "2"
              ((icon close-object) (speak "After table. after")) "after")
             (agent-shell-viewport-previous-item
              agent-shell-viewport-view-mode "A"
              ((icon close-object) (speak "Before table. before")) "before")))
    (emacspeak-agent-shell-test--with-rendered-table
        "before\n| A | B |\n|---|---|\n| 1 | 2 |\nafter\n"
      (goto-char (point-min))
      (search-forward (nth 2 case))
      (backward-char (length (nth 2 case)))
      (setq major-mode (nth 1 case))
      (cl-letf (((symbol-function 'shell-maker-busy) (lambda () t)))
        (should
         (equal
          (emacspeak-agent-shell-test--capture-events
            (call-interactively (nth 0 case)))
          (nth 3 case))))
      (should (looking-at (nth 4 case)))
      (should-not
       (get-text-property (point) 'agent-shell-markdown-table-source)))))

(ert-deftest emacspeak-agent-shell-table-row-speech-respects-title-settings ()
  "Logical row speech should announce a row title once and format each cell."
  (emacspeak-agent-shell-test--with-rendered-table
      (concat "| Name | Role | Notes |\n"
              "|---|---|---|\n"
              "| Alice | Engineer | Builds |\n"
              "| Bob | Reviewer | Checks |\n")
    (goto-char (point-min))
    (search-forward "Engineer")
    (backward-char (length "Engineer"))
    (dolist (case
             '(((column row) first
                "Alice. Engineer, Role. Builds, Notes.")
               ((column row) last
                "Alice. Role, Engineer. Notes, Builds.")
               ((column) first
                "Alice, Name. Engineer, Role. Builds, Notes.")
               (nil first "Alice. Engineer. Builds.")))
      (let ((emacspeak-agent-shell-table-titles (nth 0 case))
            (emacspeak-agent-shell-table-data-position (nth 1 case)))
        (should
         (equal
          (emacspeak-agent-shell-test--capture-events
            (call-interactively #'emacspeak-agent-shell-table-speak-row))
          `((icon item) (speak ,(nth 2 case)))))))))

(ert-deftest emacspeak-agent-shell-table-column-speech-respects-title-settings ()
  "Logical column speech should announce its title once and format each row."
  (emacspeak-agent-shell-test--with-rendered-table
      (concat "| Name | Role | Notes |\n"
              "|---|---|---|\n"
              "| Alice | Engineer | Builds |\n"
              "| Bob | Reviewer | Checks |\n")
    (goto-char (point-min))
    (search-forward "Engineer")
    (backward-char (length "Engineer"))
    (dolist (case
             '(((column row) first
                "Role. Engineer, Alice. Reviewer, Bob.")
               ((column row) last
                "Role. Alice, Engineer. Bob, Reviewer.")
               ((column) first "Role. Engineer. Reviewer.")
               ((row) first "Engineer, Alice. Reviewer, Bob.")
               (nil first "Engineer. Reviewer.")))
      (let ((emacspeak-agent-shell-table-titles (nth 0 case))
            (emacspeak-agent-shell-table-data-position (nth 1 case)))
        (should
         (equal
          (emacspeak-agent-shell-test--capture-events
            (call-interactively #'emacspeak-agent-shell-table-speak-column))
          `((icon item) (speak ,(nth 2 case)))))))))

(ert-deftest emacspeak-agent-shell-table-row-column-handle-table-kinds ()
  "Row and column speech should handle header rows and headerless tables."
  (let ((emacspeak-agent-shell-table-titles '(column row))
        (emacspeak-agent-shell-table-data-position 'first))
    (emacspeak-agent-shell-test--with-rendered-table
        "| Name | Role | Notes |\n|---|---|---|\n| Alice | Engineer | Builds |\n"
      (goto-char (point-min))
      (search-forward "Role")
      (backward-char (length "Role"))
      (should
       (equal
        (emacspeak-agent-shell-test--capture-events
          (call-interactively #'emacspeak-agent-shell-table-speak-row))
        '((icon item) (speak "Header row. Name. Role. Notes.")))))
    (emacspeak-agent-shell-test--with-rendered-table
        "| hello | world |\n| goodbye | moon |\n"
      (goto-char (point-min))
      (search-forward "world")
      (backward-char (length "world"))
      (should
       (equal
        (emacspeak-agent-shell-test--capture-events
          (call-interactively #'emacspeak-agent-shell-table-speak-row))
        '((icon item) (speak "hello. world."))))
      (should
       (equal
        (emacspeak-agent-shell-test--capture-events
          (call-interactively #'emacspeak-agent-shell-table-speak-column))
        '((icon item)
          (speak "world, hello. moon, goodbye.")))))))

(ert-deftest emacspeak-agent-shell-table-row-column-reject-outside-table ()
  "Manual row and column commands should remain silent outside tables."
  (with-temp-buffer
    (insert "outside")
    (dolist (command '(emacspeak-agent-shell-table-speak-row
                       emacspeak-agent-shell-table-speak-column))
      (should-not
       (emacspeak-agent-shell-test--capture-events
         (should-error (call-interactively command) :type 'user-error))))))

(ert-deftest emacspeak-agent-shell-table-copy-cell-copies-logical-value ()
  "Cell copying should omit visual structure and text properties."
  (let ((kill-ring nil)
        (kill-ring-yank-pointer nil))
    (emacspeak-agent-shell-test--with-rendered-table
        "| Name | Value |\n|---|---|\n| Alice | `a|b` |\n"
      (goto-char (point-min))
      (search-forward "Alice")
      (agent-shell-markdown-table-next-cell)
      (should
       (equal
        (emacspeak-agent-shell-test--capture-events
          (call-interactively #'emacspeak-agent-shell-table-copy-cell))
        '((icon save-object) (speak "Copied table cell."))))
      (should (equal (car kill-ring) "a|b"))
      (should-not (text-properties-at 0 (car kill-ring))))))

(ert-deftest emacspeak-agent-shell-table-copy-cell-handles-blank-and-outside ()
  "Cell copying should preserve blanks and remain silent outside tables."
  (let ((kill-ring '("existing"))
        (kill-ring-yank-pointer nil))
    (emacspeak-agent-shell-test--with-rendered-table
        "| Name | Value |\n|---|---|\n| Alice |  |\n"
      (goto-char (point-min))
      (search-forward "Alice")
      (agent-shell-markdown-table-next-cell)
      (should
       (equal
        (emacspeak-agent-shell-test--capture-events
          (call-interactively #'emacspeak-agent-shell-table-copy-cell))
        '((icon save-object) (speak "Copied table cell."))))
      (should (equal (car kill-ring) "")))
    (with-temp-buffer
      (insert "outside")
      (should-not
       (emacspeak-agent-shell-test--capture-events
         (should-error
          (call-interactively #'emacspeak-agent-shell-table-copy-cell)
          :type 'user-error)))
      (should (equal (car kill-ring) "")))))

(ert-deftest emacspeak-agent-shell-table-grid-navigation-is-logical ()
  "Grid movement should retain row/column identity across visual wrapping."
  (let ((emacspeak-agent-shell-table-titles '(column row))
        (emacspeak-agent-shell-table-data-position 'first)
        (agent-shell-markdown-table-max-width-fraction 1.0))
    (cl-letf (((symbol-function 'agent-shell-markdown--display-width)
               (lambda () 38)))
      (emacspeak-agent-shell-test--with-rendered-table
          (concat "| Name | Role | Notes |\n"
                  "|---|---|---|\n"
                  "| Alice | Engineer | owns a long wrapped description |\n"
                  "| Bob | Reviewer | Checks |\n")
        (goto-char (point-min))
        (search-forward "Engineer")
        (backward-char (length "Engineer"))
        (should
         (equal
          (emacspeak-agent-shell-test--capture-events
            (call-interactively
             #'emacspeak-agent-shell-table-next-column))
          '((icon item)
            (speak
             "owns a long wrapped description, Alice, Notes."))))
        (should
         (equal
          (emacspeak-agent-shell-test--capture-events
            (call-interactively #'emacspeak-agent-shell-table-next-row))
          '((icon item) (speak "Checks, Bob, Notes."))))
        (should
         (equal
          (emacspeak-agent-shell-test--capture-events
            (call-interactively
             #'emacspeak-agent-shell-table-previous-column))
          '((icon item) (speak "Reviewer, Bob, Role."))))
        (should
         (equal
          (emacspeak-agent-shell-test--capture-events
            (call-interactively #'emacspeak-agent-shell-table-previous-row))
          '((icon item) (speak "Engineer, Alice, Role."))))))))

(ert-deftest emacspeak-agent-shell-table-grid-navigation-handles-edges ()
  "Horizontal edges should warn; vertical edges should leave the table."
  (let ((emacspeak-agent-shell-table-titles '(column))
        (emacspeak-agent-shell-table-data-position 'first))
    (emacspeak-agent-shell-test--with-rendered-table
        "before\n| A | B |\n|---|---|\n| 1 | 2 |\nafter\n"
      (goto-char (point-min))
      (search-forward "A")
      (backward-char)
      (let ((position (point)))
        (should
         (equal
          (emacspeak-agent-shell-test--capture-events
            (call-interactively
             #'emacspeak-agent-shell-table-previous-column))
          '((icon warn-user) (speak "Left edge of table."))))
        (should (= position (point))))
      (should
       (equal
        (emacspeak-agent-shell-test--capture-events
          (call-interactively #'emacspeak-agent-shell-table-previous-row))
        '((icon close-object) (speak "Before table. before"))))
      (should (looking-at "before"))
      (search-forward "2")
      (backward-char)
      (should
       (equal
        (emacspeak-agent-shell-test--capture-events
          (call-interactively #'emacspeak-agent-shell-table-next-row))
        '((icon close-object) (speak "After table. after"))))
      (should (looking-at "after")))))

(ert-deftest emacspeak-agent-shell-table-explicit-exit-moves-past-table ()
  "Meta arrow commands should leave directly in either direction."
  (emacspeak-agent-shell-test--with-rendered-table
      "before\n| A | B |\n|---|---|\n| 1 | 2 |\nafter\n"
    (goto-char (point-min))
    (search-forward "1")
    (backward-char)
    (should
     (equal
      (emacspeak-agent-shell-test--capture-events
        (call-interactively #'emacspeak-agent-shell-table-exit-forward))
      '((icon close-object) (speak "After table. after"))))
    (search-backward "B")
    (should
     (equal
      (emacspeak-agent-shell-test--capture-events
        (call-interactively #'emacspeak-agent-shell-table-exit-backward))
      '((icon close-object) (speak "Before table. before"))))))

(ert-deftest emacspeak-agent-shell-table-navigation-is-contextual ()
  "Ordinary cursor entry should announce and activate table-only keys."
  (let ((emacspeak-agent-shell-table-titles '(column row))
        (emacspeak-agent-shell-table-data-position 'first))
    (emacspeak-agent-shell-test--with-rendered-table
        "before\n| Name | Role |\n|---|---|\n| Alice | Engineer |\nafter\n"
      (goto-char (point-min))
      (emacspeak-agent-shell--table-navigation-setup)
      (should-not emacspeak-agent-shell--table-navigation-active)
      (emacspeak-agent-shell--table-navigation-pre-command)
      (search-forward "Engineer")
      (backward-char (length "Engineer"))
      (should
       (equal
        (emacspeak-agent-shell-test--capture-events
          (emacspeak-agent-shell--table-navigation-post-command))
        '((stop nil)
          (icon open-object)
          (speak
           "Table, 1 data row, 2 columns. Engineer, Alice, Role."))))
      (should emacspeak-agent-shell--table-navigation-active)
      (should
       (eq (key-binding (kbd "<right>"))
           #'emacspeak-agent-shell-table-next-column))
      (dolist
          (binding
           `(("r" . ,#'emacspeak-agent-shell-table-speak-row)
             ("c" . ,#'emacspeak-agent-shell-table-speak-column)
             ("SPC" . ,#'emacspeak-agent-shell-table-speak-cell)
             ("." . ,#'emacspeak-agent-shell-table-speak-context)
             ("=" . ,#'emacspeak-agent-shell-table-speak-dimensions)
             ("w" . ,#'emacspeak-agent-shell-table-copy-cell)
             ("a" . ,#'emacspeak-agent-shell-table-select-speaking-method)
             ("M-<up>" . ,#'emacspeak-agent-shell-table-exit-backward)
             ("M-<down>" . ,#'emacspeak-agent-shell-table-exit-forward)))
        (should
         (eq (lookup-key emacspeak-agent-shell--table-navigation-map
                         (kbd (car binding)))
             (cdr binding))))
      (goto-char (point-max))
      (emacspeak-agent-shell--table-navigation-post-command)
      (should-not emacspeak-agent-shell--table-navigation-active)
      (emacspeak-agent-shell--table-navigation-cleanup)
      (should-not
       (memq #'emacspeak-agent-shell--table-navigation-post-command
             post-command-hook)))))

(ert-deftest emacspeak-agent-shell-table-feedback-handles-title-cells-and-blanks ()
  "Table feedback should avoid duplicate titles and name blank data."
  (let ((emacspeak-agent-shell-table-titles '(column row))
        (emacspeak-agent-shell-table-data-position 'first))
    (emacspeak-agent-shell-test--with-rendered-table
        "| Name | Role |\n|---|---|\n| Alice |  |\n"
      (goto-char (point-min))
      (search-forward "Role")
      (backward-char (length "Role"))
      (should
       (equal
        (emacspeak-agent-shell-test--capture-events
          (emacspeak-agent-shell--table-cell-feedback))
        '((icon item) (speak "Role."))))
      (search-forward "Alice")
      (backward-char (length "Alice"))
      (should
       (equal
        (emacspeak-agent-shell-test--capture-events
          (emacspeak-agent-shell--table-cell-feedback))
        '((icon item) (speak "Alice, Name."))))
      (agent-shell-markdown-table-next-cell)
      (should
       (equal
        (emacspeak-agent-shell-test--capture-events
          (emacspeak-agent-shell--table-cell-feedback))
        '((icon item) (speak "blank, Alice, Role.")))))))

(ert-deftest emacspeak-agent-shell-table-feedback-preserves-logical-cells ()
  "Table feedback should speak wrapped cells and protected pipes in full."
  (let ((emacspeak-agent-shell-table-titles '(column row))
        (emacspeak-agent-shell-table-data-position 'first)
        (agent-shell-markdown-table-max-width-fraction 1.0))
    (cl-letf (((symbol-function 'agent-shell-markdown--display-width)
               (lambda () 35)))
      (emacspeak-agent-shell-test--with-rendered-table
          (concat "| Code | Notes |\n"
                  "|---|---|\n"
                  "| `a|b` | owns a long wrapped description |\n")
        (goto-char (point-min))
        (search-forward "owns a long")
        (backward-char (length "owns a long"))
        (should
         (equal
          (emacspeak-agent-shell-test--capture-events
            (emacspeak-agent-shell--table-cell-feedback))
          '((icon item)
            (speak
             "owns a long wrapped description, a|b, Notes."))))))))

(ert-deftest emacspeak-agent-shell-table-feedback-respects-headerless-tables ()
  "A table without a separator should not invent column titles."
  (let ((emacspeak-agent-shell-table-titles '(column row))
        (emacspeak-agent-shell-table-data-position 'first))
    (emacspeak-agent-shell-test--with-rendered-table
        "| hello | world |\n| goodbye | moon |\n"
      (goto-char (point-min))
      (search-forward "world")
      (backward-char (length "world"))
      (should
       (equal
        (emacspeak-agent-shell-test--capture-events
          (emacspeak-agent-shell--table-cell-feedback))
        '((icon item) (speak "world, hello.")))))))

(ert-deftest emacspeak-agent-shell-table-navigation-speaks-in-both-views ()
  "Shell and viewport table traversal should share semantic feedback."
  (let ((emacspeak-agent-shell-table-titles '(column))
        (emacspeak-agent-shell-table-data-position 'first))
    (emacspeak-agent-shell-test--with-rendered-table
        "before\n| A | B |\n|---|---|\n| 1 | 2 |\nafter\n"
      (goto-char (point-min))
      (goto-char
       (next-single-property-change
        (point) 'agent-shell-markdown-table-source nil (point-max)))
      (search-forward "B")
      (backward-char)
      (setq major-mode 'agent-shell-mode)
      (cl-letf (((symbol-function 'shell-maker-busy) (lambda () t)))
        (should
         (equal
          (emacspeak-agent-shell-test--capture-events
            (call-interactively #'agent-shell-next-item))
          '((icon item) (speak "1, A.")))))
      (search-forward "2")
      (backward-char)
      (setq major-mode 'agent-shell-viewport-view-mode)
      (should
       (equal
        (emacspeak-agent-shell-test--capture-events
          (call-interactively #'agent-shell-viewport-previous-item))
        '((icon item) (speak "1, A."))))
      (search-forward "2")
      (backward-char)
      (should
       (equal
        (emacspeak-agent-shell-test--capture-events
          (call-interactively #'agent-shell-viewport-next-item))
        '((icon close-object) (speak "After table. after")))))))

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
  (should-not
   (seq-remove (lambda (entry) (fboundp (car entry)))
               emacspeak-agent-shell--advice-list)))

(ert-deftest emacspeak-agent-shell-viewport-submit-announces-success ()
  "A successful interactive viewport submission should be confirmed."
  (let ((agent-shell-prefer-viewport-interaction t)
        (agent-shell-session-strategy 'new-deferred)
        sent)
    (with-temp-buffer
      (setq major-mode 'agent-shell-viewport-edit-mode)
      (cl-letf (((symbol-function
                  'agent-shell-viewport-compose-send-and-wait-for-response)
                 (lambda () (setq sent t))))
        (should
         (equal
          (emacspeak-agent-shell-test--capture-events
            (call-interactively #'agent-shell-viewport-compose-send))
          '((icon close-object)
            (speak "Prompt submitted."))))
        (should sent)))))

(ert-deftest emacspeak-agent-shell-viewport-submit-does-not-confirm-error ()
  "A failed viewport submission should not produce a success cue."
  (let ((agent-shell-prefer-viewport-interaction t)
        (agent-shell-session-strategy 'new-deferred))
    (with-temp-buffer
      (setq major-mode 'agent-shell-viewport-edit-mode)
      (cl-letf (((symbol-function
                  'agent-shell-viewport-compose-send-and-wait-for-response)
                 (lambda () (user-error "Nothing to send"))))
        (should-not
         (emacspeak-agent-shell-test--capture-events
           (should-error
            (call-interactively #'agent-shell-viewport-compose-send)
            :type 'user-error)))))))

(ert-deftest emacspeak-agent-shell-viewport-cancel-announces-accepted-only ()
  "Viewport cancellation should distinguish acceptance from declining it."
  (let ((shell-buffer (generate-new-buffer " *agent-shell-shell-test*"))
        (agent-shell-prefer-viewport-interaction t))
    (unwind-protect
        (with-temp-buffer
          (insert "draft prompt")
          (setq major-mode 'agent-shell-viewport-edit-mode)
          (cl-letf (((symbol-function 'agent-shell-viewport--ensure-buffer)
                     #'ignore)
                    ((symbol-function 'agent-shell-viewport--shell-buffer)
                     (lambda () shell-buffer))
                    ((symbol-function 'shell-maker-history-position)
                     (lambda () t))
                    ((symbol-function 'agent-shell-viewport-view-last)
                     (lambda ()
                       (setq major-mode 'agent-shell-viewport-view-mode)))
                    ((symbol-function 'y-or-n-p) (lambda (&rest _) t)))
            (should
             (equal
              (emacspeak-agent-shell-test--capture-events
                (call-interactively #'agent-shell-viewport-compose-cancel))
              '((icon close-object)
                (speak "Prompt composition cancelled."))))
            (should (eq major-mode 'agent-shell-viewport-view-mode)))
          (setq major-mode 'agent-shell-viewport-edit-mode)
          (cl-letf (((symbol-function 'agent-shell-viewport--ensure-buffer)
                     #'ignore)
                    ((symbol-function 'agent-shell-viewport--shell-buffer)
                     (lambda () shell-buffer))
                    ((symbol-function 'shell-maker-history-position)
                     (lambda () t))
                    ((symbol-function 'y-or-n-p) (lambda (&rest _) nil)))
            (should-not
             (emacspeak-agent-shell-test--capture-events
               (call-interactively #'agent-shell-viewport-compose-cancel)))
            (should (eq major-mode 'agent-shell-viewport-edit-mode))))
      (when (buffer-live-p shell-buffer)
        (kill-buffer shell-buffer)))))

(ert-deftest emacspeak-agent-shell-configured-faces-exist ()
  "Every agent-shell face named by this integration should exist."
  :expected-result :failed
  (should (facep 'agent-shell-mode-line)))

(ert-deftest emacspeak-agent-shell-disable-cleans-existing-buffer-state ()
  "Disabling support should cancel pending work in existing shell buffers."
  (let ((buffer (generate-new-buffer " *agent-shell-cleanup-test*"))
        (saved-hook agent-shell-mode-hook)
        (saved-advice (emacspeak-agent-shell-test--saved-advice-state))
        state timer fired)
    (unwind-protect
        (progn
          (with-current-buffer buffer
            (setq major-mode 'agent-shell-mode)
            (setq state
                  (list (cons :buffer buffer)
                        (cons :event-subscriptions nil)))
            (setq-local agent-shell--state state)
            (setq-local emacspeak-agent-shell--pending-bodies
                        (make-hash-table :test #'equal))
            (puthash "request-agent_message_chunk" "pending"
                     emacspeak-agent-shell--pending-bodies)
            (setq-local emacspeak-agent-shell--pending-speech-qualified-ids
                        '("request-agent_message_chunk"))
            (setq-local emacspeak-agent-shell--permission-action-cache
                        (make-hash-table :test #'equal))
            (puthash "permission" '((:option . "Allow"))
                     emacspeak-agent-shell--permission-action-cache)
            (setq-local emacspeak-agent-shell--tool-call-status-cache
                        (make-hash-table :test #'equal))
            (puthash "tool" "in_progress"
                     emacspeak-agent-shell--tool-call-status-cache)
            (setq timer (run-with-timer 0.1 nil
                                        (lambda () (setq fired t))))
            (setq-local emacspeak-agent-shell--pending-speech-timer timer))
          (emacspeak-agent-shell-enable)
          (with-current-buffer buffer
            (should (= 4 (length (map-elt
                                  agent-shell--state
                                  :event-subscriptions))))
            (should (memq #'emacspeak-agent-shell--buffer-cleanup
                          kill-buffer-hook))
            (should (memq #'emacspeak-agent-shell--buffer-cleanup
                          change-major-mode-hook))
            (should
             (memq #'emacspeak-agent-shell--table-navigation-post-command
                   post-command-hook)))
          (emacspeak-agent-shell-disable)
          (emacspeak-agent-shell-disable)
          (sit-for 0.15)
          (should-not fired)
          (with-current-buffer buffer
            (should-not emacspeak-agent-shell--pending-speech-timer)
            (should-not emacspeak-agent-shell--pending-speech-qualified-ids)
            (should-not emacspeak-agent-shell--pending-bodies)
            (should-not emacspeak-agent-shell--permission-subscription)
            (should-not
             emacspeak-agent-shell--permission-response-subscription)
            (should-not emacspeak-agent-shell--permission-action-cache)
            (should-not emacspeak-agent-shell--lifecycle-subscription)
            (should-not emacspeak-agent-shell--tool-call-subscription)
            (should-not emacspeak-agent-shell--tool-call-status-cache)
            (should-not (map-elt agent-shell--state
                                 :event-subscriptions))
            (should-not (memq #'emacspeak-agent-shell--buffer-cleanup
                              kill-buffer-hook))
            (should-not (memq #'emacspeak-agent-shell--buffer-cleanup
                              change-major-mode-hook))
            (should-not
             (memq #'emacspeak-agent-shell--table-navigation-post-command
                   post-command-hook))))
      (when (timerp timer)
        (cancel-timer timer))
      (when (buffer-live-p buffer)
        (kill-buffer buffer))
      (setq agent-shell-mode-hook saved-hook)
      (emacspeak-agent-shell-test--restore-advice-state saved-advice))))

(ert-deftest emacspeak-agent-shell-mode-change-cleans-buffer-state ()
  "Changing major mode should cancel timers and remove subscriptions."
  (let ((buffer (generate-new-buffer " *agent-shell-mode-cleanup-test*"))
        state timer fired)
    (unwind-protect
        (progn
          (with-current-buffer buffer
            (setq major-mode 'agent-shell-mode)
            (setq state
                  (list (cons :buffer buffer)
                        (cons :event-subscriptions nil)))
            (setq-local agent-shell--state state)
            (emacspeak-agent-shell--buffer-setup)
            (setq timer (run-with-timer 0.1 nil
                                        (lambda () (setq fired t))))
            (setq-local emacspeak-agent-shell--pending-speech-timer timer
                        emacspeak-agent-shell--pending-speech-qualified-ids
                        '("pending"))
            (setq-local emacspeak-agent-shell--pending-bodies
                        (make-hash-table :test #'equal))
            (puthash "pending" "text"
                     emacspeak-agent-shell--pending-bodies)
            (fundamental-mode))
          (sit-for 0.15)
          (should-not fired)
          (should-not (map-elt state :event-subscriptions))
          (with-current-buffer buffer
            (should-not emacspeak-agent-shell--pending-speech-timer)
            (should-not emacspeak-agent-shell--pending-speech-qualified-ids)
            (should-not emacspeak-agent-shell--pending-bodies)))
      (when (timerp timer)
        (cancel-timer timer))
      (when (buffer-live-p buffer)
        (kill-buffer buffer)))))

(ert-deftest emacspeak-agent-shell-buffer-death-cleans-buffer-state ()
  "Killing a shell buffer should cancel speech and unsubscribe its events."
  (let ((buffer (generate-new-buffer " *agent-shell-kill-cleanup-test*"))
        state timer fired)
    (unwind-protect
        (progn
          (with-current-buffer buffer
            (setq major-mode 'agent-shell-mode)
            (setq state
                  (list (cons :buffer buffer)
                        (cons :event-subscriptions nil)))
            (setq-local agent-shell--state state)
            (emacspeak-agent-shell--buffer-setup)
            (setq timer (run-with-timer 0.1 nil
                                        (lambda () (setq fired t))))
            (setq-local emacspeak-agent-shell--pending-speech-timer timer))
          (kill-buffer buffer)
          (sit-for 0.15)
          (should-not fired)
          (should-not (map-elt state :event-subscriptions)))
      (when (timerp timer)
        (cancel-timer timer))
      (when (buffer-live-p buffer)
        (kill-buffer buffer)))))

(provide 'emacspeak-agent-shell-tests)
;;; emacspeak-agent-shell-tests.el ends here
