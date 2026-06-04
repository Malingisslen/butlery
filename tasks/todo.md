# Sprint Backlog

## Sprint: a11y state-change announcements (recipe detail) — 2026-06-04 (iter-112)

Clean tree on main (prior commits …23ac13e5d, 0cbd81cb0). BUT-905 (a11y `SemanticsService.announce`
on state changes). Step-0: the 4 listed sites split — favorite + comment are clean view-layer sites
with context; shopping-bought is behind an `onToggleItem` callback indirection and OCR-complete has
no clear view site. Scoping to the two clean recipe-detail surfaces; follow-up for the other two.

### Agent A: a11y — recipe-detail announcements
- [ ] **A1. BUT-905 (recipe-detail slice)** `[Tier A]` — screen-reader announcements:
      - Favorite toggle (`recipe_detail_view.dart:341`) → announce favorited/unfavorited after the
        async toggle, based on `viewModel.recipe.isFavorite`.
      - Comment posted (`recipe_social_handler.postComment`) → announce after the success snackbar.
      - l10n keys: `a11yRecipeFavorited`, `a11yRecipeUnfavorited`, `a11yCommentPosted` (sv/en).
      - Tier A (screen-reader only, no visual surface) → closes Done.
      - Follow-up filed for the shopping-bought + OCR-complete sites (callback/flow indirection).

### Needs you (Tier D / deferred — carried)
- BUT-1169, BUT-838, BUT-934, BUT-1187, onRecipeDeleted gen-2 deploy.

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos`
- [ ] Commit, push
- [ ] Linear: Done (Tier A); file follow-up for shopping/OCR announcements

---

## ARCHIVED — iter-111: online-status privacy opt-out (shipped 0cbd81cb0)
BUT-912 → In Review. 3 review-caught bugs fixed (persist, dirty-detect, last-active leak).

## ARCHIVED — iter-110/109/108/107/106
918 analytics transparency (23ac13e5d); 1039 bulk-unblock (f33b0f708); 1037 import cost-guard
(64be6fd1f); 1199 gesture hints (ba7c7a4e3); 5 Tier-A + 1198 (9c8946120).
