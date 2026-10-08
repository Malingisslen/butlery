---
paths:
  - "lib/views/pantry/**"
  - "test/widget/views/pantry/**"
---

# Accepted Deviations — the pantry sheet

Decided calls for this area, split out of `.claude/rules/accepted-deviations.md` on
2026-08-17 so they load when you open the code they govern rather than in every
session. **Do not propose them again and do not file review findings against them.**
Full rationale per entry: `docs/architecture/ACCEPTED_DEVIATIONS.md`.

A new deviation in this area is appended HERE and in that document, in the same edit.

- **The pantry sheet's unit dropdown keeps its EIGHT units and widens PER ITEM; it is not
  replaced by `UnitDefinitions.standaloneUnits`** — a stored unit the sheet does not offer is
  prepended for that item and stays selectable, so an untouched save cannot rewrite it.
  **Malin's explicit call, 2026-08-15**, over the two alternatives she was shown: adopting the
  parser's 88-entry set as the menu (no data loss, but that set exists to RECOGNISE what a
  parser may find in a recipe — it holds `pers`, `personer`, `gallons`, `tablespoons` — and a
  set you must recognise is not a set you should offer), and keeping the clamp for display
  while writing back the original (smallest change, but the screen would then disagree with
  storage). The widening keys on the STORED unit, deliberately unlike
  `RecipeFormState.mealTypeOptions` which keys on the current selection — so here the injected
  row survives a pick and can be chosen back, and a mis-pick is undoable. Do not propose the
  vocabulary swap again (pinned by `pantry_unit_options_test.dart`'s last case) and do not
  harmonise the two seams (pinned by widget test 8; test 7 pins the widening itself and stays
  green under the harmonisation mutant). Full rationale:
  `docs/architecture/ACCEPTED_DEVIATIONS.md`. BUT-1858, 2026-08-15
- **An older pantry version stays in the document, unshown, after 30 days** — `previous` is
  replaced by the next edit-sheet save or deleted with the item or the account, and until then
  it is in the Art. 15 export. There is no nightly job. **Malin's call, 2026-10-08.** BUT-2140
- **Återställ can work from a local copy older than a save the same user made on another
  device** — `PantryViewModel` holds no live stream, so the swap writes back the `previous`
  it has. BUT-1683 shape. BUT-2140, 2026-10-08
