# Emacspeak Support Extensions

A collection of speech-enabled support extensions for modern Emacs packages that work with Emacspeak.

Emacspeak is an audio desktop that provides complete eyes-free access to Emacs. This repository provides speech support for modern packages that are not yet in the Emacspeak mainline, making them more accessible and easier to use with speech feedback.

## Table of Contents

- [Installation](#installation)
- [Usage](#usage)
- [Available Extensions](#available-extensions)
- [Contributing](#contributing)
- [Development Guide](#development-guide)
- [License](#license)

## Installation

### Basic Installation

1. Clone this repository:

```bash
git clone https://github.com/robertmeta/emacspeak-support.git
```

2. Add to your Emacs configuration:

```elisp
(add-to-list 'load-path "/path/to/emacspeak-support")
(require 'emacspeak-support)
```

### Auto-loading Extensions

To automatically enable all extensions when Emacspeak loads:

```elisp
(with-eval-after-load 'emacspeak-support
  (emacspeak-support-enable-all))
```

Or selectively enable extensions when their corresponding packages load:

```elisp
(with-eval-after-load 'corfu
  (emacspeak-support-enable-corfu))

(with-eval-after-load 'which-key
  (emacspeak-support-enable-which-key))

(with-eval-after-load 'markdown-mode
  (emacspeak-support-enable-markdown))

(with-eval-after-load 'helm
  (emacspeak-support-enable-helm))
```

See `example-config.el` for a complete configuration example.

## Usage

### Enable/Disable Individual Extensions

Each extension can be toggled on or off independently:

```elisp
;; Enable specific extensions
M-x emacspeak-support-enable-corfu
M-x emacspeak-support-enable-which-key
M-x emacspeak-support-enable-markdown
M-x emacspeak-support-enable-helm

;; Disable specific extensions
M-x emacspeak-support-disable-corfu
M-x emacspeak-support-disable-which-key
M-x emacspeak-support-disable-markdown
M-x emacspeak-support-disable-helm

;; Toggle extensions on/off
M-x emacspeak-support-toggle-corfu
M-x emacspeak-support-toggle-which-key
M-x emacspeak-support-toggle-markdown
M-x emacspeak-support-toggle-helm
```

### Enable/Disable All Extensions

```elisp
;; Enable all extensions at once
M-x emacspeak-support-enable-all

;; Disable all extensions
M-x emacspeak-support-disable-all
```

### Check Extension Status

```elisp
;; Display which extensions are currently enabled
M-x emacspeak-support-status
```

### Generic Interface

You can also use the generic commands with completion:

```elisp
M-x emacspeak-support-enable    ;; prompts for extension name
M-x emacspeak-support-disable   ;; prompts for extension name
M-x emacspeak-support-toggle    ;; prompts for extension name
```

## Available Extensions

### emacspeak-corfu

Speech-enables Corfu, a modern in-buffer completion interface.

**Features:**

- Speaks completion candidates with position info (e.g., "3 of 10: candidate-name")
- Includes annotations when available
- Provides auditory icons for navigation and selection
- Real-time feedback during candidate filtering

### emacspeak-which-key

Speech-enables Which-Key, which displays available keybindings after prefix keys.

**Features:**

- Automatically speaks keybinding options when popup appears
- Page navigation with auditory feedback
- Toggle auto-speak with `emacspeak-which-key-toggle-auto-speak`
- Manual speak command: `emacspeak-which-key-speak`

### emacspeak-markdown

Speech-enables markdown-mode for better navigation of markdown documents.

**Features:**

- Speaks "heading level 3: Title" instead of "three pounds space Title"
- Smart navigation between headers, links, and list items
- Appropriate voice personalities for different markdown elements
- Keybinding: `C-c C-s h` to speak current heading

### emacspeak-helm

Speech-enables Helm, a powerful incremental completion and selection framework.

**Features:**

- Fixes helm-help mode prompt repetition during navigation
- Emacspeak prefix key (C-e) now works in helm help mode
- Proper silence control via emacspeak-speak-messages
- Complete standalone implementation (no core Emacspeak patches needed)

**Based on:** Patch by Parham Doustdar (Emacspeak mailing list, December 26, 2025)


### emacspeak-agent-shell
Speech-enables Agent Shell, a powerful and versatile tool for connecting and communicating with agents that support ACP protocol.

**Features:**

- Provides spoken feedback when the agents generate output.
- Provides a toggle to turn automatic speech announcements on and off.


## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines on:

- Why contribute here
- What makes a good extension
- Development patterns and code standards
- Testing procedures

## Requirements

- Emacs 31+
- Emacspeak
- Target packages (corfu, which-key, markdown-mode, helm, etc.) as needed

## License

GNU General Public License v2.0 or later

See the individual files for copyright and license information.
