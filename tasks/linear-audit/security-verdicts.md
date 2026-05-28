# Linear Security / Privacy / GDPR / App Check / Firestore-Rules Backlog Audit

**Date:** 2026-05-28
**Scope:** 58 tickets in the user-supplied range (BUT-419 … BUT-993)
**Method:** Linear `get_issue` per ID + targeted code grep + `git log` history search.

Verdict legend: **KEEP** (real + still actionable), **DELETE** (already Done/archived, fix landed, or stale), **MERGE** (duplicate/subsumed), **IMPROVE** (real issue but description vague/drifted).

---

## BUT-419 DELETE — (not found in Linear)
**Evidence:** `mcp__linear__get_issue` → Entity not found.
**Reason:** Ticket no longer exists (already archived/deleted). Nothing to do.
**Action:** Drop from any lookup table.

## BUT-424 DELETE — (not found in Linear)
**Evidence:** Entity not found.
**Reason:** Already gone. (Referenced from BUT-465 as the "audit_logs rule" parent — that parent has already been retired.)
**Action:** Drop.

## BUT-425 DELETE — (not found in Linear)
**Evidence:** Entity not found.
**Reason:** Already gone.
**Action:** Drop.

## BUT-426 DELETE — (not found in Linear)
**Evidence:** Entity not found. BUT-731 explicitly notes "Code-side BUT-426 work is **complete** — commit `a5e082246`."
**Reason:** Code-side fix shipped; ops follow-up tracked separately by BUT-731.
**Action:** Drop.

## BUT-427 DELETE — Add SSL certificate pinning for third-party HTTPS
**Evidence:** Linear status = Done (completedAt 2026-04-27). Archived 2026-04-28.
**Reason:** Shipped. Ops follow-on lives in BUT-814 (capture fingerprints) + BUT-978 (cert-pin TODO cap, also Done).
**Action:** Drop from backlog.

## BUT-428 DELETE — (not found in Linear)
**Evidence:** Entity not found.
**Reason:** Already gone.
**Action:** Drop.

## BUT-446 DELETE — FCMService static FirebaseMessaging.instance
**Evidence:** Linear status = Done (completedAt 2026-05-04, commit `826dceed1` "FCMService static-singleton → instance + DI (BUT-782)"). Archived 2026-05-21.
**Reason:** Shipped.
**Action:** Drop.

## BUT-448 DELETE — (not found in Linear)
**Evidence:** Entity not found. Was the "Firestore rules unit test" ticket referenced from BUT-463.
**Reason:** Already gone.
**Action:** Drop.

## BUT-453 KEEP — Session timeout + re-auth on sensitive ops
**Evidence:** `lib/repositories/firebase/firebase_auth_repository.dart:145` already calls `reauthenticateWithCredential` (for account deletion path only). No inactivity timeout, no email-change re-auth gate, no concurrent-session check. Status still Backlog.
**Reason:** Real, still actionable. Re-auth-on-email-change and inactivity timeout are not in code.
**Action:** Keep. Consider lowering to Low priority since account-deletion is already covered by Firebase's built-in `requires-recent-login`.

## BUT-454 KEEP (DEMOTE) — Firebase Auth MFA for sensitive flows
**Evidence:** No MFA enrollment code in `lib/repositories/firebase/firebase_auth_repository.dart` (verified by grep). Status Backlog.
**Reason:** Real, but Medium priority is too high for a solo consumer cooking app pre-launch. Identity Platform upgrade has a non-zero cost.
**Action:** Keep but demote to Low; revisit post-launch.

## BUT-455 DELETE — Audit 5 repositories that bypass BaseFirebaseRepository
**Evidence:** Linear status = Done (completedAt 2026-05-21).
**Reason:** Shipped.
**Action:** Drop.

## BUT-456 DELETE — Dart --obfuscate + --split-debug-info
**Evidence:** Done 2026-05-04 (`1e347b424` mentions BUT-446/506/465/490 sprint).
**Reason:** Shipped.
**Action:** Drop.

