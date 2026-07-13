# Agent Shell Accessibility Plan

Status: in progress

Audit date: 2026-07-13

## Scope and Audit Snapshot

This plan covers `emacspeak-agent-shell.el` in this repository and its support
for the current agent-shell interaction model.  The audit compared:

- emacspeak-support at `da2f902`;
- agent-shell `v0.58.1-15-g3695704`;
- Emacspeak `60.0-490-g7482f8e27`; and
- Emacs 30.2 for static and replay checks.  Final compatibility checks must
  also use the repository's documented minimum of Emacs 31.

The external agent-shell and Emacspeak worktrees were inspected read-only.
The existing integration already provides useful automatic response speech,
thought and tool-output verbosity settings, basic navigation feedback,
permission intent, and processing earcons.  The main work is to make those
features semantic, reliable across streaming updates, and aligned with
agent-shell's current public interfaces.

## Implementation Progress

Completed so far:

- deterministic speech collectors and upstream traffic-fixture replay;
- public permission request and response subscriptions, including simultaneous
  requests, semantic choices, focus feedback, and response confirmation;
- public initialization, input, turn-completion, and error feedback with
  distinct normal, cancelled, limited, refused, and failed outcomes;
- public tool-call status feedback with per-tool transition deduplication and
  icon-only, summary, and full-output verbosity;
- current viewport compose submission and accepted-cancellation feedback,
  including suppression of false success and declined-cancellation cues;
- semantic Markdown table-cell feedback in shell and viewport navigation,
  with configurable row/column titles, data-first or title-first order, and
  an interactive speech-method selector plus manual position/dimension
  context, directional table-entry announcements, and logical whole-row and
  whole-column reading, plus logical cell copying without rendered padding or
  borders; contextual two-dimensional arrow navigation that ignores Markdown
  separators and visual wrapping; direct row, column, cell, context,
  dimensions, settings, and copy keys; and natural or explicit table exit; and
- centralized, idempotent buffer teardown for pending speech, subscriptions,
  and caches on disable, major-mode change, and buffer death.

The lifecycle event path replaces heartbeat advice and suppresses delayed
rendered duplicates without discarding pending agent response text.  Tool
events likewise replace asynchronous private save advice and avoid repeating
rendered tool output.  Idle events, background-session identity, and two
remaining compatibility failures are still open Phase 0/1 work.

### Markdown Table Keys

The following contextual keys are active only while point is inside a rendered
agent-shell Markdown table:

- left/right move by logical column and up/down move by logical row;
- `TAB` and `Shift-TAB` retain agent-shell's sequential cell navigation;
- `r`, `c`, `SPC`, `.`, and `=` speak the row, column, cell, context, and
  dimensions respectively;
- `w` copies the unpadded logical cell and `a` changes table speech settings;
  and
- `M-Up` and `M-Down` leave directly before or after the table.  Up at the
  first logical row and Down at the last row provide the same exit behavior.

`TAB` and `Shift-TAB` make every visible table embedded inside a response a
navigation stop, including multiple tables in the same response.  Moving
forward from the final cell or backward from the first cell leaves the table
and speaks the adjacent content instead of reporting that no cells remain.

## Findings

### Highest-Priority Defects

1. Permission block IDs are reduced to the text after their final hyphen.
   Current agent-shell permission IDs contain hyphens, so permission content
   is classified as a tool call.  The permission choices and warning cue are
   consequently omitted in the supplied single- and multiple-permission
   traffic fixtures.
2. Unknown block types are silently discarded.  A `when-let*` requires a
   non-nil classification before reaching the intended fallback behavior.
3. Streaming completion is inferred from a 0.5-second quiet timer.  A pause in
   network output is not a semantic fragment or turn boundary, and accumulated
   bodies are cleared when that timer fires.
4. Tool completion advice checks `ems-interactive-p`, but tool updates are
   asynchronous.  Normal success and failure updates therefore do not produce
   the intended speech.
5. Heartbeat stop always uses the success icon.  Authentication, failure,
   interruption, permission blocking, and successful turn completion are not
   distinguished.

### API and Lifecycle Risks

- Response streaming advises private `agent-shell--update-fragment` and
  reconstructs identity from request counts instead of using the supplied
  namespace ID.
