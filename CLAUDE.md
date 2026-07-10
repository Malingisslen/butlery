# CLAUDE.md

Additional rules in `.claude/rules/` are auto-loaded.

## Critical Rules

1. **Find root causes** — proper fixes over quick patches. If stuck, say what you investigated and why.
2. **500-line limit** — use facade pattern for complex files
3. **Security validation** — PermissionValidationMixin on all repositories
4. **Ask before deviating** from planned tasks
5. **Plans = execute + verify** — if a plan/spec exists, implement it (don't re-plan). "Implement" includes verification steps. If verification fails, report what happened — don't claim done.
6. **Pushback = re-read** — terse follow-up after "done" means you missed something. "No, I want X" means you misunderstood. Re-read before responding.
7. **Be accurate about scope** — don't over-estimate complexity
8. **No retry loops** on plan/review gates — if rejected, ask user instead of retrying
9. **Learn from corrections AND hard-won approaches** — on any correction, IMMEDIATELY add to `tasks/lessons.md` (format: `### [Category] Title` + Date, Trigger, Rule, Example) AND append its one-line rule to `.claude/rules/lessons-digest.md` (the auto-loaded surface — a lesson not in the digest is not in force) before doing anything else. Same contract when a hard problem is SOLVED (took more than one failed attempt, or hinged on a non-obvious judgment call): record the approach that worked, so the reasoning survives the session instead of evaporating with it. A Stop-hook tripwire warns if the two drift.
10. **Honesty over completion** — "I don't know" is acceptable. Partial solution with clear gaps beats papering over problems. Never claim done if you skipped verification.
11. **Check before "not doable"** — before concluding something is impossible or out of scope, do two checks and say which you did: (a) **Your own current tools first** — the capability is often already in this session. You routinely forget you can drive a real browser (Chrome automation — for anything visual, login-gated, or "just click through it"), run subagents in parallel, run multi-step Workflows, and hold very large context. If one fits, try it. (b) **Web-search the world second** — if the doubt is about what *exists* or is *currently possible* (a tool, API, model capability), search before answering from memory; your training data is older than the frontier. Only then may you call it not doable — and state what you tried. Raises what you *attempt*; does not lower the bar for verifying what you *did*.

## Critical Conventions

**Data Sources** (see `data-source-enforcer` skill):
- `userService.currentUserProfile` → complete user data (settings, avatar, social)
- `permissionService.currentUserId` → auth/permission checks only
- Never mix these — causes settings not persisting

## Cost Principles

- **Minimize running costs** — every feature decision should consider operational expense
- **Prefer deterministic logic over LLM calls** — use code, rules, and algorithms when possible; LLMs only when genuinely needed (e.g., free-text understanding, creative generation)
- **When LLMs are necessary** — optimize: prompt caching, smaller models where sufficient, batching
- **Firebase** — avoid unnecessary reads/writes; batch operations, cache, use efficient queries

## Architecture

**Pattern**: MVVM + Repository (Views → ViewModels → Services → Repositories → Firebase)

**The USP chain** (import→parse→tag→personalize + learning loop): read
`docs/architecture/RECIPE_PIPELINE.md` before working on import/parsing/tagging/menu code —
it maps what is live vs dormant vs dead (audited 2026-07-01). Improvement backlog:
`docs/architecture/PIPELINE_IMPROVEMENT_ROADMAP.md`.

**Workflow map freshness:** `docs/onboarding/workflow-map.html` (interactive, JSON-driven)
documents ALL end-to-end flows — full coverage of the 137-feature inventory. CI fails if a
path it references stops existing OR if any `docs/feature_inventory.csv` ID loses flow
coverage (`tools/check_workflow_map.py`) — so a new feature requires a map flow. A PostToolUse hook stamps `docs/onboarding/workflow-map.stale`
when mapped code is edited. **If that marker exists:** re-trace ONLY the flows whose nodes match
the marker's `triggers`, update the map's `<script id="data">` JSON (nothing else), run the
linter, delete the marker, commit both. Don't rebuild the map; don't ignore the marker.

See `.claude/rules/code-style.md` for file size limits, service access, syntax, commenting.
See `.claude/rules/git-workflow.md` for git safety, pre-commit checks, lefthook.
See `.claude/rules/workflow-discipline.md` for plan mode, verification, self-improvement.
See `.claude/rules/ui-conventions.md` for responsive design, mockup comparison.

New code must use project mixins and base classes — see `mixin-advisor` skill.

## Testing Philosophy

Tests verify **intended behavior**, not green status.

1. **Intention first** — articulate what behavior a test proves. One sentence or it's unfocused.
2. **Failing test might be right** — ask "is the test correct?" before "how do I make it pass?" Never weaken assertions just to go green.
3. **Mock dependencies, not the subject** — a test that mocks away the behavior it claims to verify proves nothing.
4. **Test the contract** — inputs → outputs and side effects, not implementation details. One meaningful behavioral test beats ten getter checks.

## Commands
- `flutter analyze` / `flutter run` / `flutter test test/unit/file_test.dart`
- Always use forward slashes in test paths

## Stop Hook Response

When stop hook blocks with a `reason`, fix it immediately — don't ask the user:
- "uncommitted" → commit now
- "analyze" → run analyze and fix
- "tests" → run tests and fix

Session-aware: only blocks on errors in files THIS session modified. Ignore errors from parallel sessions.

**Analyzer false positives:** a block whose message is truncated right after "Analyzing butlery..." (no findings listed) while this session touched no `.dart` files is the analysis server crashing (contention or bloated `.dartServer` cache), not a real finding. Verify with one fresh `dart analyze` run: if clean, state that and continue — do not "fix" anything. If the analyzer keeps crashing: kill `dart.exe` zombies; the durable fix is clearing `%LOCALAPPDATA%\.dartServer` with VS Code closed (IDE holds the lock).

## Pre-commit /code-review effort

The `/code-review` built-in (renamed from `/simplify` in CLI 2.1.146) gates `git commit` via the shared `workflow-guards` plugin (`require-simplify-before-commit` hook; config in `.claude/shared-plugin.json`). When the hook blocks, run:

- `/code-review high` — default for Dart diffs
- `/code-review xhigh` — on Opus 4.7 when the diff touches `lib/repositories/`, `lib/services/{firebase|firestore|auth|user|gdpr}`, `functions/src/`, or `firestore.rules`
- `/code-review` (no arg) — only for trivial single-file diffs

Then `touch .claude/state/simplify-done.marker` and retry. The marker filename keeps the legacy `simplify-` prefix to avoid colliding with the `code-reviewer` agent's marker below — they are different reviewers gating different things.

If on CLI < 2.1.146, use `/simplify` (same effect, no effort param).

## Agent Usage Rules

**Before filing review findings — consult `.claude/rules/accepted-deviations.md`.** It lists
deliberate, decided deviations from otherwise-applicable rules (e.g. equality-only Firestore
queries needing no composite index, accepted large files, intentional mockup departures). Do
not re-flag anything listed there; when dispatching a review agent, point it at this file so
it does the same. A genuinely new deviation gets appended there (dated), not argued in a review.

**Tier 1 — Strongly Recommended (debugging / investigation):**
- **debugger** — bug reports, errors, test failures, unexpected behavior

**Tier 2 — Commit Enforced (hook-backed via the shared `workflow-guards` plugin's `require-review-before-commit` hook; the agent→marker matrix lives in `.claude/shared-plugin.json`):**

The hook blocks `git commit` until a fresh marker exists at `.claude/state/<name>-done.marker` for each specialist whose path pattern matches the staged diff. Markers are stale-checked by mtime: newest changed-file mtime > marker mtime → re-review required.

| Trigger pattern | Required agent | Marker |
|---|---|---|
| Any `*.dart` | `code-reviewer` | `code-review-done.marker` |
| Any `lib/**/*.dart` | `testing-specialist` | `testing-review-done.marker` |
| `lib/repositories/`, `lib/services/{firebase\|firestore\|auth\|user\|gdpr}` | `firebase-backend-security` | `firebase-security-done.marker` |
| `functions/src/` (incl. `__tests__/`) | `cloud-functions-specialist` | `cloud-functions-done.marker` |
| `firestore.rules`, `functions/src/__tests__/*-rules.test.ts` | `firestore-rules-tester` | `rules-tester-done.marker` |

**Marker workflow:** dispatch the named agent against the staged diff → after it reports clean, run `touch .claude/state/<marker>` → retry commit. Hook is silent when no triggers match (doc-only commits, etc.). Per `memory/feedback_agent_timeout.md`, agents stall on >3 files — split commits or run in batches.

**Tier 3 — On Request:**
- **uiux-designer**, **performance-optimizer**, **flutter-developer** — invoke explicitly when the diff warrants a specialist beyond Tier 2.

## Agent Knowledge Files (self-improvement pattern)

Several agents have a sibling `<agent>.knowledge.md` file holding accumulated patterns across sessions. Agents with knowledge files: `firestore-rules-tester`, `uiux-designer`, `firebase-backend-security`, `testing-specialist`, `performance-optimizer`, `cloud-functions-specialist`, `e2e-test-specialist`.

**Contract (applies to every knowledge file):**
- Agent reads it as **Step 0** of every invocation.
- Agent **APPENDS** a dated entry when it discovers a new pattern, fixes a real bug, or is corrected by the user.
- **Append-only** — supersede with a newer dated entry; never delete.
- Distinct from the global self-improvement loop in `tasks/lessons.md` (rule #9): knowledge files are agent-scoped; lessons.md is global.

When creating a new agent, default to giving it a knowledge file unless the agent's domain is so varied that accumulated patterns would become noise (e.g. `debugger`).
