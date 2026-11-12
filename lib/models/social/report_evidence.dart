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

/// Why a moderator keeps a copy beyond the case.
enum FreezeReason {
  police('police'),
  threat('threat'),
  legalClaim('legal_claim'),

  /// A wire name this build does not know (written by a newer server).
  unknown('')
  ;

  final String wireName;
  const FreezeReason(this.wireName);

  static FreezeReason fromWire(String? value) {
    for (final reason in values) {
      if (reason != unknown && reason.wireName == value) return reason;
    }
    return unknown;
  }
}

/// What `freezeReportEvidence` is asked to do.
enum FreezeAction {
  freeze('freeze'),
  extend('extend'),
  release('release')
  ;

  final String wireName;
  const FreezeAction(this.wireName);
}

/// Why `freezeReportEvidence` refused, from the callable's
/// `failed-precondition` message.
enum FreezeBlock {
  noCopy('no_copy'),
  notCaptured('not_captured'),
  alreadyFrozen('already_frozen'),
  notFrozen('not_frozen'),
  atCap('at_cap')
  ;

  final String wireName;
  const FreezeBlock(this.wireName);

  static FreezeBlock? fromWire(Object? value) {
    for (final b in values) {
      if (b.wireName == value) return b;
    }
    return null;
  }
}

/// The hold that keeps a copy past the case.
class FrozenEvidence {
  final FreezeReason reason;
  final DateTime? frozenAt;
  final DateTime? firstFrozenAt;
  final DateTime until;
  final int extensions;

  const FrozenEvidence({
    required this.reason,
    required this.until,
    this.frozenAt,
    this.firstFrozenAt,
    this.extensions = 0,
  });

  /// Null when the map holds no readable `until`: a hold without an end date
  /// cannot be shown or ordered.
  static FrozenEvidence? fromMap(Map<String, dynamic>? data) {
    if (data == null) return null;
    final until = SerializationUtils.safeDateTime(data, 'until');
    if (until == null) return null;
    return FrozenEvidence(
      reason: FreezeReason.fromWire(
        SerializationUtils.safeNullableString(data, 'reason'),
      ),
      frozenAt: SerializationUtils.safeDateTime(data, 'frozenAt'),
      firstFrozenAt: SerializationUtils.safeDateTime(data, 'firstFrozenAt'),
      until: until,
      extensions: SerializationUtils.safeInt(data, 'extensions'),
    );
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

  /// The wire name of the reported content's type, for display.
  final String? contentType;

  /// Set while a moderator keeps the copy past the case.
  final FrozenEvidence? frozen;

  bool get isFrozen => frozen != null;

  /// Present only for a menu_dish report: whether the dish named the reporter
  /// as its creator when the report came in. Null when the server wrote none.
  final bool? claimedCreatorIsReporter;

  /// Captured fields in reading order; a list value is joined with newlines.
  /// Empty unless [outcome] is [EvidenceOutcome.captured].
  final List<(String field, String value)> text;

  const ReportEvidence({
    required this.reportId,
    required this.outcome,
    this.capturedAt,
    this.truncated = false,
    this.contentType,
    this.frozen,
    this.claimedCreatorIsReporter,
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
      contentType: SerializationUtils.safeNullableString(data, 'contentType'),
      frozen: FrozenEvidence.fromMap(
        SerializationUtils.safeNullableMap(data, 'frozen'),
      ),
      claimedCreatorIsReporter: data['claimedCreatorIsReporter'] is bool
          ? data['claimedCreatorIsReporter'] as bool
          : null,
      text: fields,
    );
  }
}
