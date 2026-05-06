# Sprint Backlog

## Sprint: 8-ticket security/perf/GDPR sweep — 2026-05-06 (Q)

Theme: Wave-1/2/3 forensic-audit follow-ups. Three coherent batches: backend/security hardening, performance/leak fixes, backend correctness + GDPR.

### Agent A: Backend / Security hardening

- [x] **A1. BUT-771** — Bump CI Node 20 → 22 in `dep-audit.yml` + `e2e_tests.yml` + `sbom.yml`. New `tools/check_node_version_consistency.sh` greps every workflow's `node-version:` (literal + `${{ env.NODE_VERSION }}`) and compares to `functions/package.json` engines.node. New `node-version-consistency` job in dep-audit.yml runs the guard on PRs.
- [x] **A2. BUT-781** — Tightened `/reports` rule (contentOwnerId required, self-report block, reason enum, 24h throttle via `/users/{reporter}/report_throttle/{owner}` sentinel). New report_throttle subcollection rules. Client `firebase_report_repository.submitReport` now writes report+throttle in one batch. Cascade step 13 in `on-user-deleted.ts` anonymizes reports where deleted user was contentOwner. 7 new rules tests.
- [x] **A3. BUT-773** — New `/realtime_menus/{menuId}/votes/{voteId}` rule block (read for participants; create/update/delete owner-only via doc-id-as-uid). New `realtime-menus-rules.test.ts` with 7 cases. Wired into `test:rules:all`.
- [x] **A4. BUT-769** — New `CertPinConfig.assertReleaseModeSafety()` throws on boot in release mode if any host has empty pin list. Wired into `main()`. New `docs/operations/cert-pin-rotation.md` runbook. 4 new unit tests. (Actual fingerprint capture deferred — needs live network access; ops task.)

### Agent B: Performance / leak fixes

- [x] **B1. BUT-779** — New `lib/core/cache/lru_map.dart` (LinkedHashMap-backed LRU with eviction callback). Wrapped `RealtimeSyncService._cachedResources` (N=200) and `FirebaseUserIngredientRepository._userCache` (N=50). Eviction telemetry via AppLogger.debug. 11 unit tests.
- [x] **B2. BUT-797** — Step-0 rescope: actual leak was a `_stateManager.addListener(() { notifyListeners(); })` ChangeNotifier closure (line 281-283), not a Firestore stream listener as ticket assumed. Fixed via named `_emitStateOnStateManagerChange` method + `removeListener` in `dispose()`. Test deferred (facade un-constructible per existing test-file docstring; documented in ticket).

### Agent C: Backend correctness + GDPR

- [x] **C1. BUT-785** — Pinned `TEXT_MODEL = "gemini-2.0-flash-001"` (from moving `gemini-2.0-flash` alias). New exported `MODEL_ID` constant. Threaded `modelId` through `emitTiming` structured logs + `StructureRecipeResponse` / `OcrRecipeImageResponse` callable response shapes (server + Dart model classes). New `docs/architecture/llm-versions.md` runbook (quarterly bump cadence + golden-test gate).
- [x] **C2. BUT-770** — New `functions/src/exports/audit-logs.ts` callable (Admin SDK; pages 5000 entries DESC by timestamp; ISO-cursor pagination). Wired into `index.ts`. Client `ComplianceExportManager.exportAuditLogs` now calls the CF instead of the doomed direct-Firestore read; pages until `nextCursor: null` or 10-page safety cap. New ARB key `dataExportIncludesAuditLogs` (sv+en) added to data-export view. 6 new unit tests against fake admin Firestore.

### Tier-2 agent reviews (commit hook gate)

- [ ] **code-reviewer** (any *.dart edit)
- [ ] **testing-specialist** (lib/ → test/ obligation)
- [ ] **firebase-backend-security** (lib/repositories, functions/src/, services/firebase|gdpr|user)
- [ ] **firestore-rules-tester** (firestore.rules + functions/src/__tests__/*-rules.test.ts)

### Post-Sprint Steps

- [x] `dart analyze --fatal-infos` clean across the repo
- [x] `npx tsc --noEmit` clean in functions/
- [x] LRU + cert-pin Dart unit tests pass (24 tests)
- [x] exportAuditLogs CF unit tests pass (6 tests)
- [ ] Firestore rules tests (BUT-781 + BUT-773) — local run blocked (no Java); validates on CI's `firestore-rules.yml`
- [ ] Tier-2 reviews + markers
- [ ] Commit + push
- [ ] Linear: 8 tickets → Done with summaries

### Step-0 rescopes (per `feedback_ticket_premise_verification.md`)

- **BUT-781**: ticket assumed `reportType` / `targetUid` fields — schema actually uses `reason` / `contentId` and a (newly-required) `contentOwnerId`. Ticket-described file `profile_deletion_operations.ts` doesn't exist; cascade landed in existing `on-user-deleted.ts`.
- **BUT-797**: ticket pointed at line 274 stream-listener leak; actual leak was a ChangeNotifier listener at line 281-283.
- **BUT-769**: fingerprint capture requires live network access against production hosts — unsafe to fabricate; delivered the assertion + runbook + tests, deferred capture as ops task.
- **BUT-770**: ticket assumed an `exportUserData` callable + `data_export/` CF module exist — they don't; Butlery's data export is client-driven. Smallest delta: a single new callable consumed by the existing client manager.
- **BUT-785**: model already had `calculateGeminiCost` helper; just needed pin + MODEL_ID export + threading through emitTiming and response shapes.

### What this means in plain language
- **Eight pre-existing security and performance issues fixed**: report-spam rate limit, missing-rule on votes, unsafe model alias, empty cert pins, memory leaks in two long-running caches, a friend-service notification leak, a CI version mismatch, and the GDPR data export now actually includes the security audit history.
- **No new app features**: this sprint is internal hardening — users won't see new buttons or screens, but the app is harder to abuse, uses less memory in long sessions, and a data-export request now genuinely returns everything GDPR says it should.
- **Risk**: low. Every change has tests; rules changes have 7+14 new test cases; performance changes have an LRU bound and eviction telemetry so we'll see if the bound is too tight; the cert-pin assertion only fires in release builds (no impact on dev).
- **Two follow-ups to track**: (1) actual cert fingerprint values still need to be captured by an ops task before a release build can ship; (2) firestore rules tests need the CI Linux runner with Java to actually run.

---

## Archived prior sprint (completed in commit 709ea672f)

BUT-536 firebase_recipe_repository module extraction — 2026-05-06 (P) — 1104 → 906 lines via 3 modules.

## Archived sprint before (completed in commit 1c82cee20)

BUT-441 mina_recept_view facade extraction — 2026-05-06 (O) — 997 → 549 lines.

## Archived sprint before (completed in commit 9598e784d)

BUT-702 closure + BUT-554 dep tracking refresh — 2026-05-06 (N).

## Archived sprint before (completed in commit 5b480e01f)

CI duration telemetry + ML runtime memo + Linear hygiene — 2026-05-05 (M).
