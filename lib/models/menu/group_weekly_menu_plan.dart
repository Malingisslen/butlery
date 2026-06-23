/// Group-scoped weekly menu plan.
///
/// Shares the same day/slot/entry shape as [WeeklyMenuPlan] but is keyed by
/// `{groupId}_{YYYY}-W{WW}` instead of by owner. Participants carry per-user
/// [SharedListPermission] permissions so the same doc supports read-only
/// members, editors, and admins in parallel.
///
/// Coexists alongside — not replacing — [WeeklyMenuPlan]. 1:1 conversations
/// keep writing to the creator's personal plan; group conversations get
/// their own collaborative plan here.
library;

import 'package:clock/clock.dart';
import 'package:butlery/core/types/app_timestamp.dart';
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart'
    show SharedListPermission;

// Re-export the day/slot + entry primitives so callers importing only this
// module don't need a second import for the shared enum/class types.
export 'package:butlery/models/menu/weekly_menu_plan.dart'
    show DayOfWeek, MealSlot, WeeklyMenuPlanEntry;

/// A single participant in a group weekly menu plan.
///
/// Permission semantics (mirrors `SharedListPermission` for shopping):
/// - `view`  — read-only (viewer)
/// - `edit`  — can add/move/remove entries (editor)
/// - `admin` — can edit entries + manage participants + delete the plan
class GroupMenuParticipant {
  final String userId;
  final SharedListPermission permission;
  final DateTime addedAt;

  const GroupMenuParticipant({
    required this.userId,
    required this.permission,
    required this.addedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'permission': permission.name,
      'addedAt': AppTimestamp.fromDateTime(addedAt).toFirestore(),
    };
  }

  factory GroupMenuParticipant.fromMap(Map<String, dynamic> data) {
    return GroupMenuParticipant(
      userId: SerializationUtils.safeString(data, 'userId'),
      permission: SerializationUtils.safeEnumByName(
        SharedListPermission.values,
        SerializationUtils.safeString(
          data,
          'permission',
          defaultValue: SharedListPermission.view.name,
        ),
        SharedListPermission.view,
      ),
      addedAt: SerializationUtils.safeRequiredDateTime(data, 'addedAt'),
    );
  }

