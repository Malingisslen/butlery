# AGENTS.md

Rules in `.Codex/rules/` are auto-loaded; some load only when you open the code they
govern.

## Critical Rules

1. **Find root causes** — proper fixes over quick patches. If stuck, say what you
   investigated and why.
2. **500-line limit** — facade pattern above it (details in code-style).
3. **Security validation** — PermissionValidationMixin on all repositories.
4. **Ask before deviating** from planned tasks.
5. **Plans = execute + verify** — if a plan or spec exists, implement it rather than
   re-planning it. "Implement" includes the verification steps. If verification fails,
   report what happened; don't claim done.
6. **Pushback = re-read** — a terse follow-up after "done" means something was missed.
   "No, I want X" means the request was misunderstood. Re-read before responding.
7. **Be accurate about scope** — don't over-estimate complexity.
8. **No retry loops on plan/review gates** — if rejected, ask rather than retrying.
9. **Learn from corrections and hard-won approaches** — see the self-improvement loop in
   workflow-discipline; the lesson and its digest line belong in the same edit.
10. **Honesty over completion** — "I don't know" is acceptable. A partial solution with
    clear gaps beats papering over problems. Never claim done if verification was skipped.
11. **Check before "not doable"** — before concluding something is impossible or out of
    scope, do two checks and say which you did: (a) **your own current tools** — the
    capability is often already in this session (driving a real browser, parallel
    subagents, multi-step workflows, very large context); (b) **web search** — if the doubt
    is about what exists or is currently possible, search before answering from memory;
    your training data is older than the frontier. Only then call it not doable, and say
    what you tried. This raises what you *attempt*; it does not lower the bar for verifying
    what you *did*.

## Data sources (the footgun)

- `userService.currentUserProfile` → complete user data (settings, avatar, social).
- `permissionService.currentUserId` → auth and permission checks only.

Never mix them — it silently breaks settings persistence. See the `data-source-enforcer`
skill.

## Cost principles

Every feature decision considers running cost. Prefer deterministic logic — code, rules,
algorithms — over LLM calls; use an LLM only where free-text understanding or creative
generation genuinely needs one, then optimize it (prompt caching, smaller models,
batching). On Firebase, avoid unnecessary reads and writes: batch, cache, query efficiently.

## Architecture

MVVM + Repository. New code uses the project's mixins and base classes (`mixin-advisor`
skill); the layer patterns live in the `butlery-architecture` skill.

**Workflow map freshness:** `docs/onboarding/workflow-map.html` documents every end-to-end
flow, and CI fails if a path it references disappears or a feature loses flow coverage. A
hook stamps `docs/onboarding/workflow-map.stale` when mapped code is edited. **If that
marker exists:** re-trace only the flows whose nodes match the marker's `triggers`, update
the map's `<script id="data">` JSON and nothing else, run the linter, delete the marker,
commit both. Don't rebuild the map; don't ignore the marker.

## Commands

`flutter analyze` / `flutter run` / `flutter test test/unit/<file>_test.dart`. Always use
forward slashes in test paths. Before declaring work done, the `verify` skill runs the full
check (analyze + tests on changed files).

## Stop hook response

When the stop hook blocks with a `reason`, fix it immediately rather than asking:
"uncommitted" → commit now; "analyze" → run analyze and fix; "tests" → run and fix.

It is session-aware: it only blocks on errors in files THIS session modified, so errors
from a parallel session are not yours. If the analyzer itself looks broken — truncated
output, no findings listed, timeouts — follow `docs/ops/analyzer-recovery.md` before
treating anything as a real finding.

## Agents

**Before filing any review finding, check `.Codex/rules/accepted-deviations.md`** — those
calls are decided, and the full reasoning is in `docs/architecture/ACCEPTED_DEVIATIONS.md`,
which the commit gate names when it blocks. Point review agents at it too.

- **debugger** — strongly recommended for any bug, error, test failure, or unexpected behavior.
- **Commit-gated specialists** — a `.dart` or `functions/src` diff is blocked until the
  matching specialist has reviewed it and the marker names every staged file. The gate
  names the exact agent, marker and command when it fires; the authoritative mapping is
  `.Codex/shared-plugin.json → reviewGates`. Agents stall on more than three files — split
  the commit or run them in batches.
- **On request** — uiux-designer, performance-optimizer, flutter-developer, e2e-test-specialist.

Several agents keep a sibling `<agent>.knowledge.md`. It holds **principles** and is meant
to be rewritten — a discovery updates the principle it belongs to. The dated raw record goes
to `<agent>.knowledge.archive.md`, which is append-only and is what you grep when a principle
is too compressed to explain what you're seeing. Each agent's definition states its own
version of this. New agents get one by default unless their domain is too varied for
patterns to be anything but noise.
