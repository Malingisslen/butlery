/// P5-U26b: a version of the user's own that another person's save overwrote.
///
/// produktregler.md:109: "ingen strategi får tyst kasta data som bara finns
/// lokalt. Där strategin skriver över sparas den överskrivna versionen i 30
/// dagar och nås via Återställ." The table row for the week menu
/// (produktregler.md:104) gives it the 30 s snackbar first and "Återställ i
/// 30 dagar" after; flows-roles-budget.md:36 repeats that. PQ-01 = A (Malin,
/// 2026-09-23) scopes this to the week menu and the user's own recipe.
///
/// Where it lives: `users/{uid}/overwritten_versions/{id}`, on the server and
/// owned by the user whose version was overwritten (Q-A12, produktregler.md
/// :123 "Varje entitet har 30 dagars operationshistorik. Det är den som
/// Återställ läser"). firestore.rules lets only that user read, create and
/// delete it, and never update it. [expiresAt] is what the Firestore TTL policy
/// deletes on (firestore.indexes.json), and it is also the line after which
/// the app stops offering it, so nothing is shown past 30 days even while the
/// TTL sweep has not reached the row yet.
///
/// Identity is the document id, never the resource's title, a row number or
/// the time it was kept.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';

/// One overwritten version, kept for [OverwrittenVersion.keptFor].
class OverwrittenVersion {
  const OverwrittenVersion({
    required this.id,
    required this.ownerId,
    required this.entity,
    required this.resourceType,
    required this.resourceId,
    required this.version,
    required this.overwrittenBy,
    required this.overwrittenByName,
    required this.overwrittenAt,
    required this.expiresAt,
  });

  /// How long an overwritten version is kept (produktregler.md:104, :109).
  static const Duration keptFor = Duration(days: 30);

  /// The entities whose overwritten versions are kept (PQ-01 = A): the week
  /// menu and the user's own recipe. Everything else is BUT-2140.
  static const Set<ConflictEntity> keptEntities = {
    ConflictEntity.weekMenu,
    ConflictEntity.recipeOwn,
  };

  /// Firestore document id. Empty until the repository has stored it.
  final String id;

  /// The user whose version this is, and the only one who may read it.
  final String ownerId;

  /// Which conflict rule overwrote it.
  final ConflictEntity entity;

  /// What kind of resource [version] is, so it can be parsed back.
  final RealtimeResourceType resourceType;

  /// The realtime resource the version belongs to.
  final String resourceId;

  /// The overwritten version itself, serialized as the resource's own
  /// `toFirestore()` map.
  final Map<String, dynamic> version;

  /// Who saved over it (a user id) and the name shown for them.
  final String overwrittenBy;
  final String overwrittenByName;

  /// When it was overwritten, and when it stops being kept (exactly
  /// [keptFor] later; firestore.rules checks that).
  final DateTime overwrittenAt;
  final DateTime expiresAt;

  /// Captures [lost], which [winner] overwrote at [at], for [ownerId].
  factory OverwrittenVersion.capture({
    required String ownerId,
    required ConflictEntity entity,
    required RealtimeResource lost,
    required RealtimeResource winner,
    required DateTime at,
  }) {
    final overwrittenAt = at.toUtc();
    return OverwrittenVersion(
      id: '',
      ownerId: ownerId,
      entity: entity,
      resourceType: lost.type,
      resourceId: lost.id,
      version: lost.toFirestore(),
      overwrittenBy: winner.lastEditedBy,
      overwrittenByName: winner.lastEditedByDisplayName.trim(),
      overwrittenAt: overwrittenAt,
      expiresAt: overwrittenAt.add(keptFor),
    );
  }

  /// Whether the version may still be offered at [now].
  bool isKeptAt(DateTime now) => now.isBefore(expiresAt);

  /// A copy carrying the document id the repository stored it under.
  OverwrittenVersion withId(String newId) => OverwrittenVersion(
    id: newId,
    ownerId: ownerId,
    entity: entity,
    resourceType: resourceType,
    resourceId: resourceId,
    version: version,
    overwrittenBy: overwrittenBy,
    overwrittenByName: overwrittenByName,
    overwrittenAt: overwrittenAt,
    expiresAt: expiresAt,
  );

  /// The stored shape. The field set matches the create rule in
  /// firestore.rules (`match /users/{userId}/overwritten_versions/{id}`).
  Map<String, dynamic> toFirestore() => {
    'ownerId': ownerId,
    'entity': entity.name,
    'resourceType': resourceType.value,
    'resourceId': resourceId,
    'version': version,
    'overwrittenBy': overwrittenBy,
    'overwrittenByName': overwrittenByName,
    'overwrittenAt': Timestamp.fromDate(overwrittenAt),
    'expiresAt': Timestamp.fromDate(expiresAt),
  };

  /// Parses a stored row, or returns null when it is not one this app can
  /// restore (an unknown entity or type, or a missing field). A row that
  /// cannot be restored is never offered.
  static OverwrittenVersion? fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final entityName = data['entity'];
    final entity = ConflictEntity.values
        .where((e) => e.name == entityName)
        .firstOrNull;
    final overwrittenAt = _date(data['overwrittenAt']);
    final expiresAt = _date(data['expiresAt']);
    final version = data['version'];
    final ownerId = data['ownerId'];
    final resourceId = data['resourceId'];
    if (entity == null ||
        !keptEntities.contains(entity) ||
        overwrittenAt == null ||
        expiresAt == null ||
        version is! Map ||
        ownerId is! String ||
        resourceId is! String ||
        resourceId.isEmpty) {
      return null;
    }
    final RealtimeResourceType type;
    try {
      type = RealtimeResourceType.fromString('${data['resourceType']}');
    } on ArgumentError {
      return null;
    }
    return OverwrittenVersion(
      id: id,
      ownerId: ownerId,
      entity: entity,
      resourceType: type,
      resourceId: resourceId,
      version: Map<String, dynamic>.from(version),
      overwrittenBy: SerializationUtils.safeString(data, 'overwrittenBy'),
      overwrittenByName: SerializationUtils.safeString(
        data,
        'overwrittenByName',
      ).trim(),
      overwrittenAt: overwrittenAt,
      expiresAt: expiresAt,
    );
  }

  static DateTime? _date(Object? value) => switch (value) {
    final Timestamp t => t.toDate().toUtc(),
    final DateTime d => d.toUtc(),
    _ => null,
  };
}
