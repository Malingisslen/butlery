# Sprint Backlog

## Sprint: iter-68 — BUT-1060 drop stale dispose() on StatelessWidget — 2026-05-25 (Mon)

Theme: Pure-cleanup tech-debt — two stale `dispose()` methods on StatelessWidgets (`FriendRecipeListItem`, `MenuRecipeListItem`). Bodies are commented-out leftovers from a `StatefulWidget → StatelessWidget` refactor; framework never calls them. P4.

### Step 0 — premise verification

- Ticket points at `lib/widgets/common/dialogs/recipe_selection_dialogs.dart` — actual path is `lib/widgets/common/dialogs/recipe_selection/{menu,friend}_recipe_*_dialog.dart` (file split since ticket was written).
- Confirmed dead: `menu_recipe_selection_dialog.dart:361-365` + `friend_recipe_sharing_dialog.dart:420-424`. Both classes declare `extends StatelessWidget`. Methods have no `@override`, no real body — just 3 comment lines.
- No tests call `.dispose()` on these widgets (grep clean).
- Classification: **fits** (paths slightly stale, behavior matches).

### Design choices

- Pure deletion. No tests to update.

### Ship this sprint

- [ ] **A1. Delete dead dispose() from MenuRecipeListItem** — `lib/widgets/common/dialogs/recipe_selection/menu_recipe_selection_dialog.dart:361-365`. (BUT-1060)
- [ ] **A2. Delete dead dispose() from FriendRecipeListItem** — `lib/widgets/common/dialogs/recipe_selection/friend_recipe_sharing_dialog.dart:420-424`. (BUT-1060)

### Acceptance

- [ ] `flutter analyze` clean.
- [ ] `grep "void dispose" lib/widgets/common/dialogs/recipe_selection/` → 1 hit (the legitimate StatefulWidget dispose at menu_recipe_selection_dialog.dart:42).

### Post-Sprint Steps

- [ ] Commit + push
- [ ] Close BUT-1060

---

## Archived iter-67 (commit `2c01f6917`) — 2026-05-25 (Mon)

BUT-1072 P4 — dropped dead `_activeListeners` infrastructure from RealtimeSyncService. -58 / +36. 24/24 tests pass.
