/// Cleans the user-supplied text on a [Recipe] before it is written anywhere.
///
/// BUT-1819. This lived as a private method on `FirebaseRecipeRepository` until
/// it turned out a SECOND writer reaches the same collection without going
/// through the repository at all: `OfflineSyncManager` pushes
/// `recipe.toFirestore()` straight at `/users/{uid}/recipes` on EVERY offline
/// save that syncs — a recipe created offline, and an offline edit of one
/// created online. That is a service in another layer, so the function had to
/// become shared, and it is the live path most likely to be carrying raw
/// imported text.
///
/// It sits beside `html_sanitizer.dart` rather than in `lib/core/utils/` because
/// it imports both a model and a service, which no file in `core/utils` does
/// BOTH of today (three import one or the other); the repository already
/// imports from this directory. (An earlier draft said "2 of 30", which a
/// reviewer counted and disproved. The placement was right, the evidence for it
/// was invented.)
///
/// ## What it does and does not do
///
/// `sanitizeText` strips null bytes and control characters and folds Cyrillic
/// homoglyphs to Latin. **It does not remove HTML** — that is not this
/// function's job and nothing downstream relies on it doing so.
///
/// `sanitizeUrl` is the part that matters: it blanks a value containing
/// `javascript:`, `data:` or `vbscript:`. Note the patterns are UNANCHORED
/// substring matches, so a provenance sentence that merely contains `data:`
/// loses the whole field. That is accepted rather than unnoticed — see the
/// BUT-1819 entry in `docs/architecture/ACCEPTED_DEVIATIONS.md` — and it is why
/// the render guard in
/// `lib/core/utils/external_link.dart` is the user-facing protection rather than
/// this function alone.
library;

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/parsing/sanitizers/html_sanitizer.dart';

/// [recipe] with `title`, `description` and `sourceUrl` cleaned.
///
/// `ingredients` is passed through untouched, so a caller may test an
/// ingredient-derived predicate on the result and get the same answer it would
/// have got on the input.
///
/// **`updatedAt` is passed through explicitly, and that line is load-bearing.**
/// `Recipe.copyWith` defaults it to `clock.now()`, so cleaning a recipe would
/// otherwise restamp it, and a sanitize is not an edit. Two concrete costs:
/// `watchRecipes` and `loadMoreRecipes` both order on `core.updatedAt`, so a
/// restamp jumps the recipe to the top of the user's list for no reason the
/// user can see; and the object handed back to the caller would disagree with
/// the edit that produced it.
///
/// There is NO last-write-wins reconciliation behind this — an earlier version
/// of this comment invented one. The offline sync writes with `merge: true` and
/// no timestamp comparison anywhere, so the offline copy wins regardless.
/// Sort order and caller honesty are the real reasons.
///
/// **A behaviour change this introduced, named rather than left to be found:**
/// the private sanitizer this replaced used a bare `copyWith`, so `update()`
/// restamped on every call. It no longer does. The rule, rather than a roster
/// that goes stale: any caller that REUSES the stored `recipe.core` — every
/// membership operation in `RecipeMemberManager`, and `_grantAccessOnReshare` —
/// now leaves `updatedAt` alone, so those no longer re-sort the recipe. A
/// caller that goes through `copyWith` still restamps, which is what
/// `SocialRecipeMembershipService` does. That is the
/// better behaviour (a share is not an edit either), but it is a change.
/// It holds only where `ingredientsNormalized` is already CURRENT: `update`
/// runs its own `copyWith(ingredientsNormalized:)` whenever
/// `IngredientProcessor.needsNormalization` is true — which is
/// `getNormalizationIfNeeded(recipe) != null` — and THAT one restamps. That
/// fires on a null field, on a length mismatch and on a content mismatch — so
/// it covers recipes created offline (nothing on the offline path normalizes)
/// and any recipe whose ingredients were edited offline.
///
/// `dataChecksum` IS recomputed (passing `title` makes `copyWith` recompute it),
/// and that is correct — the checksum must describe the text actually stored.
/// The same recompute flips `dataIntegrityStatus` to `valid` in memory; the
/// field is derived on read and never serialized, so the effect stops at the
/// returned object.
Recipe sanitizeRecipeText(Recipe recipe) {
  final sanitizer = HtmlSanitizer.instance;
  return recipe.copyWith(
    title: sanitizer.sanitizeText(recipe.title),
    description: sanitizer.sanitizeText(recipe.description),
    sourceUrl: recipe.core.sourceUrl != null
        ? sanitizer.sanitizeUrl(recipe.core.sourceUrl!)
        : null,
    updatedAt: recipe.updatedAt,
  );
}

/// The denormalized recipe text a `shared_content` row carries, cleaned.
///
/// BUT-1819. Two writers put the same two facts into that collection under
/// DIFFERENT key names — `FirebaseSharedRecipeRepository.toFirestore` writes
/// `recipeTitle`/`recipeDescription`, `RecipeSharingManager` builds its own
/// payload with `title`/`description`. The spellings predate this ticket and
/// are not this ticket's to change; what is worth sharing is the DECISION, so
/// that a third field added later cannot land in only one of them.
///
/// This is the failure mode `ACCEPTED_DEVIATIONS.md` already names for this
/// collection: three sections implementing one decision separately is how they
/// drift. The drift that file RECORDS is a different pair of keys on the same
/// collection — the membership field, `sharedToUserIds` vs `sharedWithUserIds`
/// (2026-08-03) — not these two. Same collection, same failure mode, different
/// keys; do not read it as a record of this pair drifting.
///
/// Hygiene rather than a hole: no LINK-TARGET url is copied on either path.
/// URLs ARE copied — `recipeImageUrl` on the repository path, `imageUrl` and
/// `sharedByAvatarUrl` on the manager's. The property that matters, and the
/// one to re-check if a reader is added: **none of the three is passed to a
/// launcher by any reader of this collection.** Those that render at all
/// render images (e.g. `shared_recipe_card.dart`); the rest copy or null-check
/// the value. That "e.g." is deliberate — FOUR attempts to enumerate these
/// readers were each one short, including one written to fix the last. Verify
/// the property against the LAUNCHERS, which are a closed set a single grep
/// finds; the readers are not. An earlier version said "no URL is copied", which is simply false
/// and was a false reassurance about a security property in the doc of the
/// helper that provides it. Flutter renders the text literally.
({String title, String description}) sanitizeSharedRecipeText(
  String title,
  String description,
) {
  final sanitizer = HtmlSanitizer.instance;
  return (
    title: sanitizer.sanitizeText(title),
    description: sanitizer.sanitizeText(description),
  );
}
