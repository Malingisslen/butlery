/// The pantry's place groups and its add button as drawn in Skarmar v12
/// etapp 2 #skafferivyn, in the dark theme where the phone test found them
/// off: a paper edge and a saffron rule around each group, and an ink add
/// button on the dark page.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/pantry/pantry_viewmodel.dart';
import 'package:butlery/views/pantry/pantry_view.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/helpers/offline_banner_support.dart';
import '../../../test_support/base_unit_test.dart';

class _MockPantryViewModel extends Mock implements PantryViewModel {}

void main() {
  final salt = PantryItem(
    id: 'p_1',
    ingredientName: 'salt',
    quantity: 1,
    unit: 'kg',
    location: PantryLocation.pantry,
    addedAt: DateTime(2026, 1, 1),
  );
  final milk = PantryItem(
    id: 'p_2',
    ingredientName: 'Mjölk',
    quantity: 1,
    unit: 'l',
    location: PantryLocation.fridge,
    addedAt: DateTime(2026, 1, 1),
  );

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    production.ServiceLocator.initialize(DIContainer());
    ensureOfflineService();
    registerFallbackValue(PantryLocation.fridge);
  });

  late _MockPantryViewModel vm;

  setUp(() async {
    await TestServiceLocator.initialize();
    ensureOfflineService();
    vm = _MockPantryViewModel();
    when(() => vm.isLoading).thenReturn(false);
    when(() => vm.error).thenReturn(null);
    when(() => vm.hasError).thenReturn(false);
    when(() => vm.items).thenReturn([salt, milk]);
    when(() => vm.expiringItems).thenReturn([milk]);
    when(() => vm.itemsByLocation(any())).thenReturn(const []);
    when(
      () => vm.itemsByLocation(PantryLocation.pantry),
    ).thenReturn([salt]);
    when(() => vm.loadPantry()).thenAnswer((_) async {});
    TestServiceLocator.registerFactory<PantryViewModel>(() => vm);
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    BaseUnitTest.resetMocks();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  Future<ColorScheme> pumpDark(WidgetTester tester) async {
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
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: PantryView()),
      ),
    );
    await tester.pumpAndSettle();
    return AppTheme.darkTheme.colorScheme;
  }

  Border groupBorder(WidgetTester tester, String heading) {
    final box = tester.widget<Container>(
      find
          .ancestor(of: find.text(heading), matching: find.byType(Container))
          .last,
    );
    return (box.decoration! as BoxDecoration).border! as Border;
  }

  testWidgets('a place group has a muted edge and a hairline, not the recipe '
      'card frame', (tester) async {
    final cs = await pumpDark(tester);

    final border = groupBorder(tester, 'skafferi');
    expect(border.left.color, cs.outline);
    expect(border.bottom.color, cs.outlineVariant);
  });

  testWidgets('"går ut snart" takes the danger tone on its edge', (
    tester,
  ) async {
    final cs = await pumpDark(tester);

    expect(groupBorder(tester, 'går ut snart').left.color, cs.error);
  });

  testWidgets('the group heading is 13 px, as drawn', (tester) async {
    await pumpDark(tester);

    final heading = tester.widget<Text>(find.text('skafferi'));
    expect(heading.style?.fontSize, 13);
  });

  testWidgets('the add button stands out from the dark page', (tester) async {
    final cs = await pumpDark(tester);

    final button = tester.widget<Material>(
      find
          .ancestor(
            of: find.bySemanticsLabel('Lägg till ny vara'),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(button.color, cs.onSurface);
  });
}
