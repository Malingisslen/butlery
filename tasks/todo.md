# Sprint Backlog

## Sprint: autonomous-lane UI-consistency — 2026-06-23

Pulled from the `autonomous` Linear lane (sorted 2026-06-23). Coherent cluster: three
UI-consistency *finishing-touches* — each finishes applying an already-agreed convention to
its remaining call sites. All Tier B (visual surface → ship to main → In Review + notify).

### Agent A: hover-affordance — apply existing HoverableCard to remaining cards (BUT-1358)
- [ ] **A1. Wrap message bubble + friend card + shopping-list card in HoverableCard** `[Tier B]` — mirror `lib/widgets/recipe/recipe_card.dart`. (BUT-1358)
  - Acceptance: each of the 3 widgets renders a HoverableCard/MouseRegion hover wrapping its tap target · rest decoration visually identical to today (no layout change) · `enabled:false` where not tappable · `dart analyze` clean.

### Agent B: primary-action placement — friends Add-friend FAB (BUT-1357)
- [ ] **B1. Add an "Add friend" FAB on the Friends tab; keep Groups create FAB** `[Tier B]` — `lib/views/social/friends_list_view.dart`. (BUT-1357)
  - Acceptance: Friends tab shows an Add-friend FAB wired to the existing add-friend entry point · Groups tab still shows its create FAB · FAB is square · code comment records why tag-detail keeps the app-bar action · `dart analyze` clean.

### Agent C: long-press semantics — finish the BUT-948 convention audit (BUT-1356)
- [ ] **C1. Reconcile/​document remaining long-press sites** `[Tier B]` — `conversations_list_view.dart` + `cooking_mode_view.dart`. (BUT-1356)
  - Acceptance: every remaining long-press site is migrated to multi-select OR carries a code comment explaining the intentional contextual-menu exception (BUT-948) · `dart analyze` clean.

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos`
- [ ] Run/extend relevant widget tests
- [ ] code-reviewer + testing-specialist on staged .dart
- [ ] Commit, push to main
- [ ] Transition all three → In Review + PushNotification (Tier B)

---

_(Prior sprint scratch archived in git history — todo.md is sprint-scratch, overwritten each run.)_
