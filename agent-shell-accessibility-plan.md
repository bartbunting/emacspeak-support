# Agent Shell Accessibility Plan

Status: core speech and navigation implemented; remaining polish in progress

Audit date: 2026-07-13

## Scope and Audit Snapshot

This plan covers `emacspeak-agent-shell.el` in this repository and its support
for the current agent-shell interaction model.  The original audit compared:

- emacspeak-support at `da2f902`;
- agent-shell `v0.59.1-2-g5351f9b` (`5351f9b`), rechecked before semantic
  response completion;
- Emacspeak `60.0-490-g7482f8e27`; and
- Emacs 30.2 for static and replay checks.

The complete interaction and documentation were rechecked on 2026-07-21 at
emacspeak-support `eece826`, against agent-shell
`v0.62.1-15-g8a6ea7a`, Emacspeak `60.0-498-g7905520fd`, and Emacs 30.2.
The Emacspeak worktree had a pre-existing unrelated change to `servers/espeak`;
the recorded revision is the inspected source baseline.

The external agent-shell and Emacspeak worktrees were inspected read-only.
At the audit baseline, the integration provided useful automatic response
speech, thought and tool-output verbosity settings, basic navigation feedback,
permission intent, and processing earcons.  The work recorded below made those
paths semantic, reliable across streaming updates, and aligned with
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
- semantic turn-content delivery that records the latest rendered response,
  thought, and plan bodies under agent-shell's real qualified IDs and applies
  the configured speech policy once at public turn completion; network pauses
  no longer imply completion, and the private fragment-update advice is
  removed;
- current viewport compose submission and accepted-cancellation feedback,
  distinguishing immediate submission from queueing, continued composition,
  and compose-window dismissal while suppressing false success and
  declined-cancellation cues;
- preservation of agent-shell's text and graphical headers, with concise
  semantic focus speech for otherwise silent SVG headers and a full-state
  reading through Emacspeak's standard `C-e m` mode-line command;
- explicit voice mappings for all current agent-shell core and Markdown faces,
  with semantic contrast for interface states, Markdown structure, and code;
  visual table borders are inaudible, zebra striping remains plain, and the
  full `C-e m` header reading applies core voices to its semantic clauses while
  automatic focus speech remains plain;
- semantic speech-only replacements for faced pending, in-progress, completed,
  and failed status icons, with customizable labels and no change to ordinary
  ellipses; vertical arrow entry into a collapsible label also suppresses the
  redundant spoken "Press RET to toggle" hint while leaving the visual message
  and non-arrow action feedback intact;
- completing-read transcript navigation by agent response, user prompt,
  thought, activity group, tool call, plan, permission, error, rendered table,
  or other block, with complete body speech, explicit boundaries,
  collapsed-group expansion, temporary repeat keys in shell and viewport
  buffers, and
  directional property search that does not rebuild or copy the complete
  transcript on every move;
- semantic fenced source-block navigation in shell and viewport buffers, with
  concise language and line-count arrival speech, contextual bracket
  inference, explicit full reading, and copying through agent-shell's public
  source-block command;
- semantic Markdown table-cell feedback in shell and viewport navigation,
  with configurable row/column titles, data-first or title-first order, and
  an interactive speech-method selector plus manual position/dimension
  context, directional table-entry announcements, and logical whole-row and
  whole-column reading, plus logical cell copying without rendered padding or
  borders and logical row/column copying as tabular plain text; contextual
  two-dimensional arrow navigation that ignores Markdown separators and
  visual wrapping; direct row, column, cell, context, dimensions, settings,
  and copy keys; and natural or explicit table exit; and
- centralized, idempotent buffer teardown for pending speech, subscriptions,
  and caches on disable, major-mode change, and buffer death.

The lifecycle event path replaces heartbeat advice and supplies the reliable
response boundary.  Tool events likewise replace asynchronous private save
advice and avoid repeating rendered tool output.  Public idle feedback and
explicit response summary/repeat commands are still open work.

### Transcript Block Navigation

`C-c ]` selects a semantic block type and moves to its next occurrence;
`C-c [` selects a type and moves to its previous occurrence.  The previous
selection is the default.  After a successful move, `]` and `[` temporarily
repeat that selection in either direction.  Navigation does not wrap.  It
speaks the complete selected body, preceded by a label/status where present;
bodyless activity groups retain their descriptive summary and fold-state
feedback.  Selecting a thought or tool inside a collapsed group expands the
group before moving to that member.  Rendered tables and fenced source blocks
are also selectable.  Tables retain
the less chatty table-entry announcement: dimensions and the entry cell rather
than every cell.  Source-block arrival reports only the language and line
count; reading all of the code remains explicit.

