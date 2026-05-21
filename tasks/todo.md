# Sprint Backlog

## Sprint: wave-7 — analytics wiring + repo-audit security + privacy docs + dedup pass — 2026-05-21 (Th)

Theme: 4 implementations (BUT-798 split, BUT-878 wiring, BUT-455 security audit, BUT-811 privacy docs) + 4 Step 0 closures (3 duplicates/obsolete + 1 still-blocked).

### Agent A: flutter-developer — social analytics wiring (1)
- [ ] **A1. BUT-878 (HIGH-PA10)** — wire 6 missing tracker calls + 1 DM site. Tracker methods + `AnalyticsEvents.*` constants already exist (verified in `social_events_tracker.dart` + `analytics_events.dart`). Currently wired: `logFriendRequestSent`, `logFriendRequestAccepted` (friends_viewmodel), `logGroupJoined` (group_invitations_viewmodel). **Missing call sites to add:**
  - `_analyticsService.logFriendRequestRejected(senderId: ...)` → reject-request path (likely `friends_viewmodel.dart` rejectRequest or `unified_friends_service.dart` rejectFriendRequest)
  - `_analyticsService.logFriendRemoved(friendId: ...)` → unfriend path (likely `unfriend` / `removeFriend`)
  - `_analyticsService.logUserBlocked(blockedUserId: ...)` → block path (`UserService.blockUser` or block repository)
  - `_analyticsService.logUserUnblocked(unblockedUserId: ...)` → unblock path
  - `_analyticsService.logGroupLeft(groupId: ...)` → leave-group path (`unified_groups_service` or equivalent)
  - `_analyticsService.logMessageSent(conversationId, messageType)` → DM send path (`message_sending_module` or equivalent)
  - `_analyticsService.logContentSharedToGroup(groupId, contentType)` → group-share path (look in `group_invitations_viewmodel` or sharing flow)
  - Use `_analyticsService` (the `AnalyticsService` facade) where it's already injected; fall back to `_analytics?.social.log…` pattern (seen at group_invitations_viewmodel.dart:420) if the facade doesn't expose the method yet.
  - **No new constants, no new tracker methods** — verified all 9 exist already.

### Agent B: firebase-backend-security — repo-audit + GDPR cascade audit-logs (1)
- [ ] **B1. BUT-455 (MEDIUM-3 + HIGH-SEC4)** — two-part security audit:
  - Part 1: Audit the 5 named Dart repos (`firestore_repository.dart`, `collaborative_recipe_repository.dart`, `parsing_correction_repository.dart`, `site_config_repository.dart`, `algolia_search_repository.dart`). For each: confirm whether writes go through `BaseFirebaseRepository` or explicitly call `logPermissionCheck`. Document findings inline as code comments where the bypass is intentional, or add audit logging where it's not.
  - Part 2: Add `audit_logs` entries to 6 cross-user cascade-delete sites in `functions/src/cleanup/`:
    - `social_deletion_operations.ts:64` — friend-graph removal
    - `social_deletion_operations.ts:97` — friend-request cascade
    - `social_deletion_operations.ts:156` — group-membership cascade
    - `social_deletion_operations.ts:208` — block-list cascade
    - `social_deletion_operations.ts:239` — notifications cascade
    - `profile_deletion_operations.ts:65` — profile/avatar/displayName scrub
  - Audit shape: `{ actor: 'system', subject: deletedUid, targetUid: otherUid, op: 'cascade_delete', collection: '<name>', reason: 'gdpr_article_17' }`.
  - Add at least one CF unit test asserting log presence per file (or one combined test covering all 6 with table-driven cases).

### Agent C: claude (inline) — privacy/legal docs pass (1)
- [ ] **C1. BUT-811 (HIGH-LEGAL2/5/7/8/9 bundle)** — 5 small privacy/legal items:
  - **LEGAL2:** Add `ITSAppUsesNonExemptEncryption=false` to `ios/Runner/Info.plist`.
  - **LEGAL5:** Update ToS doc (`docs/legal/tos.md` or wherever it lives — verify path) with the 30-day deletion / 365-day audit retention / 30-day backup expiry timeline.
  - **LEGAL7:** Update `ios/Runner/PrivacyInfo.xcprivacy` to declare `NSPrivacyCollectedDataTypeHealthAndFitness` for allergen/dietary data.
  - **LEGAL8:** Add on-device ONNX disclosure section to privacy policy (verify file path under `docs/legal/`).
  - **LEGAL9:** Tabulate current processors (Firebase suite, Algolia[deferred], Crashlytics, GA4, Vertex, Vision, reCAPTCHA) against the privacy policy's processor list; add missing rows.
  - Bilingual: update both Swedish and English versions if the policy is bilingual (verify).

