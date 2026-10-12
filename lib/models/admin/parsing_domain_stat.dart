/// Read-model for the admin parsing-details tab: per-domain correction counts
/// plus the field category most often corrected for that domain. Derived from
/// the `parsing_corrections` collection (see ParsingCorrectionRepository).

/// The recipe field most frequently corrected for a domain — i.e. what the
/// parser most often gets wrong there.
enum ParsingIssue { title, portions, time, ingredients, instructions, none }

class ParsingDomainStat {
  final String domain;
  final int corrections;
  final ParsingIssue topIssue;

  /// Share of the domain's imports that succeeded, 0-100. Null when the
  /// domain has no import record.
  final int? successPercent;

  const ParsingDomainStat({
    required this.domain,
    required this.corrections,
    required this.topIssue,
    this.successPercent,
  });
}
