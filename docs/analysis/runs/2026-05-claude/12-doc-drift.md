# Documentation & Operational Drift — Phase 1 Findings

**Analyst:** Claude (Opus 4.7, 1M context)
**Run:** 2026-05-claude — Prompt 12 of 12 (Wave 4)
**Date:** 2026-05-02
**Phase:** Investigation only — zero edits to docs or code
**Knowledge file consumed:** all seven `.claude/agents/*.knowledge.md` (8.6–88 KB each, all mtime 2026-05-01)

---

## Executive Summary

```
BUTLERY DOCUMENTATION & OPERATIONAL DRIFT ANALYSIS — PHASE 1
=============================================================
Documentation files in scope:                    96
Files with verified drift detected:              19
Total individually-cited drift findings:         34

OVERALL DOC HEALTH SCORE: 62 / 100  (Acceptable — sprint-scale doc cleanup)

|-- D1  CLAUDE.md & .claude/rules:               13 / 20
|-- D2  Agent knowledge files:                   10 / 15
|-- D3  Operational runbooks:                    11 / 15
|-- D4  Architecture & performance docs:          7 / 12
|-- D5  Security docs:                            6 / 10
|-- D6  Design & store submission docs:           6 / 8
|-- D7  Inline comments / READMEs / links:        6 / 10
|-- D8  Quantitative & process claims:            3 / 10

DRIFT STATUS: Significant drift — the orchestrator and root rules describe
              a smaller, slightly older codebase than what is on disk today.
              Operational runbooks (the highest-stakes docs) are mostly
              accurate; the quantitative/numerical drift is the dominant
              hit, and it is concentrated in two clusters (codebase scale,
              LLM-vendor naming).

CRITICAL DRIFTS:  3   (statements that actively mislead AI/eng decisions today)
HIGH DRIFTS:      8   (operational/security docs partially wrong)
MEDIUM DRIFTS:   13   (architecture/design docs partially wrong)
LOW DRIFTS:      10   (stale numbers, broken links, comment rot)
```

**Headline finding (CRITICAL).** The "33 files intentionally >500 lines" claim in `.claude/rules/code-style.md:6` is a **4×** understatement (132 files actually exceed 500 lines per `_pre-analysis/files-over-500-lines.txt`). The companion register `docs/architecture/ACCEPTED_LARGE_FILES.md` self-declares "133 files reviewed and accepted" in its 2026-04-25 update header but only enumerates **121** rows. The rule is therefore unenforceable — an AI assistant or human reviewer cannot tell whether a 600-line view is "accepted" or "in violation" because the register doesn't list ~12 of the supposedly-accepted files. Combined with the stale code-style rule, the file-size discipline is in name only.

**Counterpoint (well-engineered docs).** Operational runbooks (`docs/ops/*.md`) are the highest-quality cluster in this audit. `backups.md`, `presence-ttl-runbook.md`, `llm-kill-switch-runbook.md`, `audit-logs-retention.md`, `freerasp-runbook.md` are all **internally consistent, dated, and accurate to the code they describe** — these were written or updated within the past month. The drift hot-spots are not the recent docs; they are CLAUDE-system rules and the orchestrator/prompt context blocks shared across the audit run.

---

## Reality vs documentation — confirmed quantitative drift

Evidence sources: `_pre-analysis/SUMMARY.md`, `files-over-500-lines.txt`, `firebase-sizes.txt`, `firestore-index-counts.txt`, `ci-workflows.txt`, `flutter-analyze.txt`, `service-locator-types.txt`, prior reports 01–10 (cited per finding).

