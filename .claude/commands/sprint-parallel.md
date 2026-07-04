---
description: Run the full-auto PARALLEL sprint — selects Linear tickets, implements area-clusters in parallel worktrees, reviews, commits, pushes to main, closes tickets. Ships autonomously. Use --dry-run to preview first.
argument-hint: [N] [malin] [--dry-run] [--focus <area>] — N = ticket count (default auto 6–10), malin = after the sprint, prep + ask you live about everything waiting on you, --dry-run previews without coding, --focus filters by area label
---

Launch the **`sprint-execute-parallel`** workflow via the **Workflow tool**. This is the
parallel / unattended sprint engine — the same rulebook as `/sprint-execute`
(`.claude/commands/sprint-execute.md`), but it fans implementation across isolated git
worktrees and ships end-to-end on its own (commit + push to main + Linear close).

This slash command is an explicit opt-in to multi-agent orchestration: call the **Workflow**
tool with `name: "sprint-execute-parallel"`. Do not re-implement the sprint logic here — the
workflow script already encodes every phase.

## Parse `$ARGUMENTS` into a real JSON object (never a string)

Build an args **object** — never a JSON string. A stringified arg silently leaves every flag
`undefined`, and a `dryRun` that flips to `false` would ship a full sprint to main by accident
(this has happened — see `memory/feedback_workflow_args_stringification.md`).

- Bare number (e.g. `8`) → `count: 8`. Omit `count` entirely to let it auto-size 6–10 —
  the sizing logic lives in the workflow script, not here; don't attempt to compute it.
- `--dry-run` present → `dryRun: true`. Otherwise omit it (a real, shipping run).
- `--focus <area>` → `focus: "<area>"` (recipe, tagging, import, parsing, social, menu,
  shopping, account, analytics, settings, backend).
- `malin` detection is an exact whitespace-token match on the split arguments (`malin` or
  `--malin`) — never a substring test, which would false-positive on e.g. a focus string.

Examples:
- `/sprint-parallel` → `Workflow({ name: "sprint-execute-parallel", args: {} })`
- `/sprint-parallel --dry-run` → `args: { dryRun: true }`
- `/sprint-parallel 8 --focus recipe` → `args: { count: 8, focus: "recipe" }`

## Before a REAL (non-dry-run) launch

- A real run **commits and pushes to main and closes Linear tickets unattended.** Explicit
  trigger rule: the message contains `--dry-run`, "preview", "kolla först"/"check first",
  or anything hedged → run `--dry-run` and confirm before a real launch. A real run needs
  the bare command or an explicit "ship it"/"kör skarpt". When genuinely ambiguous,
  default to `--dry-run` — a wasted preview is cheap, an accidental ship is not.
- The workflow has its own clean-tree precondition (Phase 0) — it refuses to run on a dirty
  working tree. The override is the workflow arg `allowDirty: true` — pass it ONLY when the
  user explicitly says the dirty files are theirs and should be left alone (a parallel
  session's work, say), never on your own initiative; the default answer to a dirty tree is
  commit/stash first or `--dry-run` (dry runs skip the check — they're read-only).
- If the Workflow tool call itself errors (workflow not found, immediate failure): report
  the error verbatim and stop. Do NOT fall back to running the sprint manually from
  `sprint-execute.md`'s text — an ad-hoc reimplementation of an unattended shipping engine
  is exactly how partial state gets pushed to main.

## After launching

The Workflow tool returns immediately with a Task ID and runs in the background. Tell the user
it's running and that you'll report when it finishes; mention they can watch live with
`/workflows`. When it completes, relay the plain-language summary (what shipped, what's parked
in In Review, what needs them) per `CLAUDE.local.md` — written for a non-coder who wasn't watching.

## `malin` keyword — decision-queue after the parallel run

If `$ARGUMENTS` contains `malin` (or `--malin`), do NOT pass it into the workflow args (the
workflow ships unattended and can't ask anything). Instead, the parallel sprint runs exactly as
normal, and **once the workflow completes**, run **Phase 3.6 of `/sprint-execute`** here in this
session — assemble the queue (need-malin lane + the workflow's Tier-D "needs you" tickets +
any parked high-stakes items it reports), prepare each into a ready-to-decide brief, and ask
Malin **live** via `AskUserQuestion`. She launched the run, so she's present for this tail —
this is where the parallel engine gets the "ask her now" step it otherwise lacks. Strip `malin`
before building the workflow args object so it doesn't get misparsed as a flag.