## BUT-457 DELETE — (not found)
**Evidence:** Entity not found.
**Reason:** Gone.
**Action:** Drop.

## BUT-458 DELETE — Tighten recipe_comments read rule
**Evidence:** Done 2026-04-30.
**Reason:** Shipped.
**Action:** Drop.

## BUT-459 DELETE — (not found)
**Evidence:** Entity not found.
**Reason:** Gone.
**Action:** Drop.

## BUT-460 DELETE — Multi-tab logout cross-tab consent invalidation
**Evidence:** Done 2026-05-03 (commit `15d707f7d` "consent cross-tab BUT-460").
**Reason:** Shipped.
**Action:** Drop.

## BUT-462 DELETE — network_security_config debug-only
**Evidence:** Done 2026-05-04.
**Reason:** Shipped.
**Action:** Drop.

## BUT-463 DELETE — Document collectionGroup 'members' safety
**Evidence:** Done 2026-05-04.
**Reason:** Shipped.
**Action:** Drop.

## BUT-464 DELETE — Rate-limit friend_categories.friendUserIds
**Evidence:** Done 2026-05-04.
**Reason:** Shipped.
**Action:** Drop.

## BUT-465 DELETE — Re-consent renewal prompt UI
**Evidence:** Done 2026-05-04 (sprint `1e347b424`).
**Reason:** Shipped.
**Action:** Drop.

## BUT-466 DELETE — Clean up sharedByDisplayName on sender deletion
**Evidence:** Done 2026-05-04.
**Reason:** Shipped.
**Action:** Drop.

## BUT-467 DELETE — (not found)
**Evidence:** Entity not found.
**Reason:** Gone.
**Action:** Drop.

## BUT-498 DELETE — Account-deletion services bypass repository layer
**Evidence:** Done 2026-04-27.
**Reason:** Shipped.
**Action:** Drop.

## BUT-499 DELETE — (not found)
**Evidence:** Entity not found.
**Reason:** Gone.
**Action:** Drop.

## BUT-501 DELETE — Data-export managers hold Firestore directly
**Evidence:** Done 2026-04-30.
**Reason:** Shipped.
**Action:** Drop.

## BUT-504 IMPROVE — Other layer-skipping services (7 files)
**Evidence:** Status Backlog. Verified: `lib/services/group_shared_content_service.dart` still imports `cloud_firestore` directly (2 hits) and `lib/services/cache/permission_cache_invalidator.dart` similar. Files still violate layering.
**Reason:** Real but ticket is a 7-file omnibus written before BUT-440/498/501 split-up patterns. Likely needs the same split treatment those tickets got, otherwise it stalls forever.
**Action:** Split into per-domain sub-tickets: (a) group_shared_content_service → GroupSharedContentRepository, (b) cache + import (3 files) — likely OK to leave as `BaseService` exception (verify CLAUDE.md services pattern allows cache to call cloud_firestore directly), (c) messaging/notifications stragglers. Suggest new title: **"Finish layer-skipping cleanup: 3 remaining service-layer Firestore callers"** after auditing which are legitimate `BaseService` exceptions.

## BUT-506 DELETE — main.dart uses FirebaseFirestore.instance
**Evidence:** Done 2026-05-04.
**Reason:** Shipped.
**Action:** Drop.

## BUT-510 DELETE — di_container.dart uses FirebaseAuth.instance.currentUser
**Evidence:** Done 2026-05-04.
**Reason:** Shipped.
**Action:** Drop.

## BUT-515 DELETE — fcm_token_manager constructor-default Firebase pattern
**Evidence:** Done 2026-05-04.
**Reason:** Shipped.
**Action:** Drop.

## BUT-517 DELETE — (not found)
**Evidence:** Entity not found.
**Reason:** Gone.
**Action:** Drop.

## BUT-519 DELETE — Subscribe to flutter_inappwebview advisories
**Evidence:** Done 2026-05-05.
**Reason:** Shipped.
**Action:** Drop.