  GroupMenuParticipant copyWith({
    SharedListPermission? permission,
    DateTime? addedAt,
  }) {
    return GroupMenuParticipant(
      userId: userId,
      permission: permission ?? this.permission,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  /// Whether this participant can edit entries (editor or admin).
  bool get canEdit =>
      permission == SharedListPermission.edit ||
      permission == SharedListPermission.admin;

  /// Whether this participant can delete the plan (admin only).
  bool get canAdmin => permission == SharedListPermission.admin;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupMenuParticipant &&
          other.userId == userId &&
          other.permission == permission;

  @override
  int get hashCode => Object.hash(userId, permission);
}

/// A group's collaborative planned meals for one ISO week, persisted as a
/// single Firestore document keyed by `{groupId}_{YYYY}-W{WW}`.
class GroupWeeklyMenuPlan {
  final String id;
  final String groupId;
  final DateTime weekStartDate;
  final List<WeeklyMenuPlanEntry> entries;
  final List<GroupMenuParticipant> participants;
  final DateTime createdAt;
  final DateTime lastModifiedAt;

  /// userId of the last writer. Nullable for empty-plan initial state;
  /// populated on the first save.
  final String? lastModifiedBy;

  const GroupWeeklyMenuPlan({
    required this.id,
    required this.groupId,
    required this.weekStartDate,
    required this.entries,
    required this.participants,
    required this.createdAt,
    required this.lastModifiedAt,
    this.lastModifiedBy,
  });

  /// Deterministic doc ID: `{groupId}_{YYYY}-W{WW}`. Mirrors the user-plan
  /// convention so upsert-by-ID works the same way.
  static String docIdFor(String groupId, DateTime date) =>
      IsoWeekUtils.weekIdFor(groupId, date);

  /// Creates an empty plan for the ISO week containing [date].
  ///
  /// [creatorId] becomes the first admin participant — they can always add
  /// more members later via the service layer.
  factory GroupWeeklyMenuPlan.empty({
    required String groupId,
    required String creatorId,
    required DateTime date,
    List<GroupMenuParticipant>? initialParticipants,
  }) {
    final weekStart = IsoWeekUtils.weekStartOf(date);
    final now = clock.now();
    final participants =
        initialParticipants ??
        [
          GroupMenuParticipant(
            userId: creatorId,
            permission: SharedListPermission.admin,
            addedAt: now,
          ),
        ];
    return GroupWeeklyMenuPlan(
      id: docIdFor(groupId, weekStart),
      groupId: groupId,
      weekStartDate: weekStart,
      entries: const [],
      participants: participants,
      createdAt: now,
      lastModifiedAt: now,
      lastModifiedBy: creatorId,
    );
  }

  /// Participant lookup — null if [userId] is not a participant.
  GroupMenuParticipant? participantFor(String userId) {
    for (final p in participants) {
      if (p.userId == userId) return p;
    }
    return null;
  }

  /// Whether [userId] has at least read access (i.e. is a participant).
  bool canRead(String userId) => participantFor(userId) != null;

  /// Whether [userId] has edit access (editor or admin).
  bool canEdit(String userId) => participantFor(userId)?.canEdit ?? false;

  /// Whether [userId] has admin access.
  bool canAdmin(String userId) => participantFor(userId)?.canAdmin ?? false;

  /// IDs-only convenience list (Firestore-queryable mirror of participants).
  List<String> get participantUserIds =>
      participants.map((p) => p.userId).toList(growable: false);

  /// `{userId: permissionName}` map, mirrors `unified_shared_shopping_lists.memberPermissions`.
  /// Serialized alongside the structured `participants` list so Firestore
  /// rules can do per-user permission lookup via map key access.
  Map<String, String> get memberPermissions => {
    for (final p in participants) p.userId: p.permission.name,
  };

  /// First entry at [day]/[slot], or null. Use for lunch/middag (single-recipe slots).
  WeeklyMenuPlanEntry? entryAt(DayOfWeek day, MealSlot slot) {
    for (final entry in entries) {
      if (entry.day == day && entry.slot == slot) return entry;
    }
    return null;
  }

  /// All entries at [day]/[slot], in insertion order.
  List<WeeklyMenuPlanEntry> entriesAt(DayOfWeek day, MealSlot slot) {
    return entries.where((e) => e.day == day && e.slot == slot).toList();
  }

  bool isOccupied(DayOfWeek day, MealSlot slot) => entryAt(day, slot) != null;

  bool get isEmpty => entries.isEmpty;
  bool get isNotEmpty => entries.isNotEmpty;

  GroupWeeklyMenuPlan copyWith({
    List<WeeklyMenuPlanEntry>? entries,
    List<GroupMenuParticipant>? participants,
    DateTime? lastModifiedAt,
    String? lastModifiedBy,
  }) {
    return GroupWeeklyMenuPlan(
      id: id,
      groupId: groupId,
      weekStartDate: weekStartDate,
      entries: entries ?? this.entries,
      participants: participants ?? this.participants,
      createdAt: createdAt,
      lastModifiedAt: lastModifiedAt ?? clock.now(),
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'groupId': groupId,
      'weekStartDate': AppTimestamp.fromDateTime(weekStartDate).toFirestore(),
      'entries': entries.map((e) => e.toMap()).toList(),
      'participants': participants.map((p) => p.toMap()).toList(),
      // Denormalised projections so Firestore rules can enforce access
      // without cracking open structured objects (rules language cannot
      // filter lists of maps). `memberPermissions` mirrors
      // `unified_shared_shopping_lists` — `{userId: 'view'|'edit'|'admin'}`.
      'participantUserIds': participantUserIds,
      'memberPermissions': memberPermissions,
      'createdAt': AppTimestamp.fromDateTime(createdAt).toFirestore(),
      'lastModifiedAt': AppTimestamp.fromDateTime(lastModifiedAt).toFirestore(),
      if (lastModifiedBy != null) 'lastModifiedBy': lastModifiedBy,
    };
  }

  factory GroupWeeklyMenuPlan.fromMap(String id, Map<String, dynamic> data) {
    final groupId = SerializationUtils.safeString(data, 'groupId');
    final weekStart = SerializationUtils.safeRequiredDateTime(
      data,
      'weekStartDate',
      defaultValue: clock.now(),
    );
    return GroupWeeklyMenuPlan(
      id: id,
      groupId: groupId,
      weekStartDate: weekStart,
      entries: SerializationUtils.safeObjectList<WeeklyMenuPlanEntry>(
        data,
        'entries',
        WeeklyMenuPlanEntry.fromMap,
      ),
      participants: SerializationUtils.safeObjectList<GroupMenuParticipant>(
        data,
        'participants',
        GroupMenuParticipant.fromMap,
      ),
      createdAt: SerializationUtils.safeRequiredDateTime(data, 'createdAt'),
      lastModifiedAt: SerializationUtils.safeRequiredDateTime(
        data,
        'lastModifiedAt',
      ),
      lastModifiedBy: SerializationUtils.safeNullableString(
        data,
        'lastModifiedBy',
      ),
    );
  }
}
