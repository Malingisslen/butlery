import 'package:butlery/core/utils/serialization_utils.dart';

/// One record kept after an account deletion, and the article that permits it.
///
/// BUT-2046 follow-up. When somebody deletes their account while a moderation
/// report against them is still open, the evidence is retained under GDPR
/// Art. 17(3)(e). Art. 12(4) then owes that person a notice saying what was
/// kept, why, for how long, and that they may complain to IMY or go to court —
/// so this crosses the callable boundary purely to be rendered.
///
/// The server sends [holdUntil] as an ISO-8601 string: a Firestore `Timestamp`
/// does not survive the callable boundary, and neither does a `DateTime`.
class RetainedRecord {
  const RetainedRecord({
    required this.resourceType,
    required this.legalBasis,
    required this.holdUntil,
    this.provisional = false,
  });

  /// Which collection the retained rows live in, as the server names it.
  final String resourceType;

  /// The article the retention rests on, e.g. `GDPR Art. 17(3)(e)`.
  final String legalBasis;

  /// The outer cap — when the hold lifts at the latest, whatever the case does.
  final DateTime? holdUntil;

  /// Whether the hold was placed without the predicate being answered — the
  /// query threw, or the hold write did.
  ///
  /// Malin's call, 2026-09-09 (BUT-2047): the notice hedges its "what" line in
  /// that case. A person is told the truth about their own record, including
  /// when the truth is that we could not determine it.
  ///
  /// A MISSING field reads as false, which is the ordinary hold and what an
  /// older deployment sends.
  final bool provisional;

  /// Parses one entry of the callable's `retained` list.
  ///
  /// Fails SOFT on a missing or unparsable [holdUntil]: the notice is the last
  /// thing the person ever sees, so a malformed date degrades the "how long"
  /// line rather than throwing away the whole notice.
  factory RetainedRecord.fromMap(Map<String, dynamic> map) {
    return RetainedRecord(
      resourceType: SerializationUtils.safeString(map, 'resourceType'),
      legalBasis: SerializationUtils.safeString(map, 'legalBasis'),
      holdUntil: SerializationUtils.parseDateTimeValue(map['holdUntil']),
      provisional: SerializationUtils.safeBool(map, 'provisional'),
    );
  }

  /// The `resourceType` of a report the deleted person FILED and whose case
  /// was still open: kept without their name, with their own words (Malin,
  /// 2026-09-18).
  static const String ownReportResource = 'reports';

  /// Whether this record is a report the person filed, rather than a review
  /// of content they were reported for.
  bool get isOwnReport => resourceType == ownReportResource;

  /// Parses the callable's `retained` field, whatever shape it arrives in.
  ///
  /// An older deployment does not send the field at all, which reads here as
  /// "nothing was kept" — the same answer as an empty list, and the one that
  /// leaves the ordinary deletion path exactly as it was.
  static List<RetainedRecord> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => RetainedRecord.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }
}

/// What the Art. 12(4) notice has to say, folded from every retained record.
///
/// The notice names each KIND of thing kept rather than rendering one record,
/// because one deletion can keep both: a review of the person's content and a
/// report they filed.
class RetentionNoticeFacts {
  const RetentionNoticeFacts({
    required this.reviewKept,
    required this.ownReportKept,
    required this.provisional,
    required this.holdUntil,
  });

  factory RetentionNoticeFacts.from(List<RetainedRecord> records) {
    final reviews = records.where((r) => !r.isOwnReport);
    DateTime? latest;
    for (final r in records) {
      final until = r.holdUntil;
      if (until != null && (latest == null || until.isAfter(latest))) {
        latest = until;
      }
    }
    return RetentionNoticeFacts(
      reviewKept: reviews.isNotEmpty,
      ownReportKept: records.any((r) => r.isOwnReport),
      provisional: reviews.any((r) => r.provisional),
      holdUntil: latest,
    );
  }

  /// A review of content the person was reported for.
  final bool reviewKept;

  /// A report the person filed, whose case was still open.
  final bool ownReportKept;

  /// Whether the review hold was placed without the check completing.
  final bool provisional;

  /// The LATEST cap among the records: the notice gives one "at the latest"
  /// date, and an earlier one would promise too little.
  final DateTime? holdUntil;
}
