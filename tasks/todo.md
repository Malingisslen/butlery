# Sprint Backlog

## Sprint: backend — thin buildable slice (2 tickets) — 2026-06-14 (iter-154)

Focus = `backend` area label. **Warning: <3 buildable backend tickets.** Of 28 open `backend`-labeled tickets, the overwhelming majority are **Tier D ops-blocked** (GCP console / deploy / staging project / gcloud / billing / external accounts) or **speculative/monetization** (RevenueCat, premature scaffolds). Only two carry a code-only mandate this loop can land. Per the skill, NOT manufacturing build work to fill N.

### Agent A: backend-refactor — repository tidy
- [ ] **A1. Extract dual-collection deletion into a documented mixin** `[Tier C]` — `lib/repositories/firebase/firebase_user_repository.dart` (610 lines): pull the `users/{uid}`-root deletion methods (`deleteUserRootDoc` and siblings that bypass the inherited `collection` getter, which points at `public_profiles/{uid}`) into a `UserRootDeletionMixin` (new file under `lib/repositories/firebase/modules/`) that documents WHY it reaches `firestore.collection(users)` directly instead of the base getter. Pure mechanical extraction — zero behavioral change. (BUT-734)
  - Acceptance: The dual-collection deletion logic lives in a new mixin file with a class/file doc-comment explaining the public_profiles-vs-users cross-collection access · `firebase_user_repository.dart` no longer exceeds its current line count (net non-increase after extraction) · No call-site signature changes — every existing caller of the moved methods compiles unchanged · Existing user-repository / account-deletion tests pass with no assertion weakened (behavior identical pre/post)

### Agent B: recipe-timers — concurrent timers + expiry notification (UI + service infra)
- [ ] **B1. Multiple concurrent labeled step timers + local notification on expiry** `[Tier B]` — `lib/services/recipe/step_timer_service.dart`, `lib/widgets/recipe/step_timer_widget.dart` (+ a new `lib/services/notifications/local_timer_notification_service.dart`): convert the single-state `StepTimerService` to a map of id→{label,endAt,state} with a stream of timer-list snapshots; re-bind `StepTimerWidget` per timer + add an active-timers overview affordance in cooking mode; schedule a real `flutter_local_notifications.zonedSchedule` at start (cancel on pause/reset) so expiry alerts fire when the app is backgrounded. Keep the `package:clock` reconciliation so backgrounding doesn't drift. (BUT-1242)
  - Acceptance: Two timers started from different steps tick independently with their own labels, and pausing/resetting one does not affect the other · An active-timers overview affordance is shown in cooking mode when ≥1 timer runs · A scheduled OS notification is created at timer-start and cancelled on pause/reset (verifiable from the notification-service calls in the diff/tests) · Existing single-timer `StepTimerService` tests pass or are deliberately migrated (no silently-deleted coverage)

### Needs you (not built — flagged for your call)
- **BUT-1242 is build-review, not auto-close** — large (its own body estimates 2–4 days), touches service architecture + platform notification infra (timezone init, notification permissions) AND has real UX decisions (how the multi-timer overview looks, notification copy, permission-prompt timing). Best-guess build parks In Review with a preview; sign off on the overview affordance + notification behaviour.
- **BUT-1011** (Low) — async status-polling for very large account deletion. The current synchronous callable has a 9-min ceiling; the ticket itself calls the timeout "theoretical" for multi-thousand-recipe accounts. Converting to an async job + client polling is a sizeable architectural change defending against an unobserved edge case. Recommendation: **defer** until a real timeout is observed in logs; not worth the complexity now.
- **BUT-1248** (Low) — schemaVersion migration-dispatch + backfill. Explicitly "when the first v2 schema change lands" — no v2 change has landed, so this is a scaffold with no live trigger. Recommendation: **defer** — build it alongside the first real migration, not speculatively.
- **BUT-1169** (Low) — backfill legacy meat_fish/fruit_veg shopping docs + drop legacy constants. The "drop constants" half is clean code (14 call sites in lib reference the legacy aliases), but it's gated on a **prod data backfill** first (legacy Firestore docs must be migrated before the read-side aliases can be removed without breaking old lists). Backfill needs prod access → ops. Recommendation: **defer** until the BUT-1169 backfill is run; do them together.
- **BUT-610** (Medium) — audit + harden offline mode. Open-ended audit across a whole module with no concrete defect list; scope and acceptance are vague. Recommendation: **reframe** into specific defect tickets after a scoped offline-mode crash audit, then build those.
- **BUT-650 / BUT-661** (Low) — subscription-tier Firestore rules + RevenueCat webhook CF. Both are monetization infrastructure; memory says "no monetization decisions yet — just build the app." Recommendation: **drop until monetization is a decided workstream.**
- **BUT-686** (Medium) — email win-back channel for dormant users. Needs an email-sending CF + provider wiring + a product call on re-engagement cadence. Recommendation: **your call** — product/lifecycle decision, not a code cleanup.

