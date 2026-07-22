# Tests

The tests use deterministic collectors for speech, interruption, auditory
icons, messages, and Windows notification-stream setup.  They read
agent-shell's checked-in traffic fixtures but do not start an agent, speech
server, or network request.

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

The suite covers semantic turn-content boundaries and response/thought/plan
policy, coalesced out-of-turn updates and restored-history suppression,
explicit latest-answer replay and structural overview, lifecycle and permission
events, tool updates, foreground/background policy, headers and voices, status
semantics, typed transcript and source navigation, current and legacy activity
groups, Markdown table interaction, viewport submission outcomes, upstream
API/face drift, and teardown.  All checked-in tests are normal regression tests
and are expected to pass.

For end-to-end speech-server logging and manual-listening methodology, see
[../CONTRIBUTING.md](../CONTRIBUTING.md).  The audited external revisions are
recorded in
[../agent-shell-accessibility-plan.md](../agent-shell-accessibility-plan.md).
