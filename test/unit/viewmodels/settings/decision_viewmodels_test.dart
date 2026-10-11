// BUT-2353: owner list, decision detail and appeal form view models.
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/models/social/moderation_outcome.dart';
import 'package:butlery/services/moderation/moderation_appeals_service.dart';
import 'package:butlery/services/moderation/report_outcomes_service.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/viewmodels/settings/appeal_form_viewmodel.dart';
import 'package:butlery/viewmodels/settings/decision_detail_viewmodel.dart';
import 'package:butlery/viewmodels/settings/my_content_decisions_viewmodel.dart';

import '../../../test_support/base_unit_test.dart';

class _MockReports extends Mock implements ReportService {}

class _MockOutcomes extends Mock implements ReportOutcomesService {}

class _MockAppeals extends Mock implements ModerationAppealsService {}

ModerationOutcome _outcome(String id) => ModerationOutcome(
  reportId: id,
  decision: ModeratorDecision.contentRemoved,
  contentType: ContentType.recipe,
  reason: 'copyright',
);

ContentReport _report(String id, {ReportStatus status = ReportStatus.closed}) =>
    ContentReport(
      id: id,
      reporterId: 'me',
      contentType: ContentType.recipe,
      contentId: 'c',
      reason: 'copyright',
      status: status,
      createdAt: DateTime.utc(2026, 10, 8),
    );

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    registerFallbackValue(AppealRole.owner);
  });

  late _MockReports reports;
  late _MockOutcomes outcomes;
  late _MockAppeals appeals;

  setUp(() {
    reports = _MockReports();
    outcomes = _MockOutcomes();
    appeals = _MockAppeals();
  });

  group('MyContentDecisionsViewModel', () {
    test('load fills the list; a failure is an error state', () async {
      final vm = MyContentDecisionsViewModel(reportOutcomesService: outcomes);
      when(
        () => outcomes.getMyContentDecisions(),
      ).thenAnswer((_) async => [_outcome('a')]);

      expect(await vm.load(), isTrue);
      expect(vm.decisions.single.reportId, 'a');
      expect(vm.hasDecisions, isTrue);

      when(() => outcomes.getMyContentDecisions()).thenThrow(Exception('x'));
      expect(await vm.refresh(), isFalse);
      expect(vm.hasError, isTrue);
    });
  });

  group('DecisionDetailViewModel', () {
    DecisionDetailViewModel detail(
      AppealRole role, {
      ModerationOutcome? outcome,
      ContentReport? report,
    }) => DecisionDetailViewModel(
      role: role,
      reportId: 'r1',
      reportService: reports,
      outcomesService: outcomes,
      outcome: outcome,
      report: report,
    );

    test(
      'owner mode finds its decision and takes type and reason from it',
      () async {
        when(
          () => outcomes.getMyContentDecisions(),
        ).thenAnswer((_) async => [_outcome('other'), _outcome('r1')]);
        final vm = detail(AppealRole.owner);

        await vm.load();

        expect(vm.isReady, isTrue);
        expect(vm.contentType, ContentType.recipe);
        expect(vm.reason, 'copyright');
        expect(vm.reportedAt, isNull);
      },
    );

    test('owner mode with an unknown id is not found, not an error', () async {
      when(
        () => outcomes.getMyContentDecisions(),
      ).thenAnswer((_) async => [_outcome('other')]);
      final vm = detail(AppealRole.owner);

      await vm.load();

      expect(vm.notFound, isTrue);
      expect(vm.hasError, isFalse);
    });

    test('reporter mode reads its report and the closed outcome', () async {
      when(() => reports.getMyReports()).thenAnswer(
        (_) async => [_report('zzz'), _report('r1')],
      );
      when(
        () => outcomes.getMyReportOutcomeDetails(),
      ).thenAnswer((_) async => {'r1': _outcome('r1')});
      final vm = detail(AppealRole.reporter);

      await vm.load();

      expect(vm.report!.id, 'r1');
      expect(vm.outcome!.decision, ModeratorDecision.contentRemoved);
      expect(vm.reportedAt, DateTime.utc(2026, 10, 8));
    });

    test(
      'an open report has no outcome and the outcomes call is skipped',
      () async {
        when(() => reports.getMyReports()).thenAnswer(
          (_) async => [_report('r1', status: ReportStatus.inReview)],
        );
        final vm = detail(AppealRole.reporter);

        await vm.load();

        expect(vm.outcome, isNull);
        expect(vm.isReady, isTrue);
        verifyNever(() => outcomes.getMyReportOutcomeDetails());
      },
    );

    test('what the list already holds is not fetched again', () async {
      final vm = detail(
        AppealRole.reporter,
        outcome: _outcome('r1'),
        report: _report('r1'),
      );

      await vm.load();

      verifyNever(() => reports.getMyReports());
      verifyNever(() => outcomes.getMyContentDecisions());
    });

    test('a failing fetch is an error and reload retries', () async {
      when(() => outcomes.getMyContentDecisions()).thenThrow(Exception('x'));
      final vm = detail(AppealRole.owner);

      expect(await vm.load(), isFalse);
      expect(vm.hasError, isTrue);

      when(
        () => outcomes.getMyContentDecisions(),
      ).thenAnswer((_) async => [_outcome('r1')]);
      expect(await vm.reload(), isTrue);
      expect(vm.isReady, isTrue);
    });
  });

  group('AppealFormViewModel', () {
    AppealFormViewModel form() => AppealFormViewModel(
      reportId: 'r1',
      role: AppealRole.owner,
      service: appeals,
    );

    test('submit is enabled from ten characters, trimmed', () {
      final vm = form();
      expect(vm.canSubmit, isFalse);
      vm.setText('         kort');
      expect(vm.canSubmit, isFalse);
      vm.setText('precis tio!');
      expect(vm.canSubmit, isTrue);
    });

    test('over 1000 characters cannot be sent', () {
      final vm = form()..setText('a' * 1001);
      expect(vm.canSubmit, isFalse);
      vm.setText('a' * 1000);
      expect(vm.canSubmit, isTrue);
    });

    test('the maximum counts the trimmed text, as the server does', () {
      final vm = form()..setText('${'a' * 1000}   ');
      expect(vm.canSubmit, isTrue);
      vm.setText('  ${'a' * 1001}  ');
      expect(vm.canSubmit, isFalse);
    });

    test('a successful submit sends report, role and text', () async {
      when(
        () => appeals.submitAppeal(
          reportId: any(named: 'reportId'),
          role: any(named: 'role'),
          text: any(named: 'text'),
        ),
      ).thenAnswer((_) async {});
      final vm = form()..setText('Receptet är mitt eget');

      expect(await vm.submit(), isTrue);
      verify(
        () => appeals.submitAppeal(
          reportId: 'r1',
          role: AppealRole.owner,
          text: 'Receptet är mitt eget',
        ),
      ).called(1);
      expect(vm.failure, isNull);
    });

    test('a refusal keeps the failure code', () async {
      when(
        () => appeals.submitAppeal(
          reportId: any(named: 'reportId'),
          role: any(named: 'role'),
          text: any(named: 'text'),
        ),
      ).thenThrow(const AppealException(AppealFailure.windowClosed));
      final vm = form()..setText('Receptet är mitt eget');

      expect(await vm.submit(), isFalse);
      expect(vm.failure, AppealFailure.windowClosed);
      expect(vm.isLoading, isFalse);
    });

    test('an unexpected error is the generic failure', () async {
      when(
        () => appeals.submitAppeal(
          reportId: any(named: 'reportId'),
          role: any(named: 'role'),
          text: any(named: 'text'),
        ),
      ).thenThrow(Exception('boom'));
      final vm = form()..setText('Receptet är mitt eget');

      expect(await vm.submit(), isFalse);
      expect(vm.failure, AppealFailure.other);
    });

    test('a too-short text is not sent at all', () async {
      final vm = form()..setText('kort');

      expect(await vm.submit(), isFalse);
      verifyNever(
        () => appeals.submitAppeal(
          reportId: any(named: 'reportId'),
          role: any(named: 'role'),
          text: any(named: 'text'),
        ),
      );
    });
  });
}
