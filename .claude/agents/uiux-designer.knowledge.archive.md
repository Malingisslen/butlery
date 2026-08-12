# uiux-designer — archive (raw record, append-only)

Dated entries. Full detail behind each compressed principle in
`uiux-designer.knowledge.md`. Never delete an entry — supersede with a new
dated one if a verdict changes.

---

### 2026-08-12 — BUT-1685 roster-incomplete hint review (`menu_content_widgets.dart`)

**Trigger:** BUT-1685's ticket required a uiux-designer pass on the visible
warning as its only outstanding acceptance criterion. Reviewed
`_buildRosterIncompleteHint` (shipped commit `2ca50f1ff`) against its call
site in `buildMenuContent` and the sibling `_buildHiddenByFamilyHint` it
replaces for `MenuPrefSource.householdIncomplete`.

**Finding 1 — ship-blocking: wrong color token on the warning icon.**
`_buildRosterIncompleteHint` colors `Icons.warning_amber` with `cs.secondary`.
`cs.secondary` resolves to `rust` (`lib/theme/app_colors.dart:271`,
`static const Color secondary = rust`), which is the SAME color the sibling
`_buildInlineError` in the same file uses for `Icons.error_outline` — a hard
generation failure. So a soft "the roster might be incomplete" caution and a
hard "menu generation failed" error render in the same hue, one screen
apart. The app has an established, pervasive warning token for exactly this:
`context.butleryColors.warning` (`#D4A03C` light / `#E4C56B` dark), used at
~50 call sites (`common_dialog_actions.dart`, `conflict_banner.dart`,
`rate_limit_dialog.dart`, `recipe_card.dart`'s `hasFailed ? cs.error :
context.butleryColors.warning` pattern, etc.). Most damning: the DIRECT
sibling for this exact feature —
`lib/views/settings/widgets/household_allergen_filter_tile.dart:151-176`,
which renders the household-allergen-roster-off state — uses
`Icons.warning_amber, size: AppDimensions.iconSizeS, color: warning` where
`warning = context.butleryColors.warning`, verbatim the icon/size the menu
hint copied, minus the correct color. Fix: swap `cs.secondary` for
`context.butleryColors.warning`.

**Finding 2 — next-commit: text color under-weighted for a safety caveat.**
The sibling tile also styles the explanatory TEXT in the warning color
(`AppTextStyles.bodySmall.copyWith(color: warning)`), not neutral gray. The
shipped menu hint uses `cs.onSurfaceVariant` for the text — identical
treatment to the purely-informational "N recept dolda" hint it replaces.
Since the copy explicitly says allergy data "kan vara ofullständig" and the
row renders even when nothing was actually hidden, giving it the exact same
visual weight as routine bookkeeping text undersells a message that is
genuinely safety-relevant (food allergies). Recommend matching the sibling:
`AppTextStyles.bodySmall.copyWith(color: warning)` for the text too, not just
the icon.

**Checked and correct — no findings:**
- **Icon choice.** `Icons.warning_amber` (vs. an error icon) correctly signals
  caution/uncertainty rather than failure — right family, wrong color (see
  Finding 1).
- **Copy/butler voice.** "Vi kunde inte läsa alla i hushållet just nu, så
  listan över allergier kan vara ofullständig." — first-person plural "vi",
  plain declarative, no exclamation, matches the tone of sibling strings
  (`menuHiddenByOwnAllergies`, `menuHiddenByFamilyAllergies`).
- **Semantics.** The row is static and non-interactive; Flutter auto-exposes
  the child `Text` to screen readers and the icon correctly carries no
  redundant `semanticLabel`. Matches the sibling `_buildHiddenByFamilyHint`
  it replaces (also unwrapped). The a11y floor (`Semantics` on interactive
  elements) doesn't reach a display-only row — no wrap needed.
- **Icon size.** `AppDimensions.iconSizeS` matches the sibling tile's warning
  row exactly.
