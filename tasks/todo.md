# Sprint Backlog

## Sprint: iter-106 — first tiered sprint (autonomy policy live) — 2026-05-30 (Sat)

**Policy:** new tier routing (see `.claude/commands/sprint-execute.md` + `memory/feedback_autonomy_tiers.md`).
First run exercises the **Tier B** path end-to-end (build → HTML preview → In Review + notify).
Clean Tier A pool is thin; Tier C deferred to a later iteration.

### Agent B (UI) — social empty-state onboarding

- [x] **B1. BUT-975: branded Friends-tab empty state** `[Tier B]` — Step 0: FITS. Current
  `friends_tab.dart` uses generic `LoadingStateBuilder` empty params (icon + title + subtitle).
  Replace with a custom `emptyBuilder` → new `FriendsEmptyState` widget mirroring
  `MinaReceptEmptyState` (`mina_recept/empty_state_widgets.dart`):
  - `VegetableIllustration(peaPod, 100)` branded illustration
  - Headline `friendsEmptyHeadline` ("Laga tillsammans med vänner")
  - Subtitle `friendsEmptySubtitle` (share recipes / see what they cook / plan menus)
  - Primary CTA `socialInviteFriends` (reuse) → `RequestsTab.shareInvitationLink`
  - Secondary CTA `friendsEmptyFindByUsername` → parent `_tabController.animateTo(3)` (Find Friends tab)
  - Wire via new `onFindByUsername` param on `FriendsTab.build`; parent passes the tab-switch.
  - 3 new ARB keys (sv+en) + `flutter gen-l10n`. Semantics on both CTAs.
  - Tier B close-out: HTML preview + Chrome screenshot → main → **In Review** + PushNotification.
  (BUT-975, P3)

### Needs you (Tier D — flagged, not worked)
- (none selected this iteration)

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos` clean
- [ ] Widget test (semantics + CTA wiring) + `flutter gen-l10n`
- [ ] code-reviewer + testing-specialist on staged Dart
- [ ] Commit, push to main
- [ ] BUT-975 → In Review (9929b3b0…) + screenshot comment + PushNotification

---

## Sprint: iter-104 — 2 clean code-only tech-debt tickets (SHIPPED) — 2026-05-30
Shipped `b80aac380` (BUT-1055 + BUT-1066). iter-105 closed BUT-969 premise-gone. `a3c49bd67`
added the autonomy-tier policy to sprint-execute. Durable record: Linear + git.
