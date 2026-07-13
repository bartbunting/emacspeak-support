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

(declare-function agent-shell--context-usage-face
                  "agent-shell-usage" (percentage))
(declare-function agent-shell-copy-source-block-at-point
                  "agent-shell" (&optional pos))
(declare-function agent-shell-markdown-source-block-at-point
                  "agent-shell-markdown" (&optional pos))
(declare-function agent-shell-ui-toggle-fragment "agent-shell-ui" ())

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

(defcustom emacspeak-agent-shell-foreground-speech-level 'response
  "Automatic speech level for the focused agent-shell session.
The focused session is the selected agent-shell buffer or the shell associated
with the selected viewport.  `full' preserves configured response, thought,
tool, and lifecycle feedback.  `response' speaks agent responses and completion
feedback while suppressing routine thought and tool chatter.  `notify' only
signals completion, and `quiet' suppresses routine feedback.  Permissions and
errors remain controlled separately because they may require action."
  :type '(choice (const :tag "Full detail" full)
                 (const :tag "Responses" response)
                 (const :tag "Notifications" notify)
                 (const :tag "Quiet" quiet))
  :group 'emacspeak-agent-shell)

(defcustom emacspeak-agent-shell-background-speech-level 'notify
  "Automatic speech level for an unfocused agent-shell session.
The available levels have the same meaning as
`emacspeak-agent-shell-foreground-speech-level'.  Background completion uses
Emacspeak's notification stream and includes the session buffer name."
  :type '(choice (const :tag "Full detail" full)
                 (const :tag "Responses" response)
                 (const :tag "Notifications" notify)
                 (const :tag "Quiet" quiet))
  :group 'emacspeak-agent-shell)

(defvar-local emacspeak-agent-shell-speech-level 'auto
  "Per-session override for automatic agent-shell speech.
The value `auto' follows the foreground and background defaults.  The values
`full', `response', `notify', and `quiet' force that level for this session.
Use `emacspeak-agent-shell-cycle-speech-level' to change it interactively.")

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
               emacspeak-pronounce-sha-checksum-pattern
               emacspeak-pronounce-date-mm-dd-yyyy-pattern
               emacspeak-pronounce-date-yyyy-mm-dd-pattern
               emacspeak-pronounce-rfc-3339-datetime-pattern
               emacspeak-comint-autospeak))
  (setq buffer-undo-list t)
  ;; Enable autospeak by default for agent-shell buffers
  (unless (local-variable-p 'emacspeak-comint-autospeak)
    (setq-local emacspeak-comint-autospeak t))
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

(defconst emacspeak-agent-shell--ui-face-voice-map
  '((agent-shell-model voice-brighten-extra)
    (agent-shell-thought-level voice-animate-extra)
    (agent-shell-container-indicator voice-lighten)
    (agent-shell-buffer-name voice-animate)
    (agent-shell-session-id voice-lighten)
    (agent-shell-session-mode voice-smoothen)
    (agent-shell-session-title voice-bolden)
    (agent-shell-session-directory voice-lighten-extra)
    (agent-shell-session-date voice-monotone-extra)
    (agent-shell-section-heading voice-bolden)
    (agent-shell-section-annotation voice-monotone)
    (agent-shell-success voice-brighten-extra)
    (agent-shell-warning voice-brighten)
    (agent-shell-error voice-bolden-and-animate)
    (agent-shell-pending voice-monotone-extra)
    (agent-shell-list-name voice-brighten)
    (agent-shell-list-description voice-monotone-extra)
    (agent-shell-list-value voice-lighten)
    (agent-shell-usage voice-monotone-extra)
    (agent-shell-prompt voice-lighten-extra)
    (agent-shell-input voice-bolden-medium)
    (agent-shell-key-binding voice-annotate)
    (agent-shell-link voice-bolden)
    (agent-shell-permission-title voice-bolden)
    (agent-shell-viewport-prompt voice-monotone)
    (agent-shell-viewport-status-edit voice-brighten-extra)
    (agent-shell-viewport-status-busy voice-brighten))
  "Voice personalities for current agent-shell interface faces.")

(defconst emacspeak-agent-shell--ui-unvoiced-faces
  '(agent-shell-viewport-status-view)
  "Agent-shell interface faces intentionally left without a voice.
The neutral viewport view face carries no state beyond its spoken text.")

(defconst emacspeak-agent-shell--markdown-face-voice-map
  '((agent-shell-markdown-bold voice-bolden)
    (agent-shell-markdown-italic voice-animate)
    (agent-shell-markdown-strikethrough voice-annotate)
    (agent-shell-markdown-inline-code voice-monotone-extra)
    (agent-shell-markdown-link voice-bolden)
    (agent-shell-markdown-blockquote voice-lighten)
    (agent-shell-markdown-header-1 voice-brighten)
    (agent-shell-markdown-header-2 voice-animate)
    (agent-shell-markdown-header-3 voice-lighten)
    (agent-shell-markdown-header-4 voice-smoothen)
    (agent-shell-markdown-header-5 voice-monotone)
    (agent-shell-markdown-header-6 voice-monotone-extra)
    (agent-shell-markdown-table-header voice-bolden)
    (agent-shell-markdown-table-border inaudible)
    (agent-shell-markdown-source-block voice-monotone-extra)
    (agent-shell-markdown-source-block-language voice-smoothen))
  "Voice personalities for current agent-shell Markdown faces.")

