# Sprint Backlog

## Sprint: Consent-gate dedup + privacy/test sweep — 2026-05-02

Theme: close the two follow-ups surfaced by the prior sprint's `firebase-backend-security` + simplify pass (BUT-751 consent-gate dedup, BUT-752 Algolia post-startup consent re-init), pair them with a 4-ticket mechanical tech-debt sweep (BUT-692 path-embedded tracking ID strip, BUT-732 3 pre-existing test failures, BUT-598 section-divider comment removal, BUT-695 rename misleading `borderRadius8=0.0` constants, BUT-602 `Colors.black/white` → theme tokens). **2 agents, 7 tasks.** No Urgent/High in non-deferred backlog — selected by coherent area clustering.

Prior sprint shipped as `f4237f23b` (BUT-749/580/620/597/609). BUT-591 and BUT-601 closed as no-ops in same sprint. **BUT-750** (`device_info_plus` pin) shipped as `64c8f236f` — transition to Done as cleanup. **No carry-overs.**

**Why this shape:** the prior sprint's own follow-up section explicitly named BUT-751 and BUT-752 as next-up. The remaining 4 sweeps target areas the project's CLAUDE.md / memory rules already mark as policy violations (no section dividers, no `Colors.black`, no misleading constants). Each agent gets a coherent context surface, and per `memory/feedback_agent_timeout.md` the per-agent file count stays under the 3-file timeout heuristic.

**Verify-before-starting flags:**
- **A1 (BUT-751)** — confirm exact line locations: `lib/di/core_module.dart:395`, `lib/main.dart:310`, `lib/di/search_module.dart:174`. Place the helper on `ConsentService` itself (`Future<bool> hasAnalyticsConsent()` with deny-by-default). Update all 3 call sites + add a unit test proving deny-by-default fires when service unregistered.
- **A2 (BUT-752)** — verify `ConsentService` exposes a stream/notifier (`onConsentChanged` or equivalent). If not present, this ticket grows — flag and stop. Otherwise wire `search_module.dart` to listen + re-init Algolia client on grant. Add a widget/unit test covering the re-init path.
- **A3 (BUT-692)** — grep for `scrubUrlParams` first; current impl strips `?utm_*` etc. but leaves IDs in the path (`/track/abc123/...`). Add path-segment scrubbing for known tracker prefixes. Tests required because false positives here break legitimate URLs.
- **B1 (BUT-732)** — read the failing test names first; "3 pre-existing failures" needs to be the **same** 3 (not regressions from main). Fix the underlying logic, not the assertions, per testing philosophy.

### Agent A: firebase-backend-security + flutter-developer — consent + privacy hygiene

- [x] **A1. Extract shared `hasAnalyticsConsent()` helper — dedup 3 drifting copies of consent gate** — Added top-level `Future<bool> hasAnalyticsConsent(GetIt)` in `lib/services/account/consent_service.dart` with fail-closed semantics. Routed `main.dart:_enableCollectionIfConsented()` and `search_module.dart:initialize()` through it. **Honest scope correction:** the prior sprint's follow-up note named 3 sites, but `core_module.dart:395` is service-wiring (`isRegistered<ConsentService>` → `analyticsService.setConsentService`), not a `hasConsent` gate — left alone. Real dedup was 2 sites, not 3. Added 5 unit tests covering the deny-by-default branches (unregistered service, missing consent doc, lookup throws) plus the grant/deny purpose paths. (BUT-751)
- [x] **A2. Algolia re-init on consent change (post-startup grants currently need restart)** — Converted `ConsentService.onConsentChanged` from a single `VoidCallback?` field to a multi-listener API (`addConsentChangeListener` / `removeConsentChangeListener`). Discovered FCMService already owned the single-callback slot (`fcm_service.dart:127`); a naive add of a SearchModule subscription would have clobbered FCM's mid-session push-permission flow — multi-listener was load-bearing for the existing code as much as for this ticket. SearchModule now extracts an idempotent `_evaluate(GetIt)` (replaces inline init logic) tracking `_algoliaActive` so consent-flip → delegate-swap is a no-op when state already matches. Listener registered in `configureUserScope` (post-sign-in, after ConsentService is registered). FCMService updated to use new API at both register + dispose sites. 6 unit tests added (single listener, multiple listeners, remove, throwing-listener-doesn't-block-others, idempotent add, save-with-no-listeners safe). (BUT-752)
- [x] **A3. `scrubUrlParams` — strip path-embedded tracker IDs in addition to query params** — Helper lives in BOTH `lib/services/llm/pii_scrubber.dart:54` and `functions/src/llm/pii-scrubber.ts:103` (defence-in-depth contract). Patched both with parallel implementations: a path segment is judged opaque iff length ≥ 20 AND URL-safe-alphanumeric AND (UUID-shaped OR has a 16+ char unsplit alphanumeric run). Heuristic is false-negative-biased per the ticket's own "we cannot scrub IDs we cannot recognize" guidance — title-cased English slugs slip through; UUIDs, Algolia object IDs, JWT-shaped tokens, and 32-char hex hashes get stripped to `:redacted`. 11 new Dart tests + 8 new TS parity tests, all green (Dart 25/25 + TS 18/18). (BUT-692)

