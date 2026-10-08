/// BUT-2168: a link that fails on the real Smart import screen says why and
/// offers the most helpful route first (flows-roles-budget.md, flow 03
/// `hämtar`): a broken link or a login wall → "Klistra in texten själv", a
/// page without a recipe → "Skriv själv".
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as prod_locator;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/models/import_result_v2.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/smart_import_viewmodel.dart';
import 'package:butlery/views/smart_import/import_widgets.dart';
import 'package:butlery/views/smart_import_view.dart';
import 'package:butlery/widgets/common/feedback/inline_error.dart';

import '../infrastructure/di/test_service_locator.dart';

class _MockImportManager extends Mock implements ImportManager {}

class _MockUserService extends Mock implements UserService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const link = 'https://www.ica.se/recept/pannkakor-1/';
  const clipboardText = 'Pannkakor\n3 dl vetemjöl\n6 dl mjölk\n3 ägg';
  late _MockImportManager importManager;
  late List<RouteSettings> pushed;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': clipboardText};
          }
          return null;
        });

    await TestServiceLocator.initialize();
    prod_locator.ServiceLocator.initialize(DIContainer());
    importManager = _MockImportManager();
    TestServiceLocator.registerMock<ImportManager>(importManager);
    final userService = _MockUserService();
    when(
      () => userService.allergenPreferences,
    ).thenReturn(UserAllergenPreferences.defaults);
    TestServiceLocator.registerMock<UserService>(userService);
    pushed = [];
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    await TestServiceLocator.reset();
    prod_locator.ServiceLocator.reset();
  });

  /// Pumps the screen with [link], taps Importera and lets the import fail
  /// with [code], as the URL strategy reports it.
  Future<void> failImport(WidgetTester tester, ImportErrorCode code) async {
    when(
      () =>
          importManager.autoImport(link, onProgress: any(named: 'onProgress')),
    ).thenAnswer(
      (_) async => ImportManagerResult.failure(
        'any English text',
        errorCode: code,
        availableStrategies: const [
          'URL Import',
          'Text Import',
          'Photo Import',
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sv'),
        home: const SmartImportView(initialUrl: link),
        onGenerateRoute: (settings) {
          pushed.add(settings);
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('editor')),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('test-smart-import-url')));
    await tester.pumpAndSettle();
  }

  /// The route buttons as the screen draws them, top to bottom, by their
  /// visible label.
  List<String> drawnRoutes(WidgetTester tester) {
    final buttons = find.descendant(
      of: find.byType(ImportErrorMessage),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );
    final labels = [
      for (final e in buttons.evaluate())
        (find
                    .descendant(
                      of: find.byWidget(e.widget),
                      matching: find.byType(Text),
                    )
                    .evaluate()
                    .single
                    .widget
                as Text)
            .data!,
    ];
    return labels;
  }

  Future<void> tapRoute(WidgetTester tester, ImportRoute route) async {
    final button = find.byKey(ImportErrorMessage.routeKey(route));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  for (final (code, what, name) in [
    (
      ImportErrorCode.urlNotAccessible,
      'Länken kunde inte läsas',
      'urlNotAccessible: says "Länken kunde inte läsas" and offers pasting '
          'the text first, which fills the field from the clipboard',
    ),
    (
      ImportErrorCode.platformBlocked,
      'Sidan kräver inloggning',
      'platformBlocked: says "Sidan kräver inloggning" and offers pasting '
          'the text first, which fills the field from the clipboard',
    ),
  ]) {
    testWidgets(name, (tester) async {
      await failImport(tester, code);

      expect(tester.widget<InlineError>(find.byType(InlineError)).what, what);
      expect(drawnRoutes(tester), [
        'Klistra in texten själv',
        'Fotografera skärmen',
        'Skriv själv',
      ]);

      await tapRoute(tester, ImportRoute.pasteText);

      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        clipboardText,
      );
      expect(pushed, isEmpty);
    });
  }

  testWidgets('noRecipeContent: says "Vi hittade inget recept på sidan" and '
      'offers writing it first, which opens the editor', (tester) async {
    await failImport(tester, ImportErrorCode.noRecipeContent);

    expect(
      tester.widget<InlineError>(find.byType(InlineError)).what,
      'Vi hittade inget recept på sidan',
    );
    expect(drawnRoutes(tester), [
      'Skriv själv',
      'Fotografera skärmen',
      'Klistra in texten själv',
    ]);

    await tapRoute(tester, ImportRoute.manual);

    expect(pushed.single.name, Routes.manualEntry);
    expect(find.text('editor'), findsOneWidget);
  });
}
