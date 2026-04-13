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

## Agent Usage Rules

**Tier 1 — Strongly Recommended:**
- **debugger** — bug reports, errors, test failures, unexpected behavior
- **firebase-backend-security** — lib/repositories/, Firebase/Firestore/auth, user data

**Tier 2 — Commit Enforced (automatic):**
- **code-reviewer** — reviews staged .dart changes
- **testing-specialist** — verifies test coverage for modified lib/ files

**Tier 3 — On Request:**
- **uiux-designer**, **performance-optimizer**, **flutter-developer**
