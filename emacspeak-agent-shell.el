;;; emacspeak-agent-shell.el --- Speech-enable AGENT-SHELL  -*- lexical-binding: t; -*-
;; $Author: T. V. Raman $
;; Description:  Speech-enable AGENT-SHELL - Native agentic integrations
;; Keywords: Emacspeak,  Audio Desktop agent-shell
;;;   LCD Archive entry:

;; LCD Archive Entry:
;; emacspeak| T. V. Raman |raman@cs.cornell.edu
;; A speech interface to Emacs |
;; 
;;  $Revision: 1.0 $ |
;; Location https://github.com/tvraman/emacspeak
;; 

;;;   Copyright:

;; Copyright (C) 2025, T. V. Raman
;; All Rights Reserved.
;; 
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

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;; Commentary:
;; 
;; agent-shell provides native agentic integrations for AI agents
;; like Claude Code, Gemini CLI, Goose, Cursor, and others.
;; It is built on shell-maker and provides a comint-based interface.
;;
;; This module speech-enables agent-shell, providing:
;; - Automatic speaking of agent responses
;; - Auditory feedback for tool calls and permissions
;; - Smart filtering of chunked output
;; - Navigation support
;; - Viewport mode integration
;;
;; See https://github.com/xenodium/agent-shell for more information.

;;; Code:

;;   Required modules:

(eval-when-compile (require 'cl-lib))
(cl-declaim  (optimize  (safety 0) (speed 3)))
(require 'emacspeak-preamble)
(require 'agent-shell)
(require 'shell-maker)

;;;  Customization

(defgroup emacspeak-agent-shell nil
  "Speech-enable agent-shell for Emacspeak."
  :group 'emacspeak
  :prefix "emacspeak-agent-shell-")



(defcustom emacspeak-agent-shell-speak-thought-process 'icon
  "How to handle agent thought process chunks.
- \\='speak: Speak the thought process content
- \\='icon: Play an auditory icon only (default)
- nil: Silent, no feedback"
  :type '(choice (const :tag "Speak content" speak)
                 (const :tag "Icon only" icon)
                 (const :tag "Silent" nil))
  :group 'emacspeak-agent-shell)

(defcustom emacspeak-agent-shell-tool-output-verbosity 'summary
  "Verbosity level for tool call output.
- \\='full: Speak the complete tool output
- \\='summary: Speak a summary (status and title)
- \\='status: Only speak the final status"
  :type '(choice (const :tag "Full output" full)
                 (const :tag "Summary" summary)
                 (const :tag "Status only" status))
  :group 'emacspeak-agent-shell)

(defcustom emacspeak-agent-shell-speak-permissions t
  "Whether to speak permission requests immediately.
When t, permission requests are spoken as soon as they appear."
  :type 'boolean
  :group 'emacspeak-agent-shell)

(defcustom emacspeak-agent-shell-speak-tool-calls t
  "Whether to announce tool calls as they happen."
  :type 'boolean
  :group 'emacspeak-agent-shell)

(defcustom emacspeak-agent-shell-signal-processing t
  "Whether to announce the agent's processing lifecycle.
When non-nil, public agent-shell events produce start and completion
icons.  Exceptional completion and error events also produce a brief
spoken explanation.  Initialization has its own start and completion
cues."
  :type 'boolean
  :group 'emacspeak-agent-shell)

(defcustom emacspeak-agent-shell-processing-start-icon 'progress
  "Auditory icon played when the model starts processing a prompt."
  :type 'symbol
  :group 'emacspeak-agent-shell)

(defcustom emacspeak-agent-shell-processing-end-icon 'task-done
  "Auditory icon played when the model finishes processing."
  :type 'symbol
  :group 'emacspeak-agent-shell)

(defcustom emacspeak-agent-shell-table-titles '(column)
  "Table titles spoken with the current Markdown table cell.
Column titles come from the first row when the Markdown source has a
separator row.  Row titles come from the first column, following
Emacspeak's table convention.  Customize this set to enable either,
both, or neither kind of title."
  :type '(set (const :tag "Column titles" column)
              (const :tag "Row titles" row))
  :group 'emacspeak-agent-shell)

(defcustom emacspeak-agent-shell-table-data-position 'first
  "Whether table cell data is spoken before or after its titles."
  :type '(choice (const :tag "Data before titles" first)
                 (const :tag "Titles before data" last))
  :group 'emacspeak-agent-shell)

;;;  Speech Setup

;;;###autoload
(defun emacspeak-agent-shell-speech-setup ()
  "Speech setup for agent-shell."
  (cl-declare (special
               emacspeak-speak-time-brief-format
               agent-shell-mode-map
               emacspeak-pronounce-sha-checksum-pattern
               emacspeak-pronounce-date-mm-dd-yyyy-pattern
               emacspeak-pronounce-date-yyyy-mm-dd-pattern
               emacspeak-pronounce-rfc-3339-datetime-pattern
               header-line-format emacspeak-use-header-line
               emacspeak-comint-autospeak))
  (setq buffer-undo-list t)
  ;; Enable autospeak by default for agent-shell buffers
  (unless (local-variable-p 'emacspeak-comint-autospeak)
    (setq-local emacspeak-comint-autospeak t))
  (when emacspeak-use-header-line
    (setq
     header-line-format
     '((:eval
        (concat
         (format-time-string emacspeak-speak-time-brief-format)
         (propertize (buffer-name) 'personality voice-annotate)
         (abbreviate-file-name default-directory)
         (when emacspeak-comint-autospeak
           (propertize "Autospeak" 'personality voice-lighten))
         (when (> (length (window-list)) 1)
           (format "%s" (length (window-list)))))))))
  (dtk-set-punctuations 'all)
  (emacspeak-pronounce-add-dictionary-entry
   'agent-shell-mode
   emacspeak-pronounce-uuid-pattern
   (cons 're-search-forward
         'emacspeak-pronounce-uuid))
  (emacspeak-pronounce-add-dictionary-entry
   'agent-shell-mode
   emacspeak-pronounce-sha-checksum-pattern
   (cons 're-search-forward
         'emacspeak-pronounce-sha-checksum))
  (emacspeak-pronounce-add-dictionary-entry
   'agent-shell-mode
   emacspeak-pronounce-date-mm-dd-yyyy-pattern
   (cons 're-search-forward
         'emacspeak-pronounce-mm-dd-yyyy-date))
  (emacspeak-pronounce-add-dictionary-entry
   'agent-shell-mode
   emacspeak-pronounce-date-yyyy-mm-dd-pattern
   (cons 're-search-forward
         'emacspeak-pronounce-yyyy-mm-dd-date))
  (emacspeak-pronounce-add-dictionary-entry
   'agent-shell-mode
   emacspeak-pronounce-rfc-3339-datetime-pattern
   (cons 're-search-forward
         'emacspeak-pronounce-decode-rfc-3339-datetime))
  (emacspeak-pronounce-refresh-pronunciations))

;;;  Voice Personalities

(voice-setup-add-map 
 '(
   (agent-shell-mode-line voice-bolden-and-animate)))

;;;  Helper Functions

(defvar emacspeak-agent-shell--pending-speech-timer nil
  "Timer for delayed speech after streaming completes.")

(make-variable-buffer-local 'emacspeak-agent-shell--pending-speech-timer)

(defvar emacspeak-agent-shell--pending-speech-qualified-ids nil
  "List of qualified-ids for blocks pending speech, in arrival order.")

(make-variable-buffer-local 'emacspeak-agent-shell--pending-speech-qualified-ids)

(defvar emacspeak-agent-shell--pending-bodies nil
  "Hash table mapping qualified-id to accumulated body text.
Populated as streaming chunks arrive; consumed when the speech timer fires.")

(make-variable-buffer-local 'emacspeak-agent-shell--pending-bodies)

(defvar-local emacspeak-agent-shell--permission-subscription nil
  "Subscription token for permission request events in this shell.")

(defvar-local emacspeak-agent-shell--permission-response-subscription nil
  "Subscription token for permission response events in this shell.")

(defvar-local emacspeak-agent-shell--permission-action-cache nil
  "Hash table mapping pending permission requests to normalized actions.")

(defvar-local emacspeak-agent-shell--lifecycle-subscription nil
  "Subscription token for lifecycle events in this shell.")

(defvar-local emacspeak-agent-shell--tool-call-subscription nil
  "Subscription token for tool call update events in this shell.")

(defvar-local emacspeak-agent-shell--tool-call-status-cache nil
  "Hash table mapping tool call IDs to their last announced status.")

(defcustom emacspeak-agent-shell-speech-delay 0.5
  "Delay in seconds before speaking completed streaming content.
When agent output streams in chunks, wait this long after the last
chunk arrives before speaking the complete text."
  :type 'number
  :group 'emacspeak-agent-shell)

(defun emacspeak-agent-shell--should-speak-p (buffer)
  "Determine if content should be spoken for BUFFER."
  (cl-declare (special emacspeak-comint-autospeak))
  (with-current-buffer buffer
    emacspeak-comint-autospeak))

(defun emacspeak-agent-shell--cancel-pending-speech ()
  "Cancel and discard delayed speech pending in the current shell."
  (when (timerp emacspeak-agent-shell--pending-speech-timer)
    (cancel-timer emacspeak-agent-shell--pending-speech-timer))
  (setq emacspeak-agent-shell--pending-speech-timer nil
        emacspeak-agent-shell--pending-speech-qualified-ids nil)
  (when (hash-table-p emacspeak-agent-shell--pending-bodies)
    (clrhash emacspeak-agent-shell--pending-bodies)))

(defun emacspeak-agent-shell--permission-announcement (event)
  "Return a semantic announcement for permission request EVENT."
  (let* ((data (map-elt event :data))
         (tool-call (map-elt data :tool-call))
         (tool-call-id (map-elt data :tool-call-id))
         (title (map-elt tool-call :title))
         (description
          (cond
           ((and (stringp title) (not (string-empty-p title)))
            (substring-no-properties title))
           ((and (stringp tool-call-id)
                 (not (string-empty-p tool-call-id)))
            (format "Tool %s" tool-call-id))
           (t "Unknown tool")))
         (choices
          (cl-loop
           for action in (append (map-elt tool-call :permission-actions) nil)
           for option = (map-elt action :option)
           when (and (stringp option) (not (string-empty-p option)))
           collect (substring-no-properties option))))
    (concat
     (format "Permission request. %s." description)
     (when choices
       (concat
        " "
        (mapconcat
         #'identity
         (cl-loop
          for choice in choices
          for index from 1
          collect (format "Choice %d: %s." index choice))
         " "))))))

(defun emacspeak-agent-shell--handle-permission-request (event)
  "Interrupt current speech and announce permission request EVENT."
  (let* ((data (map-elt event :data))
         (key (or (map-elt data :request-id)
                  (map-elt data :tool-call-id)))
         (actions (map-nested-elt event '(:data :tool-call
                                                :permission-actions))))
    (when key
      (unless (hash-table-p emacspeak-agent-shell--permission-action-cache)
        (setq emacspeak-agent-shell--permission-action-cache
              (make-hash-table :test #'equal)))
      (puthash key actions emacspeak-agent-shell--permission-action-cache)))
  ;; The private fragment advice has already seen the visual permission
  ;; block.  Discard that delayed copy to avoid a duplicate announcement.
  (emacspeak-agent-shell--cancel-pending-speech)
  (when emacspeak-agent-shell-speak-permissions
    (dtk-stop)
    (emacspeak-icon 'warn-user)
    (dtk-speak (emacspeak-agent-shell--permission-announcement event))))

(defun emacspeak-agent-shell--handle-permission-response (event)
  "Announce the semantic result of permission response EVENT."
  (let* ((data (map-elt event :data))
         (key (or (map-elt data :request-id)
                  (map-elt data :tool-call-id)))
         (option-id (map-elt data :option-id))
         (cancelled (map-elt data :cancelled))
         (actions (and key
                       (hash-table-p
                        emacspeak-agent-shell--permission-action-cache)
                       (gethash key
                                emacspeak-agent-shell--permission-action-cache)))
         (action (seq-find
                  (lambda (candidate)
                    (equal option-id (map-elt candidate :option-id)))
                  actions))
         (option (map-elt action :option))
         (kind (map-elt action :kind)))
    (when (and key
               (hash-table-p emacspeak-agent-shell--permission-action-cache))
      (remhash key emacspeak-agent-shell--permission-action-cache))
    (when emacspeak-agent-shell-speak-permissions
      (cond
       (cancelled
        (emacspeak-icon 'close-object)
        (dtk-speak "Permission cancelled."))
       ((equal kind "reject_once")
        (emacspeak-icon 'close-object)
        (dtk-speak (format "Permission denied: %s."
                           (or option "Reject"))))
       ((member kind '("allow_once" "allow_always"))
        (emacspeak-icon 'select-object)
        (dtk-speak (format "Permission granted: %s."
                           (or option "Allow"))))
       (t
        (emacspeak-icon 'select-object)
        (dtk-speak "Permission response sent."))))))

(defun emacspeak-agent-shell--permission-event-setup ()
  "Subscribe the current agent-shell buffer to permission events."
  (unless emacspeak-agent-shell--permission-subscription
    (setq emacspeak-agent-shell--permission-subscription
          (agent-shell-subscribe-to
           :shell-buffer (current-buffer)
           :event 'permission-request
           :on-event #'emacspeak-agent-shell--handle-permission-request)))
  (unless emacspeak-agent-shell--permission-response-subscription
    (setq emacspeak-agent-shell--permission-response-subscription
          (agent-shell-subscribe-to
           :shell-buffer (current-buffer)
           :event 'permission-response
           :on-event #'emacspeak-agent-shell--handle-permission-response))))

(defun emacspeak-agent-shell--permission-event-cleanup ()
  "Remove the current buffer's permission subscriptions and cached state."
  (when emacspeak-agent-shell--permission-subscription
    (agent-shell-unsubscribe
     :subscription emacspeak-agent-shell--permission-subscription)
    (setq emacspeak-agent-shell--permission-subscription nil))
  (when emacspeak-agent-shell--permission-response-subscription
    (agent-shell-unsubscribe
     :subscription emacspeak-agent-shell--permission-response-subscription)
    (setq emacspeak-agent-shell--permission-response-subscription nil))
  (when (hash-table-p emacspeak-agent-shell--permission-action-cache)
    (clrhash emacspeak-agent-shell--permission-action-cache))
  (setq emacspeak-agent-shell--permission-action-cache nil)
  (remove-hook 'kill-buffer-hook
               #'emacspeak-agent-shell--permission-event-cleanup t)
  (remove-hook 'change-major-mode-hook
               #'emacspeak-agent-shell--permission-event-cleanup t))

(defun emacspeak-agent-shell--discard-pending-blocks (regexp)
  "Discard delayed speech whose qualified block ID matches REGEXP.
Leave unrelated pending agent content and its timer intact."
  (when (hash-table-p emacspeak-agent-shell--pending-bodies)
    (dolist (qualified-id emacspeak-agent-shell--pending-speech-qualified-ids)
      (when (string-match-p regexp qualified-id)
        (remhash qualified-id emacspeak-agent-shell--pending-bodies)))
    (setq emacspeak-agent-shell--pending-speech-qualified-ids
          (seq-remove
           (lambda (qualified-id) (string-match-p regexp qualified-id))
           emacspeak-agent-shell--pending-speech-qualified-ids))
    (when (and (null emacspeak-agent-shell--pending-speech-qualified-ids)
               (timerp emacspeak-agent-shell--pending-speech-timer))
      (cancel-timer emacspeak-agent-shell--pending-speech-timer)
      (setq emacspeak-agent-shell--pending-speech-timer nil))))

(defun emacspeak-agent-shell--speak-agent-error (event)
  "Announce the ACP error described by lifecycle EVENT."
  (emacspeak-agent-shell--discard-pending-blocks
   "-\\(?:failed-\\|Error\\(?:-\\|$\\)\\)")
  (let* ((data (map-elt event :data))
         (message (map-elt data :message))
         (code (map-elt data :code))
         (detail
          (cond
           ((and (stringp message) (not (string-empty-p (string-trim message))))
            (string-trim (substring-no-properties message)))
           (code (format "code %s" code))
           (t nil))))
    (emacspeak-icon 'warn-user)
    (dtk-speak (if detail
                   (format "Agent error: %s" detail)
                 "Agent error."))))

(defun emacspeak-agent-shell--speak-turn-completion (event)
  "Announce the outcome described by turn completion EVENT."
  (let ((stop-reason (map-nested-elt event '(:data :stop-reason))))
    (if (equal stop-reason "end_turn")
        (emacspeak-icon emacspeak-agent-shell-processing-end-icon)
      (emacspeak-agent-shell--discard-pending-blocks "-stop-reason$")
      (pcase stop-reason
        ("cancelled"
         (emacspeak-icon 'close-object)
         (dtk-speak "Agent turn cancelled."))
        ("max_tokens"
         (emacspeak-icon 'warn-user)
         (dtk-speak "Agent stopped: maximum token limit reached."))
        ("max_turn_requests"
         (emacspeak-icon 'warn-user)
         (dtk-speak "Agent stopped: request limit reached."))
        ("refusal"
         (emacspeak-icon 'warn-user)
         (dtk-speak "Agent refused the request."))
        ((pred stringp)
         (emacspeak-icon 'warn-user)
         (dtk-speak
          (format "Agent stopped: %s."
                  (string-replace "_" " " stop-reason))))
        (_
         (emacspeak-icon 'warn-user)
         (dtk-speak "Agent stopped for an unknown reason."))))))

(defun emacspeak-agent-shell--handle-lifecycle-event (event)
  "Provide semantic processing feedback for public agent-shell EVENT."
  (when (and (memq (map-elt event :event) '(turn-complete error))
             (hash-table-p emacspeak-agent-shell--tool-call-status-cache))
    (clrhash emacspeak-agent-shell--tool-call-status-cache))
  (when emacspeak-agent-shell-signal-processing
    (pcase (map-elt event :event)
      ((or 'init-started 'input-submitted)
       (emacspeak-icon emacspeak-agent-shell-processing-start-icon))
      ('init-finished
       (emacspeak-icon emacspeak-agent-shell-processing-end-icon))
      ('turn-complete
       (emacspeak-agent-shell--speak-turn-completion event))
      ('error
       (emacspeak-agent-shell--speak-agent-error event)))))

(defun emacspeak-agent-shell--lifecycle-event-setup ()
  "Subscribe the current agent-shell buffer to lifecycle events."
  (unless emacspeak-agent-shell--lifecycle-subscription
    (setq emacspeak-agent-shell--lifecycle-subscription
          (agent-shell-subscribe-to
           :shell-buffer (current-buffer)
           :on-event #'emacspeak-agent-shell--handle-lifecycle-event))))

(defun emacspeak-agent-shell--lifecycle-event-cleanup ()
  "Remove the current buffer's lifecycle event subscription."
  (when emacspeak-agent-shell--lifecycle-subscription
    (agent-shell-unsubscribe
     :subscription emacspeak-agent-shell--lifecycle-subscription)
    (setq emacspeak-agent-shell--lifecycle-subscription nil))
  (remove-hook 'kill-buffer-hook
               #'emacspeak-agent-shell--lifecycle-event-cleanup t)
  (remove-hook 'change-major-mode-hook
               #'emacspeak-agent-shell--lifecycle-event-cleanup t))

(defun emacspeak-agent-shell--tool-call-block-handled-p (block-id)
  "Return non-nil when tool BLOCK-ID has public event feedback."
  (when (and (stringp block-id)
             (hash-table-p emacspeak-agent-shell--tool-call-status-cache))
    (member (gethash block-id emacspeak-agent-shell--tool-call-status-cache)
            '("pending" "in_progress" "completed" "failed"))))

(defun emacspeak-agent-shell--execute-delayed-speech (buffer qualified-ids)
  "Execute delayed speech of blocks identified by QUALIFIED-IDS in BUFFER.
This is called after streaming has completed."
  (cl-declare (special dtk-speaker-process))
  (when (and buffer (buffer-live-p buffer))
    (with-current-buffer buffer
      (dolist (qualified-id qualified-ids)
        (when-let* ((content (and emacspeak-agent-shell--pending-bodies
                                  (gethash qualified-id
                                           emacspeak-agent-shell--pending-bodies)))
                    (block-id (if (string-match "-\\([^-]+\\)$" qualified-id)
                                  (match-string 1 qualified-id)
                                qualified-id))
                    (block-type (emacspeak-agent-shell--classify-block block-id))
                    (trimmed (string-trim content)))
          (when (not (string-empty-p trimmed))
            (emacspeak-agent-shell--speak-content trimmed block-type))))
      (when emacspeak-agent-shell--pending-bodies
        (clrhash emacspeak-agent-shell--pending-bodies))
      (setq emacspeak-agent-shell--pending-speech-qualified-ids nil)
      (setq emacspeak-agent-shell--pending-speech-timer nil))))

(defun emacspeak-agent-shell--classify-block (block-id)
  "Classify BLOCK-ID to determine content type.
Returns one of: \\='agent-message, \\='user-message, \\='thought, 
\\='tool-call, \\='permission, \\='plan, \\='error, or nil."
  (cond
   ((string-match-p "agent_message_chunk" block-id) 'agent-message)
   ((string-match-p "user_message_chunk" block-id) 'user-message)
   ((string-match-p "agent_thought_chunk" block-id) 'thought)
   ((string-match-p "^permission-" block-id) 'permission)
   ((string-equal block-id "plan") 'plan)
   ((string-match-p "^failed-\\|^Error" block-id) 'error)
   ((and (not (string-match-p "-chunk\\|^permission-\\|^plan\\|^Error\\|^failed-" block-id))
         (> (length block-id) 10)) 'tool-call)
   (t nil)))

(defun emacspeak-agent-shell--speak-content (content block-type)
  "Speak CONTENT based on BLOCK-TYPE with appropriate feedback."
  (cl-declare (special emacspeak-agent-shell-speak-thought-process
                       emacspeak-agent-shell-speak-tool-calls
                       emacspeak-agent-shell-speak-permissions
                       emacspeak-agent-shell-tool-output-verbosity))
  (let ((trimmed-content (string-trim content)))
    (pcase block-type
      ('agent-message
       (dtk-speak trimmed-content))
      ('user-message
       (emacspeak-icon 'item)
       (dtk-speak (concat "User: " trimmed-content)))
      ('thought
       (pcase emacspeak-agent-shell-speak-thought-process
         ('speak (dtk-speak (concat "Thinking: " trimmed-content)))
         ('icon (emacspeak-icon 'progress))
         (_ nil)))
      ('permission
       (when emacspeak-agent-shell-speak-permissions
         (emacspeak-icon 'warn-user)
         (dtk-speak trimmed-content)))
      ('tool-call
       (when emacspeak-agent-shell-speak-tool-calls
         (pcase emacspeak-agent-shell-tool-output-verbosity
           ('full (dtk-speak trimmed-content))
           ('summary 
            ;; Extract just the first few lines or a summary
            (let ((lines (split-string trimmed-content "\n" t)))
              (if (<= (length lines) 3)
                  (dtk-speak trimmed-content)
                (dtk-speak (string-join (seq-take lines 3) " ")))))
           ('status
            ;; Just play an icon for status-only mode
            (emacspeak-icon 'task-done)))))
      ('plan
       (emacspeak-icon 'item)
       (dtk-speak (concat "Plan: " trimmed-content)))
      ('error
       (emacspeak-icon 'warn-user)
       (dtk-speak trimmed-content))
      (_
       ;; Fallback: speak if content is substantial
       (when (> (length trimmed-content) 0)
         (dtk-speak trimmed-content))))))

;;;  Advice Agent-Shell Functions

(defadvice agent-shell (after emacspeak pre act comp)
  "Announce switching to agent-shell mode.
Provide an auditory icon if possible."
  (when (ems-interactive-p)
    (emacspeak-icon 'open-object)
    (dtk-set-punctuations 'all)
    (or dtk-split-caps
        (dtk-toggle-split-caps))
    (emacspeak-pronounce-refresh-pronunciations)
    (emacspeak-speak-mode-line)))

(defadvice agent-shell-start (after emacspeak pre act comp)
  "Announce agent shell startup."
  (when (ems-interactive-p)
    (emacspeak-icon 'open-object)
    (message "Agent shell started")))

(defadvice agent-shell-new-shell (after emacspeak pre act comp)
  "Announce new agent shell."
  (when (ems-interactive-p)
    (emacspeak-icon 'open-object)
    (message "New agent shell")))

(defadvice agent-shell-toggle (after emacspeak pre act comp)
  "Provide auditory feedback when toggling agent shell."
  (when (ems-interactive-p)
    (emacspeak-icon 'select-object)
    (emacspeak-speak-mode-line)))

(defadvice agent-shell-other-buffer (after emacspeak pre act comp)
  "Announce buffer switch."
  (when (ems-interactive-p)
    (emacspeak-icon 'select-object)
    (emacspeak-speak-mode-line)))

(defadvice agent-shell-interrupt (after emacspeak pre act comp)
  "Confirm interruption."
  (when (ems-interactive-p)
    (emacspeak-icon 'close-object)
    (message "Agent interrupted")))

;;;  Output Monitoring - Core Advice

(defadvice agent-shell--update-fragment (around emacspeak pre act comp)
  "Speak agent-shell content after streaming completes.
Instead of speaking each chunk as it arrives, accumulate all blocks
and speak them after streaming pauses for a brief period."
  (let* ((args (ad-get-args 0))
         (state (plist-get args :state))
         (block-id (plist-get args :block-id))
         (body (plist-get args :body))
         (create-new (plist-get args :create-new))
         (append-p (plist-get args :append))
         (buffer (map-elt state :buffer)))
    ;; Execute the original function
    ad-do-it
    ;; Handle speech with delayed approach
    (when (and buffer (buffer-live-p buffer) body
               (not (emacspeak-agent-shell--tool-call-block-handled-p
                     block-id))
               (emacspeak-agent-shell--should-speak-p buffer))
      (with-current-buffer buffer
        ;; Cancel any existing timer
        (when emacspeak-agent-shell--pending-speech-timer
          (cancel-timer emacspeak-agent-shell--pending-speech-timer))
        ;; Lazily create the per-buffer body store
        (unless emacspeak-agent-shell--pending-bodies
          (setq emacspeak-agent-shell--pending-bodies
                (make-hash-table :test 'equal)))
        ;; Build qualified-id (namespace-id + block-id) and accumulate body
        (let* ((namespace-id (map-elt state :request-count))
               (qualified-id (format "%s-%s" namespace-id block-id))
               (existing (gethash qualified-id
                                  emacspeak-agent-shell--pending-bodies)))
          (puthash qualified-id
                   (if (and append-p existing)
                       (concat existing body)
                     body)
                   emacspeak-agent-shell--pending-bodies)
          (unless (member qualified-id
                          emacspeak-agent-shell--pending-speech-qualified-ids)
            ;; Keep arrival order: append to end rather than push to head.
            (setq emacspeak-agent-shell--pending-speech-qualified-ids
                  (append emacspeak-agent-shell--pending-speech-qualified-ids
                          (list qualified-id)))))
        ;; Set a timer to speak after the delay
        (setq emacspeak-agent-shell--pending-speech-timer
              (run-with-timer
               emacspeak-agent-shell-speech-delay
               nil
               #'emacspeak-agent-shell--execute-delayed-speech
               buffer
               (copy-sequence emacspeak-agent-shell--pending-speech-qualified-ids))))))
  ad-return-value)

;;;  Navigation Commands

(defun emacspeak-agent-shell--markdown-table-separator-p (row)
  "Return non-nil if Markdown table ROW is a separator row."
  (string-match-p "\\`[ \t]*|[-:| \t]+|[ \t]*\\'" row))

(defun emacspeak-agent-shell--markdown-table-parse-row (row)
  "Return the logical cells parsed from Markdown table ROW.
Preserve cell text properties and ignore pipes protected by agent-shell's
Markdown renderer."
  (let ((length (length row))
        (position 0)
        cells
        ended-with-separator)
    (while (and (< position length)
                (memq (aref row position) '(?\s ?\t)))
      (setq position (1+ position)))
    (when (and (< position length) (eq (aref row position) ?|))
      (setq position (1+ position)))
    (let ((cell-start position))
      (while (< position length)
        (let ((character (aref row position)))
          (cond
           ((and (eq character ?|)
                 (not (get-text-property
                       position 'agent-shell-markdown-frozen row)))
            (push (string-trim (substring row cell-start position)) cells)
            (setq position (1+ position)
                  cell-start position
                  ended-with-separator t))
           ((eq character ?\\)
            (setq position (min length (+ position 2))
                  ended-with-separator nil))
           (t
            (unless (memq character '(?\s ?\t))
              (setq ended-with-separator nil))
            (setq position (1+ position))))))
      (unless ended-with-separator
        (push (string-trim (substring row cell-start length)) cells))
    (nreverse cells))))

(defun emacspeak-agent-shell--markdown-table-rows (source)
  "Parse Markdown table SOURCE into rows and separator metadata."
  (let (rows separator-p)
    (dolist (line (split-string source "\n"))
      (unless (string-empty-p (string-trim line))
        (if (emacspeak-agent-shell--markdown-table-separator-p line)
            (setq separator-p t)
          (push (emacspeak-agent-shell--markdown-table-parse-row line)
                rows))))
    (list :rows (nreverse rows) :column-titles-p separator-p)))

(defun emacspeak-agent-shell--markdown-table-region-at-point ()
  "Return the rendered Markdown table region at point, or nil."
  (when (get-text-property (point) 'agent-shell-markdown-table-source)
    (cons
     (or (previous-single-property-change
          (min (1+ (point)) (point-max))
          'agent-shell-markdown-table-source nil (point-min))
         (point-min))
     (or (next-single-property-change
          (point) 'agent-shell-markdown-table-source nil (point-max))
         (point-max)))))

(defun emacspeak-agent-shell--markdown-table-cell-starts (region)
  "Return navigable cell positions in rendered Markdown table REGION."
  (let (positions)
    (save-excursion
      (save-restriction
        (narrow-to-region (car region) (cdr region))
        (goto-char (point-min))
        (while-let ((match (text-property-search-forward
                            'agent-shell-markdown-table-cell-start t t)))
          (push (prop-match-beginning match) positions))))
    (nreverse positions)))

(defun emacspeak-agent-shell--markdown-table-cell-at-point ()
  "Return semantic Markdown table cell data for point, or nil."
  (when-let* ((source (get-text-property
                       (point) 'agent-shell-markdown-table-source))
              (region (emacspeak-agent-shell--markdown-table-region-at-point))
              (starts
               (emacspeak-agent-shell--markdown-table-cell-starts region)))
    (let ((cell-index -1)
          (index 0))
      (dolist (start starts)
        (when (<= start (point))
          (setq cell-index index))
        (setq index (1+ index)))
      (when (>= cell-index 0)
        (let* ((parsed (emacspeak-agent-shell--markdown-table-rows source))
               (rows (plist-get parsed :rows))
               (column-titles-p (plist-get parsed :column-titles-p))
               (remaining cell-index)
               (row-index 0)
               current-row
               column-index)
          (while (and rows (not current-row))
            (if (< remaining (length (car rows)))
                (setq current-row (car rows)
                      column-index remaining)
              (setq remaining (- remaining (length (car rows)))
                    rows (cdr rows)
                    row-index (1+ row-index))))
          (when current-row
            (let ((all-rows (plist-get parsed :rows)))
              (list
               :data (nth column-index current-row)
               :row-index row-index
               :row-count (length all-rows)
               :column-index column-index
               :column-count
               (apply #'max 0 (mapcar #'length all-rows))
               :column-titles-p column-titles-p
               :rows all-rows
               :column-title
               (when column-titles-p
                 (nth column-index (car all-rows)))
               :row-title
               (unless (and column-titles-p (zerop row-index))
                 (car current-row))))))))))

(defun emacspeak-agent-shell--table-title (title face data)
  "Return TITLE voiced with FACE unless it is blank or duplicates DATA."
  (when-let* ((title (and title (string-trim title)))
              ((not (string-empty-p title)))
              ((not (string= (substring-no-properties title)
                             (substring-no-properties data)))))
    (setq title (copy-sequence title))
    (add-face-text-property 0 (length title) face t title)
    title))

(defun emacspeak-agent-shell--table-cell-speech (cell)
  "Format semantic table CELL according to the table speech options."
  (let* ((raw-data (or (plist-get cell :data) ""))
         (data (string-trim raw-data))
         (data (if (string-empty-p data) "blank" data))
         (row-title
          (when (memq 'row emacspeak-agent-shell-table-titles)
            (emacspeak-agent-shell--table-title
             (plist-get cell :row-title) 'italic data)))
         (column-title
          (when (memq 'column emacspeak-agent-shell-table-titles)
            (emacspeak-agent-shell--table-title
             (plist-get cell :column-title) 'bold data)))
         (titles (delq nil (list row-title column-title)))
         (parts (if (eq emacspeak-agent-shell-table-data-position 'first)
                    (cons data titles)
                  (append titles (list data)))))
    (concat (mapconcat #'identity parts ", ") ".")))

(defun emacspeak-agent-shell--table-cell-feedback ()
  "Speak the rendered Markdown table cell at point semantically."
  (when-let* ((cell (emacspeak-agent-shell--markdown-table-cell-at-point)))
    (emacspeak-icon 'item)
    (dtk-speak (emacspeak-agent-shell--table-cell-speech cell))
    t))

(defun emacspeak-agent-shell--table-context-speech (cell)
  "Format the position and dimensions of semantic table CELL."
  (let ((row-index (plist-get cell :row-index))
        (row-count (plist-get cell :row-count))
        (column (1+ (plist-get cell :column-index)))
        (column-count (plist-get cell :column-count)))
    (cond
     ((and (plist-get cell :column-titles-p) (zerop row-index))
      (let ((data-rows (1- row-count)))
        (format "Header row, column %d of %d; table has %d data %s."
                column column-count data-rows
                (if (= data-rows 1) "row" "rows"))))
     ((plist-get cell :column-titles-p)
      (format "Data row %d of %d, column %d of %d."
              row-index (1- row-count) column column-count))
     (t
      (format "Row %d of %d, column %d of %d."
              (1+ row-index) row-count column column-count)))))

(defun emacspeak-agent-shell--table-dimensions-speech (cell)
  "Format the dimensions of the table containing semantic CELL."
  (let* ((column-titles-p (plist-get cell :column-titles-p))
         (rows (- (plist-get cell :row-count)
                  (if column-titles-p 1 0)))
         (columns (plist-get cell :column-count)))
    (format "Table, %d %s, %d %s."
            rows
            (if column-titles-p
                (if (= rows 1) "data row" "data rows")
              (if (= rows 1) "row" "rows"))
            columns
            (if (= columns 1) "column" "columns"))))

(defun emacspeak-agent-shell--table-entry-feedback (direction)
  "Enter and speak the table at point in navigation DIRECTION."
  (when-let* ((region (emacspeak-agent-shell--markdown-table-region-at-point))
              (starts
               (emacspeak-agent-shell--markdown-table-cell-starts region)))
    (goto-char (if (eq direction 'forward) (car starts) (car (last starts))))
    (when-let* ((cell (emacspeak-agent-shell--markdown-table-cell-at-point)))
      (emacspeak-icon 'open-object)
      (dtk-speak
       (concat (emacspeak-agent-shell--table-dimensions-speech cell)
               " "
               (emacspeak-agent-shell--table-cell-speech cell)))
      t)))

(defun emacspeak-agent-shell-table-speak-context ()
  "Speak current Markdown table position and dimensions."
  (interactive)
  (if-let ((cell (emacspeak-agent-shell--markdown-table-cell-at-point)))
      (progn
        (emacspeak-icon 'item)
        (dtk-speak (emacspeak-agent-shell--table-context-speech cell)))
    (user-error "Not in a rendered Markdown table")))

(defun emacspeak-agent-shell--table-leading-title-speech (title face)
  "Format leading table TITLE with FACE, or return nil when it is blank."
  (when-let ((title (emacspeak-agent-shell--table-title title face "")))
    (concat title ".")))

(defun emacspeak-agent-shell--table-row-speech (cell)
  "Format the logical table row containing semantic CELL."
  (let* ((rows (plist-get cell :rows))
         (row-index (plist-get cell :row-index))
         (row (nth row-index rows))
         (column-titles-p (plist-get cell :column-titles-p))
         (header-row-p (and column-titles-p (zerop row-index)))
         (row-title
          (when (and (not header-row-p)
                     (memq 'row emacspeak-agent-shell-table-titles))
            (emacspeak-agent-shell--table-leading-title-speech
             (car row) 'italic)))
         (first-column (if row-title 1 0))
         entries)
    (when header-row-p
      (push "Header row." entries))
    (when row-title
      (push row-title entries))
    (cl-loop
     for data in (nthcdr first-column row)
     for column from first-column
     do
     (push
      (emacspeak-agent-shell--table-cell-speech
       (list :data data
             :column-title
             (when column-titles-p (nth column (car rows)))))
      entries))
    (string-join (nreverse entries) " ")))

(defun emacspeak-agent-shell--table-column-speech (cell)
  "Format the logical table column containing semantic CELL."
  (let* ((rows (plist-get cell :rows))
         (column (plist-get cell :column-index))
         (column-titles-p (plist-get cell :column-titles-p))
         (column-title
          (when (and column-titles-p
                     (memq 'column emacspeak-agent-shell-table-titles))
            (emacspeak-agent-shell--table-leading-title-speech
             (nth column (car rows)) 'bold)))
         (data-rows (if column-titles-p (cdr rows) rows))
         entries)
    (when column-title
      (push column-title entries))
    (dolist (row data-rows)
      (push
       (emacspeak-agent-shell--table-cell-speech
        (list :data (nth column row)
              :row-title (car row)))
       entries))
    (string-join (nreverse entries) " ")))

(defun emacspeak-agent-shell-table-speak-row ()
  "Speak the logical Markdown table row at point."
  (interactive)
  (if-let ((cell (emacspeak-agent-shell--markdown-table-cell-at-point)))
      (progn
        (emacspeak-icon 'item)
        (dtk-speak (emacspeak-agent-shell--table-row-speech cell)))
    (user-error "Not in a rendered Markdown table")))

(defun emacspeak-agent-shell-table-speak-column ()
  "Speak the logical Markdown table column at point."
  (interactive)
  (if-let ((cell (emacspeak-agent-shell--markdown-table-cell-at-point)))
      (progn
        (emacspeak-icon 'item)
        (dtk-speak (emacspeak-agent-shell--table-column-speech cell)))
    (user-error "Not in a rendered Markdown table")))

;; Agent-shell does not currently expose a current-cell value or copy command.
;; Prefer speech-enabling that command if agent-shell adds one in the future.
(defun emacspeak-agent-shell-table-copy-cell ()
  "Copy the logical Markdown table cell at point to the kill ring.
Remove renderer padding, borders, and text properties.  Preserve the complete
logical value of a wrapped cell."
  (interactive)
  (if-let ((cell (emacspeak-agent-shell--markdown-table-cell-at-point)))
      (let ((data
             (substring-no-properties
              (string-trim (or (plist-get cell :data) "")))))
        (kill-new data)
        (emacspeak-icon 'save-object)
        (dtk-speak "Copied table cell."))
    (user-error "Not in a rendered Markdown table")))

(defun emacspeak-agent-shell--table-settings-speech ()
  "Return a complete spoken summary of the table speech settings."
  (format "Table speech: %s; column titles %s; row titles %s."
          (if (eq emacspeak-agent-shell-table-data-position 'first)
              "data first"
            "titles first")
          (if (memq 'column emacspeak-agent-shell-table-titles) "on" "off")
          (if (memq 'row emacspeak-agent-shell-table-titles) "on" "off")))

(defun emacspeak-agent-shell--toggle-table-title (title)
  "Toggle table TITLE and retain canonical column, row ordering."
  (let ((titles
         (if (memq title emacspeak-agent-shell-table-titles)
             (remove title emacspeak-agent-shell-table-titles)
           (cons title emacspeak-agent-shell-table-titles))))
    (setq emacspeak-agent-shell-table-titles
          (seq-filter (lambda (candidate) (memq candidate titles))
                      '(column row)))))

(defun emacspeak-agent-shell-table-select-speaking-method ()
  "Interactively change automatic Markdown table cell speech.
Press c to toggle column titles, r to toggle row titles, or o to
switch between data-first and title-first ordering.  Speak the complete
resulting configuration after the change."
  (interactive)
  (pcase
      (read-char-choice
       "Toggle table speech: c column titles, r row titles, o order: "
       '(?c ?r ?o))
    (?c (emacspeak-agent-shell--toggle-table-title 'column))
    (?r (emacspeak-agent-shell--toggle-table-title 'row))
    (?o (setq emacspeak-agent-shell-table-data-position
              (if (eq emacspeak-agent-shell-table-data-position 'first)
                  'last
                'first))))
  (emacspeak-icon 'button)
  (dtk-speak (emacspeak-agent-shell--table-settings-speech)))

(defun emacspeak-agent-shell--permission-button-text-at-point ()
  "Return the visible permission button text at point, without decoration."
  (when (get-text-property (point) 'agent-shell-permission-button)
    (let ((start (point))
          (end (point)))
      (while (and (> start (point-min))
                  (eq (get-text-property (1- start) 'button) 'permission))
        (setq start (1- start)))
      (while (and (< end (point-max))
                  (eq (get-text-property end 'button) 'permission))
        (setq end (1+ end)))
      (let ((text (string-trim
                   (buffer-substring-no-properties start end))))
        (when (and (string-prefix-p "[" text)
                   (string-suffix-p "]" text))
          (setq text (string-trim (substring text 1 -1))))
        text))))

(defun emacspeak-agent-shell--permission-button-positions-on-line ()
  "Return permission button marker positions on the current line."
  (let ((position (line-beginning-position))
        (end (line-end-position))
        positions)
    (while (and (< position end)
                (setq position
                      (text-property-any
                       position end 'agent-shell-permission-button t)))
      (push position positions)
      (setq position
            (or (next-single-property-change
                 position 'agent-shell-permission-button nil end)
                end)))
    (nreverse positions)))

(defun emacspeak-agent-shell--permission-button-feedback ()
  "Speak the focused permission choice, position, and activation key."
  (when-let* ((text (emacspeak-agent-shell--permission-button-text-at-point))
              (positions
               (emacspeak-agent-shell--permission-button-positions-on-line))
              (offset (cl-position (point) positions :test #'=)))
    (let ((label text)
          key)
      (when (string-match "\\`\\(.*\\) (\\([^()]+\\))\\'" text)
        (setq label (string-trim (match-string 1 text))
              key (match-string 2 text)))
      (emacspeak-icon 'item)
      (dtk-speak
       (format "%s, choice %d of %d. Press Return%s."
               label
               (1+ offset)
               (length positions)
               (if key (format " or %s" key) "")))
      t)))

(defadvice agent-shell-next-item (around emacspeak pre act comp)
  "Speak the item at point after navigation, including table entry."
  (let ((interactive-p (ems-interactive-p))
        (started-in-table-p
         (get-text-property (point) 'agent-shell-markdown-table-source)))
    ad-do-it
    (when interactive-p
      (unless (or (and (not started-in-table-p)
                       (get-text-property
                        (point) 'agent-shell-markdown-table-source)
                       (emacspeak-agent-shell--table-entry-feedback 'forward))
                  (emacspeak-agent-shell--permission-button-feedback)
                  (emacspeak-agent-shell--table-cell-feedback))
        (emacspeak-icon 'item)
        (emacspeak-speak-line)))))

(defadvice agent-shell-previous-item (around emacspeak pre act comp)
  "Speak the item at point after navigation, including table entry."
  (let ((interactive-p (ems-interactive-p))
        (started-in-table-p
         (get-text-property (point) 'agent-shell-markdown-table-source)))
    ad-do-it
    (when interactive-p
      (unless (or (and (not started-in-table-p)
                       (get-text-property
                        (point) 'agent-shell-markdown-table-source)
                       (emacspeak-agent-shell--table-entry-feedback 'backward))
                  (emacspeak-agent-shell--permission-button-feedback)
                  (emacspeak-agent-shell--table-cell-feedback))
        (emacspeak-icon 'item)
        (emacspeak-speak-line)))))

(defadvice agent-shell-jump-to-latest-permission-button-row (after emacspeak pre act comp)
  "Announce jump to permission."
  (when (and (ems-interactive-p) ad-return-value)
    (emacspeak-agent-shell--permission-button-feedback)))

(defadvice agent-shell-next-permission-button (after emacspeak pre act comp)
  "Speak the next permission choice after moving to it."
  (when (and (ems-interactive-p) ad-return-value)
    (emacspeak-agent-shell--permission-button-feedback)))

(defadvice agent-shell-previous-permission-button (after emacspeak pre act comp)
  "Speak the previous permission choice after moving to it."
  (when (and (ems-interactive-p) ad-return-value)
    (emacspeak-agent-shell--permission-button-feedback)))

;;;  Session Management

(defadvice agent-shell-set-session-model (after emacspeak pre act comp)
  "Announce model change."
  (when (ems-interactive-p)
    (emacspeak-icon 'select-object)
    (message "Model changed")))

(defadvice agent-shell-set-session-mode (after emacspeak pre act comp)
  "Announce session mode change."
  (when (ems-interactive-p)
    (emacspeak-icon 'select-object)
    (message "Session mode changed")))

(defadvice agent-shell-cycle-session-mode (after emacspeak pre act comp)
  "Announce session mode cycle."
  (when (ems-interactive-p)
    (emacspeak-icon 'select-object)
    (emacspeak-speak-line)))

;;;  Viewport Mode Integration

(defadvice agent-shell-viewport-next-item (around emacspeak pre act comp)
  "Speak semantic table movement and entry in the viewport."
  (let ((interactive-p (ems-interactive-p))
        (started-in-table-p
         (get-text-property (point) 'agent-shell-markdown-table-source)))
    ad-do-it
    (when interactive-p
      (or (and (not started-in-table-p)
               (get-text-property
                (point) 'agent-shell-markdown-table-source)
               (emacspeak-agent-shell--table-entry-feedback 'forward))
          (emacspeak-agent-shell--table-cell-feedback)))))

(defadvice agent-shell-viewport-previous-item (around emacspeak pre act comp)
  "Speak semantic table movement and entry in the viewport."
  (let ((interactive-p (ems-interactive-p))
        (started-in-table-p
         (get-text-property (point) 'agent-shell-markdown-table-source)))
    ad-do-it
    (when interactive-p
      (or (and (not started-in-table-p)
               (get-text-property
                (point) 'agent-shell-markdown-table-source)
               (emacspeak-agent-shell--table-entry-feedback 'backward))
          (emacspeak-agent-shell--table-cell-feedback)))))

(defadvice agent-shell-viewport--show-buffer (after emacspeak pre act comp)
  "Announce viewport display."
  (when (ems-interactive-p)
    (emacspeak-icon 'open-object)
    (emacspeak-speak-mode-line)))

(defadvice agent-shell-prompt-compose (after emacspeak pre act comp)
  "Announce prompt composition."
  (when (ems-interactive-p)
    (emacspeak-icon 'open-object)
    (message "Compose prompt")))

(defadvice agent-shell-viewport-refresh (after emacspeak pre act comp)
  "Announce viewport refresh."
  (when (ems-interactive-p)
    (emacspeak-icon 'task-done)
    (message "Viewport refreshed")))

(defadvice agent-shell-viewport-compose-send (after emacspeak pre act comp)
  "Announce prompt submission."
  (when (ems-interactive-p)
    (emacspeak-icon 'close-object)
    (dtk-speak "Prompt submitted.")))

(defadvice agent-shell-viewport-compose-cancel (around emacspeak pre act comp)
  "Announce an accepted prompt composition cancellation."
  (let ((interactive-p (ems-interactive-p))
        (viewport-buffer (current-buffer))
        (original-mode major-mode))
    ad-do-it
    (when (and interactive-p
               (or (not (buffer-live-p viewport-buffer))
                   (not (eq (current-buffer) viewport-buffer))
                   (not (eq (buffer-local-value 'major-mode viewport-buffer)
                            original-mode))))
      (emacspeak-icon 'close-object)
      (dtk-speak "Prompt composition cancelled."))))

;;;  Interactive Commands for Viewport

(cl-loop
 for f in
 '(agent-shell-viewport-view-mode agent-shell-viewport-edit-mode)
 do
 (eval
  `(defadvice ,f (after emacspeak pre act comp)
     "Announce mode change."
     (when (ems-interactive-p)
       (emacspeak-icon 'select-object)
       (emacspeak-speak-mode-line)))))

;;;  Tool Call Feedback

(defun emacspeak-agent-shell--tool-call-status-icon (status)
  "Return appropriate auditory icon for tool call STATUS."
  (pcase status
    ("completed" 'task-done)
    ("failed" 'warn-user)
    ("in_progress" 'progress)
    ("pending" 'item)
    (_ 'item)))

(defun emacspeak-agent-shell--meaningful-tool-text (text)
  "Return a concise speech version of meaningful tool TEXT, or nil."
  (when (and (stringp text) (string-match-p "[[:alnum:]]" text))
    (let ((clean
           (replace-regexp-in-string
            "[[:space:]\n\r]+" " "
            (string-trim (substring-no-properties text)))))
      (if (> (length clean) 120)
          (concat (substring clean 0 117) "...")
        clean))))

(defun emacspeak-agent-shell--tool-call-description (tool-call tool-call-id)
  "Return a concise description of TOOL-CALL identified by TOOL-CALL-ID."
  (or (emacspeak-agent-shell--meaningful-tool-text
       (map-elt tool-call :title))
      (emacspeak-agent-shell--meaningful-tool-text
       (map-elt tool-call :description))
      (emacspeak-agent-shell--meaningful-tool-text
       (map-elt tool-call :command))
      (emacspeak-agent-shell--meaningful-tool-text
       (map-elt tool-call :kind))
      (emacspeak-agent-shell--meaningful-tool-text tool-call-id)
      "unknown tool"))

(defun emacspeak-agent-shell--tool-call-announcement (status description)
  "Return a semantic announcement for tool STATUS and DESCRIPTION."
  (let ((verb (pcase status
                ("pending" "pending")
                ("in_progress" "started")
                ("completed" "completed")
                ("failed" "failed"))))
    (concat (format "Tool %s: %s" verb description)
            (unless (string-match-p "[.!?]$" description) "."))))

(defun emacspeak-agent-shell--tool-content-block-text (block)
  "Extract speakable text from ACP tool content BLOCK."
  (cond
   ((stringp block) (substring-no-properties block))
   ((listp block)
    (let ((text (or (map-elt block :text) (map-elt block 'text)))
          (content (or (map-elt block :content) (map-elt block 'content))))
      (cond
       ((stringp text) (substring-no-properties text))
       ((stringp content) (substring-no-properties content))
       ((listp content)
        (emacspeak-agent-shell--tool-content-block-text content)))))
   (t nil)))

(defun emacspeak-agent-shell--tool-output-text (content)
  "Extract speakable terminal output from ACP tool CONTENT."
  (let* ((blocks
          (cond
           ((stringp content) (list content))
           ((vectorp content) (append content nil))
           ((and (listp content)
                 (or (assq 'type content) (assq :type content)
                     (assq 'text content) (assq :text content)))
            (list content))
           ((listp content) content)))
         (texts
          (seq-keep
           (lambda (block)
             (when-let* ((text
                          (emacspeak-agent-shell--tool-content-block-text
                           block))
                         (trimmed (string-trim text))
                         ((not (string-empty-p trimmed))))
               trimmed))
           blocks)))
    (when texts (string-join texts "\n"))))

(defun emacspeak-agent-shell--handle-tool-call-update (event)
  "Announce a new semantic status from public tool update EVENT."
  (let* ((data (map-elt event :data))
         (tool-call-id (map-elt data :tool-call-id))
         (tool-call (map-elt data :tool-call))
         (status (map-elt tool-call :status)))
    (when (and tool-call-id status)
      (unless (hash-table-p emacspeak-agent-shell--tool-call-status-cache)
        (setq emacspeak-agent-shell--tool-call-status-cache
              (make-hash-table :test #'equal)))
      (let ((previous
             (gethash tool-call-id
                      emacspeak-agent-shell--tool-call-status-cache)))
        (puthash tool-call-id status
                 emacspeak-agent-shell--tool-call-status-cache)
        (when (and emacspeak-agent-shell-speak-tool-calls
                   (member status
                           '("pending" "in_progress" "completed" "failed"))
                   (not (equal status previous)))
          (emacspeak-icon
           (emacspeak-agent-shell--tool-call-status-icon status))
          (unless (eq emacspeak-agent-shell-tool-output-verbosity 'status)
            (dtk-speak
             (emacspeak-agent-shell--tool-call-announcement
              status
              (emacspeak-agent-shell--tool-call-description
               tool-call tool-call-id)))
            (when (and (eq emacspeak-agent-shell-tool-output-verbosity 'full)
                       (member status '("completed" "failed")))
              (when-let* ((output
                           (emacspeak-agent-shell--tool-output-text
                            (map-elt tool-call :content))))
                (dtk-speak (format "Output: %s" output))))))))))

(defun emacspeak-agent-shell--tool-call-event-setup ()
  "Subscribe the current agent-shell buffer to tool call updates."
  (unless emacspeak-agent-shell--tool-call-subscription
    (setq emacspeak-agent-shell--tool-call-subscription
          (agent-shell-subscribe-to
           :shell-buffer (current-buffer)
           :event 'tool-call-update
           :on-event #'emacspeak-agent-shell--handle-tool-call-update))))

(defun emacspeak-agent-shell--tool-call-event-cleanup ()
  "Remove the current buffer's tool subscription and cached state."
  (when emacspeak-agent-shell--tool-call-subscription
    (agent-shell-unsubscribe
     :subscription emacspeak-agent-shell--tool-call-subscription)
    (setq emacspeak-agent-shell--tool-call-subscription nil))
  (when (hash-table-p emacspeak-agent-shell--tool-call-status-cache)
    (clrhash emacspeak-agent-shell--tool-call-status-cache))
  (setq emacspeak-agent-shell--tool-call-status-cache nil)
  (remove-hook 'kill-buffer-hook
               #'emacspeak-agent-shell--tool-call-event-cleanup t)
  (remove-hook 'change-major-mode-hook
               #'emacspeak-agent-shell--tool-call-event-cleanup t))

(defun emacspeak-agent-shell--buffer-setup ()
  "Install event support and centralized cleanup in this shell buffer."
  (add-hook 'kill-buffer-hook
            #'emacspeak-agent-shell--buffer-cleanup nil t)
  (add-hook 'change-major-mode-hook
            #'emacspeak-agent-shell--buffer-cleanup nil t)
  (emacspeak-agent-shell--permission-event-setup)
  (emacspeak-agent-shell--lifecycle-event-setup)
  (emacspeak-agent-shell--tool-call-event-setup))

(defun emacspeak-agent-shell--buffer-cleanup ()
  "Cancel speech work and remove all support state from this shell buffer."
  (emacspeak-agent-shell--cancel-pending-speech)
  (setq emacspeak-agent-shell--pending-bodies nil)
  (emacspeak-agent-shell--permission-event-cleanup)
  (emacspeak-agent-shell--lifecycle-event-cleanup)
  (emacspeak-agent-shell--tool-call-event-cleanup)
  (remove-hook 'kill-buffer-hook
               #'emacspeak-agent-shell--buffer-cleanup t)
  (remove-hook 'change-major-mode-hook
               #'emacspeak-agent-shell--buffer-cleanup t))

;;;  Enable/Disable support:

(defvar emacspeak-agent-shell--advice-list
  '((agent-shell after)
    (agent-shell-start after)
    (agent-shell-new-shell after)
    (agent-shell-toggle after)
    (agent-shell-other-buffer after)
    (agent-shell-interrupt after)
    (agent-shell--update-fragment around)
    (agent-shell-next-item around)
    (agent-shell-previous-item around)
    (agent-shell-jump-to-latest-permission-button-row after)
    (agent-shell-next-permission-button after)
    (agent-shell-previous-permission-button after)
    (agent-shell-set-session-model after)
    (agent-shell-set-session-mode after)
    (agent-shell-cycle-session-mode after)
    (agent-shell-viewport--show-buffer after)
    (agent-shell-viewport-next-item around)
    (agent-shell-viewport-previous-item around)
    (agent-shell-prompt-compose after)
    (agent-shell-viewport-refresh after)
    (agent-shell-viewport-compose-send after)
    (agent-shell-viewport-compose-cancel around)
    (agent-shell-viewport-view-mode after)
    (agent-shell-viewport-edit-mode after))
  "List of advised functions for Emacspeak agent-shell support.")

(defun emacspeak-agent-shell-enable ()
  "Enable Emacspeak support for agent-shell."
  (interactive)
  (dolist (advice emacspeak-agent-shell--advice-list)
    (ad-enable-advice (car advice) (cadr advice) 'emacspeak)
    (ad-activate (car advice)))
  (add-hook 'agent-shell-mode-hook #'emacspeak-agent-shell-speech-setup)
  ;; Remove hooks installed by earlier versions before installing the
  ;; centralized setup path.
  (remove-hook 'agent-shell-mode-hook
               #'emacspeak-agent-shell--permission-event-setup)
  (remove-hook 'agent-shell-mode-hook
               #'emacspeak-agent-shell--lifecycle-event-setup)
  (remove-hook 'agent-shell-mode-hook
               #'emacspeak-agent-shell--tool-call-event-setup)
  (add-hook 'agent-shell-mode-hook #'emacspeak-agent-shell--buffer-setup)
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (when (derived-mode-p 'agent-shell-mode)
        (emacspeak-agent-shell--buffer-setup))))
  (message "Enabled Emacspeak agent-shell support"))

(defun emacspeak-agent-shell-disable ()
  "Disable Emacspeak support for agent-shell."
  (interactive)
  (dolist (advice emacspeak-agent-shell--advice-list)
    (ad-disable-advice (car advice) (cadr advice) 'emacspeak)
    (ad-activate (car advice)))
  (remove-hook 'agent-shell-mode-hook #'emacspeak-agent-shell-speech-setup)
  (remove-hook 'agent-shell-mode-hook #'emacspeak-agent-shell--buffer-setup)
  ;; Also remove setup hooks left by earlier versions.
  (remove-hook 'agent-shell-mode-hook
               #'emacspeak-agent-shell--permission-event-setup)
  (remove-hook 'agent-shell-mode-hook
               #'emacspeak-agent-shell--lifecycle-event-setup)
  (remove-hook 'agent-shell-mode-hook
               #'emacspeak-agent-shell--tool-call-event-setup)
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (when (derived-mode-p 'agent-shell-mode)
        (emacspeak-agent-shell--buffer-cleanup))))
  (message "Disabled Emacspeak agent-shell support"))

(provide 'emacspeak-agent-shell)
;;;  end of file