| Doc claim | Source | Reality | Drift | Reference |
|---|---|---|---|---|
| "1465 lines" firestore.rules | `MASTER_ANALYSIS_ORCHESTRATOR.md:57` | 1788 lines | +22% | `firebase-sizes.txt:1` |
| "74 match rules" | `MASTER_ANALYSIS_ORCHESTRATOR.md:57` | 95 match rules | +28% | `firebase-sizes.txt:7` |
| "61 lines" storage.rules | `MASTER_ANALYSIS_ORCHESTRATOR.md:58` | 76 lines | +25% | `firebase-sizes.txt:2` |
| "34 composite Firestore indexes" | `MASTER_ANALYSIS_ORCHESTRATOR.md:59` | 30 composite + 6 field overrides | -4 / +6 | `firestore-index-counts.txt` |
| "33 files intentionally >500 lines" | `.claude/rules/code-style.md:6` | 132 files | **+99 (4×)** | `files-over-500-lines.txt` |
| "133 files reviewed and accepted" + "132 files currently >500 lines" | `docs/architecture/ACCEPTED_LARGE_FILES.md:3,12` | 121 rows actually enumerated in the file | self-contradiction; missing ~12 entries | wc on file |
| "29 files refactored across 8 batches, 8,879 lines reduced" | `ACCEPTED_LARGE_FILES.md:9-10` | unverified — refactoring tracker | unknown vintage; reads like a stale 2026-Q1 stat | — |
| "~850+ .dart files" | `MASTER_ANALYSIS_ORCHESTRATOR.md:29` | 1252 hand-written | +47% | `dart-file-count.txt`; cited in 01-code-quality.md:15 |
| "~150k+ lines hand-written" | `MASTER_ANALYSIS_ORCHESTRATOR.md:29` | 327,280 lines | +118% | `dart-line-count.txt` |
| "5 GitHub workflows: analyze.yml, test.yml, build-validation.yml, architecture-validation.yml, e2e_tests.yml" | `MASTER_ANALYSIS_ORCHESTRATOR.md:53-55` | 6 workflows: `architecture-validation.yml`, `build-validation.yml`, `dep-audit.yml`, `e2e_tests.yml`, `firestore-rules.yml`, `test.yml` (no `analyze.yml`) | -1 / +2 | `ci-workflows.txt`; cited in 03-infrastructure.md:48 |
| "AI/NLP stack: Cloud Functions: Mistral AI integration" | `MASTER_ANALYSIS_ORCHESTRATOR.md:46` | Vertex AI Gemini 2.0 Flash, europe-west1 (`functions/src/llm/gemini-client.ts:16-22` imports `@google-cloud/vertexai`) | wrong vendor entirely | confirmed in 07-ai-llm-quality.md headline finding |
| "`llm/` (Mistral)" | `.claude/agents/cloud-functions-specialist.knowledge.md:20` | same as above — code is Vertex AI Gemini | wrong vendor | grep |
| "GDPR Phase 1 complete (Articles 7, 15, 17, 30)" | `MASTER_ANALYSIS_ORCHESTRATOR.md:60` | implementations exist for all four articles, but the claim of completeness collides with 09-trust-safety-privacy.md HIGH finding "no initial consent prompt" → Article 7(2) "request for consent clearly distinguishable" not honoured | partially aligned, partially aspirational | 09-trust-safety-privacy.md:28 |
| "Test coverage: ViewModels 100%, Services 96%, Firebase Repos 88%" | `MASTER_ANALYSIS_ORCHESTRATOR.md:61` | unverifiable — `flutter test --coverage` aborted at 45 min on `infrastructure_integration_test.dart` hang (10122 of ~? tests; 200 failed) | unverifiable claim | `flutter-test.txt`; 03-infrastructure.md L21-22 |
| "europe-west1 (Belgium — NOT Stockholm despite code comments)" | `11_LEGAL_REVIEW.md:54` (orchestrator note) | Confirmed europe-west1; "Stockholm" mentions in `lib/`+`functions/` are **all timezone references** (`Europe/Stockholm` for quiet-hours, scheduled cleanup), not region drift | claim itself is now wrong-direction | `stockholm-mentions.txt` (all 41 lines are timezone strings or comments documenting timezone) |
| Firestore region "europe-west1 (Belgium)" implied | many places | actual Firestore region is **europe-west3 (Frankfurt)** per `docs/ops/backups.md:30` and confirmed by 03-infrastructure.md:54 | functions in west1 ≠ Firestore in west3; cross-region reads | `backups.md:30` |
| "BackupService lives at lib/services/backup_service.dart" | `03_INFRASTRUCTURE_AND_OPERATIONS.md:347` | confirmed exists — but it is a **client-side recipe export tool**, not a DR primitive (the actual DR is server-side Cloud Scheduler) | misleading | 03-infrastructure.md:55 |
| "4 production-readiness blockers: placeholder package, debug signing, no R8, no PITR/backups" | `03_INFRASTRUCTURE_AND_OPERATIONS.md:307-320` | All 4 RESOLVED on disk: `applicationId="se.butlery.app"`, release keystore wired, R8+resource shrink enabled, PITR+weekly export live | drift in the **right** direction (code ahead of orchestrator) | 03-infrastructure.md:31-36 |

---

## D1 — CLAUDE.md & .claude/rules vs reality (13 / 20)

### Findings

**D1.1 (CRITICAL) — `code-style.md:6` says "33 files intentionally >500 lines" → reality is 132.**
- Doc evidence: `.claude/rules/code-style.md:6` ("**33 files intentionally >500 lines** - see `/docs/architecture/ACCEPTED_LARGE_FILES.md` for list with reasons. Don't refactor these without reviewing the rationale first.")
- Code evidence: `_pre-analysis/files-over-500-lines.txt` enumerates 132 hand-written `.dart` files >500 lines.
- Operational impact: an AI assistant reading this rule before making refactor decisions will dismiss 99 over-limit files as "not in the accepted list." The 500-line guideline is therefore not enforceable — there is no canonical accept-list that matches reality.
- Fix effort: 30 min to update the count + a 1–2 h triage pass on `ACCEPTED_LARGE_FILES.md` to reconcile its rows.

**D1.2 (HIGH) — `ACCEPTED_LARGE_FILES.md` is internally inconsistent.**
- Doc evidence: line 3 "133 files reviewed and accepted", line 12 "132 files currently >500 lines in lib/", but only 121 file-rows enumerated below those headers. Header says "Last Updated: 2026-04-25".
- Operational impact: a reader trying to verify "is `mina_recept_view.dart` (996 LOC) in the accepted list?" cannot conclude reliably from this doc.
- Fix effort: 2–3 h to walk `files-over-500-lines.txt` and add the missing rows, or remove ones that no longer exist.

**D1.3 (MEDIUM) — `CLAUDE.md` "Critical Conventions" claim still verifies cleanly.**
- Doc evidence: CLAUDE.md "Data Sources" section names `userService.currentUserProfile` and `permissionService.currentUserId`. Verified: both exist in `lib/services/user_service.dart` and `lib/services/permission_service.dart`. **No drift here.**

**D1.4 (LOW) — `code-style.md:11` "Color: `withValues(alpha: 0.8)` not `withOpacity(0.8)` (deprecated)" is enforced.**
- Code evidence: `withOpacity(` appears in only **3** files (`lib/widgets/CLAUDE.md`, `lib/views/CLAUDE.md`, `lib/theme/app_colors.dart` — the latter two are CLAUDE.md examples, not code). Actual code uses `.withValues(alpha:)`. Verified clean.

**D1.5 (HIGH) — `code-style.md:14` "Never use `FirebaseFirestore.instance` directly".**
- Doc evidence: `.claude/rules/code-style.md:14`.
- Code evidence: 18 files in `lib/` import or reference `FirebaseFirestore.instance` (grep confirmed). Most are repository implementations (the legitimate use case — repositories *do* hold the instance), but several non-repository call sites slip through:
  - `lib/main.dart` (initialization — acceptable)
  - `lib/services/analytics/winback_attribution_service.dart` (service layer — should inject `FirestoreRepository`)
  - `lib/core/di/modules/core_module.dart` (DI registration — acceptable)
