# MASTER — Linear Ticket Dedup vs Forensic Audit

**Date:** 2026-05-06
**Inputs:**
- `docs/analysis/runs/MASTER-SYNTHESIS.md` (27 verified CRITICAL + ~100 HIGH)
- `MASTER-wave1.md` / `wave2.md` / `wave3.md` / `wave4.md` (per-wave findings + IDs)
- Linear backlog snapshot 2026-05-06 (85 issues in `Backlog`, 3 `In Progress`, plus archived/Done re-checked)

**Methodology:** For each verified finding (CRITICAL + HIGH), search backlog by area/title/description. Match types:
- **exact** — existing ticket title + description align with the finding
- **partial** — existing ticket covers part of the finding; needs scope update
- **needs-update** — existing ticket text drifted; reframe vs current source
- **stale-Done** — closed but the master shows the work isn't actually done

Strategic monetization findings tagged "deferred" per MEMORY.md (no submission yet, no monetization decisions yet) are flagged but not pushed into create-now lane.

---

## A. Existing tickets that cover findings (do NOT create new)

| Master finding ID | Existing BUT-NNN | Match-type | Notes |
|---|---|---|---|
| W1 CRIT-CQ1 (cert-pin 8 hosts empty) | **BUT-427** | **stale-Done — see §B** | Marked Done + archived 2026-04-28 but `cert_pin_config.dart:34-71` still has 8 empty fingerprint lists. |
| W1 CRIT-SEC3 (15/18 callables miss App Check) | BUT-760 | partial / In Progress | Covers Android/iOS App Check provider registration. Doesn't enumerate the 15 callables that need `enforceAppCheck: true` — extend scope or add sub-ticket. |
| W1 CRIT-CQ2 (FCMService all-static singleton) | BUT-446 | **stale-Done — see §B** | Done 2026-05-04 covered `FirebaseMessaging.instance` static — but master Pass 2 verified 11 mutable static fields + listener-leak still on disk. |
| W1 CRIT-CQ3 (BaseViewModel ~18% adoption) | BUT-520 | exact (rescoped) | Already rescoped 2026-05-04 to ~30 holdouts. Migration target = top 6 (recipe_list, recipe_form, recipe_detail, unified_shopping, friends, menu) per master Phase 3. |
| W1 CRIT-DEP1 (sqlcipher_flutter_libs EOL) | BUT-554, BUT-435 | partial | BUT-554 is build_runner discontinued (different cascade); BUT-435 is Dart SDK bump that unblocks majors. Neither is sqlcipher→sqlite3. **Add new ticket.** |
| W1 HIGH-DEP1 (build_resolvers + build_runner_core) | BUT-554 | exact | Direct match. |
| W1 HIGH-DEP6 (caret-loose pin posture; pin firebase_app_check + freerasp + http_certificate_pinning) | BUT-578 | partial | BUT-578 is for cli_util/meta only. **Add new ticket.** |
| W1 HIGH-SEC2 (friend_requests→social_requests rename in 6 functions/src refs) | — | none | **New ticket needed.** |
| W1 HIGH-SEC4 (GDPR cross-user cascade audit logging gap) | BUT-455 | partial | BUT-455 is broader BFR audit-chain gap; doesn't enumerate `social_deletion_operations` lines 64/97/156/208/239 + `profile_deletion_operations:65`. Update scope. |
| W1 HIGH-SEC5 (account-deletion `user.delete()` runs before Firestore tier deletes) | — | none | **New ticket needed.** |
| W1 HIGH-SEC6 (synthetic-friendship rule branch CVSS 7.4) | BUT-454 | partial | BUT-454 is MFA, different concern. **Add new ticket.** |
| W1 HIGH-SEC7 (iOS release missing `--obfuscate --split-debug-info`) | BUT-456 | **stale-Done — see §B** | BUT-456 Done 2026-05-04 but master verified `build-validation.yml:229` still runs iOS without obfuscate (Android does). |
| W1 HIGH-CQ1 (View directly calls FirebaseAuth.instance) | — | none | New small ticket; could fold into BUT-510 follow-up class but BUT-510 is Done — needs separate. |
| W1 HIGH-CQ2 (main.dart 35% growth + 5× Firestore.instance) | BUT-506 (Done) + BUT-530 | **stale-Done partial** | BUT-506 closed but `main.dart:172,182,194,195,196` still call Firestore.instance. BUT-530 covers size drift. Re-open/follow-up. |
| W1 HIGH-CQ3 (raw `data['x'] as Type` 7+ models) | — | none | **New ticket needed.** |
| W1 HIGH-CQ7 (View imports concrete Firebase repository) | BUT-504 | partial | BUT-504 is service layer-skipping; this is view-layer. Add scope or new ticket. |
| W1 HIGH-CQ8 (hardcoded `.collection('...')` literals 8 sites) | — | none | **New ticket needed.** |
| W1 HIGH-CQ9 (raw userId in log strings, LogSanitizer not used at 5 sites) | — | none | **New ticket needed.** |
| W1 HIGH-CQ4 (5 user-state-affecting empty `catch (_) {}`) | — | none | **New ticket needed.** |
| W1 HIGH-CQ5 (commented-out `YOUR_BITLY_ACCESS_TOKEN`) | — | none | **New ticket needed (cleanup).** |
| W1 HIGH-CQ6 (recipe_image_manager.dart 1246 lines + 11 fields) | BUT-441, BUT-526 | partial | BUT-441 is mina_recept_view (different file); BUT-526 was for recipe_unified.dart Done. **Add new ticket** for recipe_image_manager. |
| W1 HIGH-CQ10 (6 generic "Ett fel uppstod" l10n keys) | — | none | **New ticket needed (small).** |
| W1 HIGH-DEP2 (Firebase suite uniformly one minor behind) | — | none | Routine via Dependabot. Skip unless blocking. |
| W1 HIGH-DEP4 (Mistral→Vertex docstring drift 8 files) | — | none | Covered by W4 CRIT-DOC3 — **new ticket needed**. |
| W1 HIGH-DEP5 (`dep-audit.yml` no `push: branches: [main]` trigger) | — | none | **New ticket needed (5-min fix).** |
| W1 HIGH-DEP7 (ONNX model SHA-256 verification) | BUT-571 (Done — but different) | none | BUT-571 was lib eval; this is integrity verification. **New ticket needed.** |
| W1 HIGH-DEP8 (37 GitHub Actions all major-tag refs, no SHA pinning) | — | none | **New ticket needed.** |
| W1 HIGH-DEP9 (no `LICENSE`/`NOTICE`/`SECURITY.md`) | — | none | **New ticket needed.** |
| W2 CRIT-INFRA1 (backup region mismatch europe-west1 vs west3 + drill never run) | BUT-452 | partial | BUT-452 is generic operations-runbooks. Master needs concrete: pick region + run drill + update `backups.md` + cron-check. **Update BUT-452 scope or add new ticket.** |
| W2 CRIT-INFRA2 (`--coverage` excludes integration + e2e; coverage claim unverifiable) | BUT-397, BUT-494 (Done) | partial | BUT-397 tightens floor; BUT-494 was related cleanup. Neither extends `--coverage` to integration+e2e jobs. **Update BUT-397 scope or add new ticket.** |
| W2 CRIT-INFRA3 (no `dart_test.yaml` per-test timeout) | — | none | **New ticket needed (30-min fix).** |
| W2 CRIT-PERF1 (ConversationAutoHealerModule 52 listeners/user) | — | none | **New ticket needed.** |
| W2 CRIT-PERF2 (RealtimeSyncService `_cachedResources` unbounded + user_ingredient_repository) | BUT-698 (canceled as duplicate) + BUT-472 | partial | BUT-472 is realtime_session_manager (different file); BUT-698 was duplicate. Neither covers `_cachedResources` LRU wrap. **New ticket needed.** |
| W2 CRIT-PERF3 (FriendsStateManager.dispose leaks `_blockedUsersSubscription`) | BUT-471 (Done) | **stale-Done** | BUT-471 migrated to StreamManagementMixin; master verified the leak is still present (cancel-completeness for `_blockedUsersSubscription` in dispose). Re-verify on disk; if real, re-open or new follow-up ticket. |
| W2 HIGH-INFRA1 (no automated production deploy / store upload) | BUT-420 | exact | Direct match — Fastlane + App Distribution. |
| W2 HIGH-INFRA2 (manual Firebase rules deploy, no CI promotion) | BUT-486 | exact | Direct match. |
| W2 HIGH-INFRA3 (Node 20 in CI vs engines:22) | — | none | Same as W1 CRIT-DEP2 — **new ticket needed.** |
| W2 HIGH-INFRA4 (coverage floor only on Ubuntu shard) | BUT-397 | partial | Update BUT-397 scope: also lift OS-shard gate. |
| W2 HIGH-INFRA5 (architecture-validation TODO threshold warns only) | — | none | **New ticket needed.** |
| W2 HIGH-INFRA6 (lefthook pre-commit ≠ CI checks) | — | none | **New ticket needed.** |
| W2 HIGH-INFRA7 (real-time regression guard skips `test/e2e`) | — | none | **New ticket needed.** |
| W2 HIGH-INFRA8 (single notification channel; no on-call/escalation) | BUT-492 | partial | BUT-492 is cost/budget alerts. **Add new ticket** for second channel + 2-3 alert policies. |
| W2 HIGH-INFRA9 (`dep-audit.yml` no `concurrency:` block) | — | none | **New ticket needed.** |
| W2 HIGH-INFRA11 (lefthook secret-scan regex narrow) | — | none | **New ticket needed.** |
| W2 HIGH-INFRA12 (e2e emulator wait `sleep 10` not retry-loop) | BUT-489 (Done) | **stale-Done?** | BUT-489 marked Done 2026-05-04. Master Wave 2 still flags it via deep+default. Re-verify on disk; if `sleep 10 + curl || echo` is gone, drop. Otherwise re-open. |
| W2 HIGH-INFRA13 (no AAB/IPA/web bundle artifact retention) | — | none | **New ticket needed.** |
| W2 HIGH-INFRA14 (no SLO definitions document) | BUT-452 | partial | Add to BUT-452 scope. |
| W2 HIGH-INFRA15 (actions/checkout v4 vs v6 inconsistency) | — | none | **New ticket needed (30-min fix).** |
| W2 HIGH-INFRA16 (setup.sh / setup.ps1 Flutter 3.32.4 vs CI 3.35.1) | — | none | **New ticket needed (5-min fix).** |
| W2 HIGH-PERF1 (7 raw `Image.network` bypass image cache) | — | none | **New ticket needed.** |
| W2 HIGH-PERF2 (RecipeListViewModel 6 filter Sets + 3 timers, 878 lines, no facade) | BUT-441, BUT-520 | partial | Adjacent but different file. **Add new ticket.** |
| W2 HIGH-PERF3 (anonymous-closure listener leak `UnifiedFriendsService:274`) | — | none | **New ticket needed (1-h fix).** |
| W2 HIGH-PERF4 (`notification_batch` composite index gap) | — | none | **New ticket needed (30-min fix).** |
| W2 HIGH-PERF5 (zero `Isolate.run`/`compute()` in `lib/`) | — | none | **New ticket needed.** |
| W2 HIGH-PERF6 (v1/v2 CF SDK mix `cleanup/on-user-deleted.ts:31`) | — | none | **New ticket needed.** |
| W2 HIGH-PERF7 (13 ViewModels missing dispose) | BUT-520 | partial | Add to BUT-520 scope (it's the same migration set + dispose audit). |
| W2 HIGH-UX1 (clampTextScaling adopted at 2 sites only) | — | none | **New ticket needed.** |
| W2 HIGH-UX2 (touch targets <48dp) | — | none | **New ticket needed (defer; severity dispute).** |
| W2 HIGH-UX3 (39 `EdgeInsets.only((left|right):` not Directional) | — | none | **New ticket needed.** |
| W2 HIGH-UX4 (34 raw `CircularProgressIndicator`) | — | none | **New ticket needed.** |
| W2 HIGH-UX5 (`MediaQuery.viewInsets` adopted at 2 files) | — | none | **New ticket needed.** |
| W2 HIGH-UX6 (settings hub missing locale switcher) | — | none | **New ticket needed.** |
| W2 HIGH-UX7 (desktop branding broken — macOS APP_NAME ×6, Windows lowercase) | BUT-594 | partial | BUT-594 is macOS sandbox entitlements. Different concern. **Add new ticket.** |
| W3 CRIT-AI1 (no closed-loop LLM quality measurement / golden set) | BUT-626 | partial | BUT-626 is bucket A/B for prompts. Master needs golden-set + CI test. **Add new ticket.** |
| W3 CRIT-AI2 (`gemini-2.0-flash` unpinned + no `modelId` in analytics) | — | none | **New ticket needed.** |
| W3 CRIT-TS1 (brigade-amplifier on `reports`) | BUT-659 (Done — different) | none | BUT-659 is account-age cooldown. Different fix. **New ticket needed:** rate limit + enum + self-report block + `reports.contentOwnerId` cascade. |
| W3 CRIT-TS2 (no image moderation on cook_snaps/shared/recipes/feedback) | — | none | **New ticket needed.** Combine with Wave 1 MED-13/14 (storage MIME spoofing + SVG XSS) into one Cloud Storage `onObjectFinalized` trigger. |
| W3 HIGH-AI1 (server-to-server OCR-retry bypasses validators) | — | none | **New ticket needed.** |
| W3 HIGH-AI2 (recipe.title logged in success path) | — | none | **New ticket needed (30-min fix).** |
| W3 HIGH-AI3 (client retry stacks on rate-limit) | — | none | **New ticket needed (30-min fix).** |
| W3 HIGH-AI4 (no adversarial fixtures for jailbreak/prompt-injection) | BUT-694 | partial | BUT-694 is NER-based PII scrubbing — different. **Add new ticket.** |
| W3 HIGH-AI5 (no Vertex prefix caching `cachedContent`) | — | none | **New ticket needed.** |
| W3 HIGH-AI6 (two splitter implementations) | — | none | **New ticket needed.** |
| W3 HIGH-AI7 (Unicode fractions ⅙⅚⅐ missing) | — | none | **New ticket needed (small).** |
| W3 HIGH-AI8 (no prompt-changelog gate in CI) | — | none | **New ticket needed.** |
| W3 HIGH-PA1 (sessionId always null — BUT-588 TODO unshipped) | (BUT-588 was the original ticket) | re-open / new | If BUT-588 is closed-stale, re-open; if doesn't exist anymore, **new ticket.** |
| W3 HIGH-PA2 (win-back conversion only 3 actions) | BUT-686 | partial | BUT-686 is email channel for win-back. Different. **Add new ticket.** |
| W3 HIGH-PA3 (notification effectiveness from 4 incompatible source collections) | — | none | **New ticket needed.** |
| W3 HIGH-PA4 (cooking-mode entirely dark — 3 files emit zero events) | — | none | **New ticket needed.** |
| W3 HIGH-PA5 (`setUserId` never called for FirebaseAnalytics) | — | none | **New ticket needed (30-min fix).** |
| W3 HIGH-PA6 (no `kDebugMode` guard on analytics) | — | none | **New ticket needed (30-min fix).** |
| W3 HIGH-PA7 (`cooksLast14Days` only literal 0) | — | none | **New ticket needed (30-min fix).** |
| W3 HIGH-PA8 (`feature_flag_evaluated` only fires from `isInRollout`) | — | none | **New ticket needed (30-min fix).** |
| W3 HIGH-PA9 (favorite action untracked, no `recipeFavorited` constant) | — | none | **New ticket needed (30-min fix).** |
| W3 HIGH-PA10 (9 dark social-graph methods + DM) | — | none | **New ticket needed.** |
| W3 HIGH-PA11 (`firstCook` milestone event missing) | — | none | **New ticket needed (30-min fix).** |
| W3 HIGH-TS1 (onboarding consent gap) | BUT-465 (Done) | **possible stale-Done** | BUT-465 added re-consent renewal UI; master flagged onboarding-side gap separately. Re-verify; if still real, new ticket. |
| W3 HIGH-TS2 (erasure cascade gap on `reports.contentOwnerId`) | BUT-466 (Done — different) | none | BUT-466 was sharedByDisplayName cleanup; this is reports cascade. Folded into CRIT-TS1 ticket above. |
| W3 HIGH-TS3 (`ContentType` rule-side enum / silent black-hole) | — | none | **New ticket needed.** |
| W3 HIGH-TS4 (reCAPTCHA pre-consent fingerprint; privacy policy false claim) | BUT-721 | partial | BUT-721 is GDPR alignment for nutrition; different surface. **Add new ticket** for reCAPTCHA + Vision API disclosure (also covers W4 HIGH-LEGAL3). |
| W3 HIGH-MON1 (iOS subtitle 31 chars > 30 limit) | BUT-415 | partial | BUT-415 is hosted privacy policy + listing copy. Add scope or sub-task. **Per MEMORY.md "no submission yet" → defer.** |
| W3 HIGH-MON2 (`subscription_tier` analytics frozen `'free'`) | BUT-672 | partial | BUT-672 is conversion funnel events. **Add new ticket** for tier plumb-through in main.dart bootstrap. **Defer per MEMORY.md.** |
| W3 HIGH-MON3 (zero screenshots) | BUT-415 | partial | Defer per MEMORY.md. |
| W3 HIGH-MON4 (OCRUsageTracker monthly counter in-memory) | BUT-682 (Done) | **stale-Done?** | BUT-682 closed Done 2026-05-04 ("in-memory only"). Master Pass 2 says daily IS persisted; only monthly is in-memory. Verify scope completeness; if monthly fix shipped, drop. |
| W3 HIGH-MON5+6+7 (IAP scaffolding, EU 14-day, deletion-sub) | BUT-443, BUT-658, BUT-661, BUT-664, BUT-668 | exact (deferred) | Already 5 tickets in backlog covering RevenueCat scaffolding. **Defer per MEMORY.md.** |
| W4 CRIT-DOC1 (`code-style.md` "33 files" + ACCEPTED_LARGE_FILES self-contradiction) | BUT-550 | partial | BUT-550 is "accepted-large files drifted 19-33%". **Add new ticket** for the doc reconciliation specifically. |
| W4 CRIT-DOC2 (audit-log retention triple-source 365/180/730d drift) | BUT-767 (canceled-duplicate) | none | BUT-767 was about adding the new ledger to the purger — different. **New ticket needed** to reconcile model/service/CF retention values. |
| W4 CRIT-DOC3 (Mistral→Vertex 8 files docstring drift) | — | none | **New ticket needed.** Same as W1 HIGH-DEP4. |
| W4 CRIT-DOC4 (BaseService/BFR/EHM/SerUtils adoption % all wrong) | BUT-567 (Done — partial) | **possible stale-Done** | BUT-567 was BaseService narrative update only. BFR/EHM/SerUtils not addressed. **New ticket needed** to publish `docs/architecture/adoption-status.md`. |
| W4 HIGH-LEGAL1 (audit-log retention triple drift) | covered by CRIT-DOC2 above | — | — |
| W4 HIGH-LEGAL2 (iOS encryption export declaration ITSAppUsesNonExemptEncryption) | — | none | **New ticket needed (5-min Info.plist edit).** |
| W4 HIGH-LEGAL3 (privacy policy "no other data processors" false — reCAPTCHA + Vision) | covered by HIGH-TS4 ticket | — | — |
| W4 HIGH-LEGAL4 (no LICENSE/NOTICE/SECURITY.md at root) | covered by W1 HIGH-DEP9 ticket | — | — |
| W4 HIGH-LEGAL5 (ToS doesn't disclose data-deletion cascade timeline) | — | none | **New ticket needed.** |
| W4 HIGH-LEGAL6 (Mistral→Vertex 8 files) | covered by CRIT-DOC3 ticket | — | — |
| W4 HIGH-LEGAL7 (iOS Privacy Manifest health-data type) | — | none | **New ticket needed (small).** |
| W4 HIGH-LEGAL8 (on-device ONNX model disclosure gap in privacy policy) | — | none | **New ticket needed.** |
| W4 HIGH-LEGAL9 (subprocessor list staleness) | — | none | **New ticket needed (small).** |
| W4 HIGH-LEGAL10 (App Store / Play data-safety form ↔ actual data flows) | BUT-646 | exact (deferred per MEMORY.md) | Direct match — already deferred. |
| W4 HIGH-DOC1 (`audit-logs-retention.md:91` says west1, Firestore is west3) | covered by W2 CRIT-INFRA1 region-decision ticket | — | — |
| W4 HIGH-DOC2/3/6/7 (pre-analysis labeling drift) | — | none | **One audit-tooling-fix ticket** covers all (mtime check + path filters + adoption-status.md). |
| W4 HIGH-DOC8 (`data-residency.md:8` "USER MUST VERIFY" never resolved) | covered by W2 CRIT-INFRA1 ticket | — | — |
| W4 HIGH-DOC9 (`backups.md:31` "Restore drill: NEVER PERFORMED") | covered by W2 CRIT-INFRA1 ticket | — | — |
| W4 HIGH-DOC10 (BUT-588 sessionId fix claim wrong) | covered by HIGH-PA1 ticket | — | — |
| W4 HIGH-DOC11 (Mistral 8 files) | covered by CRIT-DOC3 ticket | — | — |
| W4 HIGH-DOC12 ("14 weeks backup retention" vs 30 days) | covered by W2 CRIT-INFRA1 ticket | — | — |

---

## B. Stale "Done" tickets that need re-open or follow-up

| BUT-NNN | Original work | Master finding | Evidence work isn't done |
|---|---|---|---|
| **BUT-427** | Add SSL cert pinning for 8 hosts | W1 CRIT-CQ1 / CRIT-SEC1 | Closed 2026-04-27, archived 2026-04-28. `lib/services/security/cert_pin_config.dart:34-71` — all 8 host pin lists are `<String>[]` with TODO comments. `pinned_http_client.dart:87-93` falls through to platform trust on empty pins. The wrapper is wired but **inactive**. Master Phase 1 P1.2: populate fingerprints + release-mode assertion. |
| **BUT-446** | FCMService static `FirebaseMessaging.instance` | W1 CRIT-CQ2 | Closed 2026-05-04 covered the messaging-instance constructor injection. Master Pass 2 verified `fcm_service.dart:75-103` still has 11 mutable static fields (`_currentToken`, `_isInitialized`, `_pushPermissionsRequested`, `_consentService`, etc.) + listener-leak (line 129 attaches static method, no removeListener). Original ticket scope was narrower than the structural problem. |
| **BUT-456** | iOS `--obfuscate --split-debug-info` | W1 HIGH-SEC7 | Closed Done 2026-05-04. Master verified `build-validation.yml:229` `flutter build ipa` still runs without `--obfuscate`. Android counterpart at line 194 has it. Ticket appears to have been closed before iOS line was patched (or was patched and reverted). Re-verify on disk. |
| **BUT-471** | Migrate FriendsStateManager to StreamManagementMixin | W2 CRIT-PERF3 | Closed 2026-05-04. Master Wave 2 deep Pass 2 still flags `_blockedUsersSubscription` not canceled in `dispose()` (lines 613-631) while `clearAllData()` cancels it correctly. Re-read on disk: if mixin migration covers this, drop. If asymmetry persists, re-open. |
| **BUT-489** | Gate integration-test on emulator health | W2 HIGH-INFRA12 | Closed 2026-05-04. Master Wave 2 says `test.yml:265-269` still uses `sleep 10 + curl ... \|\| echo`. Re-verify; if fixed, drop the finding. |
| **BUT-506** | main.dart Firestore.instance bootstrap | W1 HIGH-CQ2 | Closed Done 2026-05-04. Master verified 5 Firestore.instance reads still at `main.dart:172,182,194,195,196`. Either wasn't extracted or new sites grew. Re-verify. |
| **BUT-682** | OCRUsageTracker in-memory persistence | W3 HIGH-MON4 | Closed Done 2026-05-04. Master Pass 2 narrowed: daily counter IS persisted via `_persistDaily()` to SharedPreferences; only monthly counter is in-memory (bypass-via-force-quit on monthly cap). If the closed ticket persisted the monthly too, drop. Otherwise add scope. |
| **BUT-465** | Re-consent renewal prompt UI | W3 HIGH-TS1 (onboarding consent) | Closed Done 2026-05-04. Master flags onboarding-side consent gap that's distinct from the renewal prompt. Re-verify the onboarding flow. |
| **BUT-567** | BaseService narrative — 10 legitimate non-adopters | W4 CRIT-DOC4 | Closed Done 2026-05-05 for BaseService only. BaseFirebaseRepository (78%→~53%), ErrorHandlingMixin (100%→partial), SerializationUtils (100%→partial) still have stale claims in orchestrator-prompt baseline + `MASTER_ANALYSIS_ORCHESTRATOR.md`. Add scope or new ticket. |

**Recommended workflow for stale-Dones:** before creating new tickets, do a 5-minute on-disk re-check for each row above. Master findings are dated 2026-05-04/05; some tickets closed after that date (e.g. BUT-446 closed 2026-05-04 before deep Pass 2). For each:
- If on-disk evidence still matches the master finding → **re-open the original ticket** with updated scope (cheaper than parallel new ticket).
- If on-disk evidence shows the work landed → **drop the master finding** (audit was stale-by-hours).
- If partial → **new follow-up ticket** that links back.

---

## C. Findings without existing ticket — proposed new tickets, by Phase

### Phase 1 — Audit tooling + acute security/regulatory fixes (~3 days)

| Master finding ID | Proposed ticket title | Severity | Phase |
|---|---|---|---|
| W1 CRIT-CQ4 | Delete `lib/site-packages/` + add path filter to pre-analysis tooling (audit-integrity) | CRITICAL | 1 |
| W1 CRIT-CQ1 / SEC1 | Populate 8 cert-pin fingerprints + add release-mode assertion in main.dart (re-open BUT-427) | CRITICAL | 1 |
| W1 CRIT-SEC2 | Build `exportAuditLogs` Cloud Function (Admin SDK + uid filter) — fix GDPR Article 15 | CRITICAL | 1 |
| W1 CRIT-SEC3 | Add `enforceAppCheck: true` to 15 unprotected Cloud Function callables (sub-task under BUT-760) | CRITICAL | 1 |
| W1 CRIT-DEP2 / W2 HIGH-INFRA3 | Fix CI Node version mismatch (`dep-audit.yml`/`e2e_tests.yml` 20→22) + lint guard | CRITICAL | 1 |
| W1 HIGH-SEC2 | Rename `friend_requests` → `social_requests` in 6 functions/src refs across 4 files | HIGH | 1 |
| W1 CRIT-SEC1 | Add `realtime_menus/{menuId}/votes/{voteId}` Firestore rule block + rules tests | CRITICAL | 1 |
| W2 CRIT-INFRA1 | Decide canonical region (recommend europe-west1) + run real backup drill + update `backups.md`/`data-residency.md` (extend BUT-452 or new) | CRITICAL | 1 |
| W2 CRIT-INFRA3 | Create `dart_test.yaml` with 30s per-test timeout default | CRITICAL | 1 |
| W2 CRIT-PERF3 | Cancel `_blockedUsersSubscription` in `FriendsStateManager.dispose()` (re-open BUT-471 if needed) | CRITICAL | 1 |
| W4 CC-Wave4-1 | Pre-analysis tooling: mtime freshness check + adoption-status.md migration + path filters | HIGH | 1 |

### Phase 2 — Architectural locks (~7.5 days)

| Master finding ID | Proposed ticket title | Severity | Phase |
|---|---|---|---|
| W1 CRIT-CQ5 | Broaden `architecture_test.dart` (5 Firebase singletons + view→firebase-repo + VM-cloud_firestore + VM/service-extends + .collection-literal ban) | CRITICAL | 2 |
| W2 CRIT-PERF1 | Replace `ConversationAutoHealerModule` per-conversation healers with single `participantUserIds`-array-contains listener (feature-flagged) | CRITICAL | 2 |
| W2 CRIT-PERF2 | LRU-wrap `RealtimeSyncService._cachedResources` + `firebase_user_ingredient_repository._userCache` + eviction telemetry | CRITICAL | 2 |
| W3 CRIT-TS2 + W1 MED-13/14 | Cloud Storage `onObjectFinalized` trigger: magic-byte verify + SafeSearch + format whitelist (combined fix) | CRITICAL | 2 |
| W3 CRIT-TS1 | Tighten `reports` rule (rate limit + reportType enum + self-report block) + add `reports.contentOwnerId` cascade in account deletion | CRITICAL | 2 |

### Phase 3 — Adoption + observability (~11 days)

| Master finding ID | Proposed ticket title | Severity | Phase |
|---|---|---|---|
| W1 CRIT-CQ2 | Refactor `FCMService` static-singleton → instance + DI constructor injection (re-open/follow-up to BUT-446) | CRITICAL | 3 |
| W1 CRIT-CQ3 | Migrate top 6 viewmodels to `BaseViewModel` (extend BUT-520 scope to include dispose audit) | CRITICAL | 3 |
| W1 CRIT-CQ6 | Migrate `displayName`/`avatarUrl` 14 repository write paths to `DisplayIdentityProvider` | CRITICAL | 3 |
| W2 CRIT-INFRA2 | Add `--coverage` to integration + e2e jobs + merge via lcov + recompute orchestrator adoption % | CRITICAL | 3 |
| W3 CRIT-AI1 | Build `test/golden/llm/` corpus + CI golden-test step | CRITICAL | 3 |
| W3 CRIT-AI2 | Pin `gemini-2.0-flash` to versioned alias + record `modelId` + cost telemetry per Vertex call | CRITICAL | 3 |
| W3 HIGH-PA1 | Implement BUT-588 `sessionId` plumb-through across analytics events (re-open if BUT-588 still tracking, else new) | HIGH | 3 |

### Phase 4 — Migrations + dependencies (~7.5 days)

| Master finding ID | Proposed ticket title | Severity | Phase |
|---|---|---|---|
| W1 CRIT-DEP1 | Migrate `sqlcipher_flutter_libs` → `sqlite3 ^3.x` substrate (key-derivation re-test + on-device sanity) | CRITICAL | 4 |
| W1 HIGH-DEP8 | SHA-pin top-blast-radius GitHub Actions (subosito/flutter-action, aquasecurity/trivy, codecov, trufflesecurity) | HIGH | 4 |
| W1 HIGH-DEP5 | Add `push: branches: [main]` trigger to `dep-audit.yml` (5-min fix — counters solo-dev push-to-main blind spot) | HIGH | 4 |
| W1 HIGH-DEP7 | Add SHA-256 verification to `ner_model_manager` + `line_classifier_model_manager` ONNX downloads | HIGH | 4 |
| W1 HIGH-DEP6 | Pin `firebase_app_check`, `freerasp`, `http_certificate_pinning` to exact versions (~1-h fix) | HIGH | 4 |
| W1 HIGH-SEC5 | Move account-deletion entirely server-side (single CF callable, eliminates auth-context race) | HIGH | 4 |
| W1 HIGH-SEC4 | Add audit-log entries to GDPR cross-user cascade ops (`social_deletion_operations`, `profile_deletion_operations`) — extend BUT-455 | HIGH | 4 |
| W1 HIGH-CQ3 | Mass-migrate raw `data['x'] as Type` casts to `SerializationUtils.safeXxx` (sample 7+ models) | HIGH | 4 |
| W1 HIGH-DEP9 | Add `LICENSE`, `NOTICE`, `SECURITY.md` at repo root (also W4 HIGH-LEGAL4) | HIGH | 4 |

### Phase 5 — UX consistency + analytics dark areas (~7 days)

| Master finding ID | Proposed ticket title | Severity | Phase |
|---|---|---|---|
| W2 HIGH-UX4 | Mass-migrate 34 raw `CircularProgressIndicator` → shared `LoadingIndicator` widget | HIGH | 5 |
| W2 HIGH-UX3 | Mass-migrate 39 `EdgeInsets.only((left\|right):` → `EdgeInsetsDirectional.only` | HIGH | 5 |
| W2 HIGH-UX1 | Roll out `clampTextScaling` to all top-level scaffolds | HIGH | 5 |
| W2 HIGH-UX5 | Adopt `MediaQuery.viewInsets` in keyboard-aware scrollables (currently 2 files) | HIGH | 5 |
| W2 HIGH-UX6 | Add locale switcher to settings hub (LocaleProvider already plumbed) | HIGH | 5 |
| W2 HIGH-UX7 | Fix desktop branding (macOS Info.plist `APP_NAME` ×6, Windows main.cpp `L"butlery"` → `L"Butlery"`) | HIGH | 5 |
| W3 HIGH-PA4 | Add cooking-mode analytics events (start, step-advance, complete, abandon) | HIGH | 5 |
| W3 HIGH-PA10 | Wire 9 dark social-graph methods + DM events | HIGH | 5 |
| W3 HIGH-PA5+6 | Add `setUserId` for FirebaseAnalytics + `kDebugMode` guard on emission | HIGH | 5 |
| W3 HIGH-PA7+9+11+8 | Bundle small analytics fixes: cooksLast14Days real value, recipeFavorited, firstCook, feature_flag_evaluated from isEnabled | HIGH | 5 |
| W3 HIGH-PA3 | Notification effectiveness from 4 incompatible source collections — unify | HIGH | 5 |
| W2 HIGH-PERF1 | Replace 7 raw `Image.network` with `CachedNetworkImage` | HIGH | 5 |
| W2 HIGH-PERF3 | Fix anonymous-closure listener leak in `UnifiedFriendsService:274` | HIGH | 5 |
| W2 HIGH-PERF4 | Add `notification_batch` composite index to `firestore.indexes.json` | HIGH | 5 |
| W2 HIGH-PERF5 | `Isolate.run`/`compute()` offload for parser / CRF / OCR hot paths | HIGH | 5 |
| W2 HIGH-PERF6 | Migrate `cleanup/on-user-deleted.ts` v1 → v2 CF SDK | HIGH | 5 |
| W3 HIGH-AI1 | Tighten OCR retry server-side (don't bypass validators) | HIGH | 5 |
| W3 HIGH-AI2 | Stop logging `recipe.title` in success path (privacy) | HIGH | 5 |
| W3 HIGH-AI3 | Client retry-cap (3 attempts max, exponential backoff) on rate-limit | HIGH | 5 |
| W3 HIGH-AI4 | Add adversarial prompt-injection test fixtures | HIGH | 5 |
| W3 HIGH-AI5 | Add Vertex `cachedContent` prefix caching for stable system prompts | HIGH | 5 |
| W3 HIGH-AI6 | Consolidate two compound-splitter implementations | HIGH | 5 |
| W3 HIGH-AI7 | Add Unicode fractions ⅙⅚⅐ to `quantity_parser.dart:55-68` | HIGH | 5 |
| W3 HIGH-AI8 | Add prompt-changelog gate in CI | HIGH | 5 |
| W3 HIGH-TS3 | Fix `ContentType` rule-side enum / silent black-hole on retired wire values | HIGH | 5 |
| W3 HIGH-TS4 + W4 HIGH-LEGAL3 | reCAPTCHA + Vision API privacy-policy disclosure + wait-for-consent before reCAPTCHA activate | HIGH | 5 |
| W2 HIGH-INFRA12 | Replace `sleep 10` emulator wait with retry-loop probe in `test.yml:265-269` (re-open BUT-489 if not done) | HIGH | 5 |

### Phase 6 — Doc + legal cleanup (~5 days)

| Master finding ID | Proposed ticket title | Severity | Phase |
|---|---|---|---|
| W4 CRIT-DOC1 | Update `code-style.md` "33 files" → 131 + auto-update via CI; reconcile `ACCEPTED_LARGE_FILES.md` self-contradiction | CRITICAL | 6 |
| W4 CRIT-DOC2 | Reconcile audit-log retention to single source (CF authoritative; drop `expireAt` from model) | CRITICAL | 6 |
| W4 CRIT-DOC3 / W1 HIGH-DEP4 | Find-replace Mistral→Vertex in 8 code files (`functions/src/index.ts`, `PROMPT_CHANGELOG.md`, etc.) | CRITICAL | 6 |
| W4 CRIT-DOC4 | Publish `docs/architecture/adoption-status.md` with measured BFR/EHM/SerUtils/BaseViewModel %; cite from orchestrator prompts | CRITICAL | 6 |
| W4 HIGH-LEGAL2 | Document iOS encryption export declaration in Info.plist (ITSAppUsesNonExemptEncryption) | HIGH | 6 |
| W4 HIGH-LEGAL5 | ToS data-deletion cascade timeline disclosure | HIGH | 6 |
| W4 HIGH-LEGAL7 | Add iOS Privacy Manifest health-data type | HIGH | 6 |
| W4 HIGH-LEGAL8 | On-device ONNX model disclosure in privacy policy | HIGH | 6 |
| W4 HIGH-LEGAL9 | Privacy review pass — tabulate processors / manifest types / models against current policy | HIGH | 6 |
| W2 HIGH-INFRA16 / W4 HIGH-DOC12 | Update `setup.sh`/`setup.ps1` Flutter version 3.32.4 → 3.35.1 | HIGH | 6 |
| W2 HIGH-INFRA9 | Add `concurrency: cancel-in-progress` block to `dep-audit.yml` | HIGH | 6 |
| W2 HIGH-INFRA8 | Add 2-3 GCP alert policies + secondary notification channel (storage quota / Auth signup spike / Firestore index errors) | HIGH | 6 |
| W2 HIGH-INFRA15 | Standardize `actions/checkout` versions across all workflows (v6) | HIGH | 6 |
| W2 HIGH-INFRA13 | Add artifact retention for AAB / IPA / web bundle | HIGH | 6 |
| W2 HIGH-INFRA11 | Broaden lefthook secret-scan regex (Stripe sk_live_*, Slack webhooks) | HIGH | 6 |
| W2 HIGH-INFRA7 | Real-time regression guard cover `test/e2e` | HIGH | 6 |
| W2 HIGH-INFRA6 | Reconcile lefthook pre-commit and CI checks (analyze flags, real-time guard, Trivy/TruffleHog parity) | HIGH | 6 |
| W2 HIGH-INFRA5 | Architecture-validation TODO threshold should fail, not warn | HIGH | 6 |

### Phase 7 — Pre-monetization (DEFERRED per MEMORY.md "no submission yet" / "no monetization decisions yet")

These map to existing tickets already deferred. **Do NOT pull from backlog into a sprint.**

| Master finding ID | Existing BUT-NNN | Status |
|---|---|---|
| W3 HIGH-MON1 | BUT-415 (sub-task) | Deferred |
| W3 HIGH-MON2 | BUT-672 (extend) | Deferred |
| W3 HIGH-MON3 | BUT-415 | Deferred |
| W3 HIGH-MON5 | BUT-443, BUT-658, BUT-661, BUT-664, BUT-668 | Deferred |
| W3 HIGH-MON6 | (new) EU 14-day cooling-off | Deferred |
| W3 HIGH-MON7 | (new) Account-deletion ↔ subscription interaction | Deferred |
| W4 HIGH-LEGAL10 | BUT-646 | Deferred |

---

## D. Counts

- **Verified finding-set (CRITICAL + HIGH from MASTER-SYNTHESIS):** ~127
  - 27 CRITICAL
  - ~100 HIGH
- **Existing tickets that match (exact + partial):** ~30
- **Stale-Done tickets that need re-verify / re-open:** 9 (BUT-427, 446, 456, 471, 489, 506, 682, 465, 567)
- **Findings deferred per MEMORY.md (Phase 7 monetization/store-submission):** ~10 (already covered by 7 existing deferred tickets)

**True new tickets to create (Phases 1–6, after Step 0 stale-Done re-check):**

| Phase | Approx new tickets |
|---|---|
| Phase 1 (audit tooling + acute) | 11 |
| Phase 2 (architectural locks) | 5 |
| Phase 3 (adoption + observability) | 7 |
| Phase 4 (migrations + deps) | 9 |
| Phase 5 (UX + analytics + AI) | ~25 (many bundle-able into 5-8 grouped tickets — e.g., one "small analytics fixes" ticket for HIGH-PA7+9+11+8) |
| Phase 6 (doc + legal + infra) | ~17 (similar bundling potential; e.g., "audit-tooling fix" covers multiple HIGH-DOCs) |

**Realistic create-now count after sensible bundling: ~45-55 new tickets** (down from 74 raw rows above), spread Phases 1–6.

**Bundling guidance:**
- Group all ~10 "small analytics fixes" (30-min each) into a single ticket → -9 tickets
- Group all 8 "doc-drift small fixes" (find-replace Mistral, code-style.md count, setup.sh version, etc.) into a single ticket → -7 tickets
- Group all 4 small CI infra fixes (concurrency block, checkout v6, push trigger, Node version) into one → -3 tickets
- Group W1 HIGH-CQ4/5/9/10 (small code-quality cleanups) into one → -3 tickets

After bundling: **~30-35 distinct new tickets** to create across Phases 1-6, plus 9 stale-Done re-verifies = ~40 total new actions.

---

## E. Recommended next steps (no Linear writes yet)

1. **Step 0 stale-Done re-check** (≤30 min): cd into the 9 stale-Done file:line citations and verify against current source. Each row in §B either drops to "still done" or becomes a re-open.
2. **Phase 1 batch ticket creation** (only after step 0): create the 11 Phase-1 tickets first, since they unblock everything else (audit tooling especially — it cleans every future audit cycle).
3. **Existing-ticket scope updates**: extend description on BUT-455, BUT-397, BUT-452, BUT-520, BUT-760, BUT-415 to absorb the additional findings noted in §A.
4. **Bundling review**: before creating tickets in Phases 5-6, group the small mechanical fixes per the bundling guidance above.

This dedup-pass file is data-only. No Linear changes have been made.
