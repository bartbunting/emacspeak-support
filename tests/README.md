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

ERT tests marked as expected failures specify confirmed compatibility or
speech defects.  They are counted separately while the overall command still
succeeds.  When a defect is fixed, remove `:expected-result :failed` and retain
the assertion as a normal regression test.
