# Scan — Role #18 Claude AI-Harness Owner / Agent-Ops Lead

Reviewed through the harness lens: hook correctness, commit gates, marker
workflow, agent-trigger mismatches, knowledge-file discipline, rule/CLAUDE.md
consistency, settings.json, command registration. Two passes.

DEDUP checked against tasks/_scan_dedup_titles.txt, .claude/linear-tracker.json,
.claude/rules/accepted-deviations.md. None of the below are already tracked.

---

## NEW findings

### 1. `cloud-functions-specialist` is a commit-gate ghost — agent + knowledge file + marker exist, but no gate trigger and no CLAUDE.md mention
- type: tech-debt
- severity: medium
- The agent `.claude/agents/cloud-functions-specialist.md:3` declares **"MUST BE
  USED when modifying files in functions/src/"**, has a 110 KB knowledge file
  (`cloud-functions-specialist.knowledge.md`), and there is even a stale
  `.claude/state/cloud-functions-done.marker` (created 2026-06-20) — implying a
  past run touched the marker workflow.
- BUT `require-review-before-commit.sh:104-118` maps `functions/src/` (excl.
  `__tests__/`) to **`firebase-backend-security`**, not cloud-functions-specialist.
  So the agent's own "MUST BE USED" clause is never enforced by any commit gate.
- AND `CLAUDE.md` mentions the agent **nowhere** — not in the Tier-2 trigger
  table (CLAUDE.md ~line 88-99), not in the knowledge-file agent list (line 106).
- Net effect: a TypeScript Cloud Functions specialist exists with full
  infrastructure but is invisible to the documented harness contract. Either
  wire it into the gate (e.g. `functions/src/` → cloud-functions-specialist,
  with firebase-backend-security for the Flutter-side Firestore paths), or
  retire the orphan marker + downgrade the agent's "MUST BE USED" to "on
  request" and document the decision. Today the three sources of truth
  (agent def, gate, CLAUDE.md) disagree.
- Evidence: `.claude/agents/cloud-functions-specialist.md:3`,
  `.claude/hooks/require-review-before-commit.sh:104-118`,
  `.claude/state/cloud-functions-done.marker`, `CLAUDE.md:88-114`

### 2. CLAUDE.md knowledge-file list is stale — names 5 of 7 actual knowledge files
- type: tech-debt
- severity: low
- `CLAUDE.md:106` states: *"Agents with knowledge files: firestore-rules-tester,
  uiux-designer, firebase-backend-security, testing-specialist,
  performance-optimizer."*
- Actual `.claude/agents/*.knowledge.md` files number **7**: the list omits
  **`cloud-functions-specialist`** and **`e2e-test-specialist`**, both of which
  carry the Step-0-read / append-on-discovery contract in their agent defs and
  are picked up by `knowledge-freshness.sh` (which globs all `*.knowledge.md`).
- Consequence: the documented contract under-counts the agents it governs; a
  reader auditing knowledge-file discipline would miss two of them. Fix is a
  one-line update to CLAUDE.md:106.
- Evidence: `CLAUDE.md:106`, `.claude/agents/cloud-functions-specialist.knowledge.md`,
  `.claude/agents/e2e-test-specialist.knowledge.md`,
  `.claude/hooks/knowledge-freshness.sh:24`

### 3. `/permission-audit` command exists but is unregistered / undocumented
- type: tech-debt
- severity: low
- `.claude/commands/permission-audit.md` exists but is the only command in that
  directory not surfaced in the session's available-skills list and is not
  referenced from CLAUDE.md, the rules, or settings.json. (Other org commands —
  world-watch, org-retro, refresh-dossiers, stakeholder-review — are all both
  present and surfaced.)
- Either it's a dead/legacy command (delete it) or it should be registered the
  same way the other commands are. Low impact, but it's exactly the
  "command registration gap" class this role owns.
- Evidence: `.claude/commands/permission-audit.md` (only `permission-audit`
  reference repo-wide is the file itself)

---

## Verified-and-fine (no ticket — recorded so a future pass doesn't re-open)

- **Commit-gate trigger map** in `require-review-before-commit.sh:92-127` matches
  the CLAUDE.md table for the four documented agents (code-reviewer / testing /
  firebase-security / rules-tester); patterns and markers align. (The only
  divergence is the cloud-functions ghost, finding #1.)
- **Marker staleness logic** (mtime newest-changed-file > marker) is correct in
  both require-review and require-simplify; deleted-file guard (`-f`) present.
- **Argument parsing** (shlex `-a`/`--all` detection, takes-arg skip list) is
  sound; fails closed to staged-only, which is the safe under-block direction.
- **plan-review-gate.sh** two-call stateful flow (write marker → block → fresh
  marker → allow), per-session hash, stale-TTL GC, high-stakes escalation: all
  correct. Matches lessons/memory.
- **loop-pace-guard.sh** $HOME-vs-$PROJECT_ROOT state split (flagged in the
  dossier) is currently benign — guard only READS the project scan file, never
  writes it; both dirs are mkdir'd by their own writers. Not re-filed.
- **settings.json** hook wiring is internally consistent; every referenced
  hook script exists on disk. New org hooks (suggest-stakeholder-review,
  dossier-freshness-stamp, world-watch/org-retro due-checks) all present and
  fail-open.
- **Recently-modified knowledge files** (firestore-rules-tester, firebase-
  backend-security, testing-specialist, cloud-functions-specialist) follow the
  append-only dated-entry discipline; no truncation/rewrite drift observed.

---

COVERAGE: Pass 1 (hook correctness, commit gates, trigger map, marker workflow)
+ Pass 2 (rule/CLAUDE.md consistency, knowledge-file drift, settings.json,
command registration) complete. 3 NEW actionable defects found, all
documentation/registration drift (no functional gate is broken). Per the
"meta-tooling rarely ticketed" guidance these are concrete and actionable but
low/medium severity.
