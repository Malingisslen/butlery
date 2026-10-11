// Hjälp & om under Mer: help, rules and reports in one place, the moderator
// entry only for admins, the appeal mail, and the version.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/version_info.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/views/more/help_area_view.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockReportService extends Mock implements ReportService {}

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

void main() {
  final sv = AppLocalizationsSv();
  late _MockReportService reports;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GetIt.instance.reset();
    ServiceLocator.reset();
    reports = _MockReportService();
    final container = DIContainer();
    container.container.registerSingleton<ReportService>(reports);
    ServiceLocator.initialize(container);
  });

  tearDown(() async {
    ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  Future<List<String?>> pump(
    WidgetTester tester, {
    bool isAdmin = false,
  }) async {
    when(
      () => reports.watchIsAdmin(),
    ).thenAnswer((_) => Stream<bool>.value(isAdmin));
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pushed = <String?>[];
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: const HelpAreaView(),
        onGenerateRoute: (settings) {
          pushed.add(settings.name);
          return MaterialPageRoute<void>(
            builder: (_) => const SizedBox.shrink(),
            settings: settings,
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    return pushed;
  }

  // VersionInfo is static and starts as 'unknown'; this test has to run
  // before the one that initialises it.
  testWidgets('no version row while the version is unknown', (tester) async {
    await pump(tester);

    expect(find.text(sv.settingsVersionLabel), findsNothing);
    expect(find.text(sv.settingsLicensesTitle), findsOneWidget);
  });

  testWidgets('shows the app version as a row that is not a button', (
    tester,
  ) async {
    PackageInfo.setMockInitialValues(
      appName: 'Butlery',
      packageName: 'se.butlery.app',
      version: '4.5.6',
      buildNumber: '7',
      buildSignature: '',
    );
    await VersionInfo.initialize();
    final handle = tester.ensureSemantics();
    await pump(tester);

    expect(find.text('4.5.6'), findsOneWidget);
    final data = tester
        .getSemantics(
          find.bySemanticsLabel(RegExp('^${sv.settingsVersionLabel}')),
        )
        .getSemanticsData();
    expect(data.flagsCollection.isButton, isFalse);
    expect(data.hasAction(SemanticsAction.tap), isFalse);
    handle.dispose();
  });

  final destinations = <String, String>{
    sv.profileFaq: Routes.faq,
    sv.legalTermsOfService: Routes.termsOfService,
    sv.legalCommunityGuidelines: Routes.communityGuidelines,
    sv.myReportsTitle: Routes.myReports,
    sv.settingsLicensesTitle: Routes.settingsLicenses,
  };
  for (final entry in destinations.entries) {
    testWidgets('the "${entry.key}" row opens ${entry.value}', (tester) async {
      final pushed = await pump(tester);

      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();

      expect(pushed, [entry.value]);
    });
  }

  testWidgets('the moderator row is hidden for a non-admin', (tester) async {
    await pump(tester);

    expect(find.text(sv.legalTermsOfService), findsOneWidget);
    expect(find.text(sv.moderatorReviewTitle), findsNothing);
  });

  testWidgets('an admin sees the moderator row with its pill, and it opens '
      'the review queue', (tester) async {
    final pushed = await pump(tester, isAdmin: true);

    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text(sv.moderatorReviewTitle),
          matching: find.byType(InkWell),
        ),
        matching: find.text(sv.settingsAdminOnly.toUpperCase()),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text(sv.moderatorReviewTitle));
    await tester.pumpAndSettle();

    expect(pushed, [Routes.moderatorReview]);
  });

  testWidgets('the appeal row opens a mail with the general appeal template '
      '(BUT-2222)', (tester) async {
    final launcher = _RecordingUrlLauncher();
    final original = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = launcher;
    addTearDown(() => UrlLauncherPlatform.instance = original);
    await pump(tester);

    await tester.ensureVisible(find.text(sv.appealEmailLinkLabel));
    await tester.tap(find.text(sv.appealEmailLinkLabel));
    await tester.pump();

    expect(launcher.launched, hasLength(1));
    final uri = Uri.parse(launcher.launched.single);
    expect(uri.scheme, 'mailto');
    expect(uri.path, 'overklagande@butlery.se');
    expect(uri.queryParameters['subject'], sv.appealEmailSubject);
    expect(uri.queryParameters['body'], sv.appealEmailBodyTemplate);
  });
}
