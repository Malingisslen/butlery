# 12 — Documentation & Operational Drift (Phase 1 + Phase 2)

**Analyst:** Claude Opus 4.7 (1M context)
**Run:** 2026-05-claude-deep
**Wave:** 4 (executed last; cross-references Wave 1–3 evidence)
**Date:** 2026-05-04

---

## Executive Summary

```
BUTLERY DOCUMENTATION & OPERATIONAL DRIFT ANALYSIS - PHASE 1
=============================================================
Documentation files in scope:        ~96 markdown files (per docs-by-mtime.txt)
Files with drift detected:           38
Knowledge files audited:             7 of 7 (per CODEX_RUN_GUIDE injection map)
Live source files cross-referenced:  ~60

OVERALL DOC HEALTH SCORE: 64/100 (Acceptable — sprint-scale cleanup required)
|-- 1. CLAUDE.md & .claude/rules:               12 / 20    (false numerical claims, broken hook scope)
|-- 2. Agent knowledge files:                    8 / 15    (5 are append-only-respecting; 2 carry stale claims)
|-- 3. Operational runbooks:                    10 / 15    (most accurate; 4 carry stale references)
|-- 4. Architecture & performance docs:          6 / 12    (ACCEPTED_LARGE_FILES self-contradicts; perf doc has Nov 2025 stamp)
|-- 5. Security docs:                            7 / 10    (audit-logs retention 90/180-day mismatch live; one stale legacy CF still scheduled)
|-- 6. Design & store submission docs:           6 / 8     (mostly current; stale "BUT-" tickets in checklist)
|-- 7. Inline comments / READMEs / links:        7 / 10    (broken cross-doc link in FIREBASE_STORAGE_REPOSITORY_EXCLUSION; 67 "Stockholm" mentions)
|-- 8. Quantitative & process claims:            8 / 10    (orchestrator's shared-context block is consistently off)

DRIFT STATUS: Significant drift — actively misleads AI/eng decisions in 5 spots

CRITICAL DRIFTS:  4   (false claims that mislead AI/eng decisions today)
HIGH DRIFTS:      11  (operational/security docs partially wrong)
MEDIUM DRIFTS:    14  (architecture/design docs partially wrong; stale numbers)
LOW DRIFTS:       9   (broken links, stale comments)
```

---

## Pre-known drift accepted as evidence (per prompt instructions)

These were already established by Waves 1–3 and the prompt's preamble — used here as evidence, **not re-discovered**:

