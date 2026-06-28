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
9. **Learn from corrections** — on any correction, IMMEDIATELY add to `tasks/lessons.md` (format: `### [Category] Title` + Date, Trigger, Rule, Example) before doing anything else.
10. **Honesty over completion** — "I don't know" is acceptable. Partial solution with clear gaps beats papering over problems. Never claim done if you skipped verification.

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

## Pre-commit /code-review effort

The `/code-review` built-in (renamed from `/simplify` in CLI 2.1.146) gates `git commit` via `.claude/hooks/require-simplify-before-commit.sh`. When the hook blocks, run:

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

**Tier 2 — Commit Enforced (hook-backed via `.claude/hooks/require-review-before-commit.sh`):**

The hook blocks `git commit` until a fresh marker exists at `.claude/state/<name>-done.marker` for each specialist whose path pattern matches the staged diff. Markers are stale-checked by mtime: newest changed-file mtime > marker mtime → re-review required.

| Trigger pattern | Required agent | Marker |
|---|---|---|
| Any `*.dart` | `code-reviewer` | `code-review-done.marker` |
| Any `lib/**/*.dart` | `testing-specialist` | `testing-review-done.marker` |
| `lib/repositories/`, `lib/services/{firebase\|firestore\|auth\|user\|gdpr}`, `functions/src/` (excl. tests) | `firebase-backend-security` | `firebase-security-done.marker` |
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
