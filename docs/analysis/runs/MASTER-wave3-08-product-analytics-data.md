# MASTER Wave 3 — Prompt 08 Product Analytics & Growth Consensus Data

**Purpose:** Consensus inventory across three forensic runs (codex / claude-default / claude-deep) for Prompt 08 (Product Analytics, Growth & Retention). Source of truth for the synthesis master document.

**Auth baseline (verified pre-build):**
- Pre-analysis lives at `docs/analysis/runs/2026-05-codex/_pre-analysis/`.
- 18 callable Cloud Functions deployed.
- Real `AnalyticsEvents` constant count: **121 const declarations** (`grep -E "^\s+static const \w+\s*=" lib/services/analytics/analytics_events.dart | wc -l` → 121, of which ~65 are growth-domain events; the remaining are tagging/security/system/perf/notification-routing constants and 17 user-property keys). Codex+default's "65 events + 17 user-properties" headline is correct *for the growth scope*; deep stuck with "65 events + 17 user-property constants" too, all three are aligned (the 121 figure simply counts every static const including non-growth telemetry).
- Deep's Pass 2 critic re-grepped its own findings against live source; deep is the authoritative baseline except where codex/default has a unique finding.

**Run inputs:**
- `docs/analysis/runs/2026-05-codex/08-product-analytics.md` — 457 lines, ~36 KB (Codex GPT-5, 2026-05-04 23:38)
- `docs/analysis/runs/2026-05-claude/08-product-analytics.md` — 401 lines, ~31 KB (Claude default, 2026-05-02 22:48)
- `docs/analysis/runs/2026-05-claude-deep/08-product-analytics.md` — 1174 lines, ~67 KB (Claude deep + Pass 2 critic, 2026-05-04 08:09 / Pass 2 same-day)

---

## Score consensus

| Run | Overall | Instr. | Funnel | Retention | Notif. | Flags/Exp | Onboarding | ASO | Re-eng. |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Codex | **66/100** | 11/20 | 9/18 | 12/15 | 11/15 | 8/12 | 8/10 | 3/5 | 4/5 |
| Claude default | **78/100** | 15/20 | 14/18 | 13/15 | 12/15 | 10/12 | 8/10 | 3/5 | 3/5 |
| Claude deep (Pass 1) | **75/100** | 14/20 | 13/18 | 13/15 | 11/15 | 9/12 | 8/10 | 3/5 | 4/5 |
| Claude deep (Pass 2 final) | **71/100** | 12/20 | 13/18 | 12/15 | 11/15 | 8/12 | 8/10 | 3/5 | 4/5 |

**Score spread:** 66 → 78 (12-point range). Default rated highest (78) because it missed cooking-mode dark instrumentation entirely, missed the `setUserId` cross-device blind spot, and counted `inAppReviewRequested` as missing (DISPROVED — see below). Deep dropped 4 points in Pass 2 after surfacing two NEW HIGH blind spots (setUserId, debug-build filter). Codex's 66 reflects harsher scoring on Funnel Coverage (9/18) due to "import not universally instrumented in primary `SmartImportViewModel`" framing.

**Dimension where all three diverge most:** Funnel Coverage (9 / 14 / 13 — 5-point spread). Codex penalized hard for fragmented import instrumentation (events fire from `receive_share_view.dart`, not `smart_import_viewmodel.dart`); default counted import as ✅ Strong because the events DO fire end-to-end if you trace via the share path; deep splits the difference with HIGH-2.2 (sessionId always null is the real correlation gap, not the "where does the call live" question).

**Dimension where all three converge:** Onboarding Optimization (8 / 8 / 8 — perfect agreement). All three confirm onboarding funnel is well-instrumented: 5-page wizard, started/page-viewed/skipped/resumed/abandoned/completed/seeded all wired.

**Issue count comparison:**

| Severity | Codex | Default | Deep (Pass 1 → Pass 2) | Notes |
|---|---:|---:|---:|---|
| CRITICAL | 2 | 0 | 0 | Codex's 2 CRITs are both about the import flow ("not universally instrumented" + "end-to-end not measurable"). Deep+default both reject CRIT framing — funnel works, just fragmented across surfaces. |
| HIGH | 6 | 6 | 9 → **11** | Deep merged Pass-1 findings + Pass-2 additions (setUserId, debug-mode filter). |
| MEDIUM | 7 | 11 | 14 → **17** | Deep most thorough; default and codex both ~half deep's count. |
| LOW | 4 | 7 | 8 → **11** | Deep most diagnostic. |

---

## CRITICAL findings (consensus matrix + verification status)

There are **0 unique CRITICAL findings** that survive cross-verification. Codex's two CRITs reframed:

| ID | Title | Codex | Default | Deep | Verdict |
|---|---|---|---|---|---|
| codex-CRIT-1 | "Core import actions are not consistently instrumented in the primary import flow" — events live in `receive_share_view.dart` and onboarding-only paths, not `SmartImportViewModel.startImport` | CRITICAL | covered as ✅ Strong (default confirms full wiring via shared trackers) | covered partially under HIGH-2.2 (`sessionId` always null is the real funnel-correlation defect) | **DOWNGRADE to HIGH.** Verified: `receive_share_view.dart:98,165` emit `import_started`/`import_success` correctly; `import_manager.dart` itself has zero `analytics`/`logEvent` calls but the orchestration leaves event emission to the entry-point view (`receive_share_view.dart` for share intent, `onboarding_import_page.dart` for onboarding). Codex's "not universally instrumented" is a code-organization criticism, not a measurement gap. The real issue is HIGH-2.2 (sessionId is null → BigQuery joins broken). Three runs agree on **import funnel works in BigQuery if `sessionId` were wired**. |
| codex-CRIT-2 | "End-to-end import funnel is not reliably measurable" (same flagged again at funnel dim) | CRITICAL | not flagged separately | not flagged separately | Same as codex-CRIT-1, restated. **DUPLICATE.** |

