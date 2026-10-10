/// BUT-537: ViewModel-level test for `MyReportsViewModel`.
///
/// We mock `ReportService` (not `getMyReports` itself) to assert the VM
/// sequences loading → success/error states correctly, since that contract is
/// what the view binds to.
library;

import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/services/moderation/report_outcomes_service.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/viewmodels/settings/my_reports_viewmodel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/core/l10n/app_locale.dart';

class _MockReportService extends Mock implements ReportService {}

class _MockOutcomes extends Mock implements ReportOutcomesService {}

ContentReport _report({
  required String id,
  String reason = 'spam',
  ReportStatus status = ReportStatus.newReport,
  ModeratorDecision? action,
}) => ContentReport(
  id: id,
  reporterId: 'reporter1',
  contentType: ContentType.comment,
  contentId: 'c$id',
  reason: reason,
  status: status,
  createdAt: DateTime.utc(2026, 5, 4),
  guidelineVersion: '2026-02-28',
  moderatorAction: action,
);

void main() {
  group('MyReportsViewModel', () {
    late _MockReportService service;
    late _MockOutcomes outcomes;
    late MyReportsViewModel vm;

    setUp(() {
      service = _MockReportService();
      outcomes = _MockOutcomes();
      vm = MyReportsViewModel(
        reportService: service,
        reportOutcomesService: outcomes,
      );
    });

    test('initial state — empty, not loading, no error', () {
      expect(vm.reports, isEmpty);
      expect(vm.hasReports, isFalse);
      expect(vm.isLoading, isFalse);
      expect(vm.hasError, isFalse);
    });

    test('load() populates reports and clears loading', () async {
      when(() => service.getMyReports()).thenAnswer(
        (_) async => [
          _report(id: '1'),
          _report(id: '2', status: ReportStatus.actioned),
        ],
      );

      final ok = await vm.load();

      expect(ok, isTrue);
      expect(vm.reports.length, equals(2));
      expect(vm.hasReports, isTrue);
      expect(vm.isLoading, isFalse);
      expect(vm.hasError, isFalse);
    });

    test('load() surfaces error state when service throws', () async {
      when(
        () => service.getMyReports(),
      ).thenThrow(Exception('firestore offline'));

      final ok = await vm.load();

      expect(ok, isFalse);
      expect(
        vm.reports,
        isEmpty,
        reason: 'Failed load should not partially populate.',
      );
      expect(vm.hasError, isTrue);
      expect(vm.error, AppLocale.current.myReportsLoadFailed);
      expect(vm.isLoading, isFalse);
    });

    // P7-C2: the failure text is localized, not the old internal tag
    // 'my_reports_load'; an English user reads English.
    test('load() failure text follows the app locale', () async {
      AppLocale.updateLocale(const Locale('en'));
      addTearDown(() => AppLocale.updateLocale(const Locale('sv')));
      when(
        () => service.getMyReports(),
      ).thenThrow(Exception('firestore offline'));

      await vm.load();

      expect(vm.error, 'Could not load reports');
      expect(vm.error, isNot(contains('my_reports_load')));
    });

    test('refresh() re-invokes the service and replaces report list', () async {
      when(() => service.getMyReports()).thenAnswer(
        (_) async => [
          _report(id: '1'),
        ],
      );
      await vm.load();
      expect(vm.reports.single.id, equals('1'));

      when(() => service.getMyReports()).thenAnswer(
        (_) async => [
          _report(id: '2'),
          _report(id: '3'),
        ],
      );
      await vm.refresh();

      expect(vm.reports.map((r) => r.id), equals(['2', '3']));
      verify(() => service.getMyReports()).called(2);
    });

    test('hasReports tracks the underlying list', () async {
      when(() => service.getMyReports()).thenAnswer((_) async => []);
      await vm.load();
      expect(vm.hasReports, isFalse);

      when(() => service.getMyReports()).thenAnswer(
        (_) async => [
          _report(id: '1'),
        ],
      );
      await vm.refresh();
      expect(vm.hasReports, isTrue);
    });

    group('outcomes (BUT-2222)', () {
      test('decisionFor merges open-report stamp and closed outcome', () async {
        when(() => service.getMyReports()).thenAnswer(
          (_) async => [
            _report(
              id: 'open',
              status: ReportStatus.actioned,
              action: ModeratorDecision.profileHidden,
            ),
            _report(id: 'done', status: ReportStatus.closed),
            _report(id: 'bare', status: ReportStatus.closed),
          ],
        );
        when(() => outcomes.getMyReportOutcomes()).thenAnswer(
          (_) async => {'done': ModeratorDecision.noAction},
        );

        await vm.load();

        expect(
          vm.decisionFor(vm.reports[0]),
          ModeratorDecision.profileHidden,
        );
        expect(vm.decisionFor(vm.reports[1]), ModeratorDecision.noAction);
        expect(vm.decisionFor(vm.reports[2]), isNull);
      });

      test(
        'callable failure keeps reports loaded and shows no error',
        () async {
          when(() => service.getMyReports()).thenAnswer(
            (_) async => [_report(id: 'done', status: ReportStatus.closed)],
          );
          when(
            () => outcomes.getMyReportOutcomes(),
          ).thenThrow(Exception('boom'));

          final ok = await vm.load();

          expect(ok, isTrue);
          expect(vm.hasError, isFalse);
          expect(vm.reports, hasLength(1));
          expect(vm.decisionFor(vm.reports.single), isNull);
        },
      );

      test('callable is not called when no report is closed', () async {
        when(() => service.getMyReports()).thenAnswer(
          (_) async => [
            _report(id: '1'),
            _report(id: '2', status: ReportStatus.inReview),
          ],
        );

        await vm.load();

        verifyNever(() => outcomes.getMyReportOutcomes());
      });
    });
  });
}
