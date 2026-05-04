/// Service layer for group-scoped weekly menu plans.
///
/// Mirrors [WeeklyMenuPlanService] but scoped to a group instead of a user,
/// and adds per-participant permission checks before any mutation. The
/// service wraps the repository with:
///
/// - Fetch-or-build semantics for `getOrBuildWeek` (no persist).
/// - Permission gates (editor+ for entry mutations, admin for participant
///   management + delete).
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
  Future<GroupWeeklyMenuPlan?> getWeek({
    required String groupId,
    required DateTime date,
  }) async {
    return await executeServiceOperation<GroupWeeklyMenuPlan?>(
      () async {
        final weekStart = IsoWeekUtils.weekStartOf(date);
        return await _repository.fetchForWeek(
          groupId: groupId,
          weekStart: weekStart,
        );
      },
      operationName: 'getWeek',
    );
  }

  /// Load the plan, or build (in memory only) an empty one with [creatorId]
  /// as sole admin if none exists. Callers are responsible for calling
  /// [save] after mutating — this lets callers batch the "add entry +
  /// persist" flow into a single Firestore write instead of two.
  Future<GroupWeeklyMenuPlan> getOrBuildWeek({
    required String groupId,
    required String creatorId,
    required DateTime date,
    List<GroupMenuParticipant>? initialParticipants,
  }) async {
    final existing = await getWeek(groupId: groupId, date: date);
    if (existing != null) return existing;

    return GroupWeeklyMenuPlan.empty(
      groupId: groupId,
      creatorId: creatorId,
      date: date,
      initialParticipants: initialParticipants,
    );
  }

  /// Persist [plan]. Throws [PermissionDeniedException] when [actorId] is
  /// not an editor or admin on the plan. `lastModifiedBy` is stamped with
  /// [actorId] so audits always reflect the true writer.
  Future<void> save({
    required GroupWeeklyMenuPlan plan,
    required String actorId,
  }) async {
    _requireEditor(plan, actorId);
    final stamped = plan.copyWith(
      lastModifiedAt: clock.now(),
      lastModifiedBy: actorId,
    );
    await executeServiceOperation(
      () => _repository.save(stamped, userId: actorId),
      operationName: 'saveGroupWeeklyMenuPlan',
    );
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
    updated.add(WeeklyMenuPlanEntry.create(
      day: day,
      slot: slot,
      recipeId: recipe.id,
      recipeTitle: recipe.title,
      recipeImageUrl: recipe.primaryImageUrl,
    ));
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

    final without =
        plan.participants.where((p) => p.userId != participantUserId).toList();
    without.add(GroupMenuParticipant(
      userId: participantUserId,
      permission: permission,
      addedAt: clock.now(),
    ));
    return plan.copyWith(participants: without);
  }

  /// Admin-only: remove a participant. Refuses to remove the last admin —
  /// the service layer guards against an orphaned plan (rules also deny
  /// admin-field mutation that would leave zero admins, but that's a
  /// belt-and-braces second line of defence).
  GroupWeeklyMenuPlan removeParticipant({
    required GroupWeeklyMenuPlan plan,
    required String actorId,
    required String participantUserId,
  }) {
    _requireAdmin(plan, actorId);
    final target = plan.participantFor(participantUserId);
    if (target == null) return plan;

    final remaining =
        plan.participants.where((p) => p.userId != participantUserId).toList();
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
