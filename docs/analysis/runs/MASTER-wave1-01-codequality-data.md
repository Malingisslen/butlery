# MASTER Wave 1 — Prompt 01 Code Quality Consensus Data

**Purpose:** Consensus inventory across three forensic runs (codex / claude-default / claude-deep) for Prompt 01 (Code Quality & Architecture). Source of truth for the synthesis master document.

**Auth baseline (verified pre-build):**
- Real hand-written Dart LOC: **76 325 LOC / 1 257 files** (excluding `lib/site-packages/`). The `327 280` headline in codex+default reports is wrong (4× inflated by Pillow/pip side-load).
- `ConsentPurpose` analyzer error at `lib/services/notifications/notification_service.dart:648` is **RESOLVED on disk** — Pass 2 of deep verified import chain resolves cleanly. Codex flagged this as CRITICAL incorrectly; default flagged it as "verify, may be stale."
- Deep's Pass 2 critic re-grepped its own findings against live source; deep is the authoritative baseline except where codex/default has a unique finding.

**Run inputs:**
- `docs/analysis/runs/2026-05-codex/01-code-quality.md` — 386 lines (Codex GPT-5)
- `docs/analysis/runs/2026-05-claude/01-code-quality.md` — 401 lines (Claude default)
- `docs/analysis/runs/2026-05-claude-deep/01-code-quality.md` — 895 lines (Claude deep + Pass 2 critic)

---

## Score consensus

| Run | Overall score | Architecture | File Size | Dedup/Infra | Error Handling | Doc Health | Readability | Prod Readiness | Tech Debt |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Codex | **63/100** | 11/20 | 8/15 | 9/15 | 10/15 | 7/10 | 6/10 | 8/10 | 4/5 |
| Claude default | **71/100** | 15/20 | 8/15 | 12/15 | 11/15 | 7/10 | 8/10 | 7/10 | 3/5 |
| Claude deep | **56/100** | 10/20 | 9/15 | 7/15 | 9/15 | 5/10 | 7/10 | 5/10 | 4/5 |

**Score spread:** 56 → 71 (15-point range). Deep's lowest score reflects:
- Promotion of architecture-test brittleness (CRIT-5) and `displayName` denormalization (CRIT-6) to CRITICAL.
- Deep's Pass 2 found broader scopes (24+ denormalization sites vs default's "not flagged" and codex's "1-2 file pattern"; 25 services not extending BaseService vs codex's 6 sample, default's 16).
- Deep counted CRIT-2 (FCMService static-singleton) and CRIT-1 (cert-pin disabled) as CRITICAL; codex/default rated cert-pin as MEDIUM/HIGH only.

**Dimension where all three diverge most:** Architecture Compliance (10 / 11 / 15 — 5-point spread). Default rated highest because it didn't enumerate the full scope of viewmodel-base-class non-adoption.

**Dimension where all three converge:** File Size & Complexity (8 / 8 / 9 — within 1 point). All confirm 132 files >500 lines, 4-6 files >1000 lines, accepted-large-files registry inconsistency.

**Issue count comparison:**

| Severity | Codex | Default | Deep | Notes |
|---|---:|---:|---:|---|
| CRITICAL | 1 | 2 | 6 | Codex's 1 is the disproved ConsentPurpose. Default's C-1 = same disproved item, C-2 = test-infra hang (deferred to prompt 03). Deep's 6 are all live + verified. |
| HIGH | 8 | 8 | 15 | Deep merged Pass-1B addendum + Pass-2 additions. |
| MEDIUM | 13 | 11 | 17 | |
| LOW | 11 | 7 | 7 | |

---

## CRITICAL findings (consensus matrix + verification status)

