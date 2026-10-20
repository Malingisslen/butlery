// BUT-1528: the Stängda tab, the sheet with its reopen button, and a
// reopened report in the Rapporter queue.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/social/closed_report.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/models/social/report_evidence.dart';
import 'package:butlery/services/moderation/moderation_appeals_service.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/views/admin/moderator_review_view.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockReports extends Mock implements ReportService {}

class _MockAppeals extends Mock implements ModerationAppealsService {}

class _FakeReport extends Fake implements ContentReport {}

final _sv = AppLocalizationsSv();

ClosedReport _closed(
  String id, {
  ModeratorDecision decision = ModeratorDecision.profileHidden,
  int daysAgo = 1,
  bool appealed = false,
  List<PastDecision> history = const [],
  ReopenBlock? block,
  ContentType type = ContentType.profile,
}) => ClosedReport(
  reportId: id,
  decision: decision,
  moderator: DecisionMaker.self,
  rule: 'harassment',
  decidedAt: DateTime.now().subtract(Duration(days: daysAgo)),
  contentType: type,
  history: history,
  appealed: appealed,
  reopenBlock: block,
);

ContentReport _reopened({
  ModeratorDecision? action,
  ModeratorDecision? reopenedDecision,
}) => ContentReport(
  id: 'r1',
  reporterId: 'reporter',
  contentType: ContentType.profile,
  contentId: 'c1',
  contentOwnerId: 'owner',
  reason: 'harassment',
  status: ReportStatus.actioned,
  createdAt: DateTime(2026, 10, 8),
  moderatorAction: action,
  reviewRound: 1,
  reopenedAt: DateTime(2026, 10, 20),
  reopenedDecision: reopenedDecision ?? action ?? ModeratorDecision.noAction,
);

