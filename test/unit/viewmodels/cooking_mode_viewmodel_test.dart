// test/unit/viewmodels/cooking_mode_viewmodel_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';
import 'package:butlery/viewmodels/cooking_mode_viewmodel.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/persistence_service.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';

import '../../infrastructure/factories/recipe_factory.dart';

class MockPersistenceService extends Mock implements PersistenceService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockPersistenceService mockPersistence;
  late Recipe testRecipe;

  setUpAll(() {
    // Production ServiceLocator bridge — CookingModeViewModel uses ServiceLocator.get<>()
    final testContainer = DIContainer();
    ServiceLocator.initialize(testContainer);
  });

  setUp(() {
    mockPersistence = MockPersistenceService();

    // Register mock PersistenceService with GetIt (shared by DIContainer)
    final getIt = GetIt.instance;
    if (getIt.isRegistered<PersistenceService>()) {
      getIt.unregister<PersistenceService>();
    }
    getIt.registerSingleton<PersistenceService>(mockPersistence);

    // Default: no saved font scale
    when(() => mockPersistence.getInt(any())).thenAnswer((_) async => null);
    when(() => mockPersistence.setInt(any(), any())).thenAnswer((_) async {});

    testRecipe = RecipeFactory.build(
      id: 'recipe-1',
      title: 'Test Recipe',
      portions: 4,
      ingredients: ['2 dl mjol', '3 st agg', '1 tsk salt'],
      instructions: ['Step 1', 'Step 2', 'Step 3'],
    );
  });

  tearDown(() {
    final getIt = GetIt.instance;
    if (getIt.isRegistered<PersistenceService>()) {
      getIt.unregister<PersistenceService>();
    }
  });

  group('CookingModeViewModel - Initial State', () {
    test('should initialize with recipe portions and step 0', () {
      final vm = CookingModeViewModel(recipe: testRecipe);

      expect(vm.currentPortions, 4);
      expect(vm.originalPortions, 4);
      expect(vm.currentStepIndex, 0);
      expect(vm.totalSteps, 3);
      expect(vm.title, 'Test Recipe');
      expect(vm.scaleFactor, 1.0);

      vm.dispose();
    });

    test('should default portions to 1 when recipe has no portions', () {
      final noPortionsRecipe = RecipeFactory.build(
        id: 'np-1',
        portions: null,
        instructions: ['Step 1'],
      );
      final vm = CookingModeViewModel(recipe: noPortionsRecipe);

      expect(vm.currentPortions, 1);
      expect(vm.originalPortions, 1);

      vm.dispose();
    });

    test('should load font scale from persistence on init', () async {
      when(() => mockPersistence.getInt('butlery_cooking_font_scale'))
          .thenAnswer((_) async => 2); // index 2 = 1.5

      final vm = CookingModeViewModel(recipe: testRecipe);

      // Allow async _loadFontScale to complete
      await Future.delayed(Duration.zero);

      expect(vm.fontScale, 1.5);

      vm.dispose();
    });

    test('should default to fontScale 1.0 when persistence returns null',
        () async {
      when(() => mockPersistence.getInt(any())).thenAnswer((_) async => null);

      final vm = CookingModeViewModel(recipe: testRecipe);
      await Future.delayed(Duration.zero);

      expect(vm.fontScale, 1.0);

      vm.dispose();
    });
  });

  group('CookingModeViewModel - Step Navigation', () {
    test('should advance to next step', () {
      final vm = CookingModeViewModel(recipe: testRecipe);
      int notifyCount = 0;
      vm.addListener(() => notifyCount++);

      vm.nextStep();

      expect(vm.currentStepIndex, 1);
      expect(vm.hasPreviousStep, true);
      expect(vm.hasNextStep, true);
      expect(notifyCount, greaterThanOrEqualTo(1));

      vm.dispose();
    });

    test('should go back to previous step', () {
      final vm = CookingModeViewModel(recipe: testRecipe);
      vm.nextStep();
      vm.nextStep();

      vm.previousStep();

      expect(vm.currentStepIndex, 1);

      vm.dispose();
    });

    test('should not go below step 0', () {
      // Behavior: pressing "previous" at step 0 does nothing
      final vm = CookingModeViewModel(recipe: testRecipe);
      int notifyCount = 0;
      vm.addListener(() => notifyCount++);

      vm.previousStep();

      expect(vm.currentStepIndex, 0);
      expect(vm.hasPreviousStep, false);
      expect(notifyCount, 0);

      vm.dispose();
    });

    test('should not go above max step', () {
      // Behavior: pressing "next" at the last step does nothing
      final vm = CookingModeViewModel(recipe: testRecipe);
      vm.nextStep(); // 1
      vm.nextStep(); // 2 (last)

      int notifyCount = 0;
      vm.addListener(() => notifyCount++);

      vm.nextStep(); // should be no-op

      expect(vm.currentStepIndex, 2);
      expect(vm.hasNextStep, false);
      expect(notifyCount, 0);

      vm.dispose();
    });

    test('should jump to a specific step with goToStep', () {
      final vm = CookingModeViewModel(recipe: testRecipe);

      vm.goToStep(2);

      expect(vm.currentStepIndex, 2);
      expect(vm.hasNextStep, false);
      expect(vm.hasPreviousStep, true);

      vm.dispose();
    });

    test('should ignore goToStep with out-of-range index', () {
      final vm = CookingModeViewModel(recipe: testRecipe);

      vm.goToStep(-1);
      expect(vm.currentStepIndex, 0);

      vm.goToStep(100);
      expect(vm.currentStepIndex, 0);

      vm.dispose();
    });
  });

  group('CookingModeViewModel - Portion Scaling', () {
    test('should update portions within valid range', () {
      final vm = CookingModeViewModel(recipe: testRecipe);
      int notifyCount = 0;
      vm.addListener(() => notifyCount++);

      vm.updatePortions(8);

      expect(vm.currentPortions, 8);
      expect(vm.scaleFactor, 2.0);
      expect(notifyCount, greaterThanOrEqualTo(1));

      vm.dispose();
    });

    test('should reject portions below minimum (1)', () {
      // Behavior: 0 or negative portions are invalid
      final vm = CookingModeViewModel(recipe: testRecipe);

      vm.updatePortions(0);

      expect(vm.currentPortions, 4); // unchanged

      vm.dispose();
    });

    test('should reject portions above maximum (50)', () {
      final vm = CookingModeViewModel(recipe: testRecipe);

      vm.updatePortions(51);

      expect(vm.currentPortions, 4); // unchanged

      vm.dispose();
    });

    test('should accept boundary values (1 and 50)', () {
      final vm = CookingModeViewModel(recipe: testRecipe);

      vm.updatePortions(1);
      expect(vm.currentPortions, 1);

      vm.updatePortions(50);
      expect(vm.currentPortions, 50);

      vm.dispose();
    });

    test('should not notify when portions unchanged', () {
      final vm = CookingModeViewModel(recipe: testRecipe);
      int notifyCount = 0;
      vm.addListener(() => notifyCount++);

      vm.updatePortions(4); // same as original

      expect(notifyCount, 0);

      vm.dispose();
    });

    test('should rescale ingredients when portions change', () {
      final vm = CookingModeViewModel(recipe: testRecipe);

      // Original ingredients are '2 dl mjol', '3 st agg', '1 tsk salt'
      // After doubling portions: ingredients should change
      vm.updatePortions(8);

      expect(vm.scaledIngredients, isNotEmpty);
      // Just verify it changed from original — the exact scaling is PortionScalerLogic's responsibility
      expect(vm.scaledIngredients, isNot(equals(testRecipe.ingredients)));

      vm.dispose();
    });
  });

  group('CookingModeViewModel - Font Scale Cycling', () {
    test('should cycle through font scale options: 1.0 -> 1.25 -> 1.5 -> 1.0',
        () {
      final vm = CookingModeViewModel(recipe: testRecipe);

      expect(vm.fontScale, 1.0);

      vm.cycleFontScale();
      expect(vm.fontScale, 1.25);

      vm.cycleFontScale();
      expect(vm.fontScale, 1.5);

      vm.cycleFontScale();
      expect(vm.fontScale, 1.0); // wraps around

      vm.dispose();
    });

    test('should persist font scale index to PersistenceService', () {
      final vm = CookingModeViewModel(recipe: testRecipe);

      vm.cycleFontScale(); // 1.0 -> 1.25 (index 1)

      verify(() => mockPersistence.setInt('butlery_cooking_font_scale', 1))
          .called(1);

      vm.dispose();
    });

    test('should notify listeners on font scale change', () {
      final vm = CookingModeViewModel(recipe: testRecipe);
      int notifyCount = 0;
      vm.addListener(() => notifyCount++);

      vm.cycleFontScale();

      expect(notifyCount, greaterThanOrEqualTo(1));

      vm.dispose();
    });
  });

  group('CookingModeViewModel - Computed Properties', () {
    test('should expose recipe instructions directly', () {
      final vm = CookingModeViewModel(recipe: testRecipe);

      expect(vm.instructions, ['Step 1', 'Step 2', 'Step 3']);

      vm.dispose();
    });

    test('should report correct hasNextStep and hasPreviousStep', () {
      final singleStepRecipe = RecipeFactory.build(
        id: 'single-1',
        instructions: ['Only step'],
      );
      final vm = CookingModeViewModel(recipe: singleStepRecipe);

      expect(vm.hasNextStep, false);
      expect(vm.hasPreviousStep, false);
      expect(vm.totalSteps, 1);

      vm.dispose();
    });

    test('should calculate scale factor correctly', () {
      final vm = CookingModeViewModel(recipe: testRecipe);

      vm.updatePortions(2);
      expect(vm.scaleFactor, 0.5);

      vm.updatePortions(12);
      expect(vm.scaleFactor, 3.0);

      vm.dispose();
    });
  });
}
