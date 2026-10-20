// BUT-1528: the Stängda tab's list, paging, week grouping and reopen.
import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/social/closed_report.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/services/moderation/moderation_appeals_service.dart';
import 'package:butlery/viewmodels/admin/moderator_closed_viewmodel.dart';

import '../../../test_support/base_unit_test.dart';

class _MockAppeals extends Mock implements ModerationAppealsService {}

final _now = DateTime.utc(2026, 10, 20, 12);

ClosedReport _row(String id, {DateTime? decidedAt, bool appealed = false}) =>
    ClosedReport(
      reportId: id,
      decision: ModeratorDecision.noAction,
      moderator: DecisionMaker.self,
      decidedAt: decidedAt,
      appealed: appealed,
    );

void main() {
  setUpAll(BaseUnitTest.setupUnit);

  late _MockAppeals service;
  late ModeratorClosedViewModel vm;

  setUp(() {
    service = _MockAppeals();
    vm = ModeratorClosedViewModel(service: service);
  });

  tearDown(() => vm.dispose());

  void stubFirstPage(List<ClosedReport> rows, {String? next}) => when(
    () => service.listClosedReports(),
  ).thenAnswer((_) async => ClosedReportsPage(reports: rows, nextCursor: next));

  group('loading', () {
    test('nothing is asked until the tab asks, and only once', () async {
      stubFirstPage([_row('a')]);
      expect(vm.hasLoaded, isFalse);
      verifyNever(() => service.listClosedReports());

      await vm.ensureLoaded();
      await vm.ensureLoaded();

      expect(vm.hasLoaded, isTrue);
      expect(vm.reports.map((r) => r.reportId), ['a']);
      verify(() => service.listClosedReports()).called(1);
    });

    test('a failure is an error state and a retry loads', () async {
      when(() => service.listClosedReports()).thenThrow(Exception('x'));
      expect(await vm.load(), isFalse);
      expect(vm.hasError, isTrue);
      expect(vm.hasLoaded, isFalse);

      stubFirstPage([_row('a')]);
      expect(await vm.load(), isTrue);
      expect(vm.hasError, isFalse);
      expect(vm.hasLoaded, isTrue);
    });
  });

  group('week grouping', () {
    test(
      'the last 7 days by decidedAt are this week, the rest earlier',
      () async {
        await withClock(Clock.fixed(_now), () async {
          stubFirstPage([
            _row('fresh', decidedAt: _now.subtract(const Duration(days: 1))),
            _row('edge', decidedAt: _now.subtract(const Duration(days: 6))),
            _row('old', decidedAt: _now.subtract(const Duration(days: 8))),
            _row('undated'),
          ]);
          await vm.load();

          expect(vm.thisWeek.map((r) => r.reportId), ['fresh', 'edge']);
          expect(vm.earlier.map((r) => r.reportId), ['old', 'undated']);
        });
      },
    );
  });

  group('paging', () {
    test(
      'Visa fler sends the cursor and appends without repeating rows',
      () async {
        stubFirstPage([_row('a'), _row('b')], next: 'c1');
        await vm.load();
        expect(vm.hasMore, isTrue);
        when(() => service.listClosedReports(cursor: 'c1')).thenAnswer(
          (_) async => ClosedReportsPage(reports: [_row('b'), _row('c')]),
        );

        expect(await vm.loadMore(), isTrue);

        expect(vm.reports.map((r) => r.reportId), ['a', 'b', 'c']);
        expect(vm.hasMore, isFalse);
        expect(vm.isLoadingMore, isFalse);
      },
    );

    test('a failed page leaves the list and the cursor as they were', () async {
      stubFirstPage([_row('a')], next: 'c1');
      await vm.load();
      when(
        () => service.listClosedReports(cursor: 'c1'),
      ).thenThrow(Exception('x'));

      expect(await vm.loadMore(), isFalse);

      expect(vm.reports, hasLength(1));
      expect(vm.hasMore, isTrue);
      expect(vm.isLoadingMore, isFalse);
    });

    test('a second Visa fler while one is loading asks nothing more', () async {
      stubFirstPage([_row('a')], next: 'c1');
      await vm.load();
      final gate = Completer<ClosedReportsPage>();
      when(
        () => service.listClosedReports(cursor: 'c1'),
      ).thenAnswer((_) => gate.future);

      final first = vm.loadMore();
      expect(vm.isLoadingMore, isTrue);
      expect(await vm.loadMore(), isTrue);
      verify(() => service.listClosedReports(cursor: 'c1')).called(1);

      gate.complete(ClosedReportsPage(reports: [_row('b')]));
      await first;
      expect(vm.reports.map((r) => r.reportId), ['a', 'b']);
    });

    test('with no cursor there is nothing to ask for', () async {
      stubFirstPage([_row('a')]);
      await vm.load();

      expect(await vm.loadMore(), isTrue);

      verify(() => service.listClosedReports()).called(1);
      verifyNever(
        () => service.listClosedReports(cursor: any(named: 'cursor')),
      );
    });
  });

  group('reopen', () {
    setUp(() async {
      stubFirstPage([_row('a'), _row('b')]);
      await vm.load();
    });

    test('success takes the row out of the list', () async {
      when(() => service.reopenReport('a')).thenAnswer((_) async {});

      final result = await vm.reopen(vm.reports.first);

      expect(result, isA<ReopenSucceeded>());
      expect(vm.reports.map((r) => r.reportId), ['b']);
    });

    for (final block in [ReopenBlock.notClosed, ReopenBlock.reportGone]) {
      test('$block means it is no longer here: the row leaves', () async {
        when(
          () => service.reopenReport('a'),
        ).thenThrow(ReopenReportException(block));

        final result = await vm.reopen(vm.reports.first);

        expect(
          result,
          isA<ReopenBlocked>().having((r) => r.block, 'block', block),
        );
        expect(vm.reports.map((r) => r.reportId), ['b']);
      });
    }

    for (final block in [
      ReopenBlock.appealed,
      ReopenBlock.ownerErased,
      ReopenBlock.reporterErased,
      ReopenBlock.noDecision,
    ]) {
      test('$block keeps the row, disabled for the next tap', () async {
        when(
          () => service.reopenReport('a'),
        ).thenThrow(ReopenReportException(block));

        final result = await vm.reopen(vm.reports.first);

        expect(
          result,
          isA<ReopenBlocked>().having((r) => r.block, 'block', block),
        );
        expect(vm.reports.map((r) => r.reportId), ['a', 'b']);
        expect(vm.reports.first.reopenBlock, block);
        expect(vm.reports.last.reopenBlock, isNull);
        expect(vm.reports.first.appealed, block == ReopenBlock.appealed);
      });
    }

    test('any other failure keeps the row and reports failed', () async {
      when(
        () => service.reopenReport('a'),
      ).thenThrow(const ReopenReportException(null));
      expect(await vm.reopen(vm.reports.first), isA<ReopenFailed>());

      when(() => service.reopenReport('a')).thenThrow(Exception('network'));
      expect(await vm.reopen(vm.reports.first), isA<ReopenFailed>());

      expect(vm.reports, hasLength(2));
      expect(vm.reports.first.reopenBlock, isNull);
    });
  });
}
