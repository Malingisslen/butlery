// BUT-2353: "Stäng och meddela" sheet, the close that carries the motivation,
// and the Överklaganden tab with its answer sheet.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/models/social/moderation_motivation.dart';
import 'package:butlery/models/social/moderation_outcome.dart';
import 'package:butlery/services/moderation/moderation_appeals_service.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/views/admin/moderator_close_sheet.dart';
import 'package:butlery/views/admin/moderator_review_view.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockReports extends Mock implements ReportService {}

class _MockAppeals extends Mock implements ModerationAppealsService {}

class _FakeReport extends Fake implements ContentReport {}

final _sv = AppLocalizationsSv();

ContentReport _report({
  String reason = 'copyright',
  ModeratorDecision? action,
}) => ContentReport(
  id: 'r1',
  reporterId: 'reporter',
  contentType: ContentType.recipe,
  contentId: 'c1',
  contentOwnerId: 'owner',
  reason: reason,
  status: ReportStatus.actioned,
  createdAt: DateTime(2026, 10, 8),
  moderatorAction: action,
);

OpenAppeal _appeal({
  ModeratorDecision decision = ModeratorDecision.contentRemoved,
  AppealRole role = AppealRole.owner,
}) => OpenAppeal(
  appealId: 'r1_${role.name}',
  reportId: 'r1',
  role: role,
  decision: decision,
  text: 'Receptet är mitt eget',
  contentType: ContentType.recipe,
  contentId: 'rcp1',
  reason: 'copyright',
  decidedAt: DateTime.utc(2026, 10, 10),
  createdAt: DateTime.utc(2026, 10, 11),
);

