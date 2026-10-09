import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/serialization_utils.dart';

/// Why a `report_evidence` document holds (or does not hold) a text copy.
enum EvidenceOutcome {
  captured('captured'),
  missing('missing'),
  ownerMismatch('owner_mismatch'),
  notVisibleToReporter('not_visible_to_reporter'),
  unsupportedType('unsupported_type'),
  invalidRef('invalid_ref'),
  captureFailed('capture_failed'),

  /// A wire name this build does not know (written by a newer server).
  unknown('')
  ;

  final String wireName;
  const EvidenceOutcome(this.wireName);

  static EvidenceOutcome fromWire(String? value) {
    for (final outcome in values) {
      if (outcome != unknown && outcome.wireName == value) return outcome;
    }
    return unknown;
  }
}

/// Admin-only text copy of reported content, written by a Cloud Function.
class ReportEvidence {
  static const _readingOrder = [
    'title',
    'name',
    'displayName',
    'description',
    'bio',
    'ingredients',
    'instructions',
    'text',
    'content',
    'caption',
  ];

  final String reportId;
  final EvidenceOutcome outcome;
  final DateTime? capturedAt;
  final bool truncated;

  /// Captured fields in reading order; a list value is joined with newlines.
  /// Empty unless [outcome] is [EvidenceOutcome.captured].
  final List<(String field, String value)> text;

  const ReportEvidence({
    required this.reportId,
    required this.outcome,
    this.capturedAt,
    this.truncated = false,
    this.text = const [],
  });

  /// Returns null when the document does not exist.
  static ReportEvidence? fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists) return null;
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    final rawText = SerializationUtils.safeNullableMap(data, 'text');
    final fields = <(String, String)>[];
    if (rawText != null) {
      for (final entry in rawText.entries) {
        final value = entry.value;
        if (value is String) {
          fields.add((entry.key, value));
        } else if (value is List) {
          fields.add((entry.key, value.whereType<String>().join('\n')));
        }
      }
    }
    // Firestore returns map keys sorted, so a recipe would read description
    // before title; put the fields in reading order instead.
    int rank((String, String) f) {
      final i = _readingOrder.indexOf(f.$1);
      return i < 0 ? _readingOrder.length : i;
    }

    fields.sort((a, b) => rank(a).compareTo(rank(b)));
    return ReportEvidence(
      reportId: doc.id,
      outcome: EvidenceOutcome.fromWire(
        SerializationUtils.safeNullableString(data, 'outcome'),
      ),
      capturedAt: SerializationUtils.safeDateTime(data, 'capturedAt'),
      truncated: SerializationUtils.safeBool(data, 'truncated'),
      text: fields,
    );
  }
}
