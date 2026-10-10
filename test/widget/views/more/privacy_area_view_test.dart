// Integritet & data under Mer: consent, export and the policy open over this
// page without closing it (it is a plain page, not a modal), and the backup
// row offers download and restore in a sheet that does nothing when it is
// dismissed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/backup_service.dart';
import 'package:butlery/views/more/privacy_area_view.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockBackupService extends Mock implements BackupService {}

void main() {
  final sv = AppLocalizationsSv();
  late _MockBackupService backup;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GetIt.instance.reset();
    ServiceLocator.reset();
    backup = _MockBackupService();
    final container = DIContainer();
    container.container.registerSingleton<BackupService>(backup);
    ServiceLocator.initialize(container);
  });

  tearDown(() async {
    ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  Future<List<String?>> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pushed = <String?>[];
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: const PrivacyAreaView(),
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

  testWidgets('the privacy policy row opens the policy over this page', (
    tester,
  ) async {
    final pushed = await pump(tester);

    await tester.tap(find.text(sv.profilePrivacyPolicy));
    await tester.pumpAndSettle();

    expect(pushed, [Routes.privacyPolicy]);
  });

  // The services behind consent and export are not registered here, so
  // opening fails and says so; what matters is the page is still underneath.
  testWidgets('the consent row keeps this page open', (tester) async {
    await pump(tester);

    await tester.tap(find.text(sv.settingsConsents));
    await tester.pumpAndSettle();

    expect(find.text(sv.profileConsentManagementOpenFailed), findsOneWidget);
    expect(find.byType(PrivacyAreaView), findsOneWidget);
  });

  testWidgets('the export row keeps this page open', (tester) async {
    await pump(tester);

    await tester.tap(find.text(sv.profileExportData));
    await tester.pumpAndSettle();

    expect(find.text(sv.profileDataExportOpenFailed), findsOneWidget);
    expect(find.byType(PrivacyAreaView), findsOneWidget);
  });

  testWidgets('the backup row opens a sheet with download and restore, and '
      'dismissing it starts neither', (tester) async {
    await pump(tester);
    expect(find.text(sv.profileDownloadBackup), findsNothing);

    await tester.tap(find.text(sv.settingsBackupTitle));
    await tester.pumpAndSettle();
    expect(find.text(sv.profileDownloadBackup), findsOneWidget);
    expect(find.text(sv.profileRestoreFromBackup), findsOneWidget);

    await tester.tapAt(const Offset(400, 20));
    await tester.pumpAndSettle();

    expect(find.text(sv.profileDownloadBackup), findsNothing);
    verifyNever(() => backup.exportToFile());
    verifyNever(() => backup.importFromFile());
  });

  testWidgets('choosing download runs the backup once the sheet is gone', (
    tester,
  ) async {
    when(() => backup.exportToFile()).thenAnswer(
      (_) async => const BackupResult(success: true, message: 'ok'),
    );
    await pump(tester);

    await tester.tap(find.text(sv.settingsBackupTitle));
    await tester.pumpAndSettle();
    await tester.tap(find.text(sv.profileDownloadBackup));
    await tester.pumpAndSettle();

    verify(() => backup.exportToFile()).called(1);
    verifyNever(() => backup.importFromFile());
    expect(find.byType(PrivacyAreaView), findsOneWidget);
  });

  testWidgets('choosing restore runs the restore once the sheet is gone', (
    tester,
  ) async {
    when(
      () => backup.importFromFile(),
    ).thenAnswer((_) async => ImportResult.cancelled());
    await pump(tester);

    await tester.tap(find.text(sv.settingsBackupTitle));
    await tester.pumpAndSettle();
    await tester.tap(find.text(sv.profileRestoreFromBackup));
    await tester.pumpAndSettle();

    verify(() => backup.importFromFile()).called(1);
    verifyNever(() => backup.exportToFile());
  });
}
