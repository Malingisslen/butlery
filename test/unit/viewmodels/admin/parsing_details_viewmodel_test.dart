/// Tests for ParsingDetailsViewModel — the admin parsing-details tab's logic:
/// it must aggregate per-domain correction counts (most-corrected first),
/// compute the dominant corrected field per domain, skip the 'unknown' bucket
/// for detail, and degrade to empty/error states without crashing. A bug here
/// would mis-rank failing domains or mislabel what the parser gets wrong.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/admin/parsing_domain_stat.dart';
import 'package:butlery/models/parsing/field_correction.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/models/parsing/parsing_correction.dart';
import 'package:butlery/models/parsing/site_config.dart';
import 'package:butlery/repositories/parsing_correction_repository.dart';
import 'package:butlery/repositories/site_config_repository.dart';
import 'package:butlery/viewmodels/admin/parsing_details_viewmodel.dart';

import '../../../test_support/base_unit_test.dart';
import 'package:butlery/core/l10n/app_locale.dart';

class _FakeParsingRepo extends ParsingCorrectionRepository {
  _FakeParsingRepo({
    this.domainStats = const {},
    this.byDomain = const {},
  }) : super(firestore: FakeFirebaseFirestore());

  Map<String, int> domainStats;
  Map<String, List<ParsingCorrection>> byDomain;
  bool throwOnLoad = false;

  @override
  Future<Map<String, int>> getDomainStats() async {
    if (throwOnLoad) throw Exception('boom');
    return domainStats;
  }

  @override
  Future<List<ParsingCorrection>> getByDomain(
    String domain, {
    int limit = 100,
  }) async {
    return byDomain[domain] ?? const [];
  }
}

class _FakeSiteConfigs extends SiteConfigRepository {
  _FakeSiteConfigs(this.configs, {this.fail = false})
    : super(firestore: FakeFirebaseFirestore());

  final List<SiteConfig> configs;
  final bool fail;

  @override
  Future<List<SiteConfig>> getAllConfigs({int limit = 200}) async {
    if (fail) throw Exception('boom');
    return configs;
  }
}

const _fc = FieldCorrection(originalValue: 'a', correctedValue: 'b');

ParsingCorrection _corr({FieldCorrection? title, FieldCorrection? time}) =>
    ParsingCorrection.create(
      recipeId: 'r',
      userId: 'u',
      source: ImportSource.url,
      originalQuality: 0.5,
      titleCorrection: title,
      timeCorrection: time,
    );

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  test('empty domain stats yields empty list, zero total, no crash', () async {
    final vm = ParsingDetailsViewModel(repository: _FakeParsingRepo());
    await vm.load();
    expect(vm.stats, isEmpty);
    expect(vm.totalCorrections, 0);
    expect(vm.domainCount, 0);
    expect(vm.topDomain, isNull);
    expect(vm.error, isNull);
    vm.dispose();
  });

  test(
    'domains sorted most-corrected first; total + topDomain correct',
    () async {
      final vm = ParsingDetailsViewModel(
        repository: _FakeParsingRepo(
          domainStats: {'a.se': 1, 'b.se': 3, 'c.se': 2},
        ),
      );
      await vm.load();
      expect(vm.stats.map((s) => s.domain), ['b.se', 'c.se', 'a.se']);
      expect(vm.totalCorrections, 6);
      expect(vm.domainCount, 3);
      expect(vm.topDomain, 'b.se');
      vm.dispose();
    },
  );

  test('dominant issue is the most-corrected field for the domain', () async {
    final vm = ParsingDetailsViewModel(
      repository: _FakeParsingRepo(
        domainStats: {'koket.se': 3},
        byDomain: {
          'koket.se': [
            _corr(title: _fc),
            _corr(title: _fc),
            _corr(time: _fc), // title (2) > time (1)
          ],
        },
      ),
    );
    await vm.load();
    expect(vm.stats.single.topIssue, ParsingIssue.title);
    vm.dispose();
  });

  test(
    "'unknown' domain bucket is not fetched for detail (stays none)",
    () async {
      final vm = ParsingDetailsViewModel(
        repository: _FakeParsingRepo(
          domainStats: {'unknown': 5},
          byDomain: {
            'unknown': [_corr(title: _fc)], // provided, but must be skipped
          },
        ),
      );
      await vm.load();
      expect(vm.stats.single.topIssue, ParsingIssue.none);
      vm.dispose();
    },
  );

  test(
    'domains beyond the detail cap keep their count but topIssue stays none',
    () async {
      // 31 domains, descending counts 31..1. The 31st (count 1) is past the
      // _maxDetailDomains=30 cap, so its detail is never fetched.
      final stats = <String, int>{};
      final byDomain = <String, List<ParsingCorrection>>{};
      for (var i = 0; i < 31; i++) {
        final d = 'd$i.se';
        stats[d] = 31 - i; // d0=31 (top) … d30=1 (last)
        byDomain[d] = [_corr(title: _fc)]; // detail available for all
      }
      final vm = ParsingDetailsViewModel(
        repository: _FakeParsingRepo(domainStats: stats, byDomain: byDomain),
      );
      await vm.load();
      expect(vm.stats.length, 31);
      // Top domain got detail; the capped last one did not.
      expect(vm.stats.first.topIssue, ParsingIssue.title);
      expect(vm.stats.last.topIssue, ParsingIssue.none);
      expect(vm.stats.last.corrections, 1); // count still present
      vm.dispose();
    },
  );

  test('load failure sets error state', () async {
    final repo = _FakeParsingRepo()..throwOnLoad = true;
    final vm = ParsingDetailsViewModel(repository: repo);
    await vm.load();
    expect(vm.error, AppLocale.current.adminParsingStatsLoadFailed);
    expect(vm.stats, isEmpty);
    vm.dispose();
  });

  test('refresh reloads (the refresh button entry point)', () async {
    final repo = _FakeParsingRepo(domainStats: {'a.se': 1});
    final vm = ParsingDetailsViewModel(repository: repo);
    await vm.refresh();
    expect(vm.topDomain, 'a.se');
    vm.dispose();
  });

  group('import success share', () {
    test('comes from the import records, rounded to whole percent', () async {
      final vm = ParsingDetailsViewModel(
        repository: _FakeParsingRepo(domainStats: {'a.se': 2, 'b.se': 1}),
        siteConfigs: _FakeSiteConfigs([
          const SiteConfig(domain: 'a.se', successCount: 2, failureCount: 1),
          const SiteConfig(domain: 'b.se'),
        ]),
      );
      await vm.load();
      expect(vm.stats.first.successPercent, 67); // 66.7 rounds up, not down
      expect(vm.stats.last.successPercent, isNull); // no import record yet
      vm.dispose();
    });

    test('a failed read leaves the column empty, not the tab', () async {
      final vm = ParsingDetailsViewModel(
        repository: _FakeParsingRepo(domainStats: {'a.se': 2}),
        siteConfigs: _FakeSiteConfigs(const [], fail: true),
      );
      await vm.load();
      expect(vm.error, isNull);
      expect(vm.stats.single.successPercent, isNull);
      vm.dispose();
    });
  });
}
