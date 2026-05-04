# Sprint Backlog

## Sprint: pre-beta anti-spam + UGC moderation polish — 2026-05-04 (E)

Theme: cluster of 6 P3/P4 social/security tickets that close out Google Play UGC compliance gaps and prevent notification fatigue + spam vectors before opening to beta. **6 implementations + 1 obsolete close. 4 batches.**

**In Progress carry-overs (NOT in this sprint):**
- BUT-442 — repo migrations (4 candidates remaining; deserves own focused sprint).
- BUT-760 — App Check enforcement; awaiting Firebase Console flip.

**Step 0 verification — done:**
- **BUT-497** premise-gone (closed as Duplicate) — BUT-670 (commit `ac9020965`) shipped `app_maintenance_mode` Remote Config + `MaintenanceModeBlocker` widget last sprint. `min_supported_version` force-upgrade is a separate UX surface (own ticket if/when relevant).
- **BUT-537** valid — `ReportService.getMyReports()` exists at `report_service.dart:68`. No "My reports" view exists (greppable: no `MyReportsView`). Add view + Settings entry.
- **BUT-544** valid — `friends_state_manager.dart` has block filter; comment & chat read paths do not. Comments live in `lib/services/unified/operations/modules/recipe_comments_manager.dart`; chat in `lib/services/messaging/`.
- **BUT-649** plan-stale (mostly shipped) — `assets/legal/community_guidelines_{sv,en}.md` exist, `community_guidelines_view.dart` exists, Settings entry wired in `account_security_view.dart:369`, router registered in `app_router.dart:329`. **Remaining**: stamp `guidelineVersion` on `ContentReport` + reference text in report dialog + ToS link. Linear ticket description will be updated.
- **BUT-651** valid — no `notificationCounters` Firestore subcollection or per-user 24h rate cap exists. Add Firestore counter + cap-check + Remote Config keys.
- **BUT-654** plan-stale (paths) — ticket cites `lib/services/social/comment_service.dart` which doesn't exist. Comments live in `unified/operations/modules/recipe_comments_manager.dart` + `comment_crud_operations.dart`. Chat send: `messaging/message_sending_operations.dart`. Server-side enforcement via Cloud Function trigger (Firestore rules can't efficiently read time-windowed lists). Linear ticket description will be updated.
- **BUT-659** valid — no `accountAgeMinutes` derivation or rules gate. Implement rules guard + UI message. Verifier helper added to `firestore.rules`.

### Agent A: settings/UI surfaces — flutter-developer + uiux-designer

- [x] **A1. BUT-649 — Stamp `guidelineVersion` on reports + dialog reference** —
  - `lib/models/social/content_report.dart`: add `String? guidelineVersion` field, defaults to a `kCurrentGuidelineVersion` constant (e.g. `'2026-05-04'`).
  - `lib/services/moderation/report_service.dart:31` `submitReport`: stamp `guidelineVersion: kCurrentGuidelineVersion`.
  - Report dialog (locate via grep `submitReport(` in `lib/views/` / `lib/widgets/`): add a single-line reference "Genom att rapportera bekräftar du att innehållet bryter mot våra [riktlinjer för communityn]". Tap → `Navigator.pushNamed('/community-guidelines')`.
  - `assets/legal/community_guidelines_sv.md` + `_en.md`: ensure first line declares `Version: <date>` so users can tie reports to the active version.
  - ToS files (`terms_of_service_{sv,en}.md`): add a one-line reference to community guidelines if not already.
  - Tests: `test/unit/models/content_report_test.dart` — round-trip `guidelineVersion` through `toMap()`/`fromMap()`. (BUT-649)

