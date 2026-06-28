/// Shared household entity — the symmetric, multi-user container both parents
/// (and any other adult members) belong to equally.
///
/// Distinct from the per-user "household" [FriendCategory] (isHousehold flag),
/// which is an owner-scoped allergen-aggregation list and is NOT symmetric.
/// This entity is a top-level `households/{id}` document modelled on
/// `GroupWeeklyMenuPlan` — a structured [members] list plus denormalised
/// [memberUserIds] / [memberPermissions] projections so Firestore rules can do
/// per-user membership and permission lookups (the rules language cannot filter
/// a list of maps).
///
/// It is the shared identity that scopes [DinerProfile]s and [FamilyRating]s:
/// a diner profile created by either parent carries this household's [id], so
/// both members see and edit it.
library;

import 'package:clock/clock.dart';
import 'package:butlery/core/types/app_timestamp.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart'
    show SharedListPermission;
import 'package:uuid/uuid.dart';

export 'package:butlery/models/unified/unified_shopping_list.dart'
    show SharedListPermission;

/// One member of a [Household].
///
/// Permission semantics (mirrors `SharedListPermission`):
/// - `view`  — read-only
/// - `edit`  — full read/write of household-scoped data (the default for adults)
/// - `admin` — edit + manage members + delete the household
class HouseholdMember {
  final String userId;
  final SharedListPermission permission;
  final DateTime addedAt;

  const HouseholdMember({
    required this.userId,
    required this.permission,
    required this.addedAt,
  });

  /// Whether this member can write household-scoped data (editor or admin).
  bool get canEdit =>
      permission == SharedListPermission.edit ||
      permission == SharedListPermission.admin;

  /// Whether this member can manage members / delete the household.
  bool get canAdmin => permission == SharedListPermission.admin;

