import 'package:butlery/models/menu/group_weekly_menu_plan.dart';

/// Repository interface for group-scoped weekly menu plans.
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
  /// always overwrites the same document.
  ///
  /// When [userId] is provided, the repo also runs its
  /// `validateUpdatePermission` check (editor+ on the plan) before
  /// writing — belt-and-braces alongside Firestore rules. When null, only
  /// the doc-ID/groupId self-consistency check runs.
  Future<void> save(GroupWeeklyMenuPlan plan, {String? userId});

  /// Delete every group plan belonging to [groupId] (for group cleanup).
  /// Returns the number of documents deleted.
  Future<int> deleteAllByGroup(String groupId);

  /// Stream the plan document for [groupId] + the ISO week containing
  /// [date]. Emits `null` when the doc does not exist yet (callers render
  /// an empty-plan state) and a parsed `GroupWeeklyMenuPlan` on every
  /// subsequent change.
  Stream<GroupWeeklyMenuPlan?> watchForWeek({
    required String groupId,
    required DateTime date,
  });

  /// Export every group plan that [userId] is a participant on, for
  /// GDPR Article 20. Match is via the denormalised
  /// `memberPermissions.{userId}` map. Returns raw `{id, data}` shapes.
  /// Implementations MUST validate that the caller IS [userId] (a user
  /// can only export their own portability scope, not someone else's
  /// group memberships).
  Future<List<Map<String, dynamic>>> exportPlansForParticipant(
    String userId, {
    int maxDocuments = 260,
  });
}
