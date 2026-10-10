// BUT-2222: each report tile says in plain words what happened, the badge
// carries a word and a glyph, and only closed reports offer an appeal.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/contextual_time_formatter.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/services/moderation/report_outcomes_service.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/viewmodels/settings/my_reports_viewmodel.dart';
import 'package:butlery/views/settings/my_reports_view.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/social/report_outcome_labels.dart';
import 'package:butlery/widgets/social/report_reason_labels.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockReportService extends Mock implements ReportService {}

class _MockOutcomes extends Mock implements ReportOutcomesService {}

class _RecordingUrlLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  final launched = <String>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }
}

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

void main() {
  final sv = AppLocalizationsSv();
  late _MockReportService service;
  late _MockOutcomes outcomesService;

  Future<void> pump(
    WidgetTester tester,
    List<ContentReport> reports, {
    Map<String, ModeratorDecision> outcomes = const {},
  }) async {
    when(() => service.getMyReports()).thenAnswer((_) async => reports);
    when(
      () => outcomesService.getMyReportOutcomes(),
    ).thenAnswer((_) async => outcomes);
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
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

  testWidgets('all six outcome lines render', (tester) async {
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
        '5': ModeratorDecision.noAction,
        '6': ModeratorDecision.contentRemoved,
      },
    );

    expect(find.text(sv.myReportsOutcomeReceived), findsOneWidget);
    expect(find.text(sv.myReportsOutcomeInReview), findsOneWidget);
    expect(find.text(sv.myReportsOutcomeContentRemoved), findsNWidgets(2));
    expect(find.text(sv.myReportsOutcomeProfileHidden), findsOneWidget);
    expect(find.text(sv.myReportsOutcomeNoAction), findsOneWidget);
    expect(find.text(sv.myReportsOutcomeClosed), findsOneWidget);
  });

  testWidgets('badge word and glyph per status', (tester) async {
    await pump(tester, [
      _report('1', ReportStatus.newReport),
      _report('2', ReportStatus.inReview),
      _report('3', ReportStatus.actioned),
      _report('4', ReportStatus.closed),
    ]);

    expect(find.text('Inkommen'), findsOneWidget);
    expect(find.text('Granskas'), findsNWidgets(2));
    expect(find.text('Avslutad'), findsOneWidget);
    expect(find.byIcon(ButleryIcons.inbox), findsOneWidget);
    expect(find.byIcon(ButleryIcons.search), findsNWidgets(2));
    expect(find.byIcon(ButleryIcons.circleCheck), findsOneWidget);
  });

  testWidgets('appeal button only on closed reports', (tester) async {
    await pump(tester, [
      _report('1', ReportStatus.newReport),
      _report('2', ReportStatus.inReview),
      _report('3', ReportStatus.actioned),
      _report('4', ReportStatus.closed),
    ]);

    expect(find.text(sv.myReportsAppealButton), findsOneWidget);
  });

  testWidgets('appeal mail carries id, date, reason and outcome and nothing '
      'else of the report', (tester) async {
    final launcher = _RecordingUrlLauncher();
    final original = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = launcher;
    addTearDown(() => UrlLauncherPlatform.instance = original);

    final report = ContentReport(
      id: 'rep-777',
      reporterId: 'LEAK-reporter-uid',
      contentType: ContentType.comment,
      contentId: 'LEAK-content-id',
      contentOwnerId: 'LEAK-owner-uid',
      reason: 'spam',
      description: 'LEAK-free-text about Kalle Anka',
      status: ReportStatus.closed,
      createdAt: DateTime.utc(2026, 10, 1),
    );
    await pump(tester, [report]);

    await tester.tap(find.text(sv.myReportsAppealButton));
    await tester.pump();

    expect(launcher.launched, hasLength(1));
    final uri = Uri.parse(launcher.launched.single);
    expect(uri.scheme, 'mailto');
    expect(uri.path, 'overklagande@butlery.se');
    expect(uri.queryParameters['subject'], sv.myReportsAppealSubject);

    final body = uri.queryParameters['body']!;
    expect(body, contains('rep-777'));
    expect(
      body,
      contains(
        ContextualTimeFormatter.dateTime(
          report.createdAt.toLocal(),
          localeName: 'sv',
        ),
      ),
    );
    expect(body, contains(reportReasonDisplay(sv, 'spam')));
    expect(
      body,
      contains(reportOutcomeText(sv, ReportStatus.closed, null)),
    );
    expect(body, isNot(contains('LEAK')));
    expect(body, isNot(contains('Kalle Anka')));
  });

  testWidgets('appeal mail names the moderator outcome of a closed report', (
    tester,
  ) async {
    final launcher = _RecordingUrlLauncher();
    final original = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = launcher;
    addTearDown(() => UrlLauncherPlatform.instance = original);

    await pump(
      tester,
      [_report('rep-888', ReportStatus.closed)],
      outcomes: {'rep-888': ModeratorDecision.contentRemoved},
    );

    await tester.tap(find.text(sv.myReportsAppealButton));
    await tester.pump();

    final body = Uri.parse(
      launcher.launched.single,
    ).queryParameters['body']!;
    expect(body, contains(sv.myReportsOutcomeContentRemoved));
  });
}
