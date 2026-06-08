# Sprint Backlog

## Sprint: single icon convention (heart/star/bookmark) — 2026-06-08 (iter-128)

### Agent A: flutter-developer — design-system icon convention (BUT-944) `[Tier B]`

**Step 0 classification:** FITS (plan-stale-minor). Ticket says "add lib/widgets/common/icons.dart
OR extend AdaptiveIcons" — `AdaptiveIcons` (lib/widgets/common/icons/adaptive_icon.dart) ALREADY
centralizes platform-adaptive favorite/star/bookmark getters, so the work is: name the *concepts*
+ migrate the cited raw `Icons.*` sites onto them. Lower-risk than the ticket assumed.

**Convention (documented in the getters' doc comment):** heart = personal preference
(favourite / like), star = system designation (primary / featured), bookmark = template /
saved-for-later.

**Files touched:**
- `lib/widgets/common/icons/adaptive_icon.dart` — add concept getters: `favouriteFilled`/
  `favouriteOutline` (→heart), `primaryFilled`/`primaryOutline` (→star), `savedTemplate`/
  `savedTemplateOutline` (→bookmark), + convention doc comment.
- Migrate cited call sites (preserve existing colours + filled/outline state toggles):
  - heart: `recipe_detail_view.dart:344`, `comment_item_widget.dart:97`,
    `comment_item_widgets.dart:337`, `recipe_card.dart:387`, `collection_stats_view.dart:150`
  - star (primary): `image_grid_widgets.dart:157`, `primary_badge.dart:28`
  - bookmark (saved): `shopping_list_header.dart:302`, `shopping_app_bar.dart:246` (semantic rename)

**Blast radius:** icon-constant swaps only; no logic change. iOS sites that used raw Material
`Icons.*` become platform-adaptive (Cupertino on iOS) — the intended consistency gain, reviewable
in In-Review. Rating/sort/dietary stars (`star_rating_row`, `sort_menu_builder`,
`onboarding_dietary`, social_components) are a DIFFERENT concept → left untouched.

**Product-intent flag (note in In-Review comment, don't change):** colour drift — comment likes
use `colorScheme.error` (red) vs favourites use theme default. Preserving both as-is; the
unify-or-keep decision is Malin's. → follow-up.

**Rollback shape:** revert the commit — getters are additive, call-site swaps are 1:1.

- [x] **A1. Concept getters + convention doc** `[Tier B]` — `adaptive_icon.dart`: `favouriteFilled/Outline`, `primaryFilled/Outline`, `savedTemplate/Outline` + convention doc comment. (BUT-944)
- [x] **A2. Migrate 9 cited call sites** `[Tier B]` — recipe_detail_view, comment_item_widget(s), recipe_card, collection_stats_view (heart); image_grid_widgets, primary_badge (star); shopping_list_header, shopping_app_bar (bookmark). Colours preserved. analyze clean. (BUT-944)

### Follow-ups to file
- Lint/codemod ban on raw `Icons.favorite`/`star`/`bookmark` (enforcement half of BUT-944).
- Colour convention decision (red likes vs theme-default favourites).

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos` + format
- [ ] code-reviewer + testing-specialist gates
- [ ] Commit, push
- [ ] BUT-944 → In Review + notify; file follow-ups

---
## ARCHIVED — iter-127 (BUT-1210 Done + BUT-1211 In Review; BUT-1212 filed) · iter-126 (BUT-914 In Review) · iter-125 (triage) · iter-124 (BUT-1209) · iter-123 (BUT-1204)
