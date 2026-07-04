---
description: Linear issue tracker integration (scan, ticket, backlog, clean, status)
argument-hint: <subcommand> [args] — e.g. "scan", "ticket recipe import is clunky", "clean", "status" (to build a ticket interactively, use /sprint-execute --pick)
---

Linear issue tracker skill suite. Dispatches to subcommands based on the first argument.

## No Arguments — Show Cheat Sheet

If the user runs `/linear` with no arguments (empty or blank), display this quick reference and stop:

```
/linear scan              — Balanced analysis: bugs + hygiene + ideas
/linear scan deep         — Deep bug/security dive (ultrathink agents)
/linear scan creative     — Product improvement focus: UX, features, rework
/linear scan hygiene      — Lint, deps, file size, TODOs only
/linear ticket <thought>  — Quick-capture an idea or bug
/linear clean             — Hygiene: stale tickets, priority inflation
/linear status            — Dashboard: counts by state, blind spots

Build a ticket interactively → /sprint-execute --pick  (replaced /linear backlog)
```

Do NOT run any analysis or fetch issues. Just print the table above.

## Prerequisites

Before executing any subcommand, verify Linear MCP is connected by checking if `list_issues` tool is available. If not, tell the user: "Linear MCP not connected. Run `/mcp` to reconnect." and stop.

## Deduplication System

**Primary:** `.claude/linear-tracker.json` — maps findings to Linear issue IDs.