- Restored user messages take a different update path and can bypass speech.
- Legacy advice is activated while the file loads.  Enable/disable does not
  fully manage existing buffers, event subscriptions, buffer-local timers, or
  cleanup.
- Viewport submission advice had drifted from the removed
  `agent-shell-viewport-submit`; it now targets the current compose command and
  remains covered by the advice-target compatibility test.
- The only voice map names `agent-shell-mode-line`, which is not one of
  agent-shell's current semantic faces.  Agent-shell defines semantic shell
  and Markdown faces that are currently unmapped.
- The speech setup can replace agent-shell's semantic header line with a
  generic Emacspeak header.
- Every shell can autospeak, so concurrent background agents lack a clear
  announcement policy or buffer identity.
- Agent-shell does not currently provide a current-table-cell value or copy
  command.  The local logical-cell copy command should be replaced by advice
  that adds speech feedback if agent-shell gains a native command.

### Features With Little or No Semantic Support

- permission choices, focused button feedback, and permission response state;
- busy, blocked, and ready state, plus public idle, error, and turn-complete
  lifecycle events;
- grouped tool calls, status transitions, tool diffs, and failures;
- fragment summary/body navigation, fold state, and fold-all commands;
- Markdown headings, links, inline/source code, and blockquotes;
- table search and filtered row/column reading beyond the implemented table
  entry, navigation, context, whole-row/column speech, and cell copying;
- viewport item/page navigation, compose/cancel/peek, replies, history, and
  prompt queue management;
- exact model, session-mode, thought-level, and config-option values;
- session resume, fork, reload, switch, title, identifier, and transcripts;
- usage/context threshold warnings;
- attached files, images, screenshots, audio, binary resources, and alt text;
  and
- multi-file diff summaries and accept/reject actions.  Once entered,
  Emacspeak's existing `diff-mode` support should handle detailed hunk
  navigation rather than being duplicated here.

There is also an untracked alternate implementation in the inspected
Emacspeak worktree.  Its permission summaries, manual summary/body commands,
button focus feedback, and viewport navigation are useful design references,
but it targets removed functions and has a current key conflict.  It should
not be copied wholesale.

## Proposed Architecture

Use public agent-shell events for lifecycle and state:

- `permission-request` and `permission-response`;
- `tool-call-update` and `file-write`;
- `config-option-update`;
- `turn-complete`, `idle`, `error`, and `clean-up`; and
- `session-title-changed` and `input-submitted`.

Use `agent-shell-section-functions` only for rendered message, thought, plan,
and section ranges that are not represented by public events.  It is currently
experimental, so isolate it behind one compatibility adapter.  Longer term,
request a stable public fragment event or accessor upstream rather than
spreading private-function advice through this extension.

Separate the implementation into four responsibilities:

1. adapters turn agent-shell events/ranges into stable semantic records;
2. formatters produce concise and full speech strings without speaking visual
   glyphs or raw Markdown unnecessarily;
3. policy decides whether to speak, cue, defer, or suppress by event priority
   and buffer visibility; and
4. delivery calls Emacspeak speech and auditory-icon APIs.

Keep subscriptions, pending fragments, last-announced states, and timers
buffer-local.  Installation and removal should be idempotent and should apply
to both existing and newly created shell buffers.

## Speech Behavior

- Permission requests are urgent: stop lower-priority response speech, play a
  warning cue, speak the tool/request summary, then speak numbered choices and
  the current choice.  Moving between buttons speaks choice text, position,
  and action.
- Normal streaming is accumulated by semantic fragment ID.  Speak rendered
  content at a reliable fragment or turn boundary, with explicit commands for
  concise summary and full body.  A timer may coalesce bursts but must not be
  treated as proof of completion.
- Announce tool transitions only when status changes.  Include a short title
  and distinct pending/running/succeeded/failed cues; observe the configured
  output verbosity for the body.
- Navigation speaks a semantic summary, content kind, fold state, and position
  where useful.  Do not read disclosure triangles, checkbox glyphs, or raw
  decoration as if they were content.
- Setting changes speak the selected value, not just "changed".  Session
  announcements include a short title or agent identity when ambiguity is
  possible.
- Foreground output can autospeak normally.  Background output should default
  to status/icon notifications with a buffer or session prefix for urgent
  events; verbose background response speech should be opt-in.
- Preserve agent-shell's header-line information and add speech access to it
  instead of replacing it.

## Implementation Phases