void main() {
  late _MockReports reports;
  late _MockAppeals appeals;
  late StreamController<List<ContentReport>> stream;

  setUpAll(() {
    registerFallbackValue(_FakeReport());
    registerFallbackValue(AppealStatus.upheld);
  });

  setUp(() async {
    await GetIt.instance.reset();
    reports = _MockReports();
    appeals = _MockAppeals();
    stream = StreamController<List<ContentReport>>.broadcast();
    when(() => reports.watchIsAdmin()).thenAnswer((_) => Stream.value(true));
    when(() => reports.watchOpenReports()).thenAnswer((_) => stream.stream);
    when(() => reports.isMinorAccount(any())).thenAnswer((_) async => false);
    when(
      () => reports.getReportEvidence(any()),
    ).thenAnswer((_) async => (evidence: null));
    when(
      () => reports.closeReport(any(), motivation: any(named: 'motivation')),
    ).thenAnswer((_) async => true);
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
    await tester.pump();
    await tester.pump();
  }

  group('ModeratorCloseSheet', () {
    Future<void> openSheet(
      WidgetTester tester,
      ModeratorDecision decision,
    ) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModeratorCloseSheet(
                context,
                decision: decision,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('lists only the removal reasons, default preselected, and '
        'returns the chosen key', (tester) async {
      ModerationMotivation? result;
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showModeratorCloseSheet(
                context,
                decision: ModeratorDecision.contentRemoved,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text(_sv.moderatorCloseSheetTitle), findsNWidgets(2));
      expect(
        find.byType(RadioListTile<ModerationMotivation>),
        findsNWidgets(5),
      );
      expect(find.text(_sv.motivationRemovedCopyright), findsOneWidget);
      expect(find.text(_sv.motivationKeptNoBreach), findsNothing);
      final group = tester.widget<RadioGroup<ModerationMotivation>>(
        find.byType(RadioGroup<ModerationMotivation>),
      );
      expect(group.groupValue, ModerationMotivation.removedOther);
      expect(
        find.text(
          _sv.moderatorClosePreviewReporter(_sv.decisionHeadlineContentRemoved),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text(_sv.motivationRemovedSpam));
      await tester.pump();
      await tester.tap(
        find.widgetWithText(ElevatedButton, _sv.moderatorCloseSheetTitle),
      );
      await tester.pumpAndSettle();

      expect(result, ModerationMotivation.removedSpam);
    });

    testWidgets('no action offers the three "kept" reasons and says the owner '
        'gets no notice', (tester) async {
      await openSheet(tester, ModeratorDecision.noAction);

      expect(
        find.byType(RadioListTile<ModerationMotivation>),
        findsNWidgets(3),
      );
      expect(find.text(_sv.motivationKeptUnclear), findsOneWidget);
      expect(find.text(_sv.moderatorClosePreviewOwnerNone), findsOneWidget);
    });

    testWidgets('hidden profile offers its two reasons', (tester) async {
      await openSheet(tester, ModeratorDecision.profileHidden);

      expect(
        find.byType(RadioListTile<ModerationMotivation>),
        findsNWidgets(2),
      );
    });

    testWidgets('cancel returns nothing', (tester) async {
      ModerationMotivation? result = ModerationMotivation.removedSpam;
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showModeratorCloseSheet(
                context,
                decision: ModeratorDecision.noAction,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_sv.commonCancel));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });
  });

  group('closing a report', () {
    testWidgets('after a takedown the sheet offers removal reasons and the '
        'close carries the chosen key', (tester) async {
      final report = _report(action: ModeratorDecision.contentRemoved);
      await pumpView(tester, report);

      await tester.tap(find.byTooltip(_sv.moderatorCloseTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_sv.motivationRemovedCopyright));
      await tester.pump();
      await tester.tap(
        find.widgetWithText(ElevatedButton, _sv.moderatorCloseSheetTitle),
      );
      await tester.pumpAndSettle();

      verify(
        () => reports.closeReport(
          report,
          motivation: ModerationMotivation.removedCopyright,
        ),
      ).called(1);
    });

    testWidgets('without a takedown the choices are the "kept" reasons and the '
        'default is sent when nothing is changed', (tester) async {
      final report = _report();
      await pumpView(tester, report);

      await tester.tap(find.byTooltip(_sv.moderatorCloseTooltip));
      await tester.pumpAndSettle();
      expect(find.text(_sv.motivationKeptNoBreach), findsOneWidget);
      expect(find.text(_sv.motivationRemovedSpam), findsNothing);
      await tester.tap(
        find.widgetWithText(ElevatedButton, _sv.moderatorCloseSheetTitle),
      );
      await tester.pumpAndSettle();

      verify(
        () => reports.closeReport(
          report,
          motivation: ModerationMotivation.keptNoBreach,
        ),
      ).called(1);
    });

    testWidgets('a misattribution report closes at once, with no sheet and '
        'no motivation', (tester) async {
      final report = _report(reason: 'misattribution');
      await pumpView(tester, report);

      await tester.tap(find.byTooltip(_sv.moderatorCloseTooltip));
      await tester.pumpAndSettle();

      expect(find.text(_sv.moderatorCloseChoose), findsNothing);
      verify(() => reports.closeReport(report, motivation: null)).called(1);
    });

    testWidgets('dismissing the sheet closes nothing', (tester) async {
      await pumpView(tester, _report());

      await tester.tap(find.byTooltip(_sv.moderatorCloseTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_sv.commonCancel));
      await tester.pumpAndSettle();

      verifyNever(
        () => reports.closeReport(any(), motivation: any(named: 'motivation')),
      );
    });
  });

  group('Överklaganden tab', () {
    Future<void> openTab(WidgetTester tester) async {
      await tester.tap(find.textContaining('Överklaganden ('));
      await tester.pumpAndSettle();
    }

    testWidgets('the tab counts the open appeals and the card shows the '
        'person\'s text', (tester) async {
      when(
        () => appeals.listOpenAppeals(),
      ).thenAnswer((_) async => [_appeal()]);
      await pumpView(tester);
      await tester.pumpAndSettle();

      expect(find.text(_sv.moderatorTabAppeals(1)), findsOneWidget);
      expect(find.text(_sv.moderatorTabReports(0)), findsOneWidget);

      await openTab(tester);

      expect(find.text(_sv.moderatorAppealFromOwner), findsOneWidget);
      expect(find.text('Receptet är mitt eget'), findsOneWidget);
      expect(find.text(_sv.moderatorAppealAnswerButton), findsOneWidget);
    });

    testWidgets('an empty queue says so', (tester) async {
      await pumpView(tester);
      await openTab(tester);

      expect(find.text(_sv.moderatorAppealsEmpty), findsOneWidget);
    });

    testWidgets('reversing a removal warns it cannot be taken back, and '
        'sends the answer', (tester) async {
      when(
        () => appeals.listOpenAppeals(),
      ).thenAnswer((_) async => [_appeal()]);
      when(
        () => appeals.answerAppeal(
          appealId: any(named: 'appealId'),
          outcome: any(named: 'outcome'),
        ),
      ).thenAnswer((_) async {});
      await pumpView(tester);
      await openTab(tester);

      await tester.tap(find.text(_sv.moderatorAppealAnswerButton));
      await tester.pumpAndSettle();
      expect(find.text(_sv.moderatorAnswerNoteTitle), findsNothing);

      await tester.tap(find.text(_sv.appealAnswerReversedHeadline));
      await tester.pump();
      expect(find.text(_sv.moderatorAnswerNoteTitle), findsOneWidget);
      expect(find.text(_sv.moderatorAnswerNoteBody), findsOneWidget);

      await tester.tap(find.text(_sv.moderatorAnswerSubmit));
      await tester.pumpAndSettle();

      verify(
        () => appeals.answerAppeal(
          appealId: 'r1_owner',
          outcome: AppealStatus.reversed,
        ),
      ).called(1);
      expect(find.text(_sv.moderatorAppealsEmpty), findsOneWidget);
    });

    testWidgets('no restore warning when the decision was no action', (
      tester,
    ) async {
      when(() => appeals.listOpenAppeals()).thenAnswer(
        (_) async => [_appeal(decision: ModeratorDecision.noAction)],
      );
      await pumpView(tester);
      await openTab(tester);

      await tester.tap(find.text(_sv.moderatorAppealAnswerButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_sv.appealAnswerReversedHeadline));
      await tester.pump();

      expect(find.text(_sv.moderatorAnswerNoteTitle), findsNothing);
    });

    testWidgets(
      'no restore warning on a reporter\'s appeal against a removal',
      (
        tester,
      ) async {
        when(
          () => appeals.listOpenAppeals(),
        ).thenAnswer((_) async => [_appeal(role: AppealRole.reporter)]);
        await pumpView(tester);
        await openTab(tester);

        await tester.tap(find.text(_sv.moderatorAppealAnswerButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text(_sv.appealAnswerReversedHeadline));
        await tester.pump();

        expect(find.text(_sv.moderatorAnswerNoteTitle), findsNothing);
      },
    );

    testWidgets('an appeal answered elsewhere leaves the queue without retry', (
      tester,
    ) async {
      when(
        () => appeals.listOpenAppeals(),
      ).thenAnswer((_) async => [_appeal()]);
      when(
        () => appeals.answerAppeal(
          appealId: any(named: 'appealId'),
          outcome: any(named: 'outcome'),
        ),
      ).thenThrow(const AnswerAppealException(AnswerFailure.alreadyAnswered));
      await pumpView(tester);
      await openTab(tester);

      await tester.tap(find.text(_sv.moderatorAppealAnswerButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_sv.moderatorAnswerSubmit));
      await tester.pumpAndSettle();

      expect(find.text(_sv.moderatorAppealAlreadyAnswered), findsOneWidget);
      expect(find.textContaining(_sv.moderatorAnswerFailed), findsNothing);
      expect(find.text(_sv.moderatorAppealsEmpty), findsOneWidget);
    });

    testWidgets('a refused answer keeps the appeal and says so', (
      tester,
    ) async {
      when(
        () => appeals.listOpenAppeals(),
      ).thenAnswer((_) async => [_appeal()]);
      when(
        () => appeals.answerAppeal(
          appealId: any(named: 'appealId'),
          outcome: any(named: 'outcome'),
        ),
      ).thenThrow(Exception('denied'));
      await pumpView(tester);
      await openTab(tester);

      await tester.tap(find.text(_sv.moderatorAppealAnswerButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_sv.moderatorAnswerSubmit));
      await tester.pumpAndSettle();

      expect(find.textContaining(_sv.moderatorAnswerFailed), findsOneWidget);
      expect(find.text('Receptet är mitt eget'), findsOneWidget);
    });
  });
}
