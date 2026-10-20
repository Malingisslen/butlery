// BUT-2353: the decision detail (reporter and owner), the owner list and the
// appeal form.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/models/social/decision_detail_args.dart';
import 'package:butlery/models/social/moderation_outcome.dart';
import 'package:butlery/services/moderation/moderation_appeals_service.dart';
import 'package:butlery/services/moderation/report_outcomes_service.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/viewmodels/settings/my_content_decisions_viewmodel.dart';
import 'package:butlery/views/settings/appeal_form_view.dart';
import 'package:butlery/views/settings/decision_detail_view.dart';
import 'package:butlery/views/settings/my_content_decisions_view.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockReports extends Mock implements ReportService {}

class _MockOutcomes extends Mock implements ReportOutcomesService {}

class _MockAppeals extends Mock implements ModerationAppealsService {}

final _sv = AppLocalizationsSv();

ModerationOutcome _outcome({
  ModeratorDecision decision = ModeratorDecision.contentRemoved,
  String? motivation = 'removed_copyright',
  DateTime? deadline,
  ModerationAppeal? appeal,
  ContentType? type,
  String? reason,
  bool revised = false,
  bool appealable = true,
}) => ModerationOutcome(
  reportId: 'r1',
  decision: decision,
  motivationKey: motivation,
  decidedAt: DateTime.utc(2026, 10, 10, 12),
  appealDeadline: deadline ?? DateTime.now().add(const Duration(days: 100)),
  appeal: appeal,
  contentType: type,
  reason: reason,
  revised: revised,
  appealable: appealable,
);

ContentReport _report() => ContentReport(
  id: 'r1',
  reporterId: 'me',
  contentType: ContentType.recipe,
  contentId: 'c1',
  reason: 'copyright',
  status: ReportStatus.closed,
  createdAt: DateTime.utc(2026, 10, 8, 12),
);

