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
}