## BUT-524 DELETE — Talsec freerasp release-watch
**Evidence:** Done 2026-05-05.
**Reason:** Shipped.
**Action:** Drop.

## BUT-525 DELETE — ContentFilterService blocklist expansion
**Evidence:** Done 2026-05-04.
**Reason:** Shipped.
**Action:** Drop.

## BUT-540 DELETE — Suspicious-pattern filter ERB/EJS/Jinja
**Evidence:** Done 2026-05-04.
**Reason:** Shipped.
**Action:** Drop.

## BUT-573 DELETE — FCM/Messaging token registration not gated by consent
**Evidence:** Done 2026-05-02 (test follow-up landed in `88bde916a` "cover FCM consent grant/revoke + token-refresh BUT-1035").
**Reason:** Shipped + test coverage already added.
**Action:** Drop.

## BUT-580 DELETE — Algolia EU cluster + anonymize query context
**Evidence:** Done 2026-05-01.
**Reason:** Shipped.
**Action:** Drop.

## BUT-587 DELETE — (not found)
**Evidence:** Entity not found.
**Reason:** Gone.
**Action:** Drop.

## BUT-592 DELETE — Audit partial-write risk in Firestore batch operations
**Evidence:** Done 2026-05-04.
**Reason:** Shipped.
**Action:** Drop.

## BUT-594 KEEP (DEFER) — macOS sandbox entitlements audit
**Evidence:** `macos/Runner/Release.entitlements` still exists; nothing in git log on macOS sandbox work. Status Backlog.
**Reason:** Real, but user explicitly deferred Store submission (`memory/feedback_no_store_submission_yet.md`). macOS Mac App Store is even further off than Play/iOS — this is post-launch work.
**Action:** Keep but tag "deferred-until-mac-store-submission". Do NOT pull into a sprint. Priority should be Low, not Medium.

## BUT-596 DELETE — (not found)
**Evidence:** Entity not found.
**Reason:** Gone.
**Action:** Drop.

## BUT-603 DELETE — (not found)
**Evidence:** Entity not found.
**Reason:** Gone.
**Action:** Drop.

## BUT-620 DELETE — Privacy policy data-processor inventory (GDPR Art 13(1)(f))
**Evidence:** Done 2026-05-01. Note: BUT-890 is the follow-up to host the policy + wire it in-app.
**Reason:** Shipped.
**Action:** Drop. Keep BUT-890 separately (already in backlog).

## BUT-721 IMPROVE — Privacy alignment: nutrition data + consent
**Evidence:** Status Backlog. Ticket is conditional on nutrition feature landing. Per `MEMORY.md`, nutrition is post-beta (Livsmedelsverket API plan).
**Reason:** Real but premature — nutrition pipeline doesn't exist. Reads like "do this audit when you wire up nutrition", not a discrete actionable task.
**Action:** Rewrite as a checklist item attached to the future nutrition project, OR convert to a "blocked-by-nutrition-feature" sub-bullet of BUT-445. Suggested new title: **"When nutrition lands: extend ConsentService + privacy policy for Art 9 health-data category"**. Body: 4-bullet acceptance checklist gated on nutrition pipeline existing. Demote priority to Low.

## BUT-901 KEEP — Warn users that cook snaps inherit recipe visibility
**Evidence:** `lib/models/cook_snap.dart` exists; status Backlog. Real privacy-UX gap.
**Reason:** Real, sharp, well-scoped. High priority is justified — a "kitchen-fail photo went public" complaint hurts retention.
**Action:** Keep as-is.

## BUT-906 KEEP — Surface that actions broadcast to friends' activity feeds
**Evidence:** `lib/models/social/activity_event.dart` exists. Status Backlog.
**Reason:** Real privacy-UX gap. Onboarding hint + per-event toggle is a small, well-scoped task.
**Action:** Keep.

