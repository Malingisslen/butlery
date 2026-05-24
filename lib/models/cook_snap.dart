/// CookSnap model — a photo posted by a user who cooked a recipe.
library;

import 'package:clock/clock.dart';
import 'package:uuid/uuid.dart';
import 'package:butlery/core/types/app_timestamp.dart';
import 'package:butlery/core/utils/serialization_utils.dart';

/// A cooking photo posted on a recipe by any authenticated user.
class CookSnap {
  final String id;
  final String recipeId;
  final String userId;
  final String userDisplayName;
  final String? userAvatarUrl;
  final String photoUrl;
  final String? thumbnailUrl;
  final String? caption;

  /// Optimistic client time. Server timestamp is authoritative — see
  /// `FirebaseCookSnapRepository.addCookSnap`, which overwrites this
  /// field with `FieldValue.serverTimestamp()` at the write boundary
  /// (BUT-965). The in-memory value here is what the immediate UI
  /// displays; subsequent reads resolve to the server-set time.
  final DateTime createdAt;

  CookSnap({
    required this.id,
    required this.recipeId,
    required this.userId,
    required this.userDisplayName,
    this.userAvatarUrl,
    required this.photoUrl,
    this.thumbnailUrl,
    this.caption,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? clock.now();

  /// Maximum caption length.
  static const int maxCaptionLength = 200;

  factory CookSnap.create({
    required String recipeId,
    required String userId,
    required String userDisplayName,
    String? userAvatarUrl,
    required String photoUrl,
    String? thumbnailUrl,
    String? caption,
  }) {
    return CookSnap(
      id: const Uuid().v4(),
      recipeId: recipeId,
      userId: userId,
      userDisplayName: userDisplayName,
      userAvatarUrl: userAvatarUrl,
      photoUrl: photoUrl,
      thumbnailUrl: thumbnailUrl,
      caption: _sanitizeCaption(caption),
      createdAt: clock.now(),
    );
  }

  static String? _sanitizeCaption(String? caption) {
    if (caption == null) return null;
    final trimmed = caption.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length > maxCaptionLength) {
      return trimmed.substring(0, maxCaptionLength);
    }
    return trimmed;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'recipeId': recipeId,
      'userId': userId,
      'userDisplayName': userDisplayName,
      'userAvatarUrl': userAvatarUrl,
      'photoUrl': photoUrl,
      'thumbnailUrl': thumbnailUrl,
      'caption': caption,
      'createdAt': AppTimestamp.fromDateTime(createdAt).toFirestore(),
    };
  }

  factory CookSnap.fromMap(String id, Map<String, dynamic> data) {
    return CookSnap(
      id: id,
      recipeId: SerializationUtils.safeString(data, 'recipeId'),
      userId: SerializationUtils.safeString(data, 'userId'),
      userDisplayName: SerializationUtils.safeString(
        data,
        'userDisplayName',
        defaultValue: '?',
      ),
      userAvatarUrl:
          SerializationUtils.safeNullableString(data, 'userAvatarUrl'),
      photoUrl: SerializationUtils.safeString(data, 'photoUrl'),
      thumbnailUrl: SerializationUtils.safeNullableString(data, 'thumbnailUrl'),
      caption: SerializationUtils.safeNullableString(data, 'caption'),
      createdAt:
          SerializationUtils.safeDateTime(data, 'createdAt') ?? clock.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CookSnap && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'CookSnap(id: $id, user: $userDisplayName, recipe: $recipeId)';
}
