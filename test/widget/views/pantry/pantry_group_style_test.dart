/// The pantry's place groups and its add button as drawn in Skarmar v12
/// etapp 2 #skafferivyn, in the dark theme where the phone test found them
/// off: a paper bar on each group band, a saffron bar on "går ut snart", and
/// an ink add button on the dark page.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/buttons/saffron_square_button.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/pantry/pantry_viewmodel.dart';
import 'package:butlery/views/pantry/pantry_view.dart';
import 'package:butlery/widgets/common/list/section_band.dart';

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

  SectionBand band(WidgetTester tester, String heading) =>
      tester.widget<SectionBand>(
        find.ancestor(
          of: find.text(heading.toUpperCase()),
          matching: find.byType(SectionBand),
        ),
      );

  Border barOf(WidgetTester tester, String heading) {
    final box = tester.widget<Container>(
      find
          .descendant(
            of: find.ancestor(
              of: find.text(heading.toUpperCase()),
              matching: find.byType(SectionBand),
            ),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Container &&
                  w.decoration is BoxDecoration &&
                  (w.decoration! as BoxDecoration).border is Border,
            ),
          )
          .first,
    );
    return (box.decoration! as BoxDecoration).border! as Border;
  }

  testWidgets('a place group is a standard band with a paper bar and its '
      'count', (tester) async {
    final cs = await pumpDark(tester);

    expect(band(tester, 'skafferi').tone, SectionBandTone.standard);
    expect(band(tester, 'skafferi').count, '1');
    // text.primary on the dark page: paper, never the ink of cs.primary.
    final bar = barOf(tester, 'skafferi').left;
    expect(bar.color, cs.onSurface);
    expect(bar.color, isNot(cs.primary));
  });

  testWidgets('"går ut snart" takes the warning tone on its bar', (
    tester,
  ) async {
    final cs = await pumpDark(tester);

    expect(band(tester, 'går ut snart').tone, SectionBandTone.warning);
    final bar = barOf(tester, 'går ut snart').left;
    expect(bar.color, AppModeColors.actionPrimary(cs.brightness));
    expect(bar.color, isNot(barOf(tester, 'skafferi').left.color));
  });

  testWidgets('the group heading is the shared capitals overline', (
    tester,
  ) async {
    await pumpDark(tester);

    final heading = tester.widget<Text>(find.text('SKAFFERI'));
    expect(heading.style?.fontSize, AppTextStyles.sectionHeading.fontSize);
  });

  testWidgets('the add button is the saffron square, not the dark page', (
    tester,
  ) async {
    final cs = await pumpDark(tester);

    final fill = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(SaffronSquareButton),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(fill.color, AppModeColors.actionPrimary(cs.brightness));
    expect(fill.color, isNot(cs.surface));
  });
}
