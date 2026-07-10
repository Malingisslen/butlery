import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/family_rating.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart' as auth;
import 'package:butlery/repositories/interfaces/family_rating_repository.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';

/// Records and reads private, per-member family ratings — the household-internal
/// rating system, kept separate from the public social rating.
///
/// Three rules define this service:
/// 1. **No own-recipe block.** The social rating forbids rating your own recipe
///    (you can't pad a *public* score). Inside a household that restriction makes
///    no sense — a parent rating a recipe they invented is valid — so this path
///    deliberately bypasses it.
/// 2. **Latest-verdict-wins.** There is one rating per (recipe, member), keyed by
///    the deterministic [FamilyRating.buildId]; re-rating overwrites the stars and
///    preserves the original `createdAt` (which the Firestore rules pin immutable).
/// 3. **Adult hybrid.** When an adult account holder rates themselves on their own
///    device, the verdict is also mirrored to their personal/social rating (still
///    subject to the social own-recipe block). A proxy entry — someone entering on
///    a shared phone for another member — only writes the family entry, attributed
///    via `enteredByUid` ("inmatat av X"), and never touches that member's personal
///    rating.
class FamilyRatingService extends BaseService {
  @override
  String get serviceName => 'FamilyRatingService';

  FamilyRatingRepository get _ratings =>
      ServiceLocator.get<FamilyRatingRepository>();
  UnifiedRecipeService get _recipeService =>
      ServiceLocator.get<UnifiedRecipeService>();

  /// Record [member]'s star verdict on [recipeId]. Upserts (latest-verdict-wins)
  /// and, for an adult self-rating on their own device, mirrors to the personal
  /// rating. Returns the persisted [FamilyRating], or `null` if the write failed
  /// or the caller is not a household member (the repository enforces that).
  Future<FamilyRating?> rateAsFamily({
    required String recipeId,
    required String householdId,
    required String memberId,
    required HouseholdMemberType memberType,
    required int stars,
    required String enteredByUid,
  }) async {
    return executeServiceOperation(
      () => _rateAsFamily(
        recipeId: recipeId,
        householdId: householdId,
        memberId: memberId,
        memberType: memberType,
        stars: stars,
        enteredByUid: enteredByUid,
      ),
      operationName: 'rateAsFamily',
    );
  }

  Future<FamilyRating> _rateAsFamily({
    required String recipeId,
    required String householdId,
    required String memberId,
    required HouseholdMemberType memberType,
    required int stars,
    required String enteredByUid,
  }) async {
    final saved = await _upsert(
      FamilyRating.create(
        recipeId: recipeId,
        householdId: householdId,
        memberId: memberId,
        memberType: memberType,
        stars: stars,
        enteredByUid: enteredByUid,
      ),
    );

    // Refresh the denormalized family average on the recipe so the card pill
    // reflects this verdict without a per-card read. Best-effort + owned-only
    // (see helper) — never fails the rating.
    await _denormalizeFamilyAverage(recipeId, householdId);

    // Adult hybrid: mirror only a genuine self-rating to the personal/social
    // rating. `social.rateRecipe` re-applies the own-recipe block, so a parent
    // rating their own recipe still lands the family entry but not a public one.
    // The mirror is best-effort: the family entry is the source of truth, so a
    // social-layer failure must never bubble up and make the (already persisted)
    // family write look failed to the caller.
    if (_isSelfRating(saved)) {
      try {
        await _recipeService.social.rateRecipe(
          recipeId: recipeId,
          rating: stars.toDouble(),
        );
      } catch (e) {
        AppLogger.warning(
          'FamilyRatingService: social mirror failed, family entry kept: $e',
        );
      }
    }

    return saved;
  }

