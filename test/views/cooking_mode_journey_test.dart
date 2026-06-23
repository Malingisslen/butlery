/// Journey test: open recipe → enter cooking mode → step through instructions.
///
/// Exercises [CookingModeViewModel] through a simplified body that mirrors
/// the real [CookingModeView]'s split-panel layout (ingredients left /
/// instructions right larger) without pulling in the full production view
/// — the real view calls [SystemChrome.setPreferredOrientations] and
/// [WakelockPlus.enable] in initState, which blow up in the headless test
/// binding.
///
/// Assertions cover what the user observes:
///   - Both panels render with the recipe's ingredients + instructions.
///   - Advancing with the VM's next/previous step updates the active
///     instruction indicator.
///   - Closing cooking mode returns to the calling view.
///   - Panel colors are theme-resolved, not hardcoded.
library;

// ignore_for_file: invalid_use_of_protected_member

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/persistence_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/cooking_mode_viewmodel.dart';

import '../infrastructure/factories/recipe_factory.dart';

class _MockPersistenceService extends Mock implements PersistenceService {}

/// Test body that mirrors the split-panel cooking layout without the
/// orientation/wakelock side effects of the real view.
class _CookingModeBody extends StatelessWidget {
  const _CookingModeBody({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vm = context.watch<CookingModeViewModel>();

    return Scaffold(
      backgroundColor: cs.primary,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with title + close.
            Container(
              key: const Key('top_bar'),
              color: cs.primary,
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      vm.title.toLowerCase(),
                      key: const Key('title'),
                      style: TextStyle(color: cs.onPrimary),
                    ),
                  ),
                  IconButton(
                    key: const Key('close'),
                    icon: Icon(Icons.close, color: cs.onPrimary),
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ingredients panel (left, smaller).
                  Expanded(
                    flex: 35,
                    child: Container(
                      key: const Key('ingredients_panel'),
                      color: cs.primary,
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ingredienser (${vm.currentPortions} portioner)',
                            style: TextStyle(color: cs.onPrimary),
                          ),
                          const SizedBox(height: 8),
                          ...vm.scaledIngredients.map(
                            (ingredient) => Padding(
                              key: Key('ingredient_$ingredient'),
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                ingredient,
                                style: TextStyle(color: cs.onPrimary),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Instructions panel (right, larger).
                  Expanded(
                    flex: 65,
                    child: Container(
                      key: const Key('instructions_panel'),
                      color: cs.surface,
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Steg ${vm.currentStepIndex + 1} / ${vm.totalSteps}',
                            key: const Key('step_counter'),
                            style: TextStyle(color: cs.onSurface),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: ListView.builder(
                              itemCount: vm.instructions.length,
                              itemBuilder: (context, index) {
                                final isActive = index == vm.currentStepIndex;
                                return Container(
                                  key: Key('step_$index'),
                                  padding: const EdgeInsets.all(8),
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  color: isActive
                                      ? cs.primaryContainer
                                      : cs.surfaceContainerHighest,
                                  child: Text(
                                    vm.instructions[index],
                                    style: TextStyle(
                                      color: isActive
                                          ? cs.onPrimaryContainer
                                          : cs.onSurface,
                                      fontWeight: isActive
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                key: const Key('prev_step'),
                                onPressed: vm.hasPreviousStep
                                    ? vm.previousStep
                                    : null,
                                child: const Text('Föregående'),
                              ),
                              TextButton(
                                key: const Key('next_step'),
                                onPressed: vm.hasNextStep ? vm.nextStep : null,
                                child: const Text('Nästa'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _testApp({
  required CookingModeViewModel viewModel,
  required VoidCallback onClose,
  required ValueNotifier<ColorScheme?> schemeHolder,
}) {
  return ChangeNotifierProvider<CookingModeViewModel>.value(
    value: viewModel,
    child: MaterialApp(
      locale: const Locale('sv'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      home: Builder(
        builder: (context) {
          schemeHolder.value = Theme.of(context).colorScheme;
          return _CookingModeBody(onClose: onClose);
        },
      ),
    ),
  );
}

void main() {
  late _MockPersistenceService mockPersistence;
  late CookingModeViewModel viewModel;
  late bool closed;

  // Landscape-style surface so the two-panel Row has room to lay out.
  const landscapeSize = Size(1024, 600);

  setUp(() {
    // Production ServiceLocator bridge — CookingModeViewModel resolves
    // PersistenceService via ServiceLocator.get<>() to load font scale.
    final getIt = GetIt.instance;
    if (getIt.isRegistered<PersistenceService>()) {
      getIt.unregister<PersistenceService>();
    }

    production.ServiceLocator.initialize(DIContainer());

    mockPersistence = _MockPersistenceService();
    // Default: no saved font scale, setInt is a no-op.
    when(() => mockPersistence.getInt(any())).thenAnswer((_) async => null);
    when(() => mockPersistence.setInt(any(), any())).thenAnswer((_) async {});
    getIt.registerSingleton<PersistenceService>(mockPersistence);

    closed = false;
    viewModel = CookingModeViewModel(
      recipe: RecipeFactory.build(
        id: 'koettbullar',
        title: 'Köttbullar',
        ingredients: [
          '500 g blandfärs',
          '1 gul lök',
          '1 dl ströbröd',
          '1 ägg',
          '2 dl mjölk',
        ],
        instructions: [
          'Finhacka löken och fräs den i smör.',
          'Blanda färsen med ströbröd, ägg och mjölk.',
          'Rulla bollar och stek dem gyllenbruna.',
        ],
        portions: 4,
      ),
    );
  });

  tearDown(() {
    viewModel.dispose();
    final getIt = GetIt.instance;
    if (getIt.isRegistered<PersistenceService>()) {
      getIt.unregister<PersistenceService>();
    }
    production.ServiceLocator.reset();
  });

  group('Cooking mode journey', () {
    testWidgets(
      'both panels render with ingredients and instructions from the recipe',
      (tester) async {
        await tester.binding.setSurfaceSize(landscapeSize);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final schemeHolder = ValueNotifier<ColorScheme?>(null);
        await tester.pumpWidget(
          _testApp(
            viewModel: viewModel,
            onClose: () => closed = true,
            schemeHolder: schemeHolder,
          ),
        );
        await tester.pumpAndSettle();

        // Both panels are present — the two-panel layout is the defining
        // feature of cooking mode per the mockup decision (landscape split).
        expect(find.byKey(const Key('ingredients_panel')), findsOneWidget);
        expect(find.byKey(const Key('instructions_panel')), findsOneWidget);

        // Title renders lowercased per the project's recipe-detail convention.
        expect(find.text('köttbullar'), findsOneWidget);

        // Every ingredient is visible on the left.
        expect(find.text('500 g blandfärs'), findsOneWidget);
        expect(find.text('1 gul lök'), findsOneWidget);
        expect(find.text('2 dl mjölk'), findsOneWidget);

        // Every instruction is visible on the right.
        for (final step in viewModel.instructions) {
          expect(find.text(step), findsOneWidget);
        }
        expect(find.byKey(const Key('step_counter')), findsOneWidget);
        expect(find.text('Steg 1 / 3'), findsOneWidget);

        // Panel colors come from the live theme (survives a palette refactor).
        final cs = schemeHolder.value!;
        final ingredientsPanel = tester.widget<Container>(
          find.byKey(const Key('ingredients_panel')),
        );
        final instructionsPanel = tester.widget<Container>(
          find.byKey(const Key('instructions_panel')),
        );
        expect(ingredientsPanel.color, cs.primary);
        expect(instructionsPanel.color, cs.surface);
      },
    );

    testWidgets(
      'tapping Nästa advances the active step; close invokes the exit callback',
      (tester) async {
        await tester.binding.setSurfaceSize(landscapeSize);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final schemeHolder = ValueNotifier<ColorScheme?>(null);
        await tester.pumpWidget(
          _testApp(
            viewModel: viewModel,
            onClose: () => closed = true,
            schemeHolder: schemeHolder,
          ),
        );
        await tester.pumpAndSettle();

        // Step 0 is active initially.
        expect(viewModel.currentStepIndex, 0);
        expect(viewModel.hasPreviousStep, isFalse);
        expect(find.text('Steg 1 / 3'), findsOneWidget);

        // Active step's container uses primaryContainer; others use
        // surfaceContainerHighest. Verify the active-step indicator tracks
        // the VM, not a hardcoded index.
        final cs = schemeHolder.value!;
        Container stepContainer(int i) =>
            tester.widget<Container>(find.byKey(Key('step_$i')));
        expect(stepContainer(0).color, cs.primaryContainer);
        expect(stepContainer(1).color, cs.surfaceContainerHighest);
        expect(stepContainer(2).color, cs.surfaceContainerHighest);

        // Advance.
        await tester.tap(find.byKey(const Key('next_step')));
        await tester.pumpAndSettle();

        expect(viewModel.currentStepIndex, 1);
        expect(viewModel.hasPreviousStep, isTrue);
        expect(viewModel.hasNextStep, isTrue);
        expect(find.text('Steg 2 / 3'), findsOneWidget);
        expect(stepContainer(0).color, cs.surfaceContainerHighest);
        expect(stepContainer(1).color, cs.primaryContainer);

        // Advance to the final step — Nästa becomes disabled.
        await tester.tap(find.byKey(const Key('next_step')));
        await tester.pumpAndSettle();
        expect(viewModel.currentStepIndex, 2);
        expect(viewModel.hasNextStep, isFalse);
        final nextButton = tester.widget<TextButton>(
          find.byKey(const Key('next_step')),
        );
        expect(
          nextButton.onPressed,
          isNull,
          reason: 'Nästa must disable at the last step',
        );

        // Go back one step with Föregående.
        await tester.tap(find.byKey(const Key('prev_step')));
        await tester.pumpAndSettle();
        expect(viewModel.currentStepIndex, 1);

        // Tapping close fires the exit callback (in production this pops
        // the cooking-mode route back to the recipe detail view).
        expect(closed, isFalse);
        await tester.tap(find.byKey(const Key('close')));
        await tester.pumpAndSettle();
        expect(
          closed,
          isTrue,
          reason: 'Close control must invoke the exit callback',
        );
      },
    );
  });
}
