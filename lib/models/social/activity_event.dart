/// Activity event model for the social activity feed.
library;

import 'package:clock/clock.dart';
import 'package:uuid/uuid.dart';
import 'package:butlery/core/types/app_timestamp.dart';
import 'package:butlery/core/utils/serialization_utils.dart';

/// Type of social activity event.
///
/// `fromString` falls back to [cooked] for forward-compat with older clients
/// that don't yet know about newer event types. New types MUST use `.name`
/// serialization to match the existing wire format.
enum ActivityEventType {
  cooked,
  shared,
  // BUT-407/cooking-depth additions — older clients fall back to `cooked`.
  addedIngredient,
  startedCooking,
  pinged;

  static ActivityEventType fromString(String value) {
    return ActivityEventType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ActivityEventType.cooked,
    );
  }
}

/// A single activity event in the social feed.
class ActivityEvent {
  final String id;
  final String actorId;
  final String actorDisplayName;
  final ActivityEventType type;
  final String recipeId;
  final String recipeTitle;
  final Map<String, dynamic> extraData;
  final DateTime createdAt;

  ActivityEvent({
    required this.id,
    required this.actorId,
    required this.actorDisplayName,
    required this.type,
    required this.recipeId,
    required this.recipeTitle,
    this.extraData = const {},
    DateTime? createdAt,
  }) : createdAt = createdAt ?? clock.now();

  factory ActivityEvent.create({
    required String actorId,
    required String actorDisplayName,
    required ActivityEventType type,
    required String recipeId,
    required String recipeTitle,
    Map<String, dynamic>? extraData,
  }) {
    return ActivityEvent(
      id: const Uuid().v4(),
      actorId: actorId,
      actorDisplayName: actorDisplayName,
      type: type,
      recipeId: recipeId,
      recipeTitle: recipeTitle,
      extraData: extraData ?? const {},
      createdAt: clock.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'actorId': actorId,
      'actorDisplayName': actorDisplayName,
      'type': type.name,
      'recipeId': recipeId,
      'recipeTitle': recipeTitle,
      'extraData': extraData,
      'createdAt': AppTimestamp.fromDateTime(createdAt).toFirestore(),
    };
  }

  factory ActivityEvent.fromMap(String id, Map<String, dynamic> data) {
    return ActivityEvent(
      id: id,
      actorId: SerializationUtils.safeString(data, 'actorId'),
      actorDisplayName: SerializationUtils.safeString(
        data,
        'actorDisplayName',
        defaultValue: '?',
      ),
      type: ActivityEventType.fromString(
        SerializationUtils.safeString(data, 'type'),
      ),
      recipeId: SerializationUtils.safeString(data, 'recipeId'),
      recipeTitle: SerializationUtils.safeString(data, 'recipeTitle'),
      extraData: (data['extraData'] as Map<String, dynamic>?) ?? const {},
      createdAt:
          SerializationUtils.safeDateTime(data, 'createdAt') ?? clock.now(),
    );
  }

  /// CookSnap photo URL, if this is a cooked event with a photo.
  String? get photoUrl => extraData['photoUrl'] as String?;

  /// CookSnap caption, if present.
  String? get caption => extraData['caption'] as String?;

  /// Number of members a recipe was shared with.
  int? get memberCount => extraData['memberCount'] as int?;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ActivityEvent && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'ActivityEvent(id: $id, actor: $actorDisplayName, type: ${type.name}, recipe: $recipeTitle)';
}
