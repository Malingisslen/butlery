/// P4-U06: cooking mode's step row.
///
/// - "Nästa steg" is the view's one saffron action (Komponentark v1
///   mönster 4; Skarmar v12 del 1 'Matlagningsläge'; Grafisk manual v6:219).
/// - A disabled control on surface.ink is its own opaque colour, never paper
///   at an opacity, and reads at 4.5:1 or better (tokens.json:40-53,
///   :198-201; beslut-paket2 "disabled on surface.ink").
/// - The base is surface.ink in light mode and dark-bg #17251D in dark mode,
///   "så skärmen inte lyser i ett släckt kök" (Skarmar v12 del 1
///   #lagamorkt); both rules above hold on each base.
/// - "Nästa steg" fills the rest of the row (flex:1 in #lagastaende and
///   #lagamorkt).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/persistence_service.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/cooking_mode_viewmodel.dart';
import 'package:butlery/views/cooking_mode_view.dart';
import 'package:butlery/widgets/common/tappable_wrapper.dart';

import '../../infrastructure/factories/recipe_factory.dart';

class _MockPersistenceService extends Mock implements PersistenceService {}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  late CookingModeViewModel vm;

  setUp(() {
    final getIt = GetIt.instance;
    if (getIt.isRegistered<PersistenceService>()) {
      getIt.unregister<PersistenceService>();
    }
    production.ServiceLocator.initialize(DIContainer());
    final persistence = _MockPersistenceService();
    when(() => persistence.getInt(any())).thenAnswer((_) async => null);
    when(() => persistence.setInt(any(), any())).thenAnswer((_) async {});
    getIt.registerSingleton<PersistenceService>(persistence);

    vm = CookingModeViewModel(
      recipe: RecipeFactory.build(
        id: 'r1',
        title: 'Köttbullar',
        ingredients: ['500 g blandfärs'],
        instructions: ['Fräs löken.', 'Blanda färsen.', 'Stek bollarna.'],
        portions: 4,
      ),
    );
  });

  tearDown(() {
    vm.dispose();
    final getIt = GetIt.instance;
    if (getIt.isRegistered<PersistenceService>()) {
      getIt.unregister<PersistenceService>();
    }
  });

  Future<void> pump(WidgetTester tester, ThemeData theme) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        locale: const Locale('sv'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          backgroundColor: theme.colorScheme.surface,
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(width: 600, child: CookingStepNavigation(vm: vm)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Color baseOf(WidgetTester tester) => tester
      .widget<Container>(
        find
            .descendant(
              of: find.byType(CookingStepNavigation),
              matching: find.byType(Container),
            )
            .first,
      )
      .color!;

  for (final (mode, theme, base) in [
    ('light', AppTheme.lightTheme, const Color(0xFF24382C)),
    ('dark', AppTheme.darkTheme, const Color(0xFF17251D)),
  ]) {
    testWidgets('the base is ${base.toARGB32().toRadixString(16)} ($mode)', (
      tester,
    ) async {
      await pump(tester, theme);
      expect(baseOf(tester), base);
    });

    testWidgets('Nästa steg fills the rest of the row ($mode)', (
      tester,
    ) async {
      await pump(tester, theme);
      final row = tester.getRect(find.byType(CookingStepNavigation));
      final next = tester.getRect(
        find.byKey(const ValueKey('cooking-mode-next-step')),
      );
      expect(row.right - next.right, lessThanOrEqualTo(16));
      expect(next.width, greaterThan(row.width / 2));
    });

    testWidgets('Nästa steg is the one saffron action ($mode)', (tester) async {
      await pump(tester, theme);

      final heroes = tester
          .widgetList<ButtonStyleButton>(find.bySubtype<ButtonStyleButton>())
          .where(
            (b) =>
                b.style?.backgroundColor?.resolve(const {}) ==
                AppModeColors.actionPrimary(theme.brightness),
          )
          .toList();
      expect(heroes, hasLength(1));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('cooking-mode-next-step')),
          matching: find.text('Nästa steg'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('cooking-mode-next-step')));
      await tester.pumpAndSettle();
      expect(vm.currentStepIndex, 1);
    });

    testWidgets('disabled on ink is opaque and reads at 4.5:1 ($mode)', (
      tester,
    ) async {
      await pump(tester, theme);

      // First step: "Föregående steg" is disabled.
      final previous = find.descendant(
        of: find.byType(TappableWrapper),
        matching: find.byIcon(Icons.arrow_back),
      );
      final icon = tester.widget<Icon>(previous);
      final base = baseOf(tester);
      expect(icon.color!.a, 1.0, reason: 'no opacity as a state');
      expect(icon.color, isNot(theme.colorScheme.onPrimary));
      expect(_contrast(icon.color!, base), greaterThanOrEqualTo(4.5));
    });

    testWidgets('the last step disables Nästa steg ($mode)', (tester) async {
      vm.nextStep();
      vm.nextStep();
      await pump(tester, theme);

      final next = tester.widget<FilledButton>(
        find.byKey(const ValueKey('cooking-mode-next-step')),
      );
      expect(next.onPressed, isNull);
      final disabledFill = next.style!.backgroundColor!.resolve(const {
        WidgetState.disabled,
      })!;
      expect(disabledFill.a, 1.0, reason: 'no opacity as a state');
    });
  }
}