Before creating any ticket:
1. Check `.claude/linear-tracker.json` for existing mapping
2. Fetch open issues via `list_issues` and compare titles for near-duplicates.
   **Near-duplicate heuristic:** same area label AND ≥60% of the candidate title's
   non-stopword tokens appear in an existing open title → treat as a suspected dup;
   confirm with one judgment pass ("is this the same underlying issue in the CURRENT
   code?") before dropping. Remember the dedup lesson: match against the live code +
   decided-nos, never against closed-ticket titles alone — a closed same-name ticket
   may be a regression to REFILE.
3. Only create if no match found

If `.claude/linear-tracker.json` is missing, create it fresh with this minimal skeleton
(then fill as tickets are created):
```json
{ "lastScanDate": null, "lastScanFocus": null, "findings": {} }
```
If corrupted JSON, rename to `.bak` and start fresh from the same skeleton.

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

**Stakeholders (stamped on every ticket — experts assigned from the start):** For each ticket,
run `python tools/stakeholder_router.py --json <paths the finding touches>` and record the owning
role(s) in the body as a `## Stakeholders` line (e.g. `Security Architect, Privacy / Data Protection
Officer (GDPR)`). This is *who reviews the ticket before it's built* — `/sprint-execute` reads it
(Phase 1.4, including `--pick` interactive mode). Keep it in the body, not a Linear label, so no new label infra
is needed. A `full-panel` routing result means the ticket touches a high-stakes path — also note
`(high-stakes)` after the stakeholder line so the backlog reads honestly.

**Priority:** Assign autonomously using:
- Urgent: Production broken, data loss risk
- High: Must fix this week
- Medium: This month, no rush
- Low: Nice to have, someday

No effort estimates in tickets (unreliable). Effort is judged at query time in `/sprint-execute --pick`.

## Subcommands

### `scan`

Smart, gap-aware analysis that creates tickets in Triage. Has four modes:

#### Modes

- **`scan`** (no modifier) — Balanced scan. Runs hygiene checks + code analysis + creative ideas. Target output: ~40% bugs/security, ~30% hygiene/tech-debt, ~30% ideas/improvements.
- **`scan deep`** or **`scan ultrathink`** — Deep bug/security dive using parallel agents. Focused on finding correctness, security, concurrency, and data-integrity issues through exhaustive code reading.
- **`scan creative`** — Product improvement focus. Minimal bug-hunting. Instead: UX friction, feature gaps, refactoring opportunities, architecture rethinks, modern tech adoption. Uses web searches for industry benchmarking.
- **`scan hygiene`** — Quick automated checks only: `dart analyze`, `flutter pub outdated`, file sizes, TODO/FIXME age, architecture pattern violations. No deep code reading.

User can also add free-form focus hints: `/linear scan deep auth and social` or `/linear scan creative onboarding flow`.

#### Common Steps (all modes)

1. Read existing Linear issues (`list_issues`) to know what's already tracked
2. Check what changed since the last scan: read `lastScanDate` from the tracker and
   substitute the ACTUAL value — `git log --since="<lastScanDate>"` (e.g.
   `--since="2026-06-27"`). If `lastScanDate` is null/absent (first run), default to
   `--since="30 days ago"`. Never pass the literal words "last scan" to git.
3. Determine focus: combine gap-awareness (areas with no tickets), context-driven (recent changes), and rotation (what hasn't been deeply analyzed — check lastScanFocus in tracker)
4. Run analysis (mode-specific — see below)
5. Verify each finding against actual code (never trust documents as truth)
6. Check deduplication (see system above)
7. Create tickets in Triage with: 1 type label + 1+ area labels + priority + structured body
8. Update `.claude/linear-tracker.json` with new mappings
9. Report summary: "Created X tickets: Y bugs, Z security, W tech-debt, V ideas"

**Batching rule:** Same issue in N files = 1 ticket ("Fix X across N files"), not N tickets.

#### Hygiene Analysis (runs in `scan` and `scan hygiene`)

Run these automated checks in parallel:
- `dart analyze --fatal-infos` — any error or warning
- `flutter pub outdated` — major version behind or known CVE
- File size checks — >500 lines (check `docs/architecture/ACCEPTED_LARGE_FILES.md` first)
- Architecture pattern checks — direct Firebase access, mixed data sources
- Test coverage gaps — service/ViewModel with 0 test coverage
- TODO/FIXME grep — any older than 30 days (check git blame)
- Security — any OWASP M1-M10 violation

**Hygiene thresholds (no ticket below these):**
| Category | Threshold |
|----------|-----------|
| Lint | Any error or warning from `dart analyze` |
| File size | >500 lines (check accepted-large-files list first) |
| Security | Any OWASP M1-M10 violation |
| Test gaps | Service/ViewModel with 0 test coverage |
| Dependencies | Major version behind or known CVE |
| Architecture | Direct Firebase access, mixed data sources |
| TODOs | Any TODO/FIXME older than 30 days |

#### Deep Analysis (runs in `scan deep` / `scan ultrathink`)

Launch 4-6 parallel Explore agents, each assigned a focused code area — **model `sonnet`;
effort `high` for this deep mode** (exhaustive code reading earns the higher effort;
hygiene/census modes elsewhere in this command run `sonnet`/low). Agents perform
exhaustive code reading looking for bugs, security issues, race conditions, logic errors,
data integrity problems, and edge cases. Report findings with exact file paths, line
numbers, severity, and suggested fixes.

**Seat a role lens where the area maps to one.** When a code area is owned by a role (per
`docs/org/role-paths.json`), give that agent the role's dossier section in
`docs/architecture/ROLE_RESPONSIBILITY_MAP.md` as its reviewing lens — e.g. the agent reading
`firestore.rules` / `lib/services/auth/**` reviews as the **Security Architect** (and its watch-items),
the agent on `lib/services/parsing/**` as the **Data / ML Engineer**. This turns the generic
"think like a staff engineer" framing into a specific, dossier-grounded specialist — the right
expert finding the right class of issue.

#### Creative Analysis (runs in `scan` and `scan creative`)

This is where the AI thinks like a product designer, senior architect, and tech lead — not just a bug finder. No rigid thresholds. Trust your judgment about what would genuinely improve the product.

**Creative categories:**

| Category | What to look for | Label |
|----------|-----------------|-------|
| **UX friction** | Flows that work but feel wrong — too many taps, missing feedback, confusing navigation, dead-ends, no undo, poor empty states, missing loading/error states | `idea` |
| **Feature gaps** | Missing capabilities users would expect from a modern recipe app — compare to competitors, look at the user journeys and find holes | `idea` |
| **Refactoring** | Working code that's unnecessarily complex, duplicated patterns begging for abstraction, wrong abstraction level, code that fights itself | `tech-debt` |
| **Rework** | Entire subsystems where the design is fundamentally wrong — worth rebuilding. Signs: 3+ bug tickets in the same area, workarounds layered on workarounds | `tech-debt` |
| **Modern tech** | Opportunities to adopt newer Flutter/Dart/Firebase features, better libraries, modern patterns that would simplify the codebase | `tech-debt` or `idea` |
| **Performance wins** | Not bugs, but opportunities for noticeably faster UX — lazy loading, prefetching, caching strategies, reducing unnecessary rebuilds | `performance` |
| **DX improvements** | Things that make the codebase harder to work with — inconsistent patterns, missing shared infrastructure, testability blockers | `tech-debt` |

**Creative analysis techniques:**

1. **Web research** — Use `WebSearch` and `WebFetch` to research:
   - How top recipe apps (Paprika, Mealime, Whisk, Cookpad, Tasty) handle similar features
   - Modern Flutter architecture patterns and best practices (Riverpod vs Provider, go_router patterns, offline-first strategies)
   - Industry standards for the feature area being scanned (e.g., WCAG for accessibility, Schema.org for recipe data, PWA best practices for web)
   - New Flutter/Dart features that could simplify existing code
   - Firebase best practices and newer APIs that replace older patterns in the codebase

2. **User journey walkthrough** — Mentally walk through key user journeys and identify friction:
   - New user: install → register → onboard → first recipe → first cook
   - Returning user: open app → find recipe → cook → rate
   - Social user: share recipe → friend receives → imports → cooks together
   - Power user: bulk import → organize with tags → plan week menu → generate shopping list

3. **Architecture smell detection** — Look for systemic problems, not just individual bugs:
   - Which subsystems have the most bug tickets? (check tracker) → candidate for rework
   - Where do workarounds cluster? → the underlying design is fighting the use case
   - What patterns are used inconsistently? → standardize or pick one
   - What's the simplest version of this that would still work? → over-engineering detector

4. **"What would a staff engineer say?"** — For each area scanned, ask: if a senior engineer joined the team tomorrow and reviewed this code, what would they flag as the biggest improvement opportunity?

**Creative ticket format** (different from bug tickets):

```markdown
## Opportunity
What could be better and why it matters to users or developers.

## Current State
How it works today (briefly).

## Proposed Improvement
Concrete vision of the better state. Include references to how other apps/frameworks handle this if relevant.

## Effort vs Impact
Brief assessment: is this a quick win or a major undertaking? What's the user-visible payoff?
```

**Context-aware:** Concrete signal — if the working tree has uncommitted changes OR
`tasks/todo.md` holds an in-progress plan, treat it as mid-coding session and spawn a
background agent to protect context. Clean tree and no active plan → run inline.

### `ticket <thought>`

Quick capture: turns a raw thought into a structured Linear ticket.

**Steps:**
1. Parse the user's thought into title + body + labels + priority + `## Stakeholders` (run the
   router on the paths the thought implies — cheap, non-interrupting)
2. Check deduplication
3. Create ticket in Triage via `create_issue`
4. One-line confirmation: `Created: "Title" [labels] · stakeholders: <roles> in Triage`
5. No flow interruption — keep working

**Example:** `/linear ticket recipe import flow feels clunky for URLs with auth`
→ `Created: "Improve URL import auth handling" [idea, import] in Triage`

### `backlog` (removed — folded into `/sprint-execute --pick`)

The old `backlog` subcommand (browse the backlog → pick one ticket → build it) was removed
2026-06-27 because it overlapped `/sprint-execute`. Its replacement is **`/sprint-execute --pick`**:
the same grouped browse-and-pick selection, but with the full review → verify → commit → push →
close ceremony and live high-stakes escalation. If a user types `/linear backlog`, point them there.

### `clean`

Backlog hygiene.

**Steps:**
1. Fetch all open tickets via `list_issues`
2. Flag: tickets in Backlog 90+ days untouched (check updatedAt). **Exempt world-watch /
   escalate-human tickets** — issues filed by `/world-watch` (Security/Release auto-tickets, Legal
   escalations; recognizable by a source-URL citation + a `## Stakeholders` line) run on their own
   cadence and a Legal item may legitimately wait on Malin. Don't flag them as stale.
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
6. Show: **stakeholder coverage** — which roles own open tickets (from the `## Stakeholders`
   lines), and which world-watch roles are **overdue for a scan**: read
   `docs/org/world-watch/state.json` and flag any role where `now − lastScan ≥ cadence`
   (Security weekly, Release weekly, Legal monthly). This surfaces horizon-scan debt next to
   backlog debt.

## Error Handling

- **Linear API failures — triage by class, keep partial results:** a transient/5xx/
  rate-limit error → wait ~30s and retry ONCE; still failing → stop, but SAVE completed
  work (update the tracker with tickets already created, report the created list + the
  not-yet-filed drafts so nothing is lost). An auth/4xx/permission error → stop
  immediately (retrying can't help), same partial-results report. Never retry in a loop.
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