| ID | Title | Codex | Default | Deep | Verification |
|---|---|---|---|---|---|
| CRIT-A | TLS cert-pin wired but deactivated for 8 hosts (`cert_pin_config.dart:34-71`, `pinned_http_client.dart:87-93`) | MEDIUM only (Tech Debt #1) | HIGH H-9 (defer to prompt 02) | **CRIT-1** | Deep authoritative. Codex/default downgraded; deep promoted because every outbound HTTPS request is unprotected. **VERIFIED in deep Pass 2** (read both files line-by-line). |
| CRIT-B | `FCMService` is all-static singleton with 11 mutable static fields (`fcm_service.dart:75-103`, leaks listeners on hot reload) | Not flagged distinctly | Not flagged | **CRIT-2** | **Unique to deep**; **VERIFIED** by my live read of `fcm_service.dart:75-84` (confirmed: `class FCMService with ErrorHandlingMixin`, lines 77-78 private constructor + static `_errorHandler`, line 80 `static final FirebaseMessaging _messaging`, lines 81-84 four more statics confirmed). |
| CRIT-C | `BaseViewModel` adoption ~13-14 of ~62-76 viewmodels (~18%, vs documented 100% rule) | Not flagged | Not flagged | **CRIT-3** | **Unique to deep**; **VERIFIED** by deep Pass 2 (counted 14 BaseViewModel + 62 ChangeNotifier in re-grep; Pass-2 critic re-grepped to 13/61 ≈ 18%). Number shifts between passes — true ratio is "~18% adoption." |
| CRIT-D | `lib/site-packages/` ships 29 MB Python pip-install; inflates LOC count 4× | Not noticed (LOC reported as 327k accurately) | Not noticed (LOC reported as 327k accurately) | **CRIT-4** | **Unique to deep**; **VERIFIED** in deep Pass 2 (Glob confirmed Pillow + pip on disk; `.gitignore` covers it but it's on dev disks). Cascading audit-integrity finding: codex+default both took 327k as truth. |
| CRIT-E | `architecture_test.dart:65-115` is structurally too narrow (only checks `FirebaseFirestore.instance`; uses substring `path.contains('repository')` exclusions) | Indirectly flagged as MEDIUM "Architecture guardrails are narrow" | Not flagged | **CRIT-5** | Codex MED-3 in Dim 1 captured the same gap at lower severity. Deep promoted to CRITICAL because it's the *meta-gate* — every other arch finding is regression-vulnerable until this is broadened. **VERIFIED** in deep Pass 2 (read full file). |
| CRIT-F | `displayName`/`avatarUrl` denormalization at 24-25 sites reads from auth profile, not UserService (12 files; 14 are write-paths into Firestore) | HIGH-3 (Data source discipline risk; flagged 2 sites: `recipe_sharing_manager.dart:533-534`, `realtime_menu_service.dart:53-54`) | Not flagged | **CRIT-6** | **Codex flagged narrowly (2 files); deep verified at 24+ sites across 12 files via Pass-2 grep.** Codex's evidence is correct but understates scope by 12×. **VERIFIED** by deep Pass 2 grep `currentUser\?\.(displayName|avatarUrl|photoURL)` returning 25 unique lines. |

**Disproved CRITICAL (originally claimed by codex):**

| ID | Original claim | Disproof |
|---|---|---|
| codex-CRIT-1 | "Build-breaking analyzer error: `ConsentPurpose` undefined at `notification_service.dart:648`" | **DISPROVED.** Deep Pass 2 verified `notification_service.dart:16` imports `models/account/user_consent.dart`, file declares `enum ConsentPurpose` at `user_consent.dart:90`, line 649 reference resolves cleanly. Default's C-1 also flagged this as "verify before declaring real" with mtime evidence (analyze captured 19:48, file modified 19:51). User confirms RESOLVED on disk. Should be downgraded to LOW or dropped entirely from master synthesis. |

---

## HIGH findings (consensus matrix + verification)

### Three-way consensus (all three runs flagged)

| ID | Title | Codex | Default | Deep | Verification |
|---|---|---|---|---|---|
| HIGH-A | View layer reaches into Firebase / repository concrete types directly | HIGH-1 (`shared_content_actions.dart:15,16,433,475`; `feed_tab.dart:14,346,347`; `public_profile_viewmodel.dart:6,7,27,36`) | H-1 (`onboarding_age_gate_blocked_view.dart:22` — `FirebaseAuth.instance.currentUser?.delete()`) + M-3 (`feed_tab.dart:14`, `shared_content_actions.dart`) | HIGH-1 (`onboarding_age_gate_blocked_view.dart:22`) + HIGH-13 (`shared_content_actions.dart:15,16` — concrete Firebase repos) | **VERIFIED:** I confirmed `shared_content_actions.dart:15-16` imports concrete Firebase repos; `feed_tab.dart:14` imports interface; `public_profile_viewmodel.dart:6-7` imports interfaces (lesser sin); `onboarding_age_gate_blocked_view.dart:22` has direct FirebaseAuth call. All four cluster sites are real. Deep's split (HIGH-1 view→FirebaseAuth + HIGH-13 view→concrete-repo) is most precise; codex collapsed them; default split into different buckets. |
| HIGH-B | ViewModel imports SDK types directly (`menu_storage.dart:3` — `package:cloud_firestore/cloud_firestore.dart`) | HIGH-2 (called "ViewModel-side storage performs direct Firestore persistence logic") | H-2 (called "ViewModel imports cloud_firestore directly") | Mentioned under MED-12 (file is `@Deprecated`) and architecturally referenced under CRIT-5 missing test | **VERIFIED:** I confirmed `menu_storage.dart:3` imports cloud_firestore. File now has `@Deprecated` annotation per deep MED-12. |
| HIGH-C | File size sprawl: 132 files >500 lines, 4-6 files >1000 lines | HIGH-1, HIGH-2 in Dim 2 | H-4 (ACCEPTED_LARGE_FILES.md inconsistency 33 vs 132 vs 133), H-5 (files near/over 1000) | MED-17 (7-day growth velocity table) | All three confirm 132 actual files >500 lines; deep adds growth-velocity table. |

### Two-way consensus (codex+default OR codex+deep OR default+deep)

| ID | Title | Codex | Default | Deep | Verification |
|---|---|---|---|---|---|
| HIGH-D | BaseService adoption is well below documented 96%; 16-25 services don't extend it | HIGH-1 in Dim 3 (lists 6 holdouts: `auth_service`, `user_service`, `realtime_menu_service`, `unified_recipe_service`, `unified_menu_service`, `unified_shopping_service`) | H-6 (says 72/88 = 82%, lists "16 holdouts") | Methodology table lists 25 holdouts | **Codex+default+deep three-way consensus**; numbers refined progressively (codex sample 6 → default 16 → deep 25). Deep most authoritative. |
| HIGH-E | BaseFirebaseRepository adoption ~33-35 of ~45-62 (~53-78%); holdouts use direct Firebase patterns | HIGH-2 in Dim 3 (lists `parsing_correction_repository`, `collaborative_recipe_repository`, `site_config_repository`, `firebase_category_preferences_repository`, `firebase_menu_lexicon_repository`, `firebase_ingredient_repository`) | aligned in metrics table (35/45 = 78%) | HIGH-8 (33 extends + 29 implements-only = ~53%; lists `firebase_search_repository`, `firebase_menu_lexicon_repository`, `firebase_audit_repository`, `firebase_consent_repository`, `site_config_repository`, `firestore_repository`, `parsing_correction_repository`, `collaborative_recipe_repository`, `firebase_connectivity_repository`) | **VERIFIED at multiple sites** in deep Pass 2. Codex+deep have larger holdout lists; default just cites the metric. |
| HIGH-F | `main.dart` reaches `FirebaseFirestore.instance` 4-5 times for bootstrap settings | MED-2 in Dim 1 (lists `main.dart` indirectly via `content_module.dart:434`, `main.dart:172`) | M-3 / H-3 (lines 172, 182, 194-196) | HIGH-2 (lines 172, 182, 194, 195, 196) + MED-16 (main.dart grew 35% in 7 days, 954→1288 lines) | **VERIFIED**, three-way consensus. Deep adds growth-velocity finding. |
| HIGH-G | Unawaited async notification send in cook-snap flow (`cook_snap_service.dart:222`) | HIGH-1 in Dim 4 | Not flagged (default's L-3 mentions empty catches in cook_snap_service generally) | Not flagged | **DISPROVED — STALE.** I read live `cook_snap_service.dart:215-234`: line 222 is now wrapped in `try { ... } catch (e) { AppLogger.warning('Failed to send cook snap notification: $e'); }` (lines 220-233). The unawaited concern is moot — there IS a try/catch with logging. Codex's evidence is from a previous state. Should be DROPPED from master. |
| HIGH-H | Empty/silent catches in user-state-affecting paths (5-11 occurrences) | MED-1, MED-2 in Dim 4 (`recipe_list_viewmodel.dart:841,844,848,856`, `llm_tier.dart:338,340`, `recipe_sharing_manager.dart:178,185`, `cook_snap_service.dart:115,125`) | L-3 (11 across 7 files) | HIGH-5 (Pass-2 re-grepped: 11 sites, 5 of which are user-facing state failures with zero logging) | Three-way consensus. Deep's HIGH-5 is most actionable (separates 5 user-facing from 6 acceptable JS-interop / parser fallback). |
| HIGH-I | Hardcoded Firestore collection literals despite `FirestoreCollections` constants existing | MED-1 in Dim 6 (`unified_menu_service.dart:210`, `report_service.dart:91`, `firebase_menu_voting_repository.dart:25,42`) | Not flagged distinctly | HIGH-14 (`firebase_data_export_repository.dart:504`, `firebase_menu_voting_repository.dart:25,42`, `report_service.dart:91`, `onboarding_progress_service.dart:95,97`, `resource_parser_module.dart:23`, `main.dart:183`) | Codex+deep two-way; deep's site list is broader. **VERIFIED** at multiple sites. |
| HIGH-J | Raw userId in log strings (PII risk) despite `LogSanitizer` existing | MED-1 in Dim 7 (`firebase_block_repository.dart:59,61`, `firebase_notifications_repository.dart:107,400`, `notification_service.dart:531`) | Not flagged | HIGH-15 (`firebase_block_repository.dart:147`, `firebase_notifications_repository.dart:107,382,400`) | Codex+deep two-way; **VERIFIED** at `firebase_block_repository.dart:59` (logs `targetId` user ID inside catch — codex's line cite is correct). Note: codex cited line 59, deep cited line 147 — both are real but different sites. |
| HIGH-K | EOL/discontinued packages in dependency graph | HIGH-2 in Dim 7 | Not flagged (default treats as L-7) | Not flagged (deferred to prompt 05) | Codex unique HIGH; deferred to prompt 05 per orchestrator. |
| HIGH-L | Dependency advisory feed integrity (`pub-outdated.txt` decode failures) | HIGH-1 in Dim 7 | Not flagged | Not flagged | Codex unique. UNVERIFIABLE here without re-running pub outdated; defer to prompt 05. |
| HIGH-M | SerializationUtils adoption partial — raw `data['x'] as Type` casts widespread despite the helper existing | MED-1 in Dim 3 (`site_config.dart:183,184,197,201`, `shared_shopping_list.dart:119,121,122,125`) | Not flagged | HIGH-3 + HIGH-4 (sampled 7+ models incl `notification_batch.dart:28-44`, `realtime_resource.dart:348-379`, `realtime_menu_factory.dart:81,102,104`, `recipe_serialization.dart:52-258`, `recipe_unified.dart:917-919` null-safety hole) | Codex+deep two-way; deep is broader. **VERIFIED:** I read `site_config.dart:180-202` — confirmed mixed pattern (uses `SerializationUtils.safeBool/safeInt` selectively, raw `data['x']?.toString()` for ~10 fields). Deep's broader sample stands. |
| HIGH-N | View files import services directly at high volume (62 occurrences across 30 files) | Not flagged | M-2 | Not flagged | **Default unique HIGH/MEDIUM**; the count is plausible but not deeply verified by deep. UNVERIFIED — would need targeted grep to confirm 62. |
| HIGH-O | Generic "Ett fel uppstod" error string at 6 localization keys | Not flagged | Not flagged | HIGH-11 (`app_localizations_sv.dart:712, 830, 1128, 2355, 10538, 11018` + `message_states.dart:47`) | **Unique to deep**; verified by deep Pass 2 grep. |
| HIGH-P | Architecture-test gap is the meta-cause | MED-3 in Dim 1 (Architecture guardrails are narrow and can pass despite layer bypasses) | Not flagged | CRIT-5 (top-level CRITICAL) | Codex+deep two-way at different severities. Deep's promotion correct. |
| HIGH-Q | Commented-out external-integration code with credential placeholders (`deep_link_service.dart:339-356` bit.ly with `'YOUR_BITLY_ACCESS_TOKEN'`) | LOW-1 in Dim 5 (`deep_link_service.dart:344, 353, 354, 355`) | Not flagged | HIGH-6 (`deep_link_service.dart:339-356`, `recipe_social_stats.dart:392-400`, `social_recipe_coordinator.dart:116`, `social_recipe_sharing_service.dart:233`) | Codex+deep two-way; codex rated LOW, deep rated HIGH because of credential-placeholder forensic risk. Deep's framing more accurate. |
| HIGH-R | `recipe_image_manager.dart` (1246 lines, 11 fields, 3 race-condition guards) extends `ChangeNotifier` not `BaseViewModel` | Mentioned indirectly via Dim 2 hotspot list | M-4 in growers table (1,246 vs accepted 1,343) | HIGH-7 (full diagnosis) | Codex+default+deep three-way overlap; deep is most diagnostic. |
| HIGH-S | `BaseViewModel.printDebugState` is a no-op false-comfort API | Not flagged | Not flagged | HIGH-9 (`base_viewmodel.dart:268-271`) | **Unique to deep**; deep noted itself it's "5-min deletion, kept HIGH for the false-comfort API category." |
| HIGH-T | `base_viewmodel.dart` doc-comment style violates "WHY not WHAT" | Not flagged | Not flagged | HIGH-10 | **Unique to deep**; deep self-acknowledged "could be MEDIUM, kept HIGH because tone-setting." |

### Codex-unique HIGH findings (verification)

| Codex finding | Verification |
|---|---|
| HIGH-1 in Dim 1: `public_profile_viewmodel.dart` ViewModel-layer repository bypass | **VERIFIED** — `public_profile_viewmodel.dart:6-7` imports `interfaces/user_repository.dart` and `interfaces/recipe_repository.dart`; lines 27 and 36 use `ServiceLocator.get<RecipeRepository>()` directly. (VM does extend BaseViewModel — correct on that axis — but bypasses to repo interface from VM, skipping a service layer.) |

### Default-unique HIGH findings (verification)

| Default finding | Verification |
|---|---|
| H-3: 29 files with direct `FirebaseFirestore`/`FirebaseAuth.instance` (vs documented 17). Wrong locations include `lib/services/notifications/fcm_service.dart`, `notification_service.dart`, `analytics/winback_attribution_service.dart`. | Partially **VERIFIED** — deep CRIT-2 confirms `fcm_service.dart:80` `FirebaseMessaging.instance` (slightly different SDK but same class of issue). I verified `fcm_service.dart:75-84` shows static fields. The "29 files" count is UNVERIFIED here without rerunning full grep, but the pattern is real. |
| H-7: `main.dart` grew 954 → 1,250 (+31%) without doc update | **VERIFIED** by deep MED-16 with refined number 954 → 1288 (+35% per deep's live wc -l). Default's "1,250" is slightly off; deep's "1288" is current. |
| H-8: BaseService adoption is 82% (72/88), not 96% as documented | Default's number 72/88; deep refined to "76 extends + 25 holdouts = ~75%." Different denominators (default counts 88 services, deep counts ~101). Both refute the 96% doc claim. **VERIFIED** in spirit (gap is real); exact percentage is unverified-disputed. |

---

## MEDIUM findings (short consensus list)

**Three-way (all runs flagged):**
- Empty catch blocks (covered above as HIGH-H by deep)
- TODO/FIXME concentration in cert-pin (`cert_pin_config.dart:39-69`) — codex MED-1/L-2 in Dim 5+8, default M-9, deep references in CRIT-1
- Section-divider comments / non-English comments — codex MED-1 + MED-2 in Dim 5, default not flagged distinctly, deep MED-8 (downgraded to "false alarm in Pass 2")
- `personal_tag_service.dart` god-class — codex (not flagged), default (not flagged), deep MED-6 (**RESOLVED ON DISK** per Pass 2 — file is now 359 lines)

**Codex-unique MEDIUM:**
- MED-1 Dim 1: Direct service instantiation in `chat_action_handler.dart:35-38` — **VERIFIED** by my live read: lines 34-38 do `_messagingService = ServiceLocator.get<MessagingService>()` and `_mediaService = MessagingMediaService(messagingService: ServiceLocator.get(), authRepository: ServiceLocator.get())` (latter is direct constructor of MessagingMediaService inside the action handler — codex's claim is real).
- MED-3 Dim 1: Architecture guardrails are narrow (covered as HIGH-P / deep CRIT-5 above)
- MED-1 Dim 3: SerializationUtils partial adoption (covered as HIGH-M)
- MED-1 Dim 4: Silent catches in `recipe_list_viewmodel.dart:841,844,848,856` — overlaps with deep HIGH-5
- MED-2 Dim 4: Empty catch blocks (overlaps with HIGH-H)
- MED-3 Dim 4: Testing infrastructure hang (deferred to prompt 03)
- MED-1 Dim 5: Section-divider comments
- MED-2 Dim 5: Non-English comments in `form_fields_manager.dart:99,100`, `user_service.dart:357,362`, etc.
- MED-1 Dim 6: Hardcoded Firestore collection names (covered as HIGH-I)
- MED-2 Dim 6: Mixed-language naming (overlap with codex MED-2 Dim 5)
- MED-1 Dim 7: Raw user IDs in logs (covered as HIGH-J)

**Default-unique MEDIUM:**
- M-1: Notification subsystem 6 sibling managers — high coupling. Deep mentions related issue under CRIT-2 / MED-15.
- M-2: View files import services directly (62 occurrences) — UNVERIFIED count.
- M-5: `Future.delayed` "garbage collection" pauses in test infra (`test_service_locator.dart:153`, `firestore_singleton.dart:264`) — Deferred to prompt 03.
- M-6: `FakeFirebaseFirestore` singleton operation cap triggers unannounced resets (`firestore_singleton.dart:18-19, 38-44`) — Deferred to prompt 03.
- M-7: Manual mutex `_consentHandlerInProgress` in notification_service — overlaps with deep MED-15.
- M-8: `notification_service._handleConsentChange` swallows errors silently (`notification_service.dart:643-663`) — overlaps with deep MED-14.
- M-10: `FeedTab` namespace-class pattern (`feed_tab.dart:18` static-only class).
- M-11: `main.dart` calls `FirebaseFirestore.instance.terminate()`/`clearPersistence()` — overlaps with HIGH-F.

**Deep-unique MEDIUM:**
- MED-1: `realtime_menu_viewmodel.setState` false-positive grep
- MED-2: `executeAsync` rethrows vs `executeAsyncVoid` swallows-and-returns-bool divergence
- MED-3: `application_provider.dart` import path inconsistency
- MED-4: Web JS-interop silent catches (`pwa_install_service_web.dart:44, 56, 64`)
- MED-5: IndexedDB recovery uses string `.contains` matching (`main.dart:188-200`)
- MED-7: `AsyncOperationMixin.executeWithRetry` under-adopted (only `smart_import_viewmodel.dart:89` confirmed user)
- MED-9: `RecipeListViewModel` 6 filter Sets + 3 debounce timers, no facade (878 lines)
- MED-10: `RealtimeMenuState.menuSnapshot` returns `{}` if null — ambiguous contract
- MED-11: One ungated `debugPrint` (`recipe_scraper.dart:161`) — overlaps with default L-6
- MED-12: 19 `@Deprecated` APIs across 14 files
- MED-13: `web_scraper.dart` 11+ `Future.delayed` ad-hoc retries despite `RetryPolicy`/`CircuitBreaker` existing (only 5 callers use `CircuitBreaker`)
- MED-14: `notification_service.dart:641-663` swallows consent errors silently
- MED-15: Manual mutex pattern race-prone under FFI/JS
- MED-16: `main.dart` 35% growth in 7 days (954 → 1288) (overlaps with HIGH-F)
- MED-17: 7-day growth velocity table (5 undocumented >700-line files)
- NEW-MED-18 (Pass 2): `services/CLAUDE.md` `ServiceLocator.get` rule conflicts with testability
- NEW-MED-19 (Pass 2): Tests under `test/unit/services/` healthy on "mock dependencies, not subject" axis (POSITIVE finding)
- NEW-MED-20 (Pass 2): `late final` cached deps under-used
- NEW-MED-21 (Pass 2): `notification_service` reads consent on every send (cost discipline)
- NEW-CRIT-7 → also has perf-test framing (covered above as HIGH for testability/perf)

---

## Disproved by deep critic (with original-claim + counter-evidence)

| ID | Original claim | Source | Disproof | Master action |
|---|---|---|---|---|
| 1 | `flutter analyze` reports "Undefined name 'ConsentPurpose'" at `notification_service.dart:648` — CRITICAL build break | Codex CRITICAL #1 (Dim 4); Default C-1 (uncertain) | Deep Pass 2 verified import chain resolves cleanly: `notification_service.dart:16` imports `models/account/user_consent.dart`; that file declares `enum ConsentPurpose { ... pushNotifications ... }` at line 90; reference at line 649 resolves. The mtime mismatch (analyze captured 19:48, file modified 19:51) explains it — pre-analysis snapshot was pre-edit. **STALE, not real.** | DROP from master, or list as "stale finding — pre-analysis artifact issue" with severity LOW. |
| 2 | LOC count is 327,280 across 1,252 hand-written files | Codex baseline (line 5); Default Codebase Scale table; both used as headline | Deep Pass 2 verified `lib/site-packages/` contains 29 MB of Pillow + pip; real Dart LOC excluding that is ~76 325 across ~1 257 files. **Inflated 4×.** | CORRECT in master to 76 325 LOC. Note audit-integrity finding (CRIT-D) explicitly. |
| 3 | "BaseService adoption 96% (~67/~70)" (orchestrator-prompt baseline propagated by codex+default) | Both runs cite this without challenging | Deep Pass 2 found 25 services that do NOT extend BaseService → ~75% true adoption. | Use deep's number; flag the orchestrator prompt baseline as stale (→ prompt 12). |
| 4 | "BaseFirebaseRepository adoption 78% (35/45)" (orchestrator-prompt baseline) | Codex + default cite this | Deep Pass 2: 33 `extends BaseFirebaseRepository` + ~29 implements-only = ~53%. Deep's denominator is wider. | Use deep's number; flag orchestrator baseline. |
| 5 | "ErrorHandlingMixin: 100% adopted" (orchestrator claim) | Cited as orthodoxy | Deep Pass 2: many viewmodels and 25+ services use raw try/catch with `catch (_) {}`. Not 100%. | Flag stale (→ prompt 12). |
| 6 | "SerializationUtils: 100% adopted" (orchestrator claim) | Cited as orthodoxy | Deep Pass 2: 7+ models still use raw `as Map<String, dynamic>` casts; 30+ models still use `data['x'] as Type` inline. | Flag stale (→ prompt 12). |
| 7 | `personal_tag_service.dart` god-class still pending | Implied by orchestrator's "Known violations" list | Deep MED-6: file is now 359 lines — refactor happened. **REMEDIATED.** | Update orchestrator prompt; remove from known violations. |
| 8 | "setState in ViewModels: 2 known" (orchestrator claim) | Codex Gold Standard table flags as unclear migration | Deep MED-1: `realtime_menu_viewmodel.dart:135` calls `_state.resetState()` — false-positive grep. Default also flagged this as 0 effective. | Confirm 0 setState in VMs. |
| 9 | Codex HIGH (Dim 4) "Unawaited async notification send in cook-snap flow" at `cook_snap_service.dart:222` | Codex HIGH | I verified live: lines 220-233 wrap the call in `try { ... } catch (e) { AppLogger.warning(...); }` (line 230-233). The error path is handled with logging. The "unawaited" concern is moot in current source. **STALE.** | DROP from master HIGH list. |

---

## Unique to one run (verified status)

### Unique to codex (verified)

| Finding | Verification |
|---|---|
| HIGH-1 in Dim 1: `public_profile_viewmodel.dart` repository import bypass (lines 6-7, 27, 36) | **VERIFIED.** `public_profile_viewmodel.dart` extends `BaseViewModel` (good) but imports two repository interfaces and resolves them via `ServiceLocator.get<RecipeRepository>()` at line 36. Real architectural smell — VM should orchestrate via service layer, not call repos. |
| MED-1 Dim 1: `chat_action_handler.dart:35-38` direct service instantiation | **VERIFIED.** Lines 30-38: constructor uses `ServiceLocator.get<MessagingService>()` (acceptable per CLAUDE.md services rule) but ALSO does `MessagingMediaService(messagingService: ..., authRepository: ...)` — direct constructor of a service in a view-helper class. Real smell. |
| HIGH-1, HIGH-2 in Dim 7: pub-outdated decode failures + EOL/discontinued packages | **UNVERIFIABLE here** — would need to re-run `flutter pub outdated`. Defer to prompt 05. |
| MED-1 Dim 5: section-divider comments at `feed_tab.dart:359`, `parsing_correction.dart:31,45,62` | UNVERIFIED but plausible; low-impact style debt. |
| MED-2 Dim 5: non-English comments at `form_fields_manager.dart:99,100`, `user_service.dart:357,362`, `recipe_image_manager.dart:293`, `importera_fran_arkiv_view.dart:165` | UNVERIFIED but plausible; low-impact (Swedish UI conventions per CLAUDE.local.md may make this controversial). |

### Unique to default (verified status)

| Finding | Verification |
|---|---|
| C-2: Test infrastructure hang in `infrastructure_integration_test.dart` — `TestServiceLocator.reset()` `_getIt.reset(dispose: true)` chain stalls on un-cancelled stream subscriptions | **DEFERRED to prompt 03** per orchestrator. Default's root-cause analysis is the deepest. |
| H-7: `main.dart` 31% growth in 7 days | Verified by deep with refined number (35%, 1288 lines). |
| H-8: BaseService 82% (72/88), not 96% | Refined by deep (75%, ~25 holdouts). Real. |
| M-1: Notification subsystem 6 sibling managers (`notification_service.dart:18-23` imports 6) | UNVERIFIED count but plausible architecturally. |
| M-2: 62 service-imports across 30 view files | UNVERIFIED count. |
| M-5, M-6: Test infrastructure smells (`test_service_locator.dart:153`, `firestore_singleton.dart:18-19, 38-44`, 264) | DEFERRED to prompt 03. |
| M-7: Manual mutex `_consentHandlerInProgress` (`notification_service.dart:641`) | Overlaps with deep MED-15; deep adds CRIT-2's `_consentChangeInProgress` for FCMService. Real. |
| M-10: `FeedTab` is a namespace-class with static-only `build()` (`feed_tab.dart:18`) | **VERIFIED** by my read of `feed_tab.dart:18-22` — `class FeedTab { static Widget build(BuildContext, ActivityFeedViewModel) { ... } }`. Real smell. |
| L-6: One `debugPrint(` in `recipe_scraper.dart:1` | Refined by deep MED-11 to line 161. **VERIFIED** in spirit. |

### Unique to deep (already verified by Pass 2 critic)

All deep CRITICAL findings are unique to deep (CRIT-1 to CRIT-6) and were verified by deep's own Pass 2 critic against live source. CRIT-2, CRIT-4, CRIT-5, CRIT-6 are the highest-leverage findings of the entire wave.

Deep-unique HIGH (HIGH-7, HIGH-9, HIGH-10, HIGH-11, NEW-CRIT-7/HIGH-16, NEW-HIGH-17) are all verified by deep Pass 2.

---

## Disputed numbers / severities

### Disputed numerical claims

| Metric | Codex | Default | Deep | Authoritative |
|---|---|---|---|---|
| Hand-written Dart LOC | 327 280 | 327 280 | 77 243 (Pass 1) → 65 543 (Pass 2 incl l10n) → ~38 374 excluding l10n+generated (Pass 2) | **76 325 LOC / 1 257 files (user-verified baseline)**. The 327k is wrong (codex+default). Deep's number bracket is right; pick the user's authoritative figure. |
| Hand-written Dart files | 1 252 | 1 252 | 1 265 (deep Pass 1) / 1 265 (Pass 2) | **1 257** (user-verified). Within ±1% across runs (rounding/inclusion differences). |
| Files >500 lines | 131 | 132 | 132 | All within ±1; doc-claim of 33 is wrong. |
| Files >1000 lines | 6 | 4 | 4-6 (mixed) | Disputed: codex says 6, default says 4 (`recipe_image_manager`, `recipe_unified`, `main`, `known_ingredients`), deep doesn't enumerate cleanly. Likely codex includes 2 borderline files >995 (`unified_recipe_service.dart:995`, `personal_recipe_module.dart:1023`). **Pick 4 confirmed + 2 borderline = 5-6 depending on inclusion.** |
| BaseService adoption % | not given numerically | 82% (72/88) | ~75% (76/101 incl 25 holdouts) | Deep's wider denominator most authoritative; both refute documented 96%. |
| BaseFirebaseRepository adoption % | 78% (orchestrator) | 78% (orchestrator) | ~53% (33 extends + 29 implements-only) | Deep's number reflects wider denominator. |
| BaseViewModel adoption | not flagged | 0% setState (tangential) | 14/76 → 13/61 ≈ 18% (deep across 2 passes) | Deep authoritative; codex+default missed this entirely. |
| Direct Firebase singleton usage outside repo layer | ≥6 files | 29 files | sites enumerated but not totaled; 5 in main.dart + ~6 service-tier offenders | Default's 29 includes `lib/repositories/` itself (legitimate); deep's "5-6 illegitimate" is most precise. |
| TODO/FIXME count | 14 | 23 | 25-50 | Deep authoritative (codex's 14 is the orchestrator's baseline claim, not a recount). |
| `displayName`/`avatarUrl` denormalization sites | 2 sites in 2 files | not flagged | 24-25 sites in 12 files (14 are write-paths) | Deep authoritative (verified in Pass 2 grep). |
| Empty `catch (_) {}` count | 6+ examples (no total) | 11 across 7 files | 11 (Pass-2 re-grepped, 5 are user-state-affecting) | Default+deep agree on 11; deep is most diagnostic. |
| `@Deprecated` annotations | not counted | not counted | 19 across 14 files (Pass-2 corrected from 20) | Deep unique. |
| `unawaited(` usage | not counted | not counted | 25 across 17 files (positive note) | Deep unique. |

### Disputed severities

| Finding | Codex severity | Default severity | Deep severity | Recommended master severity |
|---|---|---|---|---|
| `ConsentPurpose` analyzer error | CRITICAL | CRITICAL (uncertain) | LOW (stale, disproved) | **DROP / LOW** |
| TLS cert-pin disabled | MEDIUM | HIGH (defer to prompt 02) | CRITICAL | **CRITICAL** (per deep) |
| Architecture-test brittleness | MEDIUM | not flagged | CRITICAL | **CRITICAL** (per deep — meta-gate) |
| `displayName`/`avatarUrl` denormalization | HIGH (narrow scope) | not flagged | CRITICAL (broader scope) | **CRITICAL** (per deep — verified at 24-25 sites) |
| `FCMService` static-singleton | not flagged | implied via H-3 | CRITICAL | **CRITICAL** (per deep) |
| `BaseViewModel` under-adoption | not flagged | not flagged | CRITICAL | **CRITICAL** (per deep) |
| `lib/site-packages/` audit-integrity | not flagged | not flagged | CRITICAL | **CRITICAL** (per deep) |
| Cook-snap unawaited notification | HIGH | not flagged | not flagged | **DROP** (stale per my live read of `cook_snap_service.dart:215-234`) |
| `deep_link_service.dart` commented credentials | LOW | not flagged | HIGH | **HIGH** (per deep — credential placeholder forensic risk) |
| EOL packages | HIGH | not flagged | not flagged | **DEFER to prompt 05** |
| File-size sprawl | HIGH | HIGH | MEDIUM (under MED-17 because deep treats as "growth velocity, not absolute count") | **HIGH** (consensus tilt) |

### Disputed adoption percentages — summary

The orchestrator-prompt baseline (`docs/analysis/prompts/01_CODE_QUALITY_AND_ARCHITECTURE.md`) cites:
- BaseService 96% — **all three runs refute** (real: ~75-82%).
- BaseFirebaseRepository 78% — **deep refutes with wider denominator** (real: ~53-78% depending on whether implements-only counts).
- ErrorHandlingMixin 100% — **deep refutes** (many empty catches).
- SerializationUtils 100% — **codex+deep refute** (raw casts widespread).
- BaseViewModel adoption — **only deep measured** (real: ~18%).

These are doc-drift findings → ownership belongs to **prompt 12** (documentation health).

---

## Summary stats

- **Real CRITICALs after dedup + verification:** 6 (all from deep, all verified). Codex+default's 1-2 CRITICALs are either disproved or deferred.
- **Real HIGHs after dedup + verification:** ~17 unique (after collapsing two-way overlaps). Of those, 2-3 are disproved/stale (codex's cook-snap unawaited; possibly default's "62 service imports" count without verification) and 4-5 are deferred to other prompts (test infra → 03; deps → 05; doc drift → 12).
- **Three-way consensus findings:** 6-8 (file size sprawl, view→repo bypass, ViewModel SDK type leakage, BaseService non-adoption, BaseFirebaseRepository non-adoption, empty catches, main.dart Firebase bootstrap, hardcoded collection literals, raw userId logging, recipe_image_manager size).
- **Verified-by-me-here unique findings:** codex's `public_profile_viewmodel.dart`, `chat_action_handler.dart`, `menu_storage.dart:3`, `feed_tab.dart:14`, `shared_content_actions.dart:15-16`, `firebase_block_repository.dart:59`, `fcm_service.dart:75-84`, `site_config.dart:180-202`, `cook_snap_service.dart:215-234` (latter disproves codex HIGH).

**Recommended master synthesis stance:** Use deep as authoritative baseline. Treat codex+default findings as additive only where they (a) name unique sites deep didn't enumerate, or (b) provide deeper analysis on a shared finding. Drop codex's `ConsentPurpose` CRITICAL and `cook-snap unawaited` HIGH outright.
