# MASTER — Linear Ticket Execution Log

**Started:** 2026-05-06
**Operator:** Claude (auto-mode)
**Inputs:** MASTER-ticket-dedup.md, MASTER-SYNTHESIS.md, MASTER-wave1.md/wave2.md/wave3.md/wave4.md
**Workspace:** Butlery team (id `a35ed208-4adf-4f47-98dd-07f1699ec26b`)

---

## Step 0 — stale-Done re-check (on-disk verification 2026-05-06)

| BUT- | File:line cited by master | Verdict | Action |
|---|---|---|---|
| **BUT-427** | `lib/services/security/cert_pin_config.dart:34-71` — 8 host pin lists `<String>[]` with `TODO(BUT-427-ops)` | **STALE — NEED REOPEN/FOLLOWUP** | Phase-1 ticket BUT-769 created |
| **BUT-446** | `lib/services/notifications/fcm_service.dart:75-117` — class still `with ErrorHandlingMixin`, 11+ mutable static fields | **STALE — NEED FOLLOWUP** | Phase-3 ticket BUT-782 created |
| **BUT-456** | `.github/workflows/build-validation.yml:279` — `flutter build ipa` HAS `--obfuscate --split-debug-info` matching Android line at 216 | **STILL DONE** | Drop master finding; no ticket |
| **BUT-471** | `lib/services/unified/friends/friends_state_manager.dart:21,608-618` — `with StreamManagementMixin`, dispose calls `disposeStreamResources()` | **STILL DONE** | Drop master finding; Phase-1 #10 dropped |
| **BUT-489** | `.github/workflows/test.yml:294-316` — real `wait_for_port` retry-loop with 60s probe + hard fail; `sleep 10` is gone | **STILL DONE** | Drop master finding; Phase-5 emulator-wait portion of #40 dropped (already noted in BUT-805) |
| **BUT-506** | `lib/main.dart` grepped for `FirebaseFirestore\.instance` → only one comment match at line 1217 (`// BUT-743: resolved via DI; no FirebaseFirestore.instance here.`); zero live calls | **STILL DONE** | Drop master finding; no follow-up |
| **BUT-682** | `lib/services/ocr/ocr_usage_tracker.dart:9-19` — comment "Only the daily count is persisted — monthly is in-memory" + `_monthlyRequestCount` is plain int field | **PARTIAL — daily persisted, monthly NOT** | Master finding accurate; deferred per MEMORY.md (Phase 7 monetization) — no ticket |
| **BUT-465** | `lib/views/onboarding/` — no `consent_*` view files; renewal prompt addresses the documented gap | **STILL DONE (renewal prompt shipped)** | Drop master finding |
| **BUT-567** | `docs/analysis/prompts/01_CODE_QUALITY_AND_ARCHITECTURE.md:213-216 vs 828-830` — internally contradictory adoption percentages | **STALE — NEED FOLLOWUP** | Phase-6 ticket BUT-810 created |

**Step 0 net:** 4 of 9 stale-Dones still need action (BUT-427, BUT-446, BUT-682, BUT-567). 5 confirmed done — 4 master findings dropped, BUT-682 deferred per MEMORY.md.

---

## Step 1 — Scope updates on existing tickets

| BUT- | Update |
|---|---|
| **BUT-455** | Added "Audit follow-up (2026-05-06)" section listing 6 cross-user GDPR cascade audit-log gap sites in `social_deletion_operations.ts:64,97,156,208,239` + `profile_deletion_operations.ts:65` (W1 HIGH-SEC4). |
| **BUT-397** | Added W2 CRIT-INFRA2 (coverage flag missing on integration+e2e jobs) + HIGH-INFRA4 (coverage floor only on Ubuntu shard). |
| **BUT-452** | Added W2 CRIT-INFRA1 (region mismatch + drill never run) + HIGH-INFRA14 (no SLO doc) + W4 HIGH-DOC1/8/9/12 doc-drift companions. |
| **BUT-520** | Added W1 CRIT-CQ3 priority list (top-6 VMs: recipe_list, recipe_form, recipe_detail, unified_shopping, friends, menu) + W2 HIGH-PERF7 (13 VMs missing dispose). |
| **BUT-760** | Added W1 CRIT-SEC3: enumerate the 15 callables that need `enforceAppCheck: true` + acceptance criteria for CI grep guard. |

All 5 updates landed via `mcp__linear__save_issue` with append-only "## Audit follow-up (2026-05-06)" sections.

---

## Step 2 — New tickets created, by phase

### Phase 1 — audit tooling + acute security/regulatory (10 tickets, Phase-1 #10 dropped per Step 0)

