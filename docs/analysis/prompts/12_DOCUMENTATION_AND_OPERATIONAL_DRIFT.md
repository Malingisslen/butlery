# 12 — Documentation & Operational Drift Analysis

**Analyst:** Claude (Opus 4.7) or OpenAI Codex
**Mission:** Detect every place where Butlery's written documentation, runbooks, agent knowledge files, and operational claims have drifted out of alignment with the current code. The goal is to surface stale, contradictory, or outright wrong statements before they mislead an engineer (human or AI) and cause the wrong fix.
**Orchestrator weight:** 6% of overall codebase health score.

**Cross-Prompt Boundaries:**
- Code-quality issues themselves: covered in `01_CODE_QUALITY_AND_ARCHITECTURE.md` — skip here. This prompt only checks whether **the docs that describe the code** still match.
- CI/CD and deployment correctness: covered in `03_INFRASTRUCTURE_AND_OPERATIONS.md` — skip here. This prompt checks whether **runbooks** still describe the live infrastructure.
- Firestore rules correctness: covered in `02_SECURITY_AND_COMPLIANCE.md` — skip here. This prompt checks whether `docs/security/*` still describes them.
- Performance hot paths: covered in `04_PERFORMANCE_AND_SCALABILITY.md` — skip here. This prompt checks whether `docs/performance/FIREBASE_PERFORMANCE_GUIDE.md` still matches the query patterns in code.
- Legal-document drift: covered in `11_LEGAL_REVIEW.md` — skip here. This prompt covers everything **except** `assets/legal/*`.
- This prompt owns: `CLAUDE.md`, `.claude/rules/*.md`, `.claude/agents/*.knowledge.md`, `.claude/skills/*.md`, `docs/architecture/`, `docs/ops/`, `docs/parser/`, `docs/performance/`, `docs/security/` (as documentation, not as policy), `docs/design/`, `docs/store-submission/`, `docs/tagging/`, plus inline doc comments and READMEs anywhere in the repo.

---

## Two-Phase Approach

### Phase 1: Investigation & Documentation (THIS PHASE)

**CRITICAL**: Document every drift finding, change nothing.
- Cross-reference every factual claim in documentation against current code
- Document findings with `doc_path:line` ↔ `code_path:line` pairs
- Classify drift by severity (Critical / High / Medium / Low)
- Provide effort estimates per fix
- **ZERO documentation edits made**
- **ZERO code changes made**
- Output: complete drift report ready for Phase 2 remediation

### Phase 2: Remediation Plan (AFTER Phase 1 Complete)

- Group fixes by document (one batch edit per file is cheaper than scattered edits)
- Separate "doc edits only" (cheap, fast) from "doc + code reconciliation needed" (slower)
- Prioritize: docs that gate AI/agent decisions (CLAUDE.md, .claude/rules) > onboarding docs > runbooks > inline comments
- Sequence to minimize re-reading the same file twice

**DO NOT START PHASE 2 UNTIL PHASE 1 IS COMPLETE**

---

## Shared Project Context

```
Project:             Butlery (Swedish recipe and meal planning app)
Firebase project:    butlery-app-1
Framework:           Flutter / Dart (SDK >=3.24.0)
Architecture:        MVVM + Repository
                     Views -> ViewModels -> Services -> Repositories -> Firebase
DI system:           ServiceLocator.get<T>(), modular DI modules

Documentation surface area:
  - CLAUDE.md                              (root project instructions for AI)
  - .claude/rules/*.md                     (5 rule files: code-style, git-workflow, html-previews, ui-conventions, workflow-discipline)
  - .claude/agents/*.knowledge.md          (7 knowledge files, ~3220 total lines)
  - .claude/skills/*.md                    (17 skill files)
  - .claude/plan-review-checklist.md       (plan review gate criteria)
  - docs/architecture/*.md                 (ACCEPTED_LARGE_FILES, FIREBASE_STORAGE_REPOSITORY_EXCLUSION)
  - docs/ops/*.md                          (15 runbooks: kill switches, privacy manifests, freerasp, moderation, storage lifecycle, presence TTL, age rating, data residency, app review demo, GCP alerting, deep links, Mac setup, backups, Play data safety, third-party privacy)
  - docs/security/*.md                     (SECRETS_MANAGEMENT, FIRESTORE_FIELD_PROTECTION, audit-logs-retention)
  - docs/parser/PARSER_ARCHITECTURE.md
  - docs/performance/FIREBASE_PERFORMANCE_GUIDE.md
  - docs/design/*.md                       (BUTLERY_VIEWS_AND_STATES, butler-voice-guide, butlery-mockup-reference)
  - docs/store-submission/*.md             (STORE_SUBMISSION_CHECKLIST, play-data-safety/)
  - docs/tagging/tagging_system.md
  - docs/analysis/prompts/*.md             (this orchestrator + 12 prompts — meta)
  - README.md if present
  - Inline doc comments throughout lib/ and functions/

Generated file exclusions (skip during analysis):
  - *.g.dart
  - *.freezed.dart
  - app_localizations*.dart
  - .dart_tool/, build/, .firebase/
```