Navigation searches agent-shell's semantic text-property runs from point and
constructs only the destination block.  It does not cache copied response
bodies, so streaming edits cannot leave a stale navigation index.  Contextual
navigation classifies the local fragment, prompt, table, or source panel
without enumerating the transcript.  A synthetic 30,000-line, 300-response
check reduced 20 response moves from about 0.35 seconds to about 0.004 seconds
with speech calls disabled; the deterministic suite also prevents the command
path from regressing to the whole-buffer collectors.

When no repeat map is active, bare `]` and `[` infer the innermost semantic
block at point, then move to the next or previous block of that type.  A table
nested in a response is treated as a table, and a fenced block is treated as
source.  At the live shell prompt and in the viewport compose buffer, these
keys continue to insert literal brackets.  At unclassified transcript text,
the bare bracket opens the same case-insensitive block-type selector as its
`C-c` counterpart.  Pressing that bracket again while the selector is empty
accepts the previous block type as the default; once text has been entered,
the bracket inserts normally.

Agent-shell currently exposes generic next/previous block navigation but no
public semantic block-type field.  The compatibility adapter therefore infers
type from `agent-shell-ui-state` qualified IDs and group metadata, with prompt,
viewport, rendered-table, and rendered-source properties as fallbacks.  Both
older `tool-calls-N` groups and current `activity-N` groups use the stable
generic group kind and are presented as activity groups; the former
`tool-group` navigation symbol remains a reload-compatible alias.  Keep this
inference isolated and replace it with a public semantic accessor if
agent-shell adds one.

### Markdown Source Block Keys

Source navigation lands on the first character of code and expands a collapsed
parent group when necessary.  It does not wrap.  `C-c C-b` reads the complete
source block at point; `C-c C-y` copies its body without fences through
agent-shell's public copy command.  Agent-shell's existing `RET` action on the
language label remains available for copying.

### Markdown Table Keys

The following contextual keys are active only while point is inside a rendered
agent-shell Markdown table:

- left/right move by logical column and up/down move by logical row;
- `TAB` and `Shift-TAB` retain agent-shell's sequential cell navigation;
- `r`, `c`, `SPC`, `.`, and `=` speak the row, column, cell, context, and
  dimensions respectively;
- `k k` copies the unpadded logical cell, `k r` copies its row with tab-separated
  cells, and `k c` copies its column with newline-separated cells; `w` remains
  an alias for copying the cell, and `a` changes table speech settings; and
- `M-Up` and `M-Down` leave directly before or after the table.  Up at the
  first logical row and Down at the last row provide the same exit behavior.

`TAB` and `Shift-TAB` make every visible table embedded inside a response a
navigation stop, including multiple tables in the same response.  Moving
forward from the final cell or backward from the first cell leaves the table
and speaks the adjacent content instead of reporting that no cells remain.
At the live shell prompt, agent-shell's plain `n` and `p` bindings retain their
self-insertion behavior and do not trigger table discovery or move focus.

### Speech Levels

Automatic speech follows the selected session by default.  Focused sessions
use `emacspeak-agent-shell-foreground-speech-level`; other sessions use
`emacspeak-agent-shell-background-speech-level`.  The levels are:

- `full` for configured response, thought, plan, tool, and lifecycle feedback;
- `response` for agent responses and turn completion;
- `notify` for turn completion only; and
- `quiet` for no routine feedback.

Permissions and errors remain audible at every routine level.  Background
announcements use the notification stream and include the session name.
`C-c C-q` selects the current session's override, including automatic mode;
`C-c C-S-q` selects the default for all automatic background sessions.  The
session selector controls the backing shell from viewport mode.  Selecting
`notify` or `quiet` cancels queued speech affected by that setting.  The older
`emacspeak-agent-shell-cycle-speech-level` command remains available through
`M-x` for users who prefer repeated cycling.

### Turn Content and Response Completion