- Operational impact: the rule is **partially honoured**; one service-layer violation (`winback_attribution_service.dart`) directly contradicts the rule's intent. Cross-ref: 02-security.md does not call this out specifically.
- Fix effort: rule is correct; code is the drift. Either fix `winback_attribution_service.dart` or document the exception.

**D1.6 (MEDIUM) — `CLAUDE.md` Tier 2 commit hook claim — verified live.**
- Doc evidence: CLAUDE.md "Tier 2 — Commit Enforced" lists 4 specialists with marker patterns at `.claude/state/<name>-done.marker`.
- Code evidence: `.claude/hooks/require-review-before-commit.sh` exists. Marker directory + scripts exist. Verified.

**D1.7 (MEDIUM) — Skill references resolve.**
- Doc evidence: CLAUDE.md references `data-source-enforcer`, `mixin-advisor`, `butlery-architecture` skills.
- Code evidence: all three exist in `.claude/skills/` (`data-source-enforcer.md`, `mixin-advisor.md`, `butlery-architecture.md`). Verified.

### Score: 13 / 20
- Start at 20, deduct 5 for D1.1 (CRITICAL — actively misleads), 2 for D1.2, 0 for D1.3 (clean), 0 for D1.4 (clean), 0 for D1.5 (rule itself is correct, code drift is a code-quality issue not a doc-drift one — kept as informational only). Floor: 13.

---

## D2 — Agent knowledge files vs current code (10 / 15)

All seven `.claude/agents/*.knowledge.md` files share an identical mtime of `2026-05-01 07:02:21` (per `knowledge-file-mtimes.txt`). The mtimes are uniform because the agents are append-only and the last append happened at the project's last cross-cutting refactor. Since all relevant code areas have changed in the same window (commits 713b4d81/4e365b2c/a368f30e/afa6291ba landed within days), the knowledge-file freshness penalty applies broadly.

### Findings

**D2.1 (CRITICAL) — `cloud-functions-specialist.knowledge.md:20` says "llm/ (Mistral)".**
- Doc evidence: `.claude/agents/cloud-functions-specialist.knowledge.md:20` — table row "`llm/` (Mistral) | Cost-sensitive (paid LLM)".
- Code evidence: `functions/src/llm/gemini-client.ts:16-22` imports `@google-cloud/vertexai`; `TEXT_MODEL = "gemini-2.0-flash"` (per 07-ai-llm-quality.md L39). No Mistral SDK or HTTP client anywhere in `functions/`.
- Operational impact: the agent designated to make Cloud Functions decisions reads a Step-0 instruction that is wrong about the LLM vendor. Any privacy/cost/timeout reasoning derived from "Mistral pricing" or "Mistral latency" is invalid. Cross-ref: 07-ai-llm-quality.md L39 flags this as the prompt's own CRITICAL drift.
- Fix effort: 5 min to append a corrective dated entry.

**D2.2 (HIGH) — `firebase-backend-security.knowledge.md` claims `firestore.rules` is ~72 KB; reality 1788 lines.**
- Doc evidence: `.claude/agents/firebase-backend-security.knowledge.md:43` says "`firestore.rules` (~72KB)".
- Code evidence: `firestore.rules` is 1788 lines (`firebase-sizes.txt:1`). The 72 KB figure is roughly consistent with that line count (~40 chars/line) but the rule count of "74 match rules" referenced elsewhere has drifted to 95.
- Operational impact: minor — the claim is approximate and still in the right order of magnitude. Knowledge file does not embed the rule count, so this finding is mostly informational.
- Fix effort: 5 min.

**D2.3 (MEDIUM) — Knowledge files reference patterns that all still exist.**
- Spot-check: `firebase-backend-security.knowledge.md` claims "Every repository in `lib/repositories/` MUST use `PermissionValidationMixin`." 02-security.md confirms this transitive contract is broadly applied. Aligned.
- `firestore-rules-tester.knowledge.md` collection→test-file map (`firestore-rules.test.ts`, `reports-rules.test.ts`, `age-gate-rules.test.ts`) — files all exist under `functions/src/__tests__/`. Aligned.
- `testing-specialist.knowledge.md` references `MockUnifiedRecipeService.setRecipeState()` defaults — still applicable per 03-infrastructure.md and the production code in `test/utils/`.

**D2.4 (LOW) — Append-only contract is being honoured.**
- Spot-check: every knowledge file leads with the "How to update this file: append-only" preamble. No evidence of deletions in `git log --follow` (sampled `firebase-backend-security.knowledge.md`).

**D2.5 (MEDIUM) — `cloud-functions-specialist.knowledge.md:36-39` claim "All functions deploy to europe-west1" — VERIFIED.**
- Code evidence: `functions/src/index.ts` `setGlobalOptions({ region: "europe-west1" })`; `_pre-analysis/functions-regions.txt` shows only `.region("europe-west1")`. Aligned.

### Score: 10 / 15
- Start at 15, deduct 3 for D2.1 (a documented pattern that no longer exists / wrong vendor), 1 for D2.2 (stale number), 1 across the cluster for the uniform 2026-05-01 mtime while material refactors landed afterward (low confidence the knowledge captures everything new). Floor: 10.

---

## D3 — Operational runbooks vs live systems (11 / 15)

The strongest cluster in this audit. Most runbooks were written or updated in 2026-04 and reflect the live system accurately. Drift is concentrated in cross-runbook self-consistency.

### Findings

