/// P6-U04 · Flow 04, cooking mode (flows-roles-budget.md:66-73;
/// produktregler.md:421-423, 1199-1201, 1227; Skarmar v12 etapp 11
/// #lgbutan).
///
/// - Back and close leave at once until more than one step is done; after
///   that they ask, and "Fortsätt laga" keeps the step.
/// - The last step carries "Klart", which leaves with [CookingModeExit.finished]
///   so the recipe detail counts the recipe as cooked.
/// - Landscape is forced only under 768 px on the shortest side.
/// - A recipe without steps is not a cooking session: no forced rotation, no
///   kept-awake screen, no "lagar just nu" signal — and it offers "Skriv
///   stegen" and "Till inköpslistan".
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/cooking/ingredient_substitution.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/cooking/step_timer_service.dart';
import 'package:butlery/services/cooking/substitution_suggestion_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/persistence_service.dart';
import 'package:butlery/services/voice/tts_service.dart';
import 'package:butlery/services/voice/voice_capture_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/cooking_mode_viewmodel.dart';
import 'package:butlery/views/cooking_mode_view.dart';

import '../infrastructure/factories/recipe_factory.dart';
import '../infrastructure/mocks/production_mocks.dart';

class _MockPersistenceService extends Mock implements PersistenceService {}

class _FakeEffects implements CookingSessionEffects {
  final List<String> calls = [];

  @override
  void lockLandscape() => calls.add('lock');

  @override
  void releaseOrientation() => calls.add('release');

  @override
  void keepScreenAwake({required bool on}) => calls.add(on ? 'awake' : 'sleep');

  @override
  void edgeToEdge() => calls.add('edge');
}

class _SpyVm extends CookingModeViewModel {
  _SpyVm({required super.recipe});

  int enters = 0;
  int exits = 0;

  @override
  Future<void> onEnter() {
    enters++;
    return super.onEnter();
  }

  @override
  Future<void> onExit() {
    exits++;
    return super.onExit();
  }
}

class _FakeTts extends Fake implements TtsService {
  @override
  bool get isAvailable => false;

  @override
  bool get isSpeaking => false;

  @override
  Future<void> init() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

class _FakeCapture extends Fake implements VoiceCaptureService {
  @override
  bool get isRecording => false;

