/// The recipe's own cook summary opens the full history, and only shows
/// when the recipe has been cooked and is the user's own (not a public copy).
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/recipe/recipe_cooking_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_metadata.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../views/helpers/view_test_helpers.dart';

void main() {
  final lastCooked = DateTime(2026, 11, 20);

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() async {
    await ViewTestHelpers.setupViewTestEnvironment();
    TestServiceLocator.registerMock<RecipeCookingService>(
      MockFactory.createRecipeCookingService(),
    );
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    await ViewTestHelpers.teardownViewTestEnvironment();
  });

  Recipe recipe({required int cooks, DateTime? last}) => RecipeFactory.build(
    id: 'r1',
    title: 'Köttbullar',
    lastCookedAt: last,
  ).copyWith(cookCount: cooks);

  Future<List<String?>> pump(
    WidgetTester tester,
    Recipe r, {
    bool publicCopy = false,
  }) async {
    final service = MockUnifiedRecipeService()
      ..setRecipeState(recipes: [r], isInitialized: true);
    TestServiceLocator.registerMock<UnifiedRecipeService>(service);
    final vm = RecipeDetailViewModel(recipe: r);
    addTearDown(vm.dispose);
    final pushed = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('sv', 'SE'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.lightTheme,
        onGenerateRoute: (settings) {
          pushed.add(settings.name);
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('history page')),
          );
        },
        home: Scaffold(
          body: RecipeDetailMetadata(
            viewModel: vm,
            currentPortions: 4,
            isScaled: false,
            publicCopy: publicCopy,
          ),
        ),
      ),
    );
    await tester.pump();
    return pushed;
  }

  String summary(WidgetTester tester, int cooks) {
    final l10n = AppLocalizations.of(
      tester.element(find.byType(RecipeDetailMetadata)),
    );
    return l10n.cookHistoryRecipeSummary(
      cooks,
      DateFormat.MMMd(l10n.localeName).format(lastCooked),
    );
  }

  testWidgets('a cooked recipe shows its summary and a tap opens history', (
    tester,
  ) async {
    final pushed = await pump(tester, recipe(cooks: 2, last: lastCooked));

    final text = summary(tester, 2);
    expect(find.text(text), findsOneWidget);

    await tester.tap(find.text(text));
    await tester.pumpAndSettle();

    expect(pushed, contains(Routes.cookHistory));
  });

  testWidgets('a recipe never cooked shows no summary link', (tester) async {
    await pump(tester, recipe(cooks: 0, last: lastCooked));

    expect(find.text(summary(tester, 0)), findsNothing);
    expect(find.text(summary(tester, 1)), findsNothing);
  });

  testWidgets('a public copy shows no summary link', (tester) async {
    await pump(
      tester,
      recipe(cooks: 2, last: lastCooked),
      publicCopy: true,
    );

    expect(find.text(summary(tester, 2)), findsNothing);
  });
}
