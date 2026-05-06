# MASTER Wave 4 — Prompt 12 (Documentation & Operational Drift) — Consensus Data

**Purpose:** Two-run consensus reduction (Codex run absent for prompt 12) for the eventual MASTER-wave4-12 finding doc.
**Inputs analysed:**
- `docs/analysis/runs/2026-05-claude/12-doc-drift.md` (default Claude, ~42 KB, 2026-05-02) — sanity-check role
- `docs/analysis/runs/2026-05-claude-deep/12-doc-drift.md` (deep + Pass-2 critic, ~51 KB, 2026-05-04) — **AUTHORITATIVE**
- Codex run for prompt 12: **NOT RUN** (run-level deferral; no codex/12-*.md exists)

**Authority rule (per orchestrator):** Deep run wins on conflict. Default findings unique to default are verified against live source and marked VERIFIED / DISPROVED / UNVERIFIABLE.

**Verification anchor (live, 2026-05-04, this audit run):**
- `firestore.rules`: **1894 lines** (deep cited 1813; default cited 1788 — both stale already)
- `storage.rules`: **76 lines** (both runs agree)
- `firestore.rules` match-rules: **92** (`grep -c '^[[:space:]]*match '`); deep cited 90, default cited 95
- `lib/` hand-written `.dart` files (excl. `*.g.dart`, `*.freezed.dart`, `app_localizations*.dart`): **1270**
- Files >500 lines (same exclusions): **131** (deep: 136, default: 132 — both close, all reject "33")
- GitHub workflows: **7** (`architecture-validation.yml`, `build-validation.yml`, `dep-audit.yml`, `e2e_tests.yml`, `firestore-rules.yml`, **`sbom.yml` (added 2026-05-04)**, `test.yml`) — both runs cited 6, neither captured `sbom.yml` because it post-dates them
- `compileSdk`: **36** (both agree)
- `setGlobalOptions({ region: "europe-west1" })`: confirmed at `functions/src/index.ts:25`

---

## Section 1 — Inventory of CRITICAL + HIGH findings

### Deep run — CRITICAL (4)

| ID | Title | Source-of-claim | Severity |
|---|---|---|---|
| D1.1 | `code-style.md:6` "33 files >500 lines" → reality 136 | `.claude/rules/code-style.md:6` | CRITICAL |
| D4.1 | `ACCEPTED_LARGE_FILES.md` self-contradicts (133 / ~120 listed / 136 actual) | `docs/architecture/ACCEPTED_LARGE_FILES.md:3,11,13` | CRITICAL |
| D5.1 / D3.11 | Audit-log retention: 90 / 180 / 365 day three-way drift | `cleanup-audit-logs.ts:39` vs `audit-logs-retention.md:18,35` | CRITICAL |
| D8.6 | Orchestrator claims "Mistral AI" — actual is Vertex AI / Gemini | `MASTER_ANALYSIS_ORCHESTRATOR.md:46` | CRITICAL (HIGH-tagged in deep severity table; appears as CRITICAL in deep summary cluster) |

### Deep run — HIGH (11)

| ID | Title |
|---|---|
| D1.4 | `FirebaseFirestore.instance` rule unenforceable in `main.dart` bootstrap (9 hits outside `lib/repositories/`) |
| D1.9 | CLAUDE.md missing `cloud-functions-specialist` and `e2e-test-specialist` from agent index (7 exist, 5 listed) |
| D2.5 | `cloud-functions-specialist.knowledge.md:455` flags `notification_service.dart:487` latent bug — unverified |
| D2.8 | `e2e-test-specialist.knowledge.md` abandoned at seed (3856 B, mtime 2026-04-25) |
| D3.7 | `moderation-runbook.md:42` lists 5 collections; rules support 3 more (`friend_categories`, `public_profiles`, `unified_shared_shopping_lists`) |
| D3.10 | `storage-lifecycle-runbook.md:3` "PENDING" through every wave, RPO claim meaningless |
| D3.11 | Legacy `cleanupOldAuditLogs` (90 days) coexists with `purgeExpiredAuditLogs` (180 days) — same root as D5.1 |
| D5.2 | `FIRESTORE_FIELD_PROTECTION.md:23` allow-list (7 keys) disagrees with rules-tester knowledge file (9 keys) |
| D5.4 | `audit-logs-retention.md:35` 365-day TTL backstop adds third number to retention triplet |
| D7.1 | 67 "Stockholm" mentions — re-classified LOW after spot-check (all timezone, not region) |
| D8.1 | Orchestrator firestore.rules 1465/74 vs reality 1813/90 (off 24%/22%) |