- [x] **A2. BUT-537 — "Mina rapporter" view in Settings → Privacy/Safety** —
  - New view `lib/views/settings/my_reports_view.dart` extending `BaseScaffold` (`lib/widgets/common/scaffolds/`). Stream/Future from `ReportService.getMyReports()`. List items show: content type icon, date (`DateFormat.yMMMd('sv')`), reason, status badge.
  - Status enum already on `ContentReport` (verify: pending / reviewed / actioned). If missing, derive from existing fields.
  - Empty state: "Du har inte skickat in några rapporter än." with `EmptyStatePresenter` if exists, else simple Center + Text.
  - New ViewModel `lib/viewmodels/settings/my_reports_viewmodel.dart` extending `BaseViewModel` (per `lib/services/CLAUDE.md` and project conventions).
  - Wire route `'/my-reports'` in `lib/core/router/app_router.dart` (place near `community_guidelines_view` import).
  - Settings entry in `lib/views/settings/account_security_view.dart` (or appropriate Privacy/Safety section): below the community-guidelines tile, add a `ListTile` with title `context.l10n.settingsMyReports` ("Mina rapporter"), trailing chevron, onTap pushes `/my-reports`.
  - L10n: add `settingsMyReports`, `myReportsTitle`, `myReportsEmpty`, `myReportsStatusPending`, `myReportsStatusReviewed`, `myReportsStatusActioned` to `app_sv.arb` + `app_en.arb`. Run `flutter gen-l10n`.
  - Tests: `test/widget/views/settings/my_reports_view_test.dart` — empty state, populated list, status badges. (BUT-537)

### Agent B: social server/client moderation — flutter-developer + cloud-functions-specialist

- [x] **B1. BUT-544 — Block-aware filtering on comments + chat reads** —
  - Locate the existing block-list source. Read `friends_state_manager.dart` for the canonical `blockedUserIds` getter.
  - **Comments** (`lib/services/unified/operations/modules/recipe_comments_manager.dart` + `social_recipe_query_service.dart` if it owns the read query): post-filter the result list against `blockedUserIds` before returning. (Firestore `whereNotIn` is 10-cap; result-set filter is cheaper for unbounded blocked counts.)
  - **Chat** (`lib/services/messaging/message_sending_operations.dart` and the read-path module — find via grep `getMessages\|streamMessages`): same post-filter pattern on the message stream.
  - Centralize the filter in `lib/services/social/blocking/blocked_user_filter.dart` so both modules share the predicate (`bool shouldHide(authorId, blockedIds)`).
  - Tests: `test/unit/services/social/blocking/blocked_user_filter_test.dart` (predicate), plus integration-style assertions in existing comment + chat tests that blocked-author content is filtered out. (BUT-544)

