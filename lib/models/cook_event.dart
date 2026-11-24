import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/utils/serialization_utils.dart';

/// A single "user cooked this recipe" event (BUT-838).
///
/// Stored at `recipe_cook_events/{userId}/events/{eventId}` — see
/// `FirebaseCookEventRepository` for the full schema contract. Unlike the
/// denormalized `core.cookCount` / `core.lastCookedAt` fields on the recipe
/// document, the event log preserves one row per cook, so repeat cooks of
/// the same recipe within a window are countable (the old distinct-recipe
/// proxy collapsed them to 1).
class CookEvent {
  final String id;

  /// Owner — the `{userId}` path segment, NOT a document field.
  final String userId;

  final String recipeId;
  final DateTime cookedAt;

  /// Roster member ids present at this cook (the "who's eating today" pick) —
  /// account `userId`s and `DinerProfile.id`s, as resolved by the household
  /// roster. Empty when no attendance was recorded (the default), which keeps
  /// the stored doc to `{recipeId, cookedAt}` for backward compatibility.
  final List<String> attendeeMemberIds;

  /// This cook's own 1-5 verdict, set from the after-cook sheet. Null when the
  /// sheet was skipped or the household rated through the family entry.
  final int? rating;

  /// Free-text note about this cook, at most [maxNoteLength] characters.
  final String? note;

  /// Id of the CookSnap photo post tied to this cook, when one was added.
  final String? snapId;

  static const int maxNoteLength = 500;

  const CookEvent({
    required this.id,
    required this.userId,
    required this.recipeId,
    required this.cookedAt,
    this.attendeeMemberIds = const [],
    this.rating,
    this.note,
    this.snapId,
  });

  factory CookEvent.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return CookEvent(
      id: doc.id,
      // events/{eventId} → parent = events, parent.parent = {userId} doc.
      userId: (doc.reference.parent.parent?.id).orEmpty(),
      recipeId: SerializationUtils.safeString(data, 'recipeId'),
      // Epoch fallback keeps a malformed doc out of any recency window
      // instead of inflating counts with "now". safeRequiredDateTime also
      // tolerates non-Timestamp shapes (ISO strings, raw seconds maps) that
      // a hard `as Timestamp` cast would throw on.
      cookedAt: SerializationUtils.safeRequiredDateTime(
        data,
        'cookedAt',
        defaultValue: DateTime.fromMillisecondsSinceEpoch(0),
      ),
      attendeeMemberIds: SerializationUtils.safeStringList(
        data,
        'attendeeMemberIds',
      ),
      rating: SerializationUtils.safeNullableInt(data, 'rating'),
      note: SerializationUtils.safeNullableString(data, 'note'),
      snapId: SerializationUtils.safeNullableString(data, 'snapId'),
    );
  }

  /// Document fields only — `userId` lives in the path, `id` is the doc id.
  /// `attendeeMemberIds` is omitted when empty so historical events and
  /// no-attendance cooks keep the original two-field shape.
  Map<String, dynamic> toFirestore() => {
    'recipeId': recipeId,
    'cookedAt': Timestamp.fromDate(cookedAt),
    if (attendeeMemberIds.isNotEmpty) 'attendeeMemberIds': attendeeMemberIds,
    if (rating != null) 'rating': rating,
    if (note != null) 'note': note,
    if (snapId != null) 'snapId': snapId,
  };
}
