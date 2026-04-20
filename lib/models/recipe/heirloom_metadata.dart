/// Heirloom OCR metadata ("Farmors lapp") — optional per-recipe record of
/// an original hand-written/printed source image with writer attribution.
///
/// BUT-410: Hero feature letting users preserve the visual "story" of a
/// family recipe alongside the parsed text version. Null for normal recipes.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/serialization_utils.dart' as utils;

/// Metadata describing an heirloom source scan attached to a recipe.
///
/// Invariants (enforced at construction):
/// - [year] if present is between 1800 and the current year (inclusive).
/// - [writerName] if present is at most 100 characters.
/// - [note] if present is at most 200 characters.
///
/// Round-trips through JSON and Firestore identically — the only difference
/// is that Firestore stores [addedAt] as a [Timestamp], JSON as ISO8601.
class HeirloomMetadata {
  /// Download URL of the uploaded source image in Firebase Storage.
  /// Content-addressed path: `users/{uid}/recipes/{rid}/heirloom/{sha256prefix}.jpg`.
  final String sourceImageUrl;

  /// Who wrote the original recipe (e.g. "Farmor Elsa"). Max 100 chars.
  final String? writerName;

  /// Year the recipe was written down, 1800..currentYear inclusive.
  final int? year;

  /// Short user-provided note about the recipe's origin. Max 200 chars.
  final String? note;

  /// When the heirloom metadata was attached.
  final DateTime addedAt;

  /// Auth uid of the user who added the heirloom record — used for GDPR
  /// cascade deletion (see FirebaseStorageRepository deletion walk).
  final String addedByUserId;

  HeirloomMetadata({
    required this.sourceImageUrl,
    this.writerName,
    this.year,
    this.note,
    required this.addedAt,
    required this.addedByUserId,
  }) {
    // Validate writerName length
    if (writerName != null && writerName!.length > 100) {
      throw ArgumentError.value(
        writerName,
        'writerName',
        'must be at most 100 characters',
      );
    }

    // Validate note length
    if (note != null && note!.length > 200) {
      throw ArgumentError.value(
        note,
        'note',
        'must be at most 200 characters',
      );
    }

    // Validate year range — lower bound matches the oldest plausible
    // family recipe; upper bound tracks the current year so time can't
    // "run ahead" of validation.
    if (year != null) {
      final currentYear = DateTime.now().year;
      if (year! < 1800 || year! > currentYear) {
        throw ArgumentError.value(
          year,
          'year',
          'must be between 1800 and $currentYear',
        );
      }
    }
  }

  /// Serialize to JSON-compatible map (ISO8601 dates).
  Map<String, dynamic> toJson() => {
        'sourceImageUrl': sourceImageUrl,
        'writerName': writerName,
        'year': year,
        'note': note,
        'addedAt': addedAt.toIso8601String(),
        'addedByUserId': addedByUserId,
      };

  /// Serialize to Firestore map (Timestamp for dates).
  Map<String, dynamic> toFirestore() => {
        'sourceImageUrl': sourceImageUrl,
        'writerName': writerName,
        'year': year,
        'note': note,
        'addedAt': Timestamp.fromDate(addedAt),
        'addedByUserId': addedByUserId,
      };

  /// Deserialize from a JSON or Firestore map. Handles both shapes since
  /// the only divergence (addedAt) is routed through [utils.SerializationUtils.parseRequiredDateTimeValue],
  /// which accepts ISO strings, Timestamps, ints, and seconds-map variants.
  factory HeirloomMetadata.fromMap(Map<String, dynamic> map) {
    return HeirloomMetadata(
      sourceImageUrl:
          utils.SerializationUtils.safeString(map, 'sourceImageUrl'),
      writerName:
          utils.SerializationUtils.safeNullableString(map, 'writerName'),
      year: utils.SerializationUtils.safeNullableInt(map, 'year'),
      note: utils.SerializationUtils.safeNullableString(map, 'note'),
      addedAt: utils.SerializationUtils.safeRequiredDateTime(map, 'addedAt'),
      addedByUserId: utils.SerializationUtils.safeString(map, 'addedByUserId'),
    );
  }

  HeirloomMetadata copyWith({
    String? sourceImageUrl,
    String? writerName,
    int? year,
    String? note,
    DateTime? addedAt,
    String? addedByUserId,
  }) {
    return HeirloomMetadata(
      sourceImageUrl: sourceImageUrl ?? this.sourceImageUrl,
      writerName: writerName ?? this.writerName,
      year: year ?? this.year,
      note: note ?? this.note,
      addedAt: addedAt ?? this.addedAt,
      addedByUserId: addedByUserId ?? this.addedByUserId,
    );
  }
}
