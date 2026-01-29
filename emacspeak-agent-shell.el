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
  "List of qualified-ids for blocks pending speech.
Accumulates all block IDs until streaming completes, then we read
the actual content from agent-shell-ui--content-store.")

(make-variable-buffer-local 'emacspeak-agent-shell--pending-speech-qualified-ids)

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

(defun emacspeak-agent-shell--execute-delayed-speech (buffer qualified-ids)
  "Execute delayed speech of blocks identified by QUALIFIED-IDS in BUFFER.
This is called after streaming has completed."
  (cl-declare (special agent-shell-ui--content-store dtk-speaker-process))
  (when (and buffer (buffer-live-p buffer))
    (with-current-buffer buffer
      ;; Speak each accumulated block in order
      (dolist (qualified-id qualified-ids)
        ;; Read the actual content from the content store
        (when-let* ((body-key (concat qualified-id "-body"))
                    (content (and agent-shell-ui--content-store
                                  (gethash body-key agent-shell-ui--content-store)))
                    (block-id (if (string-match "-\\([^-]+\\)$" qualified-id)
                                  (match-string 1 qualified-id)
                                qualified-id))
                    (block-type (emacspeak-agent-shell--classify-block block-id))
                    (trimmed (string-trim content)))
          (when (not (string-empty-p trimmed))
            (emacspeak-agent-shell--speak-content trimmed block-type))))
      ;; Clear pending state
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
               (emacspeak-agent-shell--should-speak-p buffer))
      (with-current-buffer buffer
        ;; Cancel any existing timer
        (when emacspeak-agent-shell--pending-speech-timer
          (cancel-timer emacspeak-agent-shell--pending-speech-timer))
        ;; Build qualified-id (namespace-id + block-id)
        (let* ((namespace-id (map-elt state :request-count))
               (qualified-id (format "%s-%s" namespace-id block-id)))
          ;; Add qualified-id to list if not already present
          (unless (member qualified-id emacspeak-agent-shell--pending-speech-qualified-ids)
            (push qualified-id emacspeak-agent-shell--pending-speech-qualified-ids)))
        ;; Set a timer to speak after the delay
        (setq emacspeak-agent-shell--pending-speech-timer
              (run-with-timer
               emacspeak-agent-shell-speech-delay
               nil
               #'emacspeak-agent-shell--execute-delayed-speech
               buffer
               ;; Pass a copy of the list
               (copy-sequence emacspeak-agent-shell--pending-speech-qualified-ids))))))
  ad-return-value)

;;;  Navigation Commands

(defadvice agent-shell-next-item (after emacspeak pre act comp)
  "Speak the item at point after navigation."
  (when (ems-interactive-p)
    (emacspeak-icon 'item)
    (emacspeak-speak-line)))

(defadvice agent-shell-previous-item (after emacspeak pre act comp)
  "Speak the item at point after navigation."
  (when (ems-interactive-p)
    (emacspeak-icon 'item)
    (emacspeak-speak-line)))

(defadvice agent-shell-jump-to-latest-permission-button-row (after emacspeak pre act comp)
  "Announce jump to permission."
  (when (ems-interactive-p)
    (emacspeak-icon 'large-movement)
    (message "Permission request")
    (emacspeak-speak-line)))

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

(defadvice agent-shell-viewport-submit (after emacspeak pre act comp)
  "Announce prompt submission."
  (when (ems-interactive-p)
    (emacspeak-icon 'close-object)
    (message "Prompt submitted")))

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
    ("running" 'progress)
    ("pending" 'item)
    (_ 'item)))

(defadvice agent-shell--save-tool-call (after emacspeak pre act comp)
  "Provide feedback when tool call status changes."
  (when (ems-interactive-p)
    (let* ((tool-call (ad-get-arg 2))
           (status (map-elt tool-call :status))
           (title (map-elt tool-call :title)))
      (when (and status (member status '("completed" "failed")))
        (emacspeak-icon (emacspeak-agent-shell--tool-call-status-icon status))
        (when title
          (message "Tool: %s - %s" title status))))))

;;;  Enable/Disable support:

(defvar emacspeak-agent-shell--advice-list
  '((agent-shell after)
    (agent-shell-start after)
    (agent-shell-new-shell after)
    (agent-shell-toggle after)
    (agent-shell-other-buffer after)
    (agent-shell-interrupt after)
    (agent-shell--update-fragment around)
    (agent-shell-next-item after)
    (agent-shell-previous-item after)
    (agent-shell-jump-to-latest-permission-button-row after)
    (agent-shell-set-session-model after)
    (agent-shell-set-session-mode after)
    (agent-shell-cycle-session-mode after)
    (agent-shell-viewport--show-buffer after)
    (agent-shell-prompt-compose after)
    (agent-shell-viewport-refresh after)
    (agent-shell-viewport-submit after)
    (agent-shell-viewport-view-mode after)
    (agent-shell-viewport-edit-mode after)
    (agent-shell--save-tool-call after))
  "List of advised functions for Emacspeak agent-shell support.")

(defun emacspeak-agent-shell-enable ()
  "Enable Emacspeak support for agent-shell."
  (interactive)
  (dolist (advice emacspeak-agent-shell--advice-list)
    (ad-enable-advice (car advice) (cadr advice) 'emacspeak)
    (ad-activate (car advice)))
  (add-hook 'agent-shell-mode-hook #'emacspeak-agent-shell-speech-setup)
  (message "Enabled Emacspeak agent-shell support"))

(defun emacspeak-agent-shell-disable ()
  "Disable Emacspeak support for agent-shell."
  (interactive)
  (dolist (advice emacspeak-agent-shell--advice-list)
    (ad-disable-advice (car advice) (cadr advice) 'emacspeak)
    (ad-activate (car advice)))
  (remove-hook 'agent-shell-mode-hook #'emacspeak-agent-shell-speech-setup)
  (message "Disabled Emacspeak agent-shell support"))

(provide 'emacspeak-agent-shell)
;;;  end of file
