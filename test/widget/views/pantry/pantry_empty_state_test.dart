/// An empty pantry draws the shared empty state for an own collection, and its
/// action opens the add sheet (BUT-2371).
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
import 'package:butlery/views/pantry/add_pantry_item_sheet.dart';
import 'package:butlery/views/pantry/pantry_view.dart';
import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/helpers/offline_banner_support.dart';
import '../../../test_support/base_unit_test.dart';

class _MockPantryViewModel extends Mock implements PantryViewModel {}

void main() {
  final sv = lookupAppLocalizations(const Locale('sv'));

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
    when(() => vm.items).thenReturn(const []);
    when(() => vm.expiringItems).thenReturn(const []);
    when(() => vm.itemsByLocation(any())).thenReturn(const []);
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

  Future<void> pumpEmpty(WidgetTester tester) async {
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
        home: const Scaffold(body: PantryView()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an empty pantry shows its title and illustration', (
    tester,
  ) async {
    await pumpEmpty(tester);

    expect(find.text(sv.pantryEmptyTitle), findsOneWidget);
    expect(find.text(sv.pantryEmptyDescription), findsOneWidget);
    expect(find.byType(VegetableIllustration), findsOneWidget);
  });

  testWidgets('the empty state action opens the add sheet', (tester) async {
    await pumpEmpty(tester);

    await tester.tap(find.text(sv.pantryAddIngredient));
    await tester.pumpAndSettle();

    expect(find.byType(AddPantryItemSheet), findsOneWidget);
  });
}
