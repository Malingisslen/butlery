import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show immutable;

import 'package:butlery/core/utils/serialization_utils.dart';

/// The fields an edit-sheet save changed, as they were before it (BUT-2140).
///
/// Kept on the item itself, written in the same update as the change, so
/// Återställ costs no extra read or write. Only the latest save is kept: the
/// next one replaces the whole map.
@immutable
class PantryPreviousVersion {
  const PantryPreviousVersion({required this.fields, required this.at});

  /// Stored values by field name. Null means the field was missing, and
  /// restoring it deletes the field.
  final Map<String, Object?> fields;

  /// When the save that replaced these values was made.
  final DateTime at;

  /// How long Återställ is offered (Malin 2026-10-08). Firestore TTL removes
  /// whole documents, never a field, so an older version stays in the
  /// document, unshown, until the next save replaces it; Malin accepted that
  /// rather than a nightly job.
  static const restoreWindow = Duration(days: 30);

  /// The fields a user edits (`PantryItem.changesFrom`). Nothing else is kept
  /// or written back, so the version never carries `updatedBy` or any uid.
  static const restorableKeys = {
    'ingredientId',
    'ingredientName',
    'quantity',
    'unit',
    'location',
    'expiryDate',
    'note',
    'isStaple',
  };

  /// Whether the row "Förra versionen" is shown at [now].
  bool isRestorableAt(DateTime now) =>
      fields.isNotEmpty && now.difference(at) < restoreWindow;

  /// Reads the stored map, or null when there is none.
  static PantryPreviousVersion? fromMap(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final stored = SerializationUtils.safeMap(raw, 'fields');
    return PantryPreviousVersion(
      fields: {
        for (final entry in stored.entries)
          if (restorableKeys.contains(entry.key)) entry.key: entry.value,
      },
      // A server timestamp still pending in the local cache reads as null;
      // the save it stamps is happening now.
      at: SerializationUtils.safeDateTime(raw, 'at') ?? clock.now(),
    );
  }

  /// The `previous` field an update writes: [fields] stamped by the server.
  static Map<String, Object> toFirestore(Map<String, Object?> fields) => {
    'fields': fields,
    'at': FieldValue.serverTimestamp(),
  };

  /// The update that writes [fields] back: a missing value deletes the field.
  Map<String, Object> get restoreChanges => {
    for (final entry in fields.entries)
      entry.key: entry.value ?? FieldValue.delete(),
  };
}
