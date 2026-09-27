// A failed backup or restore says what failed and what was kept, never the
// exception's text (content-style-guide.md:87-97: what happened, what was
// kept, an action; never an error code in user text). And the settings page
// is a plain page: backup and restore from there must not pop it (BUT-2150).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/providers/locale_provider.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/backup_service.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/settings/settings_hub_view.dart';
import 'package:butlery/widgets/common/profile/handlers/backup_restore_handler.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

class _MockBackupService extends Mock implements BackupService {}

class _MockReportService extends Mock implements ReportService {}

const _rawCause = 'PlatformException(storage_full, disk 0x1f)';

Widget _app(GlobalKey<NavigatorState> navigatorKey) => MaterialApp(
  navigatorKey: navigatorKey,
  locale: const Locale('sv'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: AppTheme.lightTheme,
  home: const Scaffold(body: Text('home')),
);

void main() {
  final sv = AppLocalizationsSv();
  late _MockBackupService backup;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GetIt.instance.reset();
    ServiceLocator.reset();
    backup = _MockBackupService();
    final reportService = _MockReportService();
    when(
      () => reportService.watchIsAdmin(),
    ).thenAnswer((_) => Stream<bool>.value(false));
    final container = DIContainer();
    container.container.registerSingleton<BackupService>(backup);
    container.container.registerSingleton<ReportService>(reportService);
    container.container.registerSingleton<LocaleProvider>(LocaleProvider());
    container.container.registerSingleton<UserService>(MockUserService());
    ServiceLocator.initialize(container);
  });

  tearDown(() async {
    ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  group('SettingsHubView backup and restore (BUT-2150)', () {
    Future<GlobalKey<NavigatorState>> pumpHubOverHome(
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(navigatorKey));
      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const SettingsHubView()),
      );
      await tester.pumpAndSettle();
      return navigatorKey;
    }

    testWidgets('a failed backup keeps the settings page open and names '
        'what failed and what was kept, not the exception', (tester) async {
      when(() => backup.exportToFile()).thenThrow(Exception(_rawCause));
      await pumpHubOverHome(tester);

      await tester.tap(find.text(sv.profileDownloadBackup));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsHubView), findsOneWidget);
      expect(
        find.text('${sv.profileBackupNotSaved} ${sv.profileBackupRecipesKept}'),
        findsOneWidget,
      );
      expect(find.textContaining(_rawCause), findsNothing);
      expect(find.text(sv.commonClose), findsOneWidget);
    });

    testWidgets('a failed restore keeps the settings page open and says no '
        'recipe was removed, not the exception', (tester) async {
      when(() => backup.importFromFile()).thenThrow(Exception(_rawCause));
      await pumpHubOverHome(tester);

      await tester.tap(find.text(sv.profileRestoreFromBackup));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsHubView), findsOneWidget);
      expect(
        find.text(
          '${sv.profileRestoreNotRead} ${sv.profileRestoreNothingRemoved}',
        ),
        findsOneWidget,
      );
      expect(find.textContaining(_rawCause), findsNothing);
    });
  });

  group('BackupRestoreHandler when the service caught the exception', () {
    // BackupService catches its own exceptions and returns an "unexpected"
    // result. Even if such a result carried the cause, the handler shows only
    // the three-part failure.
    testWidgets('an unexpected export result shows the failure, not the '
        'cause', (tester) async {
      when(() => backup.exportToFile()).thenAnswer(
        (_) async => const BackupResult(
          success: false,
          message: _rawCause,
          unexpected: true,
        ),
      );
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(navigatorKey));

      BackupRestoreHandler.handleBackup(
        navigatorKey.currentContext!,
        closeModal: false,
      );
      await tester.pumpAndSettle();

      expect(
        find.text('${sv.profileBackupNotSaved} ${sv.profileBackupRecipesKept}'),
        findsOneWidget,
      );
      expect(find.textContaining(_rawCause), findsNothing);
    });

    testWidgets('an unexpected import result shows the failure, not the '
        'cause', (tester) async {
      when(() => backup.importFromFile()).thenAnswer(
        (_) async => const ImportResult(
          success: false,
          errorMessage: _rawCause,
          unexpected: true,
        ),
      );
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(navigatorKey));

      BackupRestoreHandler.handleRestore(
        navigatorKey.currentContext!,
        closeModal: false,
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          '${sv.profileRestoreNotRead} ${sv.profileRestoreNothingRemoved}',
        ),
        findsOneWidget,
      );
      expect(find.textContaining(_rawCause), findsNothing);
    });
  });

  group('BackupRestoreHandler from a modal', () {
    testWidgets('closes the sheet, keeps the page, and shows the failure '
        'after the sheet is gone', (tester) async {
      when(() => backup.exportToFile()).thenThrow(Exception(_rawCause));
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(navigatorKey));

      showModalBottomSheet<void>(
        context: navigatorKey.currentContext!,
        builder: (sheetContext) => TextButton(
          onPressed: () => BackupRestoreHandler.handleBackup(sheetContext),
          child: const Text('backup'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('backup'));
      await tester.pumpAndSettle();
      // The snackbar waits for the sheet's closing animation.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('backup'), findsNothing);
      expect(find.text('home'), findsOneWidget);
      expect(
        find.text('${sv.profileBackupNotSaved} ${sv.profileBackupRecipesKept}'),
        findsOneWidget,
      );
      expect(find.textContaining(_rawCause), findsNothing);
    });
  });
}
