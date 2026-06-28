import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/family_rating.dart';
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
  /// NOTE (deferred): the symmetric mirror — retracting an adult self-rater's
  /// personal/social rating — is intentionally not done here yet. There is no
  /// family un-rate UI until Phase 3; wiring `social.removeRating` now would be
  /// speculative and untested. Add it alongside the un-rate entry point so the
  /// social aggregate isn't left with an orphaned rating.
  Future<void> removeRating({
    required String recipeId,
    required String memberId,
  }) async {
    await executeServiceOperation(
      () => _ratings.delete(FamilyRating.buildId(recipeId, memberId)),
      operationName: 'removeRating',
    );
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
