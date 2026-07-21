# Emacspeak Support Extensions

This repository provides independently loadable Emacspeak speech interfaces
for packages that are not fully supported in Emacspeak itself.  The current
extensions cover Corfu, Vertico, Which-Key, Markdown Mode, Helm, and
agent-shell.

## Installation

Clone the repository and add it to `load-path` after Emacspeak has been set up:

```bash
git clone https://github.com/robertmeta/emacspeak-support.git
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
- distinct permission, lifecycle, error, and tool-status feedback;
- focus-aware foreground and background speech levels;
- a concise spoken graphical header on focus and full session-state speech
  through Emacspeak's standard `C-e m` command;
- voices for current agent-shell interface and rendered Markdown faces;
- semantic status words for faced plan/status icons while leaving ordinary
  ellipses unchanged;
- typed transcript navigation for responses, prompts, thoughts, tools, plans,
  permissions, errors, source blocks, and rendered tables;
- fenced source-block reading and copying; and
- two-dimensional Markdown table navigation, row/column reading, configurable
  header speech, logical copying, and direct table exit.

Permissions and errors remain audible even when routine session speech is
quiet.  Background completion uses Emacspeak's notification stream and names
the session.

#### Agent-shell Keys

These keys are installed in agent-shell shell and viewport buffers:

| Key | Action |
| --- | --- |
| `C-c C-q` | Select speech level for the current session |
| `C-c C-S-q` | Select the default speech level for background sessions |
| `C-c ]`, `C-c [` | Select a block type and move forward or backward |
| `]`, `[` | Repeat typed navigation, infer the type at point, or open the selector |
| `C-c C-b` | Speak the complete fenced source block at point |
| `C-c C-y` | Copy the fenced source body without its delimiters |
| `C-e m` | Speak the full semantic agent header and session state |

Bare brackets retain normal insertion at the live prompt and in a viewport
compose buffer.  Block-type completion is case-insensitive; pressing the same
bracket again with an empty selector accepts its default.

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

## Requirements and Compatibility

- Emacspeak.  The currently inspected Emacspeak release requires Emacs 29.1
  or later.
- The target package for each enabled extension.
- Current agent-shell declares Emacs 29.1, shell-maker 0.93.5, and ACP 0.13.1.

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

See [tests/README.md](tests/README.md) for paths and suite details,
[AGENTS.md](AGENTS.md) for the layered speech-testing methodology, and
[CONTRIBUTING.md](CONTRIBUTING.md) for extension design and contribution
guidance.

## License

GNU General Public License v2.0 or later.  See the individual files for
copyright and license information.