---

## Pre-Analysis Commands

Run these before starting. Attach output as context.

```bash
# 1. Inventory: docs by date (newest = most likely accurate, oldest = most likely drifted)
find docs .claude CLAUDE.md README.md -name "*.md" -type f -printf '%T+  %p\n' 2>/dev/null | sort

# 2. Quantitative drift signals — if CLAUDE.md says "X files >500 lines", count them
find lib -name "*.dart" ! -name "*.g.dart" ! -name "*.freezed.dart" ! -name "app_localizations*.dart" -exec wc -l {} + | awk '$1 > 500' | wc -l

# 3. Test coverage claim verification
flutter test --coverage 2>/dev/null | tail -5    # Compare to claims like "ViewModels 100%"

# 4. Service locator verification — does every service named in docs still exist?
grep -roh "ServiceLocator.get<[A-Za-z]*>" lib | sort -u

# 5. Firestore rules size claim verification
wc -l firestore.rules storage.rules

# 6. Cloud Functions region verification (CLAUDE.md / runbooks claim europe-west1)
grep -rh "region(" functions/src --include="*.ts" | sort -u

# 7. Markdown link integrity
find docs .claude -name "*.md" -exec grep -EHn '\]\((\.\.?/|[a-z])' {} \; > /tmp/doc-links.txt

# 8. Knowledge file ages — append-only, but if mtime is months old vs heavy code change in matching area, that's drift
ls -la .claude/agents/*.knowledge.md
```

If a tool is unavailable, note its absence. The investigation works without optional tooling but quality drops.

---

## Investigation Framework: 8 Dimensions (100 Points Total)

### Dimension 1: CLAUDE.md & .claude/rules vs Reality (20 points)

**Investigation Scope:** The root `CLAUDE.md` and `.claude/rules/*.md` files are the canonical AI-assistant instructions. Every false claim here causes downstream wrong fixes.

**Specific Investigation Tasks:**

1. **Numerical claims**
   - `CLAUDE.md` mentions "33 files intentionally >500 lines" — verify exact count via the find command above
   - `CLAUDE.md` references `docs/architecture/ACCEPTED_LARGE_FILES.md` — confirm file exists and the listed files all still exist and are still >500 lines
   - `.claude/rules/code-style.md` says "500 lines max" — verify whether new files violate this and have justification
   - Files: `CLAUDE.md`, `.claude/rules/code-style.md`, `docs/architecture/ACCEPTED_LARGE_FILES.md`

2. **Convention claims vs code**
   - `CLAUDE.md` "Critical Conventions" section names `userService.currentUserProfile` and `permissionService.currentUserId` — verify both APIs still exist and have the documented contract
   - `.claude/rules/code-style.md` says "withValues(alpha:) not withOpacity()" — grep for `withOpacity(` violations in recent code
   - `.claude/rules/code-style.md` says "ServiceLocator.get<T>() / never FirebaseFirestore.instance directly" — grep for direct instance use outside repository files
   - Files: as referenced above

3. **Process / hook claims**
   - `CLAUDE.md` "Tier 2 — Commit Enforced" lists 4 specialist agents and marker files — verify `.claude/hooks/require-review-before-commit.sh` actually enforces them
   - `CLAUDE.md` says hook is "session-aware: only blocks on errors in files THIS session modified" — verify hook script logic
   - `.claude/rules/git-workflow.md` lefthook section claims pre-commit hooks reformat — verify lefthook config
   - Files: `CLAUDE.md`, `.claude/hooks/`, `lefthook.yml` (if present)

