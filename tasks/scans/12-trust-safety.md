# Role #12 — Trust & Safety / Content Moderation — scan findings

Scope: firestore.rules, lib/models/block_record.dart, lib/models/social/content_report.dart,
lib/repositories/firebase/firebase_block_repository.dart, lib/repositories/firebase/firebase_report_repository.dart,
lib/services/auth/account_maturity_helper.dart, lib/services/moderation/**, lib/services/social/blocking/blocked_user_filter.dart

Note on already-known items (NOT re-filed):
- BUT-458 (comment cross-user read rule) and BUT-459 (`isNotBlockedBy` on comment + notification
  creates) — verified present and correct at firestore.rules:1071-1073 and :1525-1539. Skipped.
- Dossier watch-item: leetspeak map has no `4→h` mapping (content_filter_service.dart:170-177) —
  already tracked. Skipped.
- Dossier watch-item: `onReportCreated` email stub (BUT-417) + no fallback alert — already tracked. Skipped.
- Dossier watch-item: `ReportService.submitReport` doesn't null-check `contentOwnerId` before the
  repo (repo validates) — already tracked. Skipped.
- Report create rule (firestore.rules:1948-1965): reporterId == auth.uid, self-report block,
  contentOwnerId required, reason enum, per-(reporter,owner) 24h throttle — verified solid, no forgery
  vector found. Report state machine (firestore.rules:1963-1974) is forward-only + immutable identity
  fields — verified solid. Nothing filed against reporting integrity.

---

## PASS 1 — primary (blocking enforcement, report integrity, content-filter bypass)

### Comment posting never runs the profanity filter on the write path
- type: bug  area: social (recipe comments)  priority: High
- pass: 1
- finding: The dossier states `ContentFilterService.ensureClean` is "the canonical pre-publish gate
  on every UGC surface ... comments" and "should call this BEFORE the network/Firebase write".
  The comment write path does not. `SocialCommentsManager.postComment` (social_comments_manager.dart:158-194)
  calls `_recipeService.social.addComment(...)` with the raw `_newCommentText` and never checks
  profanity. The underlying `CommentCrudOperations.createComment` (comment_crud_operations.dart:39-78)
  only validates non-empty/length — no `ContentFilterService` call anywhere on the path. The only
  profanity hook is `hasProfanityWarning` (social_comments_manager.dart:56-57), a getter that is
  **never consumed by any view** (grep of lib/views for `hasProfanityWarning` returns nothing).
- why: Comments are a primary harassment surface (Apple 1.2 / Google Play UGC). Group names, profile
  bios, recipe titles, and cook-snap captions ARE gated (form_validators.dart:443-451 `contentFilter`
  validator; cook_snap_service.dart:73 `ensureClean`), so comments are the one obvious UGC hole — and
  the warning getter that should have plugged it is dead code, so it looks covered but isn't. Firestore
  rules don't filter profanity (they can't), so there is no second line of defense.
- fix: In `postComment`, before `addComment`, call `ContentFilterService.ensureClean(_newCommentText,
  fieldName: 'comment')` and abort + surface `result.reason` when not clean (mirror the cook_snap_service
  pattern). Removing the unused `hasProfanityWarning` getter is optional cleanup.

### Chat text messages bypass the profanity filter on send
- type: bug  area: social (direct messages / chat)  priority: High
- pass: 1
- finding: `ChatViewModel.sendTextMessage` (chat_viewmodel.dart:271-314) sends `content.trim()` via
  `_messagingService.sendTextMessage(...)` with no profanity gate. The VM exposes
  `containsProfanity(text)` (chat_viewmodel.dart:94-95) but, like the comment getter, it is not
  consumed by any view (grep of lib/views for `containsProfanity` returns nothing) and `sendTextMessage`
  itself never calls it.
- why: DMs are explicitly flagged as "a primary spam vector" in the rules (firestore.rules:1308-1320,
  BUT-659) and are a harassment surface. Profanity filtering is the dossier's stated contract for chat;
  it's silently absent on the actual send path while a never-called helper makes it look present.
- fix: Gate `sendTextMessage` on `containsProfanity(content)` (or `ensureClean`) before the
  `_messagingService` call; set `_sendError` to the localized warning and return false when it matches.

### `AccountMaturityHelper.isMatured()` is dead client-side — maturity-gated CTAs surface raw permission errors
- type: bug  area: account / social (friend requests, DMs, group invites)  priority: Medium
- pass: 1
- finding: `AccountMaturityHelper.isMatured()` (account_maturity_helper.dart:28-36) is documented as
  the client mirror that lets "the UI pre-disable CTAs and surface the verification message before the
  user takes the action." Grep of lib/ shows the only reference to `isMatured`/`AccountMaturityHelper`
  is its own file (and tests) — no view or viewmodel calls it. The server gate `isAccountMatured()`
  (firestore.rules:109-123) DOES fire on friend-request create (firestore.rules:558), message create
  (firestore.rules:1315), etc., so a new account that taps "add friend" / "send message" gets a raw
  Firestore permission-denied instead of the intended "verify your email / wait 60 min" message.
- why: Not a security hole (the server gate holds), but it's the moderation/anti-abuse UX the dossier
  promises, and its absence means legitimate new users hit an opaque failure on exactly the friction
  actions maturity is meant to soften. The helper exists, is tested, and is simply not wired in.
- fix: Wire `isMatured(profile, firebaseUser)` into the friend-request / DM / group-invite CTAs to
  pre-disable + show the verification copy, OR (if the wiring is intentionally deferred) record that in
  accepted-deviations so the dead-code state is decided, not accidental.

---

## PASS 2 — second sweep (maturity-gate coverage on abuse-prone actions, moderation queue/handling)

### Recipe comment create is NOT gated by `isAccountMatured()` — maturity coverage is inconsistent
- type: bug  area: social (recipe comments) / firestore.rules  priority: Medium
- pass: 2
- finding: The new-account anti-spam gate `isAccountMatured()` is applied to friend-request create
  (firestore.rules:558) and message create (firestore.rules:1315), but the recipe-comment create rule
  (firestore.rules:1056-1075) gates only `isAgeCompliant()` + author identity + rate limit
  (`rateLimitWrite('comments', 5)`) — no `isAccountMatured()`. The dossier's own framing
  ("account-maturity cooldown ... gates high-friction actions (friends, comments)") names comments as a
  maturity-gated action, but the rule doesn't enforce it.
- why: Comments are public-facing UGC and a spam/abuse vector identical in risk profile to DMs. A
  freshly-registered bot is blocked from blasting DMs/friend-requests for 60 min but can immediately
  post comments (subject only to the 5s rate limit). Either the dossier overstates coverage or the rule
  is missing the gate; either way it's an inconsistency worth a decision.
- fix: Add `&& isAccountMatured()` to the recipe-comment create rule (firestore.rules:1056) to match the
  DM/friend-request posture, plus an allow/deny case in recipe-comments-rules.test.ts — OR amend the
  dossier to state comments are intentionally maturity-exempt (rate-limit-only) and log it in
  accepted-deviations.

### Moderation queue cannot surface `closed` reports — no re-open / audit-trail path
- type: improvement  area: moderation (admin dashboard)  priority: Low
- pass: 2
- finding: `ReportService.watchOpenReports()` (report_service.dart:109-121) queries
  `status whereIn ['new','in_review','actioned']` only; `closed` is excluded by design. The state
  machine is forward-only at the rules layer (firestore.rules:1963-1974) with no transition back out of
  `closed`. Combined, once a moderator closes a report it disappears from the only moderator-facing
  stream and can never be re-opened or reviewed again. There is no `watchClosedReports` /
  audit-history query.
- why: A wrongly-closed report (mis-click, or "not actionable" later proven wrong on a repeat offender)
  is unrecoverable from the moderator UI, and there's no way to audit past moderation decisions — both
  are real gaps for DSA statement-of-reasons / appeal expectations as the user base grows. Low priority
  pre-launch (≈1 user) but worth a ticket so it isn't discovered under load.
- fix: Add a `watchClosedReports()` (or a `watchReportsByStatus` with an optional filter) for an admin
  "history/closed" tab; optionally allow a `closed → in_review` re-open transition in the rule if appeals
  are desired. Defer the appeal flow itself.

---

COVERAGE: Reviewed all owned paths against the role-12 mandate (blocking enforcement, report
integrity/forgery, content-filter bypass, account-maturity gates, moderation queue/handling).
Report create + state-machine rules and the block-doc model verified solid (no findings). 5 NEW
findings filed (3 pass-1, 2 pass-2): two content-filter bypasses on the comment + chat write paths
(High), dead client-side maturity helper (Medium), missing maturity gate on comment create (Medium),
and a closed-report blind spot in the moderation queue (Low). All other domain risks were already
tracked in BUT-458/459, the dossier watch-items, or the hardened report rules — not re-filed.