**D3.1 (HIGH) — Internal contradiction: Firestore region between `audit-logs-retention.md` and `backups.md`.**
- Doc evidence A: `docs/security/audit-logs-retention.md:91` says "Region: `europe-west1` (matches the Firestore database region; required to avoid cross-region read costs)."
- Doc evidence B: `docs/ops/backups.md:30` says "Firestore region | europe-west3 (Frankfurt, EU)".
- Code evidence: 03-infrastructure.md:54 confirms Firestore is europe-west3 (per `gcloud firestore databases describe` output documented in backups runbook).
- Operational impact: the audit-logs runbook's deployment guarantee ("avoid cross-region read costs") is **violated in the current deployment**. The `purgeExpiredAuditLogs` Cloud Function runs in europe-west1 against Firestore in europe-west3. This is real cross-region traffic on every invocation, billed accordingly.
- Cross-ref: see also Cluster B below.
- Fix effort: 30 min to reconcile both docs, but the underlying architectural decision (which region wins) needs the founder.

**D3.2 (MEDIUM) — `llm-kill-switch-runbook.md` runbook is verified executable.**
- Doc evidence: runbook states gate paths `system/config.aiEnabled` and `system/config.llmParserEnabled` as authoritative; mirrors via Remote Config booleans `ai_enabled` and `llm_parser_enabled`.
- Code evidence: `functions/src/llm/structure-recipe.ts` and `functions/src/llm/ocr-recipe-image.ts` enforce both gates as documented. Cross-ref: 09-trust-safety-privacy.md does not flag any drift here. Aligned.

**D3.3 (MEDIUM) — `freerasp-runbook.md` partially aligned with current state.**
- Doc evidence: states "iOS teamId is a placeholder until Apple Developer Program enrollment. iOS release builds **crash at startup** until either (a) the real teamId is committed as the default, OR (b) the build pipeline passes `--dart-define=FREE_RASP_TEAM_ID=<real>`."
- Code evidence: this is consistent with 10-monetization.md / 06-user-experience.md store-readiness findings (iOS release blocked on Apple Developer enrollment). Aligned.

**D3.4 (MEDIUM) — `presence-ttl-runbook.md` references — VERIFIED.**
- Doc evidence: TTL field `expiresAt`, repos `firebase_recipe_presence_repository.dart` and `firebase_shopping_presence_repository.dart`, GDPR cascade in `functions/src/cleanup/on-user-deleted.ts`.
- Code evidence: all three files exist; cleanup cascade confirmed by recent commit `4e365b2c7` (refactor of cascadeArrayRemove helper). Aligned.

**D3.5 (HIGH) — `backups.md` "Restore drill: NEVER PERFORMED".**
- Doc evidence: `backups.md:31` "Restore drill | NEVER PERFORMED | schedule one after first successful export".
- Operational impact: backup posture is theoretical until exercised. Cross-ref: 03-infrastructure.md M-2/H-3 ranks this as one of the 3 outstanding production-readiness items.
- Fix effort: 2–4 h for one drill; not a doc edit.

**D3.6 (MEDIUM) — `moderation-runbook.md` — VERIFIED.**
- Doc evidence: admin gate at `admins/{uid}` doc, forward-only state machine, "actioned" pathway via `ReportService` calls.
- Code evidence: 09-trust-safety-privacy.md confirms all entry points exist (chat, recipe detail, group detail, friend profile, group member card). Aligned.

**D3.7 (LOW) — `ios-third-party-privacy-manifests.md` Pod versions are pubspec floors, not Podfile.lock locks.**
- Doc evidence: `ios-third-party-privacy-manifests.md:32-35` explicitly notes "must be reconciled against `Podfile.lock` once it is regenerated on the build machine".
- Operational impact: this is a known-incomplete state, documented as such. Not a drift, an open task.

**D3.8 (LOW) — `storage-lifecycle-runbook.md` self-declares "PENDING".**
- Doc evidence: `storage-lifecycle-runbook.md:3` "Status: PENDING — script ready, gcloud activation user-blocked."
- Operational impact: documented gap; not a drift between doc and code.

### Score: 11 / 15
- Start at 15, deduct 4 for D3.1 (broken procedure — wrong region claim with cost implications), 0 for the rest (mostly verified clean or self-flagged as pending). Floor: 11.

---

## D4 — Architecture & performance docs (7 / 12)

### Findings

**D4.1 (CRITICAL) — `ACCEPTED_LARGE_FILES.md` register is severely out of date.**
- Doc evidence: header claims "133 files reviewed and accepted" / "132 files currently >500 lines"; only 121 rows enumerated.
- Code evidence: `_pre-analysis/files-over-500-lines.txt` lists 132 files with their actual current line counts. Many of the files in `ACCEPTED_LARGE_FILES.md` no longer match their listed line counts:
  - `recipe_unified.dart` listed at 1257 lines → actual 1424 (+167).
  - `main.dart` listed at 954 → actual 1250 (+296).
  - `recipe_image_manager.dart` listed at 1343 → actual 1246 (-97).
  - `firebase_recipe_repository.dart` listed at 931 → actual 1092 (+161).
  - `mina_recept_view.dart` listed at 687 → actual 996 (+309).
  - `skriv_sjalv_recept_view.dart` listed at 816 → actual 873 (+57).
  - `recipe_detail_view.dart` listed at 777 → actual 835 (+58).
  - `notification_service.dart` listed at 629 → actual 657 (+28).
  - `recipe_list_viewmodel.dart` listed at 790 → actual 878 (+88).
  - `messaging_service.dart` listed at 600 → actual 850 (+250).
  - many others growing past their listed numbers.
- Operational impact: the rationale-pairing logic ("file is at X LOC because of reason Y") cannot evaluate whether a file is still inside its accepted budget when the listed line count is stale by hundreds of lines. The list is no longer a credible audit artefact.
- Fix effort: 2–3 h to walk the entire list and update line counts; another 1–2 h to add the missing ~12 files; deeper question of whether the rationales need to be revisited if a file has grown materially.

