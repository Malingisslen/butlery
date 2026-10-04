---
description: Replay stored gate reviews on Sonnet and report, in plain Swedish, whether Sonnet can take over the code-reviewer and integration-reviewer gates
---

The Opus-vs-Sonnet review trial. A SubagentStop hook (`.claude/hooks/review_trial.py`)
already snapshots each change the two gates review, with the Opus verdict. This command
gets the Sonnet verdict for the same changes and reports. Malin reads the summary, not
the reviews.

## Steps

1. List the snapshots still lacking a Sonnet verdict:
   ```
   py -3 .claude/hooks/review_trial.py pending
   ```
2. For each id, dispatch the `sonnet-shadow` agent with the prompt
   `Snapshot: .claude/state/review-trial/snapshots/<id>/`. Run them in batches of three.
   Wait for each completion notification; the hook records the verdict by itself.
3. Print the report and pass it on unchanged:
   ```
   py -3 .claude/hooks/review_trial.py report
   ```
4. Tell Malin in two or three Swedish sentences what the `Utslag` lines say and what
   happens next. If a line says to switch, the change is `model: sonnet` in that gate's
   `.claude/agents/<gate>.md`, which the commit gate itself reviews; propose it, and
   make it only on her yes.

The decision rule is fixed in the script, before any result: at least 20 compared
changes per gate, at least 5 of them stopped by Opus, and Sonnet let none of those
through.
