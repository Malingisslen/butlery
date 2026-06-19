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

  const ParsingDomainStat({
    required this.domain,
    required this.corrections,
    required this.topIssue,
  });
}