Only response, thought, and plan sections rendered during an active submitted
turn are collected.  Each update replaces the stored snapshot for its real
agent-shell qualified ID, so a streaming pause produces no speech and separate
sections preserve their arrival order.  At `response` level, only answer
sections are spoken.  At `full`, plan sections are spoken and thoughts follow
`emacspeak-agent-shell-speak-thought-process`.  A successful public
`turn-complete` event applies that policy to the rendered snapshots once,
followed by the completion cue.  Cancellation, failure, and public error
events discard partial turn content before their semantic outcome
announcement.  Permission prompts interrupt speech without discarding the
current snapshots.

`emacspeak-agent-shell-speech-delay` remains defined for configuration
compatibility but no longer determines completion.  Reloading support removes
the former `agent-shell--update-fragment` advice, cancels any timer left by the
older implementation, and installs the section collector in already enabled
shell buffers without requiring a session restart.

## Findings

### Original Highest-Priority Defects

These findings describe the audit baseline; completed corrections are recorded
in Implementation Progress above.

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

- Response streaming now uses a buffer-local
  `agent-shell-section-functions` collector and the public `turn-complete`
  event.  The section hook is explicitly experimental upstream, so this
  compatibility dependency remains isolated and covered by rendered-range and
  qualified-ID tests.
- Restored history renders outside an active submitted turn and is
  intentionally excluded from automatic response speech; it remains available
  through transcript navigation.
- Reload migration explicitly removes the old fragment advice and cancels its
  timers; enable/disable and buffer teardown manage the replacement hook and
  all buffer-local response state.
- Viewport submission advice had drifted from the removed
  `agent-shell-viewport-submit`; it now targets the current compose command,
  samples the public pre-send session status to distinguish queueing from
  immediate submission, and reports prefix-driven continued composition or
  configured dismissal.  Errors still produce no success cue, and the former
  zero-argument command remains compatible.
- Agent-shell's current core and Markdown faces now have explicit voice
  mappings because Emacspeak's exact-symbol mapping does not inherit them from
  visual parent faces.  Inventory tests detect newly added upstream faces.
- Rendered Markdown carries a plain-text `yank-handler` for normal clipboard
  use.  A `dtk-speak` adapter scoped to shell and viewport buffers removes that
  handler only from temporary speech copies, preserving faces for audio while
  leaving copy and paste unchanged.
- Speech setup now preserves agent-shell's semantic header line; graphical
  headers receive separate concise and full semantic speech paths.  Context
  severity uses the guarded private `agent-shell--context-usage-face` helper
  when available, with tested compatibility thresholds for older releases.
- Every shell can autospeak, so concurrent sessions require explicit policy
  and identity.  Focus-aware levels now suppress
  background response and tool chatter by default; completed background turns
  use the notification stream and identify their session.
- Agent-shell does not currently provide current-table-cell values or copy
  commands.  The local logical cell, row, and column copy commands should be
  replaced by advice if agent-shell adds suitable native commands.

### Remaining Semantic Gaps

- explicit concise-summary, full-response, repeat-last-response, and fold-all
  commands;
- public `idle` feedback independent of turn completion;
- generic viewport item/page, peek, reply, history, and prompt-queue command
  feedback beyond the implemented compose, submit, cancellation, refresh,
  header, block, source, and table paths;
- explicit config-option update speech and automatic context-threshold
  warnings; exact model, session mode, thought level, and context usage are
  already available in the full semantic header;
- session resume, fork, reload, switch, title-change, identifier, and
  transcript workflows;
- table search and filtered row/column reading beyond current discovery,
  two-dimensional movement, whole-row/column reading, and logical copying;
- attached files, images, screenshots, audio, binary resources, and alt text;
- multi-file diff summaries and accept/reject action feedback.  Once entered,
  Emacspeak's existing `diff-mode` support should handle detailed hunk
  navigation rather than being duplicated here.

## Architecture and Direction

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
- Normal streaming is accumulated by qualified semantic fragment ID and each
  update replaces that fragment's stored body.  Speak the ordered rendered
  content only at public turn completion.  No quiet timer is used as proof of
  completion; the delay option and timer path remain only for reload
  compatibility with older loaded versions.
- Announce tool transitions only when status changes.  Include a short title
  and distinct pending/running/succeeded/failed cues; observe the configured
  output verbosity for the body.
- Navigation speaks a semantic summary, content kind, fold state, and position
  where useful.  Do not read disclosure triangles, checkbox glyphs, or raw
  decoration as if they were content.
