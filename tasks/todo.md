# Sprint Backlog

## Sprint: activity-feed broadcast opt-out (BUT-906) — 2026-06-08 (iter-131) `[Tier B]`

**Step 0:** FITS (re-scoped to MVP). Activity events (cooked/shared/addedIngredient/startedCooking/
pinged) auto-post to friends' feeds via the single chokepoint `ActivityFeedService.emitEvent`; users
are never told and can't opt out. Full ticket wants per-event-type toggles + a one-time hint — re-scoped
to a **master toggle** ("show my activity in friends' feed", default ON) which delivers the core control;
per-event granularity + one-time hint → follow-up. Mirrors the established `showOnlineStatus` privacy
pattern (BUT-912) exactly, so low risk.

**Files touched (all mirror `showOnlineStatus`):**
- `lib/models/user_profile.dart` — new `shareActivityToFeed` bool (default true): field, ctor default, copyWith, both toJson maps, both fromJson/fromFirestore safeBool, equality.
- `lib/viewmodels/user_profile_viewmodel.dart` — getter + `updateShareActivityToFeed(bool)` + include in save (`completeProfileUpdate`/copyWith) + equality helper.
- `lib/services/social/activity_feed_service.dart` — `emitEvent`: after loading `currentUserProfile`, `if (profile?.shareActivityToFeed == false) return;` (silent skip; fire-and-forget).
- `lib/views/social/user_profile_edit_view.dart` — `_buildPrivacySettings`: add a SwitchListTile mirroring the online-status toggle.
- `lib/l10n/app_sv.arb` + `app_en.arb` — toggle title + subtitle.

**Blast radius:** enforcement is one early-return in emitEvent (default-true pref + null-profile → preserves current broadcast behavior). Profile field persists via existing saveProfile path (no user_service change → no firebase-backend-security trigger). Default ON = zero behavior change until a user opts out.

**Product-intent flag (In-Review):** master toggle vs the ticket's 5 per-event-type toggles — granularity deferred to follow-up. Default ON (discoverable opt-out, not opt-in) per the ticket.

**Rollback:** revert commit; field is additive + defaults to current behavior.

**Deferred → follow-up:** per-event-type toggles (5) + one-time "this appears in friends' feed" hint.

- [ ] **A1. `shareActivityToFeed` pref + enforcement + privacy toggle** `[Tier B]` (BUT-906)

### Post-Sprint Steps
- [ ] gen-l10n + `dart analyze --fatal-infos` + format
- [ ] code-reviewer + testing-specialist gates
- [ ] Commit, push; BUT-906 → In Review + notify; file granularity follow-up

---
## ARCHIVED — iter-130 (BUT-901 In Review; BUT-1214) · iter-129 (BUT-923 In Review) · iter-128 (BUT-944 In Review; BUT-1213) · iter-127 (BUT-1210 Done + BUT-1211 In Review; BUT-1212)