### Agent B: testing-specialist + flutter-developer — test + tech-debt sweep

- [x] **B1. Fix 3 pre-existing `removeFromSharedContent` test failures** — Reproduced 3 named failures (lines 186/229/255) on main. Diagnosed: (1) `views` / `dismissals` subcollections in the test fixture don't exist in the production schema — only `engagements` does (`shared_content/{contentId}/engagements/{userId}`, written by `Shared{Recipe,Menu,Shopping}EngagementRepository`); (2) test asserted production handles legacy `sharedWith` array; (3) fixture used `ownerId` field but prod schema uses `sharedByUserId` (17+ sites). Fixes: production code collectionGroup-scrubs `engagements` by `userId` (GDPR Art. 17 erasure); test fixtures aligned to real schema. **`firebase-backend-security` review caught a near-miss:** the legacy `sharedWith` cleanup I initially added would have permission-denied in prod (firestore.rules:515-518 only permits update by `sharedByUserId` owner or member-subcollection participant — legacy recipients have neither, FakeFirestore masked this). Removed the doomed code; renamed/inverted the test to pin the contract that user-driven path is a no-op on legacy data; filed **BUT-753** for admin-cascade Cloud Function cleanup. Also added `engagements.userId` entry to `firestore.indexes.json` (mirrors `members.userId` shape) — required for the new collectionGroup query in prod. 11/11 tests green. (BUT-732)
- [x] **B2. Remove 15 section-divider comments across 9 files** — Reconnaissance found only 2 of the 9 files Linear listed still had dividers in `lib/`: `lib/services/llm/llm_service.dart:254-256` and `lib/services/cooking/step_timer_service.dart:119-121` (each a 3-line `// -----` block, 6 lines total). The other 7 files Linear flagged were swept clean in earlier sprints. Removed the 2 surviving blocks. Other matches outside `lib/` (test files, build artifacts) untouched per ticket scope. (BUT-598)
- [x] **B3. Rename misleading `borderRadius8 = 0.0` constants in `app_dimensions`** — Reconnaissance: 122 call sites across 39 files for `borderRadiusN` with N ∈ {0,2,4,6,7,8,10,12,16,20,25}. A rename is a 39-file refactor that conflicts with `memory/feedback_agent_timeout.md`'s 3-files-per-agent heuristic. Linear ticket explicitly offered "OR add a header comment" as alternative — chose that option. Wrote a load-bearing comment block above the constants explaining (a) the SQUARE design language collapses every requested radius to 0, (b) why the `N` in the name is intentional ("this corner WAS 8px" — semantic intent for the day the rule loosens), (c) the two non-zero exceptions (`borderRadiusRound = 50.0`, `borderRadius100 = 100.0`). Future-dev confusion is the actual risk this ticket addresses; doc fixes that without churning 39 files. (BUT-695)
- [x] **B4. Replace `Colors.black` / `Colors.white` in `veckomeny_view.dart` with theme tokens** — **NO-OP.** Reconnaissance: `lib/views/veckomeny_view.dart` exists but `Colors.black`/`Colors.white` are gone (likely cleaned in an earlier sprint). The only remaining `Colors.black` occurrences in `lib/` are 11 sites in `lib/theme/app_shadows.dart` — those are theme primitives building shadow `BoxShadow(color: Colors.black.withValues(alpha: …))`, not a view-layer violation. Closing as already-resolved. (BUT-602)

