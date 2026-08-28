/// Service layer for group-scoped weekly menu plans.
///
/// Mirrors [WeeklyMenuPlanService] but scoped to a group instead of a user,
/// and adds per-participant permission checks. The service wraps the
/// repository with:
///
/// - Fetch-or-build semantics for `getOrBuildWeek` (no persist).
/// - Permission gates (editor+ for entry mutations, admin for participant
///   management). Read each method — they differ.
/// - Pure helper methods (`addEntry`, `removeEntry`, `moveEntry`) that
///   return updated plans without persisting — callers pick when to save
///   so multiple edits can batch into one Firestore write.
library;

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/models/menu/group_weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:clock/clock.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart'
    show SharedListPermission;
import 'package:butlery/repositories/interfaces/group_weekly_menu_plan_repository.dart';

/// Outcome of a group weekly-plan read (BUT-1928).
///
/// A bare `GroupWeeklyMenuPlan?` spells two different situations the same way:
/// the group has no plan for that week, and the fetch never answered. Only the
/// first is safe to build an empty plan on top of and save.
///
/// [plan] is null when the week has no saved plan, and always null when
/// [readFailed] is true.
class GroupWeeklyMenuPlanRead {
  final GroupWeeklyMenuPlan? plan;
  final bool readFailed;

  const GroupWeeklyMenuPlanRead({required this.plan, required this.readFailed});
}

class GroupWeeklyMenuPlanService extends BaseService {
  final GroupWeeklyMenuPlanRepository _repository;

  GroupWeeklyMenuPlanService({
    required GroupWeeklyMenuPlanRepository repository,
  }) : _repository = repository;

  @override
  String get serviceName => 'GroupWeeklyMenuPlanService';

  /// Loads the saved plan for the ISO week containing [date], or returns
  /// `null` when the group has no plan for that week yet.
  ///
  /// Caller-side read permission is enforced by Firestore rules; this
  /// method does not re-check because a forged read would fail at the
  /// wire before reaching us.
  /// A failed read is reported as `null` here, indistinguishable from "no plan
  /// yet". Callers that go on to SAVE use [readWeek] or [readOrBuildWeek].
  Future<GroupWeeklyMenuPlan?> getWeek({
    required String groupId,
    required DateTime date,
  }) async {
    return (await readWeek(groupId: groupId, date: date)).plan;
  }

  /// [getWeek] plus the one bit it cannot return: whether the fetch actually
  /// answered (BUT-1928).
  ///
  /// `readFailed` is true when the wrapped read did not answer — a throwing
  /// repository or a failed auth pre-flight — because either leaves the caller
  /// holding a null plan that does not describe what is saved. A repository
  /// that maps an unreachable week to null rather than throwing is NOT covered:
  /// that route reports `readFailed: false` and is indistinguishable here from
  /// a week with nothing saved.
  Future<GroupWeeklyMenuPlanRead> readWeek({
    required String groupId,
    required DateTime date,
  }) async {
    // A nullable inside a nullable cannot tell "no plan" from "no answer", so
    // the sentinel is the WRAPPER: a null wrapper is the failure.
    final read = await executeServiceOperation<GroupWeeklyMenuPlanRead>(
      () async {
        final weekStart = IsoWeekUtils.weekStartOf(date);
        return GroupWeeklyMenuPlanRead(
          plan: await _repository.fetchForWeek(
            groupId: groupId,
            weekStart: weekStart,
          ),
          readFailed: false,
        );
      },
      operationName: 'getWeek',
    );
    return read ?? const GroupWeeklyMenuPlanRead(plan: null, readFailed: true);
  }

