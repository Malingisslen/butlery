/// Tests for ImportHealthViewModel — the admin import-health screen's logic:
/// it must surface only domains with real import activity, sort the worst
/// (failing) domains to the top, and compute correct summary totals. A bug
/// here would hide failing recipe sites or mis-rank them in the dashboard.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/parsing/site_config.dart';
import 'package:butlery/repositories/site_config_repository.dart';
import 'package:butlery/viewmodels/admin/import_health_viewmodel.dart';

import '../../../test_support/base_unit_test.dart';

class _FakeSiteConfigRepository extends SiteConfigRepository {
  _FakeSiteConfigRepository(this._configs)
      : super(firestore: FakeFirebaseFirestore());

  final List<SiteConfig> _configs;
  bool throwOnLoad = false;

  @override
  Future<List<SiteConfig>> getAllConfigs({int limit = 200}) async {
    if (throwOnLoad) throw Exception('boom');
    return _configs;
  }
}

SiteConfig _cfg(String domain, {required int success, required int fail}) =>
    SiteConfig(
      domain: domain,
      successCount: success,
      failureCount: fail,
      lastUpdated: DateTime.utc(2026, 3, 15),
    );

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  test('load keeps only domains with import activity', () async {
    final repo = _FakeSiteConfigRepository([
      _cfg('active.se', success: 1, fail: 0),
      _cfg('never.se', success: 0, fail: 0), // no activity — excluded
    ]);
    final vm = ImportHealthViewModel(repository: repo);
    await vm.load();
    expect(vm.stats.map((c) => c.domain), ['active.se']);
    vm.dispose();
  });

  test('load sorts failing domains first, worst success rate before better',
      () async {
    final repo = _FakeSiteConfigRepository([
      _cfg('ok.se', success: 5, fail: 0), // no failures → last
      _cfg('half.se', success: 2, fail: 2), // fails, rate 50%
      _cfg('broken.se', success: 0, fail: 3), // fails, rate 0% → first
    ]);
    final vm = ImportHealthViewModel(repository: repo);
    await vm.load();
    expect(
      vm.stats.map((c) => c.domain),
      ['broken.se', 'half.se', 'ok.se'],
    );
    vm.dispose();
  });

  test('summary totals and overall rate are correct', () async {
    final repo = _FakeSiteConfigRepository([
      _cfg('a.se', success: 5, fail: 0),
      _cfg('b.se', success: 0, fail: 3),
      _cfg('c.se', success: 2, fail: 2),
    ]);
    final vm = ImportHealthViewModel(repository: repo);
    await vm.load();
    expect(vm.totalDomains, 3);
    expect(vm.totalSuccess, 7);
    expect(vm.totalFailure, 5);
    expect(vm.overallSuccessRate, closeTo(7 / 12, 0.0001));
    vm.dispose();
  });

  test('empty repo result yields empty stats and zero rate', () async {
    final repo = _FakeSiteConfigRepository([]);
    final vm = ImportHealthViewModel(repository: repo);
    await vm.load();
    expect(vm.stats, isEmpty);
    expect(vm.overallSuccessRate, 0);
    vm.dispose();
  });

  test('load failure sets error state', () async {
    final repo = _FakeSiteConfigRepository([])..throwOnLoad = true;
    final vm = ImportHealthViewModel(repository: repo);
    await vm.load();
    expect(vm.error, isNotNull);
    expect(vm.stats, isEmpty);
    vm.dispose();
  });

  test('refresh reloads stats (the refresh button entry point)', () async {
    final repo = _FakeSiteConfigRepository([_cfg('a.se', success: 1, fail: 0)]);
    final vm = ImportHealthViewModel(repository: repo);
    await vm.refresh();
    expect(vm.stats.map((c) => c.domain), ['a.se']);
    vm.dispose();
  });
}