  @override
  Future<void> cancelRecording() async {}
}

class _FakeSubstitutions extends Fake implements SubstitutionSuggestionService {
  @override
  Future<List<IngredientSubstitution>> suggestFor(
    String ingredientName,
  ) async => const [];
}

Recipe _recipe({List<String>? steps, List<String>? ingredients}) =>
    RecipeFactory.build(
      id: 'r1',
      title: 'Köttbullar',
      ingredients: ingredients ?? ['500 g blandfärs'],
      instructions:
          steps ?? ['Fräs löken.', 'Blanda färsen.', 'Stek bollarna.'],
      portions: 4,
    );

void main() {
  final sv = AppLocalizationsSv();
  late StepTimerService timers;

  setUp(() {
    final getIt = GetIt.instance;
    if (getIt.isRegistered<PersistenceService>()) {
      getIt.unregister<PersistenceService>();
    }
    if (getIt.isRegistered<OfflineService>()) {
      getIt.unregister<OfflineService>();
    }
    if (getIt.isRegistered<TtsService>()) getIt.unregister<TtsService>();
    if (getIt.isRegistered<VoiceCaptureService>()) {
      getIt.unregister<VoiceCaptureService>();
    }
    if (getIt.isRegistered<StepTimerService>()) {
      getIt.unregister<StepTimerService>();
    }
    if (getIt.isRegistered<SubstitutionSuggestionService>()) {
      getIt.unregister<SubstitutionSuggestionService>();
    }
    production.ServiceLocator.initialize(DIContainer());
    final persistence = _MockPersistenceService();
    when(() => persistence.getInt(any())).thenAnswer((_) async => null);
    when(() => persistence.setInt(any(), any())).thenAnswer((_) async {});
    when(() => persistence.getBool(any())).thenAnswer((_) async => true);
    when(() => persistence.setBool(any(), any())).thenAnswer((_) async {});
    getIt.registerSingleton<PersistenceService>(persistence);
    final offline = MockOfflineService();
    when(() => offline.isOnline).thenReturn(true);
    when(() => offline.addListener(any())).thenReturn(null);
    when(() => offline.removeListener(any())).thenReturn(null);
    getIt.registerSingleton<OfflineService>(offline);
    getIt.registerSingleton<TtsService>(_FakeTts());
    getIt.registerSingleton<VoiceCaptureService>(_FakeCapture());
    timers = StepTimerService();
    getIt.registerSingleton<StepTimerService>(timers);
    getIt.registerSingleton<SubstitutionSuggestionService>(
      _FakeSubstitutions(),
    );
  });

  tearDown(() {
    timers.dispose();
  });

  group('CookingSessionLifecycle', () {
    test('a phone (shortest side 400) is forced to landscape', () {
      final effects = _FakeEffects();
      final vm = _SpyVm(recipe: _recipe());
      addTearDown(vm.dispose);
      final lifecycle = CookingSessionLifecycle(vm: vm, effects: effects);

      lifecycle.start(const Size(400, 860));
      expect(effects.calls, ['lock', 'awake', 'edge']);
      expect(vm.enters, 1);

      lifecycle.end();
      expect(effects.calls, [
        'lock',
        'awake',
        'edge',
        'release',
        'sleep',
        'edge',
      ]);
      expect(vm.exits, 1);
    });

    test('a tablet (shortest side 800) follows the device', () {
      final effects = _FakeEffects();
      final vm = _SpyVm(recipe: _recipe());
      addTearDown(vm.dispose);
      final lifecycle = CookingSessionLifecycle(vm: vm, effects: effects);

      lifecycle.start(const Size(800, 1280));
      lifecycle.end();

      expect(effects.calls, isNot(contains('lock')));
      expect(effects.calls, isNot(contains('release')));
      expect(effects.calls, containsAllInOrder(['awake', 'sleep']));
    });

    test('the rule is the shortest side, under 768', () {
      expect(cookingForcesLandscape(const Size(767, 1400)), isTrue);
      expect(cookingForcesLandscape(const Size(1400, 767)), isTrue);
      expect(cookingForcesLandscape(const Size(768, 1024)), isFalse);
    });

    test(
      'a recipe without steps: no rotation, no wakelock, no "lagar just nu"',
      () {
        final effects = _FakeEffects();
        final vm = _SpyVm(recipe: _recipe(steps: const []));
        addTearDown(vm.dispose);
        final lifecycle = CookingSessionLifecycle(vm: vm, effects: effects);

        lifecycle.start(const Size(400, 860));
        lifecycle.end();

        expect(effects.calls, isEmpty);
        expect(vm.enters, 0);
        expect(vm.exits, 0);
      },
    );
  });

  Widget host(Widget Function(BuildContext) open, {List<Object?>? results}) =>
      MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('sv'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  final result = await Navigator.of(context).push<Object?>(
                    MaterialPageRoute(builder: open),
                  );
                  results?.add(result);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

  group('CookingModeView · a recipe without steps', () {
    testWidgets('shows the drawn empty state and touches no device effect', (
      tester,
    ) async {
      final effects = _FakeEffects();
      final results = <Object?>[];
      await tester.pumpWidget(
        host(
          (_) => CookingModeView(
            recipe: _recipe(steps: const []),
            effects: effects,
          ),
          results: results,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text(sv.cookingNoStepsTitle), findsOneWidget);
      expect(find.text(sv.cookingNoStepsBody), findsOneWidget);
      expect(find.text(sv.cookingNoStepsShopping), findsOneWidget);
      expect(effects.calls, isEmpty);

      await tester.tap(find.text(sv.cookingNoStepsWrite));
      await tester.pumpAndSettle();
      expect(results, [CookingModeExit.editRecipe]);
      expect(effects.calls, isEmpty);
    });

    testWidgets('"Till inköpslistan" returns to the recipe with that choice', (
      tester,
    ) async {
      final results = <Object?>[];
      await tester.pumpWidget(
        host(
          (_) => CookingModeView(
            recipe: _recipe(steps: const []),
            effects: _FakeEffects(),
          ),
          results: results,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(sv.cookingNoStepsShopping));
      await tester.pumpAndSettle();
      expect(results, [CookingModeExit.toShoppingList]);
    });

    testWidgets('no ingredients either: only "Skriv stegen"', (tester) async {
      await tester.pumpWidget(
        host(
          (_) => CookingModeView(
            recipe: _recipe(steps: const [], ingredients: const []),
            effects: _FakeEffects(),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text(sv.cookingNoStepsBodyNoIngredients), findsOneWidget);
      expect(find.text(sv.cookingNoStepsShopping), findsNothing);
      expect(find.text(sv.cookingNoStepsWrite), findsOneWidget);
    });
  });

  group('CookingModeView · leaving and finishing', () {
    Future<void> openCooking(
      WidgetTester tester, {
      List<Object?>? results,
      _FakeEffects? effects,
    }) async {
      // A landscape phone (shortest side 720): the split layout needs the
      // width the forced landscape gives it.
      final logical = tester.view.physicalSize / tester.view.devicePixelRatio;
      if (logical.shortestSide < 720) {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1280, 720);
        addTearDown(tester.view.reset);
      }
      await tester.pumpWidget(
        host(
          (_) => CookingModeView(
            recipe: _recipe(),
            effects: effects ?? _FakeEffects(),
          ),
          results: results,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    Future<void> next(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('cooking-mode-next-step')));
      await tester.pumpAndSettle();
    }

    testWidgets('back on step 2 leaves at once', (tester) async {
      final results = <Object?>[];
      await openCooking(tester, results: results);
      await next(tester);

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      await navigator.maybePop();
      await tester.pumpAndSettle();

      expect(find.text(sv.cookingExitConfirmTitle), findsNothing);
      expect(results, [null]);
    });

    testWidgets(
      'back on step 3 asks; Fortsätt laga keeps the step, Avsluta leaves',
      (tester) async {
        final results = <Object?>[];
        await openCooking(tester, results: results);
        await next(tester);
        await next(tester);
        expect(find.text(sv.cookingModeStepOf(3, 3)), findsOneWidget);

        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        unawaited(navigator.maybePop());
        await tester.pumpAndSettle();
        expect(find.text(sv.cookingExitConfirmTitle), findsOneWidget);

        await tester.tap(find.text(sv.cookingExitConfirmStay));
        await tester.pumpAndSettle();
        expect(find.text(sv.cookingModeStepOf(3, 3)), findsOneWidget);
        expect(results, isEmpty);

        unawaited(navigator.maybePop());
        await tester.pumpAndSettle();
        await tester.tap(find.text(sv.cookingExitConfirmLeave));
        await tester.pumpAndSettle();
        expect(results, [null]);
      },
    );

    testWidgets('the last step carries Klart, which returns finished', (
      tester,
    ) async {
      final results = <Object?>[];
      await openCooking(tester, results: results);
      await next(tester);
      await next(tester);

      expect(
        find.byKey(const ValueKey('cooking-mode-next-step')),
        findsNothing,
      );
      await tester.tap(find.text(sv.cookingDone));
      await tester.pumpAndSettle();

      expect(find.text(sv.cookingExitConfirmTitle), findsNothing);
      expect(results, [CookingModeExit.finished]);
    });

    testWidgets('a rotation keeps the step and the running timer', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1024, 1366);
      addTearDown(tester.view.reset);
      final effects = _FakeEffects();
      await openCooking(tester, effects: effects);
      expect(effects.calls, isNot(contains('lock')));
      await next(tester);
      timers.startTimer(
        id: 'step-1',
        duration: const Duration(minutes: 5),
        label: 'Blanda färsen.',
      );

      tester.view.physicalSize = const Size(1366, 1024);
      await tester.pumpAndSettle();

      expect(find.text(sv.cookingModeStepOf(2, 3)), findsOneWidget);
      expect(timers.isRunningFor('step-1'), isTrue);
      timers.resetTimer('step-1');
    });
  });
}
