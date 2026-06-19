import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/admin/parsing_domain_stat.dart';
import 'package:butlery/models/parsing/parsing_correction.dart';
import 'package:butlery/repositories/parsing_correction_repository.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// ViewModel for the admin parsing-details tab. Complements import-health:
/// import-health says WHICH domains fail, this says WHAT the parser gets wrong
/// (which recipe field is corrected most per domain). Read-only.
///
/// Reuses the existing [ParsingCorrectionRepository]. Pre-launch this carries a
/// few rows from manual testing; admin read across all users' corrections is
/// rules-gated to isAdmin.
class ParsingDetailsViewModel extends BaseViewModel {
  final ParsingCorrectionRepository _repository;

  /// Bound on how many domains we fetch per-domain detail for, to cap read
  /// cost. Beyond this, rows still show counts but `topIssue` stays [none].
  static const int _maxDetailDomains = 30;

  List<ParsingDomainStat> _stats = const [];
  int _totalCorrections = 0;

  ParsingDetailsViewModel({ParsingCorrectionRepository? repository})
      : _repository =
            repository ?? ServiceLocator.get<ParsingCorrectionRepository>();

  /// Domains with corrections, most-corrected first.
  List<ParsingDomainStat> get stats => _stats;
  int get totalCorrections => _totalCorrections;
  int get domainCount => _stats.length;
  String? get topDomain => _stats.isEmpty ? null : _stats.first.domain;

  Future<void> load() async {
    await executeAsyncVoid(
      () async {
        final domainCounts = await _repository.getDomainStats();
        final entries = domainCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        final stats = <ParsingDomainStat>[];
        var total = 0;
        for (var i = 0; i < entries.length; i++) {
          final entry = entries[i];
          total += entry.value;
          var issue = ParsingIssue.none;
          if (i < _maxDetailDomains && entry.key != 'unknown') {
            // Issue label is computed from at most the 100 most-recent
            // correction docs (getByDomain's default cap). Fine pre-launch;
            // revisit if a single domain accumulates >100 corrections.
            final corrections =
                await _repository.getByDomain(entry.key, limit: 100);
            issue = _dominantIssue(corrections);
          }
          stats.add(ParsingDomainStat(
            domain: entry.key,
            corrections: entry.value,
            topIssue: issue,
          ));
        }
        if (entries.length > _maxDetailDomains) {
          AppLogger.info(
            'ParsingDetails: top-issue computed for first $_maxDetailDomains '
            'of ${entries.length} domains (cost cap)',
          );
        }
        _stats = stats;
        _totalCorrections = total;
      },
      errorPrefix: 'loadParsingDetails',
    );
  }

  Future<void> refresh() => load();

  /// The field category corrected in the most of a domain's corrections.
  static ParsingIssue _dominantIssue(List<ParsingCorrection> corrections) {
    if (corrections.isEmpty) return ParsingIssue.none;
    final counts = <ParsingIssue, int>{};
    void add(ParsingIssue issue, int n) =>
        counts[issue] = (counts[issue] ?? 0) + n;
    for (final c in corrections) {
      // Scalar fields are binary (present or not); list fields count by how
      // many corrections they hold, so a doc with many ingredient fixes
      // weighs more than one with a single title fix.
      if (c.titleCorrection != null) add(ParsingIssue.title, 1);
      if (c.portionsCorrection != null) add(ParsingIssue.portions, 1);
      if (c.timeCorrection != null) add(ParsingIssue.time, 1);
      add(ParsingIssue.ingredients, c.ingredientCorrections.length);
      add(ParsingIssue.instructions, c.instructionCorrections.length);
    }
    counts.removeWhere((_, n) => n == 0);
    if (counts.isEmpty) return ParsingIssue.none;
    // Highest count wins; ties broken by enum order for determinism.
    return counts.entries
        .reduce((a, b) => a.value != b.value
            ? (a.value > b.value ? a : b)
            : (a.key.index <= b.key.index ? a : b))
        .key;
  }
}