4. **Skill / command references**
   - Every `.claude/skills/*.md` referenced by name in CLAUDE.md or rules must exist
   - Every `.claude/commands/*.md` referenced must exist
   - Cross-check: `data-source-enforcer`, `mixin-advisor`, `butlery-architecture` skills referenced in CLAUDE.md
   - Files: `CLAUDE.md`, `.claude/skills/`, `.claude/commands/`

**Output:** Drift table with `doc_file:line` claim, `code_evidence` of contradiction, severity, fix effort.

---

### Dimension 2: Agent Knowledge Files vs Current Code (15 points)

**Investigation Scope:** `.claude/agents/*.knowledge.md` files are append-only accumulated wisdom. They can become stale when underlying code is refactored without updating the knowledge note.

**Specific Investigation Tasks:**

1. **firebase-backend-security.knowledge.md (~1700 lines)**
   - For each documented Firestore rule pattern: does the rule still exist in `firestore.rules`?
   - For each documented PermissionValidationMixin pattern: do the named repositories still use it?
   - For each "fixed bug" entry: is the fix still in place?

2. **cloud-functions-specialist.knowledge.md (~610 lines)**
   - Region claims (europe-west1) match current `functions/src/**` configuration?
   - Idempotency patterns documented vs actually implemented in named functions?
   - Retry semantics claims vs current Cloud Functions v2 config?

3. **firestore-rules-tester.knowledge.md, performance-optimizer.knowledge.md, testing-specialist.knowledge.md, uiux-designer.knowledge.md, e2e-test-specialist.knowledge.md**
   - Same exercise: each documented pattern → does the code still match?

4. **Append-only contract violations**
   - Has any knowledge file been edited (deletions/rewrites) instead of appended? Check `git log --follow` per file
   - If a newer entry contradicts an older one, is the old entry clearly marked superseded?

**Output:** Per knowledge file, list every claim that no longer matches code with evidence. Flag any file with mtime >90 days where the relevant code area has changed in the same period.

---

### Dimension 3: Operational Runbooks vs Live Systems (15 points)

**Investigation Scope:** `docs/ops/*-runbook.md` files describe how to operate live systems. Drift here causes incident-response errors.

**Specific Investigation Tasks:**

1. **llm-kill-switch-runbook.md**
   - Does the named Remote Config flag still exist in code (`lib/services/feature_flags/`)?
   - Does the Cloud Function the runbook describes still exist with the same name?
   - Are the steps still executable as written?

2. **freerasp-runbook.md**
   - FreeRASP service still in pubspec.yaml at the documented version?
   - Configuration steps still match `lib/services/security/` (or wherever it lives)?

3. **moderation-runbook.md**
   - Moderator queue paths in Firestore match current rules?
   - Admin view/viewmodel paths still valid (`lib/views/admin/moderator_review_view.dart`, `lib/viewmodels/admin/moderator_review_viewmodel.dart`)?

4. **ios-privacy-manifest-audit.md, ios-third-party-privacy-manifests.md**
   - Listed third-party SDKs match current pubspec dependencies?
   - PrivacyInfo.xcprivacy entries match the runbook's expected entries?

5. **storage-lifecycle-runbook.md**
   - GCS lifecycle rules described match what's actually applied (cross-check with `firebase.json` / Storage rules / live config notes)
   - Documented retention periods match cleanup function defaults

6. **presence-ttl-runbook.md**
   - TTL value documented matches `functions/src/cleanup/` and `lib/services/presence/`

7. **gcp-alerting-runbook.md, deep-link-setup.md, age-rating-runbook.md, data-residency.md, app-review-demo.md, play-data-safety-runbook.md, backups.md, setup-mac.md**
   - For each: pick one factual claim and verify it against code/config

**Output:** Per runbook, mark Verified / Drifted / Unverifiable with evidence and severity.

---

### Dimension 4: Architecture & Performance Docs vs Code (12 points)

**Investigation Scope:** `docs/architecture/`, `docs/performance/`, `docs/parser/`, `docs/tagging/` describe how subsystems work.

**Specific Investigation Tasks:**