  /// Load the plan, or build (in memory only) an empty one with [creatorId]
  /// as sole admin if none exists. Callers are responsible for calling
  /// [save] after mutating — this lets callers batch the "add entry +
  /// persist" flow into a single Firestore write instead of two.
  ///
  /// Builds on a failed read too, which is why a caller that saves the result
  /// uses [readOrBuildWeek] instead.
  Future<GroupWeeklyMenuPlan> getOrBuildWeek({
    required String groupId,
    required String creatorId,
    required DateTime date,
    List<GroupMenuParticipant>? initialParticipants,
  }) async {
    final read = await readOrBuildWeek(
      groupId: groupId,
      creatorId: creatorId,
      date: date,
      initialParticipants: initialParticipants,
    );
    return read.plan ??
        GroupWeeklyMenuPlan.empty(
          groupId: groupId,
          creatorId: creatorId,
          date: date,
          initialParticipants: initialParticipants,
        );
  }

  /// [getOrBuildWeek] that tells the caller whether the read FAILED instead of
  /// answering it with a freshly built empty plan (BUT-1928).
  ///
  /// The group rule carries the same `createdAt` conjunct as the personal one
  /// (G1 in `weekly-menu-plans-rules.test.ts`), so writing that empty plan over
  /// a stored week is refused rather than destructive.
  ///
  /// `plan` is non-null exactly when `readFailed` is false.
  Future<GroupWeeklyMenuPlanRead> readOrBuildWeek({
    required String groupId,
    required String creatorId,
    required DateTime date,
    List<GroupMenuParticipant>? initialParticipants,
  }) async {
    final read = await readWeek(groupId: groupId, date: date);
    if (read.readFailed) return read;

    return GroupWeeklyMenuPlanRead(
      plan:
          read.plan ??
          GroupWeeklyMenuPlan.empty(
            groupId: groupId,
            creatorId: creatorId,
            date: date,
            initialParticipants: initialParticipants,
          ),
      readFailed: false,
    );
  }

  /// Persist [plan]. Throws [PermissionDeniedException] when [actorId] is
  /// not an editor or admin on the plan — and, since the wrapper was removed,
  /// whatever else the repository raises: a `StateError` for a mis-keyed doc
  /// id, an `AuthenticationException` from the audit call, or the Firestore
  /// failure itself. `lastModifiedBy` is stamped with [actorId] so audits
  /// always reflect the true writer.
  Future<void> save({
    required GroupWeeklyMenuPlan plan,
    required String actorId,
  }) async {
    _requireEditor(plan, actorId);
    final stamped = plan.copyWith(
      lastModifiedAt: clock.now(),
      lastModifiedBy: actorId,
    );
    // Not wrapped in `executeServiceOperation` — same reason as the per-user
    // service: it answers a failure with a default, which for a write makes a
    // refusal indistinguishable from a save (BUT-1962). The only live caller
    // is the meal-poll close, where swallowing meant the poll burned its
    // one-way close with no winner in the plan.
    await _repository.save(stamped, userId: actorId);
  }

  /// Add a single recipe to a (day, slot). For lunch/middag, replaces any
  /// existing entry; for övrigt, appends. Pure — does not persist.
  GroupWeeklyMenuPlan addEntry({
    required GroupWeeklyMenuPlan plan,
    required String actorId,
    required DayOfWeek day,
    required MealSlot slot,
    required Recipe recipe,
  }) {
    _requireEditor(plan, actorId);
    final updated = List<WeeklyMenuPlanEntry>.from(plan.entries);
    if (!slot.isMulti) {
      updated.removeWhere((e) => e.day == day && e.slot == slot);
    }
    updated.add(
      WeeklyMenuPlanEntry.create(
        day: day,
        slot: slot,
        recipeId: recipe.id,
        recipeTitle: recipe.title,
        recipeImageUrl: recipe.primaryImageUrl,
      ),
    );
    return plan.copyWith(entries: updated);
  }

  /// Remove an entry by id. Returns the same plan unchanged if the id is
  /// missing, so the caller can short-circuit.
  GroupWeeklyMenuPlan removeEntry({
    required GroupWeeklyMenuPlan plan,
    required String actorId,
    required String entryId,
  }) {
    _requireEditor(plan, actorId);
    final updated = plan.entries.where((e) => e.id != entryId).toList();
    if (updated.length == plan.entries.length) return plan;
    return plan.copyWith(entries: updated);
  }

