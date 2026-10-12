// BUT-2222: each report tile says in plain words what happened, the badge
// carries a word and a glyph, and only closed reports offer an appeal.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/models/social/decision_detail_args.dart';
import 'package:butlery/models/social/moderation_outcome.dart';
import 'package:butlery/services/moderation/report_outcomes_service.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/viewmodels/settings/my_reports_viewmodel.dart';
import 'package:butlery/views/settings/my_reports_view.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockReportService extends Mock implements ReportService {}

class _MockOutcomes extends Mock implements ReportOutcomesService {}

ContentReport _report(
  String id,
  ReportStatus status, {
  ModeratorDecision? action,
}) => ContentReport(
  id: id,
  reporterId: 'u1',
  contentType: ContentType.comment,
  contentId: 'c$id',
  reason: 'spam',
  status: status,
  createdAt: DateTime.utc(2026, 10, 1),
  moderatorAction: action,
);

ModerationOutcome _outcome(
  String id,
  ModeratorDecision decision, {
  ModerationAppeal? appeal,
}) => ModerationOutcome(reportId: id, decision: decision, appeal: appeal);

void main() {
  final sv = AppLocalizationsSv();
  late _MockReportService service;
  late _MockOutcomes outcomesService;

  Future<void> pump(
    WidgetTester tester,
    List<ContentReport> reports, {
    Map<String, ModerationOutcome> outcomes = const {},
    Route<dynamic>? Function(RouteSettings)? onGenerateRoute,
  }) async {
    when(() => service.getMyReports()).thenAnswer((_) async => reports);
    when(
      () => outcomesService.getMyReportOutcomeDetails(),
    ).thenAnswer((_) async => outcomes);
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        onGenerateRoute: onGenerateRoute,
        child: const MyReportsView(),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GetIt.instance.reset();
    ServiceLocator.reset();
    service = _MockReportService();
    outcomesService = _MockOutcomes();
    final container = DIContainer();
    container.container.registerFactory<MyReportsViewModel>(
      () => MyReportsViewModel(
        reportService: service,
        reportOutcomesService: outcomesService,
      ),
    );
    ServiceLocator.initialize(container);
  });

  tearDown(() async {
    ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  testWidgets('Back names Hjälp & om', (tester) async {
    await pump(tester, const []);

    expect(
      tester.widget<ButleryTopBar>(find.byType(ButleryTopBar)).backTo,
      sv.settingsHelpTitle,
    );
  });

  testWidgets('every decided outcome renders its line', (tester) async {
    await pump(
      tester,
      [
        _report('1', ReportStatus.newReport),
        _report('2', ReportStatus.inReview),
        _report(
          '3',
          ReportStatus.actioned,
          action: ModeratorDecision.contentRemoved,
        ),
        _report(
          '4',
          ReportStatus.inReview,
          action: ModeratorDecision.profileHidden,
        ),
        _report('5', ReportStatus.closed),
        _report('6', ReportStatus.closed),
        _report('7', ReportStatus.closed),
      ],
      outcomes: {
        '5': _outcome('5', ModeratorDecision.noAction),
        '6': _outcome('6', ModeratorDecision.contentRemoved),
      },
    );

    // A matter still open says it with its pill, not with an outcome.
    expect(find.textContaining(sv.myReportsOutcomeReceived), findsNothing);
    expect(find.textContaining(sv.myReportsOutcomeInReview), findsNothing);
    expect(
      find.textContaining(sv.myReportsOutcomeContentRemoved),
      findsNWidgets(2),
    );
    expect(
      find.textContaining(sv.myReportsOutcomeProfileHidden),
      findsOneWidget,
    );
    expect(find.textContaining(sv.myReportsOutcomeNoAction), findsOneWidget);
    expect(find.textContaining(sv.myReportsOutcomeClosed), findsOneWidget);
  });

  testWidgets('badge word and glyph per status', (tester) async {
    await pump(tester, [
      _report('1', ReportStatus.newReport),
      _report('2', ReportStatus.inReview),
      _report('3', ReportStatus.actioned),
      _report('4', ReportStatus.closed),
    ]);

    expect(find.text('INKOMMEN'), findsOneWidget);
    expect(find.text('GRANSKAS'), findsOneWidget);
    expect(find.text(sv.myReportsStatusActioned.toUpperCase()), findsOneWidget);
    expect(find.text('AVSLUTAD'), findsOneWidget);
    expect(find.byIcon(ButleryIcons.inbox), findsOneWidget);
    expect(find.byIcon(ButleryIcons.search), findsOneWidget);
    expect(find.byIcon(ButleryIcons.circleCheck), findsNWidgets(2));
  });

  testWidgets('the mail appeal button is gone from the rows', (tester) async {
    await pump(tester, [_report('4', ReportStatus.closed)]);

    expect(find.text(sv.myReportsAppealButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('a row opens its decision with what the '
      'list already holds', (tester) async {
    final pushed = <RouteSettings>[];
    final closed = _report('4', ReportStatus.closed);
    await pump(
      tester,
      [closed, _report('5', ReportStatus.newReport)],
      outcomes: {'4': _outcome('4', ModeratorDecision.contentRemoved)},
      onGenerateRoute: (settings) {
        pushed.add(settings);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const Scaffold(body: Text('detail')),
        );
      },
    );

    await tester.tap(
      find
          .descendant(
            of: find.byKey(const ValueKey('report-4')),
            matching: find.byType(InkWell),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(pushed.last.name, Routes.decisionDetail);
    final args = pushed.last.arguments! as DecisionDetailArgs;
    expect(args.role, AppealRole.reporter);
    expect(args.reportId, '4');
    expect(args.outcome!.decision, ModeratorDecision.contentRemoved);
    expect(args.report, same(closed));
  });

  testWidgets('a report with an open appeal wears the Överklagad badge', (
    tester,
  ) async {
    await pump(
      tester,
      [_report('4', ReportStatus.closed)],
      outcomes: {
        '4': _outcome(
          '4',
          ModeratorDecision.noAction,
          appeal: const ModerationAppeal(
            status: AppealStatus.open,
            text: 'x',
          ),
        ),
      },
    );

    expect(find.text(sv.decisionStatusAppealed.toUpperCase()), findsOneWidget);
    expect(find.text(sv.myReportsStatusClosed.toUpperCase()), findsNothing);
  });

  testWidgets('"Jag vill överklaga" shows only where an appeal can still be '
      'made, and opens the form for the reporter', (tester) async {
    final pushed = <RouteSettings>[];
    final outcome = _outcome('4', ModeratorDecision.noAction);
    await pump(
      tester,
      [_report('4', ReportStatus.closed), _report('5', ReportStatus.closed)],
      outcomes: {
        '4': outcome,
        '5': _outcome(
          '5',
          ModeratorDecision.noAction,
          appeal: const ModerationAppeal(
            status: AppealStatus.open,
            text: 'x',
          ),
        ),
      },
      onGenerateRoute: (settings) {
        pushed.add(settings);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const Scaffold(body: Text('form')),
        );
      },
    );

    expect(find.text(sv.decisionAppealLink), findsOneWidget);
    await tester.tap(find.text(sv.decisionAppealLink));
    await tester.pumpAndSettle();

    expect(pushed.last.name, Routes.appealForm);
    final args = pushed.last.arguments! as AppealFormArgs;
    expect(args.role, AppealRole.reporter);
    expect(args.outcome, same(outcome));
  });
}