### Tier D — ops-blocked (flagged, never coded this loop)
- **BUT-1229** (High) — deploy BUT-1214 cook-snap visibility backfill BEFORE rules+indexes deploy (needs prod creds + ordered deploy).
- **BUT-492** (High) — Firebase/GCP cost & budget alerts (GCP console).
- **BUT-451** (High) — staging Firebase project (console + .firebaserc + project creation).
- **BUT-486** (High) — automate rules/indexes/functions deploy in CI (needs deploy creds + workflow).
- **BUT-1166** (High) — App Check Play Integrity/App Attest registration + Monitor→Enforce (console roll-out).
- **BUT-813** (High) — observability hardening: GCP alert policies + notification channels (console).
- **BUT-819** (Medium) — verify Firestore region via gcloud (console/CLI).
- **BUT-821** (Medium) — Cloud Monitoring alert on moderate-upload failures (console).
- **BUT-818** (Medium) — SafeSearch via Vision API (paid GCP API + billing/privacy-policy).
- **BUT-1239** (Low) — CI guard vs Firebase Storage latest_version.txt (needs Storage creds in CI).
- **BUT-1224** (Low) — explicit cachedContents decision gate (needs 2 weeks of deployed telemetry).
- **BUT-1167** (Medium) — AI/LLM ops remainder (Vertex prefix caching verify, CI gate — deploy-coupled).
- **BUT-840** (Low) — Algolia mirror in on-profile-updated.ts (Algolia is client-side; server CF needs Algolia SDK + admin API key secret = ops).
- **BUT-491** (Medium) — desktop platform CI builds (runner config).
- **BUT-594 / BUT-420** (Low) — macOS entitlements / Fastlane deploy pipeline (store-submission deferred per memory).

### Obsolete (done in git, still open in Linear)
- None detected in the backend focus. No BUT-XXX in the last 7 days of git maps to an open backend ticket.

### Post-Sprint Steps
- [ ] Run `dart analyze --fatal-infos`
- [ ] Run relevant unit tests (`test/unit/repositories/`, `test/unit/services/recipe/`)
- [ ] Commit, push to main
- [ ] Update Linear: BUT-734 → Done (Tier C, mechanical+test-proven), BUT-1242 → In Review + notify (Tier B)

---
## ARCHIVED — iter-153 (tagging: area drained, no batches — BUT-907 flagged needsApproval as speculative Trash & Recovery epic) · iter-152 (menu: BUT-1278/1279 Tier A, BUT-1043/930 Tier B — shipped commit 1711d297c; BUT-1179 Needs-you) · iter-151 (import: BUT-1040/931/947/903/1205 — shipped 673f80c87 + 10325a5bb; BUT-653/656/684/941 needsApproval) · iter-150 (social conflict-cleanup + activity/sharing UI: BUT-1267/1266 Tier A, BUT-1220/1000/949 Tier B; BUT-1265 obsolete-closed) · iter-149 (BUT-1265 conflictStream test — f37c9af03) · iter-148 (BUT-1263/1264 recoverLocalVersion test-gaps — d4ee51b0f) · iter-147 (BUT-1262 realtime data-loss-path) · iter-146 (BUT-1053/1247/1250) · iter-145 (BUT-1251/1246/1249 Done) · iter-144 (BUT-648/1057 In Review) · iter-143 (BUT-1245/626 Done) · äldre i git-historiken
