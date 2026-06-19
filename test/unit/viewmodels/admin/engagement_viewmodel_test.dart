/// Tests for EngagementViewModel — the admin engagement tab's logic: it must
/// load the user count and recent daily feature-retention aggregates, derive
/// the "active" proxies from the latest day, and degrade to empty/error states
/// without crashing when there is no data (the pre-launch reality). A bug here
/// would either crash the tab on zero data or report wrong active-user numbers.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/admin/engagement_stats.dart';
import 'package:butlery/repositories/engagement_repository.dart';
import 'package:butlery/viewmodels/admin/engagement_viewmodel.dart';

import '../../../test_support/base_unit_test.dart';

class _FakeEngagementRepository extends EngagementRepository {
  _FakeEngagementRepository({
    this.userCount = 0,
    this.days = const [],
  }) : super(firestore: FakeFirebaseFirestore());

  int userCount;
  List<DailyEngagement> days;
  bool throwOnLoad = false;

  @override
  Future<int> getUserCount() async {
    if (throwOnLoad) throw Exception('boom');
    return userCount;
  }

  @override
  Future<List<DailyEngagement>> getDailyFeatureRetention(
      {int limit = 14}) async {
    if (throwOnLoad) throw Exception('boom');
    return days;
  }
}

DailyEngagement _day(
  String date, {
  FeatureCounts dau = const FeatureCounts(),
  FeatureCounts wau7d = const FeatureCounts(),
  FeatureCounts wau28d = const FeatureCounts(),
}) =>
    DailyEngagement(date: date, dau: dau, wau7d: wau7d, wau28d: wau28d);

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  test('zero data yields empty days but no crash (pre-launch state)', () async {
    final vm = EngagementViewModel(repository: _FakeEngagementRepository());
    await vm.load();
    expect(vm.userCount, 0);
    expect(vm.days, isEmpty);
    expect(vm.activeToday, 0);
    expect(vm.active7d, 0);
    expect(vm.active28d, 0);
    expect(vm.error, isNull);
    vm.dispose();
  });

  test('user count loads even when there is no activity data', () async {
    final vm = EngagementViewModel(
      repository: _FakeEngagementRepository(userCount: 3),
    );
    await vm.load();
    expect(vm.userCount, 3);
    expect(vm.days, isEmpty);
    vm.dispose();
  });

  test('active proxies derive from the latest day, max across features',
      () async {
    final vm = EngagementViewModel(
      repository: _FakeEngagementRepository(
        userCount: 5,
        days: [
          // newest first — only this one feeds the stat cards
          _day(
            '2026-06-19',
            dau: const FeatureCounts(cooked: 2, imported: 4),
            wau7d: const FeatureCounts(shared: 6),
            wau28d: const FeatureCounts(shopped: 9),
          ),
          _day('2026-06-18', dau: const FeatureCounts(cooked: 99)),
        ],
      ),
    );
    await vm.load();
    expect(vm.activeToday, 4); // max(2,4,...) from latest day
    expect(vm.active7d, 6);
    expect(vm.active28d, 9);
    expect(vm.days.length, 2);
    vm.dispose();
  });

  test('load failure sets error state without partial data', () async {
    final repo = _FakeEngagementRepository()..throwOnLoad = true;
    final vm = EngagementViewModel(repository: repo);
    await vm.load();
    expect(vm.error, isNotNull);
    expect(vm.days, isEmpty);
    vm.dispose();
  });

  test('refresh reloads (the refresh button entry point)', () async {
    final repo = _FakeEngagementRepository(userCount: 1);
    final vm = EngagementViewModel(repository: repo);
    await vm.refresh();
    expect(vm.userCount, 1);
    vm.dispose();
  });
}