### Post-Sprint Steps

- [x] `dart analyze --fatal-infos` — 0 issues
- [x] Affected unit tests: 88/88 green (consent_service + pii_scrubber + social_deletion_operations)
- [x] Tier-2 specialist gates: code-reviewer ✅, testing-specialist ✅, firebase-backend-security ✅ (caught the legacy-sharedWith permission issue → BUT-753 filed)
- [x] BUT-750 cleanup transitioned to Done (shipped as `64c8f236f`)
- [ ] Commit, push to main
- [ ] Update Linear: BUT-751/752/692/732/598/695/602 → Done

### Follow-ups surfaced this sprint

- **BUT-753** — Admin-cascade legacy `sharedWith` cleanup (Cloud Function on user delete). Caught by `firebase-backend-security` near-miss: client-side path I originally wrote would server-side permission-deny in prod. Needs admin context.

### Continued blockers (NOT in scope per memory)

- BUT-415 / BUT-714 / BUT-646 / BUT-731 — store/Play submission deferred (Apple Dev enrollment gated)
- BUT-498 / BUT-697 — explicitly skipped per standing direction
- BUT-686 / BUT-660 / BUT-694 — need feature-level brainstorming first
- BUT-674 / BUT-721 — need their own scoped sprints
- BUT-579 — true High but holding for a focused button-system sprint, not a sweep slot
- All `idea`-labeled monetization scaffolding — post-beta per memory

---

## What this means in plain language

- **Two follow-ups from last week ship.** Last sprint's own report flagged that the search backend doesn't switch on/off when you grant analytics consent (you'd have to restart the app), and that the same consent check is copy-pasted three times in the startup code with subtle drift. Both get fixed.
- **One privacy fix ships.** A URL-cleaning helper currently misses tracker IDs hidden inside the path of a link (only catches them in the query string after `?`). Plugged.
- **Three pre-existing test failures get fixed.** They've been hanging around showing red on share-content removal — finally addressed.
- **Mechanical cleanup wave.** Section-divider comments removed, a misleadingly-named constant renamed, hardcoded black/white colors swapped for theme tokens in the weekly menu screen.
- **Risk: low.** All changes are localized, all are covered by tests, none touch the UI structure or any external service contract. Easy to revert any single ticket on its own.

---

## ARCHIVED — Sprint: Security spot-fix + privacy paperwork + tech-debt sweep — 2026-05-02

Shipped as `f4237f23b` ("fix(security/privacy): menus self-scrub gap + Algolia EU/consent + privacy DPA (BUT-749/580/620/597/609)"). 5 implementation tickets shipped; BUT-591 and BUT-601 closed as no-ops (already-resolved/already-clean). BUT-749/580/620/591/597/601/609 → Done in Linear. Surfaced two follow-ups (BUT-751 consent-gate dedup, BUT-752 Algolia re-init on consent change) — picked up in next sprint. Plus BUT-750 (`device_info_plus` pin) shipped as `64c8f236f`.

## ARCHIVED — Sprint: Retention measurement loop + import HEIC fix — 2026-05-01

Shipped as `d803ea1f2` ("feat(analytics/import): retention measurement loop + HEIC conversion (BUT-688/691/623/599/662)") plus `9d259b06c` (CI unblock) and `815df8e43` (DateTime baseline). All 5 implementation tasks complete. BUT-688/691/623/599/662 → Done in Linear.

## ARCHIVED — Sprint: GDPR tripwires red→green + onboarding follow-ups + simplify-pass cleanup — 2026-05-01

Shipped as `e52a1ebb4` ("fix(gdpr): close BUT-746/747/748 + onboarding follow-ups + migration perf"). All 8 tasks complete. BUT-740/741/743/744/745/746/747/748 → Done in Linear.