  HouseholdMember copyWith({SharedListPermission? permission}) {
    return HouseholdMember(
      userId: userId,
      permission: permission ?? this.permission,
      addedAt: addedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'permission': permission.name,
    'addedAt': AppTimestamp.fromDateTime(addedAt).toFirestore(),
  };

  factory HouseholdMember.fromMap(Map<String, dynamic> data) {
    return HouseholdMember(
      userId: SerializationUtils.safeString(data, 'userId'),
      // Least-privilege fallback (matches GroupMenuParticipant): a missing or
      // unrecognised permission must NEVER silently grant write access.
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

  // Deliberately excludes addedAt (mirrors GroupMenuParticipant): two records
  // for the same (userId, permission) are equal regardless of when added.
  // Safe because members are only ever held in a List, never a Set/map key.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HouseholdMember &&
          other.userId == userId &&
          other.permission == permission;

  @override
  int get hashCode => Object.hash(userId, permission);
}

/// A shared household — a top-level document scoping the family's diner
/// profiles and family ratings.
class Household {
  final String id;
  final String name;
  final List<HouseholdMember> members;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  const Household({
    required this.id,
    required this.name,
    required this.members,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = 1,
  });

  /// Default Swedish household name.
  static const String defaultName = 'Vårt hushåll';

  /// Creates a new household with [creatorId] as the first admin member.
  factory Household.create({
    required String creatorId,
    String? name,
    List<HouseholdMember>? initialMembers,
  }) {
    final now = clock.now();
    assert(
      initialMembers == null ||
          initialMembers.any((m) => m.userId == creatorId),
      'createdBy must be among initialMembers',
    );
    final members =
        initialMembers ??
        [
          HouseholdMember(
            userId: creatorId,
            permission: SharedListPermission.admin,
            addedAt: now,
          ),
        ];
    return Household(
      id: const Uuid().v4(),
      name: name ?? defaultName,
      members: members,
      createdBy: creatorId,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Member lookup — null if [userId] is not a member.
  HouseholdMember? memberFor(String userId) {
    for (final m in members) {
      if (m.userId == userId) return m;
    }
    return null;
  }

  /// Whether [userId] has at least read access (i.e. is a member).
  bool isMember(String userId) => memberFor(userId) != null;

  /// Whether [userId] can write household-scoped data (editor or admin).
  bool canEdit(String userId) => memberFor(userId)?.canEdit ?? false;

  /// Whether [userId] can manage members / delete the household.
  bool canAdmin(String userId) => memberFor(userId)?.canAdmin ?? false;

  /// IDs-only mirror of [members] for Firestore `arrayContains` queries
  /// ("which household am I in?").
  List<String> get memberUserIds =>
      members.map((m) => m.userId).toList(growable: false);

  /// `{userId: permissionName}` map so Firestore rules can do per-user
  /// permission lookup via map-key access.
  Map<String, String> get memberPermissions => {
    for (final m in members) m.userId: m.permission.name,
  };

  /// Returns a copy with [userId] added as an [permission] member (no-op on
  /// the structured list if already present — caller should check first for
  /// permission upgrades).
  Household addMember(
    String userId, {
    SharedListPermission permission = SharedListPermission.edit,
  }) {
    if (isMember(userId)) return this;
    return copyWith(
      members: [
        ...members,
        HouseholdMember(
          userId: userId,
          permission: permission,
          addedAt: clock.now(),
        ),
      ],
      updatedAt: clock.now(),
    );
  }

  /// Returns a copy with [userId] removed from the member list.
  Household removeMember(String userId) {
    if (!isMember(userId)) return this;
    return copyWith(
      members: members.where((m) => m.userId != userId).toList(),
      updatedAt: clock.now(),
    );
  }

  /// [updatedAt] defaults to the existing value — pass an explicit
  /// `clock.now()` (as the mutation helpers do) to bump it.
  Household copyWith({
    String? name,
    List<HouseholdMember>? members,
    DateTime? updatedAt,
  }) {
    return Household(
      id: id,
      name: name ?? this.name,
      members: members ?? this.members,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      schemaVersion: schemaVersion,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'members': members.map((m) => m.toMap()).toList(),
    // Denormalised projections for Firestore rules + membership queries.
    'memberUserIds': memberUserIds,
    'memberPermissions': memberPermissions,
    'createdBy': createdBy,
    'createdAt': AppTimestamp.fromDateTime(createdAt).toFirestore(),
    'updatedAt': AppTimestamp.fromDateTime(updatedAt).toFirestore(),
    'schemaVersion': schemaVersion,
  };

  factory Household.fromMap(String id, Map<String, dynamic> data) {
    return Household(
      id: id,
      name: SerializationUtils.safeString(
        data,
        'name',
        defaultValue: defaultName,
      ),
      members: SerializationUtils.safeObjectList<HouseholdMember>(
        data,
        'members',
        HouseholdMember.fromMap,
      ),
      createdBy: SerializationUtils.safeString(data, 'createdBy'),
      createdAt: SerializationUtils.safeRequiredDateTime(data, 'createdAt'),
      updatedAt: SerializationUtils.safeRequiredDateTime(data, 'updatedAt'),
      schemaVersion: SerializationUtils.safeInt(
        data,
        'schemaVersion',
        defaultValue: 1,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'members': members.map((m) => m.toMap()).toList(),
    'createdBy': createdBy,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'schemaVersion': schemaVersion,
  };

  factory Household.fromJson(Map<String, dynamic> json) {
    return Household(
      id: SerializationUtils.safeString(json, 'id'),
      name: SerializationUtils.safeString(
        json,
        'name',
        defaultValue: defaultName,
      ),
      members: SerializationUtils.safeObjectList<HouseholdMember>(
        json,
        'members',
        HouseholdMember.fromMap,
      ),
      createdBy: SerializationUtils.safeString(json, 'createdBy'),
      createdAt:
          SerializationUtils.safeDateTime(json, 'createdAt') ?? clock.now(),
      updatedAt:
          SerializationUtils.safeDateTime(json, 'updatedAt') ?? clock.now(),
      schemaVersion: SerializationUtils.safeInt(
        json,
        'schemaVersion',
        defaultValue: 1,
      ),
    );
  }

  @override
  String toString() =>
      'Household(id: $id, name: $name, members: ${members.length})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Household && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
