// lib/models/cooking/cooking_session.dart
//
// BUT-408: Live "Erik lagar just nu" presence entry for a friend group.
//
// Data model for cooking session presence stored in RTDB at
// `cooking_sessions/{groupId}/{userId}`. Ephemeral — cleared via
// `onDisconnect().remove()` and an explicit endSession() on cooking mode exit.

import 'package:butlery/core/utils/serialization_utils.dart';

/// A single friend's live cooking session, broadcast to every group the user
/// is a member of while cooking mode is open.
class CookingSession {
  /// Recipe being cooked — used for nav target when the card is tapped.
  final String recipeId;

  /// Recipe title — shown inline in the card ("Erik lagar kycklinggryta").
  final String recipeTitle;

  /// Optional recipe hero image URL. Reserved for future UI; the initial
  /// card does not render it but repos persist the field for forward-compat.
  final String? recipeImageUrl;

  /// Wall-clock start time. Ordering key when merging multiple sessions.
  final DateTime startedAt;

  /// User broadcasting the session. Matches `auth.uid` of the writer.
  final String userId;

  /// Display name shown in the card's primary line.
  final String userName;

  /// Optional avatar URL — reserved for future UI variants (currently unused
  /// in the card but persisted for consistency with other presence records).
  final String? userAvatar;

  const CookingSession({
    required this.recipeId,
    required this.recipeTitle,
    required this.startedAt,
    required this.userId,
    required this.userName,
    this.recipeImageUrl,
    this.userAvatar,
  });

  /// Serialize for RTDB. `startedAt` goes out as epoch millis so RTDB
  /// (which has no native Timestamp type) can round-trip it losslessly.
  Map<String, dynamic> toMap() {
    return {
      'recipeId': recipeId,
      'recipeTitle': recipeTitle,
      'recipeImageUrl': recipeImageUrl,
      'startedAt': startedAt.millisecondsSinceEpoch,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
    };
  }

  /// Parse an RTDB value map (dynamic keys) back into a [CookingSession].
  /// Missing fields fall back to safe defaults so a malformed row never
  /// crashes the presence stream.
  factory CookingSession.fromMap(Map<dynamic, dynamic> data) {
    final typed = <String, dynamic>{};
    data.forEach((k, v) => typed[k.toString()] = v);

    return CookingSession(
      recipeId: SerializationUtils.safeString(typed, 'recipeId'),
      recipeTitle: SerializationUtils.safeString(typed, 'recipeTitle'),
      recipeImageUrl:
          SerializationUtils.safeNullableString(typed, 'recipeImageUrl'),
      startedAt: SerializationUtils.parseDateTimeValue(typed['startedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      userId: SerializationUtils.safeString(typed, 'userId'),
      userName: SerializationUtils.safeString(typed, 'userName'),
      userAvatar: SerializationUtils.safeNullableString(typed, 'userAvatar'),
    );
  }

  CookingSession copyWith({
    String? recipeId,
    String? recipeTitle,
    String? recipeImageUrl,
    DateTime? startedAt,
    String? userId,
    String? userName,
    String? userAvatar,
  }) {
    return CookingSession(
      recipeId: recipeId ?? this.recipeId,
      recipeTitle: recipeTitle ?? this.recipeTitle,
      recipeImageUrl: recipeImageUrl ?? this.recipeImageUrl,
      startedAt: startedAt ?? this.startedAt,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CookingSession &&
        other.recipeId == recipeId &&
        other.recipeTitle == recipeTitle &&
        other.recipeImageUrl == recipeImageUrl &&
        other.startedAt == startedAt &&
        other.userId == userId &&
        other.userName == userName &&
        other.userAvatar == userAvatar;
  }

  @override
  int get hashCode => Object.hash(
        recipeId,
        recipeTitle,
        recipeImageUrl,
        startedAt,
        userId,
        userName,
        userAvatar,
      );

  @override
  String toString() =>
      'CookingSession(user: $userName, recipe: $recipeTitle, started: $startedAt)';
}