### Agent D: claude (inline) — coordinator: file BUT-798 Phase 1-4 sub-tickets (1)
- [ ] **D1. BUT-798 (HIGH-UX4 coordinator)** — per ticket's own re-scoped plan, file 4 sub-tickets in Linear:
  - Phase 1: Center(child: CircularProgressIndicator) → StateWidget.loading() in `lib/views/` (~25 sites)
  - Phase 2: Inline button spinners → LoadingIndicator.small() in `lib/widgets/common/buttons/` + dialogs (~30 sites)
  - Phase 3: Image overlays + upload progress (~20 sites)
  - Phase 4: Remaining tagging/social/recipe widget files (~50 sites)
  - Close BUT-798 as superseded once the 4 children exist.

### Step 0 — obsolete / duplicate / blocked tickets to close (4)
- [~] **BUT-875** — premise gone. BUT-876 (wave-6) chose **option 2** (rewrite test to pin transitional behavior) — `model_manager_integrity_test.dart` now asserts the documented soft-allow contract per `_expected_model_hashes.dart:23-27`. Close as resolved by wave-6 commit `273152149`.
- [~] **BUT-859** — duplicate of BUT-862. Same source (BUT-805 PERF5 follow-up), same scope (isolate offload for parser/CRF/OCR), same acceptance. BUT-862 has more detail. Close BUT-859 as duplicate.
- [~] **BUT-829** — duplicate of BUT-798. Both cover the same `CircularProgressIndicator` → `StateWidget.loading()` migration. BUT-798 has been re-scoped to a coordinator (file Phase 1-4 children); BUT-829 just repeats the bulk-migration plan. Close BUT-829 as duplicate.
- [~] **BUT-877** — still blocked. Registry currently has only v1 for both NER + LineClassifier; flipping `verifyModelDownload` to fail-close would brick users if a v2 has been deployed without a registry update. No Firebase Storage access this session to verify `latest_version.txt` is still v1. Leave open, add Linear comment explaining the blocker + acceptance gate ("verify `latest_version.txt` == 1 for both families before flipping; OR build the CI check first to enforce coverage").

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos` clean
- [ ] Tier-2 agent reviews — `code-reviewer` (.dart files), `testing-specialist` (lib/*.dart), `firebase-backend-security` (BUT-455 repos + cleanup CFs), `firestore-rules-tester` (if rules touched — likely not in this sprint) — markers written before commit
- [ ] File follow-ups in Linear (mandatory before commit): any reviewer findings deferred; any BUT-811 sub-items that turn out to need more than the bundled fix
- [ ] Commit (inline) + push direct to main
- [ ] Close Linear tickets BUT-878/455/811/798 (done) + BUT-875/829/859 (obsolete/duplicate); leave BUT-877 open with explanatory comment
- [ ] CI watcher

---

## Archived prior sprint (commit 273152149)

wave-6 — model-integrity test contract fix + cooking-mode analytics + ops runbooks — 2026-05-21 (Th) — BUT-876/802/452 shipped. BUT-874 closed as premise-gone.

## Archived two-sprints-ago (commit b66f5892f)

wave-5 — image-quality OCR gate + test-gap closures + adoption metric — BUT-660/872/865/866/873 shipped. BUT-479/843/858 closed as premise-gone. BUT-840 deferred.

## Archived three-sprints-ago (commit 90d88cfca / b115d7519)

wave-3 follow-ups + UI consolidation continuation — BUT-868/869/870/871/867/776/864.

## Archived four-sprints-ago (commit 8e54f68f2)

UI consolidation + CI + model integrity tests — BUT-861/579/801/841/825/823.