- Rendered status icons are replaced only in temporary speech copies, using
  their faces to distinguish semantic state.  Ordinary prose ellipses and the
  visual buffer are unchanged.  Exact cursor-action hints may be filtered from
  arrow-key speech when line speech already identifies the same object and
  non-arrow entry retains the discoverable action.
- Setting changes speak the selected value, not just "changed".  Session
  announcements include a short title or agent identity when ambiguity is
  possible.
- Foreground output defaults to response speech without routine tool, thought,
  or plan chatter.  Background output defaults to completion notifications
  with a session prefix; verbose background response speech is opt-in.
  Permissions and errors remain audible at the quiet routine level.
- Preserve agent-shell's header-line information instead of replacing it.
  When a graphical header has no textual representation, entering the buffer
  speaks a concise semantic summary: agent, project, viewport position and
  status, or busy state.  Interactive `emacspeak-speak-mode-line`, normally
  bound to `C-e m`, reads the full state on demand, adding model, thought level,
  session mode, context usage, and the optional session ID.  Its prefix-argument
  buffer-information behavior is preserved.  Animated busy frames are
  represented once as "busy", and graphical key-binding hints remain available
  through agent-shell help rather than being read on every focus change.
  The full semantic header preserves agent-shell's face distinctions as speech
  voices for agent, project, status, model, thought level, session mode, context
  severity, and session ID.  The concise automatic focus summary remains plain
  speech to avoid excessive voice changes.

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

Status: complete for permission, initialization, turn-completion, error, and
interruption paths.  Standalone public idle feedback remains a later polish
item.

### Phase 2: Semantic Fragments and Streaming

- Introduce the section-range compatibility adapter.
- Track complete qualified IDs rather than parsing IDs heuristically.
- Extract rendered semantic body text and handle unknown content safely.
- Flush pending content on public semantic completion; retain the former timer
  only as a reload and teardown compatibility path for older loaded versions.
- Add concise-summary, full-body, and repeat-last-response commands.
- Define foreground/background and thought/plan policies.

Exit criterion: chunk boundaries and network pauses do not create duplicate or
truncated speech, and restored user messages and unknown blocks remain usable.

Status: the semantic boundary, response/thought/plan capture,
foreground/background policy, and typed fragment navigation are complete.
Explicit summary, full-response, and repeat-last-response commands remain.

### Phase 3: Navigation, Voices, and Viewport

- Maintain the implemented core and Markdown face mappings as agent-shell's
  rendered interface evolves.
- Extend the implemented typed block body/status/fold feedback to generic item
  navigation.
- Add table cell/header context using Emacspeak's tabulated-list patterns.
- Cover fold, reply, compose, history, queue, and current viewport commands.
- Speak exact model, mode, thought-level, and config values.
- Retain and expose agent-shell's semantic header information.

Exit criterion: all current shell and viewport navigation commands provide
useful feedback without raw visual decoration, and no advice target is missing.

Status: core and Markdown voices, semantic headers, typed block/source/table
navigation, and compose lifecycle feedback are complete.  Generic viewport,
fold, reply, history, queue, and config-update command coverage remains.

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

## Established Defaults

Focused sessions use response speech and background sessions use a named
completion notification.  Both defaults are customizable, and per-session
overrides can follow them automatically or select an explicit level.

## Open Decisions

- Whether thought content should remain icon-only by default.  Preserve the
  current default until user testing indicates otherwise.
- Whether an urgent permission should interrupt all current speech or only
  speech originating from the same shell.  Start with same-shell interruption
  unless Emacspeak's global speech queue makes that distinction impractical.
- Whether to request a stable fragment event/accessor upstream and replace the
  current narrow experimental-hook adapter.
- Which commands and bindings should expose summary/full-body speech without
  conflicting with agent-shell's current session configuration bindings.

## Progress

- [x] Audit current support against agent-shell and Emacspeak.
- [x] Reproduce permission classification and semantic navigation gaps with
  supplied traffic fixtures.
- Phase 0 complete: compatibility harness.
- Phase 1 core complete: permissions and lifecycle outcomes; standalone idle
  speech remains.
- Phase 2 core complete: semantic fragments, streaming boundaries, and speech
  policy; explicit response summary/repeat commands remain.
- Phase 3 partially complete: core voices, headers, and typed
  block/source/table navigation are complete; generic viewport and session
  command coverage remains.
- Phase 4 not started: rich content and session polish.
