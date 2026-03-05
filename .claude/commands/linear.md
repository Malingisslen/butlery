---
description: Linear issue tracker integration (scan, ticket, backlog, clean, status)
argument-hint: <subcommand> [args] — e.g. "scan", "ticket recipe import is clunky", "backlog", "clean", "status"
---

Linear issue tracker skill suite. Dispatches to subcommands based on the first argument.

## No Arguments — Show Cheat Sheet

If the user runs `/linear` with no arguments (empty or blank), display this quick reference and stop:

```
/linear scan              — Analyze code, create tickets in Triage
/linear ticket <thought>  — Quick-capture an idea or bug
/linear backlog           — Browse & pick a ticket to implement
/linear clean             — Hygiene: stale tickets, priority inflation
/linear status            — Dashboard: counts by state, blind spots
```

Do NOT run any analysis or fetch issues. Just print the table above.

## Prerequisites

Before executing any subcommand, verify Linear MCP is connected by checking if `list_issues` tool is available. If not, tell the user: "Linear MCP not connected. Run `/mcp` to reconnect." and stop.

## Deduplication System

**Primary:** `.claude/linear-tracker.json` — maps findings to Linear issue IDs.

Before creating any ticket:
1. Check `.claude/linear-tracker.json` for existing mapping
2. Fetch open issues via `list_issues` and compare titles for near-duplicates
3. Only create if no match found

If `.claude/linear-tracker.json` is missing, create it fresh. If corrupted JSON, rename to `.bak` and start fresh.

After creating tickets, update `.claude/linear-tracker.json` with new mappings.

## Ticket Format

**Title:** Start with a verb: Fix, Add, Refactor, Update, Remove, Improve, Investigate

**Body:**
```markdown
## Finding
What was found, with file path and line numbers.

## Why It Matters
Impact on correctness, security, maintainability, or performance.

## Suggested Fix
Specific enough to act on without re-investigation.
```

**Labels:** Every ticket gets exactly 1 type label + 1 or more area labels.

Type labels: `bug`, `security`, `tech-debt`, `performance`, `test-gap`, `dependency`, `idea`

Area labels: `recipe`, `tagging`, `import`, `parsing`, `social`, `menu`, `shopping`, `account`, `analytics`, `settings`, `backend`

**Priority:** Assign autonomously using:
- Urgent: Production broken, data loss risk
- High: Must fix this week
- Medium: This month, no rush
- Low: Nice to have, someday

No effort estimates in tickets (unreliable). Effort is judged at query time in `/linear backlog`.

## Subcommands

### `scan`

Smart, gap-aware analysis that creates tickets in Triage.

**Steps:**
1. Read existing Linear issues (`list_issues`) to know what's already tracked
2. Check `git log --since="last scan"` (read lastScanDate from tracker) to see what changed recently
3. Determine focus: combine gap-awareness (areas with no tickets), context-driven (recent changes), and rotation (what hasn't been deeply analyzed — check lastScanFocus in tracker)
4. Run analysis tools in parallel:
   - `dart analyze --fatal-infos` — any error or warning
   - `flutter pub outdated` — major version behind or known CVE
   - File size checks — >500 lines (check `docs/architecture/ACCEPTED_LARGE_FILES.md` first)
   - Architecture pattern checks — direct Firebase access, mixed data sources
   - Test coverage gaps — service/ViewModel with 0 test coverage
   - TODO/FIXME grep — any older than 30 days (check git blame)
   - Security — any OWASP M1-M10 violation
5. Verify each finding against actual code (never trust documents as truth)
6. Check deduplication (see system above)
7. Create tickets in Triage with: 1 type label + 1+ area labels + priority + structured body
8. Update `.claude/linear-tracker.json` with new mappings
9. Report summary: "Created X tickets: Y bugs, Z security, W ideas"

**Batching rule:** Same issue in N files = 1 ticket ("Fix X across N files"), not N tickets.

**Thresholds (no ticket below these):**
| Category | Threshold |
|----------|-----------|
| Lint | Any error or warning from `dart analyze` |
| File size | >500 lines (check accepted-large-files list first) |
| Security | Any OWASP M1-M10 violation |
| Test gaps | Service/ViewModel with 0 test coverage |
| Dependencies | Major version behind or known CVE |
| Architecture | Direct Firebase access, mixed data sources |
| TODOs | Any TODO/FIXME older than 30 days |

**Context-aware:** If triggered mid-coding session (context window has active work), spawn a background agent to protect context. If triggered at session start, run inline.

### `ticket <thought>`

Quick capture: turns a raw thought into a structured Linear ticket.

**Steps:**
1. Parse the user's thought into title + body + labels + priority
2. Check deduplication
3. Create ticket in Triage via `create_issue`
4. One-line confirmation: `Created: "Title" [labels] in Triage`
5. No flow interruption — keep working

**Example:** `/linear ticket recipe import flow feels clunky for URLs with auth`
→ `Created: "Improve URL import auth handling" [idea, import] in Triage`

### `backlog`

Shows current backlog with filter dimensions, then starts implementation.

**Steps:**
1. Fetch all tickets in Backlog/Todo states via `list_issues`
2. Display counts grouped by:
   - **Type:** bug (3), security (1), tech-debt (5), ...
   - **Area:** parsing (4), recipe (2), social (1), ...
   - **Effort:** XS (3), S (5), M (2), L (1) — judged at query time
3. Ask user to pick a filter (e.g. "bugs" or "parsing" or "quick wins")
4. Show the highest-priority ticket matching that filter
5. User confirms → start implementation
6. On completion (analyze + tests pass) → move ticket to Done via `update_issue`

### `clean`

Backlog hygiene.

**Steps:**
1. Fetch all open tickets via `list_issues`
2. Flag: tickets in Backlog 90+ days untouched (check updatedAt)
3. Flag: tickets whose underlying issue has been fixed by other work (verify against actual code)
4. Flag: priority inflation (>20% of open tickets are High+Urgent)
5. Suggest: close/cancel stale tickets, adjust priorities
6. Ask user to confirm each action before executing

### `status`

Dashboard overview.

**Steps:**
1. Fetch all tickets via `list_issues`, group by state
2. Show: `Triage (X) | Backlog (Y) | Todo (Z) | In Progress (W) | Done (total)`
3. Show: coverage gaps — which area labels have 0 open tickets (blind spots)
4. Show: last scan date and focus area (from `.claude/linear-tracker.json`)
5. Show: stale ticket count (90+ days untouched)

## Error Handling

- **Linear API rate limits:** If `create_issue` or `list_issues` fails, report the error and stop. Don't retry in a loop. Report what was created so far.
- **Missing labels:** Before creating tickets, verify label names exist via `list_issue_labels`. If a label doesn't exist, warn the user to create it manually in Linear.
- **Tracker issues:** Never crash on tracker file problems — recreate if missing, backup if corrupted.

## Incidental Discovery (During Normal Coding)

This applies outside of `/linear` commands, during regular coding sessions:

- When encountering an issue in a file you're NOT actively working on: mention it inline and ask "Want a ticket?"
- When encountering a small fix (XS effort) in the SAME file you're editing: fix it on the spot (boy scout rule), mention in commit message. No ticket.

## Relationship to Other Systems

- **Linear** = long-term backlog (bugs, ideas, tech debt, security — persists across sessions)
- **`/tasks/todo.md`** = session-level tasks (current session work)
- **Master plan** = reference input for `/linear scan`, but always verified against actual code
