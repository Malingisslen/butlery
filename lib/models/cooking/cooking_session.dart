import 'package:butlery/core/utils/serialization_utils.dart';

// copyWith sentinel — distinguishes "not provided" from "explicit null".
const Object _sentinel = Object();

class CookingSession {
  final String recipeId;
  final String recipeTitle;
  final String? recipeImageUrl;
  final DateTime startedAt;
  final String userId;
  final String userName;
  final String? userAvatar;

  // Step fields are pair-valid: either both null or both non-null with
  // `1 <= currentStep <= totalSteps`. Enforced by the assert below so the
  // card never renders "steg 3 av null" or "steg 5 av 3".
  final int? currentStep;
  final int? totalSteps;

  const CookingSession({
    required this.recipeId,
    required this.recipeTitle,
    required this.startedAt,
    required this.userId,
    required this.userName,
    this.recipeImageUrl,
    this.userAvatar,
    this.currentStep,
    this.totalSteps,
  })  : assert(
          (currentStep == null) == (totalSteps == null),
          'currentStep and totalSteps must both be null or both be non-null',
        ),
        assert(
          currentStep == null || currentStep >= 1,
          'currentStep is 1-based and must be >= 1',
        ),
        assert(
          currentStep == null ||
              totalSteps == null ||
              currentStep <= totalSteps,
          'currentStep must not exceed totalSteps',
        );

  /// Serialize for RTDB. `startedAt` goes out as epoch millis so RTDB
  /// (which has no native Timestamp type) can round-trip it losslessly.
  ///
  /// Nullable fields are written as `null` entries (matches the original
  /// "all keys present" style), except `currentStep` / `totalSteps` which
  /// are elided entirely when null — old clients must not see phantom keys.
  Map<String, dynamic> toMap() {
    return {
      'recipeId': recipeId,
      'recipeTitle': recipeTitle,
      'recipeImageUrl': recipeImageUrl,
      'startedAt': startedAt.millisecondsSinceEpoch,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      if (currentStep != null) 'currentStep': currentStep,
      if (totalSteps != null) 'totalSteps': totalSteps,
    };
  }

  /// Parse an RTDB value map (dynamic keys) back into a [CookingSession].
  /// Missing fields fall back to safe defaults so a malformed row never
  /// crashes the presence stream.
  factory CookingSession.fromMap(Map<dynamic, dynamic> data) {
    final typed = <String, dynamic>{};
    data.forEach((k, v) => typed[k.toString()] = v);

    final rawCurrent = SerializationUtils.safeNullableInt(typed, 'currentStep');
    final rawTotal = SerializationUtils.safeNullableInt(typed, 'totalSteps');
    // Defensive: a malformed RTDB row with only one of the two set, or an
    // out-of-range pair, must not crash the stream via the constructor
    // assertion. Treat any inconsistent pair as "no step data".
    final keepSteps = rawCurrent != null &&
        rawTotal != null &&
        rawCurrent >= 1 &&
        rawCurrent <= rawTotal;

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
      currentStep: keepSteps ? rawCurrent : null,
      totalSteps: keepSteps ? rawTotal : null,
    );
  }

  CookingSession copyWith({
    String? recipeId,
    String? recipeTitle,
    Object? recipeImageUrl = _sentinel,
    DateTime? startedAt,
    String? userId,
    String? userName,
    Object? userAvatar = _sentinel,
    Object? currentStep = _sentinel,
    Object? totalSteps = _sentinel,
  }) {
    return CookingSession(
      recipeId: recipeId ?? this.recipeId,
      recipeTitle: recipeTitle ?? this.recipeTitle,
      recipeImageUrl: identical(recipeImageUrl, _sentinel)
          ? this.recipeImageUrl
          : recipeImageUrl as String?,
      startedAt: startedAt ?? this.startedAt,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: identical(userAvatar, _sentinel)
          ? this.userAvatar
          : userAvatar as String?,
      currentStep: identical(currentStep, _sentinel)
          ? this.currentStep
          : currentStep as int?,
      totalSteps: identical(totalSteps, _sentinel)
          ? this.totalSteps
          : totalSteps as int?,
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
        other.userAvatar == userAvatar &&
        other.currentStep == currentStep &&
        other.totalSteps == totalSteps;
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
        currentStep,
        totalSteps,
      );

  @override
  String toString() =>
      'CookingSession(user: $userName, recipe: $recipeTitle, started: $startedAt)';
}
