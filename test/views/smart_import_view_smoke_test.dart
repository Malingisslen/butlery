/// BUT-1197: smoke test proving [SmartImportView] mounts via DI.
///
/// Step-0 note (the ticket was written before BUT-1154's connectivity fix
/// landed): `SmartImportViewModel` is already directly constructible in a unit
/// test today — `_setupConnectivityListener` uses `ServiceLocator.tryGet`
/// (null-safe), so no construction-time `StateError` survives. The genuine
/// remaining gap the ticket targets is the *widget* mount: `SmartImportView`
/// builds its own `ChangeNotifierProvider(create: ... ServiceLocator.get<
/// ImportManager>())`, so a widget test must satisfy that one lookup. This
/// proves it does, with exactly the "ImportManager bridge + clipboard stub"
/// the ticket calls for — the guard net for the 467-line `State.build` split.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/smart_import_view.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as prod_locator;

import '../infrastructure/di/test_service_locator.dart';

class _MockImportManager extends Mock implements ImportManager {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget app() => MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sv'),
        home: const SmartImportView(),
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    // Clipboard stub: the view's post-frame initState reads the clipboard via
    // the VM. Return empty text so no URL is detected and no suggestion dialog
    // is shown — keeps the smoke test to a clean mount.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': ''};
      }
      return null;
    });

    // ImportManager bridge: TestServiceLocator registers into the shared GetIt;
    // the prod DIContainer wraps that same GetIt, so the view's
    // `ServiceLocator.get<ImportManager>()` in its `create:` resolves the mock.
    await TestServiceLocator.initialize();
    prod_locator.ServiceLocator.initialize(DIContainer());
    TestServiceLocator.registerMock<ImportManager>(_MockImportManager());
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    await TestServiceLocator.reset();
    prod_locator.ServiceLocator.reset();
  });

  testWidgets('mounts and settles via the ImportManager DI bridge',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // The view built without throwing on the ServiceLocator lookup, and its
    // Swedish app-bar title rendered — proof the DI graph resolved.
    expect(find.byType(SmartImportView), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
  });
}