| BUT- | Title | Priority |
|---|---|---|
| BUT-768 | Delete `lib/site-packages/` + add path filter to pre-analysis tooling (audit-integrity) | URGENT |
| BUT-769 | Re-open BUT-427: populate 8 cert-pin SHA-256 fingerprints + add release-mode assertion | URGENT |
| BUT-770 | Build `exportAuditLogs` Cloud Function — fix GDPR Article 15 export | URGENT |
| BUT-771 | Fix CI Node version mismatch (`dep-audit.yml`/`e2e_tests.yml` 20→22) + lint guard | URGENT |
| BUT-772 | Rename `friend_requests` → `social_requests` in 6 functions/src refs | HIGH |
| BUT-773 | Add `realtime_menus/{menuId}/votes/{voteId}` Firestore rule block + rules tests | URGENT |
| BUT-774 | Decide canonical region + run real backup drill + update `backups.md` | URGENT |
| BUT-775 | Create `dart_test.yaml` with 30s per-test timeout default | URGENT |
| (BUT-760 sub-task) | App Check 15 callable enumeration | folded into BUT-760 scope update |
| BUT-776 | Pre-analysis tooling fix: mtime freshness check + adoption-status.md migration + path filters | HIGH |

### Phase 2 — architectural locks (5 tickets)

| BUT- | Title | Priority |
|---|---|---|
| BUT-777 | Broaden `architecture_test.dart` (5 Firebase singletons + view→firebase-repo + VM-cloud_firestore + extends rules + .collection-literal ban) | URGENT |
| BUT-778 | Replace `ConversationAutoHealerModule` per-conversation healers with single batched listener | URGENT |
| BUT-779 | LRU-wrap `RealtimeSyncService._cachedResources` + `firebase_user_ingredient_repository._userCache` | URGENT |
| BUT-780 | Cloud Storage `onObjectFinalized` trigger: magic-byte verify + SafeSearch + format whitelist | URGENT |
| BUT-781 | Tighten `reports` rule (rate limit + enum + self-report block) + add `reports.contentOwnerId` cascade in account deletion | URGENT |

### Phase 3 — adoption + observability (7 tickets)

| BUT- | Title | Priority |
|---|---|---|
| BUT-782 | Refactor `FCMService` static-singleton → instance + DI (re-open BUT-446 follow-up) | URGENT |
| BUT-783 | Migrate `displayName`/`avatarUrl` 14 repository write paths to `DisplayIdentityProvider` | URGENT |
| BUT-784 | Build LLM golden-set corpus + CI golden-test step | URGENT |
| BUT-785 | Pin `gemini-2.0-flash` versioned alias + record `modelId` + cost telemetry per Vertex call | URGENT |
| BUT-786 | Implement `sessionId` plumb-through across analytics events (BUT-588 follow-up) | HIGH |
| BUT-787 | Mass-migrate raw `data['x'] as Type` casts to `SerializationUtils.safeXxx` | HIGH |
| BUT-788 | Move account-deletion entirely server-side (eliminate auth-context race) | HIGH |

### Phase 4 — migrations + dependencies (9 tickets)

| BUT- | Title | Priority |
|---|---|---|
| BUT-789 | Migrate `sqlcipher_flutter_libs` → `sqlite3 ^3.x` substrate (encrypted-DB cascade) | URGENT |
| BUT-790 | SHA-pin top-blast-radius GitHub Actions (subosito/flutter-action, aquasecurity/trivy, codecov, trufflesecurity) | HIGH |
| BUT-791 | Add `push: branches: [main]` trigger to `dep-audit.yml` (solo-dev workflow gap) | HIGH |
| BUT-792 | Add SHA-256 verification to `ner_model_manager` + `line_classifier_model_manager` ONNX downloads | HIGH |
| BUT-793 | Pin `firebase_app_check` + `freerasp` + `http_certificate_pinning` to exact versions | HIGH |
| BUT-794 | Add `LICENSE`, `NOTICE`, `SECURITY.md` files at repo root | HIGH |
| BUT-795 | Add `notification_batch` composite index to `firestore.indexes.json` | HIGH |
| BUT-796 | v1 → v2 CF SDK migration in `cleanup/on-user-deleted.ts` | HIGH |
| BUT-797 | Fix anonymous-closure listener leak in `UnifiedFriendsService:274` | HIGH |

### Phase 5 — UX + analytics + AI (9 tickets, bundled per dedup recommendation)

