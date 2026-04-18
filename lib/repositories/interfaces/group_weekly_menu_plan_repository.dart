import 'package:butlery/models/menu/group_weekly_menu_plan.dart';

/// Repository interface for group-scoped weekly menu plans (BUT-405).
///
/// Storage: top-level `group_weekly_menu_plans` collection. Documents are
/// keyed by the deterministic `{groupId}_{YYYY}-W{WW}` ID computed via
/// `GroupWeeklyMenuPlan.docIdFor`, so calling [save] for the same group+week
/// is an upsert (no duplicates ever).
///
/// Access control lives in Firestore rules (participant membership +
/// per-participant `SharedListPermission`) — the repo enforces only
/// internal self-consistency (doc-ID prefix matches `plan.groupId`).
abstract class GroupWeeklyMenuPlanRepository {
  /// Fetch the plan for the ISO week containing [weekStart] for [groupId].
  /// Returns `null` when no document exists yet — callers should treat that
  /// as an empty plan, not an error.
  Future<GroupWeeklyMenuPlan?> fetchForWeek({
    required String groupId,
    required DateTime weekStart,
  });

  /// Upsert the plan. Uses the deterministic doc ID; same `(groupId, week)`
  /// always overwrites the same document. Does NOT check per-participant
  /// edit permissions — that's the service layer's job.
  Future<void> save(GroupWeeklyMenuPlan plan);

  /// Delete every group plan belonging to [groupId] (for group cleanup).
  /// Returns the number of documents deleted.
  Future<int> deleteAllByGroup(String groupId);
}