  /// Recompute the household's average for [recipeId] and write it onto the
  /// recipe's denormalized `core.familyAverage`/`core.familyRatingCount` so
  /// list cards render the family pill without reading the rating store per
  /// card.
  ///
  /// Owned-only by nature: only the household's OWN personal recipe copy
  /// (stored at `users/{uid}/recipes/{recipeId}`) is patched. A community or
  /// another member's recipe keeps a null family pill until the deferred
  /// aggregate function ships.
  ///
  /// BUT-1505: this is a read-then-write on the recipe doc, so a second
  /// concurrent verdict (two members rating on a shared phone, or the same
  /// account on two devices) used to lose the first write — the old path read
  /// the recipe from the in-memory cache and rewrote the WHOLE doc, clobbering
  /// the other verdict and any unrelated field. It now runs inside a Firestore
  /// transaction that reads the recipe doc as the conflict anchor and writes
  /// ONLY the two family fields; a conflicting commit retries and recomputes
  /// from the authoritative rating store. `core.updatedAt` is left untouched so
  /// a rating never reorders "recently updated". Still best-effort — a failure
  /// is logged and never fails the rating.
  Future<void> _denormalizeFamilyAverage(
    String recipeId,
    String householdId,
  ) async {
    try {
      // Not in the user's own list, or not a personal recipe we own → nothing
      // to patch (community recipe, another member's copy, or a cold cache);
      // the family pill stays null until a later rate/load.
      final recipe = _recipeService.getRecipeById(recipeId);
      if (recipe == null || !recipe.isPersonal) return;

      final uid = ServiceLocator.get<auth.AuthRepository>().currentUserId;
      if (uid == null) return;

      final firestore = ServiceLocator.get<FirestoreRepository>().firestore;
      final recipeRef = firestore
          .collection(FirestoreCollections.users)
          .doc(uid)
          .collection(FirestoreCollections.recipes)
          .doc(recipeId);

      FamilyRatingSummary? committed;
      await firestore.runTransaction((txn) async {
        // Conflict anchor: a concurrent denormalization writing this same
        // recipe doc forces the transaction to retry and recompute from the
        // authoritative rating store below.
        final snap = await txn.get(recipeRef);
        if (!snap.exists) return;

        final ratings = await _ratings.getForRecipe(householdId, recipeId);
        final summary = FamilyRatingSummary.fromRatings(recipeId, ratings);
        committed = summary;

        // Partial update — only the denormalized family fields, so a
        // concurrent edit to any other recipe field is never clobbered.
        txn.update(recipeRef, {
          'core.familyAverage': summary.hasRatings
              ? summary.familyAverage
              : null,
          'core.familyRatingCount': summary.hasRatings
              ? summary.familyRatingCount
              : null,
        });
      });

      // Mirror the committed values onto the in-memory recipe so the card pill
      // refreshes without a reload (the prior updateRecipe path notified too).
      final result = committed;
      if (result != null) {
        recipe.core.familyAverage = result.hasRatings
            ? result.familyAverage
            : null;
        recipe.core.familyRatingCount = result.hasRatings
            ? result.familyRatingCount
            : null;
        _recipeService.notifyListeners();
      }
    } catch (e) {
      AppLogger.warning(
        'FamilyRatingService: family-average denormalization failed '
        '(rating kept): $e',
      );
    }
  }

  /// A real account holder entering their own verdict on their own device — the
  /// only case the personal-rating mirror should fire. Proxy entries and diner
  /// profiles never mirror.
  bool _isSelfRating(FamilyRating rating) =>
      rating.memberType == HouseholdMemberType.user &&
      rating.enteredByUid == rating.memberId;

  /// Upsert preserving the original `createdAt` on re-rating (the rules pin it
  /// immutable). `copyWith` keeps id/createdAt and bumps `lastUpdatedAt`.
  Future<FamilyRating> _upsert(FamilyRating rating) async {
    final existing = await _ratings.read(rating.id);
    if (existing == null) {
      return _ratings.create(rating);
    }
    final updated = existing.copyWith(
      stars: rating.stars,
      enteredByUid: rating.enteredByUid,
    );
    await _ratings.update(updated);
    return updated;
  }

  /// Remove a member's verdict (un-rate). No-op tolerant — the repository
  /// membership check still applies.
  ///
  /// Symmetric to [rateAsFamily]: it re-denormalizes the recipe's family
  /// average (so the card pill drops when the last verdict goes), and retracts
  /// the adult self-rater's personal/social rating so the public aggregate is
  /// never left with an orphaned rating the family no longer stands behind.
  /// Only a genuine self-rate ever mirrored out, so only it un-mirrors; the
  /// retraction is best-effort (the family entry is already gone).
  Future<void> removeRating({
    required String recipeId,
    required String memberId,
  }) async {
    await executeServiceOperation(() async {
      final id = FamilyRating.buildId(recipeId, memberId);
      final existing = await _ratings.read(id);
      await _ratings.delete(id);
      if (existing == null) return;

      await _denormalizeFamilyAverage(recipeId, existing.householdId);

      if (_isSelfRating(existing)) {
        try {
          await _recipeService.social.removeRating(recipeId);
        } catch (e) {
          AppLogger.warning(
            'FamilyRatingService: social un-mirror failed, family entry '
            'already removed: $e',
          );
        }
      }
    }, operationName: 'removeRating');
  }

  /// The household's aggregate for one recipe — the value the "familj" pill
  /// renders. Returns an empty summary when there are no ratings or the caller
  /// is not a member.
  Future<FamilyRatingSummary> getSummaryForRecipe({
    required String householdId,
    required String recipeId,
  }) async {
    final ratings = await _memberRatings(householdId, recipeId);
    return FamilyRatingSummary.fromRatings(recipeId, ratings);
  }

  /// Every member's verdict on one recipe (for the detail-page breakdown).
  Future<List<FamilyRating>> getMemberRatings({
    required String householdId,
    required String recipeId,
  }) async {
    return _memberRatings(householdId, recipeId);
  }

  Future<List<FamilyRating>> _memberRatings(
    String householdId,
    String recipeId,
  ) async {
    final result = await executeServiceOperation(
      () => _ratings.getForRecipe(householdId, recipeId),
      operationName: 'getMemberRatings',
    );
    if (result == null) {
      AppLogger.debug('No family ratings resolved for recipe $recipeId');
    }
    return result ?? const <FamilyRating>[];
  }
}
