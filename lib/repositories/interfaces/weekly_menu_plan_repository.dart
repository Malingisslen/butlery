import 'package:butlery/models/menu/weekly_menu_plan.dart';

/// Repository interface for per-user weekly menu plans.
///
/// Storage: top-level `weekly_menu_plans` collection. Documents are keyed by
/// the deterministic `{userId}_{YYYY}-W{WW}` ID computed via
/// `IsoWeekUtils.weekIdFor`, so calling [save] for the same user+week is an
/// upsert (no duplicates ever).
abstract class WeeklyMenuPlanRepository {
  /// Fetch the plan for the ISO week containing [weekStart] for [userId].
  /// Returns `null` when no document exists yet — callers should treat that
  /// as an empty plan, not an error.
  Future<WeeklyMenuPlan?> fetchForWeek({
    required String userId,
    required DateTime weekStart,
  });

  /// Upsert the plan. Uses the deterministic doc ID; same `(userId, week)`
  /// always overwrites the same document.
  Future<void> save(WeeklyMenuPlan plan);

  /// Delete every weekly plan owned by [userId] (for GDPR cascade).
  /// Returns the number of documents deleted.
  Future<int> deleteAllByUser(String userId);

  /// Export every weekly plan owned by [userId] for GDPR Article 20.
  /// Returns raw `{id, data}` shapes for the export pipeline. Implementations
  /// MUST validate that the caller owns [userId].
  Future<List<Map<String, dynamic>>> exportAllByUser(
    String userId, {
    int maxDocuments = 260,
  });

  /// BUT-893: scrub [recipeId] from every weekly plan owned by [userId].
  /// Returns the number of plans actually changed (no-op when the recipe
  /// was never referenced). Used to keep menu slots from going blank when
  /// the source recipe is deleted.
  Future<int> removeRecipeFromAllPlans({
    required String userId,
    required String recipeId,
  });
}