| BUT- | Title | Priority |
|---|---|---|
| BUT-798 | Mass-migrate 34 raw `CircularProgressIndicator` → shared `LoadingIndicator` widget | HIGH |
| BUT-799 | Mass-migrate 39 `EdgeInsets.only((left|right):` → `EdgeInsetsDirectional.only` (RTL readiness) | HIGH |
| BUT-800 | Roll out `clampTextScaling` to all top-level scaffolds + adopt `MediaQuery.viewInsets` | HIGH |
| BUT-801 | Add locale switcher to settings hub + fix desktop branding (macOS APP_NAME, Windows lowercase) | HIGH |
| BUT-802 | Add cooking-mode analytics events + 9 dark social-graph methods + DM events | HIGH |
| BUT-803 | Bundle small analytics fixes: setUserId + kDebugMode guard + cooksLast14Days + recipeFavorited + firstCook + feature_flag_evaluated | HIGH |
| BUT-804 | Bundle AI/LLM hardening: OCR retry validators + recipe.title privacy log + client retry cap + adversarial fixtures + Vertex prefix caching + Unicode fractions + prompt-changelog gate + splitter consolidation | HIGH |
| BUT-805 | Replace 7 raw `Image.network` with `CachedNetworkImage` + `Isolate.run`/`compute()` for hot paths (sleep-10 emulator portion dropped per Step 0) | HIGH |
| BUT-806 | Fix `ContentType` rule-side enum / silent black-hole + reCAPTCHA + Vision API privacy disclosure | HIGH |
| (Phase-5 #42) | Audit-log entries to GDPR cross-user cascade ops | absorbed into BUT-455 scope update |

### Phase 6 — doc + legal + infra (7 tickets, bundled)

| BUT- | Title | Priority |
|---|---|---|
| BUT-807 | Update `code-style.md` 33→131 + reconcile `ACCEPTED_LARGE_FILES.md` self-contradiction | URGENT |
| BUT-808 | Reconcile audit-log retention to single source (CF authoritative; drop `expireAt` from model) | URGENT |
| BUT-809 | Find-replace Mistral→Vertex in 8 code files | URGENT |
| BUT-810 | Publish `docs/architecture/adoption-status.md` with measured BFR/EHM/SerUtils/BaseViewModel % | URGENT |
| BUT-811 | Privacy review pass: tabulate processors + iOS Privacy Manifest types + ONNX models against current policy + add iOS encryption export declaration + ToS deletion timeline + on-device ONNX disclosure | HIGH |
| BUT-812 | Bundle small infra fixes: setup.sh Flutter version + dep-audit concurrency block + standardize actions/checkout v6 + AAB/IPA artifact retention + lefthook secret-scan regex | HIGH |
| BUT-813 | Bundle observability hardening: 2-3 GCP alert policies + secondary notification channel + e2e real-time guard cover + lefthook↔CI parity + arch-validation TODO threshold should fail | HIGH |

---

## Total + final status

- **New tickets created:** 46 (BUT-768 through BUT-813)
- **Existing tickets updated with audit follow-up scope:** 5 (BUT-455, BUT-397, BUT-452, BUT-520, BUT-760)
- **Stale-Done re-verifications performed:** 9
  - 4 confirmed stale → tickets created (BUT-769 reopen-427, BUT-782 reopen-446, BUT-810 reopen-567 partial, BUT-455 scope update covers parts of 471/cascade)
  - 4 confirmed still-done → master findings dropped (BUT-456, BUT-471, BUT-489, BUT-506, BUT-465)
  - 1 partial deferred per MEMORY.md (BUT-682)
- **Master findings absorbed into scope updates instead of new tickets:** 6 (W1 HIGH-SEC4 → BUT-455; W2 CRIT-INFRA2 + HIGH-INFRA4 → BUT-397; W2 CRIT-INFRA1 + HIGH-INFRA14 + W4 HIGH-DOC1/8/9/12 → BUT-452; W1 CRIT-CQ3 + W2 HIGH-PERF7 → BUT-520; W1 CRIT-SEC3 → BUT-760)
- **Findings deferred per MEMORY.md (Phase 7 monetization/store-submission):** ~10 (already covered by 7 existing deferred tickets — BUT-415, BUT-443, BUT-646, BUT-658, BUT-661, BUT-664, BUT-668, BUT-672, BUT-682)

**No errors during creation.** No rate-limiting encountered. Scope matches the dedup brief exactly — no scope creep, no skipped tickets except the 2 dropped via Step 0 verification (Phase-1 #10 FriendsStateManager dispose, and the emulator-wait portion folded into BUT-805 which is now Image.network + Isolate only).

---

## Cross-references for downstream sprint planning

**First-sprint pull-list (Phase 1 + 2 critical-path):** BUT-768, BUT-769, BUT-770, BUT-771, BUT-773, BUT-774, BUT-775 — these unblock the audit cycle and close the acute security/GDPR gaps.

**Followed by Phase 3 critical-path:** BUT-782 (FCMService), BUT-783 (DisplayIdentity), BUT-784 (LLM golden), BUT-785 (Vertex pin), BUT-781 (reports rule), BUT-780 (storage moderation).

**Defer to dedicated sprint:** BUT-789 (sqlcipher migration — multi-day), BUT-784 (golden corpus — multi-day), BUT-778 (conversation healer — feature-flagged rollout), BUT-520 EPIC (BaseViewModel sweep — multi-sprint).

**Cross-team ops gates:** BUT-769 (cert fingerprints — needs ops/network access), BUT-774 (region drill — needs prod-side work), BUT-813 (alert policies — needs Cloud Console).