1. **docs/architecture/ACCEPTED_LARGE_FILES.md**
   - Every file in the list still exists at the listed path?
   - Every file's actual line count still >500 (and if so, still in the rationale's range)?
   - Files that have since shrunk below 500 lines should be removed from the list

2. **docs/architecture/FIREBASE_STORAGE_REPOSITORY_EXCLUSION.md**
   - Excluded paths/patterns still excluded in current code?
   - Rationale still applies?

3. **docs/performance/FIREBASE_PERFORMANCE_GUIDE.md**
   - Documented query patterns match `lib/repositories/firebase/`
   - Documented index strategy matches `firestore.indexes.json` (and the orchestrator says "34 composite indexes" — verify)
   - Cache TTLs documented match code

4. **docs/parser/PARSER_ARCHITECTURE.md**
   - Pipeline stages described match `lib/services/parsing/` (or wherever the parser lives)
   - LLM/regex/site-config tier order matches code
   - Swedish NLP components named exist

5. **docs/tagging/tagging_system.md**
   - 5-phase pipeline claim verified in code
   - Named tagger classes exist

**Output:** Per architecture doc, drift table with code-evidence pairs.

---

### Dimension 5: Security Docs vs Current Rules/Services (10 points)

**Investigation Scope:** `docs/security/*.md` documents claims about security posture. These are read by both engineers and AI assistants.

**Specific Investigation Tasks:**

1. **docs/security/SECRETS_MANAGEMENT.md**
   - Documented secret-handling locations match `firebase.json`, GitHub Actions secrets, Secret Manager
   - Rotation procedures still actionable

2. **docs/security/FIRESTORE_FIELD_PROTECTION.md**
   - Listed protected fields still protected by current `firestore.rules`?
   - Per-field validation patterns still in rules?

3. **docs/security/audit-logs-retention.md**
   - Retention period claim matches `functions/src/cleanup/cleanup-audit-logs.ts` and `lib/services/account/account_deletion_service.dart`
   - **Known orchestrator note:** there's a documented 90/180-day mismatch — verify which doc is wrong

**Output:** Per security doc, claim-vs-evidence table with severity (security drift = automatic HIGH minimum).

---

### Dimension 6: Design & Store Submission Docs (8 points)

**Investigation Scope:** `docs/design/`, `docs/store-submission/` — read at release time.

**Specific Investigation Tasks:**

1. **docs/design/BUTLERY_VIEWS_AND_STATES.md**
   - Listed views still exist under `lib/views/`?
   - Documented state flows match current ViewModels?

2. **docs/design/butler-voice-guide.md, butlery-mockup-reference.md**
   - Brand voice rules referenced in current copy (Swedish UI strings)?
   - Mockup reference paths still valid?

3. **docs/store-submission/STORE_SUBMISSION_CHECKLIST.md**
   - Every checklist item still actionable / still matches current submission requirements (2026)?
   - References to other docs (privacy manifest, age rating) still valid?