### Phase 0: Compatibility Harness

- Add ERT collectors for speech, stop, messages, and auditory icons.
- Add fixture replay for the existing permission and user-message traffic.
- Add helpers that construct semantic event data without a live agent.
- Establish an agent-shell compatibility matrix and guard optional commands
  with `fboundp` or versioned adapters.
- Make enable/disable and buffer cleanup testable and idempotent.

Exit criterion: current behavior is captured by tests, and the known
permission, unknown-block, missing-command, and cleanup failures reproduce.

### Phase 1: Permissions and Lifecycle

- Subscribe to public permission, tool, turn, idle, error, and cleanup events.
- Speak complete permission summaries and choices immediately.
- Add button-focus and response feedback.
- Replace heartbeat-only success signaling with distinct busy, blocked,
  succeeded, failed, and interrupted feedback.
- Include session identity for urgent background events.

Exit criterion: single and simultaneous permission fixtures produce ordered,
complete speech; every lifecycle outcome has unambiguous feedback exactly once.

### Phase 2: Semantic Fragments and Streaming

- Introduce the section-range compatibility adapter.
- Track complete qualified IDs rather than parsing IDs heuristically.
- Extract rendered semantic body text and handle unknown content safely.
- Flush pending content on semantic completion, with a timer only for burst
  coalescing and recovery.
- Add concise-summary, full-body, and repeat-last-response commands.
- Define foreground/background and thought/plan policies.

Exit criterion: chunk boundaries and network pauses do not create duplicate or
truncated speech, and restored user messages and unknown blocks remain usable.

### Phase 3: Navigation, Voices, and Viewport

- Map current agent-shell and Markdown faces to appropriate personalities.
- Speak item kind, status, fold state, and semantic content on navigation.
- Add table cell/header context using Emacspeak's tabulated-list patterns.
- Cover fold, reply, compose, history, queue, and current viewport commands.
- Speak exact model, mode, thought-level, and config values.
- Retain and expose agent-shell's semantic header information.

Exit criterion: all current shell and viewport navigation commands provide
useful feedback without raw visual decoration, and no advice target is missing.

### Phase 4: Rich Content and Session Polish

- Announce attachment type, filename, count, and alt text where available.
- Summarize resource links and safe actions.
- Announce diff file/hunk counts and accept/reject entry points, then delegate
  detailed navigation to existing Emacspeak diff support.
- Add usage/context threshold warnings and queue/pending counts.
- Cover session selection, resume, fork, reload, title, and transcripts.

Exit criterion: non-text content and long-running multi-session workflows have
complete discoverable speech paths.

## Verification Matrix

Each phase should use the methodology in `AGENTS.md`:

1. `check-parens`, byte compilation, batch load, and enable/disable checks;
2. ERT assertions over ordered speech, interruption, and icon calls;
3. replay of redacted agent-shell traffic fixtures;
4. an interactive `log-dtk-soft` transcript from a clean Emacs session; and
5. manual listening for pacing, personalities, cues, and interruptibility.

At minimum, cover permission allow/deny/cancel, multiple concurrent
permissions, tool success/failure, normal/failed/interrupted turns, restored
messages, collapsed/expanded sections, Markdown code/link/table content,
viewport navigation and submission, and visible/background sessions.

## Open Decisions

- Whether background sessions should be silent, icon/status only, or speak
  complete responses by default.  Icon/status only is the proposed default.
- Whether thought content should remain icon-only by default.  Preserve the
  current default until user testing indicates otherwise.
- Whether an urgent permission should interrupt all current speech or only
  speech originating from the same shell.  Start with same-shell interruption
  unless Emacspeak's global speech queue makes that distinction impractical.
- Whether to upstream a stable fragment event/accessor to agent-shell before
  Phase 2 or maintain a narrow experimental-hook adapter temporarily.
- Which commands and bindings should expose summary/full-body speech without
  conflicting with agent-shell's current session configuration bindings.

## Progress

- [x] Audit current support against agent-shell and Emacspeak.
- [x] Reproduce permission classification and semantic navigation gaps with
  supplied traffic fixtures.
- [x] Phase 0: compatibility harness.
- [ ] Phase 1: permissions and lifecycle.
- [ ] Phase 2: semantic fragments and streaming.
- [ ] Phase 3: navigation, voices, and viewport.
- [ ] Phase 4: rich content and session polish.
