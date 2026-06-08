# Sprint Backlog

## Sprint: cook-snap visibility disclosure (BUT-901) — 2026-06-08 (iter-130) `[Tier B]`

**Step 0:** FITS. Cook snaps inherit the parent recipe's visibility (`isPublic` / `isCollaborative`)
and the user is never told at capture time. Current add-flow (`recipe_detail_view._showAddSnapSheet`)
picks a source → `vm.addSnap()` immediately, NO preview/confirm step. Insert a visibility-disclosure
confirm before upload. Reuses BUT-914's `commentVisibilityAudience` + `resolveCommentAudienceNames`
for the collaborative audience.

**Files touched:**
- NEW `lib/views/recipe_detail/cook_snap_visibility.dart` — pure `cookSnapAudience(recipe, currentUserId, friendNames)` → `(scope: public|shared|private, resolvedNames, total)`. Reuses comment_visibility helpers for the shared case.
- `lib/views/recipe_detail_view.dart` — `_showAddSnapSheet`: thread `recipe`; for public/shared scope show a disclosure confirm dialog before `addSnap`; private = unchanged (no friction).
- `lib/l10n/app_sv.arb` + `app_en.arb` — disclosure title/public-text/shared-text/confirm-button keys.
- NEW `test/unit/views/recipe_detail/cook_snap_visibility_test.dart` — pure-function tests (public/shared/private, name resolution, never-under-state).

**Blast radius:** only the cook-snap add path; additive confirm dialog. Private recipes unchanged.
comment_visibility helpers reused read-only (no change). recipe_detail_view (993 lines, accepted-large)
gains only the dialog call — logic lives in the new helper.

**Product-intent flag (note in In-Review):** confirm shown for public AND collaborative recipes
(both have an audience beyond self); private = no friction. Could be public-only if collaborative
friction is unwanted.

**Rollback:** revert the commit; disclosure is a self-contained addition.

**Deferred → follow-up:** per-snap visibility override (same-as-recipe / only-me) — needs a model
field on `CookSnap` + persistence + enforcement (Part 2 of the ticket).

- [x] **A1. `cookSnapAudience` pure helper + unit tests** `[Tier B]` — `cook_snap_visibility.dart` + 6 unit tests (public/shared/private, precedence, never-under-state). 6/6 green. (BUT-901)
- [x] **A2. Disclosure confirm dialog in the add-snap flow + l10n** `[Tier B]` — `recipe_detail_view._showAddSnapSheet` shows the disclosure for public/shared scope before `addSnap`; 4 l10n keys sv/en. analyze clean. (BUT-901)

### Post-Sprint Steps
- [ ] gen-l10n + `dart analyze --fatal-infos` + format
- [ ] code-reviewer + testing-specialist gates
- [ ] Commit, push; BUT-901 → In Review + notify; file Part-2 follow-up

---
## ARCHIVED — iter-129 (BUT-923 In Review) · iter-128 (BUT-944 In Review; BUT-1213) · iter-127 (BUT-1210 Done + BUT-1211 In Review; BUT-1212) · iter-126 (BUT-914 In Review)
