# Sprint Backlog

## Sprint: iter-59 — BUT-937 cook-snap delete undo — 2026-05-24 (Sun)

Theme: Mirror BUT-943 snackbar-undo pattern (already shipped for comments). Plan-fil FÖRST.

### Step 0 — premise verification

- Ticket says "Soft-delete via #9" (= BUT-907 trash EPIC, multi-week, not yet shipped).
- Snackbar-undo pattern from BUT-943 (`recipe_detail_comments.dart:316-330`) is the working alternative — already established. Same shape for photo-delete (BUT-932).
- Current state: `recipe_detail_view.dart:670` wires `onDelete: (snapId) => vm.deleteSnap(snapId)` directly to the destructive call. No confirmation, no undo.

### Design choices

- **Apply BUT-943's pattern exactly**: confirm-delete dialog → 7s snackbar with Undo action → if untapped, commit the delete.
- **Wire at the callsite** (`recipe_detail_view.dart:670`), not in the ViewModel — keep VM's `deleteSnap(snapId)` pure. View owns the snackbar lifecycle.
- **No optimistic removal**: snap stays visible during the 7s window, matching comment-delete behavior.
- **New l10n key**: `cookSnapDeletedUndoMessage`.

### Ship this sprint

- [ ] **A1. ARB**: add `cookSnapDeletedUndoMessage` (sv + en).
- [ ] **A2. gen-l10n**: regenerate.
- [ ] **A3. recipe_detail_view.dart**: wrap the `onDelete` callback in a new private `_deleteCookSnapWithUndo(snapId, vm)` method that mirrors `_deleteComment` from `recipe_detail_comments.dart:300-338`.

### Acceptance

- [ ] Tap delete on own cook snap → confirm dialog → tap confirm → 7s snackbar with Undo.
- [ ] Undo tap within 7s → snap stays.
- [ ] Snackbar dismissed → commit delete.

### Post-Sprint Steps

- [ ] Commit + push
- [ ] Stäng BUT-937 i Linear → Done

---

## Archived iter-58 (commit `9f5670e26`) — 2026-05-24 (Sun)

BUT-895 LoadingIndicator semantic label. Wrapper-level fix benefits 50+ callsites. +60 / -22. BUT-895 → Done.