4. **docs/store-submission/play-data-safety/**
   - Data-safety declarations match what the code actually collects?
   - Defer the legal-accuracy portion to prompt 11 — here only check for stale references, broken links, removed SDKs still listed

**Output:** Drift table; release-blocker items elevated to HIGH severity.

---

### Dimension 7: Inline Comments, READMEs, & Cross-Doc Links (10 points)

**Investigation Scope:** Doc-comments inside code files, top-of-file headers, and link integrity across all docs.

**Specific Investigation Tasks:**

1. **Inline doc comments in lib/**
   - Sample 30 files; flag class/method doc comments that contradict the implementation
   - Look especially for "TODO/FIXME/HACK/XXX" markers older than 90 days — they're often stale notes

2. **Inline doc comments in functions/src/**
   - Same exercise; Cloud Functions tend to drift fast because of region/runtime updates

3. **Cross-document links**
   - From `/tmp/doc-links.txt` (pre-analysis output): every relative `[text](./path)` link resolves?
   - Any document link points to a moved/renamed file?

4. **README files**
   - If repo root has `README.md`: setup steps still work? Versions claimed still current?
   - Per-directory READMEs (some `docs/*` subdirs have one): still describe current contents?

5. **CHANGELOG / release notes**
   - If present: latest entry roughly matches recent commits?

**Output:** List of stale comments / broken links with paths and recommended action.

---

### Dimension 8: Quantitative & Process Claims (10 points)

**Investigation Scope:** Specific numbers and process descriptions used as ground truth elsewhere.

**Specific Investigation Tasks:**

1. **Test coverage claims**
   - Orchestrator + various docs claim "ViewModels 100%, Services 96%, Firebase Repos 88%"
   - Run actual coverage; flag gap

2. **CI/CD workflow claims**
   - Orchestrator claims "5 GitHub Actions workflows: analyze, test, build-validation, architecture-validation, e2e_tests"
   - List `.github/workflows/*.yml` and verify exact set + names

3. **Codebase size claims**
   - Orchestrator claims "~850+ .dart files, ~150k+ lines hand-written" — verify current numbers
   - Each prompt's "Shared Project Context" repeats this — they all need to update if reality has moved

4. **Firestore rules / index claims**
   - Orchestrator claims "1465 lines, 74 match rules, 34 composite indexes" — verify against `firestore.rules` and `firestore.indexes.json`

5. **GDPR phase claim**
   - "Phase 1 complete (Articles 7, 15, 17, 30)" — verify each Article's implementation is referenced by a corresponding service/repository

6. **Deployment region claims**
   - "europe-west1 (Belgium — NOT Stockholm despite code comments)" — verify code comments still erroneously say Stockholm OR have been corrected

7. **Process drift**
   - `CLAUDE.md` mentions skills/agents that exist — does any skill reference an obsolete pattern?
   - `.claude/plan-review-checklist.md` items still applicable?

**Output:** Numerical drift table — old number, current number, doc(s) to update.

---

## Investigation Process

### Stage 1: Mechanical Inventory (1 hour)

Run pre-analysis commands. Build a master list of every documentation file with mtime + size + first-line topic.

### Stage 2: Doc-by-Doc Cross-Reference (4 hours)

Walk Dimensions 1 → 8 in order. For each dimension, work through the named files and run the named verifications. Record every drift in a structured table.

### Stage 3: Consolidation (1 hour)

Merge findings into the output format. Sort by severity. Cross-link drifts that share a root cause (e.g. "Region drift appears in CLAUDE.md, runbook X, and knowledge file Y — single root cause").

**Total estimated: 6 hours**

---

## Output Format

### Executive Summary

```
BUTLERY DOCUMENTATION & OPERATIONAL DRIFT ANALYSIS - PHASE 1
=============================================================
Analysis Date: [Date]
Analyst: [Claude Opus 4.7 | OpenAI Codex]
Documentation files in scope: [N]
Files with drift detected: [M]

OVERALL DOC HEALTH SCORE: X/100
|-- CLAUDE.md & .claude/rules:                X/20
|-- Agent knowledge files:                    X/15
|-- Operational runbooks:                     X/15
|-- Architecture & performance docs:          X/12
|-- Security docs:                            X/10
|-- Design & store submission docs:           X/8
|-- Inline comments / READMEs / links:        X/10
|-- Quantitative & process claims:            X/10

DRIFT STATUS: [In sync | Minor drift | Significant drift | Severely outdated]

CRITICAL DRIFTS:  X (false statements that mislead AI/eng decisions today)
HIGH DRIFTS:      X (operational runbooks, security docs that are wrong)
MEDIUM DRIFTS:    X (architecture/design docs partially wrong)
LOW DRIFTS:       X (stale numbers, broken links, old comments)
```

### Drift Detail Table

```markdown
| # | Doc file:line | Claim | Code evidence | Severity | Fix effort |
|---|---------------|-------|---------------|----------|------------|
| 1 | CLAUDE.md:42  | "33 files >500 lines" | Actually 41 (find command output) | LOW | 5 min |
| 2 | docs/ops/llm-kill-switch-runbook.md:18 | "Set flag llm_kill_switch_v1" | Flag renamed to llm_emergency_disable in lib/services/feature_flags/feature_flag_service.dart:127 | HIGH | 15 min |
...
```

### Cross-Document Root-Cause Cluster

Group drifts that share a single underlying change (e.g. a rename, a moved file, a region change). Fixing the root once and propagating saves time vs whack-a-mole.

```markdown
## Cluster A: Region naming
- CLAUDE.md:17 says "europe-west1 (Stockholm)" — Belgium per orchestrator
- functions/src/index.ts:8 comment "Stockholm region" — same error
- docs/ops/data-residency.md:11 "Stockholm europe-west1" — same error
Root cause: original region note assumed Stockholm at project setup
Single fix: update all three with one search-replace
```

### Issues by Severity (Phase 2 Input)

```markdown
## CRITICAL (fix immediately — actively misleads AI/engineering decisions)
- [List with doc_path:line and code evidence]

## HIGH (fix within current sprint — operational/security docs wrong)
- [List]

## MEDIUM (scheduled — architecture/design docs partially wrong)
- [List]

## LOW (backlog — stale numbers, broken links, comment rot)
- [List]

Total drifts: X
Estimated total remediation effort: X hours
```

---

## Phase 1 Deliverables Checklist

- [ ] Executive summary with overall score (X/100)
- [ ] Per-dimension findings (8 dimensions)
- [ ] Drift detail table with `doc_file:line` ↔ `code_evidence` pairs
- [ ] Cross-document root-cause clusters identified
- [ ] Inline comment / link / README findings sampled (not exhaustive)
- [ ] Quantitative claims verified with current numbers
- [ ] Issues classified by severity with counts
- [ ] ZERO documentation edits made
- [ ] ZERO code changes made

---

## Scoring Guide

| Score Range | Rating       | Interpretation                                      |
|-------------|--------------|-----------------------------------------------------|
| 90-100      | Excellent    | Docs match reality; minor polish only               |
| 75-89       | Good         | Few drifts; targeted updates needed                 |
| 60-74       | Acceptable   | Noticeable drift; sprint-scale doc cleanup          |
| 40-59       | Needs work   | Docs actively misleading; block AI work until fixed |
| 0-39        | Critical     | Docs unreliable; treat as untrusted source          |

### Per-Dimension Scoring Guidance

**CLAUDE.md & .claude/rules (20 pts):** Start at 20. Deduct: -5 per false claim that would cause an AI assistant to make a wrong fix today, -2 per outdated reference, -1 per broken cross-reference. Floor at 0.

**Agent knowledge files (15 pts):** Start at 15. Deduct: -3 per documented pattern that no longer exists in code, -2 per superseded-but-not-marked-superseded entry, -1 per knowledge file with mtime >90 days while related code area changed. Floor at 0.

**Operational runbooks (15 pts):** Start at 15. Deduct: -4 per runbook with broken procedure (steps no longer executable), -2 per renamed/moved-but-still-referenced artifact, -1 per stale version/SDK reference. Floor at 0.

**Architecture & performance docs (12 pts):** Start at 12. Deduct: -3 per misdescribed subsystem, -2 per file in ACCEPTED_LARGE_FILES that has shrunk or moved, -1 per stale code reference. Floor at 0.

**Security docs (10 pts):** Start at 10. Deduct: -4 per wrong security claim (security drift is high-impact), -2 per stale procedure, -1 per stale reference. Floor at 0.

**Design & store submission docs (8 pts):** Start at 8. Deduct: -3 per release-blocker item that no longer matches reality, -1 per stale checklist item or moved file reference. Floor at 0.

**Inline comments / READMEs / links (10 pts):** Start at 10. Deduct: -1 per broken cross-doc link, -0.5 per stale doc comment in sampled files, -2 per stale README setup section. Floor at 0.

**Quantitative & process claims (10 pts):** Start at 10. Deduct: -2 per quantitative claim off by >20%, -1 per process step that no longer matches reality. Floor at 0.

---

## Begin Phase 1 Investigation

Execute the documentation-and-operational-drift investigation across all 8 dimensions. Start with mechanical inventory, then walk dimensions in order. Compile findings into the output format above.

**Rules:**
- NO documentation edits. NO code changes. Investigation and documentation only.
- Every drift finding requires both a `doc_file:line` and a `code_path:line` (or `config_path:line`) reference.
- Cluster related drifts by root cause; flag whether one fix resolves multiple drifts.
- Treat security and runbook drift as automatic HIGH severity minimum.
- Do not duplicate analysis owned by other prompts — defer per cross-prompt boundaries above.
- For Codex runs: use the relevant `.claude/agents/*.knowledge.md` content as injected by `docs/analysis/CODEX_RUN_GUIDE.md`.