  /// Move an entry to a new (day, slot). Swap semantics match
  /// [WeeklyMenuPlanService.moveEntry].
  GroupWeeklyMenuPlan moveEntry({
    required GroupWeeklyMenuPlan plan,
    required String actorId,
    required String entryId,
    required DayOfWeek toDay,
    required MealSlot toSlot,
  }) {
    _requireEditor(plan, actorId);
    final source = plan.entries.firstWhere(
      (e) => e.id == entryId,
      orElse: () => throw StateError('Entry $entryId not found'),
    );
    if (source.day == toDay && source.slot == toSlot) return plan;

    final updated = List<WeeklyMenuPlanEntry>.from(plan.entries);
    updated.removeWhere((e) => e.id == entryId);

    if (!toSlot.isMulti) {
      final occupantIndex = updated.indexWhere(
        (e) => e.day == toDay && e.slot == toSlot,
      );
      if (occupantIndex != -1) {
        final occupant = updated[occupantIndex];
        updated[occupantIndex] = occupant.copyWith(
          day: source.day,
          slot: source.slot,
        );
      }
    }
    updated.add(source.copyWith(day: toDay, slot: toSlot));
    return plan.copyWith(entries: updated);
  }

  /// Admin-only: add a participant (with the given permission) to the
  /// plan. No-op if already present with the same permission.
  GroupWeeklyMenuPlan addParticipant({
    required GroupWeeklyMenuPlan plan,
    required String actorId,
    required String participantUserId,
    SharedListPermission permission = SharedListPermission.edit,
  }) {
    _requireAdmin(plan, actorId);
    final existing = plan.participantFor(participantUserId);
    if (existing != null && existing.permission == permission) return plan;

    final without = plan.participants
        .where((p) => p.userId != participantUserId)
        .toList();
    without.add(
      GroupMenuParticipant(
        userId: participantUserId,
        permission: permission,
        addedAt: clock.now(),
      ),
    );
    return plan.copyWith(participants: without);
  }

  /// Admin-only: remove a participant. Refuses to remove the last admin —
  /// the service layer guards against an orphaned plan.
  GroupWeeklyMenuPlan removeParticipant({
    required GroupWeeklyMenuPlan plan,
    required String actorId,
    required String participantUserId,
  }) {
    _requireAdmin(plan, actorId);
    final target = plan.participantFor(participantUserId);
    if (target == null) return plan;

    final remaining = plan.participants
        .where((p) => p.userId != participantUserId)
        .toList();
    final remainingAdmins = remaining
        .where((p) => p.permission == SharedListPermission.admin)
        .length;
    if (remainingAdmins == 0) {
      throw StateError('Cannot remove last admin from plan ${plan.id}');
    }
    return plan.copyWith(participants: remaining);
  }

  /// Delete every group plan belonging to [groupId] (used when a group
  /// conversation is deleted). No per-participant permission check — the
  /// caller is assumed to have group-level admin rights.
  Future<int> deleteAllByGroup(String groupId) async {
    return await executeServiceOperation<int>(
          () => _repository.deleteAllByGroup(groupId),
          operationName: 'deleteAllByGroup',
        ) ??
        0;
  }

  void _requireEditor(GroupWeeklyMenuPlan plan, String actorId) {
    if (!plan.canEdit(actorId)) {
      throw PermissionDeniedException(
        'User $actorId lacks edit permission on plan ${plan.id}',
        resource: plan.id,
        operation: 'edit',
        userId: actorId,
      );
    }
  }

  void _requireAdmin(GroupWeeklyMenuPlan plan, String actorId) {
    if (!plan.canAdmin(actorId)) {
      throw PermissionDeniedException(
        'User $actorId lacks admin permission on plan ${plan.id}',
        resource: plan.id,
        operation: 'admin',
        userId: actorId,
      );
    }
  }
}
