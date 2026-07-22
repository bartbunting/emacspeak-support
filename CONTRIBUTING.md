# Contributing to Emacspeak Support

This repository is an iteration and testing home for speech interfaces to
modern Emacs packages.  A useful contribution makes the package's semantic
state and available actions understandable through speech, not merely audible.

## Before Editing

- Inspect the target package, the existing support extension, and comparable
  modules in the Emacspeak codebase.
- Record the Emacs, Emacspeak, target-package, and support-repository revisions
  used for compatibility work.
- Treat external Emacspeak and target-package worktrees as read-only unless the
  task explicitly includes changing them.
- Preserve unrelated local changes.

## Design Principles

- Prefer public hooks, events, and commands over advice on private functions.
- If a private or experimental interface is unavoidable, isolate it behind a
  small compatibility adapter, document it, and add a test that detects drift.
- Separate event detection, semantic formatting, policy, and delivery.  A
  formatter should be testable without a running synthesizer.
- Keep state buffer-local when it belongs to a package session.
- Make enable, disable, reload, mode change, and buffer teardown idempotent.
- Give interactive commands useful speech and an appropriate auditory icon,
  while avoiding repeated prompts, visual glyphs, and low-value chatter.
- Use face-to-voice mappings for semantic contrast; do not voice decoration
  whose only purpose is visual styling.

## Extension Structure

Create `emacspeak-PACKAGE.el` with lexical binding, commentary, explicit
requirements, and a provided feature:

```elisp
;;; emacspeak-PACKAGE.el --- Speech-enable PACKAGE -*- lexical-binding: t; -*-

;;; Commentary:
;; Describe PACKAGE and the semantic feedback supplied here.

;;; Code:

(require 'emacspeak-preamble)
(require 'PACKAGE)

;; Speech setup, semantic adapters, formatters, and feedback follow.

(provide 'emacspeak-PACKAGE)
;;; emacspeak-PACKAGE.el ends here
```

### Voice Mappings

Register package faces with Emacspeak personalities:

```elisp
(voice-setup-add-map
 '((package-heading-face voice-bolden)
   (package-metadata-face voice-annotate)
   (package-code-face voice-monotone-extra)))
```

Commonly useful personalities include `voice-bolden`, `voice-annotate`,
`voice-smoothen`, `voice-lighten`, and `voice-monotone`.  Inspect comparable
Emacspeak modules before choosing a mapping.  Inventory tests are valuable for
packages whose face set changes frequently.

### Hooks, Events, and Advice

Use public semantic notifications when the package offers them:

```elisp
(defun emacspeak-package--after-selection ()
  "Speak PACKAGE's selected object."
  (when (ems-interactive-p)
    (emacspeak-icon 'select-object)
    (dtk-speak (emacspeak-package--selection-text))))
```

Advice is appropriate when there is no suitable hook or event.  Keep it named,
reversible, and limited to a stable user-facing command:

```elisp
(defun emacspeak-package--after-command (&rest _)
  "Provide speech after an interactive package command."
  (when (ems-interactive-p)
    (emacspeak-package--after-selection)))

(advice-add 'package-command :after #'emacspeak-package--after-command)
;; Disable with:
(advice-remove 'package-command #'emacspeak-package--after-command)
```

Asynchronous callbacks generally do not satisfy `ems-interactive-p`; use the
package's event semantics to decide whether and when to speak them.

### Enable and Disable

Every extension must expose `emacspeak-PACKAGE-enable` and
`emacspeak-PACKAGE-disable`.  Enabling should install hooks, subscriptions,
advice, keymaps, and setup in existing relevant buffers as well as future
ones.  Disabling should remove all of them and cancel pending timers or queued
state.  Calling either function repeatedly must be safe.

Register the extension in `emacspeak-support--extensions` and add the matching
convenience enable, disable, and toggle commands.  The current registry is:

```elisp
'((corfu . "emacspeak-corfu")
  (vertico . "emacspeak-vertico")
  (which-key . "emacspeak-which-key")
  (markdown . "emacspeak-markdown")
  (helm . "emacspeak-helm")
  (agent-shell . "emacspeak-agent-shell"))
```

Update [README.md](README.md) and [example-config.el](example-config.el) when
adding an extension or user-facing command.

## Testing

Test in layers; loading successfully is only the first layer.

1. Run `check-parens`, byte compilation with all relevant directories on
   `load-path`, a batch load, and the enable/disable cycle.
2. Add ERT tests that replace at least `dtk-speak`, `dtk-stop`, and
   `emacspeak-icon` with collectors and assert the ordered semantic result.
3. For event- or protocol-driven packages, replay checked-in redacted fixtures
   through the same handlers used at runtime.
4. Drive a clean Emacs session with Emacspeak's logging speech server and
   compare the protocol log with an expected transcript.
5. Finish high-impact speech changes by listening with a normal speech server.

For a logged-speech test, use a separate clean Emacs session with Emacspeak
loaded.  Run `C-e d d` (`dtk-select-server`) and choose the `log-` variant of
the engine being tested, such as `log-outloud`.  The wrapper records the
server protocol in a new `/tmp/ENGINE-PID.log` file while forwarding it to the
underlying engine.  Perform one bounded scenario, switch back to the normal
server (or use `emacspeak-emergency-tts-restart`), and inspect the newest
matching log for spoken text, voice changes, stop commands, and auditory
icons.

Exercise focus changes, navigation in both directions, asynchronous updates,
completion, interruption, and enable/disable cycles as relevant to the
change.  Repeat high-impact cases with the normal speech server and listen to
the result.  Speech logs and ACP traffic may contain prompts, source text,
paths, tokens, or agent responses; redact fixtures and never commit raw logs.
Agent-shell test commands and path overrides are in
[tests/README.md](tests/README.md).

## Reference Extensions

- `emacspeak-corfu.el`: completion candidates, annotations, and position.
- `emacspeak-vertico.el`: minibuffer completion and candidate-count changes.
- `emacspeak-which-key.el`: popup timing and page speech.
- `emacspeak-markdown.el`: semantic reading and voice personalities.
- `emacspeak-helm.el`: scoped message suppression and key dispatch.
- `emacspeak-agent-shell.el`: public event subscriptions, concurrent session
  policy, semantic navigation, and deterministic fixture replay.

## Submitting a Change

Include:

- the user-facing problem and intended speech behavior;
- the public or compatibility interfaces used;
- revisions and Emacs versions tested;
- automated checks and manual/logged-speech scenarios run; and
- remaining risks or target-package behavior that is still unsupported.

Emacspeak documentation is available at
<https://tvraman.github.io/emacspeak/>.
