import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show immutable;

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/models/tagging/ingredient_allergen_impact.dart';
import 'package:butlery/models/tagging/ingredient_column.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';

/// Wire names are what Firestore rules and the later apply step match on.
enum IngredientChangeStatus {
  pending('pending'),
  withdrawn('withdrawn'),
  applied('applied'),
  inReview('inReview'),
  conflict('conflict'),
  rejected('rejected')
  ;

  const IngredientChangeStatus(this.wireName);

  final String wireName;

  /// An unknown value reads as pending so a status added by the server later
  /// stays visible instead of vanishing from the queue.
  static IngredientChangeStatus fromWire(Object? raw) {
    for (final s in values) {
      if (s.wireName == raw) return s;
    }
    return pending;
  }
}

@immutable
class IngredientFieldChange {
  const IngredientFieldChange({
    required this.column,
    required this.oldValue,
    required this.newValue,
  });

  /// Reads the old value from [ingredient] so it is always the shape the
  /// sync would produce for that column.
  factory IngredientFieldChange.from(
    IngredientData ingredient,
    IngredientColumn column,
    Object? newValue,
  ) => IngredientFieldChange(
    column: column,
    oldValue: column.oldValueOf(ingredient),
    newValue: newValue,
  );

  final IngredientColumn column;
  final Object? oldValue;
  final Object? newValue;

  Map<String, Object?> toMap() => {'old': oldValue, 'new': newValue};

  static Object? _read(IngredientColumn column, Object? raw) =>
      switch (column.kind) {
        IngredientColumnKind.list => [
          if (raw is Iterable)
            for (final e in raw) e.toString(),
        ],
        IngredientColumnKind.number => raw is num ? raw.toDouble() : null,
        IngredientColumnKind.text => (raw?.toString()).orEmpty(),
      };

  static IngredientFieldChange? fromMap(String csvName, Object? raw) {
    final column = IngredientColumn.fromCsvName(csvName);
    if (column == null || raw is! Map) return null;
    return IngredientFieldChange(
      column: column,
      oldValue: _read(column, raw['old']),
      newValue: _read(column, raw['new']),
    );
  }
}

@immutable
class IngredientChangeRequest {
  const IngredientChangeRequest({
    this.id = '',
    required this.ingredientId,
    required this.changes,
    this.ingredientUpdatedAt,
    this.note = '',
    this.batchId,
    this.status = IngredientChangeStatus.pending,
    this.createdBy = '',
    this.createdAt,
    this.withdrawnAt,
    this.withdrawnBy,
    this.expireAt,
    this.prNumber,
    this.appliedAt,
    this.reason,
    this.csvValue,
    this.kind = kIngredientKind,
  });

  /// A document without `kind` is an ingredient proposal.
  static const String kIngredientKind = 'ingredient';

  final String id;
  final String ingredientId;
  final List<IngredientFieldChange> changes;
  final DateTime? ingredientUpdatedAt;
  final String note;
  final String? batchId;
  final IngredientChangeStatus status;
  final String createdBy;

  /// Null on a snapshot that still holds the pending server timestamp.
  final DateTime? createdAt;
  final DateTime? withdrawnAt;
  final String? withdrawnBy;
  final DateTime? expireAt;

  /// Server-written once the proposal is in a pull request.
  final int? prNumber;

  /// Server timestamp the sync job writes when the proposal becomes `applied`.
  final DateTime? appliedAt;

  /// Server-written on `conflict` and `rejected`.
  final String? reason;

  /// The CSV's own value per column on a conflict; null for a column whose
  /// row is gone.
  final Map<String, Object?>? csvValue;
  final String kind;

  IngredientChangeRequest withIdentity({
    required String id,
    required String createdBy,
  }) => IngredientChangeRequest(
    id: id,
    ingredientId: ingredientId,
    changes: changes,
    ingredientUpdatedAt: ingredientUpdatedAt,
    note: note,
    batchId: batchId,
    status: status,
    createdBy: createdBy,
    createdAt: createdAt,
    withdrawnAt: withdrawnAt,
    withdrawnBy: withdrawnBy,
    expireAt: expireAt,
    prNumber: prNumber,
    appliedAt: appliedAt,
    reason: reason,
    csvValue: csvValue,
    kind: kind,
  );

  IngredientFieldChange? changeFor(IngredientColumn column) {
    for (final c in changes) {
      if (c.column == column) return c;
    }
    return null;
  }

  bool get affectsAllergens {
    final props = changeFor(IngredientColumn.properties);
    if (props == null) return false;
    return propertyChangeAffectsAllergens(
      List<String>.from(props.oldValue as Iterable),
      List<String>.from(props.newValue as Iterable),
    );
  }

  /// The creation document. The key set is exactly what the rules accept:
  /// optional keys are left out, never written as null or empty.
  Map<String, dynamic> toFirestore() => {
    'ingredientId': ingredientId,
    'changes': {for (final c in changes) c.column.csvName: c.toMap()},
    if (ingredientUpdatedAt != null)
      'ingredientUpdatedAt': Timestamp.fromDate(ingredientUpdatedAt!),
    if (note.isNotEmpty) 'note': note,
    if (batchId != null) 'batchId': batchId,
    'status': IngredientChangeStatus.pending.wireName,
    'createdBy': createdBy,
    'createdAt': FieldValue.serverTimestamp(),
  };

  factory IngredientChangeRequest.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawChanges = data['changes'];
    final changes = <IngredientFieldChange>[
      if (rawChanges is Map)
        for (final e in rawChanges.entries)
          ?IngredientFieldChange.fromMap(e.key.toString(), e.value),
    ]..sort((a, b) => a.column.index.compareTo(b.column.index));
    return IngredientChangeRequest(
      id: doc.id,
      ingredientId: (data['ingredientId']?.toString()).orEmpty(),
      changes: changes,
      ingredientUpdatedAt: _date(data['ingredientUpdatedAt']),
      note: (data['note']?.toString()).orEmpty(),
      batchId: data['batchId']?.toString(),
      status: IngredientChangeStatus.fromWire(data['status']),
      createdBy: (data['createdBy']?.toString()).orEmpty(),
      createdAt: _date(data['createdAt']),
      withdrawnAt: _date(data['withdrawnAt']),
      withdrawnBy: data['withdrawnBy']?.toString(),
      expireAt: _date(data['expireAt']),
      prNumber: data['prNumber'] is num
          ? (data['prNumber'] as num).toInt()
          : null,
      appliedAt: _date(data['appliedAt']),
      reason: data['reason']?.toString(),
      csvValue: _csvValue(data['csvValue']),
      kind: data['kind'] is String && (data['kind'] as String).isNotEmpty
          ? data['kind'] as String
          : kIngredientKind,
    );
  }

  static Map<String, Object?>? _csvValue(Object? raw) => raw is Map
      ? {for (final e in raw.entries) e.key.toString(): e.value}
      : null;

  static DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : null;
}
