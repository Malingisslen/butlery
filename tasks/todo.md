# Sprint Backlog

## Sprint: multi-select bulk-unblock — 2026-06-04 (iter-109)

Clean tree on main (prior commits …ba7c7a4e3, 64be6fd1f). Fresh area (social) after 3 import-quality
iters. Single focused Tier-B ticket reusing the established BUT-997/1038 multi-select pattern
(service primitives already shipped).

### Agent A: social — bulk-unblock UI
- [ ] **A1. BUT-1039** `[Tier B]` — multi-select bulk-unblock in `blocked_users_section.dart`.
      - **Step 0:** fits. UI lives in `lib/widgets/common/settings/blocked_users_section.dart`
        (already StatefulWidget, 203 lines). Service primitive `unblockUsers(List<String>) → Future<int>`
        in `friends_management_operations.dart` exists. Mirror `group_members_list.dart` (BUT-1038):
        long-press→selection, inline "(N)" action bar, self-contained.
      - Long-press tile → selection mode; tap toggles; per-tile "Avblockera" hides in selection.
      - Inline bar "Avblockera valda (N)" + cancel; confirm dialog → `unblockUsers(ids)`; count snackbar.
      - **Note:** primitive returns an int (count), not failed names — summary is count-based
        ("N avblockerade" / partial "N av M"); true failed-names needs a richer primitive (flag).
      - Bulk-block from friends list = out of scope (more disruptive flow) → follow-up if warranted.
      - l10n sv/en + a11y Semantics on the now-tappable tile. Widget tests mirroring BUT-1038's 6.

### Needs you (Tier D / deferred — carried)
- BUT-1169 (legacy shopping consts — prod backfill CF), BUT-838 (cook-events log — Tier-C rules+CF),
  BUT-1187 (phone import verify), onRecipeDeleted gen-2 deploy ticket.

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos`
- [ ] widget tests green
- [ ] Commit, push
- [ ] Linear: In Review + notify (Tier B UI)

---

## ARCHIVED — iter-108: import cost-guard (shipped 64be6fd1f)
BUT-1037 → In Review. RecipeTextHeuristic + warn dialog + telemetry, 10 tests.

## ARCHIVED — iter-107: gesture-hint discoverability (shipped ba7c7a4e3)
BUT-1199 → In Review. Generalized SwipeHintBanner + cooking-step + shopping-claim hints, 6 tests.

## ARCHIVED — iter-106: post-refactor testability + import-UX (shipped 9c8946120)
5 Tier-A Done (1194/1195/1196/1197/1028) + BUT-1198 allergen banner In Review. Follow-up BUT-1200.