- [x] **B2. BUT-654 — Duplicate-content rejection on comments + chat** —
  - **Server-side trigger** is the source of truth (rules can't time-window). Add `functions/src/social/duplicate-content-guard.ts`:
    - Firestore `onDocumentCreated` triggers on the comment + chat-message paths.
    - Compute `crypto.createHash('sha1').update(authorUid + ':' + body.trim().toLowerCase()).digest('hex').slice(0, 16)`.
    - Read `users/{uid}/recentContentHashes/{hash}` — if exists and `createdAt > now - windowMs`, delete the new doc (or mark `rejected: true` so client can show toast).
    - Else write the hash with TTL = 5min (use `expiresAt` for client-side filter; emulate TTL by sweeper or rely on overwrite on re-emit).
    - Window read from Remote Config key `duplicate_content_window_ms` (default 5 * 60 * 1000).
  - **Client-side fast-path** (optional but better UX): before sending, hash + check local cache (`SharedPreferences` rolling window of last 20). Reject early with Swedish toast "Du har precis skickat samma meddelande." Sites: `recipe_comments_manager.dart` create path + `message_sending_operations.dart` send path.
  - **Telemetry**: log `duplicate_content_rejected` analytics event with surface (`comment` | `chat`). Add to `analytics_events.dart`.
  - Tests: `functions/src/__tests__/duplicate-content-guard.test.ts` — dup within window rejected, dup after window allowed, different content allowed. (BUT-654)

### Agent C: rules + UI gating — firestore-rules-tester + flutter-developer

- [x] **B3. BUT-659 — New-account restriction (24h or verified email) on high-friction social actions** —
  - `firestore.rules`: add `function isAccountMatured()` returning `request.auth.token.email_verified == true || (request.time.toMillis() - get(/databases/$(database)/documents/users/$(request.auth.uid)).data.createdAt.toMillis()) >= 60 * 60 * 1000` (60min default — bumpable later). Cache the user-doc fetch via a single helper.
  - Apply in create-allow rules for: `friend_requests/`, `groups/{gid}/invites/`, `conversations/{cid}/messages/` (DM to non-friend), and group create paths. Read existing rules to find these.
  - Avoid double-fetch: helpers in firestore.rules already use `getAfter`/`get` patterns — reuse.
  - **UI message**: when a write is denied, show Swedish snackbar "Bekräfta din e-post för att lägga till vänner" with a "Skicka bekräftelse" CTA → `FirebaseAuth.instance.currentUser?.sendEmailVerification()`. Add a small util `lib/services/auth/account_maturity_helper.dart` that exposes `bool get isMatured` (client-side mirror) so UI can pre-check + disable CTAs.
  - Constant `kAccountMaturityMinutes = 60` shared between client + rules (rules-side hardcoded; doc the constant).
  - Tests: `functions/src/__tests__/social-rules.test.ts` (or wherever the rules tests live) — allow after 60min, deny before, allow immediately if `email_verified`. (BUT-659)

### Agent D: notifications backend — cloud-functions-specialist

- [x] **C1. BUT-651 — Global per-user 24h push-notification rate cap** —
  - Wrapper helper `functions/src/notifications/rate-cap.ts` exposing `async checkAndIncrement(uid, priority): Promise<{allowed: boolean, count: number, cap: number}>`.
    - Counter at `users/{uid}/notificationCounters/{YYYY-MM-DD}` doc with `count`, `criticalCount`, `lastUpdated` (server time).
    - Caps from Remote Config: `push_cap_total_per_24h` (default 10), `push_cap_noncritical_per_24h` (default 5). Cache for function warm lifetime.
    - Critical priority bypasses non-critical cap; total cap still applies.
    - Atomic increment via `FieldValue.increment(1)` in a transaction (read counter → check cap → either increment + return allowed, or return blocked without incrementing).
  - Wire into existing senders: `functions/src/notifications/send-notification.ts` + `deliver-scheduled-notifications.ts`. Before each `messaging().send()`, call `checkAndIncrement`. If blocked, log `notification_rate_capped` (Firestore `analytics_events` collection if that's the convention, else just `console.warn`) and skip.
  - Idempotency: counter increment is part of the per-send transaction; rules already gate creation paths.
  - Tests: `functions/src/__tests__/notification-rate-cap.test.ts` — increments under cap, blocks at cap, critical bypasses non-critical cap, day-rollover resets. (BUT-651)

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos` — 0 issues
- [ ] Functions: `cd functions && npm run build && npm test -- --testPathPattern='(duplicate-content|notification-rate-cap|social-rules)'`
- [ ] Affected Dart unit tests: `content_report_test`, `my_reports_view_test`, `blocked_user_filter_test`, plus regenerated l10n
- [ ] Tier-2 specialist gates: `code-reviewer` (any .dart), `testing-specialist` (any lib/), `firebase-backend-security` (auth/services touched), `cloud-functions-specialist` (functions/), `firestore-rules-tester` (rules changed — required)
- [ ] Commit, push to main
- [ ] CI watcher monitors green
- [ ] Update Linear: BUT-537/544/649/651/654/659 → Done; BUT-497 already Duplicate

### Continued blockers (NOT in scope per memory)
- BUT-415 / BUT-714 / BUT-646 / BUT-731 — store/Play submission deferred (Apple Dev enrollment gated)
- BUT-549 — post-beta (Sign in with Apple lands when social login does)
- BUT-579 — held for button-system sprint
- BUT-444 / BUT-445 — own product-design sprints
- BUT-498 / BUT-697 — explicitly skipped
- BUT-686 / BUT-660 / BUT-694 — feature-level brainstorming first
- BUT-674 / BUT-721 — own scoped sprints
- BUT-626 — bucket-based A/B infra; own sprint
- BUT-420 / BUT-451 / BUT-452 / BUT-486 — deploy-pipeline / staging cluster; focused infra sprint
- BUT-550 / BUT-536 / BUT-441 — ACCEPTED_LARGE_FILES drift sprint
- BUT-558 — DCM install (own sprint)
- BUT-554 — tracking ticket (blocked on drift_dev upstream)
- BUT-594 — macOS sandbox audit needs hardware-exercise step
- BUT-701 — focus traversal (2-day a11y sprint)
- BUT-479 — cursor-pagination half is non-trivial; needs design ticket
- BUT-435 + BUT-502/503/507/509 — Dart SDK 3.10 bump cluster (one focused sprint)
- All `idea`-labeled monetization scaffolding — post-beta

---

## Archived prior sprint (completed in commit ac9020965)

LLM resilience + ops kill-switches + DI tech-debt — 2026-05-04 (D) — shipped BUT-589/679/522/687/670/766/515. See git log for full task breakdown.