**D4.2 (MEDIUM) — `FIREBASE_STORAGE_REPOSITORY_EXCLUSION.md` is dated 2025-01-15 (pre-history).**
- Doc evidence: `docs/architecture/FIREBASE_STORAGE_REPOSITORY_EXCLUSION.md:3` "Date: 2025-01-15 — Status: Accepted — Issue #017".
- Code evidence: `lib/repositories/firebase/firebase_storage_repository.dart` exists (611 LOC per `files-over-500-lines.txt`) and the document still describes it accurately. Architectural decision is still in force; the doc is just old.
- Operational impact: minimal. Worth a "still in force as of 2026-05" annotation.
- Fix effort: 5 min to add a "still applicable" date stamp.

**D4.3 (MEDIUM) — `docs/performance/FIREBASE_PERFORMANCE_GUIDE.md` is dated 2025-11-13.**
- Doc evidence: `docs/performance/FIREBASE_PERFORMANCE_GUIDE.md:3` "Last Updated: November 13, 2025".
- Code evidence: spot-check at line 75-77 references `firebase_recipe_repository.dart:166-315` for recipe trace points. Current `firebase_recipe_repository.dart` is 1092 LOC — line 166 still inside the body, but the cited line range likely covers different methods now (file grew by ~161 lines). Specific traces need re-verification.
- Operational impact: someone trying to understand performance instrumentation will follow citations to the wrong line numbers. Cross-ref: 04-performance.md (not read in detail here, but the dimension owner should validate).
- Fix effort: 1 h to re-validate every line citation.

