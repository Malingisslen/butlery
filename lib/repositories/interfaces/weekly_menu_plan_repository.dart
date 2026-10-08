import 'package:butlery/core/exceptions/repository_exception.dart';
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
  ///
  /// Writes `plan.revId` and `plan.baseRevId` as they are; the caller mints
  /// them with `nextRevision()` (BUT-2215). Throws [WeekPlanConflictException]
  /// when the stored week is no longer the copy [plan] was built on.
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

/// BUT-2215: a week save was refused because the stored week is no longer the
/// copy the save was built on — another save (in practice the owner's other
/// device) landed first. [remote] is the week as the server holds it now.
class WeekPlanConflictException extends RepositoryException {
  final WeeklyMenuPlan remote;

  const WeekPlanConflictException(this.remote, {super.originalError})
    : super('The week was saved elsewhere first', code: 'week-plan-conflict');

  @override
  String toString() => 'WeekPlanConflictException';
}