(defconst emacspeak-agent-shell--markdown-unvoiced-faces
  '(agent-shell-markdown-table-zebra)
  "Agent-shell Markdown faces intentionally left without a voice.
Zebra striping is purely visual and should not alter table data speech.")

(voice-setup-add-map emacspeak-agent-shell--ui-face-voice-map)
(voice-setup-add-map emacspeak-agent-shell--markdown-face-voice-map)

;;;  Helper Functions

(defun emacspeak-agent-shell--speech-copy-without-yank-handler (text)
  "Return TEXT prepared for speech without invoking its clipboard handler.
Agent-shell Markdown uses `yank-handler' to make pasted content plain.  Speech
must bypass that handler so `dtk-speak' retains faces and other aural display
properties while copying TEXT into its private scratch buffer."
  (if (and (stringp text)
           (> (length text) 0)
           (text-property-not-all 0 (length text) 'yank-handler nil text))
      (let ((copy (copy-sequence text)))
        (remove-text-properties 0 (length copy) '(yank-handler nil) copy)
        copy)
    text))

(defun emacspeak-agent-shell--prepare-speech-text (text)
  "Prepare TEXT for speech in agent-shell, leaving other modes unchanged."
  (if (and (stringp text)
           (derived-mode-p 'agent-shell-mode
                           'agent-shell-viewport-view-mode
                           'agent-shell-viewport-edit-mode))
      (emacspeak-agent-shell--speech-copy-without-yank-handler text)
    text))

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

(defvar-local emacspeak-agent-shell--table-navigation-active nil
  "Non-nil when contextual Markdown table keys are active.")

(defvar-local emacspeak-agent-shell--table-navigation-table-start nil
  "Start position of the rendered table currently being navigated.")

(defvar-local emacspeak-agent-shell--table-navigation-origin nil
  "Point before the command most recently tracked for table entry.")

(defvar-local emacspeak-agent-shell--speech-control-active nil
  "Non-nil when agent-shell speech-level keys are active.")

(defcustom emacspeak-agent-shell-speech-delay 0.5
  "Delay in seconds before speaking completed streaming content.
When agent output streams in chunks, wait this long after the last
chunk arrives before speaking the complete text."
  :type 'number
  :group 'emacspeak-agent-shell)

(defconst emacspeak-agent-shell--speech-level-values
  '((quiet . 0) (notify . 1) (response . 2) (full . 3))
  "Numeric ordering of agent-shell automatic speech levels.")

(defun emacspeak-agent-shell--session-focused-p (&optional buffer)
  "Return non-nil when BUFFER's agent-shell session has keyboard focus.
A selected viewport counts as focus for its associated shell buffer."
  (let* ((shell-buffer (or buffer (current-buffer)))
         (selected-buffer (window-buffer (selected-window))))
    (and (buffer-live-p shell-buffer)
         (or (eq shell-buffer selected-buffer)
             (and (buffer-live-p selected-buffer)
                  (with-current-buffer selected-buffer
                    (and
                     (derived-mode-p 'agent-shell-viewport-view-mode
                                     'agent-shell-viewport-edit-mode)
                     (fboundp 'agent-shell-viewport--shell-buffer)
                     (eq shell-buffer
                         (agent-shell-viewport--shell-buffer
                          selected-buffer)))))))))

(defun emacspeak-agent-shell--session-label (&optional buffer)
  "Return a concise spoken label for agent-shell BUFFER."
  (let* ((name (buffer-name (or buffer (current-buffer))))
         (trimmed (and name
                       (string-trim name
                                    "[*[:space:]]+"
                                    "[*[:space:]]+"))))
    (if (and trimmed (not (string-empty-p trimmed)))
        trimmed
      "Agent shell")))

(defun emacspeak-agent-shell--effective-speech-level (&optional buffer)
  "Return the automatic speech level currently effective for BUFFER."
  (let ((target (or buffer (current-buffer))))
    (with-current-buffer target
      (if (memq emacspeak-agent-shell-speech-level
                '(full response notify quiet))
          emacspeak-agent-shell-speech-level
        (if (emacspeak-agent-shell--session-focused-p target)
            emacspeak-agent-shell-foreground-speech-level
          emacspeak-agent-shell-background-speech-level)))))

(defun emacspeak-agent-shell--speech-level-at-least-p (level &optional buffer)
  "Return non-nil when BUFFER's effective speech level includes LEVEL."
  (>= (or (alist-get (emacspeak-agent-shell--effective-speech-level buffer)
                     emacspeak-agent-shell--speech-level-values)
          0)
      (or (alist-get level emacspeak-agent-shell--speech-level-values) 0)))

(defun emacspeak-agent-shell--deliver-announcement (icon text)
  "Deliver ICON and TEXT for the current session without background chatter."
  (if (emacspeak-agent-shell--session-focused-p)
      (progn
        (emacspeak-icon icon)
        (dtk-speak text))
    (dtk-notify-icon icon)
    (dtk-notify
     (format "%s. %s"
             (emacspeak-agent-shell--session-label)
             text))))

(defconst emacspeak-agent-shell--speech-level-cycle
  '(full response notify quiet)
  "Order used by `emacspeak-agent-shell-cycle-speech-level'.")

(defconst emacspeak-agent-shell--speech-level-choices
  '(("automatic" . auto)
    ("full" . full)
    ("response" . response)
    ("notify" . notify)
    ("quiet" . quiet))
  "Completion candidates for interactive agent-shell speech levels.")

(defun emacspeak-agent-shell--session-buffer (&optional buffer)
  "Return the agent-shell session associated with BUFFER.
Signal a user error when BUFFER is neither a shell nor an associated viewport."
  (let ((candidate (or buffer (current-buffer))))
    (with-current-buffer candidate
      (cond
       ((derived-mode-p 'agent-shell-mode) candidate)
       ((derived-mode-p 'agent-shell-viewport-view-mode
                        'agent-shell-viewport-edit-mode)
        (or (and (fboundp 'agent-shell-viewport--shell-buffer)
                 (agent-shell-viewport--shell-buffer candidate))
            (user-error "This viewport has no agent-shell session")))
       (t (user-error "Not in an agent-shell session"))))))

(defun emacspeak-agent-shell--nonempty-text (value)
  "Return VALUE as trimmed plain text, or nil when it has no text."
  (when (stringp value)
    (let ((text (string-trim (substring-no-properties value))))
      (unless (string-empty-p text) text))))

(defun emacspeak-agent-shell--agent-name (state)
  "Return the spoken agent name represented by STATE."
  (when-let* ((name
               (emacspeak-agent-shell--nonempty-text
                (map-nested-elt state '(:agent-config :buffer-name)))))
    (if (string-match-p "\\bagent\\'" (downcase name))
        name
      (format "%s agent" name))))

(defun emacspeak-agent-shell--context-percentage (state)
  "Return the displayed context percentage represented by STATE."
  (when (bound-and-true-p agent-shell-show-context-usage-indicator)
    (let* ((usage (map-elt state :usage))
           (used (map-elt usage :context-used))
           (size (map-elt usage :context-size)))
      (when (and (numberp used) (numberp size) (> size 0))
        (round (/ (* 100.0 used) size))))))

(defun emacspeak-agent-shell--viewport-position ()
  "Return the current viewport position as a spoken string, or nil.
This isolates agent-shell's private viewport position API so upstream drift is
easy to detect and adapt."
  (when (derived-mode-p 'agent-shell-viewport-view-mode
                        'agent-shell-viewport-edit-mode)
    (when-let* ((position
                 (or (and (boundp 'agent-shell-viewport--position-cache)
                          agent-shell-viewport--position-cache)
                     (and (fboundp 'agent-shell-viewport--position)
                          (ignore-errors
                            (agent-shell-viewport--position)))))
                (current (map-elt position :current))
                (total (map-elt position :total)))
      (format "%s of %s" current total))))

(defun emacspeak-agent-shell--header-state (&optional buffer)
  "Return semantic header state for BUFFER, or nil when unavailable.
BUFFER may be an agent shell or one of its viewports.  Access to the private
aggregate `agent-shell--state' is kept here so compatibility changes remain
localized; individual model, thought-level, mode, and busy values use public
accessors where agent-shell provides them."
  (let* ((target (or buffer (current-buffer)))
         (viewport-p
          (with-current-buffer target
            (derived-mode-p 'agent-shell-viewport-view-mode
                            'agent-shell-viewport-edit-mode)))
         (position
          (when viewport-p
            (with-current-buffer target
              (emacspeak-agent-shell--viewport-position))))
         (viewport-mode
          (when viewport-p
            (with-current-buffer target major-mode)))
         (shell-buffer
          (condition-case nil
              (emacspeak-agent-shell--session-buffer target)
            (error nil))))
    (when (buffer-live-p shell-buffer)
      (with-current-buffer shell-buffer
        (when-let* ((state
                     (and (boundp 'agent-shell--state)
                          agent-shell--state)))
          (let* ((busy
                  (or (and (fboundp 'shell-maker-busy)
                           (ignore-errors (shell-maker-busy)))
                      (eq 'busy
                          (map-nested-elt state '(:heartbeat :status)))))
                 (project
                  (emacspeak-agent-shell--nonempty-text
                   (and (fboundp 'agent-shell--project-name)
                        (ignore-errors (agent-shell--project-name)))))
                 (status
                  (when viewport-p
                    (cond
                     ((and busy
                           (eq viewport-mode
                               'agent-shell-viewport-edit-mode))
                      "edit queue")
                     (busy "busy")
                     ((eq viewport-mode 'agent-shell-viewport-edit-mode)
                      "edit")
                     (t "view")))))
            (list
             :agent (or (emacspeak-agent-shell--agent-name state)
                        (emacspeak-agent-shell--session-label shell-buffer))
             :project project
             :busy busy
             :viewport-position position
             :viewport-status status
             :model
             (emacspeak-agent-shell--nonempty-text
              (and (fboundp 'agent-shell-get-model-name)
                   (ignore-errors (agent-shell-get-model-name state))))
             :thought-level
             (emacspeak-agent-shell--nonempty-text
              (and (fboundp 'agent-shell-get-thought-level-name)
                   (ignore-errors
                     (agent-shell-get-thought-level-name state))))
             :mode
             (emacspeak-agent-shell--nonempty-text
              (and (fboundp 'agent-shell-get-mode-name)
                   (ignore-errors (agent-shell-get-mode-name state))))
             :context-percentage
             (emacspeak-agent-shell--context-percentage state)
             :session-id
             (when (bound-and-true-p agent-shell-show-session-id)
               (emacspeak-agent-shell--nonempty-text
                (map-nested-elt state '(:session :id)))))))))))

(defun emacspeak-agent-shell--format-brief-header (state)
  "Return a concise focus announcement for semantic header STATE."
  (let ((parts
         (delq
          nil
          (list
           (plist-get state :agent)
           (plist-get state :project)
           (when-let* ((position (plist-get state :viewport-position)))
             (format "viewport %s" position))
           (or (plist-get state :viewport-status)
               (and (plist-get state :busy) "busy"))))))
    (when parts
      (concat (mapconcat #'identity parts ", ") "."))))

(defun emacspeak-agent-shell--header-context-face (percentage)
  "Return agent-shell's semantic face for context PERCENTAGE.
Use the guarded private helper when available so speech follows the graphical
indicator; retain current agent-shell thresholds as a compatibility fallback."
  (if (fboundp 'agent-shell--context-usage-face)
      (agent-shell--context-usage-face percentage)
    ;; Preserve useful contrast with agent-shell releases predating the helper.
    (cond
     ((>= percentage 85) 'agent-shell-error)
     ((>= percentage 60) 'agent-shell-warning)
     (t 'agent-shell-success))))

(defun emacspeak-agent-shell--header-status-face (status)
  "Return the semantic viewport face for spoken STATUS."
  (pcase status
    ((or "edit" "edit queue") 'agent-shell-viewport-status-edit)
    ("busy" 'agent-shell-viewport-status-busy)
    ("view" 'agent-shell-viewport-status-view)))

(defun emacspeak-agent-shell--format-full-header (state)
  "Return a voiced full spoken description of semantic header STATE."
  (let ((parts
         (delq
          nil
          (list
           (when-let* ((agent (plist-get state :agent)))
             (propertize agent 'face 'agent-shell-buffer-name))
           (when-let* ((project (plist-get state :project)))
             (propertize (format "Project %s" project)
                         'face 'agent-shell-session-directory))
           (when (and (plist-get state :busy)
                      (not (plist-get state :viewport-status)))
             (propertize "Busy" 'face 'agent-shell-warning))
           (when-let* ((position (plist-get state :viewport-position)))
             (format "Viewport %s" position))
           (when-let* ((status (plist-get state :viewport-status)))
             (propertize
              (concat (upcase (substring status 0 1))
                      (substring status 1))
              'face (emacspeak-agent-shell--header-status-face status)))
           (when-let* ((model (plist-get state :model)))
             (propertize (format "Model %s" model)
                         'face 'agent-shell-model))
           (when-let* ((thought (plist-get state :thought-level)))
             (propertize (format "Thought level %s" thought)
                         'face 'agent-shell-thought-level))
           (when-let* ((mode (plist-get state :mode)))
             (propertize (format "Mode %s" mode)
                         'face 'agent-shell-session-mode))
           (when-let* ((percentage
                        (plist-get state :context-percentage)))
             (propertize
              (format "Context %d percent" percentage)
              'face
              (emacspeak-agent-shell--header-context-face percentage)))
           (when-let* ((session-id (plist-get state :session-id)))
             (propertize (format "Session ID %s" session-id)
                         'face 'agent-shell-session-id))))))
    (when parts
      (concat (mapconcat #'identity parts ". ") "."))))

(defun emacspeak-agent-shell--unspoken-graphical-header-p ()
  "Return non-nil when the current agent header has no speakable text."
  (and header-line-format
       (derived-mode-p 'agent-shell-mode
                       'agent-shell-viewport-view-mode
                       'agent-shell-viewport-edit-mode)
       (string-empty-p
        (string-trim
         (substring-no-properties
          (or (format-mode-line header-line-format) ""))))))

(defun emacspeak-agent-shell--speak-focus-header-if-needed ()
  "Speak the concise semantic header when its graphical form is inaccessible.
Return non-nil when an announcement was delivered."
  (when (emacspeak-agent-shell--unspoken-graphical-header-p)
    (when-let* ((state (emacspeak-agent-shell--header-state))
                (speech
                 (emacspeak-agent-shell--format-brief-header state)))
      (emacspeak-icon 'item)
      (dtk-notify speech)
      t)))

(defun emacspeak-agent-shell-speak-header ()
  "Speak the full semantic header for the current agent-shell session."
  (interactive)
  (let* ((state
          (or (emacspeak-agent-shell--header-state)
              (user-error "Agent header state is unavailable")))
         (speech (emacspeak-agent-shell--format-full-header state)))
    (dtk-stop)
    (emacspeak-icon 'item)
    (dtk-speak speech)))

(defun emacspeak-agent-shell--next-speech-level (level)
  "Return the speech level following LEVEL in the interactive cycle."
  (or (cadr (memq level emacspeak-agent-shell--speech-level-cycle))
      (car emacspeak-agent-shell--speech-level-cycle)))

(defun emacspeak-agent-shell--read-speech-level
    (prompt current &optional include-auto)
  "Read a speech level with PROMPT, defaulting to CURRENT.
When INCLUDE-AUTO is non-nil, include the automatic focus-aware choice."
  (let* ((choices
          (if include-auto
              emacspeak-agent-shell--speech-level-choices
            (cdr emacspeak-agent-shell--speech-level-choices)))
         (default (or (car (rassq current choices)) (caar choices)))
         (selected
          (completing-read
           (format-prompt prompt default)
           (mapcar #'car choices)
           nil t nil nil default)))
    (alist-get selected choices nil nil #'string=)))

(defun emacspeak-agent-shell--set-session-speech-level
    (shell-buffer level)
  "Set SHELL-BUFFER's speech override to LEVEL and announce the result."
  (let ((label (emacspeak-agent-shell--session-label shell-buffer))
        announcement)
    (with-current-buffer shell-buffer
      (setq-local emacspeak-agent-shell-speech-level level)
      (when (memq level '(notify quiet))
        (emacspeak-agent-shell--cancel-pending-speech))
      (setq announcement
            (if (eq level 'auto)
                (format "Agent speech automatic: %s when focused, %s in background."
                        emacspeak-agent-shell-foreground-speech-level
                        emacspeak-agent-shell-background-speech-level)
              (format "Agent speech %s for %s." level label))))
    (emacspeak-icon (if (eq level 'quiet) 'off 'select-object))
    (dtk-speak announcement)
    level))

(defun emacspeak-agent-shell-select-speech-level ()
  "Select the automatic speech level for the current agent-shell session."
  (interactive)
  (let ((shell-buffer (emacspeak-agent-shell--session-buffer)))
    (emacspeak-agent-shell--set-session-speech-level
     shell-buffer
     (with-current-buffer shell-buffer
       (emacspeak-agent-shell--read-speech-level
        "Session speech level" emacspeak-agent-shell-speech-level t)))))

(defun emacspeak-agent-shell--cancel-background-pending-speech ()
  "Cancel queued speech affected by a non-content background default."
  (dolist (buffer (buffer-list))
    (when (buffer-live-p buffer)
      (with-current-buffer buffer
        (when (and (derived-mode-p 'agent-shell-mode)
                   (eq emacspeak-agent-shell-speech-level 'auto)
                   (not (emacspeak-agent-shell--session-focused-p buffer)))
          (emacspeak-agent-shell--cancel-pending-speech))))))

(defun emacspeak-agent-shell-select-background-speech-level ()
  "Select the automatic speech level shared by background sessions."
  (interactive)
  (let ((level
         (emacspeak-agent-shell--read-speech-level
          "Background speech level"
          emacspeak-agent-shell-background-speech-level)))
    (setq emacspeak-agent-shell-background-speech-level level)
    (when (memq level '(notify quiet))
      (emacspeak-agent-shell--cancel-background-pending-speech))
    (emacspeak-icon (if (eq level 'quiet) 'off 'select-object))
    (dtk-speak (format "Background agent speech %s." level))))

(defun emacspeak-agent-shell-cycle-speech-level (&optional reset)
  "Cycle automatic speech for the current agent-shell session.
Cycle from the effective level toward less speech: full, response, notify,
quiet, then full again.  With prefix argument RESET, restore `auto' so focus
selects the configured foreground or background level."
  (interactive "P")
  (let ((shell-buffer (emacspeak-agent-shell--session-buffer)))
    (emacspeak-agent-shell--set-session-speech-level
     shell-buffer
     (if reset
         'auto
       (emacspeak-agent-shell--next-speech-level
        (emacspeak-agent-shell--effective-speech-level shell-buffer))))))

(defvar emacspeak-agent-shell--speech-control-map
  (make-sparse-keymap)
  "Keymap for agent-shell speech-level controls.")

(defun emacspeak-agent-shell--install-speech-control-bindings ()
  "Install current speech controls, including when this file is reloaded."
  (define-key emacspeak-agent-shell--speech-control-map (kbd "C-c C-q")
              #'emacspeak-agent-shell-select-speech-level)
  (define-key emacspeak-agent-shell--speech-control-map (kbd "C-c C-S-q")
              #'emacspeak-agent-shell-select-background-speech-level)
  (define-key emacspeak-agent-shell--speech-control-map (kbd "C-c C-b")
              #'emacspeak-agent-shell-speak-source-block)
  (define-key emacspeak-agent-shell--speech-control-map (kbd "C-c C-y")
              #'emacspeak-agent-shell-copy-source-block)
  (define-key emacspeak-agent-shell--speech-control-map (kbd "C-c ]")
              #'emacspeak-agent-shell-next-block-of-type)
  (define-key emacspeak-agent-shell--speech-control-map (kbd "C-c [")
              #'emacspeak-agent-shell-previous-block-of-type)
  (define-key emacspeak-agent-shell--speech-control-map (kbd "]")
              #'emacspeak-agent-shell-next-block-at-point)
  (define-key emacspeak-agent-shell--speech-control-map (kbd "[")
              #'emacspeak-agent-shell-previous-block-at-point))

(emacspeak-agent-shell--install-speech-control-bindings)

(unless (assq 'emacspeak-agent-shell--speech-control-active
              minor-mode-map-alist)
  (push (cons 'emacspeak-agent-shell--speech-control-active
              emacspeak-agent-shell--speech-control-map)
        minor-mode-map-alist))

(defun emacspeak-agent-shell--should-speak-p (buffer)
  "Determine if content should be spoken for BUFFER."
  (cl-declare (special emacspeak-comint-autospeak))
  (with-current-buffer buffer
    (and (bound-and-true-p emacspeak-comint-autospeak)
         (emacspeak-agent-shell--speech-level-at-least-p
          'response buffer))))

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
    (emacspeak-agent-shell--deliver-announcement
     'warn-user
     (emacspeak-agent-shell--permission-announcement event))))

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
        (emacspeak-agent-shell--deliver-announcement
         'close-object "Permission cancelled."))
       ((equal kind "reject_once")
        (emacspeak-agent-shell--deliver-announcement
         'close-object
         (format "Permission denied: %s." (or option "Reject"))))
       ((member kind '("allow_once" "allow_always"))
        (emacspeak-agent-shell--deliver-announcement
         'select-object
         (format "Permission granted: %s." (or option "Allow"))))
       (t
        (emacspeak-agent-shell--deliver-announcement
         'select-object "Permission response sent."))))))

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
    (emacspeak-agent-shell--deliver-announcement
     'warn-user
     (if detail
         (format "Agent error: %s" detail)
       "Agent error."))))

(defun emacspeak-agent-shell--speak-turn-completion (event)
  "Announce the outcome described by turn completion EVENT."
  (let ((stop-reason (map-nested-elt event '(:data :stop-reason))))
    (if (equal stop-reason "end_turn")
        (when (emacspeak-agent-shell--speech-level-at-least-p 'notify)
          (if (emacspeak-agent-shell--session-focused-p)
              (emacspeak-icon emacspeak-agent-shell-processing-end-icon)
            (dtk-notify-icon emacspeak-agent-shell-processing-end-icon)
            (dtk-notify
             (format "%s finished."
                     (emacspeak-agent-shell--session-label)))))
      (emacspeak-agent-shell--discard-pending-blocks "-stop-reason$")
      (pcase stop-reason
        ("cancelled"
         (emacspeak-agent-shell--deliver-announcement
          'close-object "Agent turn cancelled."))
        ("max_tokens"
         (emacspeak-agent-shell--deliver-announcement
          'warn-user "Agent stopped: maximum token limit reached."))
        ("max_turn_requests"
         (emacspeak-agent-shell--deliver-announcement
          'warn-user "Agent stopped: request limit reached."))
        ("refusal"
         (emacspeak-agent-shell--deliver-announcement
          'warn-user "Agent refused the request."))
        ((pred stringp)
         (emacspeak-agent-shell--deliver-announcement
          'warn-user
          (format "Agent stopped: %s."
                  (string-replace "_" " " stop-reason))))
        (_
         (emacspeak-agent-shell--deliver-announcement
          'warn-user "Agent stopped for an unknown reason."))))))

(defun emacspeak-agent-shell--handle-lifecycle-event (event)
  "Provide semantic processing feedback for public agent-shell EVENT."
  (when (and (memq (map-elt event :event) '(turn-complete error))
             (hash-table-p emacspeak-agent-shell--tool-call-status-cache))
    (clrhash emacspeak-agent-shell--tool-call-status-cache))
  (when emacspeak-agent-shell-signal-processing
    (pcase (map-elt event :event)
      ((or 'init-started 'input-submitted)
       (when (emacspeak-agent-shell--speech-level-at-least-p 'full)
         (emacspeak-icon emacspeak-agent-shell-processing-start-icon)))
      ('init-finished
       (when (emacspeak-agent-shell--speech-level-at-least-p 'full)
         (emacspeak-icon emacspeak-agent-shell-processing-end-icon)))
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
      (when (emacspeak-agent-shell--should-speak-p buffer)
        (dolist (qualified-id qualified-ids)
          (when-let* ((content (and emacspeak-agent-shell--pending-bodies
                                    (gethash
                                     qualified-id
                                     emacspeak-agent-shell--pending-bodies)))
                      (block-id
                       (if (string-match "-\\([^-]+\\)$" qualified-id)
                           (match-string 1 qualified-id)
                         qualified-id))
                      (block-type
                       (emacspeak-agent-shell--classify-block block-id))
                      (trimmed (string-trim content)))
            (when (not (string-empty-p trimmed))
              (emacspeak-agent-shell--speak-content
               trimmed block-type)))))
      (when emacspeak-agent-shell--pending-bodies
        (clrhash emacspeak-agent-shell--pending-bodies))
      (setq emacspeak-agent-shell--pending-speech-qualified-ids nil)
      (setq emacspeak-agent-shell--pending-speech-timer nil))))

(defun emacspeak-agent-shell--classify-block (block-id)
  "Classify BLOCK-ID to determine content type.
Returns one of: \\='agent-message, \\='user-message, \\='thought, 
\\='tool-call, \\='permission, \\='plan, \\='error, or \\='unknown."
  (cond
   ((string-match-p "agent_message_chunk" block-id) 'agent-message)
   ((string-match-p "user_message_chunk" block-id) 'user-message)
   ((string-match-p "agent_thought_chunk" block-id) 'thought)
   ((string-match-p "^permission-" block-id) 'permission)
   ((string-equal block-id "plan") 'plan)
   ((string-match-p "^failed-\\|^Error" block-id) 'error)
   ((and (not (string-match-p "-chunk\\|^permission-\\|^plan\\|^Error\\|^failed-" block-id))
         (> (length block-id) 10)) 'tool-call)
   (t 'unknown)))

(defun emacspeak-agent-shell--speak-content (content block-type)
  "Speak CONTENT based on BLOCK-TYPE with appropriate feedback."
  (cl-declare (special emacspeak-agent-shell-speak-thought-process
                       emacspeak-agent-shell-speak-tool-calls
                       emacspeak-agent-shell-speak-permissions
                       emacspeak-agent-shell-tool-output-verbosity))
  (let ((trimmed-content (string-trim content)))
    (pcase block-type
      ('agent-message
       (when (emacspeak-agent-shell--speech-level-at-least-p 'response)
         (dtk-speak trimmed-content)))
      ('user-message
       (when (emacspeak-agent-shell--speech-level-at-least-p 'full)
         (emacspeak-icon 'item)
         (dtk-speak (concat "User: " trimmed-content))))
      ('thought
       (when (emacspeak-agent-shell--speech-level-at-least-p 'full)
         (pcase emacspeak-agent-shell-speak-thought-process
           ('speak (dtk-speak (concat "Thinking: " trimmed-content)))
           ('icon (emacspeak-icon 'progress))
           (_ nil))))
      ('permission
       (when emacspeak-agent-shell-speak-permissions
         (emacspeak-agent-shell--deliver-announcement
          'warn-user trimmed-content)))
      ('tool-call
       (when (and emacspeak-agent-shell-speak-tool-calls
                  (emacspeak-agent-shell--speech-level-at-least-p 'full))
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
       (when (emacspeak-agent-shell--speech-level-at-least-p 'response)
         (emacspeak-icon 'item)
         (dtk-speak (concat "Plan: " trimmed-content))))
      ('error
       (emacspeak-agent-shell--deliver-announcement
        'warn-user trimmed-content))
      ('unknown
       (cond
        ((emacspeak-agent-shell--speech-level-at-least-p 'full)
         (dtk-speak trimmed-content))
        ((emacspeak-agent-shell--speech-level-at-least-p 'response)
         (dtk-speak "Additional agent content available."))))
      (_
       ;; Fallback: speak if content is substantial
       (when (and (> (length trimmed-content) 0)
                  (emacspeak-agent-shell--speech-level-at-least-p 'response))
         (dtk-speak trimmed-content))))))

;;;  Advice Agent-Shell Functions

(defadvice dtk-speak (around emacspeak pre act comp)
  "Preserve rendered Markdown properties while speaking agent-shell content.
This changes only the temporary speech string; agent-shell's clipboard handler
and the source buffer remain untouched."
  (ad-set-arg
   0 (emacspeak-agent-shell--prepare-speech-text (ad-get-arg 0)))
  ad-do-it)

(defadvice emacspeak-speak-mode-line (around emacspeak pre act comp)
  "Read the full semantic header when invoked interactively in agent-shell.
Automatic mode-line speech continues through the normal Emacspeak path, as
does an interactive call with a prefix argument for buffer information."
  (let ((buffer-info (ad-get-arg 0))
        (target (window-buffer (selected-window))))
    (if (and (null buffer-info)
             (ems-interactive-p)
             (buffer-live-p target)
             (with-current-buffer target
               (derived-mode-p 'agent-shell-mode
                               'agent-shell-viewport-view-mode
                               'agent-shell-viewport-edit-mode)))
        (with-current-buffer target
          (emacspeak-agent-shell-speak-header))
      ad-do-it)))

(defadvice emacspeak-speak-header-line (around emacspeak pre act comp)
  "Speak semantic agent-shell state when a graphical header has no text."
  (or (emacspeak-agent-shell--speak-focus-header-if-needed)
      ad-do-it))

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

(defconst emacspeak-agent-shell--block-type-choices
  '(("Agent response" . agent-response)
    ("User prompt" . user-prompt)
    ("Thought or reasoning" . thought)
    ("Tool call" . tool-call)
    ("Tool group" . tool-group)
    ("Plan" . plan)
    ("Permission" . permission)
    ("Error" . error)
    ("Table" . table)
    ("Source block" . source-block)
    ("Other" . other))
  "Completion candidates for semantic agent-shell block navigation.")

(defvar emacspeak-agent-shell--block-navigation-type 'agent-response
  "Most recently selected semantic agent-shell block type.")

(defun emacspeak-agent-shell--block-type-label (type)
  "Return the display label for semantic block TYPE."
  (or (car (rassq type emacspeak-agent-shell--block-type-choices))
      "Other"))

(defun emacspeak-agent-shell--read-block-type ()
  "Read and remember a semantic agent-shell block type."
  (let* ((default
          (emacspeak-agent-shell--block-type-label
           emacspeak-agent-shell--block-navigation-type))
         (selection
          (completing-read
           (format-prompt "Block type" default)
           (mapcar #'car emacspeak-agent-shell--block-type-choices)
           nil t nil nil default)))
    (setq emacspeak-agent-shell--block-navigation-type
          (alist-get selection emacspeak-agent-shell--block-type-choices
                    nil nil #'string=))))

(defun emacspeak-agent-shell--semantic-block-type (qualified-id state)
  "Classify QUALIFIED-ID and fragment STATE for navigation.
Agent-shell currently exposes fragment identity but no public semantic type;
keep that compatibility inference isolated here."
  (cond
   ((and (stringp qualified-id)
         (string-match-p "agent_message_chunk\\'" qualified-id))
    'agent-response)
   ((and (stringp qualified-id)
         (string-match-p "user_message_chunk\\'" qualified-id))
    'user-prompt)
   ((and (stringp qualified-id)
         (string-match-p "agent_thought_chunk\\'" qualified-id))
    'thought)
   ((and (stringp qualified-id)
         (string-match-p "permission-" qualified-id))
    'permission)
   ((eq (map-elt state :kind) 'group) 'tool-group)
   ((map-elt state :group-id) 'tool-call)
   ((and (stringp qualified-id)
         (string-match-p "-plan\\'" qualified-id))
    'plan)
   ((and (stringp qualified-id)
         (string-match-p
          "\\(?:failed-\\|Error\\|out-of-turn-acp-bug\\|[Uu]nhandled\\)"
          qualified-id))
    'error)
   (t 'other)))

(defun emacspeak-agent-shell--concise-block-text (text)
  "Return a concise single-line version of block TEXT."
  (when text
    (let ((plain
           (string-trim
            (replace-regexp-in-string
             "[[:space:]]+" " " (substring-no-properties text)))))
      (unless (string-empty-p plain)
        (if (> (length plain) 80)
            (concat (substring plain 0 77) "...")
          plain)))))

(defun emacspeak-agent-shell--block-section-text (start end section)
  "Return text for fragment SECTION between START and END."
  (let ((position start)
        result)
    (while (and (< position end) (not result))
      (let ((next
             (or (next-single-property-change
                  position 'agent-shell-ui-section nil end)
                 end)))
        (when (eq (get-text-property position 'agent-shell-ui-section)
                  section)
          (setq result
                (buffer-substring-no-properties position next)))
        (setq position next)))
    (emacspeak-agent-shell--concise-block-text result)))

(defun emacspeak-agent-shell--block-section-range (start end section)
  "Return the range of fragment SECTION between START and END."
  (let ((position start)
        result)
    (while (and (< position end) (not result))
      (let ((next
             (or (next-single-property-change
                  position 'agent-shell-ui-section nil end)
                 end)))
        (when (eq (get-text-property position 'agent-shell-ui-section)
                  section)
          (setq result (cons position next)))
        (setq position next)))
    result))

(defun emacspeak-agent-shell--visible-block-text (start end)
  "Return complete visible block text between START and END."
  (when (and start end (< start end))
    (let ((text (filter-buffer-substring start end)))
      (setq text (string-trim (substring-no-properties text)))
      (unless (string-empty-p text) text))))

(defun emacspeak-agent-shell--fragment-location (start end state)
  "Return a semantic location for fragment STATE from START to END."
  (let* ((qualified-id (map-elt state :qualified-id))
         (type
          (emacspeak-agent-shell--semantic-block-type qualified-id state))
         (left
          (emacspeak-agent-shell--block-section-text
           start end 'label-left))
         (right
          (emacspeak-agent-shell--block-section-text
           start end 'label-right))
         (indicator
          (text-property-any
           start end 'agent-shell-ui-section 'indicator))
         (label
          (emacspeak-agent-shell--concise-block-text
           (string-join (delq nil (list left right)) " ")))
         (body-range
          (emacspeak-agent-shell--block-section-range start end 'body))
         (body
          (if body-range
              (emacspeak-agent-shell--visible-block-text
               (car body-range) (cdr body-range))
            (when (eq type 'user-prompt)
              (emacspeak-agent-shell--visible-block-text start end)))))
    (list :position start
          :end end
          :type type
          :state state
          :label label
          :body body
          :fold-state
          (when indicator
            (if (map-elt state :collapsed) "collapsed" "expanded")))))

(defun emacspeak-agent-shell--fragment-locations ()
  "Return semantic locations for all agent-shell UI fragments."
  (let ((position (point-min))
        locations)
    (while (< position (point-max))
      (let* ((state (get-text-property position 'agent-shell-ui-state))
             (next
              (or (next-single-property-change
                   position 'agent-shell-ui-state nil (point-max))
                  (point-max))))
        (when (and state (< position next))
          (push (emacspeak-agent-shell--fragment-location
                 position next state)
                locations))
        (setq position next)))
    (nreverse locations)))

(defun emacspeak-agent-shell--face-includes-p (value face)
  "Return non-nil when face specification VALUE includes FACE."
  (or (eq value face)
      (and (listp value) (memq face value))))

(defun emacspeak-agent-shell--prompt-locations ()
  "Return semantic user-prompt locations in the current buffer."
  (let (locations)
    (dolist (property '(agent-shell-viewport-prompt font-lock-face face))
      (let ((position (point-min)))
        (while (< position (point-max))
          (let* ((value (get-text-property position property))
                 (next
                  (or (next-single-property-change
                       position property nil (point-max))
                      (point-max)))
                 (prompt-p
                  (if (eq property 'agent-shell-viewport-prompt)
                      value
                    (emacspeak-agent-shell--face-includes-p
                     value 'agent-shell-prompt)))
                 (body-end
                  (when prompt-p
                    (if (eq property 'agent-shell-viewport-prompt)
                        next
                      (or (text-property-any
                           next (point-max) 'shell-maker--marker t)
                          (point-max))))))
            (when prompt-p
              (push
               (list :position position
                     :end body-end
                     :type 'user-prompt
                     :body
                     (emacspeak-agent-shell--visible-block-text
                      position body-end))
               locations))
            (setq position next)))))
    (nreverse locations)))

(defun emacspeak-agent-shell--table-locations ()
  "Return semantic locations for rendered Markdown tables."
  (let ((position (point-min))
        locations)
    (while (< position (point-max))
      (let* ((source
              (get-text-property
               position 'agent-shell-markdown-table-source))
             (next
              (or (next-single-property-change
                   position 'agent-shell-markdown-table-source
                   nil (point-max))
                  (point-max))))
        (when source
          (when-let ((cell
                      (text-property-any
                       position next
                       'agent-shell-markdown-table-cell-start t)))
            (push (list :position cell
                        :start position
                        :end next
                        :type 'table
                        :state
                        (get-text-property cell 'agent-shell-ui-state))
                  locations)))
        (setq position next)))
    (nreverse locations)))

(defun emacspeak-agent-shell--source-block-language (source)
  "Return the fenced code language recorded in Markdown SOURCE."
  (when (and (stringp source)
             (string-match
              "\\`[ \t]*`\\{3,\\}[ \t]*\\([[:alnum:]+#-]*\\)"
              source))
    (emacspeak-agent-shell--nonempty-text (match-string 1 source))))

(defun emacspeak-agent-shell--source-block-panel-start (body-start)
  "Return the rendered panel start preceding BODY-START."
  (let ((start body-start))
    (while (and (> start (point-min))
                (stringp
                 (get-text-property
                  (1- start) 'agent-shell-markdown-source)))
      (setq start
            (or (previous-single-property-change
                 start 'agent-shell-markdown-source nil (point-min))
                (point-min))))
    start))

(defun emacspeak-agent-shell--source-block-panel-end (body-end)
  "Return the rendered panel end following BODY-END."
  (let ((end body-end))
    (while (and (< end (point-max))
                (stringp
                 (get-text-property end 'agent-shell-markdown-source)))
      (setq end
            (or (next-single-property-change
                 end 'agent-shell-markdown-source nil (point-max))
                (point-max))))
    end))

(defun emacspeak-agent-shell--source-block-line-count (body)
  "Return the number of logical lines in source block BODY."
  (if (or (not (stringp body)) (string-empty-p body))
      0
    (let ((lines 1)
          (position 0))
      (while (string-match "\n" body position)
        (setq lines (1+ lines)
              position (match-end 0)))
      lines)))

(defun emacspeak-agent-shell--source-block-locations ()
  "Return semantic locations for rendered Markdown source blocks."
  (let ((position (point-min))
        locations)
    (while (< position (point-max))
      (let* ((body-p
              (get-text-property
               position 'agent-shell-markdown-source-block-body))
             (next
              (or (next-single-property-change
                   position 'agent-shell-markdown-source-block-body
                   nil (point-max))
                  (point-max))))
        (when body-p
          (let* ((source
                  (get-text-property
                   position 'agent-shell-markdown-source))
                 (body
                  (agent-shell-markdown-source-block-at-point position)))
            (push
             (list
              :position position
              :start
              (emacspeak-agent-shell--source-block-panel-start position)
              :end (emacspeak-agent-shell--source-block-panel-end next)
              :type 'source-block
              :state (get-text-property position 'agent-shell-ui-state)
              :language
              (emacspeak-agent-shell--source-block-language source)
              :line-count
              (emacspeak-agent-shell--source-block-line-count body)
              :body body)
             locations)))
        (setq position next)))
    (nreverse locations)))

(defun emacspeak-agent-shell--deduplicate-block-locations (locations)
  "Return LOCATIONS without duplicate type/position pairs."
  (let (seen result)
    (dolist (location locations)
      (let ((key (cons (plist-get location :type)
                       (plist-get location :position))))
        (unless (member key seen)
          (push key seen)
          (push location result))))
    (nreverse result)))

(defun emacspeak-agent-shell--block-locations ()
  "Return all semantic transcript block locations in buffer order."
  (let* ((fragments (emacspeak-agent-shell--fragment-locations))
         (prompts (emacspeak-agent-shell--prompt-locations))
         (tables (emacspeak-agent-shell--table-locations))
         (source-blocks
          (emacspeak-agent-shell--source-block-locations))
         (locations (append fragments prompts tables source-blocks)))
    ;; A restored viewport normally retains response fragment state.  Keep a
    ;; whole-response fallback for older or plain viewport content.
    (when (and (derived-mode-p 'agent-shell-viewport-view-mode)
               (not (seq-find
                     (lambda (item)
                       (eq (plist-get item :type) 'agent-response))
                     fragments)))
      (when-let* ((prompt (car (last prompts)))
                  (start (plist-get prompt :end))
                  (response
                   (save-excursion
                     (goto-char start)
                     (skip-chars-forward " \\t\\n\\r")
                     (and (< (point) (point-max)) (point)))))
        (push (list :position response
                    :end (point-max)
                    :type 'agent-response
                    :body
                    (emacspeak-agent-shell--visible-block-text
                     response (point-max)))
              locations)))
    (sort (emacspeak-agent-shell--deduplicate-block-locations locations)
          (lambda (left right)
            (< (plist-get left :position)
               (plist-get right :position))))))

(defun emacspeak-agent-shell--expand-block-parent (location)
  "Expand LOCATION's collapsed parent group when necessary."
  (when-let* ((state (plist-get location :state))
              (group-id (map-elt state :group-id))
              ((invisible-p (plist-get location :position)))
              (parent
               (seq-find
                (lambda (candidate)
                  (equal
                   (map-elt (plist-get candidate :state) :qualified-id)
                   group-id))
                (emacspeak-agent-shell--fragment-locations)))
              (parent-state (plist-get parent :state))
              ((map-elt parent-state :collapsed)))
    (goto-char (plist-get parent :position))
    (agent-shell-ui-toggle-fragment)))

(defun emacspeak-agent-shell--source-block-summary (location)
  "Return a concise spoken summary of source block LOCATION."
  (let ((language (plist-get location :language))
        (lines (plist-get location :line-count)))
    (if language
        (format "%s source block, %d %s."
                language lines (if (= lines 1) "line" "lines"))
      (format "Source block, %d %s."
              lines (if (= lines 1) "line" "lines")))))

(defun emacspeak-agent-shell--source-block-speech (location)
  "Return full voiced speech for source block LOCATION."
  (concat
   (propertize
    (emacspeak-agent-shell--source-block-summary location)
    'face 'agent-shell-markdown-source-block-language)
   " "
   (propertize
    (or (plist-get location :body) "")
    'face 'agent-shell-markdown-source-block)))

(defun emacspeak-agent-shell--block-location-speech (location)
  "Return complete semantic speech for block LOCATION."
  (let* ((label (plist-get location :label))
         (body (plist-get location :body))
         (fallback
          (or label
              (emacspeak-agent-shell--block-type-label
               (plist-get location :type)))))
    (if body
        (string-join (delq nil (list label body)) ". ")
      (concat
       (string-join
        (delq nil (list fallback (plist-get location :fold-state))) ", ")
       "."))))

(defun emacspeak-agent-shell--jump-block-of-type
    (type direction &optional origin)
  "Move to semantic block TYPE in DIRECTION and announce it.
Use ORIGIN instead of point as the navigation boundary when non-nil."
  (unless (derived-mode-p 'agent-shell-mode
                          'agent-shell-viewport-view-mode)
    (user-error "Not in an agent-shell transcript"))
  (let* ((locations
          (seq-filter
           (lambda (location) (eq (plist-get location :type) type))
           (emacspeak-agent-shell--block-locations)))
         (origin (or origin (point)))
         (target
          (if (eq direction 'forward)
              (seq-find
               (lambda (location)
                 (> (plist-get location :position) origin))
               locations)
            (car
             (last
              (seq-take-while
               (lambda (location)
                 (if (memq type '(table source-block))
                     (<= (plist-get location :end) origin)
                   (< (plist-get location :position) origin)))
               locations))))))
    (if target
        (progn
          (emacspeak-agent-shell--expand-block-parent target)
          (goto-char (plist-get target :position))
          (dtk-stop)
          (pcase type
            ('table
             (emacspeak-agent-shell--table-entry-feedback direction))
            ('source-block
             (emacspeak-icon 'open-object)
             (dtk-speak
              (emacspeak-agent-shell--source-block-summary target)))
            (_
             (emacspeak-icon 'large-movement)
             (dtk-speak
              (emacspeak-agent-shell--block-location-speech target))))
          target)
      (emacspeak-icon 'warn-user)
      (dtk-speak
       (format "No %s %s%s."
               (if (eq direction 'forward) "later" "earlier")
               (downcase (emacspeak-agent-shell--block-type-label type))
               (if (eq type 'source-block) "" " block")))
      nil)))

(defun emacspeak-agent-shell--block-location-at-point (&optional position)
  "Return the innermost semantic block containing POSITION or point.
Rendered tables and source blocks win ties with enclosing transcript blocks."
  (setq position (or position (point)))
  (car
   (sort
    (seq-filter
     (lambda (location)
       (let ((start (or (plist-get location :start)
                        (plist-get location :position)))
             (end (plist-get location :end)))
         (and start end (<= start position) (< position end))))
     (emacspeak-agent-shell--block-locations))
    (lambda (left right)
      (let ((left-size
             (- (plist-get left :end)
                (or (plist-get left :start)
                    (plist-get left :position))))
            (right-size
             (- (plist-get right :end)
                (or (plist-get right :start)
                    (plist-get right :position)))))
        (or (< left-size right-size)
            (and (= left-size right-size)
                 (memq (plist-get left :type) '(table source-block))
                 (not
                  (memq (plist-get right :type)
                        '(table source-block))))))))))

(defun emacspeak-agent-shell--source-block-at-point ()
  "Return the semantic source block containing point, or signal an error."
  (let ((location (emacspeak-agent-shell--block-location-at-point)))
    (unless (eq (plist-get location :type) 'source-block)
      (user-error "Not in a rendered source block"))
    location))

(defun emacspeak-agent-shell-speak-source-block ()
  "Read the complete rendered Markdown source block at point."
  (interactive)
  (let ((location (emacspeak-agent-shell--source-block-at-point)))
    (dtk-stop)
    (emacspeak-icon 'item)
    (dtk-speak (emacspeak-agent-shell--source-block-speech location))))

(defun emacspeak-agent-shell-copy-source-block ()
  "Copy the rendered Markdown source block at point using agent-shell."
  (interactive)
  (let ((location (emacspeak-agent-shell--source-block-at-point)))
    (emacspeak-icon 'yank-object)
    (agent-shell-copy-source-block-at-point
     (plist-get location :position))))

(defun emacspeak-agent-shell--literal-character-input-p ()
  "Return non-nil when this command key should insert at an editable prompt."
  (and (integerp last-command-event)
       (> (length (this-command-keys-vector)) 0)
       (eq (key-binding (this-command-keys-vector)) this-command)
       (or (derived-mode-p 'agent-shell-viewport-edit-mode)
           (and (derived-mode-p 'agent-shell-mode)
                (not (shell-maker-busy))
                (shell-maker-point-at-last-prompt-p)))))

(defun emacspeak-agent-shell--navigate-block-at-point (direction)
  "Navigate in DIRECTION using the semantic block containing point."
  (if (emacspeak-agent-shell--literal-character-input-p)
      (self-insert-command 1)
    (if-let* ((location (emacspeak-agent-shell--block-location-at-point))
              (type (plist-get location :type)))
        (progn
          (setq emacspeak-agent-shell--block-navigation-type type)
          (when (emacspeak-agent-shell--jump-block-of-type
                 type direction (plist-get location :position))
            (emacspeak-agent-shell--activate-block-repeat-map)))
      (emacspeak-icon 'warn-user)
      (dtk-speak "No semantic block at point."))))

(defvar emacspeak-agent-shell--block-repeat-map
  (make-sparse-keymap)
  "Temporary map for repeating semantic block navigation.")

(defun emacspeak-agent-shell--install-block-repeat-bindings ()
  "Install reload-safe semantic block repeat keys."
  (define-key emacspeak-agent-shell--block-repeat-map (kbd "]")
              #'emacspeak-agent-shell-repeat-next-block)
  (define-key emacspeak-agent-shell--block-repeat-map (kbd "[")
              #'emacspeak-agent-shell-repeat-previous-block))

(emacspeak-agent-shell--install-block-repeat-bindings)

(defun emacspeak-agent-shell--activate-block-repeat-map ()
  "Activate temporary bracket bindings for semantic block repetition."
  (set-transient-map emacspeak-agent-shell--block-repeat-map t))

(defun emacspeak-agent-shell-next-block-of-type ()
  "Select a semantic block type and move to its next occurrence."
  (interactive)
  (when (emacspeak-agent-shell--jump-block-of-type
         (emacspeak-agent-shell--read-block-type) 'forward)
    (emacspeak-agent-shell--activate-block-repeat-map)))

(defun emacspeak-agent-shell-previous-block-of-type ()
  "Select a semantic block type and move to its previous occurrence."
  (interactive)
  (when (emacspeak-agent-shell--jump-block-of-type
         (emacspeak-agent-shell--read-block-type) 'backward)
    (emacspeak-agent-shell--activate-block-repeat-map)))

(defun emacspeak-agent-shell-next-block-at-point ()
  "Move to the next block matching the semantic block at point.
When invoked by `]' at an editable prompt, insert that character instead."
  (interactive)
  (emacspeak-agent-shell--navigate-block-at-point 'forward))

(defun emacspeak-agent-shell-previous-block-at-point ()
  "Move to the previous block matching the semantic block at point.
When invoked by `[' at an editable prompt, insert that character instead."
  (interactive)
  (emacspeak-agent-shell--navigate-block-at-point 'backward))

(defun emacspeak-agent-shell-repeat-next-block ()
  "Move to the next occurrence of the selected semantic block type."
  (interactive)
  (when (emacspeak-agent-shell--jump-block-of-type
         emacspeak-agent-shell--block-navigation-type 'forward)
    (emacspeak-agent-shell--activate-block-repeat-map)))

(defun emacspeak-agent-shell-repeat-previous-block ()
  "Move to the previous occurrence of the selected semantic block type."
  (interactive)
  (when (emacspeak-agent-shell--jump-block-of-type
         emacspeak-agent-shell--block-navigation-type 'backward)
    (emacspeak-agent-shell--activate-block-repeat-map)))

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
      (setq emacspeak-agent-shell--table-navigation-active t
            emacspeak-agent-shell--table-navigation-table-start (car region))
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

(defun emacspeak-agent-shell-table-speak-cell ()
  "Speak the logical Markdown table cell at point."
  (interactive)
  (unless (emacspeak-agent-shell--table-cell-feedback)
    (user-error "Not in a rendered Markdown table")))

(defun emacspeak-agent-shell-table-speak-dimensions ()
  "Speak the dimensions of the Markdown table at point."
  (interactive)
  (if-let ((cell (emacspeak-agent-shell--markdown-table-cell-at-point)))
      (progn
        (emacspeak-icon 'item)
        (dtk-speak (emacspeak-agent-shell--table-dimensions-speech cell)))
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
(defun emacspeak-agent-shell--table-plain-cell (data)
  "Return table cell DATA without padding or text properties."
  (substring-no-properties (string-trim (or data ""))))

(defun emacspeak-agent-shell--table-copy (text object)
  "Copy plain TEXT to the kill ring and announce copied table OBJECT."
  (kill-new (substring-no-properties text))
  (emacspeak-icon 'save-object)
  (dtk-speak (format "Copied table %s." object)))

(defun emacspeak-agent-shell-table-copy-cell ()
  "Copy the logical Markdown table cell at point to the kill ring.
Remove renderer padding, borders, and text properties.  Preserve the complete
logical value of a wrapped cell."
  (interactive)
  (if-let ((cell (emacspeak-agent-shell--markdown-table-cell-at-point)))
      (emacspeak-agent-shell--table-copy
       (emacspeak-agent-shell--table-plain-cell (plist-get cell :data))
       "cell")
    (user-error "Not in a rendered Markdown table")))

(defun emacspeak-agent-shell-table-copy-row ()
  "Copy the logical Markdown table row at point to the kill ring.
Separate cells with tabs and omit Markdown separator syntax."
  (interactive)
  (if-let* ((cell (emacspeak-agent-shell--markdown-table-cell-at-point))
            (row (nth (plist-get cell :row-index)
                      (plist-get cell :rows))))
      (emacspeak-agent-shell--table-copy
       (mapconcat #'emacspeak-agent-shell--table-plain-cell row "\t")
       "row")
    (user-error "Not in a rendered Markdown table")))

(defun emacspeak-agent-shell-table-copy-column ()
  "Copy the logical Markdown table column at point to the kill ring.
Separate cells with newlines and omit Markdown separator syntax."
  (interactive)
  (if-let ((cell (emacspeak-agent-shell--markdown-table-cell-at-point)))
      (let ((column (plist-get cell :column-index)))
        (emacspeak-agent-shell--table-copy
         (mapconcat
          (lambda (row)
            (emacspeak-agent-shell--table-plain-cell (nth column row)))
          (plist-get cell :rows)
          "\n")
         "column"))
    (user-error "Not in a rendered Markdown table")))

(defun emacspeak-agent-shell--table-cell-position (cell row column)
  "Return the rendered position for ROW and COLUMN relative to CELL.
Return nil when that logical cell does not exist."
  (let* ((rows (plist-get cell :rows))
         (region (emacspeak-agent-shell--markdown-table-region-at-point))
         (starts
          (and region
               (emacspeak-agent-shell--markdown-table-cell-starts region)))
         (target-row (nth row rows)))
    (when (and target-row (<= 0 column) (< column (length target-row)))
      (nth (+ column
              (apply #'+ (mapcar #'length (seq-take rows row))))
           starts))))

(defun emacspeak-agent-shell--table-boundary-feedback (message)
  "Play a boundary cue and speak MESSAGE."
  (emacspeak-icon 'warn-user)
  (dtk-speak message))

(defun emacspeak-agent-shell--table-exit-destination (region direction)
  "Return a useful point outside table REGION in DIRECTION."
  (pcase direction
    ('backward
     (when (> (car region) (point-min))
       (save-excursion
         (goto-char (car region))
         (backward-char 1)
         (skip-chars-backward " \t\n\r")
         (beginning-of-line)
         (back-to-indentation)
         (point))))
    ('forward
     (when (< (cdr region) (point-max))
       (save-excursion
         (goto-char (cdr region))
         (skip-chars-forward " \t\n\r")
         (back-to-indentation)
         (point))))))

(defun emacspeak-agent-shell--table-exit (direction)
  "Leave the rendered table at point in DIRECTION and speak the destination."
  (if-let* ((region (emacspeak-agent-shell--markdown-table-region-at-point))
            (destination
             (emacspeak-agent-shell--table-exit-destination region direction)))
      (progn
        (goto-char destination)
        (setq emacspeak-agent-shell--table-navigation-active nil
              emacspeak-agent-shell--table-navigation-table-start nil)
        (emacspeak-icon 'close-object)
        (let ((line
               (string-trim
                (buffer-substring-no-properties
                 (line-beginning-position) (line-end-position)))))
          (dtk-speak
           (format "%s table.%s"
                   (if (eq direction 'backward) "Before" "After")
                   (if (string-empty-p line) "" (concat " " line))))))
    (emacspeak-agent-shell--table-boundary-feedback
     (format "No content %s table."
             (if (eq direction 'backward) "before" "after")))))

(defun emacspeak-agent-shell-table-exit-backward ()
  "Leave the current Markdown table and move to preceding content."
  (interactive)
  (emacspeak-agent-shell--table-exit 'backward))

(defun emacspeak-agent-shell-table-exit-forward ()
  "Leave the current Markdown table and move to following content."
  (interactive)
  (emacspeak-agent-shell--table-exit 'forward))

(defun emacspeak-agent-shell--table-move (row-delta column-delta)
  "Move by ROW-DELTA and COLUMN-DELTA in the logical table at point."
  (if-let ((cell (emacspeak-agent-shell--markdown-table-cell-at-point)))
      (let* ((row (plist-get cell :row-index))
             (column (plist-get cell :column-index))
             (rows (plist-get cell :rows))
             (target-row (+ row row-delta))
             (target-column (+ column column-delta)))
        (cond
         ((< target-row 0)
          (emacspeak-agent-shell--table-exit 'backward))
         ((>= target-row (length rows))
          (emacspeak-agent-shell--table-exit 'forward))
         ((< target-column 0)
          (emacspeak-agent-shell--table-boundary-feedback
           "Left edge of table."))
         ((>= target-column (length (nth target-row rows)))
          (emacspeak-agent-shell--table-boundary-feedback
           (if (zerop row-delta)
               "Right edge of table."
             "No cell in that row.")))
         (t
          (if-let ((target
                    (emacspeak-agent-shell--table-cell-position
                     cell target-row target-column)))
              (progn
                (goto-char target)
                (emacspeak-agent-shell--table-cell-feedback))
            (emacspeak-agent-shell--table-boundary-feedback
             "No rendered cell at that position.")))))
    (user-error "Not in a rendered Markdown table")))

(defun emacspeak-agent-shell-table-next-column (&optional count)
  "Move COUNT columns right in the current logical Markdown table row."
  (interactive "p")
  (emacspeak-agent-shell--table-move 0 (or count 1)))

(defun emacspeak-agent-shell-table-previous-column (&optional count)
  "Move COUNT columns left in the current logical Markdown table row."
  (interactive "p")
  (emacspeak-agent-shell--table-move 0 (- (or count 1))))

(defun emacspeak-agent-shell-table-next-row (&optional count)
  "Move COUNT logical Markdown table rows down, retaining the column."
  (interactive "p")
  (emacspeak-agent-shell--table-move (or count 1) 0))

(defun emacspeak-agent-shell-table-previous-row (&optional count)
  "Move COUNT logical Markdown table rows up, retaining the column."
  (interactive "p")
  (emacspeak-agent-shell--table-move (- (or count 1)) 0))

(defvar emacspeak-agent-shell--table-navigation-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "<right>")
                #'emacspeak-agent-shell-table-next-column)
    (define-key map (kbd "<left>")
                #'emacspeak-agent-shell-table-previous-column)
    (define-key map (kbd "<down>") #'emacspeak-agent-shell-table-next-row)
    (define-key map (kbd "<up>") #'emacspeak-agent-shell-table-previous-row)
    (define-key map (kbd "M-<up>")
                #'emacspeak-agent-shell-table-exit-backward)
    (define-key map (kbd "M-<down>")
                #'emacspeak-agent-shell-table-exit-forward)
    (define-key map (kbd "r") #'emacspeak-agent-shell-table-speak-row)
    (define-key map (kbd "c") #'emacspeak-agent-shell-table-speak-column)
    (define-key map (kbd "SPC") #'emacspeak-agent-shell-table-speak-cell)
    (define-key map (kbd ".") #'emacspeak-agent-shell-table-speak-context)
    (define-key map (kbd "=") #'emacspeak-agent-shell-table-speak-dimensions)
    (define-key map (kbd "w") #'emacspeak-agent-shell-table-copy-cell)
    (define-key map (kbd "a")
                #'emacspeak-agent-shell-table-select-speaking-method)
    map)
  "Contextual keymap active while point is in a rendered Markdown table.")

(defun emacspeak-agent-shell--install-table-copy-bindings ()
  "Install reload-safe table copying keys in the contextual table map."
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "k") #'emacspeak-agent-shell-table-copy-cell)
    (define-key map (kbd "r") #'emacspeak-agent-shell-table-copy-row)
    (define-key map (kbd "c") #'emacspeak-agent-shell-table-copy-column)
    (define-key emacspeak-agent-shell--table-navigation-map (kbd "k") map)))

(emacspeak-agent-shell--install-table-copy-bindings)

(unless (assq 'emacspeak-agent-shell--table-navigation-active
              minor-mode-map-alist)
  (push (cons 'emacspeak-agent-shell--table-navigation-active
              emacspeak-agent-shell--table-navigation-map)
        minor-mode-map-alist))

(defun emacspeak-agent-shell--table-navigation-entry-feedback (direction)
  "Announce entry at point, falling back to table edge in DIRECTION."
  (if-let* ((region (emacspeak-agent-shell--markdown-table-region-at-point))
            (cell (emacspeak-agent-shell--markdown-table-cell-at-point)))
      (progn
        (setq emacspeak-agent-shell--table-navigation-active t
              emacspeak-agent-shell--table-navigation-table-start
              (car region))
        (emacspeak-icon 'open-object)
        (dtk-speak
         (concat (emacspeak-agent-shell--table-dimensions-speech cell)
                 " "
                 (emacspeak-agent-shell--table-cell-speech cell))))
    (emacspeak-agent-shell--table-entry-feedback direction)))

(defun emacspeak-agent-shell--table-navigation-pre-command ()
  "Remember point before a possible contextual table entry."
  (setq emacspeak-agent-shell--table-navigation-origin (point)))

(defun emacspeak-agent-shell--table-navigation-post-command ()
  "Track table entry and toggle the contextual table keymap."
  (let* ((region (emacspeak-agent-shell--markdown-table-region-at-point))
         (table-start (and region (car region))))
    (cond
     ((not region)
      (setq emacspeak-agent-shell--table-navigation-active nil
            emacspeak-agent-shell--table-navigation-table-start nil))
     ((not (equal table-start
                  emacspeak-agent-shell--table-navigation-table-start))
      (setq emacspeak-agent-shell--table-navigation-active t)
      (dtk-stop)
      (emacspeak-agent-shell--table-navigation-entry-feedback
       (if (and emacspeak-agent-shell--table-navigation-origin
                (< (point) emacspeak-agent-shell--table-navigation-origin))
           'backward
         'forward)))
     (t
      (setq emacspeak-agent-shell--table-navigation-active t)))))

(defun emacspeak-agent-shell--table-navigation-setup ()
  "Install contextual Markdown table navigation in the current buffer."
  (setq emacspeak-agent-shell--speech-control-active t)
  (add-hook 'pre-command-hook
            #'emacspeak-agent-shell--table-navigation-pre-command nil t)
  (add-hook 'post-command-hook
            #'emacspeak-agent-shell--table-navigation-post-command nil t)
  (add-hook 'kill-buffer-hook
            #'emacspeak-agent-shell--table-navigation-cleanup nil t)
  (add-hook 'change-major-mode-hook
            #'emacspeak-agent-shell--table-navigation-cleanup nil t)
  (if-let ((region (emacspeak-agent-shell--markdown-table-region-at-point)))
      (setq emacspeak-agent-shell--table-navigation-active t
            emacspeak-agent-shell--table-navigation-table-start (car region))
    (setq emacspeak-agent-shell--table-navigation-active nil
          emacspeak-agent-shell--table-navigation-table-start nil)))

(defun emacspeak-agent-shell--table-navigation-cleanup ()
  "Remove contextual Markdown table navigation from the current buffer."
  (setq emacspeak-agent-shell--speech-control-active nil
        emacspeak-agent-shell--table-navigation-active nil
        emacspeak-agent-shell--table-navigation-table-start nil
        emacspeak-agent-shell--table-navigation-origin nil)
  (remove-hook 'pre-command-hook
               #'emacspeak-agent-shell--table-navigation-pre-command t)
  (remove-hook 'post-command-hook
               #'emacspeak-agent-shell--table-navigation-post-command t)
  (remove-hook 'kill-buffer-hook
               #'emacspeak-agent-shell--table-navigation-cleanup t)
  (remove-hook 'change-major-mode-hook
               #'emacspeak-agent-shell--table-navigation-cleanup t))

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

(defun emacspeak-agent-shell--table-sequential-edge-p (direction)
  "Return non-nil at the table edge in sequential DIRECTION."
  (when-let* ((cell (emacspeak-agent-shell--markdown-table-cell-at-point))
              (rows (plist-get cell :rows)))
    (let* ((row (plist-get cell :row-index))
           (column (plist-get cell :column-index))
           (index (+ column
                     (apply #'+
                            (mapcar #'length (seq-take rows row)))))
           (count (apply #'+ (mapcar #'length rows))))
      (if (eq direction 'forward)
          (= index (1- count))
        (zerop index)))))

(defun emacspeak-agent-shell--table-between (origin destination direction)
  "Return a visible table position between ORIGIN and DESTINATION.
Search in DIRECTION.  When item navigation did not move, extend the search to
the corresponding buffer boundary."
  (let ((property 'agent-shell-markdown-table-source)
        found)
    (save-excursion
      (pcase direction
        ('forward
         (let ((limit (if (> destination origin) destination (point-max)))
               (position origin))
           (while (and (< position limit) (not found))
             (setq position
                   (next-single-property-change
                    position property nil limit))
             (when (and (< position limit)
                        (get-text-property position property)
                        (not (invisible-p position)))
               (setq found position)))))
        ('backward
         (let ((limit (if (< destination origin) destination (point-min)))
               (position origin))
           (while (and (> position limit) (not found))
             (setq position
                   (previous-single-property-change
                    position property nil limit))
             (let ((candidate (max limit (1- position))))
               (when (and (> position limit)
                          (get-text-property candidate property)
                          (not (invisible-p candidate)))
                 (setq found candidate)))))))
      found)))

(defun emacspeak-agent-shell--table-discovery-feedback
    (origin direction)
  "Stop at and announce a table skipped from ORIGIN in DIRECTION."
  (let ((destination (point)))
    (when-let ((table-position
                (if (get-text-property
                     destination 'agent-shell-markdown-table-source)
                    destination
                  (emacspeak-agent-shell--table-between
                   origin destination direction))))
      (goto-char table-position)
      (emacspeak-agent-shell--table-entry-feedback direction))))

(defadvice agent-shell-next-item (around emacspeak pre act comp)
  "Discover, enter, traverse, and leave rendered tables semantically."
  (let ((interactive-p (ems-interactive-p))
        (origin (point))
        (modification-tick (buffer-chars-modified-tick))
        (started-in-table-p
         (get-text-property (point) 'agent-shell-markdown-table-source))
        handled-p)
    (if (and interactive-p started-in-table-p
             (emacspeak-agent-shell--table-sequential-edge-p 'forward))
        (progn
          (setq handled-p t)
          (emacspeak-agent-shell--table-exit 'forward))
      ad-do-it)
    ;; Plain n self-inserts at a live prompt; a text change is not navigation.
    (when (and interactive-p
               (not handled-p)
               (= modification-tick (buffer-chars-modified-tick)))
      (unless (or (and (not started-in-table-p)
                       (emacspeak-agent-shell--table-discovery-feedback
                        origin 'forward))
                  (emacspeak-agent-shell--permission-button-feedback)
                  (emacspeak-agent-shell--table-cell-feedback))
        (emacspeak-icon 'item)
        (emacspeak-speak-line)))))

(defadvice agent-shell-previous-item (around emacspeak pre act comp)
  "Discover, enter, traverse, and leave rendered tables semantically."
  (let ((interactive-p (ems-interactive-p))
        (origin (point))
        (modification-tick (buffer-chars-modified-tick))
        (started-in-table-p
         (get-text-property (point) 'agent-shell-markdown-table-source))
        handled-p)
    (if (and interactive-p started-in-table-p
             (emacspeak-agent-shell--table-sequential-edge-p 'backward))
        (progn
          (setq handled-p t)
          (emacspeak-agent-shell--table-exit 'backward))
      ad-do-it)
    ;; Plain p self-inserts at a live prompt; a text change is not navigation.
    (when (and interactive-p
               (not handled-p)
               (= modification-tick (buffer-chars-modified-tick)))
      (unless (or (and (not started-in-table-p)
                       (emacspeak-agent-shell--table-discovery-feedback
                        origin 'backward))
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
  "Discover, enter, traverse, and leave tables in the viewport."
  (let ((interactive-p (ems-interactive-p))
        (origin (point))
        (started-in-table-p
         (get-text-property (point) 'agent-shell-markdown-table-source))
        handled-p)
    (if (and interactive-p started-in-table-p
             (emacspeak-agent-shell--table-sequential-edge-p 'forward))
        (progn
          (setq handled-p t)
          (emacspeak-agent-shell--table-exit 'forward))
      ad-do-it)
    (when (and interactive-p (not handled-p))
      (or (and (not started-in-table-p)
               (emacspeak-agent-shell--table-discovery-feedback
                origin 'forward))
          (emacspeak-agent-shell--table-cell-feedback)))))

(defadvice agent-shell-viewport-previous-item (around emacspeak pre act comp)
  "Discover, enter, traverse, and leave tables in the viewport."
  (let ((interactive-p (ems-interactive-p))
        (origin (point))
        (started-in-table-p
         (get-text-property (point) 'agent-shell-markdown-table-source))
        handled-p)
    (if (and interactive-p started-in-table-p
             (emacspeak-agent-shell--table-sequential-edge-p 'backward))
        (progn
          (setq handled-p t)
          (emacspeak-agent-shell--table-exit 'backward))
      ad-do-it)
    (when (and interactive-p (not handled-p))
      (or (and (not started-in-table-p)
               (emacspeak-agent-shell--table-discovery-feedback
                origin 'backward))
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
                   (emacspeak-agent-shell--speech-level-at-least-p 'full)
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
  (emacspeak-agent-shell--tool-call-event-setup)
  (emacspeak-agent-shell--table-navigation-setup))

(defun emacspeak-agent-shell--buffer-cleanup ()
  "Cancel speech work and remove all support state from this shell buffer."
  (emacspeak-agent-shell--cancel-pending-speech)
  (setq emacspeak-agent-shell--pending-bodies nil)
  (emacspeak-agent-shell--permission-event-cleanup)
  (emacspeak-agent-shell--lifecycle-event-cleanup)
  (emacspeak-agent-shell--tool-call-event-cleanup)
  (emacspeak-agent-shell--table-navigation-cleanup)
  (remove-hook 'kill-buffer-hook
               #'emacspeak-agent-shell--buffer-cleanup t)
  (remove-hook 'change-major-mode-hook
               #'emacspeak-agent-shell--buffer-cleanup t))

;;;  Enable/Disable support:

(defvar emacspeak-agent-shell--advice-list
  '((dtk-speak around)
    (emacspeak-speak-mode-line around)
    (emacspeak-speak-header-line around)
    (agent-shell after)
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
  (add-hook 'agent-shell-viewport-view-mode-hook
            #'emacspeak-agent-shell--table-navigation-setup)
  (add-hook 'agent-shell-viewport-edit-mode-hook
            #'emacspeak-agent-shell--table-navigation-setup)
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (cond
       ((derived-mode-p 'agent-shell-mode)
        (emacspeak-agent-shell--buffer-setup))
       ((derived-mode-p 'agent-shell-viewport-view-mode
                        'agent-shell-viewport-edit-mode)
        (emacspeak-agent-shell--table-navigation-setup)))))
  (message "Enabled Emacspeak agent-shell support"))

(defun emacspeak-agent-shell-disable ()
  "Disable Emacspeak support for agent-shell."
  (interactive)
  (dolist (advice emacspeak-agent-shell--advice-list)
    (ad-disable-advice (car advice) (cadr advice) 'emacspeak)
    (ad-activate (car advice)))
  (remove-hook 'agent-shell-mode-hook #'emacspeak-agent-shell-speech-setup)
  (remove-hook 'agent-shell-mode-hook #'emacspeak-agent-shell--buffer-setup)
  (remove-hook 'agent-shell-viewport-view-mode-hook
               #'emacspeak-agent-shell--table-navigation-setup)
  (remove-hook 'agent-shell-viewport-edit-mode-hook
               #'emacspeak-agent-shell--table-navigation-setup)
  ;; Also remove setup hooks left by earlier versions.
  (remove-hook 'agent-shell-mode-hook
               #'emacspeak-agent-shell--permission-event-setup)
  (remove-hook 'agent-shell-mode-hook
               #'emacspeak-agent-shell--lifecycle-event-setup)
  (remove-hook 'agent-shell-mode-hook
               #'emacspeak-agent-shell--tool-call-event-setup)
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (cond
       ((derived-mode-p 'agent-shell-mode)
        (emacspeak-agent-shell--buffer-cleanup))
       ((derived-mode-p 'agent-shell-viewport-view-mode
                        'agent-shell-viewport-edit-mode)
        (emacspeak-agent-shell--table-navigation-cleanup)))))
  (message "Disabled Emacspeak agent-shell support"))

(provide 'emacspeak-agent-shell)
;;;  end of file