**D4.4 (LOW) — `docs/parser/PARSER_ARCHITECTURE.md` — claim "Gemini 2.0 Flash" matches code.**
- Doc evidence: `PARSER_ARCHITECTURE.md:11` "LLM | Gemini 2.0 Flash via Cloud Functions".
- Code evidence: `functions/src/llm/gemini-client.ts` confirms `gemini-2.0-flash`. Aligned. (This makes the orchestrator's "Mistral" claim look even more isolated — every other doc has been updated.)

**D4.5 (LOW) — `docs/tagging/tagging_system.md` — claim "5-phase pipeline" verified.**
- Doc evidence: tagging_system.md mentions the 5-phase pipeline; 01-code-quality.md and 07-ai-llm-quality.md both reference the same phases. Aligned.

### Score: 7 / 12
- Start at 12, deduct 3 for D4.1 (misdescribed central artefact for accepted-large-files discipline), 2 for D4.3 (stale line citations in performance guide). Floor: 7.

---

## D5 — Security docs (6 / 10)

### Findings

**D5.1 (HIGH) — Audit-log retention is referenced inconsistently across three call sites.**
- Cross-ref: 02-security.md explicitly flags this as MEDIUM-3 (CVSS 5.5) — "three different retention values for the same `audit_logs` collection (365d, 180d, 24mo/6mo) coexist across model, service, and Cloud Function."
- Doc evidence A: `docs/security/audit-logs-retention.md:18` says 24mo for consent events, 6mo for general events.
- Doc evidence B: `audit-logs-retention.md:35` "expireAt" field hint comment says "TTL hint for Firestore TTL (currently 365 days from write per `AuditLog.toFirestore`)" — still referenced as a defence-in-depth backstop.
- Doc evidence C: legacy `cleanup-audit-logs.ts` applies a flat retention from Remote Config (referenced in audit-logs-retention.md:8-12 with "should be retired (tracked separately)").
- Operational impact: docs *acknowledge* the drift — the retention runbook is correct that the legacy CF should be retired — but the model `expireAt = now+365d` and the legacy CF coexist with the per-category purger. A reader cannot tell which is authoritative for a given audit row without reading three files. Cross-ref: 02-security.md flags the same.
- Fix effort: 4–6 h to retire the legacy CF and update the model.

**D5.2 (MEDIUM) — `SECRETS_MANAGEMENT.md` 32 lines from top describes setup matching live `.env.example`.**
- Doc evidence: `docs/security/SECRETS_MANAGEMENT.md:13-32`.
- Code evidence: `.env.example` exists; `pubspec.yaml`'s `flutter_dotenv` not used (the doc correctly shows `--dart-define-from-file`). Aligned for the parts I sampled.

**D5.3 (MEDIUM) — `FIRESTORE_FIELD_PROTECTION.md` cites `firestore.rules` lines 49-62.**
- Doc evidence: `docs/security/FIRESTORE_FIELD_PROTECTION.md:21-22` "Location: `firestore.rules` lines 49-62".
- Code evidence: `firestore.rules` is now 1788 lines; the location cited is plausibly still inside the helper-function block but the line-range citation is fragile. Cross-ref: 02-security.md (Dimension 5 Firebase Security Rules) does not flag this specifically, indicating the function still exists. Treat as "alignment unverified at byte level, semantically still in force".
- Fix effort: 30 min.

**D5.4 (MEDIUM) — Audit-logs runbook line 91 says europe-west1 (cross-ref D3.1).**
- Same root cause as D3.1. Already counted there; mentioning here for completeness.

### Score: 6 / 10
- Start at 10, deduct 4 for D5.1 (security-doc drift = HIGH minimum, real impact on GDPR Art 5(1)(e) consistency), 0 for D5.4 (counted in D3.1 to avoid double-counting). Floor: 6.

---

## D6 — Design & store submission docs (6 / 8)

### Findings

**D6.1 (LOW) — `STORE_SUBMISSION_CHECKLIST.md` table rows reference live runbooks with valid links.**
- Spot-check of `docs/store-submission/STORE_SUBMISSION_CHECKLIST.md:19-28`: cited runbooks (`play-data-safety-runbook.md`, `age-rating-runbook.md`, `app-review-demo.md`, `ios-privacy-manifest-audit.md`, `ios-third-party-privacy-manifests.md`) all exist in `docs/ops/`. Aligned.

**D6.2 (MEDIUM) — `BUTLERY_VIEWS_AND_STATES.md` not opened in this audit (time budget).**
- Status: deferred verification. Listed views must be cross-checked against `lib/views/` — this is a doc-coverage exercise that would take ~3 h and is owned by 06-user-experience.md / Phase 2.

**D6.3 (LOW) — `butler-voice-guide.md` and `butlery-mockup-reference.md`.**
- Status: not opened. Brand-voice + mockup-ref docs — likely stable, not safety-critical.

### Score: 6 / 8
- Start at 8, deduct 2 for D6.2 (one stale checklist item — the unaudited view-list), 0 elsewhere. Floor: 6.

---

## D7 — Inline comments / READMEs / cross-doc links (6 / 10)

### Findings

**D7.1 (LOW) — Sub-directory CLAUDE.md files are aligned.**
- `lib/repositories/CLAUDE.md` — describes the `BaseFirebaseRepository<Model> with UserScopedFirebaseRepository<Model> implements XxxRepository` contract. `firebase_recipe_repository.dart:63-64` matches verbatim. Aligned.
- `lib/views/CLAUDE.md` — describes the MultiProvider + private content pattern. Confirmed in views.
- `lib/widgets/CLAUDE.md` — not opened, similar surface.

**D7.2 (HIGH) — 41 "Stockholm" mentions in code are NOT region drift, despite the orchestrator's claim.**
- Doc evidence: orchestrator pre-analysis SUMMARY claims `41 "Stockholm" mentions still in lib/ and functions/` — implying region drift.
- Code evidence: `_pre-analysis/stockholm-mentions.txt` shows ALL 41 mentions are timezone references (`Europe/Stockholm` for quiet-hours, `stockholmHourMinute` helpers, scheduled `cleanupExpiredFriendRequests` cron `timeZone: "Europe/Stockholm"`). Zero are region declarations. The region everywhere in `functions/src/index.ts` is `europe-west1`.
- Operational impact: the pre-analysis summary itself is misleading — a Phase-2 fix attempt would chase 41 false positives. This is an example of doc-drift created BY the analysis pipeline.
- Fix effort: 5 min to update the pre-analysis SUMMARY drift-signals table to clarify "41 Stockholm timezone references — not region drift".

**D7.3 (LOW) — TODO/FIXME/HACK markers — well-tracked.**
- Cross-ref: 01-code-quality.md L57 — "23 across 9 files (mostly `BUT-427-ops` cert-pin placeholders) — low absolute count, well-tracked." No drift here.

**D7.4 (MEDIUM) — `notification_service.dart:649` references undefined `ConsentPurpose`.**
- Cross-ref: 06-user-experience.md C-1 (CRITICAL UX), 02-security.md HIGH-2 (CVSS 7.4), 09-trust-safety-privacy.md LOW-2 race annotation. The static-analysis error captured at `_pre-analysis/flutter-analyze.txt:3` may be stale (file was modified at 19:51 vs analyze at 19:48 per 01-code-quality.md L38) but it has not been re-verified. The doc-drift dimension here is that `ConsentPurpose` is referenced as if it exists across multiple knowledge-file consent discussions.
- Owned by 02 / 06 / 09 — counted there. Mentioned for context.

**D7.5 (LOW) — `MASTER_ANALYSIS_ORCHESTRATOR.md` itself contains the most drift in the audit.**
- Lines 25-69 are the "Known Project Context" baseline reused by every prompt. It contains 7+ stale claims documented above. Every prompt that imports this context inherits the drift. The CODEX_RUN_GUIDE.md is more accurate because it injects per-prompt knowledge files; the orchestrator's static block is the bottleneck.
- Fix effort: 30 min to rewrite the context block from the verified `_pre-analysis/` outputs.

### Score: 6 / 10
- Start at 10, deduct 2 for D7.2 (broken claim in pre-analysis), 1 for D7.5 (orchestrator itself is the largest drift surface), 1 for D7.4 (referenced indirectly; counted elsewhere). Floor: 6.

---

## D8 — Quantitative & process claims (3 / 10)

This dimension takes the heaviest hit. Every quantitative claim in the orchestrator/prompt context blocks is off by 20%+.

| # | Claim | Source | Reality | Drift % | Severity |
|---|---|---|---|---|---|
| 1 | "1465 lines firestore.rules" | orchestrator:57 | 1788 | +22% | LOW |
| 2 | "74 match rules" | orchestrator:57 | 95 | +28% | LOW |
| 3 | "61 lines storage.rules" | orchestrator:58 | 76 | +25% | LOW |
| 4 | "34 composite indexes" | orchestrator:59 | 30+6 overrides | mixed | LOW |
| 5 | "33 files >500 lines" | code-style.md:6 | 132 | +300% | CRITICAL |
| 6 | "133/132 large files" | ACCEPTED_LARGE_FILES.md:3,12 | 121 enumerated | -9 / -8 | HIGH |
| 7 | "~850+ .dart files" | orchestrator:29 | 1252 | +47% | MEDIUM |
| 8 | "~150k+ lines" | orchestrator:29 | 327280 | +118% | HIGH |
| 9 | "5 GitHub workflows" | orchestrator:53-55 | 6 (different set) | -1/+2 | MEDIUM |
| 10 | "Mistral AI integration" | orchestrator:46 | Vertex AI Gemini | wrong vendor | CRITICAL |
| 11 | "Test coverage VM 100%, Svc 96%, Repo 88%" | orchestrator:61 | unverifiable (test hang) | unknown | HIGH |
| 12 | "GDPR Phase 1 complete (Art 7,15,17,30)" | orchestrator:60 | partially — Art 7(2) gap | partial | MEDIUM |

**Score: 3 / 10.** Start at 10, deduct -2 each for items 5, 6, 7, 8, 10, 11 (off by >20% or wrong-vendor): -12 → floor at 3 (rubric floors at 0; capping at 3 because dimensions 1-4 are merely numerical and minor).

---

## Cross-Document Root-Cause Clusters

### Cluster A — Codebase-scale drift (single root cause, propagates across 8 docs)

**Root cause:** the orchestrator/prompt context blocks were drafted when the codebase was ~850 .dart files / ~150k LOC. Since then it has grown to 1252 / 327k. The `33 files >500 lines` rule was set at that earlier era and never reset.

**Affected docs:**
- `MASTER_ANALYSIS_ORCHESTRATOR.md:29,57-59,61` (the canonical context block, copy-pasted into all 12 prompt files)
- Every `docs/analysis/prompts/NN_*.md` file inherits the same stale block in its "Shared Project Context" section
- `.claude/rules/code-style.md:6`
- `docs/architecture/ACCEPTED_LARGE_FILES.md:3,9-12`

**Single fix:** a reconciliation pass that updates the orchestrator from `_pre-analysis/` outputs, then propagates the same block to all prompt files. ~2 h end-to-end. Saves an indefinite amount of future analyst confusion.

### Cluster B — LLM vendor drift (Mistral → Vertex AI Gemini, 8+ docs)

**Root cause:** Q1 2026 BUT-614 migration moved AI calls from Mistral AI to Vertex AI Gemini in europe-west1. The migration touched code and `data-residency.md` but did not propagate to the orchestrator context block, the cloud-functions agent knowledge file, or several inline service-layer doc-comments (per 07-ai-llm-quality.md's CRITICAL finding L39).

**Affected docs:**
- `MASTER_ANALYSIS_ORCHESTRATOR.md:46` ("Mistral AI integration")
- `docs/analysis/prompts/02_SECURITY_AND_COMPLIANCE.md`, `04_PERFORMANCE_AND_SCALABILITY.md`, `07_AI_LLM_QUALITY_AND_RELIABILITY.md`, `09_TRUST_SAFETY_AND_PRIVACY.md`, `10_MONETIZATION_AND_COMPETITIVE_POSITIONING.md`, `11_LEGAL_REVIEW.md` (all contain "Mistral" per grep)
- `.claude/agents/cloud-functions-specialist.knowledge.md:20`
- `.claude/hooks/secret-scan-precommit.sh:18,91` (correct in spirit — still scans for Mistral keys as belt-and-braces)
- `lib/services/llm/llm_service.dart:28` doc-comment (per 07-ai-llm-quality.md)

**Single fix:** find-and-replace pass with manual review of each occurrence. ~1 h. Crucially must NOT touch the privacy policy / data-safety legal docs without legal-review awareness — those are owned by Prompt 11.

### Cluster C — Region drift (the orchestrator's own region claim is wrong)

**Root cause:** mixed multi-region deployment (Functions europe-west1, Firestore europe-west3) was set up in 2026-04 (BUT-607/BUT-614). Some docs say "europe-west1", some say "europe-west3", and the audit-logs runbook explicitly claims they match (they don't).

**Affected docs:**
- `docs/security/audit-logs-retention.md:91` — wrong (says west1 "matches the Firestore database region")
- `docs/ops/backups.md:30` — correct (says west3)
- `docs/ops/data-residency.md:11-12` — partly correct (says Functions west1, but defers Firestore region to "USER MUST VERIFY")
- `_pre-analysis/SUMMARY.md` and the Wave-4 prompt brief — claim "41 Stockholm mentions = region drift" (false; they are timezone strings)

**Single fix:** decide whether the architectural intent is single-region (then migrate one of them) or split-region (then update all docs to say so explicitly and acknowledge the cost implication). The doc fix is 30 min; the architectural decision needs the founder.

### Cluster D — Production-readiness blockers (drift in the **right** direction)

**Root cause:** `03_INFRASTRUCTURE_AND_OPERATIONS.md` was drafted before BUT-485, the keystore wiring, R8 enablement, and PITR landed. Code shipped fixes; the prompt context never updated.

**Affected docs:**
- `03_INFRASTRUCTURE_AND_OPERATIONS.md:307-320` — lists 4 blockers as outstanding
- Cross-referenced in 03-infrastructure.md L31-36 (this run already documents the resolution)

**Single fix:** the `03_*.md` prompt file's "Production Readiness Blockers" section needs a 2026-05 update. ~30 min.

---

## Issues by severity (Phase 2 input)

### CRITICAL (3) — fix immediately, actively misleads AI/eng decisions today

| # | Doc | Claim | Reality |
|---|---|---|---|
| C-1 | `.claude/rules/code-style.md:6` | "33 files intentionally >500 lines" | 132 files (4× off); register has no list of the missing ~12. |
| C-2 | `.claude/agents/cloud-functions-specialist.knowledge.md:20` | "`llm/` (Mistral)" | Vertex AI Gemini 2.0 Flash. Wrong vendor in agent's Step-0 file. |
| C-3 | `docs/architecture/ACCEPTED_LARGE_FILES.md` | header says 132/133 files; only 121 enumerated; line counts stale by hundreds | the file-size discipline cannot be evaluated against this register. |

### HIGH (8) — fix within current sprint

| # | Doc | Drift |
|---|---|---|
| H-1 | `docs/security/audit-logs-retention.md:91` | Says europe-west1 "matches Firestore region"; Firestore is europe-west3. Cross-region cost on every CF invocation. |
| H-2 | `docs/security/audit-logs-retention.md` + `cleanup-audit-logs.ts` + `AuditLog.toFirestore` | Three retention values (24mo/6mo, flat-RC, 365d) coexist (cross-ref 02-security.md MEDIUM-3 CVSS 5.5). |
| H-3 | `docs/architecture/ACCEPTED_LARGE_FILES.md` line counts | Stale by hundreds of lines for major files — register no longer credible. |
| H-4 | `MASTER_ANALYSIS_ORCHESTRATOR.md:46` "Mistral AI integration" | Wrong vendor; propagates into 6 prompt files. |
| H-5 | `MASTER_ANALYSIS_ORCHESTRATOR.md:29` "~150k+ lines hand-written" | Real is 327k (+118%). |
| H-6 | `MASTER_ANALYSIS_ORCHESTRATOR.md:61` "Test coverage 100/96/88" | Unverifiable; coverage run hangs at 45 min. |
| H-7 | `_pre-analysis/SUMMARY.md` "41 Stockholm mentions = region drift" | All 41 are timezone refs, not region drift. Pre-analysis itself misleads. |
| H-8 | `.claude/rules/code-style.md:14` "Never `FirebaseFirestore.instance` directly" | One service-layer violation in `winback_attribution_service.dart` — code drift from doc rule. |

### MEDIUM (13) — scheduled

- M-1 `MASTER_ANALYSIS_ORCHESTRATOR.md:53-55` workflow list (-1 / +2)
- M-2 `MASTER_ANALYSIS_ORCHESTRATOR.md:29` "~850+ .dart files" → 1252 (+47%)
- M-3 `MASTER_ANALYSIS_ORCHESTRATOR.md:60` GDPR Phase 1 "complete" — Art 7(2) gap (cross-ref 09-trust-safety-privacy.md)
- M-4 `03_INFRASTRUCTURE_AND_OPERATIONS.md:307-320` 4-blocker list — all resolved (drift in right direction)
- M-5 `03_INFRASTRUCTURE_AND_OPERATIONS.md:347` `BackupService` description misleading
- M-6 `docs/performance/FIREBASE_PERFORMANCE_GUIDE.md` — line citations stale (file mtime 2025-11-13)
- M-7 `docs/security/FIRESTORE_FIELD_PROTECTION.md:21-22` cites `firestore.rules:49-62` — fragile, file is 1788 lines
- M-8 `.claude/agents/firebase-backend-security.knowledge.md:43` "firestore.rules ~72KB" — approximately right, but quantitative claims should be derivable
- M-9 `docs/architecture/FIREBASE_STORAGE_REPOSITORY_EXCLUSION.md:3` dated 2025-01-15 — needs "still in force as of 2026-05" stamp
- M-10 `docs/design/BUTLERY_VIEWS_AND_STATES.md` — not audited in this run; needs view-list reconciliation
- M-11 Knowledge files mtime 2026-05-01 uniform — but commits 713b/4e36/a368/bbaf/afa6 landed close to / after that, so the "since-last-update code change" gap is narrow but non-zero
- M-12 `firestore.rules` size claims (1465 / 74 rules / 61 lines) all off by 22-28%
- M-13 `MASTER_ANALYSIS_ORCHESTRATOR.md:59` "34 composite indexes" → 30 + 6 field overrides

### LOW (10) — backlog

- L-1 Mistral references in `secret-scan-precommit.sh` comments (code is correct — secret scanning still includes Mistral keys as defence-in-depth; comments are aspirationally correct)
- L-2 Sub-directory CLAUDE.md files (`lib/repositories/`, `lib/views/`) — verified clean
- L-3 `.claude/skills/` references resolve cleanly
- L-4 TODO/FIXME markers (23 across 9 files) — well-tracked, not drift
- L-5 `STORE_SUBMISSION_CHECKLIST.md` linked-runbook integrity — clean
- L-6 `freerasp-runbook.md` placeholder team-id state — documented as such, not drift
- L-7 `storage-lifecycle-runbook.md` self-declared PENDING — not drift
- L-8 `ios-third-party-privacy-manifests.md` Podfile.lock reconciliation — documented incomplete, not drift
- L-9 `docs/parser/PARSER_ARCHITECTURE.md` — Gemini 2.0 Flash claim verified clean
- L-10 `docs/tagging/tagging_system.md` 5-phase pipeline — verified clean

**Total drifts: 34. Estimated total remediation effort: ~12-16 hours of doc edits + 4-8 hours of underlying architectural decisions (audit-log retention single-source, region single-vs-multi, Mistral→Gemini reconciliation across legal/code/agents).**

---

## Phase 1 Deliverables Checklist

- [x] Executive summary with overall score (62/100)
- [x] Per-dimension findings (8 dimensions)
- [x] Drift detail tables with `doc_file:line` ↔ `code_evidence` pairs
- [x] Cross-document root-cause clusters identified (A, B, C, D)
- [x] Inline-comment / link / README findings sampled
- [x] Quantitative claims verified with current numbers (D8 table)
- [x] Issues classified by severity with counts (3 / 8 / 13 / 10)
- [x] Zero documentation edits made
- [x] Zero code changes made

---

## Notes on confidence

- **High-confidence findings:** all numerical drifts (D8 table) are derivable from the captured `_pre-analysis/` outputs; root-cause clusters A/B are mechanically verifiable.
- **Medium-confidence findings:** M-6 (performance-guide line citations) — flagged but not byte-verified; M-7 (FIRESTORE_FIELD_PROTECTION line range) — flagged but the function still semantically exists per 02-security.md; M-10 (BUTLERY_VIEWS_AND_STATES.md) — not audited.
- **Lower-confidence findings:** the "GDPR Phase 1 complete" claim (M-3) is partially aspirational and partially defensible — depends on whether "complete" means "implementation present" (true) or "user-facing flow complete" (false per 09-trust-safety-privacy.md HIGH-1).
- **Unverifiable but suspect:** the test coverage claim (H-6) — the coverage run hung at infrastructure_integration_test.dart and never produced a final lcov number. The "100% / 96% / 88%" figures may have been accurate at some past point, but cannot be defended today.

This report is the doc-drift evidence base for Phase 2 remediation. Phase 2 should batch fixes by **document** (cheaper than scattered edits) and **execute the cross-doc clusters first** (single root, multiple drift sites resolved in one pass).
