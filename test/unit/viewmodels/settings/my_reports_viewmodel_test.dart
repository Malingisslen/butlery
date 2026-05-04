/// BUT-537: ViewModel-level test for `MyReportsViewModel`.
///
/// We mock `ReportService` (not `getMyReports` itself) to assert the VM
/// sequences loading → success/error states correctly, since that contract is
/// what the view binds to.
library;

import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/viewmodels/settings/my_reports_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockReportService extends Mock implements ReportService {}

ContentReport _report({
  required String id,
  String reason = 'spam',
  ReportStatus status = ReportStatus.newReport,
}) =>
    ContentReport(
      id: id,
      reporterId: 'reporter1',
      contentType: ContentType.comment,
      contentId: 'c$id',
      reason: reason,
      status: status,
      createdAt: DateTime.utc(2026, 5, 4),
      guidelineVersion: '2026-02-28',
    );

void main() {
  group('MyReportsViewModel', () {
    late _MockReportService service;
    late MyReportsViewModel vm;

    setUp(() {
      service = _MockReportService();
      vm = MyReportsViewModel(reportService: service);
    });

    test('initial state — empty, not loading, no error', () {
      expect(vm.reports, isEmpty);
      expect(vm.hasReports, isFalse);
      expect(vm.isLoading, isFalse);
      expect(vm.hasError, isFalse);
    });

    test('load() populates reports and clears loading', () async {
      when(() => service.getMyReports()).thenAnswer((_) async => [
            _report(id: '1'),
            _report(id: '2', status: ReportStatus.actioned),
          ]);

      final ok = await vm.load();

      expect(ok, isTrue);
      expect(vm.reports.length, equals(2));
      expect(vm.hasReports, isTrue);
      expect(vm.isLoading, isFalse);
      expect(vm.hasError, isFalse);
    });

    test('load() surfaces error state when service throws', () async {
      when(() => service.getMyReports())
          .thenThrow(Exception('firestore offline'));

      final ok = await vm.load();

      expect(ok, isFalse);
      expect(vm.reports, isEmpty,
          reason: 'Failed load should not partially populate.');
      expect(vm.hasError, isTrue);
      expect(vm.isLoading, isFalse);
    });

    test('refresh() re-invokes the service and replaces report list', () async {
      when(() => service.getMyReports()).thenAnswer((_) async => [
            _report(id: '1'),
          ]);
      await vm.load();
      expect(vm.reports.single.id, equals('1'));

      when(() => service.getMyReports()).thenAnswer((_) async => [
            _report(id: '2'),
            _report(id: '3'),
          ]);
      await vm.refresh();

      expect(vm.reports.map((r) => r.id), equals(['2', '3']));
      verify(() => service.getMyReports()).called(2);
    });

    test('hasReports tracks the underlying list', () async {
      when(() => service.getMyReports()).thenAnswer((_) async => []);
      await vm.load();
      expect(vm.hasReports, isFalse);

      when(() => service.getMyReports()).thenAnswer((_) async => [
            _report(id: '1'),
          ]);
      await vm.refresh();
      expect(vm.hasReports, isTrue);
    });
  });
}
