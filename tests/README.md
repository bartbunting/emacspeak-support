# Tests

The agent-shell tests use deterministic collectors for speech, interruption,
auditory icons, and messages.  They read agent-shell's checked-in traffic
fixtures but do not start an agent or make network requests.

From the repository root, run:

```bash
emacs --batch -Q -l tests/run-tests.el
```

The runner expects Emacspeak at `~/emacs/src/emacspeak` and agent-shell at
`~/src/agent-shell`.  Override either location when needed:

```bash
EMACSPEAK_DIR=/path/to/emacspeak \
AGENT_SHELL_DIR=/path/to/agent-shell \
emacs --batch -Q -l tests/run-tests.el
```

The suite covers response boundaries, lifecycle and permission events, tool
updates, foreground/background policy, headers and voices, status semantics,
typed transcript and source navigation, Markdown table interaction, upstream
API/face drift, and teardown.  All checked-in tests are normal regression tests
and are expected to pass.

For end-to-end speech-server logging and manual-listening methodology, see
[../AGENTS.md](../AGENTS.md).  The audited external revisions are recorded in
[../agent-shell-accessibility-plan.md](../agent-shell-accessibility-plan.md).
