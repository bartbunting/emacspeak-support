# Emacspeak Support Extensions

This repository provides independently loadable Emacspeak speech interfaces
for packages that are not fully supported in Emacspeak itself.  The current
extensions cover Corfu, Vertico, Which-Key, Markdown Mode, Helm, and
agent-shell.  The repository also provides optional native Windows speech and
auditory-icon support for Emacspeak running under WSL.

This repository descends from Robert Melton's original
[Emacspeak Support repository](https://github.com/robertmeta/emacspeak-support).
That repository remains the source of the original project and its history;
this fork carries the additional integrations and Windows support documented
here.

## Installation

Clone the repository and add it to `load-path` after Emacspeak has been set up:

```bash
git clone https://github.com/bartbunting/emacspeak-support.git
```

```elisp
(add-to-list 'load-path "/path/to/emacspeak-support")
(require 'emacspeak-support)
```

Enable only the integrations you use:

```elisp
(with-eval-after-load 'corfu
  (emacspeak-support-enable-corfu))

(with-eval-after-load 'vertico
  (emacspeak-support-enable-vertico))

(with-eval-after-load 'which-key
  (emacspeak-support-enable-which-key))

(with-eval-after-load 'markdown-mode
  (emacspeak-support-enable-markdown))

(with-eval-after-load 'helm
  (emacspeak-support-enable-helm))

(with-eval-after-load 'agent-shell
  (emacspeak-support-enable-agent-shell))
```

`emacspeak-support-enable-all` is available when every corresponding target
package is installed.  See [example-config.el](example-config.el) for a
complete selective setup.

## Managing Extensions

Each extension has interactive enable, disable, and toggle commands.  For
example:

```text
M-x emacspeak-support-enable-agent-shell
M-x emacspeak-support-disable-agent-shell
M-x emacspeak-support-toggle-agent-shell
```

The same command suffixes are available for `corfu`, `vertico`, `which-key`,
`markdown`, and `helm`.  The generic
`emacspeak-support-enable`, `emacspeak-support-disable`, and
`emacspeak-support-toggle` commands prompt for an extension.  Use
`emacspeak-support-status` to report the enabled set, or
`emacspeak-support-enable-all` and `emacspeak-support-disable-all` to change
the complete set.

## Available Extensions

### Corfu

`emacspeak-corfu.el` speaks the selected completion candidate, its annotation,
and its position in the candidate set.  It adds auditory feedback for
navigation, insertion, and completion updates.

### Vertico

`emacspeak-vertico.el` announces candidate-count changes while filtering and
speaks the selected candidate, annotation, and position during minibuffer
navigation.  Selection and exit receive auditory confirmation.

### Which-Key

`emacspeak-which-key.el` speaks the displayed key bindings and page
information.  `emacspeak-which-key-speak` reads the current page and
`emacspeak-which-key-toggle-auto-speak` controls automatic reading.

### Markdown Mode

`emacspeak-markdown.el` adds semantic voices and navigation feedback for
headings, lists, links, tables, tasks, code, and other Markdown structures.
Its optional reading mode removes most spoken markup while retaining voice
contrast:

- `C-c C-s h` speaks the current heading.
- `C-c C-s r` toggles `emacspeak-markdown-reading-mode`.
- `emacspeak-markdown-auto-reading-mode` enables reading mode automatically.

### Helm

`emacspeak-helm.el` prevents Helm Help's prompt from being repeated during
navigation and makes the Emacspeak prefix key work in the Helm Help event
loop.  It is a standalone version of Parham Doustdar's December 2025
Emacspeak mailing-list patch.

### Agent Shell

`emacspeak-agent-shell.el` provides semantic speech for agent-shell's
asynchronous, multi-session interface.  It currently includes:

- semantic response speech at the public turn-completion boundary, with
  thought and plan speech at full detail, without treating a network pause as
  completion;
- one-time focused speech for agent messages that arrive outside a submitted
  turn, with a named content-free notification when their session is in the
  background and silence for restored history;
- on-demand full speech or a concise structural overview of the latest agent
  answer without moving point or replaying thoughts, plans, and tool activity;
- distinct permission, lifecycle, error, and tool-status feedback;
- focus-aware foreground and background speech levels;
- viewport submission feedback that distinguishes submitted and queued prompts,
  continued composition, and compose-window dismissal;
- a concise spoken graphical header on focus and full session-state speech
  through Emacspeak's standard `C-e m` command;
- voices for current agent-shell interface and rendered Markdown faces;
- semantic status words for faced plan/status icons while leaving ordinary
  ellipses unchanged;
- typed transcript navigation for responses, prompts, thoughts, activity
  groups, tools, plans, permissions, errors, source blocks, and rendered
  tables;
- fenced source-block reading and copying; and
- two-dimensional Markdown table navigation, row/column reading, configurable
  header speech, logical copying, and direct table exit.

Permissions and errors remain audible even when routine session speech is
quiet.  Background completion and out-of-turn availability use Emacspeak's
notification stream and name the session.

#### Agent-shell Keys

These keys are installed in agent-shell shell and viewport buffers:

| Key | Action |
| --- | --- |
| `C-c C-q` | Select speech level for the current session |
| `C-c C-S-q` | Select the default speech level for background sessions |
| `C-c r` | Speak the latest agent answer in full without moving point |
| `C-c R` | Speak a structural overview and opening of the latest answer |
| `C-c ]`, `C-c [` | Select a block type and move forward or backward |
| `]`, `[` | Repeat typed navigation, infer the type at point, or open the selector |
| `C-c C-b` | Speak the complete fenced source block at point |
| `C-c C-y` | Copy the fenced source body without its delimiters |
| `C-e m` | Speak the full semantic agent header and session state |

Bare brackets retain normal insertion at the live prompt and in a viewport
compose buffer.  Block-type completion is case-insensitive; pressing the same
bracket again with an empty selector accepts its default.

`C-c r` works from shell and viewport buffers and is always spoken when
explicitly invoked, even when automatic speech is quiet.  It reads all answer
fragments from the latest interaction in order while omitting thought, plan,
tool, and other activity fragments.  Legacy unannotated responses fall back to
their complete response text.

`C-c R` reports the answer's line count and any rendered headings, code blocks,
or tables, then reads only its opening sentence or a bounded opening phrase.
Like `C-c r`, it works at every automatic speech level and does not move point.

In a viewport compose buffer, `C-c C-c` announces whether the prompt was
submitted immediately or queued.  With `C-u C-c C-c`, it also confirms that
the cleared editor remains ready for another prompt.  When
`agent-shell-viewport-dismiss-on-send` is enabled, dismissal is announced.

While point is in a rendered Markdown table:

| Key | Action |
| --- | --- |
| Arrow keys | Move by logical row or column |
| `TAB`, `Shift-TAB` | Move sequentially through cells |
| `r`, `c`, `SPC` | Speak the current row, column, or cell |
| `.`, `=` | Speak cell context or table dimensions |
| `k k`, `k r`, `k c` | Copy the logical cell, row, or column |
| `w` | Copy the logical cell |
| `a` | Change title inclusion and data/title order |
| `M-Up`, `M-Down` | Leave before or after the table |

The table defaults and status words can also be changed through
`M-x customize-group RET emacspeak-agent-shell RET`.  The most relevant
options are `emacspeak-agent-shell-table-titles`,
`emacspeak-agent-shell-table-data-position`,
`emacspeak-agent-shell-status-speech-labels`, the foreground/background
speech levels, thought-process handling, and tool-output verbosity.

The detailed audit, implemented behavior, compatibility dependencies, and
remaining work are recorded in
[agent-shell-accessibility-plan.md](agent-shell-accessibility-plan.md).

#### Reloading a Development Checkout

Emacspeak may also contain a bundled file with the same feature name.  To test
this checkout, load it by absolute path after `emacspeak-setup.el`, then enable
it:

```elisp
(load "/absolute/path/to/emacspeak-support/emacspeak-agent-shell.el")
(emacspeak-agent-shell-enable)
```

Existing agent-shell and viewport buffers are updated; their sessions do not
need to be restarted.  `emacspeak-agent-shell-speech-setup` is a mode setup
function and is not an interactive command.  If the wrong copy appears to be
loaded, evaluate:

```elisp
(symbol-file 'emacspeak-agent-shell-enable)
```

### Native Windows Speech and Audio Under WSL

The Windows support keeps its launchers in this repository: it does not copy
them into Emacspeak's `servers` directory or alter Emacspeak's `.servers`
file.  The integration adds the short names `windows-outloud` and
`windows-dtk` to `dtk-select-server`, then translates only those names to this
checkout's absolute paths.

Build whichever components you need from the repository root:

```bash
make windows-audio
make windows-outloud
make windows-dtk
```

`windows-audio` builds native auditory-icon playback.  `windows-outloud`
builds the Eloquence bridge but requires an existing licensed Windows
Eloquence installation at run time; no proprietary Eloquence files are
included.  `windows-dtk` downloads the pinned DECtalk 2023-10-30 IA32 runtime,
verifies its SHA-256 digest, and extracts it into an ignored build directory.
Neither generated executables nor the DECtalk runtime are committed.

After Emacspeak is initialized, load the integration:

```elisp
(require 'emacspeak-windows-speech)
```

Loading it only registers the friendly server choices.  It does not change
the active speech server or audio configuration.  Select a server through the
usual prompt:

```text
M-x dtk-select-server RET windows-outloud RET
M-x dtk-select-server RET windows-dtk RET
```

Both Windows servers automatically start a second, independent speech process
for Emacspeak's notification stream.  The main and notification streams use
separate native bridge instances and can interrupt independently while Windows
mixes both through its default output device.  Set
`emacspeak-windows-speech-enable-notification-stream` to `nil` and restart the
speech server to disable the additional stream.

Speech is rendered as stereo so the streams can occupy distinct positions.
The main stream is centered by default, while notifications are positioned
65 percent to the right.  Customize
`emacspeak-windows-speech-main-pan` and
`emacspeak-windows-speech-notification-pan` from `-1.0` (fully left) through
`0.0` (center) to `1.0` (fully right), then restart the speech server.  This
positions synthesized speech and its native tones; auditory icons keep their
independent audio-player routing.

The dedicated commands
`emacspeak-windows-speech-select-eloquence` and
`emacspeak-windows-speech-select-dectalk` perform the same selections without
prompting.  When the integration is not loaded, an absolute launcher path can
still be passed directly from Lisp, for example:

```elisp
(dtk-select-server
 "/path/to/emacspeak-support/servers/windows-outloud")
```

Configure native Windows auditory-icon playback with:

```text
M-x emacspeak-windows-speech-configure-audio
```

This saves the current Emacspeak audio settings so that
`emacspeak-windows-speech-restore-audio` can restore them.  Use a prefix
argument, for example
`C-u M-x emacspeak-windows-speech-configure-audio`, to restart the active
speech server immediately; otherwise run `M-x tts-restart` when convenient.
The restore command accepts the same prefix argument.

Run `M-x emacspeak-windows-speech-diagnose` to report WSL tools, Tclx, SoX,
Emacspeak's Tcl library, built bridges, and the DECtalk runtime.  Run
`M-x emacspeak-windows-speech-disable` to remove the selection advice and the
friendly names that this integration added.  Disabling selection does not
switch the current server or restore audio; use the restore command separately
when required.

Windows locks a running speech bridge executable.  Before rebuilding
`windows-outloud` or `windows-dtk`, use `dtk-select-server` to select the other
engine or another speech server.  Rebuild, then select the desired engine
again.  Do not manually kill an Emacspeak bridge.  The `windows-audio` build
target safely stops its own player process before rebuilding.

The component guides contain architecture, setup, and direct-test details:

- [native Windows audio](servers/windows-audio/Readme.org)
- [Windows Eloquence](servers/windows-eloquence/Readme.org)
- [Windows Software DECtalk](servers/windows-dectalk/Readme.org)

## Requirements and Compatibility

- Emacspeak.  The currently inspected Emacspeak release requires Emacs 29.1
  or later.
- The target package for each enabled extension.
- Current agent-shell declares Emacs 29.1, shell-maker 0.93.5, and ACP 0.13.1.
- Native Windows speech requires WSL, Tcl/Tclx, `powershell.exe`, `wslpath`,
  SoX, and the .NET Framework C# compiler included with Windows.  Each speech
  engine also needs the corresponding separately licensed runtime described
  above.

The agent-shell integration is currently developed and replay-tested with
Emacs 30.2.  Its exact audited revisions are recorded in the accessibility
plan.  Compatibility-sensitive changes should also be checked against the
oldest Emacs and target-package versions that the repository intends to
support.

## Testing and Contributing

Run the deterministic agent-shell suite with:

```bash
emacs --batch -Q -l tests/run-tests.el
```

See [tests/README.md](tests/README.md) for paths and suite details and
[CONTRIBUTING.md](CONTRIBUTING.md) for extension design, layered speech
testing, and contribution guidance.

## License

GNU General Public License v2.0 or later.  See the individual files for
copyright and license information.