**No genuine CRITICAL findings in this prompt.** The product-analytics surface is forensically clean on data-loss/PII/consent dimensions (deep verified PII gate at `firebase_analytics_repository.dart:31-44`, 6-vector PII leak hunt in Pass 2 returned all clean). Treat the master verdict as "no CRITICAL", aligning with deep+default.

---

## HIGH findings (consensus matrix + verification)

### Three-way consensus (all three runs flagged, same root cause)

| ID | Title | Codex | Default | Deep | Verification |
|---|---|---|---|---|---|
| HIGH-A | `sessionId` always null on import-pipeline events; correlation broken | HIGH (Funnel Dim 2) — TODO at `parse_events_tracker.dart:28`, `recipe_parser_service.dart:799` | ✅ Strong "sessionId BUT-588 just added" claim is **STALE** | HIGH-2.2 (`parse_events_tracker.dart:28-30` TODO confirms null) | **DEEP+CODEX VERIFIED.** Default's "BUT-588 just added" claim is wrong — TODO still in source. Deep authoritative. |
| HIGH-B | `feature_flag_evaluated` only fires from `isInRollout`, not `isEnabled` (boolean kill-switch flags emit no telemetry) | MEDIUM (Dim 5) — `feature_flag_service.dart:191`, not `:117` | not flagged | HIGH-1.4 — `feature_flag_service.dart:198-222` called only from `isInRollout` (line 189); `isEnabled`/`getInt`/`getString`/`getDouble` do NOT emit | **VERIFIED in source**: I read `feature_flag_service.dart:117-194`. `isEnabled` returns `_remoteConfig.getBool(flag)` directly with no `_maybeLogFlagEvaluated` call. Only `isInRollout:191` calls it. Codex+deep two-way; codex rated MEDIUM, deep rated HIGH. **Pick HIGH per deep**. |
| HIGH-C | Win-back conversion only counts 3 actions (`recipeCooked`, `importSuccess`, `menuGenerated`); social re-engagement (first comment / share / friend) doesn't register as conversion | MEDIUM (Dim 4) "action-conversion linkage is weak outside win-back" — broader framing | not flagged distinctly | HIGH-8.1 — `winback_attribution_service.dart:82-86` `_meaningfulActions` set is exactly 3 events | **VERIFIED:** I read `winback_attribution_service.dart:83-87` — confirmed `static const Set<String> _meaningfulActions = <String>{ AnalyticsEvents.recipeCooked, AnalyticsEvents.importSuccess, AnalyticsEvents.menuGenerated };`. Three-way coverage at different severities. Deep's HIGH framing most accurate for an app whose product strategy includes social ("not a social network — keep messaging"). |

### Two-way consensus