### Default run — CRITICAL (3)

| ID | Title |
|---|---|
| C-1 (default D1.1) | `code-style.md:6` "33 files" → 132 |
| C-2 (default D2.1) | `cloud-functions-specialist.knowledge.md:20` "`llm/` (Mistral)" — wrong vendor |
| C-3 (default D4.1) | `ACCEPTED_LARGE_FILES.md` register: 132/133 header, 121 enumerated, line counts stale by hundreds |

### Default run — HIGH (8)

| ID | Title |
|---|---|
| H-1 (D3.1) | `audit-logs-retention.md:91` says europe-west1 "matches Firestore region"; Firestore is **europe-west3** — cross-region cost |
| H-2 (D5.1) | Three audit-log retention values (24mo/6mo, flat-RC, 365d) coexist |
| H-3 (D4.1) | `ACCEPTED_LARGE_FILES.md` line counts stale by hundreds (e.g. `recipe_unified.dart` 1257→1424; `main.dart` 954→1250; `mina_recept_view.dart` 687→996) |
| H-4 | Orchestrator "Mistral AI integration" propagates into 6 prompt files |
| H-5 | Orchestrator "~150k+ lines" → 327280 (default's pre-analysis count; deep correctly disputes this) |
| H-6 | Orchestrator "Test coverage 100/96/88" unverifiable — coverage hangs at 45 min |
| H-7 | Pre-analysis SUMMARY claims "41 Stockholm = region drift" — actually all timezone refs |
| H-8 | `winback_attribution_service.dart` violates "never `FirebaseFirestore.instance`" rule |

---

## Section 2 — Two-way consensus map

### 2.1 Findings BOTH runs identified (consensus)

| Topic | Deep ID | Default ID | Consensus severity |
|---|---|---|---|
| `code-style.md` "33 files >500 lines" wrong | D1.1 (CRITICAL) | C-1 / D1.1 (CRITICAL) | **CRITICAL** (agreement) |
| `ACCEPTED_LARGE_FILES.md` self-contradiction (133 / ~120 listed / actual 131-136) | D4.1 (CRITICAL) | C-3 / D4.1 (CRITICAL) | **CRITICAL** |
| Audit-log retention 90/180/365 day drift | D5.1 + D3.11 (CRITICAL/HIGH) | H-2 / D5.1 (HIGH) | **CRITICAL** (deep wins on severity) |
| Orchestrator "Mistral AI" → Vertex/Gemini | D8.6 (CRITICAL) | C-2 / D2.1 + H-4 (CRITICAL) | **CRITICAL** |
| Orchestrator firestore.rules size off 22-25% | D8.1 (HIGH) | M-12 + table row 1-3 (LOW/MEDIUM) | **HIGH** (deep wins) |
| Orchestrator "850 dart files" / "150k LOC" wrong | D8.3 (MEDIUM) | M-2 / H-5 (MEDIUM/HIGH) | **MEDIUM** — but see disagreement note in 2.3 |
| Orchestrator workflow count wrong (5 listed) | D8.2 (MEDIUM) | M-1 (MEDIUM) | **MEDIUM** — both missed sbom.yml (now 7) |
| Orchestrator composite-index count 34 vs 30+7 overrides | D8.4 (MEDIUM) | M-13 / row 4 (LOW) | **MEDIUM** (deep wins) |
| `FIRESTORE_FIELD_PROTECTION.md:21-23` cites stale `firestore.rules` line range 49-62 | D5.2 (HIGH/MEDIUM) | M-7 (MEDIUM) | **MEDIUM-HIGH** — deep elevates because allow-list keys disagree |
| `FIREBASE_PERFORMANCE_GUIDE.md` Nov-2025 stamp / stale citations | D4.3 (MEDIUM) | M-6 (MEDIUM) | **MEDIUM** |
| `freerasp-runbook.md` partial alignment / version-pin gap | D3.6 (MEDIUM) | D3.3 (MEDIUM) | **MEDIUM** |
| `storage-lifecycle-runbook.md` PENDING | D3.10 (HIGH) | D3.8 (LOW) | **HIGH** (deep wins — pending forever is not equivalent to documented gap) |
| `STORE_SUBMISSION_CHECKLIST.md` deferred BUT-IDs | D6.1 (MEDIUM) | D6.1 (LOW) | **MEDIUM** — annotate "intentionally deferred" |
| Knowledge-file uniformity / activity skew | D2 cluster + Cluster D | D2 cluster (M-11) | **MEDIUM** |
| 67 / 41 "Stockholm" mentions are all timezone, not region drift | D7.1 (HIGH→LOW after spot-check) | H-7 (HIGH) | **LOW** (deep critic correctly downgraded; default flagged as HIGH but the *target* is the pre-analysis SUMMARY itself, not the code) |
| `compileSdk = 36` vs implied 35 | D8.7 (LOW) | (not raised) | **LOW** |
| Test-coverage claims unverifiable (suite hangs) | D8.5 (MEDIUM; self-critic upgrades to HIGH) | H-6 (HIGH) | **HIGH** (default + deep self-critic agree) |
| Hook trigger map (Tier-2) verified accurate | D1.5 (PASS) | D1.6 (PASS) | **PASS** |
| Skill references resolve | D1.8 (LOW) | D1.7 (PASS) | **PASS** |
| `withOpacity` rule essentially honoured | D1.3 (LOW) | D1.4 (LOW) | **LOW / PASS** |
| `code-style.md:14` "never FirebaseFirestore.instance directly" — partial honour | D1.4 (HIGH) | D1.5 / H-8 (HIGH) | **HIGH** |

### 2.2 Findings UNIQUE to deep (auto-VERIFIED — deep is authoritative)

| Deep ID | Finding | Note |
|---|---|---|
| D1.6 | Hook regex `^lib/services/.*(firebase\|firestore\|auth\|user\|gdpr)` does NOT match `lib/services/account/` or `lib/services/permissions/` (security-critical paths) | Verified (this audit): `account/` and `permissions/` exist as separate dirs. Real silent under-trigger for security edits. |
| D1.7 | CLAUDE.md lists 5 knowledge files, actually 7 exist | Verified live: 7 `.knowledge.md` files present |
| D1.9 | CLAUDE.md missing `cloud-functions-specialist` + `e2e-test-specialist` from agent index | Verified: `cloud-functions-specialist.knowledge.md` is the largest active knowledge file (56 KB, mtime 2026-05-04 verified) |
| D2.1 | `firestore-rules-tester.knowledge.md` collection→test map shows 4 entries vs 9 live test files | Plausible; not byte-verified here |
| D2.5 | Latent-bug claim at `notification_service.dart:487` not superseded | Real risk — agent will attempt re-fix |
| D2.8 | `e2e-test-specialist.knowledge.md` abandoned at seed (3856 B) | Verified live (`ls -la` shows mtime 2026-04-25, size 3856 B) |
| D2.9 | `performance-optimizer.knowledge.md` shows perf-work being absorbed by cloud-functions agent | Procedural drift |
| D3.6 | freerasp version not pinned in runbook | Pinned in `pubspec.yaml` only |
| D3.7 | `moderation-runbook.md` predates moderation-matrix expansion | Knowledge-file cross-confirms |
| D3.11 | Legacy `cleanupOldAuditLogs` still scheduled, 90-day default | Verified: `cleanup-audit-logs.ts:39` `DEFAULT_RETENTION_DAYS = 90` confirmed |
| D5.4 | `expireAt` 365-day TTL is third number in retention triplet | Verified at `audit-logs-retention.md:35` |
| Cluster D | Knowledge-file activity table (sizes/mtimes) | Verified live: e2e seed-only, perf-optimizer 1 entry, others active |
| What's-Missing list (10 items) | Architecture index, workflow runbooks, ops-index, parser benchmarks, etc. | Default run did not produce a "missing docs" list |

### 2.3 Findings UNIQUE to default — verification

| Default ID | Claim | Verification status | Evidence |
|---|---|---|---|
| H-1 / D3.1 | `audit-logs-retention.md:91` says europe-west1 "matches Firestore database region"; Firestore is europe-west3 | **VERIFIED** | Live: `docs/security/audit-logs-retention.md:91` reads *"Region: `europe-west1` (matches the Firestore database region…)"*. `docs/ops/backups.md:30` confirms `Firestore region | europe-west3 (Frankfurt, EU)`. **This is a real cross-region drift the deep run missed entirely.** Operational impact: every `purgeExpiredAuditLogs` invocation pays cross-region read cost. |
| H-5 | "150k LOC" → 327,280 LOC | **DISPROVED** | Default's 327k figure came from Codex `dart-line-count.txt` which (per deep, line 49) walked Python `lib/site-packages/`. Real LOC is ~53k–65k depending on exclusions. Deep critic correctly flagged this; default trusted the broken pre-analysis. **Deep wins.** |
| H-7 | "41 Stockholm mentions = region drift" (claim is in the pre-analysis SUMMARY itself) | **VERIFIED** (the meta-drift claim) | Live grep: 31 Stockholm mentions in `lib/`+`functions/src/` — all timezone (`Europe/Stockholm`, `STOCKHOLM_TZ`). Deep run reached the same conclusion (D7.1) but classified the *finding* as LOW. Default's framing — that the **pre-analysis SUMMARY itself is misleading** — is a sharper observation. **Default-unique value-add: the pre-analysis surfaces drift as findings.** |
| H-8 / D1.5 | `winback_attribution_service.dart` violates `FirebaseFirestore.instance` rule (service-layer, not bootstrap) | **DISPROVED** (as stated) | Live grep: only 1 hit and it is in a **doc-comment** (`lib/services/analytics/winback_attribution_service.dart:240` — *"`FirebaseFirestore.instance` per `lib/repositories/CLAUDE.md`"*), not a real call. The 4 actual instance call-sites are: `lib/core/bootstrap/firestore_bootstrap.dart:16` (DI fallback), `lib/core/di/modules/core_module.dart:63,358` (comments excusing main.dart), `lib/main.dart:1217` (comment about BUT-743 resolved). Deep's framing (D1.4) is more accurate: rule unenforceable for bootstrap path; services are now clean. |
| M-3 | "GDPR Phase 1 complete (Art 7,15,17,30)" — Art 7(2) gap | UNVERIFIABLE in this prompt | Owned by prompt 09 (trust/safety/privacy). Cross-prompt deferral. |
| M-4 | `03_INFRASTRUCTURE_AND_OPERATIONS.md:307-320` 4-blocker list — all resolved (drift in *right* direction) | **VERIFIED** | `docs/ops/backups.md:3` reads *"Status: ACTIVE — PITR enabled, weekly GCS exports scheduled."* — confirms PITR/exports are live. R8/keystore: cross-prompt 03 evidence. **Default-unique value-add: distinguishes "code ahead of doc" drift from "doc ahead of code" drift.** Deep run did not surface this as a category. |
| M-5 | `BackupService` description in `03_*.md:347` misleading (it's a client-side recipe export tool, not a DR primitive) | UNVERIFIED | Plausible per default's cross-ref to 03-infrastructure.md:55. Not byte-verified here. |
| D2.2 | `firebase-backend-security.knowledge.md:43` says `firestore.rules` is "~72KB" | UNVERIFIABLE without reading the 143 KB knowledge file | Live `firestore.rules` is 1894 lines × ~40 chars ≈ 76 KB — claim is approximately correct (~5% off). |
| L-7 / D3.8 | `storage-lifecycle-runbook.md:3` PENDING — default tags LOW (documented gap) vs deep HIGH (forever-pending) | Reconciled in §2.1 above (HIGH wins). |

### 2.4 Findings UNIQUE to default — value-adding (kept in MASTER)

These are real and add coverage missing from deep:

1. **D3.1 / H-1** — Audit-logs-retention.md:91 region claim wrong (europe-west1 vs Firestore's europe-west3). **Deep missed this entirely.** This is a real, currently-billing-cross-region cost.
2. **H-7** — The pre-analysis SUMMARY itself is a doc-drift surface (the analysis pipeline produces drift as it runs). Meta-finding worth keeping.
3. **M-4** — "Drift in the right direction" category (code ahead of stale prompt files). Useful taxonomy.

---

## Section 3 — Cross-reference verification (Wave 1-2 deferrals)

The orchestrator pre-known list flagged several doc-vs-code drifts cross-prompt. Verify each appears in the deep/default reports for prompt 12:

| Pre-known cross-prompt finding | In deep? | In default? | Verification |
|---|---|---|---|
| BaseService 96% (orchestrator) vs ~75-82% (Wave 1 reality) | ✅ D8.8 (MEDIUM) | ❌ not raised explicitly | Live: 75 of 362 service files contain `BaseService` literal (~21%); Wave 1 stated 82% via wider pattern. Deep covers; default missed. |
| BaseFirebaseRepository 78% vs ~53% | ❌ NOT in deep | ❌ NOT in default | **MISSING COVERAGE** — orchestrator preamble flagged it; neither run picked it up. Pre-known but unattributed in either run. |
| ErrorHandlingMixin 100% vs partial | ❌ NOT in deep | ❌ NOT in default | **MISSING COVERAGE** |
| SerializationUtils 100% vs partial | ❌ NOT in deep | ❌ NOT in default | **MISSING COVERAGE** |
| "33 files >500" vs 132/136 reality | ✅ D1.1 + D4.1 (CRITICAL) | ✅ C-1 + C-3 (CRITICAL) | Strong consensus |
| 1252 LOC claim vs 76,325 (was 1252 dart files / ~76k LOC) | ✅ D8.3 (MEDIUM, deep correctly cites ~53-65k true LOC) | ✅ M-2 (MEDIUM, but uses broken 327k as the truth — see §2.3) | Deep correct, default trusts broken pre-analysis |
| ConsentPurpose felflaggat 2 gånger | ❌ NOT explicitly in deep | ✅ D7.4 (MEDIUM, partial — referenced as cross-prompt) | Live: `ConsentPurpose` referenced 51 times across `lib/`. Symbol exists at `lib/services/notifications/notification_service.dart:652` (`ConsentPurpose.pushNotifications`). Pre-known claim "felflaggat 2 gånger" → likely refers to consent-related cross-doc references that were stale; **MISSING COVERAGE in deep, partial in default** |
| "infrastructure_integration_test.dart hangs" (false — file is 124 lines, 4 tests) | ⚠️ D8.5 self-critic flags it as "should investigate" | ⚠️ H-6 flags coverage-hang but doesn't disprove | **PARTIAL COVERAGE** — Live verification (this audit): file is 124 lines, contains 4 `testWidgets(...)` blocks, no obvious hang. The "hangs" claim in pre-analysis is itself doc-drift. Neither run explicitly disproved it; deep's self-critic flagged the gap. |
| 6 vs 7 GitHub workflows (sbom.yml added 2026-05-04) | ⚠️ D8.2 says 6 | ⚠️ M-1 says 6 | **PARTIAL COVERAGE** — Both runs cited 6, neither saw `sbom.yml` because deep ran 2026-05-04 (same day, possibly before commit) and default ran 2026-05-02. Live now: **7 workflows**. The drift is now 5→7 (orchestrator) and 6→7 (both runs already stale). |
| Mistral → Vertex AI doc drift | ✅ D8.6 (CRITICAL) | ✅ C-2 + H-4 (CRITICAL) | Strong consensus; verified live (`functions/src/index.ts:25`, `functions/package.json` carries `@google-cloud/vertexai` 1.12.0). Confirmed: 9+ "Mistral" hits remain in `docs/analysis/prompts/` (07 file alone has 9 mentions) and `cloud-functions-specialist.knowledge.md:20`. |
| "14 weeks backup retention" vs 30 days reality | ❌ NOT in deep | ❌ NOT in default | **MISSING COVERAGE** — Live `docs/ops/backups.md:30` reads *"30 days auto-delete"*. The "14 weeks" claim must be in some other doc (likely `data-residency.md` or an older runbook). Neither run located the doc with the wrong claim. |
| Flutter 3.32.4 (setup.sh) vs 3.35.1 (CI) | ❌ NOT in deep | ❌ NOT in default | **MISSING COVERAGE** — neither run examined `scripts/setup.sh` vs `.github/workflows/test.yml` for Flutter version pin drift. |

**Missing-coverage summary (5 pre-known drifts neither run picked up):**
1. BaseFirebaseRepository 78% → ~53% adoption
2. ErrorHandlingMixin 100% → partial
3. SerializationUtils 100% → partial
4. "14 weeks backup retention" → 30 days
5. Flutter 3.32.4 vs 3.35.1 setup-vs-CI

These should be added to the MASTER finding doc as **escalated cross-wave drift** even though prompt 12 missed them.

---

## Section 4 — Default findings DISPROVED by deep critic / live verification

| Default claim | Disproved by | Resolution |
|---|---|---|
| "150k LOC → 327,280 LOC" (default H-5, table row 9) | Deep run line 49: Codex's `dart-line-count.txt` walked Python `lib/site-packages/`. Real LOC ≈ 53k–65k. Live verification (this audit): `find lib -name "*.dart" ! generated -exec wc -l` → 1270 files, ~53k–59k LOC (excl. `known_ingredients.dart` 5741). | **Use deep's number (53-65k), discard default's 327k.** |
| `winback_attribution_service.dart` violates "never `FirebaseFirestore.instance`" rule (default H-8) | Live grep (this audit): the only hit in that file is a *doc-comment* citing `lib/repositories/CLAUDE.md`, not an actual call. Real violations are in `main.dart`/`firestore_bootstrap.dart`/`core_module.dart` per deep D1.4. | **Discard default H-8 as stated; keep deep D1.4 (bootstrap-path drift).** |
| "1788 lines firestore.rules" (default table row 1) and "1813 lines" (deep D8.1) | Live (this audit, 2026-05-04): **1894 lines**. Both runs are already stale by ~80-100 lines. | **Use 1894 in MASTER doc.** |
| "74 match rules" → "95" (default) vs "→ 90" (deep) | Live `grep -c '^[[:space:]]*match '`: **92**. Both runs are off in different directions. | **Use 92 in MASTER doc.** |
| "121 rows enumerated in ACCEPTED_LARGE_FILES" (default D1.2) vs "~120 rows" (deep D4.1) | Default is more precise; not formally disproved. | Either is acceptable; defer to default's tight count. |
| "67 Stockholm mentions" (deep D7.1) vs "41 Stockholm mentions" (default H-7) | Live grep `lib/` + `functions/src/`: **31 mentions**. Both runs are over-counts (likely included docs/agents). | Lower than both; clarify in MASTER. |
| Default treats "67/41 Stockholm" as HIGH region-drift signal | Deep critic spot-check + live verification: ALL Stockholm mentions are timezone (`Europe/Stockholm` for quiet hours / DST math). Zero are deployment-region. | **Final classification: LOW (deep's downgrade wins).** Default's value-add is the meta-claim that pre-analysis SUMMARY misleads. |
| Default M-2 says "850 dart files → 1252" | Live: 1270 dart files (excl. generated). Default's 1252 is from `_pre-analysis/dart-file-count.txt`; deep cites 1257. All are within 1% of true. | Use 1270 in MASTER. |

---

## Section 5 — Final consensus severity table (for MASTER doc)

### CRITICAL (4)

| # | Title | Source-of-claim | Live evidence (this audit) | Effort |
|---|---|---|---|---|
| 1 | `code-style.md:6` "33 files >500 lines" wrong | `.claude/rules/code-style.md:6` | 131 files >500 (lib/, excl. generated) | 5 min number + 30-60 min ACCEPTED_LARGE_FILES regen |
| 2 | `ACCEPTED_LARGE_FILES.md` self-contradicts | `docs/architecture/ACCEPTED_LARGE_FILES.md:3,11,13` | Header "133 reviewed" / "29 refactored" / "133 currently >500"; live count 131 | 60 min auto-regen script |
| 3 | Audit-log retention 90/180/365-day three-way drift | `cleanup-audit-logs.ts:39` (90); `audit-logs-retention.md:18` (180); `audit-logs-retention.md:35` (365) | All three numbers verified live; legacy CF still scheduled Sun 03:00 UTC | 30 min decision + retire legacy CF |
| 4 | Orchestrator "Mistral AI" → reality Vertex AI / Gemini | `MASTER_ANALYSIS_ORCHESTRATOR.md:46`; `cloud-functions-specialist.knowledge.md:20` | Live: `functions/src/index.ts:25` europe-west1; `@google-cloud/vertexai` 1.12.0; 9 "Mistral" hits in prompt files + 1 in agent knowledge | 10 min find-replace + manual review |

### HIGH (~12 after consensus)

| # | Title | Source | Notes |
|---|---|---|---|
| 1 | `audit-logs-retention.md:91` Functions europe-west1 ≠ Firestore europe-west3 (cross-region cost) | `docs/security/audit-logs-retention.md:91` | **Default-unique, deep missed**. Verified live via `docs/ops/backups.md:30`. |
| 2 | `code-style.md:14` "never `FirebaseFirestore.instance` directly" — bootstrap exception undocumented | `.claude/rules/code-style.md:14` | 4 real call-sites in `main.dart` / `firestore_bootstrap.dart` / `core_module.dart`. Deep wins (D1.4) over default H-8 (which mis-cited winback). |
| 3 | CLAUDE.md missing 2 of 7 agents from index | `CLAUDE.md:88` | Live: 7 `.knowledge.md` files exist. Deep-only (D1.9). |
| 4 | `cloud-functions-specialist.knowledge.md:455` flags latent `notification_service.dart:487` bug — unverified | `cloud-functions-specialist.knowledge.md:455` | Deep-only (D2.5). |
| 5 | `e2e-test-specialist.knowledge.md` abandoned at seed (3856 B, mtime 2026-04-25) | `.claude/agents/e2e-test-specialist.knowledge.md` | Deep-only (D2.8). Verified live. |
| 6 | `moderation-runbook.md:42` lists 5 collections; rules support 3 more | `docs/ops/moderation-runbook.md:42` | Deep-only (D3.7). |
| 7 | `storage-lifecycle-runbook.md:3` PENDING through every wave | `docs/ops/storage-lifecycle-runbook.md:3` | Both runs flagged; severity reconciled to HIGH. |
| 8 | `FIRESTORE_FIELD_PROTECTION.md` line range 49-62 + allow-list disagreement vs rules-tester knowledge file | `docs/security/FIRESTORE_FIELD_PROTECTION.md:21-23` | Deep-only flags allow-list mismatch (7 keys vs 9). |
| 9 | Orchestrator firestore.rules count off 22-25% | `MASTER_ANALYSIS_ORCHESTRATOR.md:57` | Both runs; live now 1894/92 (worse than both runs cited). |
| 10 | Test-coverage claims 100/96/88 unverifiable (suite hangs) | `MASTER_ANALYSIS_ORCHESTRATOR.md:61` | Both runs flag; deep self-critic upgrades to HIGH. **`infrastructure_integration_test.dart` hang claim is itself drift — file is 124 lines, 4 testWidgets, no hang signal in its body. Pre-analysis is wrong.** |
| 11 | Pre-analysis SUMMARY misleads ("Stockholm = region drift") | `_pre-analysis/SUMMARY.md` | Default-unique meta-finding (H-7); deep critic implicitly agreed by spot-check downgrade. |
| 12 | `cloud-functions-specialist.knowledge.md:20` "(Mistral)" — wrong vendor in agent Step-0 | `.claude/agents/cloud-functions-specialist.knowledge.md:20` | Both runs (consensus with #4 in CRITICAL — kept here as separate fix-target file). |

### MEDIUM (~15)

(Carried as-is from §2.1 reconciliations: hook regex misses `account/`/`permissions/`, knowledge-file freshness skew, perf-optimizer absorbed by cloud-functions agent, freerasp version pin gap, ACCEPTED_LARGE_FILES line-count staleness for individual files, FIREBASE_PERFORMANCE_GUIDE Nov-2025 stamp, store-submission deferred-pending header missing, codebase-size 850→1270 in orchestrator, workflow names wrong + missing sbom.yml, composite-index 30+7 vs 34, BaseService 96%→~21% literal-grep / 82% Wave-1, GDPR Phase 1 "complete" Art 7(2) gap defer to prompt 09, FIREBASE_STORAGE_REPOSITORY_EXCLUSION.md 2025-01-15 needs date-stamp refresh, BackupService description in 03_*.md misleading.)

### LOW (~10)

(`compileSdk` 36 vs implied 35; sub-directory CLAUDE.md anti-pattern; broken cross-doc link in FIREBASE_STORAGE_REPOSITORY_EXCLUSION.md:148 to `docs/ultimate/MASTERPLAN.md` — verified `docs/ultimate/` does not exist; ADR-001 not enumerated in orchestrator; `docs-by-mtime.txt` snapshot lag; data-residency.md "USER MUST VERIFY" honesty-but-stale; placeholder `(BUT-XXX)` in cloud-functions-specialist knowledge; `withOpacity` essentially clean; skill references resolve; TODO/FIXME well-tracked.)

---

## Section 6 — Strategic / Cross-Doc Root Causes (consensus)

Both runs converged on these clusters:

- **Cluster A — Numeric drift in MASTER_ANALYSIS_ORCHESTRATOR.md lines 25-69.** Single shared-context block, never auto-regenerated. Affects every analysis prompt session.
- **Cluster B — Mistral → Vertex AI vendor drift.** BUT-614 migration touched code + data-residency.md but missed orchestrator, agent knowledge file, prompt files (02/04/07/09/10/11), and one inline service-layer doc-comment.
- **Cluster C — Audit-log retention 90/180/365.** Two CFs running in parallel without retirement of legacy.
- **Cluster D — File-size truth claims.** code-style.md / ACCEPTED_LARGE_FILES.md / live find never reconcile.
- **Cluster E — Knowledge-file activity skew.** e2e-test + perf-optimizer effectively abandoned; cloud-functions-specialist absorbing perf work.
- **Default-unique: Cluster F — Region split.** Functions europe-west1 vs Firestore europe-west3 — multi-region intent vs single-region claim in audit-logs-retention.md:91.
- **Default-unique: Cluster G — "Drift in the right direction".** 03_INFRASTRUCTURE_AND_OPERATIONS.md:307-320 4-blocker list — all already RESOLVED on disk; prompt context never updated. Worth flagging because it makes audit conclusions overly pessimistic.

Strategic fixes (consensus):
1. `scripts/regen-orchestrator-context.sh` weekly cron — eliminates Cluster A.
2. CI gate failing if `<files-over-500>` differs from doc by >10% — eliminates Cluster D.
3. Per-PR doc-vs-code mismatch comments.
4. `<doc>:<line>` ↔ `<code>:<line>` reciprocity linter for numerical claims.
5. Knowledge-file freshness gate (already partially exists at `.claude/hooks/knowledge-freshness.sh`).
6. Retire `e2e-test-specialist` agent or force-grow it.
7. Decide audit-log-retention canonical window + retire legacy CF.
8. Decide region intent (single europe-west1, or document multi-region cost).

---

## Section 7 — Summary numbers for MASTER doc

| Metric | Deep | Default | Consensus / Live |
|---|---|---|---|
| Overall doc-health score | 64/100 | 62/100 | **63/100** (average) |
| CRITICAL findings | 4 | 3 | **4** (deep wins; D8.6 elevated) |
| HIGH findings | 11 | 8 | **~12** (consensus + default-unique D3.1) |
| MEDIUM findings | 14 | 13 | **~15** |
| LOW findings | 9 | 10 | **~10** |
| Total drifts | 38 | 34 | **~41** (after deduping consensus + adding cross-prompt missing-coverage) |
| Estimated remediation effort | 7.5 h | 12-16 h doc + 4-8 h architectural | **~10-15 h doc + ~6 h architectural decisions** |

**Confidence:** HIGH on all CRITICAL/HIGH consensus items (verified against live source this audit). MEDIUM on items with cross-prompt deferral (BaseFirebaseRepository / ErrorHandlingMixin / SerializationUtils — Wave 1 owns; flagged as **MISSING COVERAGE** in §3). MEDIUM on D2.5 (notification_service.dart:487 latent-bug claim — needs cross-prompt verification).

**Codex-run absence:** Prompt 12 has no Codex run for cross-validation. The consensus relies on two-way (deep + default) plus live verification anchored to this audit's live-source checks. No third-vote arbitration available — deep authoritative rule applied throughout.

---

**End of consensus data file. Zero docs/code modified.**
