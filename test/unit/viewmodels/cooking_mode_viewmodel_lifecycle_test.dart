// test/unit/viewmodels/cooking_mode_viewmodel_lifecycle_test.dart
//
// BUT-408: verifies [CookingModeViewModel.onEnter] broadcasts a session and
// [onExit] clears it. Uses the production ServiceLocator bridge pattern so
// the VM's `ServiceLocator.tryGet<CookingSessionModule>()` resolves to a
// test fake without touching RTDB.

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/cooking/cooking_session.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/persistence_service.dart';
import 'package:butlery/services/unified/operations/cooking/cooking_session_module.dart';
import 'package:butlery/viewmodels/cooking_mode_viewmodel.dart';

import '../../infrastructure/factories/recipe_factory.dart';

/// In-memory [CookingSessionModule] — records every call so tests can
/// inspect broadcast behaviour without reaching into RTDB.
class _FakeCookingSessionModule implements CookingSessionModule {
  final List<Recipe> startCalls = [];
  int endCalls = 0;

  @override
  Future<void> startSession(Recipe recipe) async {
    startCalls.add(recipe);
  }

  @override
  Future<void> endSession() async {
    endCalls++;
  }

  final List<({int current, int total})> stepCalls = [];

  @override
  Future<void> updateStep({
    required int currentStep,
    required int totalSteps,
  }) async {
    stepCalls.add((current: currentStep, total: totalSteps));
  }

  @override
  Stream<List<CookingSession>> watchGroupSessions(String groupId) =>
      const Stream.empty();
}

/// Stub PersistenceService — the VM's font-scale loader calls getInt/setInt.
class _StubPersistence implements PersistenceService {
  @override
  Future<int?> getInt(String key) async => null;

  @override
  Future<void> setInt(String key, int value) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeCookingSessionModule fakeModule;
  late Recipe testRecipe;

  setUpAll(() {
    // Bridge ServiceLocator to a test DIContainer so tryGet resolves.
    final testContainer = DIContainer();
    ServiceLocator.initialize(testContainer);
  });

  setUp(() {
    final getIt = GetIt.instance;

    // Register a stub persistence so the font-scale loader doesn't blow up.
    if (getIt.isRegistered<PersistenceService>()) {
      getIt.unregister<PersistenceService>();
    }
    getIt.registerSingleton<PersistenceService>(_StubPersistence());

    // Register the fake CookingSessionModule as the interface type —
    // matches DI registration in collaboration_module.dart.
    if (getIt.isRegistered<CookingSessionModule>()) {
      getIt.unregister<CookingSessionModule>();
    }
    fakeModule = _FakeCookingSessionModule();
    getIt.registerSingleton<CookingSessionModule>(fakeModule);

    testRecipe = RecipeFactory.build(
      id: 'recipe_test',
      title: 'Kycklinggryta',
      portions: 4,
      ingredients: ['2 dl mjol'],
      instructions: ['Step 1'],
    );
  });

  tearDown(() {
    final getIt = GetIt.instance;
    if (getIt.isRegistered<PersistenceService>()) {
      getIt.unregister<PersistenceService>();
    }
    if (getIt.isRegistered<CookingSessionModule>()) {
      getIt.unregister<CookingSessionModule>();
    }
  });

  group('CookingModeViewModel.onEnter', () {
    test('broadcasts the recipe via CookingSessionModule.startSession',
        () async {
      final vm = CookingModeViewModel(recipe: testRecipe);

      await vm.onEnter();

      expect(fakeModule.startCalls, hasLength(1));
      expect(fakeModule.startCalls.single.id, 'recipe_test');
      expect(fakeModule.startCalls.single.title, 'Kycklinggryta');
      expect(fakeModule.endCalls, 0);

      vm.dispose();
    });

    test('swallows module errors silently — cooking mode must not block',
        () async {
      // Swap in a throwing module.
      final getIt = GetIt.instance;
      getIt.unregister<CookingSessionModule>();
      getIt.registerSingleton<CookingSessionModule>(_ThrowingModule());

      final vm = CookingModeViewModel(recipe: testRecipe);

      // Should not rethrow.
      await expectLater(vm.onEnter(), completes);

      vm.dispose();
    });

    test('no-op when module is not registered', () async {
      final getIt = GetIt.instance;
      getIt.unregister<CookingSessionModule>();

      final vm = CookingModeViewModel(recipe: testRecipe);

      await expectLater(vm.onEnter(), completes);

      vm.dispose();
    });
  });

  group('CookingModeViewModel.onExit', () {
    test('clears the broadcast via CookingSessionModule.endSession', () async {
      final vm = CookingModeViewModel(recipe: testRecipe);

      await vm.onExit();

      expect(fakeModule.endCalls, 1);
      expect(fakeModule.startCalls, isEmpty);

      vm.dispose();
    });

    test('swallows module errors silently', () async {
      final getIt = GetIt.instance;
      getIt.unregister<CookingSessionModule>();
      getIt.registerSingleton<CookingSessionModule>(_ThrowingModule());

      final vm = CookingModeViewModel(recipe: testRecipe);

      await expectLater(vm.onExit(), completes);

      vm.dispose();
    });
  });

  group('Full lifecycle', () {
    test('onEnter then onExit produces one start + one end call', () async {
      final vm = CookingModeViewModel(recipe: testRecipe);

      await vm.onEnter();
      await vm.onExit();

      expect(fakeModule.startCalls, hasLength(1));
      expect(fakeModule.endCalls, 1);

      vm.dispose();
    });
  });
}

class _ThrowingModule implements CookingSessionModule {
  @override
  Future<void> startSession(Recipe recipe) async {
    throw StateError('boom');
  }

  @override
  Future<void> endSession() async {
    throw StateError('boom');
  }

  @override
  Future<void> updateStep({
    required int currentStep,
    required int totalSteps,
  }) async {
    throw StateError('boom');
  }

  @override
  Stream<List<CookingSession>> watchGroupSessions(String groupId) =>
      const Stream.empty();
}
