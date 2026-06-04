# Sprint Backlog

## Sprint: online-status privacy toggle — 2026-06-04 (iter-111)

Clean tree on main (prior commits …f33b0f708, 23ac13e5d). Picked BUT-912 (Medium) — a real privacy
opt-out. Step-0 confirmed premise holds: `firebase_user_repository.updateOnlineStatus` writes
`isOnline`/`lastActiveAt`; `friend_request_card` renders a green dot `if (isOnline)`; the write
funnels through the single `UserService.updateOnlineStatus` gate.

### Agent A: privacy — opt out of online status
- [ ] **A1. BUT-912** `[Tier B]` — "Show online status" toggle. (settings/social)
      - Model: add `bool showOnlineStatus` (default true) to `UserProfile` (ctor + toFirestore +
        fromFirestore + fromJson + copyWith), sibling to `isSearchable`/`allowEmailSearch`.
      - Gate: in `UserService.updateOnlineStatus`, force `isOnline=false` when the current profile's
        `showOnlineStatus` is off — user is invisible to everyone at the source (write-gate, GDPR-clean).
      - VM: `user_profile_viewmodel` getter + setter mirroring `isSearchable`.
      - View: toggle row in `user_profile_edit_view` next to the existing privacy toggles. l10n sv/en.
      - When toggled OFF, push `isOnline=false` immediately so the dot clears now.

### Needs you (Tier D / deferred — carried)
- BUT-1169, BUT-838, BUT-934 (re-engagement CF), BUT-1187, onRecipeDeleted gen-2 deploy.

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos`
- [ ] tests green (model round-trip + service gate)
- [ ] Commit, push
- [ ] Linear: In Review + notify (Tier B; firebase-backend-security gate on user_service.dart)

---

## ARCHIVED — iter-110: analytics transparency (shipped 23ac13e5d)
BUT-918 → In Review. "What we log" disclosure. BUT-923 flagged premise-stale.

## ARCHIVED — iter-109: multi-select bulk-unblock (shipped f33b0f708)
BUT-1039 → In Review. 6 widget tests.

## ARCHIVED — iter-108: import cost-guard (shipped 64be6fd1f)
BUT-1037 → In Review. RecipeTextHeuristic + warn dialog, 10 tests.

## ARCHIVED — iter-107 / iter-106
BUT-1199 gesture hints (ba7c7a4e3); 5 Tier-A + BUT-1198 (9c8946120).