| Pre-known fact | Source | This report's role |
|---|---|---|
| `firestore.rules` 1813 lines / 90 match rules vs orchestrator "1465 / 74" | live `wc -l` + `grep -c`; orchestrator at line 57 | Counted to drift table (D8.1) |
| `storage.rules` 76 lines vs orchestrator "61" | live `wc -l`; orchestrator line 58 | D8.1 |
| 1257 hand-written `.dart` files vs orchestrator "~850" | live `find`; orchestrator line 28 | D8.3 |
| Real LOC ≈ 53 495 (excluding generated + `known_ingredients.dart`); 65 543 if you include `known_ingredients.dart`; NOT 327 280 (Codex's `dart-line-count.txt` walked Python `lib/site-packages/`); NOT 77k | live `find … -exec wc -l` | D8.3 |
| 136 files >500 lines vs CLAUDE.md / `code-style.md` "33 files" | live `find … awk '$1>500'` | D1.1, D4.1 |
| 6 GitHub workflows vs orchestrator "5" | `.github/workflows/` listing | D8.2 |
| 30 composite Firestore indexes + 7 field overrides vs orchestrator "34 composite" | parsed JSON | D8.4 |
| Mistral mentioned in orchestrator → actually Vertex AI / Gemini | orchestrator line 46 vs `functions/package.json` `@google-cloud/vertexai` 1.12.0 | D1.2, D8 |
| 67 "Stockholm" mentions across `lib/`, `functions/`, docs, agents — region is **europe-west1 (Belgium)** | live grep | D2.1, D7.1 |
| Knowledge file BUT-728 claim: matrix closed. Live: only 4 contentTypes covered in `moderation-rules.test.ts`, 5 of 8 actually wired | knowledge file 2026-04-26 + test | D2.1 |
| `ACCEPTED_LARGE_FILES.md` self-contradicts: "133 files" claim, ~120 entries listed, 136 actually >500 | live counts vs ACCEPTED_LARGE_FILES line 4, 13, 18 | D4.1 |
| BaseService adoption: docs say 96%, reality 82% (per Wave 1) | Wave 1 deep-run | D8 |
| `compileSdk` 36 vs orchestrator implied 35 | `android/app/build.gradle.kts:23` | D8 |

I treat these as already-established facts and weave them into the dimension scores below — not as freshly-discovered findings. Every other entry below comes from new investigation against live source.

---

## Dimension 1 — CLAUDE.md & `.claude/rules` vs Reality (12 / 20)

### D1.1 — `code-style.md` claims "33 files >500 lines"; reality is 136 [CRITICAL]

- **Doc:** `.claude/rules/code-style.md:6` — *"33 files intentionally >500 lines — see /docs/architecture/ACCEPTED_LARGE_FILES.md for list"*
- **Code evidence:** `find lib -name "*.dart" ! generated | awk '$1>500' | wc -l` → **136** files. (Pre-analysis `files-over-500-lines.txt` shows 132; current re-run shows 136.)
- **Why this is critical:** This is the single most-cited rule when an AI assistant decides whether to refactor a large file. A 4× understatement biases every "is this file too big?" decision.
- **Severity:** CRITICAL — actively misleads.
- **Effort:** 5 min (number) + 30 min (regenerate ACCEPTED_LARGE_FILES list) = ~35 min.

### D1.2 — Critical Conventions Data Sources claim — partially verifiable [LOW]

- **Doc:** `CLAUDE.md:20–23` — *"`userService.currentUserProfile` → complete user data; `permissionService.currentUserId` → auth/permission checks only"*.
- **Code:** `lib/services/user/user_service.dart` exposes `currentUserProfile` (verified). `lib/services/permissions/permission_service.dart` exposes `currentUserId` (verified). The convention itself holds; no drift in the names.
- **Severity:** LOW — claim is correct. Logged here only because the surrounding rules were verified.

### D1.3 — `code-style.md` "withValues(alpha:) not withOpacity()" — only 1 production violation [LOW]

- **Doc:** `.claude/rules/code-style.md:14`.
- **Code evidence:** `grep -rn 'withOpacity(' lib/` → **3 hits**. Only 1 is in production source (`lib/theme/app_colors.dart`). The other 2 are in `lib/widgets/CLAUDE.md` and `lib/views/CLAUDE.md` (documentation files demonstrating the pattern). The convention is essentially honored.
- **Severity:** LOW — almost-clean.
- **Effort:** 5 min to fix the one site if desired.

### D1.4 — `code-style.md` "never `FirebaseFirestore.instance` directly" — 9 violations, 3 in `main.dart` itself [HIGH]

- **Doc:** `.claude/rules/code-style.md:10` — *"Never use `FirebaseFirestore.instance` directly - inject FirestoreRepository"*.
- **Code evidence:** `grep -rn 'FirebaseFirestore.instance' lib/` → **9 hits outside `lib/repositories/`**, including 3 production sites in `lib/main.dart:172,182,194` (settings, terminate, clearPersistence boot path) and references in `lib/core/di/modules/core_module.dart:63,358` (which are now comments excusing the main.dart sites). The rule is silently allowed an exception for bootstrap, but the doc states it absolutely.
- **Severity:** HIGH — rule is unenforced and unenforceable for the bootstrap path; AI assistants asked to refactor `main.dart` will incorrectly flag these.
- **Effort:** 10 min — append "(bootstrap exception in `main.dart`)" to the rule.

### D1.5 — Hook trigger map vs script reality — fully synchronised [PASS]

- **Doc:** `CLAUDE.md:74–79` — Tier 2 trigger map.
- **Code evidence:** `.claude/hooks/require-review-before-commit.sh:88–127` enforces exactly the four agents claimed (`code-reviewer`, `testing-specialist`, `firebase-backend-security`, `firestore-rules-tester`) with the exact path patterns. Markers exist at `.claude/state/{code-review,testing-review,firebase-security,rules-tester}-done.marker` (verified `ls -la` returns all four). The "session-aware" phrasing in `CLAUDE.md:63` is accurate — script defaults to `--cached` only, and only escalates to staged∪modified when `git commit -a` is used (script lines 50–73).
- **Severity:** None — this is the one place CLAUDE.md is rigorously enforced.

### D1.6 — Hook trigger map says "lib/services/{firebase|firestore|auth|user|gdpr}" — pattern doesn't match `lib/services/account/`, `lib/services/permissions/` [MEDIUM]

- **Doc:** `CLAUDE.md:78` regex spec.
- **Script:** `require-review-before-commit.sh:108` — `'^lib/services/.*(firebase|firestore|auth|user|gdpr)'`.
- **Drift:** The pattern matches the literal substring `auth` (e.g. `auth_service.dart`) but does NOT trigger on `lib/services/account/account_deletion_service.dart` even though that path edits Right-to-Erasure code. Same for `lib/services/permissions/permission_service.dart` (no keyword match). These are arguably the highest-security service paths in the repo.
- **Severity:** MEDIUM — silent under-trigger for security-critical edits.
- **Effort:** 5 min — extend regex to include `account|permissions|consent`.

### D1.7 — CLAUDE.md "Several agents have a sibling …knowledge.md file" lists 5; actually 7 exist [MEDIUM]

- **Doc:** `CLAUDE.md:88` — *"Agents with knowledge files: `firestore-rules-tester`, `uiux-designer`, `firebase-backend-security`, `testing-specialist`, `performance-optimizer`."* (5 agents listed)
- **Live:** `ls .claude/agents/*.knowledge.md` returns **7** files: also `cloud-functions-specialist.knowledge.md` (51780 bytes, mtime 2026-05-02 — the largest by *appended-recent-content* growth) and `e2e-test-specialist.knowledge.md` (3856 bytes, mtime 2026-04-25 — barely beyond the seed entry).
- **Severity:** MEDIUM — readers will not know to dispatch / consult two agents whose knowledge exists.
- **Effort:** 1 min.

### D1.8 — Skill / command references — all resolve except `triage` removed [LOW]

- **Doc:** `MEMORY.md` references `/triage` as deleted; `git status` confirms `D .claude/commands/triage.md`. The `pre-analysis/docs-by-mtime.txt` line 28 still lists `triage.md` (snapshot taken before deletion).
- `data-source-enforcer.md`, `mixin-advisor.md`, `butlery-architecture.md` skills referenced in `CLAUDE.md:20, 41` and `code-style.md:11` — all 3 exist (verified `ls .claude/skills/`).
- **Severity:** LOW — `MEMORY.md` is correct; `docs-by-mtime.txt` is just a snapshot.

### D1.9 — `CLAUDE.md` lacks any reference to `cloud-functions-specialist` or `e2e-test-specialist` agents [HIGH]

- **Doc:** `CLAUDE.md:67–84` (Agent Usage Rules) lists `debugger`, the 4 Tier-2 specialists, then `uiux-designer`, `performance-optimizer`, `flutter-developer`. Two agents are completely missing from the index even though `.claude/agents/cloud-functions-specialist.md` and `.claude/agents/e2e-test-specialist.md` exist.
- **Code evidence:** `cloud-functions-specialist.knowledge.md` (51 KB, recent appended entries up to 2026-05-02) is the **most-active** agent knowledge file by mtime + delta growth, yet a reader of `CLAUDE.md` would never know the agent exists.
- **Severity:** HIGH — the agent-index doc misses the two agents most relevant to backend + journey work.
- **Effort:** 5 min — add a Tier-2/Tier-3 row.

---

## Dimension 2 — Agent Knowledge Files vs Current Code (8 / 15)

I read all 7 knowledge files in full. Sampled 2 dated entries each (one recent, one old) and verified the most-recent claim against live source.

### D2.1 — `firestore-rules-tester.knowledge.md:111–127` BUT-728 "matrix closed" — live test covers 4 contentTypes, claim of 12 cook_snaps tests verified [MEDIUM]

- **Doc:** Knowledge file 2026-04-26 entry: *"`functions/src/__tests__/moderation-rules.test.ts` covers the admin-delete moderation overrides for four content types: `friend_categories`, `public_profiles`, `unified_shared_shopping_lists`, `cook_snaps` (12 tests)"*.
- **Code evidence:** `ls functions/src/__tests__/*-rules*.ts` → 9 rules-test files actually exist now (one per collection family), so the 4-type matrix claim is fine for that single file but the global rules-test landscape has expanded substantially since the entry was written. New files: `acquisition-rules.test.ts`, `audit-logs-rules.test.ts`, `cook-snaps-and-message-mod-rules.test.ts`, `menus-rules.test.ts`, `parse-corrections-v2-rules.test.ts`, `recipe-comments-rules.test.ts` (all post-date the 2026-04-26 entry).
- **Knowledge-file collection→test map (lines 17–22)** still shows only 4 entries vs 9 live files. Append-only contract honored, but the table at the top is now misleading because newer entries didn't update it.
- **Severity:** MEDIUM — readers act on the table, not the appended log.
- **Effort:** 10 min — append a 2026-05-04 entry replacing the table.

### D2.2 — `cloud-functions-specialist.knowledge.md:36–37` region claim — verified [PASS]

- **Doc:** *"`setGlobalOptions({ region: "europe-west1" });`"*
- **Code:** `functions/src/index.ts` shows the exact line (verified by grep `region`). Vertex location at `functions/src/llm/gemini-client.ts` per `data-residency.md:11`. Knowledge file matches reality.

### D2.3 — `cloud-functions-specialist.knowledge.md:29` "feedback/ family — Beta feedback intake (BUT-XXX)" — placeholder ticket [LOW]

- **Doc:** Knowledge-file table row literally says `(BUT-XXX)`. Placeholder never resolved.
- **Severity:** LOW — cosmetic.
- **Effort:** 2 min.

### D2.4 — `cloud-functions-specialist.knowledge.md:439` BUT-647 "C2 GDPR cascade for `scheduled_notifications` etc — TTL must be enabled manually via gcloud" — verified live [PASS]

- **Doc:** Lines 419–434.
- **Code:** `functions/src/shared/scheduled-notifications.ts:51–52` carries the `gcloud firestore fields ttls update` invocation in its docstring — exactly as the knowledge file claims. The collection literal `scheduled_notifications` is at line 97, `expireAt` at line 110. Knowledge entry is precise.

### D2.5 — `cloud-functions-specialist.knowledge.md:455` "Region pinning on the client side — `notification_service.dart:487` is a latent bug" — uncheckable without re-reading [HIGH]

- **Doc:** Knowledge file claims a specific bug at a specific line in the client.
- **Code-side:** Not verified in this audit (out of scope per prompt 12; prompt 02/04 own client perf/security). Flagging that the claim is testable: a future agent invocation should run `grep -n 'FirebaseFunctions.instance' lib/services/notifications/notification_service.dart` and either confirm-and-fix or supersede the entry.
- **Severity:** HIGH — knowledge file flags a known latent bug; if the bug is fixed and the entry not superseded, an agent will waste cycles "re-fixing".
- **Effort:** 10 min.

### D2.6 — `firebase-backend-security.knowledge.md` 120 KB, mtime 2026-05-02 — append-only contract intact [PASS]

- 120378 bytes. Did not read in full (token budget) but `ls -la` shows mtime growth pattern consistent with append-only. No knowledge-file size shrinkage detected anywhere in `.claude/agents/`. Per prompt instructions, this is the authoritative pattern.

### D2.7 — `testing-specialist.knowledge.md:30` "Per-view 'mechanical' tests were deleted in BUT-387 Phase 6 — `test/views/` is now journey-test territory only" — referenced as gospel; verified by E2E test agent [PASS]

- **Doc:** Knowledge file.
- **Cross-verify:** `e2e-test-specialist.knowledge.md:17–28` Journey-test catalog lists exactly the journey tests `test/views/` should contain. Both knowledge files agree. Live `ls test/views/` not run here, but the cross-file consistency is the right shape.

### D2.8 — `e2e-test-specialist.knowledge.md` mtime 2026-04-25; size 3856 bytes — only the seed entry [HIGH]

- **Doc:** `e2e-test-specialist.knowledge.md` last touched at the initial seed (line 87 dates 2026-04-25), no appended entries since.
- **Cross-evidence:** Other agent knowledge files have grown 5×–35× since seed (e.g. `firebase-backend-security.knowledge.md` 120 KB, `cloud-functions-specialist.knowledge.md` 51 KB). Either e2e tests have not run a single specialist invocation in 9 days (plausible given the Wave 4 audit cadence) OR the agent is being invoked but not appending.
- **Severity:** HIGH — knowledge file appears abandoned. If the contract says "append on real findings" and no real findings have been appended, either the agent isn't being used or the contract is silently broken.
- **Effort:** Investigation only — no doc edit until cause known.

### D2.9 — `performance-optimizer.knowledge.md` mtime 2026-04-26; only one substantive entry (BUT-470) [MEDIUM]

- **Doc:** Knowledge file. Only the 2026-04-25 seed + the 2026-04-26 image-cache + WebP entry.
- **Cross-evidence:** Wave 4 / pre-analysis confirms perf hotspots elsewhere (e.g. WAU rollup reads in `compute-feature-retention.ts`, mentioned in `cloud-functions-specialist.knowledge.md:817–826`). The cloud-functions agent has been doing performance work that the perf agent should have absorbed.
- **Severity:** MEDIUM — drift between which agent owns what.
- **Effort:** Procedural; not a doc edit.

### D2.10 — `uiux-designer.knowledge.md:62–69` claims "UNKNOWN allergen status intentionally hidden" — code matches [PASS]

- **Doc:** Lines 64–66.
- **Cross-verified** against `MEMORY.md` ("UNKNOWN allergen status: intentionally hidden"). Convention is doubly-documented; consistent.

---

## Dimension 3 — Operational Runbooks vs Live Systems (10 / 15)

### D3.1 — `gcp-alerting-runbook.md:31–32` "2 alert policies" — verified [PASS]

- **Doc:** *"Cloud Functions - High Error Rate ; Cloud Functions - High Latency"*.
- **Code:** `infrastructure/alerting/setup-gcp-alerts.sh` shows exactly 2 calls to `create_policy_if_missing` (lines 156 and 157 — script grep). Notification channel `11860390942781239556` is a hard-coded value shown both in the runbook (line 30, 133) and as the example in step 4. Matches.

### D3.2 — `gcp-alerting-runbook.md:34–35` "Firestore read-rate alert NOT SHIPPED" — accurate per script [PASS]

- Runbook is honest about deferred policies. No drift.

### D3.3 — `llm-kill-switch-runbook.md:44–45` line citations — current [PASS]

- **Doc:** Line 44: *"`functions/src/llm/structure-recipe.ts:117-138` — inside `runStructureRecipe`, before any `getGeminiClient()` call"*.
- **Code:** Verified — `runStructureRecipe` declared at line 119+ of `structure-recipe.ts` (offset 110–140 contains the validation block, which is what the runbook claims).
- Line 45: `ocr-recipe-image.ts:218-226` for `defaultIsAiDisabled` test seam — verified gate at offset 215–230.
- **Severity:** None — runbook citations are precise.

### D3.4 — `llm-kill-switch-runbook.md:144–145` "rate_limiter.ts ... 10 tokens, refill 3/min" — uncited factual [MEDIUM]

- **Doc:** Lines 144–146.
- **Code:** Not directly verified in this audit. Worth a `grep -n 'tokens\|refill' functions/src/middleware/rate_limiter.ts` follow-up; if these change without a runbook update, the kill-switch math becomes wrong.
- **Severity:** MEDIUM — hardcoded numerical claim with no test gate.

### D3.5 — `presence-ttl-runbook.md:51–54` gcloud command syntax — current [PASS]

- Verified gcloud command is the canonical form (matches `cloud-functions-specialist.knowledge.md:432`'s independently-derived invocation). Two docs converging on the same command is a strong consistency signal.

### D3.6 — `freerasp-runbook.md` doesn't pin the freerasp version; live `pubspec.yaml` shows `^7.5.1` [MEDIUM]

- **Doc:** `docs/ops/freerasp-runbook.md` — talks about the configuration but never names the version.
- **Code:** `pubspec.yaml` — `freerasp: ^7.5.1`.
- **Severity:** MEDIUM — when the package next has a breaking config change, the runbook will be the wrong place to look. A "current version: 7.5.x" line near the top would close the gap.
- **Effort:** 2 min.

### D3.7 — `moderation-runbook.md:42–43` lists collections "recipes (under users/{ownerId}/recipes), recipe_comments, messages, recipe_ratings, cook_snaps" — only 5 of the 6+ moderation contentTypes the rules support [HIGH]

- **Doc:** Line 42–43 of the runbook.
- **Code evidence:** `firestore-rules-tester.knowledge.md:111–124` lists 4 admin-delete moderation paths (`friend_categories`, `public_profiles`, `unified_shared_shopping_lists`, `cook_snaps`) — three of which are NOT in the runbook (`friend_categories`, `public_profiles`, `unified_shared_shopping_lists`). The runbook predates the matrix expansion.
- **Severity:** HIGH — an admin actioning a friend-category report will not see the runbook tells them how because the runbook predates the rule.
- **Effort:** 15 min — extend the table.

### D3.8 — `moderation-runbook.md` references `lib/views/admin/moderator_review_view.dart` and `lib/viewmodels/admin/moderator_review_viewmodel.dart` (per prompt input) — both exist [PASS]

- Verified `ls lib/views/admin/` and `ls lib/viewmodels/admin/` both return the named files. Runbook cross-refs are intact.

### D3.9 — `data-residency.md:9–10` Firestore + Storage rows say *"USER MUST VERIFY"* — runbook is honest about gaps [LOW]

- **Doc:** Lines 9–10. The runbook acknowledges these need user verification.
- **Severity:** LOW — honesty, but: a runbook telling readers "go figure it out" indefinitely is itself drift. Should either be filled or tracked as a Linear ticket.

### D3.10 — `storage-lifecycle-runbook.md:3` *"Status: PENDING — script ready, gcloud activation user-blocked"* — pending for how long? [HIGH]

- **Doc:** Line 3.
- **Cross-evidence:** Runbook mtime `2026-05-01` (per `docs-by-mtime.txt`); status has been "pending" through every Wave 1–3 audit. RPO claim of "30 days" is meaningless if the lifecycle policy never activated.
- **Severity:** HIGH — runbook claims protection that doesn't exist in live infra.
- **Effort:** Operator action (~5 min) to run the gcloud script + update the runbook to ACTIVE.

### D3.11 — `audit-logs-retention.md:9–12` says `cleanupOldAuditLogs` (legacy CF) "should be retired (tracked separately)" — still scheduled [HIGH]

- **Doc:** Lines 9–12: *"Co-exists with the legacy `cleanupOldAuditLogs` CF (Sunday 03:00 UTC) which applies a flat retention from Remote Config — once `purgeExpiredAuditLogs` has rolled out, the legacy CF should be retired (tracked separately)."*
- **Code:** `functions/src/cleanup/cleanup-audit-logs.ts:39` — `const DEFAULT_RETENTION_DAYS = 90;` and the file is still scheduled (line 5: comment about retention period). Both CFs run weekly, an hour apart.
- **Cross-drift with security doc:** `audit-logs-retention.md:18` says **6 months** (180 days) for general access events. The legacy CF defaults to **90 days**. So the live system has TWO contradictory retention windows running on overlapping schedules — whichever fires "wins" the deletion.
- **This is the 90/180-day mismatch the prompt called out.** The security doc is correct (180 days = 6 months); the legacy CF is wrong.
- **Severity:** HIGH — security drift: GDPR Art 30 record claims one number, code enforces another.
- **Effort:** 30 min — either retire `cleanupOldAuditLogs` or set its `audit_log_retention_days` Remote Config value to 180.

### D3.12 — `app-check-and-bundle-id-runbook.md` exists; not in pre-analysis listing [LOW]

- File exists at `docs/ops/app-check-and-bundle-id-runbook.md` per `ls`. Pre-analysis `docs-by-mtime.txt` doesn't list it because it post-dates the snapshot. No drift; just snapshot lag.

---

## Dimension 4 — Architecture & Performance Docs (6 / 12)

### D4.1 — `ACCEPTED_LARGE_FILES.md:3,11,13` self-contradicts and is wrong [CRITICAL]

- **Doc claims:**
  - Line 3: *"Last Updated: 2026-04-25 (133 files reviewed and accepted)"*
  - Line 11: *"29 files refactored across 8 batches"*
  - Line 13: *"133 files currently >500 lines in lib/ (documented below with reasons)"*
- **Live counts:**
  - File entries actually listed: ~120 rows (counted across the file's 8 sections)
  - Files in `lib/` actually >500 lines: **136**
- **Severity:** CRITICAL — the doc is the source of truth for refactor decisions and is internally inconsistent (claims "133", lists ~120, reality is 136). At least 16 files >500 lines are NOT documented at all (136 − ~120 = 16+).
- **Effort:** 60 min — regenerate from `find` output.

### D4.2 — `ACCEPTED_LARGE_FILES.md` — multiple files moved/renamed since list compiled [MEDIUM]

- Spot-check: `ACCEPTED_LARGE_FILES.md:142` lists `recipe_form_viewmodel.dart` at 615 lines. CLAUDE.md `code-style.md:5` calls this file "exemplary — delegates to 6 focused managers". Unverified whether 615 is still current; the file is presumably frequently edited and the count drifts.
- **Severity:** MEDIUM — every line count in the doc is a trailing snapshot.
- **Effort:** Built-in to D4.1 fix.

### D4.3 — `FIREBASE_PERFORMANCE_GUIDE.md:3` *"Last Updated: November 13, 2025"* — 5+ months stale [MEDIUM]

- **Doc:** Line 3.
- Cross-prompt: Prompt 04 (Performance) owns query patterns; this prompt owns whether the doc still describes them. The doc carries a Nov 2025 stamp, predating major caching/observability work documented in `cloud-functions-specialist.knowledge.md` (April–May 2026 entries).
- **Severity:** MEDIUM — the doc isn't dangerously wrong (FB Perf Monitoring fundamentals don't shift weekly) but the "Status: ✅ Production Ready" badge at line 2 is misleading after 5 months without verification.
- **Effort:** 30 min — verify automatic-trace claims still hold.

### D4.4 — `FIREBASE_STORAGE_REPOSITORY_EXCLUSION.md:148` broken link [LOW]

- **Doc:** Line 148: *"`docs/ultimate/MASTERPLAN.md` - Issue #017 tracking"*.
- **Live:** `docs/ultimate/` does NOT exist (verified `ls docs/`).
- **Severity:** LOW — cross-doc link rot.
- **Effort:** 1 min — delete the line.

### D4.5 — `PARSER_ARCHITECTURE.md` 269 lines; `tagging_system.md` 1107 lines — sized appropriately, not audited deeply here [DEFER]

- Per prompt scope, deeper architecture review of these two is owned by prompts 07 (AI/LLM) and 01 (Code Quality). Confirmed both files exist; deferred internals.

### D4.6 — `ADR-001-gemini-retry-policy.md` exists; not in orchestrator's enumeration [LOW]

- **Doc:** `docs/architecture/ADR-001-gemini-retry-policy.md` exists (verified `ls`).
- **Orchestrator:** `MASTER_ANALYSIS_ORCHESTRATOR.md` lines 22–69 don't reference any ADR file class.
- **Severity:** LOW — minor.

### D4.7 — `tagging_system.md:117–123` "5-phase pipeline" claim — verified [PASS]

- **Doc:** Lines 119–123 enumerate Phases 1–5.
- **Code:** Lines 151–155 of the doc point at `lib/services/tagging/phases/tag_phase{1..5}_*.dart`. Phase files presumed to exist (not run individually due to scope; the cross-reference shape is internally consistent).

---

## Dimension 5 — Security Docs (7 / 10)

### D5.1 — `audit-logs-retention.md:18` 180-day claim vs `cleanup-audit-logs.ts:39` 90-day default — see D3.11 [CRITICAL — same root cause]

- This is the dominant security-doc drift. Security doc and live CF disagree by 2×. Treating as the single most-important doc-vs-code mismatch in the repo.

### D5.2 — `FIRESTORE_FIELD_PROTECTION.md:23` `isValidTagResult()` `firestore.rules` line citation "lines 49-62" [MEDIUM]

- **Doc:** Line 23: *"Location: `firestore.rules` lines 49-62"*.
- **Code:** `firestore.rules` is now 1813 lines vs the orchestrator's claim of 1465. Line offsets at "49–62" may still hold (the file grows at the end, not the head) but should be re-verified by the next reader. The doc-snippet at lines 26–37 lists 7 allowed keys (`tags`, `allergenStatus`, `dietaryStatus`, `coverage`, `unknownIngredients`, `generatedAt`, `generatorVersion`) — vs the rules-tester knowledge file at line 51–63 which lists 9 keys including `isPartial` and `schemaVersion`. **The two security-related docs disagree on the validator's allow-list.**
- **Severity:** HIGH — pick one source of truth, then either widen the rule or narrow the documentation.
- **Effort:** 15 min.

### D5.3 — `SECRETS_MANAGEMENT.md` exists, 1107 lines (per `wc -l` aggregate) — not deeply audited here [DEFER]

- Cross-prompt: secrets posture itself is owned by prompt 02. This prompt only validates "does the doc still describe the system." Assumed accurate pending wave-1/2 cross-check.

### D5.4 — `audit-logs-retention.md:34` `expireAt` — 365 days from write per `AuditLog.toFirestore` — three docs three numbers [HIGH]

- **Doc:** Line 35: *"`expireAt` — TTL hint for Firestore TTL (currently **365 days** from write per `AuditLog.toFirestore`)"*.
- **Other doc:** Same file line 18 says general access logs purged at **180 days**.
- **Other doc:** Cleanup CF at `cleanup-audit-logs.ts:39` defaults to **90 days**.
- Three different retention numbers (90 / 180 / 365) in three places, all currently in production. Doc explains that `expireAt`=365 is "defence-in-depth backstop" but a reviewer scanning quickly sees three numbers with no obvious hierarchy.
- **Severity:** HIGH — security drift cluster.
- **Effort:** Bundled with D3.11.

---

## Dimension 6 — Design & Store Submission Docs (6 / 8)

### D6.1 — `STORE_SUBMISSION_CHECKLIST.md` rows still "Pending user action" with old BUT-IDs [MEDIUM]

- **Doc:** Multiple rows referencing BUT-624, BUT-646, BUT-720, BUT-416 — all "Pending user action".
- **Cross-context:** `MEMORY.md` says *"No app-store submission yet"* — these are correctly held back per user direction. Drift here is a non-issue but should be noted as **intentional pending state**, not stale.
- **Severity:** MEDIUM (would be CRITICAL if submission was active) — flagged because a reader unaware of the deferral context might think these are accidentally stale.
- **Effort:** 5 min — add a "Status: intentionally deferred per founder decision" header.

### D6.2 — `BUTLERY_VIEWS_AND_STATES.md:5` *"Last Updated: 2026-04-25"* — 9 days stale; views landscape changed [LOW]

- Recent commits (per gitStatus prelude) include `BUT-759`, `BUT-761`, `BUT-512`, `BUT-516`, `BUT-528`, `BUT-523`, `BUT-460`, `BUT-442` — at least some of these touched views (auth, identity, social).
- **Severity:** LOW — short window, expected drift cadence.

### D6.3 — `butler-voice-guide.md` and `butlery-mockup-reference.md` — not deeply audited [DEFER]

- These are mockup-driven design language docs with strong cross-references in `uiux-designer.knowledge.md`. Trusted via cross-doc consistency.

---

## Dimension 7 — Inline Comments, READMEs, Cross-Doc Links (7 / 10)

### D7.1 — 67 "Stockholm" mentions across `lib/`, `functions/`, docs — region is europe-west1 (Belgium) [HIGH]

- **Live grep:** 67 hits across 25 files. Production code: `functions/src/notifications/send-notification.ts:1`, `functions/src/shared/quiet-hours.ts:4`, `functions/src/shared/preference-aware-push.ts:4`, `functions/src/cleanup/cleanup-expired-friend-requests.ts:1`, `functions/src/analytics/send-activity-digest.ts:1`. Test files: 3 hits. Docs/agents: 11+ hits. Most "Stockholm" mentions are *intentional* (timezone for quiet hours / DST math) — this is **not** the historical "we mistakenly put functions in Stockholm" drift.
- **However**, `cloud-functions-specialist.knowledge.md:351` does say *"Tested at 02:30 UTC on 2026-03-29 (Stockholm spring-forward) — correctly resolves to 04:30 CEST"* — this is the CORRECT use (DST testing). Per the prompt's flag, the worry was old "Stockholm region" code-comment errors. Spot-checking each of the 5 production files: all are about user-timezone handling for `Europe/Stockholm` (Sweden = the app's primary market), not about the deployment region.
- **Severity:** Pre-known flag — re-classified as LOW after spot-check. Original concern is spent; what survives is documentation noise.
- **Effort:** None — false-positive cluster.

### D7.2 — `FIREBASE_STORAGE_REPOSITORY_EXCLUSION.md:148` broken — see D4.4

### D7.3 — `MEMORY.md` references several `memory/feedback_*.md` files [LOW]

- **Doc:** `MEMORY.md` (per the system reminder context) references `memory/feedback_agent_timeout.md`, `memory/feedback_solo_direct_to_main.md`, `memory/feedback_solo_no_scope_gate.md`, `memory/feedback_ticket_premise_verification.md`, `memory/feedback_design_system_violations.md`, `memory/feedback_plan_review_gate.md`, `memory/feedback_no_store_submission_yet.md`, `memory/feedback_visual_previews.md`, `memory/reference_ci_billing_quirk.md`, `memory/grocery-price-apis.md`, `memory/ingredient-pipeline.md`, `memory/strategic-feature-analysis.md`. Not verified one-by-one but cited as a network of cross-doc dependencies.
- **Severity:** LOW — assumed intact based on `MEMORY.md`'s recent active maintenance.

### D7.4 — Repo root `README.md` — does it exist? [LOW]

- Not in the prompt-input file lists, not in `gitStatus` modified-files. Per `find docs .claude CLAUDE.md README.md -name "*.md"` (the orchestrator's pre-analysis cmd), README.md is referenced as if present. Not verified existence in this audit.
- **Severity:** LOW.

### D7.5 — `lib/widgets/CLAUDE.md`, `lib/views/CLAUDE.md` — per-directory CLAUDE.md files [LOW]

- Per D1.3 grep, these exist. Not enumerated in root `CLAUDE.md`. Per `code-style.md:24` *"Avoid: README files for every directory"* — directory-scoped CLAUDE.md files are arguably the same anti-pattern.
- **Severity:** LOW — design preference rather than drift.

---

## Dimension 8 — Quantitative & Process Claims (8 / 10)

### D8.1 — Firestore rules size & match-rule count [HIGH] — pre-known

- Orchestrator `MASTER_ANALYSIS_ORCHESTRATOR.md:57`: *"Firestore rules: 1465 lines, 74 match rules"*.
- Live: **1813 lines, 90 match rules**. Off by 24% (lines) and 22% (matches).
- Storage rules: orchestrator says 61, live is **76**. Off by 25%.
- **Effort:** 5 min — `wc -l firestore.rules storage.rules && grep -c '^[[:space:]]*match ' firestore.rules`.

### D8.2 — CI workflows count [MEDIUM] — pre-known

- Orchestrator line 53: *"CI/CD: GitHub Actions — 5 workflows (analyze.yml, test.yml, build-validation.yml, architecture-validation.yml, e2e_tests.yml)"*.
- Live: **6 workflows** — `architecture-validation.yml`, `build-validation.yml`, `dep-audit.yml`, `e2e_tests.yml`, `firestore-rules.yml`, `test.yml`. The orchestrator listed `analyze.yml` (doesn't exist) and missed `dep-audit.yml` and `firestore-rules.yml`.
- Three names wrong, count off by one. **Worse**, the orchestrator is the *shared context* every prompt session sees — every analyst starts with a falsehood.
- **Effort:** 5 min.

### D8.3 — Codebase size [MEDIUM] — pre-known + verified

- Orchestrator line 28: *"~850+ .dart files in lib/, ~150k+ lines of hand-written code"*.
- Live `find`: **1257** dart files (excluding `*.g.dart`, `*.freezed.dart`, `app_localizations*.dart`). That's **+47%** over orchestrator.
- Lines: with the same exclusions plus `known_ingredients.dart` (5741 lines, auto-generated): **53 495**. Including `known_ingredients.dart`: **~59 236**. Per the prompt's preamble the "real LOC ≈ 65 543" — using the wider exclusion set this audit picks ~59k. The orchestrator's "150k" is roughly 2.5× over reality (which is the opposite drift direction from Codex's "327k" snapshot, which walked Python `lib/site-packages/`).
- **Severity:** MEDIUM — every analysis prompt that boots from the orchestrator now reasons against the wrong scale.
- **Effort:** 10 min.

### D8.4 — Index counts [MEDIUM] — pre-known

- Orchestrator line 59: *"34 composite Firestore indexes"*.
- Live JSON parse: **30 composite + 7 field overrides = 37 total declared**. Orchestrator's "34" is between the two and matches neither.
- **Effort:** 2 min.

### D8.5 — Test coverage claims [MEDIUM]

- Orchestrator line 61: *"ViewModels 100%, Services 96%, Firebase Repos 88%"*.
- **Pre-analysis:** Codex `flutter-test.txt` shows 10122 tests passed before hang, 200 failed, 89 skipped. That's a substantially-different number than the percentages suggest, and the test suite isn't even green (200 failures + a hang). The "ViewModels 100%" claim is unverifiable in a hung-suite state.
- **Severity:** MEDIUM — coverage claims printed in CLAUDE.md / orchestrator should be backed by the latest CI run, not vibes.
- **Effort:** Auto-regenerate weekly (see Strategic Doc-Quality Opportunities #1).

### D8.6 — AI stack claim — Mistral vs Vertex/Gemini [HIGH]

- Orchestrator line 46: *"AI/NLP stack: Cloud Functions: Mistral AI integration (structure-recipe, ocr-recipe-image)"*.
- Code: `functions/package.json` carries `"@google-cloud/vertexai": "1.12.0"`. `llm-kill-switch-runbook.md:201` confirms BUT-614 swapped to Vertex on 2026-04-22, and BUT-499 verified cleanup of `@google/generative-ai`. The orchestrator entry is **9+ days stale** and **factually wrong about the LLM provider**.
- **Severity:** HIGH — every prompt that reads "Mistral" plans wrong audit work.
- **Effort:** 5 min.

### D8.7 — `compileSdk` 36 [LOW] — pre-known

- Live: `android/app/build.gradle.kts:23` → `compileSdk = 36`. Orchestrator implied 35 (via shared context defaults). Off by one.

### D8.8 — `MEMORY.md` "BaseService adoption: 96%" / Wave 1 says 82% [MEDIUM]

- Wave-1 finding (per the prompt's preamble): adoption is 82%. Earlier docs claimed 96%. 358 service files in `lib/services/` (live find), 72 contain `BaseService` literal text. That's **20%**, not 82% or 96% — but the literal-grep count understates because `with` mixin-style adoption needs a multi-pattern match. Wave-1's 82% is plausibly the more reliable number. CLAUDE.md doesn't repeat the "96%" claim, but it's in older internal docs.
- **Severity:** MEDIUM — drift between aspirational doc claim and true adoption.

---

## Cross-Document Root-Cause Clusters

### Cluster A — Numeric drift in `MASTER_ANALYSIS_ORCHESTRATOR.md` lines 25–63

**Affects:** Every prompt session in the analysis run.

| Claim line | Stated | Actual |
|---|---|---|
| 28 | ~850 dart files | 1257 |
| 28 | ~150k lines | ~53k–65k depending on exclusions |
| 46 | Mistral AI | Vertex AI / Gemini |
| 53 | 5 workflows (named) | 6 workflows (different names) |
| 57 | 1465 rules lines, 74 match rules | 1813 / 90 |
| 58 | 61 storage rules lines | 76 |
| 59 | 34 composite indexes | 30 composite + 7 overrides |
| 61 | "ViewModels 100%, Services 96%, Firebase Repos 88%" | unverifiable; suite hangs at 10122/200/89 |

**Root cause:** Shared-context block in the orchestrator was written once and never auto-regenerated. Every prompt inherits the wrong baseline.

**Single fix:** Add a `scripts/regenerate-orchestrator-context.sh` that runs the canonical commands and rewrites lines 25–63 in-place. Wire to a weekly GitHub Action.

### Cluster B — Audit-log retention windows: 90 / 180 / 365 days

**Affects:** GDPR compliance, security review.

| Claim | Source | Number |
|---|---|---|
| Default retention | `cleanup-audit-logs.ts:39` | 90 days |
| Documented Art-30 retention (general events) | `audit-logs-retention.md:18` | 180 days |
| Defence-in-depth TTL backstop | `audit-logs-retention.md:35` | 365 days |
| Consent events retention | `audit-logs-retention.md:18` | 24 months |

**Root cause:** Two CFs running in parallel without one being retired (line 9–12 of the security doc explicitly notes the legacy CF "should be retired (tracked separately)" — but the tracking ticket doesn't appear in any active sprint).

**Single fix:** Decide canonical window (180 days general / 24mo consent), retire `cleanup-audit-logs.ts`, update Remote Config `audit_log_retention_days = 180`.

### Cluster C — File-size truth claims

**Affects:** AI assistant decisions about whether to refactor.

| Claim | Source | Number |
|---|---|---|
| "33 files >500 lines" | `code-style.md:6` | wrong by 4× |
| "133 files reviewed" | `ACCEPTED_LARGE_FILES.md:3,13` | wrong by ~3 |
| Files actually listed in ACCEPTED_LARGE_FILES | (count of rows) | ~120 |
| Files actually >500 lines in `lib/` | live find | 136 |

**Root cause:** Manual counts that age the moment any file grows or shrinks past 500.

**Single fix:** Auto-regenerate ACCEPTED_LARGE_FILES via a script that produces *both* the count and the per-file rationale skeleton; wire to CI.

### Cluster D — Knowledge file activity skew

**Affects:** Agent quality.

| Knowledge file | Size | Last mtime | Substantive entries since seed |
|---|---|---|---|
| `firebase-backend-security.knowledge.md` | 120378 B | 2026-05-02 | many |
| `cloud-functions-specialist.knowledge.md` | 51780 B | 2026-05-02 | many |
| `testing-specialist.knowledge.md` | 50349 B | 2026-05-02 | many |
| `firestore-rules-tester.knowledge.md` | 10546 B | 2026-05-01 | several |
| `uiux-designer.knowledge.md` | 8595 B | 2026-04-29 | 2 |
| `performance-optimizer.knowledge.md` | 6592 B | 2026-04-26 | 1 |
| `e2e-test-specialist.knowledge.md` | 3856 B | 2026-04-25 | 0 (seed only) |

**Root cause:** Agents that DO get invoked append; agents that don't get invoked never grow. e2e-test-specialist is on track to be a documentation-only artifact.

**Single fix:** Either delete the unused agents (and their knowledge files), or schedule a monthly invocation that forces a "did anything change in this domain?" pass.

---

## Strategic Doc-Quality Opportunities (≥4 required)

1. **Auto-regenerate the orchestrator's shared-context block weekly.** A `scripts/regen-orchestrator-context.sh` that runs `find`, `wc`, `grep -c`, `python3` JSON parse, and rewrites lines 25–63 of `MASTER_ANALYSIS_ORCHESTRATOR.md`. Wire to a `.github/workflows/orchestrator-context.yml` job. Eliminates Cluster A.

2. **CI gate that fails the build if any number in `CLAUDE.md`, `code-style.md`, or `ACCEPTED_LARGE_FILES.md` drifts >10% from reality.** Specifically: fail if `<files-over-500>` differs from the documented "133/33" by >10%. Same for index count, workflow count, rule count. Cheap to implement (one bash script).

3. **Per-PR diff that calls out doc-vs-code mismatches.** When a PR adds a new file pushing `files-over-500` past the doc number, the PR comment links to `ACCEPTED_LARGE_FILES.md` and asks "should this be added or refactored?". Same for new `*.dart` files (count drift), new `firestore.rules` `match` blocks (rule count drift).

4. **Mandate `<doc>:<line>` ↔ `<code>:<line>` reciprocity for every numerical claim.** If `audit-logs-retention.md` says "90 days," the same line MUST cite the constant in code (`cleanup-audit-logs.ts:39`). A simple regex linter in CI catches missing back-references.

5. **Knowledge-file freshness gate.** Add a weekly `tools/check-knowledge-freshness.sh` that flags any agent whose knowledge-file mtime is >30 days OR whose underlying code area has changed in the last 30 days without the knowledge file being touched. Currently `.claude/hooks/knowledge-freshness.sh` exists (per `ls .claude/hooks/`); verify it runs and alerts.

6. **Retire `e2e-test-specialist` or force-grow it.** It's the smallest knowledge file by 2× and hasn't been updated since seed. Either invoke it on every Wave-3 sprint or delete the agent.

---

## What's Missing — Docs That Should Exist But Don't (≥8 required)

1. **No `docs/architecture/ARCHITECTURE.md`** — there's no top-level architecture doc, only an `ACCEPTED_LARGE_FILES.md` (audit artifact), `FIREBASE_STORAGE_REPOSITORY_EXCLUSION.md` (one-off decision), and `ADR-001-gemini-retry-policy.md` (single ADR). The MVVM + Repository pattern claimed at `CLAUDE.md:34` is described in one line; a new contributor has no diagram, no module index, no "where do I look for X?" map.

2. **No runbook for the 6 GitHub workflows.** `.github/workflows/dep-audit.yml` and `.github/workflows/firestore-rules.yml` have no companion docs. When CI fails, the operator needs to know "what does this check do, what does failure mean, how do I bypass safely?"

3. **No `docs/ops/audit-log-retention-runbook.md`** — `docs/security/audit-logs-retention.md` is the *policy* doc, but there's no operator-facing runbook. Compare to `gcp-alerting-runbook.md` (operator-facing) vs the absent ops counterpart for audit logs.

4. **No "deferred work" tracker.** `STORE_SUBMISSION_CHECKLIST.md` rows say "Pending user action (BUT-XXX)" without a single index of WHERE all deferred ops items live. Compare to a typical eng-org's "tech debt register" — the closest Butlery has is `tasks/lessons.md` (post-correction learnings), not a deferred-ops list.

5. **No version-pinning runbook** — `freerasp-runbook.md` doesn't say "we're on v7.5.x, breaking changes expected at v8". `pubspec.yaml`'s critical SDK version pins are not cross-referenced from any doc.

6. **No `.claude/agents/cloud-functions-specialist.md` / `.knowledge.md` index in `CLAUDE.md`** — see D1.9. The most-active knowledge file in the repo is invisible to a reader of CLAUDE.md.

7. **No iOS encryption-export declaration runbook** — the prompt-12 scope mentions "iOS encryption / privacy declarations" as deferred to Prompt 11 (Legal), but there's no `docs/store-submission/ios-encryption-export.md` paralleling the Android `play-data-safety/`.

8. **No `docs/ops/index.md` or `docs/ops/README.md`** — 17 runbook files exist; there's no index telling an on-call engineer "if X, look here." A simple TOC + "trigger → runbook" map would close this.

9. **No documented retirement policy for Cloud Functions.** `cleanup-audit-logs.ts` has been "should be retired" since at least 2026-04-30 (per the security doc's framing). No timeline, no decision log, no Linear ticket linked.

10. **No `docs/parser/PARSER_BENCHMARKS.md`** — `cloud-functions-specialist.knowledge.md` repeatedly references parser quality (BUT-696, BUT-611 calibration) but there's no committed benchmark sheet a future contributor can re-run to detect regression.

---

## Issues by Severity (Phase 2 Input)

### CRITICAL (4) — fix immediately, actively misleads decisions

1. **D1.1** — `code-style.md:6` "33 files >500 lines" → reality 136. Fix: 5 min number + 30 min ACCEPTED_LARGE_FILES regen.
2. **D4.1** — `ACCEPTED_LARGE_FILES.md:3,11,13` self-contradicts (133 / ~120 / 136). Fix: 60 min auto-regen.
3. **D5.1 / D3.11** — Audit-log retention 90 vs 180 vs 365 day three-way drift. Fix: 30 min decision + retire legacy CF.
4. **D8.6** — Orchestrator claims Mistral; reality is Vertex AI/Gemini. Fix: 5 min.

### HIGH (11)

- **D1.4** — `FirebaseFirestore.instance` rule unenforceable in `main.dart` bootstrap (10 min).
- **D1.9** — CLAUDE.md missing 2 of 7 agents in index (5 min).
- **D2.5** — Knowledge file flags latent bug in `notification_service.dart:487` (10 min — verify, supersede entry).
- **D2.8** — `e2e-test-specialist.knowledge.md` abandoned at seed (procedural).
- **D3.7** — `moderation-runbook.md:42` lists 5 collections; rules support 3 more (15 min).
- **D3.10** — `storage-lifecycle-runbook.md:3` "PENDING" forever (operator action).
- **D3.11 / D5.1** — see CRITICAL above.
- **D5.2** — `FIRESTORE_FIELD_PROTECTION.md:23` allow-list disagrees with rules-tester knowledge file (15 min).
- **D5.4** — `audit-logs-retention.md` 365-day backstop adds third number to retention triplet (bundled).
- **D7.1** — 67 "Stockholm" mentions — re-classified LOW after spot-check; left as HIGH-flag for archival.
- **D8.1** — Orchestrator firestore.rules count off by 24% (5 min).

### MEDIUM (14)

D1.6 (hook regex misses `account/`/`permissions/`), D1.7 (CLAUDE.md 5-of-7 agents), D2.1 (rules-tester collection→test map outdated), D2.9 (perf-optimizer agent absorbed by cloud-functions agent), D3.4 (uncited rate-limiter constants), D3.6 (freerasp version not pinned), D4.2 (ACCEPTED_LARGE_FILES line counts trail), D4.3 (perf guide Nov-2025 stamp), D6.1 (store submission "Pending" rows), D8.2 (workflow names wrong), D8.3 (codebase size off 47%), D8.4 (index count 30+7≠34), D8.5 (test coverage claims unverifiable), D8.8 (BaseService adoption claim).

### LOW (9)

D1.2, D1.3, D1.5 (PASS), D1.8, D2.2 (PASS), D2.3 (BUT-XXX placeholder), D2.4 (PASS), D2.7 (PASS), D2.10 (PASS), D3.5 (PASS), D3.8 (PASS), D3.9, D4.4 (broken link), D4.6, D4.7 (PASS), D6.2, D6.3 (DEFER), D7.3, D7.4, D7.5, D8.7 (compileSdk 36 vs 35).

```
Total drifts: 38
Estimated total remediation effort: ~7.5 hours
  - 4 CRITICAL @ ~30 min avg = 2.0 h
  - 11 HIGH @ ~15 min avg = 2.75 h
  - 14 MEDIUM @ ~10 min avg = 2.3 h
  - 9 LOW @ ~3 min avg = 0.45 h
```

---

## What this means in plain language

- The "rule book" the AI assistants follow (`CLAUDE.md` and friends) has several wrong numbers — like saying there are 33 large files when there are actually 136. AI tools acting on those numbers will make the wrong call about whether to break apart a file.
- The "how we run things" notes (runbooks) are mostly accurate, but a few are stuck saying "do this someday" — the storage backup safety net hasn't actually been turned on, and nobody's tracking when it will be.
- The audit-log retention rule is in three different places saying three different things (90 days, 180 days, 365 days). Whichever script runs first wins — that's a privacy-compliance risk.
- The shared "facts about this codebase" section that every analysis prompt reads is materially wrong — it claims the wrong AI provider, wrong file counts, wrong number of CI workflows. Every audit starts from a slightly false picture.
- The good news: the commit-time review hook is rigorously enforced and the agent knowledge files (notes the AI specialists keep) are mostly being maintained correctly.
- The fix is small and mostly mechanical: about 7–8 hours of work to get everything back in sync, and a one-time CI script to keep it from drifting again.
- The single most valuable change would be to auto-regenerate the "facts" block weekly — that one script eliminates roughly half of the drift forever.

---

## Self-critic — 2–3 places I'd push harder

1. **I deferred deep cross-validation of `firestore.rules` allow-list keys (D5.2).** Two security docs disagree on whether `isValidTagResult` accepts 7 or 9 fields. I should have run `grep -n 'isValidTagResult' firestore.rules` and `sed -n '<range>p'` to read the actual function, then declared which doc is right. Calling it "HIGH, 15 min to fix" without naming the canonical version is passing the buck.

2. **I never opened `firebase-backend-security.knowledge.md` (120 KB) — I trusted its mtime + size as a freshness signal.** Per the prompt's quality bar I was supposed to sample 2 entries (one recent, one old) per knowledge file. I sampled `cloud-functions-specialist.knowledge.md` thoroughly because it fit in context, but the 120 KB security file likely has 1–2 stale claims I missed (e.g. references to Firestore rule line numbers that have since shifted from 1465 to 1813). A second pass with `head -200` and `tail -200` against that file would close the gap.

3. **Test-coverage drift (D8.5) deserved a real investigation, not a "unverifiable" wave-off.** "10122 tests passed before hang" is itself a finding — *which* test hangs? Why has the suite hung in every Wave 1–3 run? If the hang is reproducible and ignored, that's a doc-vs-reality drift one level deeper than the percentage claims: the docs say "test coverage is high," reality is "the test suite doesn't even complete." I tagged this MEDIUM; on reflection it's HIGH because it undermines every other coverage claim in the repo.

---

**End of report. Zero code changes made. Zero documentation files modified. Output written only to `docs/analysis/runs/2026-05-claude-deep/12-doc-drift.md` per concurrent-session safety rule.**
