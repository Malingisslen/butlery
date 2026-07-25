---
paths:
  - ".claude/hooks/**"
  - ".claude/skills/**"
  - ".claude/workflows/**"
---

# Automation and parallel-agent proposals

Detail behind two workflow-discipline stubs. Loads when editing a hook, skill, or the
delivery workflow engine — the places a new automated loop or a parallel-agent fan-out
gets proposed. Kept out of always-on because these rules govern a PROPOSAL, not an edit;
the path trigger is an imperfect proxy, which is why workflow-discipline.md keeps a
one-line resident version of each.

## The four-box test

A hook, scheduled routine, self-running loop or agent earns its keep only if all four hold.
Miss one and it stays a manual tool, honestly labelled:

1. **Repeats at least weekly** — below that the setup never amortizes.
2. **Something can auto-reject bad output** — a test, gate or hard rule fails the work
   without a human. No gate and the loop just spins and bills.
3. **Runs end-to-end** — if it stalls waiting for a human mid-run it's a manual step in a
   loop costume.
4. **"Done" is objective, not taste** — automate the detection, leave the decision.

It also needs a named firing path (hook, schedule, gate) or it rots unread. Prefer
deterministic code over an LLM call inside any loop.

## Parallel agent tasks

Process files in small chunks (50–100 items), never a whole large file at once. Define
chunk boundaries before launching. Verify agents aren't overwriting each other. For a plan
with 10+ items, run sequentially or in batches of 2–3.
