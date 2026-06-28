import 'package:butlery/models/family_rating.dart';
import 'package:butlery/repositories/interfaces/repository.dart';

/// Repository for [FamilyRating]s — private per-diner star verdicts in the
/// top-level `family_ratings` collection, scoped to a household.
///
/// Access is gated by household membership. Persistence enforces the 1–5 stars
/// invariant at the data boundary. Latest-verdict-wins is achieved via the
/// deterministic id (recipeId|memberId); the service layer preserves createdAt
/// on a re-rate by reading-then-updating.
abstract class FamilyRatingRepository extends Repository<FamilyRating> {
  /// All family ratings for [recipeId] within [householdId] (empty if the
  /// caller is not a member). Used to compute the family-average summary.
  Future<List<FamilyRating>> getForRecipe(String householdId, String recipeId);

  /// All family ratings within [householdId] (empty for a non-member).
  Future<List<FamilyRating>> getForHousehold(String householdId);
}
