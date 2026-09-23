/// P4-U06: cooking mode's step row.
///
/// - "Nästa steg" is the view's one saffron action (Komponentark v1
///   mönster 4; Skarmar v12 del 1 'Matlagningsläge'; Grafisk manual v6:219).
/// - A disabled control on surface.ink is its own opaque colour, never paper
///   at an opacity, and reads at 4.5:1 or better (tokens.json:40-53,
///   :198-201; beslut-paket2 "disabled on surface.ink").
/// - Both hold in light and dark mode, since cooking mode is ink in both.
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
          backgroundColor: theme.colorScheme.primary,
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(width: 600, child: CookingStepNavigation(vm: vm)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final (mode, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
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
      final ink = theme.colorScheme.primary;
      expect(icon.color!.a, 1.0, reason: 'no opacity as a state');
      expect(icon.color, isNot(theme.colorScheme.onPrimary));
      expect(_contrast(icon.color!, ink), greaterThanOrEqualTo(4.5));
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