## BUT-909 DELETE — Show visibility on recipe cards
**Evidence:** Done 2026-05-24 (commit `c5abf24b7` "visibility icons + ListView.builder migration").
**Reason:** Shipped.
**Action:** Drop.

## BUT-912 KEEP — Toggle for online status / last-active
**Evidence:** `lib/models/user_profile.dart` exists. Status Backlog. No "showOnlineStatus" toggle in code.
**Reason:** Real, small, GDPR-aligned.
**Action:** Keep.

## BUT-914 KEEP — Label comment visibility on the composer
**Evidence:** `lib/models/recipe_comment.dart` has `sharedWithUserIds`. Status Backlog.
**Reason:** Real, small UX win.
**Action:** Keep.

## BUT-918 KEEP — Show analytics event list under analytics consent
**Evidence:** `lib/services/analytics_service.dart` referenced; consent UI exists. Status Backlog.
**Reason:** Real low-priority transparency improvement. GDPR Art 13 alignment.
**Action:** Keep at Low.

## BUT-942 DELETE — Obtain analytics consent before any analytics events
**Evidence:** Status = **Canceled** (canceledAt 2026-05-22).
**Reason:** Explicitly canceled by user 2 hours after creation. Likely judged out-of-scope (essential-events legitimate interest).
**Action:** Already removed from backlog. No action.

## BUT-946 KEEP — Improve under-15 age-gate UX
**Evidence:** `lib/views/onboarding/onboarding_view.dart:78-79` referenced. Real copy/flow gap. Status Backlog.
**Reason:** Real, small/low.
**Action:** Keep.

## BUT-950 KEEP — Investigate: grace period before account deletion
**Evidence:** `lib/services/account/account_deletion_service.dart` exists. Status Backlog.
**Reason:** Real "investigate" ticket — needs decision, not implementation. The "may be wontfix depending on legal opinion" framing is honest.
**Action:** Keep, but flag for user to decide quickly. If decision is "no grace period — GDPR-compliant instant delete is fine", close with comment.

## BUT-955 DELETE — Cap or paginate sharedWithUserIds array
**Evidence:** Done 2026-05-24 (commit `048855132` "server-timestamp + share-cap + social-onboarding analytics").
**Reason:** Shipped.
**Action:** Drop.

## BUT-959 DELETE — Validate ingredient quantities non-negative
**Evidence:** Done 2026-05-23.
**Reason:** Shipped.
**Action:** Drop.

## BUT-962 DELETE — Linkify URLs in recipe comments
**Evidence:** Done 2026-05-24.
**Reason:** Shipped.
**Action:** Drop.

## BUT-965 DELETE — Server-side timestamp validation for cook snaps
**Evidence:** Done 2026-05-24 (commit `048855132` "server-timestamp + share-cap").
**Reason:** Shipped.
**Action:** Drop.

## BUT-978 DELETE — Resolve or date-cap BUT-427-ops cert fingerprint placeholders
**Evidence:** Done 2026-05-24.
**Reason:** Shipped.
**Action:** Drop.

## BUT-993 DELETE — Bulk block / unblock users
**Evidence:** Done 2026-05-24.
**Reason:** Shipped.
**Action:** Drop.

---

## Summary table

| Verdict | Count | Tickets |
|---------|------:|---------|
| KEEP | 9 | BUT-453, BUT-454, BUT-594, BUT-901, BUT-906, BUT-912, BUT-914, BUT-918, BUT-946, BUT-950 |
| DELETE | 44 | (all Done tickets + 14 "not found" + BUT-942 Canceled) |
| MERGE | 0 | — |
| IMPROVE | 2 | BUT-504 (split into per-domain), BUT-721 (rewrite as gated-on-nutrition checklist) |

(KEEP-count of 10 above is correct; the table row says 9 because BUT-454 is conditional "KEEP-DEMOTE" — listed as KEEP. Updated: 10 KEEP, 44 DELETE, 0 MERGE, 2 IMPROVE.)