void main() {
  late _MockReports reports;
  late _MockAppeals appeals;
  late StreamController<List<ContentReport>> stream;

  setUpAll(() => registerFallbackValue(_FakeReport()));

  setUp(() async {
    await GetIt.instance.reset();
    reports = _MockReports();
    appeals = _MockAppeals();
    stream = StreamController<List<ContentReport>>.broadcast();
    when(() => reports.watchIsAdmin()).thenAnswer((_) => Stream.value(true));
    when(() => reports.watchOpenReports()).thenAnswer((_) => stream.stream);
    when(() => reports.isMinorAccount(any())).thenAnswer((_) async => false);
    when(
      () => reports.getReportEvidence(any(), round: any(named: 'round')),
    ).thenAnswer(
      (_) async => (
        evidence: ReportEvidence(
          reportId: 'r1',
          outcome: EvidenceOutcome.captured,
          capturedAt: DateTime(2026, 10, 20, 10, 12),
        ),
      ),
    );
    when(
      () => reports.closeReport(any(), motivation: any(named: 'motivation')),
    ).thenAnswer((_) async => true);
    when(() => reports.closeWithNoAction(any())).thenAnswer((_) async => true);
    when(() => appeals.listOpenAppeals()).thenAnswer((_) async => []);
    GetIt.instance.registerSingleton<ReportService>(reports);
    GetIt.instance.registerSingleton<ModerationAppealsService>(appeals);
    prod.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    await stream.close();
    prod.ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  Future<void> pumpView(WidgetTester tester, [ContentReport? report]) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: const ModeratorReviewView(),
      ),
    );
    await tester.pump();
    stream.add([?report]);
    await tester.pumpAndSettle();
  }

  Future<void> openClosedTab(WidgetTester tester) async {
    await tester.tap(find.text(_sv.moderatorTabClosed));
    await tester.pumpAndSettle();
  }

  group('Stängda tab', () {
    testWidgets('is the third tab, has no count and loads only when shown', (
      tester,
    ) async {
      when(
        () => appeals.listClosedReports(),
      ).thenAnswer((_) async => const ClosedReportsPage(reports: []));
      await pumpView(tester);

      expect(find.text(_sv.moderatorTabClosed), findsOneWidget);
      verifyNever(() => appeals.listClosedReports());

      await openClosedTab(tester);

      verify(() => appeals.listClosedReports()).called(1);
      expect(find.text(_sv.moderatorClosedEmpty), findsOneWidget);
    });

    testWidgets('rows are grouped by week and carry their label, subtitle '
        'and pills', (tester) async {
      when(() => appeals.listClosedReports()).thenAnswer(
        (_) async => ClosedReportsPage(
          reports: [
            _closed('a'),
            _closed(
              'b',
              decision: ModeratorDecision.contentRemoved,
              appealed: true,
            ),
            _closed(
              'c',
              decision: ModeratorDecision.noAction,
              history: const [
                PastDecision(
                  decision: ModeratorDecision.contentRemoved,
                  moderator: DecisionMaker.self,
                ),
              ],
            ),
            _closed('d', daysAgo: 20),
          ],
        ),
      );
      await pumpView(tester);
      await openClosedTab(tester);

      expect(
        find.text(_sv.moderatorClosedThisWeek.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.text(_sv.moderatorClosedEarlier.toUpperCase()),
        findsOneWidget,
      );
      expect(find.text(_sv.moderatorDecisionProfileHidden), findsNWidgets(2));
      expect(find.text(_sv.moderatorDecisionContentRemoved), findsOneWidget);
      expect(find.text(_sv.moderatorDecisionNoAction), findsOneWidget);
      expect(
        find.textContaining(
          '${_sv.reportReasonHarassment} · ${_sv.moderatorContentTypeProfile} · ',
        ),
        findsNWidgets(4),
      );
      expect(
        find.textContaining(' · ${_sv.moderatorByYou}'),
        findsNWidgets(4),
      );
      expect(
        find.text(_sv.moderatorPillAppealed.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.text(_sv.decisionStatusRevised.toUpperCase()),
        findsOneWidget,
      );
      expect(find.text(_sv.moderatorClosedShowMore), findsNothing);
    });

    testWidgets('Visa fler loads the next page with the cursor', (
      tester,
    ) async {
      when(() => appeals.listClosedReports()).thenAnswer(
        (_) async =>
            ClosedReportsPage(reports: [_closed('a')], nextCursor: 'c1'),
      );
      when(() => appeals.listClosedReports(cursor: 'c1')).thenAnswer(
        (_) async => ClosedReportsPage(
          reports: [_closed('b', decision: ModeratorDecision.noAction)],
        ),
      );
      await pumpView(tester);
      await openClosedTab(tester);
      expect(find.text(_sv.moderatorDecisionNoAction), findsNothing);

      await tester.tap(find.text(_sv.moderatorClosedShowMore));
      await tester.pumpAndSettle();

      expect(find.text(_sv.moderatorDecisionNoAction), findsOneWidget);
      expect(find.text(_sv.moderatorClosedShowMore), findsNothing);
    });

    testWidgets('a failed load is the error state with a retry', (
      tester,
    ) async {
      when(() => appeals.listClosedReports()).thenThrow(Exception('x'));
      await pumpView(tester);
      await openClosedTab(tester);

      expect(find.text(_sv.moderatorClosedLoadFailed), findsOneWidget);

      when(() => appeals.listClosedReports()).thenAnswer(
        (_) async => ClosedReportsPage(reports: [_closed('a')]),
      );
      await tester.tap(find.text(_sv.commonRetry));
      await tester.pumpAndSettle();

      verify(() => appeals.listClosedReports()).called(2);
      expect(find.text(_sv.moderatorDecisionProfileHidden), findsOneWidget);
    });

    testWidgets('a row opens the sheet with its facts and its history', (
      tester,
    ) async {
      when(() => appeals.listClosedReports()).thenAnswer(
        (_) async => ClosedReportsPage(
          reports: [
            _closed(
              'c',
              decision: ModeratorDecision.noAction,
              history: [
                PastDecision(
                  decision: ModeratorDecision.contentRemoved,
                  moderator: DecisionMaker.other,
                  rule: 'spam',
                  decidedAt: DateTime.now().subtract(const Duration(days: 5)),
                ),
              ],
            ),
          ],
        ),
      );
      await pumpView(tester);
      await openClosedTab(tester);

      await tester.tap(find.text(_sv.moderatorDecisionNoAction));
      await tester.pumpAndSettle();

      // "Beslut" is both the sheet's title and its first row.
      expect(find.text(_sv.moderatorClosedRowDecision), findsNWidgets(2));
      for (final label in [
        _sv.moderatorClosedRowRule,
        _sv.moderatorClosedRowAbout,
        _sv.moderatorClosedRowDecided,
        _sv.moderatorClosedRowModerator,
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(
        find.text(_sv.moderatorClosedHistoryTitle.toUpperCase()),
        findsOneWidget,
      );
      expect(find.textContaining(_sv.moderatorByOther), findsOneWidget);
      expect(find.text(_sv.moderatorClosedNote), findsOneWidget);
    });

    testWidgets('Öppna igen asks first, then reopens, drops the row and moves '
        'to Rapporter', (tester) async {
      when(() => appeals.listClosedReports()).thenAnswer(
        (_) async => ClosedReportsPage(reports: [_closed('a')]),
      );
      when(() => appeals.reopenReport('a')).thenAnswer((_) async {});
      await pumpView(tester);
      await openClosedTab(tester);

      await tester.tap(find.text(_sv.moderatorDecisionProfileHidden));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('closed-sheet-reopen')));
      await tester.pumpAndSettle();

      expect(find.text(_sv.moderatorReopenConfirmTitle), findsOneWidget);
      expect(find.text(_sv.moderatorReopenConfirmBody), findsOneWidget);
      verifyNever(() => appeals.reopenReport(any()));

      await tester.tap(find.text(_sv.commonCancel));
      await tester.pumpAndSettle();
      verifyNever(() => appeals.reopenReport(any()));

      await tester.tap(find.text(_sv.moderatorDecisionProfileHidden));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('closed-sheet-reopen')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(_sv.moderatorClosedReopen),
        ),
      );
      await tester.pumpAndSettle();

      verify(() => appeals.reopenReport('a')).called(1);
      expect(find.text(_sv.moderatorReopened), findsOneWidget);
      expect(find.text(_sv.moderatorNoOpenReports), findsOneWidget);
    });

    testWidgets('an appealed decision cannot be reopened: the button is '
        'disabled and a band says why', (tester) async {
      when(() => appeals.listClosedReports()).thenAnswer(
        (_) async => ClosedReportsPage(
          reports: [
            _closed(
              'b',
              decision: ModeratorDecision.contentRemoved,
              appealed: true,
              block: ReopenBlock.appealed,
            ),
          ],
        ),
      );
      await pumpView(tester);
      await openClosedTab(tester);

      await tester.tap(find.text(_sv.moderatorDecisionContentRemoved));
      await tester.pumpAndSettle();

      final button = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('closed-sheet-reopen')),
      );
      expect(button.onPressed, isNull);
      expect(find.text(_sv.moderatorReopenBlockAppealed), findsOneWidget);
      expect(find.text(_sv.moderatorClosedRemovedBand), findsNothing);
      expect(find.text(_sv.commonClose), findsOneWidget);
    });

    testWidgets('a removed-content decision warns that it cannot be restored', (
      tester,
    ) async {
      when(() => appeals.listClosedReports()).thenAnswer(
        (_) async => ClosedReportsPage(
          reports: [
            _closed('b', decision: ModeratorDecision.contentRemoved),
          ],
        ),
      );
      await pumpView(tester);
      await openClosedTab(tester);

      await tester.tap(find.text(_sv.moderatorDecisionContentRemoved));
      await tester.pumpAndSettle();

      expect(find.text(_sv.moderatorClosedRemovedBand), findsOneWidget);
    });

    testWidgets('a refusal found when reopening is told and the row stays', (
      tester,
    ) async {
      when(() => appeals.listClosedReports()).thenAnswer(
        (_) async => ClosedReportsPage(reports: [_closed('a')]),
      );
      when(
        () => appeals.reopenReport('a'),
      ).thenThrow(const ReopenReportException(ReopenBlock.appealed));
      await pumpView(tester);
      await openClosedTab(tester);

      await tester.tap(find.text(_sv.moderatorDecisionProfileHidden));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('closed-sheet-reopen')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(_sv.moderatorClosedReopen),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(_sv.moderatorReopenBlockAppealed), findsOneWidget);
      expect(find.text(_sv.moderatorDecisionProfileHidden), findsOneWidget);
    });

    testWidgets('a failed reopen is told and the row stays', (tester) async {
      when(() => appeals.listClosedReports()).thenAnswer(
        (_) async => ClosedReportsPage(reports: [_closed('a')]),
      );
      when(() => appeals.reopenReport('a')).thenThrow(Exception('network'));
      await pumpView(tester);
      await openClosedTab(tester);

      await tester.tap(find.text(_sv.moderatorDecisionProfileHidden));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('closed-sheet-reopen')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(_sv.moderatorClosedReopen),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining(_sv.moderatorReopenFailed), findsOneWidget);
      expect(find.text(_sv.moderatorDecisionProfileHidden), findsOneWidget);
    });
  });

  group('a reopened report in Rapporter', () {
    testWidgets('shows the pill, the earlier decision, the content now and '
        'the two buttons', (tester) async {
      await pumpView(
        tester,
        _reopened(action: ModeratorDecision.profileHidden),
      );

      expect(
        find.text(_sv.moderatorReopenedPill.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.text(
          _sv.moderatorPreviousDecision(_sv.moderatorDecisionProfileHidden),
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(_sv.moderatorEvidenceNowHeadingAt('')),
        findsOneWidget,
      );
      expect(
        find.textContaining(_sv.moderatorEvidenceHeadingAt('')),
        findsNothing,
      );
      expect(find.text(_sv.moderatorKeepDecision), findsOneWidget);
      expect(find.text(_sv.moderatorChangeToNoAction), findsOneWidget);
      expect(find.byTooltip(_sv.moderatorCloseTooltip), findsNothing);
    });

    testWidgets('an ordinary report has neither pill nor buttons', (
      tester,
    ) async {
      await pumpView(
        tester,
        ContentReport(
          id: 'r2',
          reporterId: 'x',
          contentType: ContentType.recipe,
          contentId: 'c',
          reason: 'spam',
          status: ReportStatus.newReport,
          createdAt: DateTime(2026, 10, 8),
        ),
      );

      expect(find.text(_sv.moderatorReopenedPill.toUpperCase()), findsNothing);
      expect(find.text(_sv.moderatorKeepDecision), findsNothing);
      expect(
        find.textContaining(_sv.moderatorEvidenceHeadingAt('')),
        findsOneWidget,
      );
      expect(
        find.textContaining(_sv.moderatorEvidenceNowHeadingAt('')),
        findsNothing,
      );
    });

    testWidgets('a reopened report with no standing action keeps the usual '
        'actions', (tester) async {
      await pumpView(tester, _reopened());

      expect(
        find.text(_sv.moderatorReopenedPill.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.text(_sv.moderatorPreviousDecision(_sv.moderatorDecisionNoAction)),
        findsOneWidget,
      );
      expect(find.text(_sv.moderatorKeepDecision), findsNothing);
      expect(find.byTooltip(_sv.moderatorCloseTooltip), findsOneWidget);
    });

    testWidgets('a takedown in the new round of a no-action case keeps the '
        'usual close and the true earlier decision', (tester) async {
      await pumpView(
        tester,
        _reopened(
          action: ModeratorDecision.profileHidden,
          reopenedDecision: ModeratorDecision.noAction,
        ),
      );

      expect(
        find.text(_sv.moderatorPreviousDecision(_sv.moderatorDecisionNoAction)),
        findsOneWidget,
      );
      expect(
        find.text(
          _sv.moderatorPreviousDecision(_sv.moderatorDecisionProfileHidden),
        ),
        findsNothing,
      );
      expect(find.text(_sv.moderatorKeepDecision), findsNothing);
      expect(find.byTooltip(_sv.moderatorCloseTooltip), findsOneWidget);
    });

    testWidgets('Behåll beslutet closes it as it stands, with no sheet and no '
        'motivation', (tester) async {
      final report = _reopened(action: ModeratorDecision.profileHidden);
      await pumpView(tester, report);

      await tester.tap(find.text(_sv.moderatorKeepDecision));
      await tester.pumpAndSettle();

      verify(() => reports.closeReport(report, motivation: null)).called(1);
      expect(find.text(_sv.moderatorCloseChoose), findsNothing);
      verifyNever(() => reports.closeWithNoAction(any()));
    });

    testWidgets('Ändra till Ingen åtgärd confirms first, then closes with no '
        'action', (tester) async {
      final report = _reopened(action: ModeratorDecision.profileHidden);
      await pumpView(tester, report);

      await tester.tap(find.text(_sv.moderatorChangeToNoAction));
      await tester.pumpAndSettle();

      expect(find.text(_sv.moderatorChangeConfirmTitle), findsOneWidget);
      expect(find.text(_sv.moderatorChangeConfirmBodyProfile), findsOneWidget);
      verifyNever(() => reports.closeWithNoAction(any()));

      await tester.tap(find.text(_sv.moderatorChangeConfirm));
      await tester.pumpAndSettle();

      verify(() => reports.closeWithNoAction(report)).called(1);
    });

    testWidgets('a refused Behåll beslutet is told with a retry', (
      tester,
    ) async {
      final report = _reopened(action: ModeratorDecision.profileHidden);
      when(
        () => reports.closeReport(report, motivation: null),
      ).thenAnswer((_) async => false);
      await pumpView(tester, report);

      await tester.tap(find.text(_sv.moderatorKeepDecision));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining(_sv.moderatorCloseFailed), findsOneWidget);
      await tester.tap(find.text(_sv.commonRetry));
      await tester.pumpAndSettle();
      verify(() => reports.closeReport(report, motivation: null)).called(2);
    });

    testWidgets('removed content says it cannot be restored in the change '
        'dialog', (tester) async {
      await pumpView(
        tester,
        _reopened(action: ModeratorDecision.contentRemoved),
      );

      await tester.tap(find.text(_sv.moderatorChangeToNoAction));
      await tester.pumpAndSettle();

      expect(find.text(_sv.moderatorChangeConfirmBodyRemoved), findsOneWidget);

      await tester.tap(find.text(_sv.commonCancel));
      await tester.pumpAndSettle();
      verifyNever(() => reports.closeWithNoAction(any()));
    });
  });
}
