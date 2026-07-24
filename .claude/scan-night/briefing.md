# scan night — agent briefing (2026-07-24)

You are one of several scoped scanners in an unattended overnight backlog scan of the
Butlery Flutter/Firebase app. You do NOT write code and you do NOT create tickets.
You return findings. Someone else files them.

## Step 0 — read these first (mandatory)

1. `.claude/rules/accepted-deviations.md` — deliberate, DECIDED deviations. Anything
   listed there is OUT OF BOUNDS. Do not report it. Re-flagging a decided deviation is
   the single worst failure mode of this scan.
2. `.claude/linear-tracker.json` — a map of ~421 already-filed ticket ids → titles.
   Grep it for your candidate's key nouns/verbs before reporting. If a near-match exists
   (same verb + same target), DROP the candidate and say which id it duplicates.

## What counts as a finding — two classes, two gates

### Class A: DEFECT (label `bug` / `security` / `performance` / `test-gap` / `tech-debt`)
Gate: a correctness, security, data-integrity, or resource-leak bug **confirmed at a real
`file:line` that you opened and read**, with a **stated failure path** — concrete inputs
or state → wrong output, crash, data loss, or exposure. "This looks fragile" is not a
finding. "If a user does X while Y, line 214 reads a null field and throws" is.

### Class B: FEATURE GAP (label `idea`)
Gate: must cite an **anchor**, quoted at `file:line`:
- a `TODO`/`FIXME` in production code, or
- a half-built path (code exists but nothing calls it / no view renders it), or
- data that is captured and stored but never surfaced to the user, or
- a flow dead-end (a button/state that leads nowhere).
No anchor → do not report it. Do not invent product ideas.

## Adversarial self-check (mandatory, per finding)
Before reporting, try to DISPROVE your own finding: is the guard actually elsewhere? is
the caller already checking? is it dead code? is it test-only? Discard anything you
cannot confirm by reading the actual code. Prefer 3 confirmed findings over 12 guesses.

## Aggregation
The same issue in N files = ONE finding listing every site. Do not emit N findings.

## Output format (return ONLY this, no preamble)

For each finding:

```
### <verb-first title, names the file or surface>
CLASS: defect | gap
TYPE: bug|security|performance|test-gap|tech-debt|dependency|idea
AREA: <one or more of: recipe tagging import parsing social menu shopping account analytics settings backend>
PRIORITY: urgent|high|medium|low
ANCHOR: path/to/file.dart:123  (+ a <=2 line verbatim quote)
FINDING: what is wrong, where, how it manifests
FAILURE PATH: concrete inputs/state -> wrong outcome   (defects only)
WHY IT MATTERS: 1-2 sentences
SUGGESTED FIX: the smallest root-cause change
DISPROOF ATTEMPT: what you checked to try to kill this finding, and why it survived
DEDUP: checked tracker for "<terms>" — no match | duplicates BUT-XXXX (then DROP it)
```

End with one line: `SCANNED: <files/dirs you actually read>` and
`NOTHING-FOUND: <areas of your scope where both gates came up empty>`.

Hard cap: 8 findings. If you have more, report the 8 worst and add
`OVERFLOW: <n> more of the same theme in <where>`.
