/// A link pasted into Smart import that imports cleanly opens in the recipe
/// editor for review.
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
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/smart_import_view.dart';

import '../infrastructure/di/test_service_locator.dart';

class _MockImportManager extends Mock implements ImportManager {}

class _MockUserService extends Mock implements UserService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const link = 'https://www.ica.se/recept/pannkakor-1/';
  late _MockImportManager importManager;
  late List<RouteSettings> pushed;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': ''};
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

  testWidgets('paste URL → fetch+parse → the recipe opens in the editor', (
    tester,
  ) async {
    final recipe = Recipe(
      core: RecipeCore(
        id: '',
        title: 'Pannkakor',
        description: '',
        ingredients: const ['3 dl vetemjöl', '6 dl mjölk', '3 ägg'],
        instructions: const ['Vispa ihop.', 'Stek.'],
        mealType: 'Middag',
        sourceUrl: link,
      ),
      type: RecipeType.personal,
    );
    when(
      () =>
          importManager.autoImport(link, onProgress: any(named: 'onProgress')),
    ).thenAnswer((_) async => ImportManagerResult.success(recipe));

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

    verify(
      () =>
          importManager.autoImport(link, onProgress: any(named: 'onProgress')),
    ).called(1);
    final editor = pushed.single;
    expect(editor.name, Routes.manualEntry);
    final args = editor.arguments! as Map<String, Object?>;
    expect(args['initialRecipe'], same(recipe));
    expect(find.text('editor'), findsOneWidget);
  });
}