void main() {
  late _MockReports reports;
  late _MockOutcomes outcomes;
  late _MockAppeals appeals;

  setUpAll(() => registerFallbackValue(AppealRole.owner));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GetIt.instance.reset();
    ServiceLocator.reset();
    reports = _MockReports();
    outcomes = _MockOutcomes();
    appeals = _MockAppeals();
    final container = DIContainer();
    container.container
      ..registerSingleton<ReportService>(reports)
      ..registerSingleton<ReportOutcomesService>(outcomes)
      ..registerSingleton<ModerationAppealsService>(appeals)
      ..registerFactory<MyContentDecisionsViewModel>(
        () => MyContentDecisionsViewModel(reportOutcomesService: outcomes),
      );
    ServiceLocator.initialize(container);
  });

  tearDown(() async {
    ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  Future<List<RouteSettings>> pumpApp(
    WidgetTester tester,
    Widget child,
  ) async {
    final pushed = <RouteSettings>[];
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        onGenerateRoute: (settings) {
          pushed.add(settings);
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('pushed')),
          );
        },
        child: child,
      ),
    );
    await tester.pumpAndSettle();
    return pushed;
  }

  DecisionDetailView detail(
    AppealRole role,
    ModerationOutcome outcome, {
    ContentReport? report,
  }) => DecisionDetailView(
    args: DecisionDetailArgs(
      role: role,
      reportId: 'r1',
      outcome: outcome,
      report: report ?? (role == AppealRole.reporter ? _report() : null),
    ),
  );

  group('DecisionDetailView', () {
    testWidgets('reporter: what was reported, the decision with its '
        'motivation, and the appeal offer', (tester) async {
      await pumpApp(
        tester,
        detail(
          AppealRole.reporter,
          _outcome(deadline: DateTime.utc(2099, 4, 10)),
        ),
      );

      expect(find.text(_sv.decisionDetailReporterTitle), findsOneWidget);
      expect(find.text(_sv.decisionYouReportedLabel), findsOneWidget);
      expect(find.text('Ett recept för upphovsrättsintrång'), findsOneWidget);
      expect(
        find.textContaining(_sv.decisionHeadlineContentRemoved),
        findsOneWidget,
      );
      expect(
        find.textContaining(_sv.motivationRemovedCopyright),
        findsOneWidget,
      );
      expect(find.text(_sv.appealPromptTitle), findsOneWidget);
      expect(find.textContaining('10 apr. 2099'), findsOneWidget);
      expect(find.text(_sv.decisionAppealLink), findsOneWidget);
    });

    testWidgets('the appeal button opens the form with role and outcome', (
      tester,
    ) async {
      final outcome = _outcome();
      final pushed = await pumpApp(
        tester,
        detail(AppealRole.reporter, outcome),
      );

      await tester.tap(find.text(_sv.decisionAppealLink));
      await tester.pumpAndSettle();

      expect(pushed.last.name, Routes.appealForm);
      final args = pushed.last.arguments! as AppealFormArgs;
      expect(args.role, AppealRole.reporter);
      expect(args.outcome, same(outcome));
    });

    testWidgets('past the deadline the button is replaced by a note', (
      tester,
    ) async {
      await pumpApp(
        tester,
        detail(
          AppealRole.reporter,
          _outcome(deadline: DateTime.utc(2020, 1, 1)),
        ),
      );

      expect(find.text(_sv.decisionAppealLink), findsNothing);
      expect(find.text(_sv.appealWindowClosedInfo), findsOneWidget);
    });

    testWidgets('a row the server will not admit offers no appeal and does '
        'not claim the window closed', (tester) async {
      await pumpApp(
        tester,
        detail(AppealRole.reporter, _outcome(appealable: false)),
      );

      expect(find.text(_sv.decisionAppealLink), findsNothing);
      expect(find.text(_sv.appealWindowClosedInfo), findsNothing);
    });

    testWidgets('an open appeal shows the own text and "granskas igen"', (
      tester,
    ) async {
      await pumpApp(
        tester,
        detail(
          AppealRole.reporter,
          _outcome(
            appeal: ModerationAppeal(
              status: AppealStatus.open,
              text: 'Det står fortfarande ordagrant',
              submittedAt: DateTime.utc(2026, 10, 11),
            ),
          ),
        ),
      );

      expect(find.text('Det står fortfarande ordagrant'), findsOneWidget);
      expect(find.text(_sv.appealUnderReview), findsOneWidget);
      expect(find.text(_sv.decisionAppealLink), findsNothing);
      expect(find.text(_sv.appealAnswerFinal), findsNothing);
    });

    testWidgets('an upheld appeal shows the answer and that it is final', (
      tester,
    ) async {
      await pumpApp(
        tester,
        detail(
          AppealRole.reporter,
          _outcome(
            appeal: ModerationAppeal(
              status: AppealStatus.upheld,
              text: 'Min text',
              submittedAt: DateTime.utc(2026, 10, 11),
              answeredAt: DateTime.utc(2026, 10, 12),
            ),
          ),
        ),
      );

      expect(find.text(_sv.appealAnswerUpheldHeadline), findsOneWidget);
      expect(find.text(_sv.appealAnswerUpheldBody), findsOneWidget);
      expect(find.text(_sv.appealAnswerFinal), findsOneWidget);
      expect(find.text(_sv.decisionAppealLink), findsNothing);
      expect(find.text(_sv.appealAnswerReversedOwnerRemoved), findsNothing);
    });

    testWidgets('owner: subject and reason, no content title, and the '
        'removed-content note when the decision is reversed', (tester) async {
      await pumpApp(
        tester,
        detail(
          AppealRole.owner,
          _outcome(
            type: ContentType.recipe,
            reason: 'copyright',
            appeal: ModerationAppeal(
              status: AppealStatus.reversed,
              text: 'Mitt eget',
              submittedAt: DateTime.utc(2026, 10, 11),
              answeredAt: DateTime.utc(2026, 10, 12),
            ),
          ),
        ),
      );

      expect(find.text(_sv.decisionDetailOwnerTitle), findsOneWidget);
      expect(find.text('Ditt recept'), findsOneWidget);
      expect(find.text('Anmält för upphovsrättsintrång'), findsOneWidget);
      expect(find.text(_sv.appealAnswerReversedHeadline), findsOneWidget);
      expect(find.text(_sv.appealAnswerReversedOwnerRemoved), findsOneWidget);
    });

    ModerationAppeal reversedAppeal() => ModerationAppeal(
      status: AppealStatus.reversed,
      text: 'Mitt eget',
      submittedAt: DateTime.utc(2026, 10, 11),
      answeredAt: DateTime.utc(2026, 10, 12),
    );

    testWidgets('a reporter with a reversed appeal is not told the content '
        'could not be restored', (tester) async {
      await pumpApp(
        tester,
        detail(AppealRole.reporter, _outcome(appeal: reversedAppeal())),
      );

      expect(find.text(_sv.appealAnswerReversedHeadline), findsOneWidget);
      expect(find.text(_sv.appealAnswerReversedOwnerRemoved), findsNothing);
    });

    testWidgets('an owner whose hidden profile was reversed is not told the '
        'content could not be restored', (tester) async {
      await pumpApp(
        tester,
        detail(
          AppealRole.owner,
          _outcome(
            decision: ModeratorDecision.profileHidden,
            type: ContentType.recipe,
            reason: 'copyright',
            appeal: reversedAppeal(),
          ),
        ),
      );

      expect(find.text(_sv.appealAnswerReversedHeadline), findsOneWidget);
      expect(find.text(_sv.appealAnswerReversedOwnerRemoved), findsNothing);
    });

    testWidgets('opened from a push with only the id, it loads the decision', (
      tester,
    ) async {
      when(() => outcomes.getMyContentDecisions()).thenAnswer(
        (_) async => [
          _outcome(type: ContentType.comment, reason: 'spam'),
        ],
      );
      await pumpApp(
        tester,
        const DecisionDetailView(
          args: DecisionDetailArgs(role: AppealRole.owner, reportId: 'r1'),
        ),
      );

      expect(find.text('Din kommentar'), findsOneWidget);
      expect(find.text(_sv.decisionAppealLink), findsOneWidget);
    });

    testWidgets('an id the caller has no decision for says so', (tester) async {
      when(() => outcomes.getMyContentDecisions()).thenAnswer((_) async => []);
      await pumpApp(
        tester,
        const DecisionDetailView(
          args: DecisionDetailArgs(role: AppealRole.owner, reportId: 'r1'),
        ),
      );

      expect(find.text(_sv.decisionDetailNotFound), findsOneWidget);
    });
  });

  group('MyContentDecisionsView', () {
    testWidgets('a row names the kind of content and why it was reported, '
        'and opens the owner detail', (tester) async {
      when(() => outcomes.getMyContentDecisions()).thenAnswer(
        (_) async => [_outcome(type: ContentType.recipe, reason: 'copyright')],
      );
      final pushed = await pumpApp(tester, const MyContentDecisionsView());

      expect(find.text(_sv.myContentDecisionsTitle), findsOneWidget);
      expect(find.text('Ditt recept'), findsOneWidget);
      expect(find.textContaining('Upphovsrättsintrång'), findsOneWidget);
      expect(
        find.textContaining(_sv.decisionHeadlineContentRemoved),
        findsOneWidget,
      );
      expect(
        find.text(_sv.decisionStatusDecided.toUpperCase()),
        findsOneWidget,
      );

      await tester.tap(find.text('Ditt recept'));
      await tester.pumpAndSettle();

      expect(pushed.last.name, Routes.decisionDetail);
      final args = pushed.last.arguments! as DecisionDetailArgs;
      expect(args.role, AppealRole.owner);
      expect(args.reportId, 'r1');
    });

    testWidgets('a revised no-action row says the warning is gone and carries '
        'the Omprövat pill', (tester) async {
      when(() => outcomes.getMyContentDecisions()).thenAnswer(
        (_) async => [
          _outcome(
            decision: ModeratorDecision.noAction,
            type: ContentType.profile,
            reason: 'harassment',
            revised: true,
          ),
        ],
      );
      await pumpApp(tester, const MyContentDecisionsView());

      expect(
        find.text(_sv.decisionStatusRevised.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.textContaining(_sv.decisionRevisedNoActionOutcome),
        findsOneWidget,
      );
      expect(find.text(_sv.decisionStatusDecided.toUpperCase()), findsNothing);
    });

    testWidgets('the appeal link opens the form for the owner', (tester) async {
      final outcome = _outcome(type: ContentType.recipe, reason: 'copyright');
      when(
        () => outcomes.getMyContentDecisions(),
      ).thenAnswer((_) async => [outcome]);
      final pushed = await pumpApp(tester, const MyContentDecisionsView());

      await tester.tap(find.text(_sv.decisionAppealLink));
      await tester.pumpAndSettle();

      expect(pushed.last.name, Routes.appealForm);
      final args = pushed.last.arguments! as AppealFormArgs;
      expect(args.role, AppealRole.owner);
      expect(args.outcome, same(outcome));
    });

    testWidgets('an open appeal shows the Överklagad badge', (tester) async {
      when(() => outcomes.getMyContentDecisions()).thenAnswer(
        (_) async => [
          _outcome(
            type: ContentType.profile,
            reason: 'spam',
            appeal: const ModerationAppeal(
              status: AppealStatus.open,
              text: 'x',
            ),
          ),
        ],
      );
      await pumpApp(tester, const MyContentDecisionsView());

      expect(
        find.text(_sv.decisionStatusAppealed.toUpperCase()),
        findsOneWidget,
      );
      // The deadline is far off, so only the existing appeal hides the link.
      expect(find.text(_sv.decisionAppealLink), findsNothing);
    });

    testWidgets('an open appeal follows the outcome as a new sentence', (
      tester,
    ) async {
      when(() => outcomes.getMyContentDecisions()).thenAnswer(
        (_) async => [
          _outcome(
            type: ContentType.recipe,
            reason: 'copyright',
            appeal: const ModerationAppeal(
              status: AppealStatus.open,
              text: 'x',
            ),
          ),
        ],
      );
      await pumpApp(tester, const MyContentDecisionsView());

      expect(
        find.textContaining(
          '${_sv.decisionHeadlineContentRemoved}. ${_sv.appealUnderReview}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Back names Hjälp & om', (tester) async {
      when(() => outcomes.getMyContentDecisions()).thenAnswer((_) async => []);
      await pumpApp(tester, const MyContentDecisionsView());

      expect(
        tester.widget<ButleryTopBar>(find.byType(ButleryTopBar)).backTo,
        _sv.settingsHelpTitle,
      );
    });

    testWidgets('empty state', (tester) async {
      when(() => outcomes.getMyContentDecisions()).thenAnswer((_) async => []);
      await pumpApp(tester, const MyContentDecisionsView());
      expect(find.text(_sv.myContentDecisionsEmpty), findsOneWidget);
    });

    testWidgets('failed state', (tester) async {
      when(() => outcomes.getMyContentDecisions()).thenThrow(Exception('x'));
      await pumpApp(tester, const MyContentDecisionsView());
      expect(find.text(_sv.myContentDecisionsLoadFailed), findsOneWidget);
    });
  });

  group('AppealFormView', () {
    AppealFormView form(AppealRole role) => AppealFormView(
      args: AppealFormArgs(role: role, outcome: _outcome()),
    );

    void stubSubmit({Object? error}) {
      final call = when(
        () => appeals.submitAppeal(
          reportId: any(named: 'reportId'),
          role: any(named: 'role'),
          text: any(named: 'text'),
        ),
      );
      if (error != null) {
        call.thenThrow(error);
      } else {
        call.thenAnswer((_) async {});
      }
    }

    ElevatedButton sendButton(WidgetTester tester) =>
        tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, _sv.appealSubmit),
        );

    testWidgets('counter counts, and send is enabled from ten characters', (
      tester,
    ) async {
      await pumpApp(tester, form(AppealRole.reporter));

      expect(find.text(_sv.appealFormIntro), findsOneWidget);
      expect(find.text(_sv.appealFormOnceReporter), findsOneWidget);
      expect(find.text('0 / 1000'), findsOneWidget);
      expect(sendButton(tester).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'nio tecken');
      await tester.pump();
      expect(find.text('10 / 1000'), findsOneWidget);
      expect(sendButton(tester).onPressed, isNotNull);

      await tester.enterText(find.byType(TextField), 'nio tecke');
      await tester.pump();
      expect(sendButton(tester).onPressed, isNull);
    });

    Future<void> openFormPushed(WidgetTester tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => form(AppealRole.owner),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('Back asks before throwing a typed appeal away', (
      tester,
    ) async {
      await openFormPushed(tester);
      await tester.enterText(find.byType(TextField), 'Receptet är mitt eget');
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text(_sv.unsavedChangesTitle), findsOneWidget);
      expect(find.byType(AppealFormView), findsOneWidget);
      verifyNever(
        () => appeals.submitAppeal(
          reportId: any(named: 'reportId'),
          role: any(named: 'role'),
          text: any(named: 'text'),
        ),
      );
    });

    testWidgets('Back from an empty appeal leaves without asking', (
      tester,
    ) async {
      await openFormPushed(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text(_sv.unsavedChangesTitle), findsNothing);
      expect(find.byType(AppealFormView), findsNothing);
    });

    testWidgets('the owner is told the reporter does not see the text', (
      tester,
    ) async {
      await pumpApp(tester, form(AppealRole.owner));
      expect(find.text(_sv.appealFormOnceOwner), findsOneWidget);
    });

    testWidgets('sending calls submitAppeal, says so and closes with true', (
      tester,
    ) async {
      stubSubmit();
      Object? result;
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => form(AppealRole.owner),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Receptet är mitt eget');
      await tester.pump();
      await tester.tap(find.text(_sv.appealSubmit));
      await tester.pumpAndSettle();

      verify(
        () => appeals.submitAppeal(
          reportId: 'r1',
          role: AppealRole.owner,
          text: 'Receptet är mitt eget',
        ),
      ).called(1);
      expect(result, true);
      expect(find.text(_sv.appealSent), findsOneWidget);
    });

    const failures = {
      AppealFailure.windowClosed: 'Tiden för att överklaga har gått ut.',
      AppealFailure.alreadyAppealed:
          'Du har redan överklagat det här beslutet.',
      AppealFailure.notAllowed: 'Du kan inte överklaga det här beslutet.',
      AppealFailure.notFound: 'Vi hittar inget beslut att överklaga.',
      AppealFailure.invalidText: 'Skriv minst 10 och högst 1000 tecken.',
      AppealFailure.other: 'Överklagan kunde inte skickas. Försök igen.',
    };
    for (final entry in failures.entries) {
      testWidgets('${entry.key} is explained in Swedish and the form stays', (
        tester,
      ) async {
        stubSubmit(error: AppealException(entry.key));
        await pumpApp(tester, form(AppealRole.reporter));

        await tester.enterText(
          find.byType(TextField),
          'tillräckligt lång text',
        );
        await tester.pump();
        await tester.tap(find.text(_sv.appealSubmit));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.textContaining(entry.value), findsOneWidget);
        expect(find.byType(AppealFormView), findsOneWidget);
        expect(find.text(_sv.appealSent), findsNothing);
      });
    }
  });
}