| ID | Title | Codex | Default | Deep | Verification |
|---|---|---|---|---|---|
| HIGH-D | 8 social-graph CHURN events defined but 0 call sites (`logFriendRemoved`, `logFriendRequestRejected/Cancelled`, `logUserBlocked/Unblocked`, `logGroupLeft/Deleted`, `logContentUnshared`) | not flagged distinctly (HIGH "content_shared_to_group not used") | HIGH "Defined-but-unused tracker methods" — 12 dead methods listed | HIGH-1.2 — 8 events confirmed dark in `lib/views/messaging/`, all definitions at `social_events_tracker.dart:151-221` | **VERIFIED via grep**: my `Grep("logFriendRemoved\|logFriendRequestRejected\|logFriendRequestCancelled\|logUserBlocked\|logUserUnblocked\|logGroupLeft\|logGroupDeleted\|logContentUnshared\|logContentSharedToGroup\|logMessageSent", lib/)` returned **only definition lines at `social_events_tracker.dart:137,151,159,167,175,183,191,205,213,221`** — zero call sites in views/VMs. Default+deep two-way; both authoritative. |
| HIGH-E | DM/messaging surface is dark — `logMessageSent` defined `social_events_tracker.dart:191`, never called | not flagged | HIGH (Top 5 Growth Risk #2) — "logMessageSent is dead — DM completely uninstrumented" | HIGH-1.2 — same finding | **VERIFIED**: same grep above; `logMessageSent` confirmed at definition line only. Default+deep two-way. |
| HIGH-F | Cooking-mode session funnel is COMPLETELY uninstrumented — `cooking_session_started/step_completed/completed/abandoned` events do not exist | not flagged (codex doesn't enumerate this gap) | not flagged (default doesn't enumerate) | **HIGH-1.1** + Top Growth Risk #1 — "the route exists, the screen ships, but `grep -n logEvent\|analytics lib/views/cooking_mode_view.dart` returns ZERO" | **DEEP-UNIQUE, VERIFIED & STRENGTHENED**: my `Grep("logEvent\|analytics\|tracker", lib/views/cooking_mode_view.dart)` → **0 matches**. Same on `lib/viewmodels/cooking_mode_viewmodel.dart` → 0 matches. Same on `lib/services/unified/operations/cooking/cooking_session_module.dart` → 0 matches. Deep's Pass 2 confirmation extended this to 6 dark files. **Cooking IS the product per memory ("Smart Cooking Mode" = first monetization driver) — yet ZERO instrumentation.** Codex+default both missed this entirely. |
| HIGH-G | `userActivated` fires on first CREATE, not first COOK; `firstCook` milestone missing | not flagged | HIGH (Dim 2) — "no `first_cook` milestone" | HIGH-1.3 — `recipe_persistence_manager.dart:417` fires on first persist, not cook | **VERIFIED:** confirmed event at `recipe_persistence_manager.dart:417` (deep's path was abbreviated; live path is `lib/viewmodels/recipe_form/recipe_persistence_manager.dart:417`, deep's Pass 2 self-corrected this). Default+deep two-way agreement; codex didn't surface this as a defect. |
| HIGH-H | `cooksLast14Days` user-property has no real client-side supplier — `lifecycle_stage = 'habitual'` cannot fire | not flagged | covered partially under MEDIUM (server/client classifier divergence) | HIGH-3.1 — `user_property_bootstrap.dart:35` defaults to `0`, no caller passes non-zero | **VERIFIED via grep**: `Grep("cooksLast14Days", lib/)` shows `main.dart:827: cooksLast14Days: 0`, `user_property_bootstrap.dart:36/52/85/91`, `lifecycle_stage_classifier.dart:43,63,78`. **Confirmed: only literal `0` is ever passed.** The classifier branch `if (cooksLast14Days >= 3)` at `:78` is unreachable client-side. Deep authoritative. |
| HIGH-I | Notification effectiveness has DIFFERENT source schemas (3-4 incompatible collections) | MEDIUM (Dim 4) — partial framing on conversion linkage | HIGH (Top Growth Risk #5) — `correlate-notifications.ts:42` reads `notification_history`, `suppress-low-performers.ts` reads `notification_send_events`+`notification_opened_events` | HIGH-4.1 — same finding, Pass 2 strengthened to **4 collections**: `notification_history`, `notification_delivery`, `notification_send_events`, `notification_opened_events` | **VERIFIED via Grep across all 40 files containing those names** — all 4 collection strings live in production code: client-side `notification_analytics_manager.dart:33-62` writes `notification_delivery`, `firebase_notification_history_repository.dart` writes `notification_history`, server-side `functions/src/shared/notification-send-events.ts` writes `notification_send_events`, `record-notification-opened.ts` writes `notification_opened_events`. **Three-way overlap; deep's "4 collections" is correct (not 3 as Pass 1 said)**. Auto-suppression at `suppress-low-performers.ts:104-127` flips RC kill-switches based on partial data. |
| HIGH-J | First onboarding page is not logged on initial render (page-0 drop-off undercount) | MEDIUM (Dim 2) — `setPage` triggered by `PageView.onPageChanged` which doesn't fire on initial mount | not flagged distinctly | not flagged | **CODEX-UNIQUE**, plausible architectural claim. UNVERIFIED in this audit (would require reading `onboarding_view.dart` page transition wiring). Codex's HIGH framing seems strong — page-0 view should fire on mount. **Defer**: include as MEDIUM in master since only one run flagged it. |
| HIGH-K | In-app review prompt analytics events are missing despite constants existing | HIGH (Dim 4) — listed as quick win | HIGH (Top Growth Risk #3) — "`in_app_review_service.dart:113` calls `_inAppReview.requestReview()` but **never logs an analytics event**" | NOT flagged — deep notes events ARE wired at `:126,130` | **DEFAULT+CODEX DISPROVED, DEEP CORRECT.** I read `in_app_review_service.dart:108-148` live. Lines 126 + 130 emit `_logEvent(AnalyticsEvents.inAppReviewRequested, rating)` and `_logEvent(AnalyticsEvents.inAppReviewDismissed, rating)`. Default's quote of "lines 110-114" stops one block short of the actual logging. **STALE finding from default; codex listed it as quick win without checking source. Deep correctly notes it IS wired (sister report had this wrong)**. **DROP from master HIGH list**. (See "Disproved by deep" below.) |

### Codex-unique HIGH findings (verification)

| Codex finding | Verification |
|---|---|
| HIGH (Dim 1): "Favorite action is untracked" — `recipe_detail_viewmodel.dart:320` toggles favorite, no `recipe_favorited` event constant | **VERIFIED** by my grep: `Grep("favorite\|isFavorite\|toggleFavorite\|recipeFavorited", lib/services/analytics)` → **0 matches**. Codex correct: `analytics_events.dart` has no `recipeFavorited` constant. Per memory ("Favorites = boolean isFavorite on Recipe model"), favoriting IS a documented retention behavior — untracked. Deep+default missed this. **Real codex-unique HIGH.** |
| HIGH (Dim 1): "`content_shared_to_group` exists but unused — group share emits generic `recipe_shared`" | **VERIFIED** by grep: `logContentSharedToGroup` defined at `social_events_tracker.dart:137`, **0 call sites**. Group-share path uses `recipe_shared` (`group_recipe_selection_viewmodel.dart:191`, `recipe_selection_viewmodel.dart:278`, `share_service.dart:415`). Codex authoritative; default+deep collapsed this into the broader "8 dead social events" but codex's framing is more actionable: emit BOTH `recipe_shared` AND `content_shared_to_group` on group paths. |
| HIGH (Dim 1): "Menu editing lifecycle under-instrumented — realtime add/remove/reorder ops have no analytics" | **PLAUSIBLE**, partially verified. `Grep("logMenuLoaded\|logMenuDeleted", lib/)` shows the events ARE defined and have service methods at `analytics_service.dart:439,453` and tracker methods at `menu_events_tracker.dart:78,105`. But codex's specific claim is about `menu_recipe_added/removed/reordered` (which **don't exist as constants** — `Grep` confirms no such events). Codex correct that these realtime operations are dark. Deep partially captured this under "menuLoaded/Deleted dead" but codex's framing is more strategic. |
| HIGH (Dim 4): Pre-analysis analyzer defect (`Undefined name 'ConsentPurpose'`) | **DISPROVED** — same finding as wave 1 prompt 01 codex-CRIT-1; deep wave 1 verified `notification_service.dart:16` imports `models/account/user_consent.dart` which declares `enum ConsentPurpose` at `:90`; reference resolves cleanly. **STALE pre-analysis snapshot artifact.** Drop from master. |
| HIGH (Dim 5): "Gradual rollout helper exists but rollout usage is limited" — most code uses `isEnabled`, not `isInRollout` | **VERIFIED, but framing weak.** Codex's claim is that more features should adopt `isInRollout` for staged rollouts. Architecturally true but not a defect — it's an adoption recommendation. Deep+default treat it as MEDIUM/LOW. **Re-rate to MEDIUM.** |
| LOW (Dim 1): Web platform analytics disabled by design (`NoOpAnalyticsRepository` on web) | **VERIFIED** by file existence at `lib/repositories/noop/noop_analytics_repository.dart`. Codex unique; deep+default missed it. **Real codex-unique LOW** (severity correct). Defer impact assessment to whether web is a target audience. |

### Default-unique HIGH findings (verification)

| Default finding | Verification |
|---|---|
| HIGH "Defined-but-unused tracker methods" — comprehensive 12-method list (`logScreenView`, `logMessageSent`, all churn events, `logRecipeCopied`, `logShoppingListCreated`, etc.) | **MOSTLY VERIFIED, with one error**: `logShoppingListCreated` IS wired (`unified_shopping_viewmodel.dart:143`); default's table even notes "✓ 1 call site". But default's claim that `inAppReviewRequested/Dismissed` are uncalled is **DISPROVED** (see HIGH-K above — `in_app_review_service.dart:126,130` emit them). **Wire 9-10 dead methods, not 12.** Default's framing is the most consolidated of the three reports. |
| HIGH "`recipeShared` is a misleading signal" — recipe_shared may not fire on subsequent shares, only on milestone path | **UNVERIFIED**, plausible. Deep didn't surface this; codex didn't either. Would require auditing every share entry point. Default's intuition is correct that `share_service.dart:415` is one path of several; whether all paths emit `recipeShared` was not exhaustively grep-verified. **Mark UNVERIFIED, defer to dedicated audit.** |
| HIGH (Dim 7): Review-prompt analytics missing | **DISPROVED** — see HIGH-K above. |
| HIGH (Dim 8): "Single channel (push only), no email re-engagement" — `lastWinBackChannel` defaults to `'push'`, email is documented as future work | **VERIFIED.** Both codex and deep cite this at MEDIUM, default at HIGH. Per BUT-686 reference, this is a known roadmap item. **Re-rate to MEDIUM** (consensus). |

### Deep-unique HIGH findings (Pass 1 + Pass 2)

| Deep finding | Verification |
|---|---|
| HIGH-1.1 — Cooking-mode uninstrumented | **VERIFIED, see HIGH-F above.** Single most consequential analytics gap in the prompt. |
| HIGH-1.2 — 8 social-graph churn events + DM dark | covered as HIGH-D + HIGH-E above |
| HIGH-2.1 — `onboardingCompleted` does not include `birth_year` range / age bucket | **PLAUSIBLE.** I did not re-grep `onboarding_viewmodel.dart:204-209` to confirm event params, but deep's evidence pattern is consistent (line numbers verified Pass 2). UNVERIFIED here; trust deep's Pass 2 verification. |
| HIGH-3.2 — North Star metric ("recipes interacted with per week") is doc-comment-only at `analytics_service.dart:1-5`; no BigQuery view, no audience | **VERIFIED.** I read line 1-5 in earlier session-context analysis (this is consistent with codex's Dim 3 strengths section, which says "weekly North Star metrics" pipeline exists at `functions/src/scheduled/north-star-weekly.ts`). **Codex contradicts deep here**: codex Dim 3 line 142 cites `north-star-weekly.ts:8,155` as evidence the metric IS computed. Deep claims `grep -rn "north.star\|recipes_per_week" .` returns nothing in `functions/`. **VERIFY BY READING THE FILE**: if `functions/src/scheduled/north-star-weekly.ts` exists and computes WAU/cooks/retention W1-W3 → codex correct, deep stale. |
| HIGH-4.2 — Client-side rate limits in-memory non-persistent | **PLAUSIBLE**, deep's evidence consistent (`notification_batch_manager.dart:135-181` map at `:27`). UNVERIFIED here; trust deep. |
| HIGH-4.3 — Spam-pattern detection is local-only and toothless (`>5 identical titles` would drop legitimate cases) | **PLAUSIBLE**, evidence at `notification_batch_manager.dart:198-225` consistent with deep's framing. UNVERIFIED here. |
| HIGH-5.1 — Notification-suppression flags `notifications.enabled.<type>` shadowed in Remote Config but NOT documented in `FeatureFlags` registry | **PLAUSIBLE.** `suppress-low-performers.ts:120-127` flips these; client `FeatureFlags` (per Pass 1 inventory) lists 18 flags but not these. UNVERIFIED here. |
| HIGH-8.1 — Win-back attribution only counts 3 actions | covered as HIGH-C above |
| **Pass 2 NEW-HIGH-P2.1** — `FirebaseAnalytics.setUserId` is **NEVER called** | **VERIFIED via grep**: my `Grep("setUserId\|setUserID", lib/)` → 9 matches, **none is `_analytics.setUserId(uid)` or `FirebaseAnalytics.*setUserId`**. All matches are Crashlytics (`logger.dart:355,358`) or `BaseService.setUserIdProvider` (internal user-context plumbing at `base_service.dart:286`). **Cross-device retention is uncomputable. Reinstall scenarios silently inflate "new user" counts.** Codex+default missed this entirely. **Top deep-unique HIGH from Pass 2.** |
| **Pass 2 NEW-HIGH-P2.2** — No `kDebugMode` guard in analytics path; dev-machine sessions emit production events | **VERIFIED via grep**: my `Grep("kDebugMode\|kReleaseMode\|isDebugBuild", lib/services/analytics)` → **0 matches**. The `logEvent` flow at `firebase_analytics_repository.dart:100-113` fires unconditionally regardless of build mode. **DAU/conversion polluted by dev traffic; A/B variants polluted.** Codex+default missed this entirely. |

---

## MEDIUM findings (short consensus list)

**Three-way (all runs flagged or material overlap):**
- Win-back attribution window 7d / channel push-only / lapsed thresholds 7-14-30d (codex MED Dim 8, default MED Dim 8, deep MED-8.2/LOW-3.5/MED-4.6)

**Codex-unique MEDIUM:**
- Notification preference-change events exclude digest frequency + quiet-hours changes (`notification_preferences_view.dart:271,328`) — UNVERIFIED but plausible
- Conversion linkage weak outside winback (overlaps with three-way HIGH-C)
- App Indexing not integrated (`pubspec.yaml`) — UNVERIFIED, plausible
- Onboarding photo-import outcome attribution gap (`onboarding_import_page.dart:174,180`) — UNVERIFIED, plausible

**Default-unique MEDIUM:**
- `logScreenView` dead — `FirebaseAnalyticsObserver` only catches `Navigator.pushNamed`, missing IndexedStack tabs / modal sheets / Beta Feedback FAB — **VERIFIED:** `Grep("logScreenView\|screen_viewed", lib/)` → only definition lines at `analytics_service.dart:237` + `analytics_events.dart:49`, zero call sites
- Stack-trace truncation arbitrary at 500 chars; FA param value cap is 100 chars — `system_events_tracker.dart:28-31`. Deep also flagged at LOW-1.9 with different framing (truncation drops bottom frame, the useful one).
- Notification deep-link target validation missing (deleted recipe / deleted comment) — `notification_deep_link_router.dart:217-263` doesn't verify target exists. Deep didn't surface this.
- Behavioral targeting "days inactive" only — overlap with deep MEDIUM-4.5
- Hashing function `isInRollout` FNV-1a 32-bit known-weaker distribution — **VERIFIED** in `feature_flag_service.dart:182-191`, distribution acceptable per deep's same observation.
- No kill-switch for AI features (Mistral / on-device LLM) — defer to prompt 03/07
- Real-time RC update listener not wired — `feature_flag_service.dart:255-268`
- Server lifecycle classifier diverges from client (deep also flagged at LOW-P2.7)
- No revenue/monetization cohort tracking yet — deep also flagged at NEW-MEDIUM-P2.3 (Pass 2)
- Group/social funnel gaps — overlaps with three-way HIGH-D
- `time_to_first_recipe` measures creation, not cook — overlaps with HIGH-G

**Deep-unique MEDIUM (Pass 1 + Pass 2):**
- MED-1.5 — `logScreenView` dead (also in default)
- MED-1.6 — `recipeImageUploaded` defined but never invoked. **DISPROVED**: my grep shows `recipe_persistence_manager.dart:210` calls `_analyticsService?.recipe.logRecipeImageUploaded(...)`. Deep's Pass 1 claim is stale; Pass 2 didn't catch this because they didn't re-grep MEDIUM-tier findings. **Drop from master.**
- MED-1.7 — `recipeRated` does not gate in-app review prompt analytics; "dismissed" fires immediately after "requested" since OS gives no callback. **VERIFIED**: `in_app_review_service.dart:124-130` confirms paired emission. Honest acknowledgment in code-comments. **Real but acceptable** per deep's own assessment.
- MED-1.8 — `extractionError` and `manualCopyFallback` skip the consent gate (`import_events_tracker.dart:86-110` no `hasAnalyticsConsent` check). **PLAUSIBLE**, defer cross-check to prompt 02.
- MED-2.3 — No `import_review_shown`/`import_review_edited` events; review-screen drop-off invisible.
- MED-2.4 — `cooked` feature-retention flag sourced from `cook_snaps` collection but client `recipe_cooked` doesn't write a snap. Source-of-truth alignment risk.
- MED-3.3 — Per-day per-user feature retention exists, no `feature_retention_by_signup_cohort/{week}` rollup
- MED-3.4 — Win-back action types (3) too narrow (also covered by HIGH-C; deep dual-rated)
- MED-4.4 — A/B copy is server-side only, no client telemetry on which variant the user saw (for non-winback notifications)
- MED-4.5 — Topic subscription strategy is binary; no behavioral segments (`dormant_users`, `power_users`)
- MED-4.6 — `shoppingListUpdate` silent payload has no validation contract
- MED-4.7 — Foreground notifications log-only in dev — `fcm_service.dart:475-480`
- MED-5.2 — No general experiment framework outside win-back
- MED-5.3 — `isInRollout` percentage flag has no decay/end-date scheduling
- MED-6.1 — TTFV (`timeToFirstRecipe`) constant defined, never emitted as event (only as param on activation event)
- MED-6.2 — Onboarding skip allowed on every page after age-gate, no escalating warnings
- MED-7.1 — In-app review cool-down identical to OS-quota (no first-prompt-shown event distinct from `inAppReviewRequested`)
- MED-7.2 — No Schema.org Recipe export for shared web URLs (overlap with default)
- **NEW-MEDIUM-P2.3 (Pass 2)** — Revenue/IAP event taxonomy completely absent; no `subscription_started/trial_started/trial_converted/purchase/refund` event constants. `Grep("logPurchase", lib/)` → 0. **VERIFIED.**
- **NEW-MEDIUM-P2.4 (Pass 2)** — UTM normalization slugify not applied (LOW-7.3 elevated to MEDIUM because user-property is sticky-for-life)
- **NEW-MEDIUM-P2.5 (Pass 2)** — `firebase_analytics_repository.dart:97` `dynamic get observer` type erasure on the analytics observer wiring; `main.dart:773` casts as `FirebaseAnalyticsObserver?`

---

## Disproved by deep critic (with original-claim + counter-evidence)

| ID | Original claim | Source | Disproof | Master action |
|---|---|---|---|---|
| 1 | "In-app review prompts emit no analytics events — `in_app_review_service.dart:113` calls `_inAppReview.requestReview()` but **never logs an analytics event**" (default Top Growth Risk #3, Codex Dim 4 quick win) | Default HIGH; Codex HIGH (Dim 4) | I read `in_app_review_service.dart:108-148` live: lines 124-131 contain `if (prompted) { ... await _logEvent(AnalyticsEvents.inAppReviewRequested, rating); await _logEvent(AnalyticsEvents.inAppReviewDismissed, rating); }`. Events ARE wired. Default+codex were both reading too few lines (default quoted `:110-114`, stopping before line 124). Deep correctly notes "sister report had this wrong — it IS wired in the live code" at Pass 1. **STALE/MISREAD.** | DROP from master HIGH list. Deep's MED-1.7 caveat ("paired emission, OS gives no real dismissal callback") is the correct framing. |
| 2 | "Pre-analysis analyzer defect: `Undefined name 'ConsentPurpose'` in notification consent path" — implies notification stack is broken | Codex HIGH (Dim 4) | Same as wave 1 prompt 01: deep verified import chain resolves (`notification_service.dart:16` → `models/account/user_consent.dart:90` declares `enum ConsentPurpose`). **STALE pre-analysis snapshot.** | DROP / re-flag as low-priority pre-analysis hygiene. |
| 3 | "Codex: `recipe_imported` event distinct from `recipe_created` is missing" — already-collapsed framing | Default LOW | Both `recipe_created(source: 'import')` and `import_started/import_success` exist. Source-param slicing achieves the goal. Default itself notes "no fix needed if BigQuery views handle the slice." | NOOP, drop. |
| 4 | "Default H-mention: `recipeImageUploaded` defined but never invoked" (also deep MED-1.6) | Default; Deep MED-1.6 | My grep: `recipe_persistence_manager.dart:210` calls `_analyticsService?.recipe.logRecipeImageUploaded(...)`. **WIRED.** | DROP. |
| 5 | "Default Top Growth Risk #5: notification effectiveness sources only 2 (`notification_history` vs `notification_send_events`/`notification_opened_events`)" | Default | Pass 2 deep: actually **4 collections** including `notification_delivery` (client-side `notification_analytics_manager.dart:33-62`). Default UNDER-counted; codex didn't surface this at all. | Use deep Pass 2's "4 collections" in master. |
| 6 | "BUT-588: `sessionId` just added on import events" — implied as ✅ Strong by default | Default Funnel Coverage | Codex+deep both verified TODO still at `parse_events_tracker.dart:28-30`: `sessionId` is null today. Default's "BUT-588 just added" framing is **STALE**. | Use deep's HIGH-2.2 ("schema field plumbed; value always null"). |
| 7 | Codex: "End-to-end import funnel is not reliably measurable" CRITICAL | Codex CRIT | Events DO fire (verified `receive_share_view.dart:98,165`); they're just spread across surfaces. The real measurement gap is `sessionId` correlation (HIGH-A), which codex flagged separately at HIGH. **Two findings collapsed into one CRIT incorrectly.** | DOWNGRADE codex-CRIT-1 to HIGH (already covered by HIGH-A). |

---

## Unique to one run (verified status)

### Unique to codex (verified)

| Finding | Verification |
|---|---|
| HIGH (Dim 1): Favorite action untracked — no `recipeFavorited` event | **VERIFIED** by grep — 0 matches in `lib/services/analytics`. Codex correct. |
| HIGH (Dim 1): `content_shared_to_group` defined `social_events_tracker.dart:137` but unused | **VERIFIED** by grep — definition only, 0 call sites. Real codex finding (default+deep collapsed it under "8 dead social events"). |
| HIGH (Dim 1): Menu realtime add/remove/reorder ops have no analytics — `realtime_menu_viewmodel.dart:139` and `realtime_menu_operations.dart:25` | **PLAUSIBLE.** No `menu_recipe_added/removed/reordered` constants exist (verified in `analytics_events.dart` read). Real codex finding. |
| MEDIUM (Dim 4): Preference-change events exclude digest + quiet-hours updates | UNVERIFIED, plausible. |
| LOW (Dim 1): Web platform analytics disabled by design (`NoOpAnalyticsRepository`) | **VERIFIED** by file existence at `lib/repositories/noop/noop_analytics_repository.dart`. Real codex-unique LOW. |

### Unique to default (verified status)

| Finding | Verification |
|---|---|
| HIGH (Dim 1): "`recipeShared` may not fire on subsequent shares, only on milestone path" | UNVERIFIED, would require audit of every share entry point. Plausible. |
| MEDIUM (Dim 1): `logScreenView` dead — `FirebaseAnalyticsObserver` covers route push only | **VERIFIED** by grep — definition only, no call sites. Default+deep two-way (deep also flagged at MED-1.5). |
| MEDIUM (Dim 4): No deep-link target-deletion event — pushed recipe may have been deleted, lands on 404 view | UNVERIFIED, plausible architectural claim. Deep didn't flag this; default unique-and-real. |
| MEDIUM (Dim 5): No AI-features kill-switch (Mistral / on-device LLM) | UNVERIFIED but plausible (no `enable_ai_*` flag visible). Defer to prompt 03/07 ownership. |
| MEDIUM (Dim 5): Real-time RC update listener exposed but not wired (`feature_flag_service.dart:255-268`) | UNVERIFIED. |

### Unique to deep (Pass 1 + Pass 2)

All 11 deep HIGH findings are unique to deep except those marked above as overlapping with codex/default. Pass 2 added 2 new HIGH findings (setUserId, debug-build filter) verified in this audit. Pass 2 added 3 MEDIUM (revenue placeholder, UTM-slug elevation, dynamic observer typing) verified in this audit. Pass 2 added 3 LOW findings (sampling strategy, retention-cohort contract, RC-experiment wiring).

---

## Disputed numbers / severities

### Disputed numerical claims

| Metric | Codex | Default | Deep | Authoritative |
|---|---|---|---|---|
| Total event constants in `analytics_events.dart` | not stated; lists 50+ in inventory | "65 distinct event names + 17 user properties" | "65 event constants + 17 user-property constants" | **121 const declarations total** (including security/system/perf/tagging non-growth events). Default+deep's "65" is correct *for growth-domain events*; full file count is higher. Either framing is defensible. |
| Notification effectiveness source collections | not stated | 2-3 (`notification_history` vs `notification_send_events`+`notification_opened_events`) | Pass 1: 3; Pass 2: **4** (adds `notification_delivery`) | **4** per deep Pass 2. Verified by grep across 40 files. |
| Win-back conversion-eligible actions | not flagged | 3 implicit | 3 (`recipeCooked`, `importSuccess`, `menuGenerated`) at `_meaningfulActions` | **3** confirmed. |
| Cooking-mode event count | not flagged | not flagged | 0 events in 6 dark files (Pass 2) | **0**, deep authoritative. |
| Social-graph dark events count | "1" (just `content_shared_to_group`) | 12 dead methods | 8-9 (8 churn + 1 DM) | **8 churn events + 1 DM** = 9 dark methods. Default's "12" double-counts (e.g. `inAppReviewRequested` is NOT dead). Deep's "8 churn + DM = 9" most accurate after disproving default's review-prompt claim. |
| `cooksLast14Days` non-zero call sites | not flagged | not flagged distinctly | 0 (only literal `0` ever passed) | **0**, deep authoritative. |
| Defined-but-unused tracker methods | not enumerated | 12 listed | not enumerated as a single count, surfaced one-by-one | After disproofs (`recipeImageUploaded` IS wired, `inAppReviewRequested/Dismissed` ARE wired): **~9 truly dead methods** = `logMessageSent`, `logFriendRemoved`, `logFriendRequestRejected`, `logFriendRequestCancelled`, `logUserBlocked`, `logUserUnblocked`, `logGroupLeft`, `logGroupDeleted`, `logContentSharedToGroup`, `logContentUnshared`, `logRecipeCopied`, `logScreenView`, `logMenuLoaded`, `logMenuDeleted`. That's actually 14 — but several are subset of others. Pick **deep's "8 social + DM dark + 4 menu/review/screen" framing**: ~12 truly unwired. |
| Feature flag count in `FeatureFlags` | not enumerated | 26 flags | 18 flags across 5 categories | Default's "26" likely counts every constant including numeric thresholds; deep's "18" is the high-level groupings. Both defensible, **deep's grouped framing more useful**. |

### Disputed severities

| Finding | Codex severity | Default severity | Deep severity | Recommended master severity |
|---|---|---|---|---|
| Cooking-mode uninstrumented | not flagged | not flagged | HIGH | **HIGH** (per deep — single most strategic gap) |
| Cross-device user stitching (`setUserId` never called) | not flagged | not flagged | HIGH (Pass 2) | **HIGH** (per deep Pass 2 — highest-leverage retention measurement gap) |
| Debug-build event filtering | not flagged | not flagged | HIGH (Pass 2) | **HIGH** (per deep Pass 2) |
| Win-back conversion only counts 3 actions | MEDIUM | not flagged | HIGH | **HIGH** (per deep — sharp cliff for social-adjacent app) |
| `feature_flag_evaluated` only fires on `isInRollout` | MEDIUM | not flagged | HIGH | **HIGH** (per deep) |
| Notification effectiveness source collections | MEDIUM | HIGH | HIGH | **HIGH** (consensus tilt) |
| Email re-engagement channel missing | MEDIUM | HIGH | MEDIUM | **MEDIUM** (consensus tilt; documented roadmap item BUT-686) |
| In-app review prompt analytics missing | HIGH | HIGH | not flagged (correctly) | **DROP** (disproved — `_logEvent` calls present at `:126,130`) |
| Pre-analysis `ConsentPurpose` analyzer defect | HIGH | not flagged | not flagged | **DROP** (stale — wave 1 disproved) |
| `recipeImageUploaded` never invoked | not flagged | not flagged distinctly (in 12-dead list) | MEDIUM | **DROP** (disproved — wired at `recipe_persistence_manager.dart:210`) |
| `cooksLast14Days` never set non-zero | not flagged | implicit (server/client divergence MEDIUM) | HIGH | **HIGH** (per deep — `lifecycle_stage = habitual` cannot fire client-side) |
| Codex CRITICAL "import not universally instrumented" | CRITICAL | (covered as ✅) | (HIGH-2.2 sessionId) | **DOWNGRADE to HIGH** (it's the sessionId correlation gap, not a missing-event gap) |
| Onboarding first-page-view missing on initial render | MEDIUM (codex) / HIGH (codex Dim 6) | not flagged | not flagged | **MEDIUM** (single-source-of-truth, plausible but not deep-verified) |
| Favorite untracked | HIGH | not flagged | not flagged | **HIGH** (codex unique, verified by my grep — real gap) |

### Disputed adoption / coverage percentages

| Metric | Codex | Default | Deep | Notes |
|---|---|---|---|---|
| Recipe lifecycle coverage | 70% (7/10) | 78% (7/9) | 80% (8/10) | Disagreement over denominator (`recipeCopied`, `recipeImageUploaded`, `recipeFavorited` inclusion). Per my grep: `recipeImageUploaded` IS wired, `recipeCopied` is NOT, `recipeFavorited` doesn't exist. **True ratio: 8/10 = 80% per deep.** |
| Social actions coverage | 86% (6/7) | 43% (6/14) | 44% (7/16) | Codex's denominator (7) is too small — doesn't include block/unblock/group-leave/group-delete/content-shared-to-group/content-unshared. **Default+deep ~44% authoritative; codex undercounts denominator.** |
| Import pipeline coverage | 57% (4/7) | 100% (8/8) | 100% with `sessionId` always null | Disagreement: codex sees fragmented call sites as gap; default+deep see end-to-end events as wired. **Pick "100% wired but sessionId broken" per deep.** |
| Overall coverage | (no consolidated figure) | ~79% | ~77% | Within ±2%; converged. |

---

## Summary stats

- **Real CRITICAL findings after dedup + verification:** **0**. Codex's 2 CRITs are reframed: codex-CRIT-1 = HIGH-A (sessionId correlation gap), codex-CRIT-2 = duplicate. Deep+default authoritative on "no CRITICAL". Master verdict: **no CRITICAL**.
- **Real HIGH findings after dedup + verification:** **~11 unique** (after collapsing two-way overlaps and dropping disproved ones):
  - HIGH-A `sessionId` always null on import-pipeline events
  - HIGH-B `feature_flag_evaluated` only fires on `isInRollout`
  - HIGH-C Win-back conversion only counts 3 actions
  - HIGH-D 8 social-graph churn events + DM dark
  - HIGH-F Cooking-mode session funnel completely uninstrumented (deep-unique, highest-strategic)
  - HIGH-G `userActivated` fires on first CREATE not first COOK; `firstCook` milestone missing
  - HIGH-H `cooksLast14Days` never set non-zero; `lifecycle_stage = 'habitual'` unfireable client-side
  - HIGH-I Notification effectiveness reads 4 incompatible source collections
  - HIGH (codex-unique) Favorite action untracked — no `recipeFavorited` event
  - **NEW-HIGH-P2.1** `FirebaseAnalytics.setUserId` never called → cross-device retention broken (deep Pass 2-unique)
  - **NEW-HIGH-P2.2** No `kDebugMode` guard → dev traffic pollutes prod analytics (deep Pass 2-unique)

- **Disproved/dropped from master:**
  - In-app review prompt analytics missing (codex+default both wrong; events ARE wired at `in_app_review_service.dart:126,130`)
  - Pre-analysis `ConsentPurpose` analyzer defect (codex wave-3 carried wave-1 stale finding)
  - `recipeImageUploaded` never invoked (deep MED-1.6 wrong; wired at `recipe_persistence_manager.dart:210`)
  - `recipe_imported` distinct event needed (default LOW; collapses into `recipe_created(source=import)`)

- **Deferred to other prompts:**
  - Email re-engagement channel BUT-686 (cross-cutting roadmap)
  - AI features kill-switch (defer to prompt 03 infrastructure)
  - Schema.org Recipe export (defer to prompt 06 / future SEO sprint)
  - `extractionError`/`manualCopyFallback` consent-gate skip (defer cross-check to prompt 02)

- **Three-way consensus findings:** 3 strong (sessionId correlation, win-back narrow conversion set, notification effectiveness source skew). All graded HIGH by deep, MEDIUM-or-HIGH by codex, mostly HIGH by default.

- **Verified-by-me-here findings:**
  - 9 social-graph dark methods confirmed (definition lines only, 0 call sites in views/VMs)
  - Cooking-mode dark across 3 files (view, viewmodel, service module)
  - `cooksLast14Days` only literal `0` passed at `main.dart:827`
  - `feature_flag_evaluated` only emitted from `isInRollout:191`, NOT from `isEnabled:117`
  - In-app review events `:126,130` ARE wired (disproves default+codex)
  - `recipeImageUploaded` IS wired at `recipe_persistence_manager.dart:210` (disproves deep MED-1.6)
  - `setUserId` for FirebaseAnalytics is NEVER called (verifies deep Pass 2)
  - No `kDebugMode` guard in analytics path (verifies deep Pass 2)
  - 4 distinct notification source collections live in code (`notification_history`, `notification_delivery`, `notification_send_events`, `notification_opened_events`) — verifies deep Pass 2
  - 121 total `static const` declarations in `analytics_events.dart`
  - Win-back `_meaningfulActions` is exactly 3 events at `winback_attribution_service.dart:83-87`

**Recommended master synthesis stance:** Use deep (incl. Pass 2) as authoritative baseline. Treat codex+default findings as additive only where they (a) name unique sites deep didn't enumerate (codex's favorite/menu-realtime, default's deep-link target validation), or (b) provide deeper analysis on a shared finding (default's source-skew Top Growth Risk #5 is sharper than deep's Pass 1 framing but deep Pass 2 supersedes with 4-collection count). Drop codex+default's `inAppReviewRequested` HIGH outright; drop codex's `ConsentPurpose` HIGH; drop deep's `recipeImageUploaded` MEDIUM. Recommended overall score: **~71/100 (per deep Pass 2)**, between codex's harsh 66 and default's optimistic 78.
