// A failed lookup says so and offers a retry instead of reading as "none found".

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/cooking/ingredient_substitution.dart';
import 'package:butlery/services/cooking/substitution_suggestion_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/recipe/ingredient_substitution_sheet.dart';

import '../../infrastructure/di/test_service_locator.dart';

class _FlakySubstitutions extends Fake
    implements SubstitutionSuggestionService {
  int calls = 0;

  @override
  Future<List<IngredientSubstitution>> suggestFor(String ingredientName) async {
    calls++;
    if (calls == 1) throw StateError('offline');
    return const [IngredientSubstitution(name: 'Yoghurt', ratio: 0.75)];
  }
}

void main() {
  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() async {
    await TestServiceLocator.initialize();
  });

  tearDown(() async {
    await TestServiceLocator.reset();
  });

  testWidgets('a failed lookup shows an error and retry loads the options', (
    tester,
  ) async {
    final service = _FlakySubstitutions();
    TestServiceLocator.registerMock<SubstitutionSuggestionService>(service);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('sv'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: IngredientSubstitutionSheet(ingredientName: 'Grädde'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kunde inte hämta ersättningar'), findsOneWidget);
    expect(find.text('Inga ersättningar hittades'), findsNothing);

    await tester.tap(find.text('Försök igen'));
    await tester.pumpAndSettle();

    expect(find.text('Yoghurt'), findsOneWidget);
    expect(service.calls, 2);
  });
}
