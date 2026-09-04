// test/unit/viewmodels/menu/menu_state_manager_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/viewmodels/menu/menu_state_manager.dart';
import 'package:butlery/models/recipe_unified.dart';

import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/di/test_service_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MenuStateManager stateManager;

  setUpAll(() async {
    await TestServiceLocator.initialize();
  });

  setUp(() async {
    stateManager = MenuStateManager();
  });

  tearDown(() async {
    stateManager.dispose();
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
  });

  Map<String, List<Recipe>> createTestMenu() {
    return {
      'Monday': [
        RecipeFactory.build(id: 'recipe_1', title: 'Monday Pasta'),
      ],
      'Tuesday': [
        RecipeFactory.build(id: 'recipe_2', title: 'Tuesday Soup'),
      ],
      'Wednesday': [],
    };
  }

  group('MenuStateManager - Initialization', () {
    test('should initialize with default state', () {
      expect(stateManager.menu, isEmpty);
      expect(stateManager.isGenerating, isFalse);
      expect(stateManager.error, isNull);
      expect(stateManager.hasError, isFalse);
      expect(stateManager.hasMenu, isFalse);
      expect(stateManager.lastPrompt, isEmpty);
      expect(stateManager.savedMenus, isEmpty);
      expect(stateManager.totalRecipeCount, equals(0));
    });
  });

  group('MenuStateManager - Menu State Management', () {
    test('should set menu correctly', () {
      final menu = createTestMenu();

      stateManager.setMenu(menu);

      expect(stateManager.menu, equals(menu));
      expect(stateManager.hasMenu, isTrue);
      expect(stateManager.totalRecipeCount, equals(2));
    });

    test('should update menu section', () {
      final menu = createTestMenu();
      stateManager.setMenu(menu);

      final newRecipes = [
        RecipeFactory.build(id: 'recipe_3', title: 'New Wednesday Recipe'),
        RecipeFactory.build(id: 'recipe_4', title: 'Another Wednesday Recipe'),
      ];

      stateManager.updateMenuSection('Wednesday', newRecipes);

      expect(stateManager.menu['Wednesday'], equals(newRecipes));
      expect(stateManager.totalRecipeCount, equals(4));
    });

    test('should clear menu', () {
      final menu = createTestMenu();
      stateManager.setMenu(menu);
      stateManager.setLastPrompt('test prompt');
      stateManager.setError('test error');

      stateManager.clearMenu();

      expect(stateManager.menu, isEmpty);
      expect(stateManager.hasMenu, isFalse);
      expect(stateManager.lastPrompt, isEmpty);
      expect(stateManager.error, isNull);
      expect(stateManager.totalRecipeCount, equals(0));
    });

    test('should load menu from data', () {
      final menu = createTestMenu();
      const prompt = 'vegetarian weekly menu';

      stateManager.loadMenuFromData(menu: menu, lastPrompt: prompt);

      expect(stateManager.menu, equals(menu));
      expect(stateManager.lastPrompt, equals(prompt));
      expect(stateManager.error, isNull);
      expect(stateManager.hasMenu, isTrue);
    });

    test('should return immutable menu copy', () {
      final menu = createTestMenu();
      stateManager.setMenu(menu);

      final menuCopy = stateManager.menu;

      // Try to modify the returned menu - should throw or have no effect
      expect(() => menuCopy['Thursday'] = [], throwsUnsupportedError);
    });
  });

  group('MenuStateManager - Generation State Management', () {
    test('should set generating state', () {
      expect(stateManager.isGenerating, isFalse);

      stateManager.setGenerating(true);

      expect(stateManager.isGenerating, isTrue);

      stateManager.setGenerating(false);

      expect(stateManager.isGenerating, isFalse);
    });

    test('should track generation progress', () {
      int notificationCount = 0;
      stateManager.addListener(() => notificationCount++);

      stateManager.setGenerating(true);
      expect(notificationCount, equals(1));

      stateManager.setGenerating(false);
      expect(notificationCount, equals(2));
    });
  });

  group('MenuStateManager - Error Management', () {
    test('should set and clear error', () {
      const errorMessage = 'Generation failed';

      stateManager.setError(errorMessage);

      expect(stateManager.error, equals(errorMessage));
      expect(stateManager.hasError, isTrue);

      stateManager.clearError();

      expect(stateManager.error, isNull);
      expect(stateManager.hasError, isFalse);
    });

    test('should handle operation error', () {
      const operation = 'Menu Generation';
      final error = Exception('Network error');

      stateManager.handleOperationError(operation, error);

      // Production sanitizes via sanitizeErrorForUser — surfaces a localized
      // user-facing message (Swedish), not the operation name or raw
      // exception text. The previous assertion leaked implementation
      // details that the sanitizer was added to hide.
      expect(stateManager.hasError, isTrue);
      expect(stateManager.error, isNotNull);
      expect(stateManager.error, isNotEmpty);
    });

    test('should clear error after success', () {
      stateManager.setError('Previous error');
      expect(stateManager.hasError, isTrue);

      stateManager.clearErrorAfterSuccess();

      expect(stateManager.hasError, isFalse);
      expect(stateManager.error, isNull);
    });

    test('should not clear error if no error exists', () {
      expect(stateManager.hasError, isFalse);

      // Should not throw or cause issues
      stateManager.clearErrorAfterSuccess();

      expect(stateManager.hasError, isFalse);
    });
  });

  group('MenuStateManager - Prompt Management', () {
    test('should set and get last prompt', () {
      const prompt = 'vegetarian weekly menu for family';

      stateManager.setLastPrompt(prompt);

      expect(stateManager.lastPrompt, equals(prompt));
    });

    test('should validate prompt', () {
      expect(stateManager.validatePrompt(''), isFalse);
      expect(stateManager.validatePrompt('   '), isFalse);
      expect(stateManager.validatePrompt('valid prompt'), isTrue);
      expect(stateManager.validatePrompt('  valid prompt  '), isTrue);
    });
  });

  group('MenuStateManager - Saved Menus Management', () {
    test('should set saved menus', () {
      final savedMenus = [
        SavedMenuInfo(
          key: 'menu_1',
          name: 'Weekly Menu 1',
          savedDate: DateTime.now(),
          recipeCount: 5,
          comment: 'Great family menu',
        ),
        SavedMenuInfo(
          key: 'menu_2',
          name: 'Vegetarian Menu',
          savedDate: DateTime.now(),
          recipeCount: 3,
          comment: 'Healthy options',
        ),
      ];

      stateManager.setSavedMenus(savedMenus);

      expect(stateManager.savedMenus, equals(savedMenus));
      expect(stateManager.savedMenus.length, equals(2));
    });

    test('should return immutable saved menus copy', () {
      final savedMenus = [
        SavedMenuInfo(
          key: 'menu_1',
          name: 'Test Menu',
          savedDate: DateTime.now(),
          recipeCount: 3,
          comment: 'Test comment',
        ),
      ];

      stateManager.setSavedMenus(savedMenus);
      final menusCopy = stateManager.savedMenus;

      // Try to modify the returned list - should throw or have no effect
      expect(
        () => menusCopy.add(
          SavedMenuInfo(
            key: 'menu_2',
            name: 'Another Menu',
            savedDate: DateTime.now(),
            recipeCount: 2,
            comment: 'Another comment',
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('MenuStateManager - State Validation', () {
    test('should validate menu for saving', () {
      expect(stateManager.validateMenuForSaving(), isFalse);

      final menu = createTestMenu();
      stateManager.setMenu(menu);

      expect(stateManager.validateMenuForSaving(), isTrue);
    });

    test('should validate empty menu', () {
      stateManager.setMenu({});

      expect(stateManager.validateMenuForSaving(), isFalse);
      expect(stateManager.hasMenu, isFalse);
    });

    test('should calculate total recipe count correctly', () {
      final menu = {
        'Monday': [
          RecipeFactory.build(),
          RecipeFactory.build(),
        ],
        'Tuesday': [
          RecipeFactory.build(),
        ],
        'Wednesday': <Recipe>[],
        'Thursday': [
          RecipeFactory.build(),
          RecipeFactory.build(),
          RecipeFactory.build(),
        ],
      };

      stateManager.setMenu(menu);

      expect(stateManager.totalRecipeCount, equals(6));
    });
  });

  group('MenuStateManager - Listener Notifications', () {
    test('should notify listeners on menu changes', () {
      int notificationCount = 0;
      stateManager.addListener(() => notificationCount++);

      stateManager.setMenu(createTestMenu());
      expect(notificationCount, equals(1));

      stateManager.updateMenuSection('Friday', [RecipeFactory.build()]);
      expect(notificationCount, equals(2));

      stateManager.clearMenu();
      expect(notificationCount, equals(3));
    });

    test('should notify listeners on error changes', () {
      int notificationCount = 0;
      stateManager.addListener(() => notificationCount++);

      stateManager.setError('Test error');
      expect(notificationCount, equals(1));

      stateManager.clearError();
      expect(notificationCount, equals(2));
    });

    test('should notify listeners on generating state changes', () {
      int notificationCount = 0;
      stateManager.addListener(() => notificationCount++);

      stateManager.setGenerating(true);
      expect(notificationCount, equals(1));

      stateManager.setGenerating(false);
      expect(notificationCount, equals(2));
    });

    test('should notify listeners on saved menus changes', () {
      int notificationCount = 0;
      stateManager.addListener(() => notificationCount++);

      final savedMenus = [
        SavedMenuInfo(
          key: 'menu_1',
          name: 'Test Menu',
          savedDate: DateTime.now(),
          recipeCount: 3,
          comment: 'Test',
        ),
      ];

      stateManager.setSavedMenus(savedMenus);
      expect(notificationCount, equals(1));
    });
  });

  group('MenuStateManager - Edge Cases', () {
    test('should handle null values gracefully', () {
      stateManager.setError(null);
      expect(stateManager.error, isNull);
      expect(stateManager.hasError, isFalse);

      stateManager.setLastPrompt('');
      expect(stateManager.lastPrompt, isEmpty);
    });

    test('should handle large menus', () {
      final largeMenu = <String, List<Recipe>>{};

      // Create a menu with many sections and recipes
      for (int i = 0; i < 10; i++) {
        final recipes = <Recipe>[];
        for (int j = 0; j < 20; j++) {
          recipes.add(RecipeFactory.build(id: 'recipe_${i}_$j'));
        }
        largeMenu['Section_$i'] = recipes;
      }

      stateManager.setMenu(largeMenu);

      expect(stateManager.hasMenu, isTrue);
      expect(stateManager.totalRecipeCount, equals(200));
      expect(stateManager.menu.keys.length, equals(10));
    });

    test('should handle disposal correctly', () {
      // Create separate instance to avoid tearDown conflicts
      final separateManager = MenuStateManager();
      final menu = createTestMenu();
      separateManager.setMenu(menu);

      separateManager.dispose();

      // BUT-1641 CHANGED THIS. It used to assert `throwsFlutterError` — the
      // crash from ChangeNotifier's own assert — which pinned the defect as
      // though it were the contract. A post-dispose setter now notifies nobody
      // and does not throw (the field itself is still assigned): the caller
      // reaching here is the owning ViewModel's async continuation finishing
      // after the screen closed, and crashing the app is the wrong answer.
      expect(() => separateManager.setMenu({}), returnsNormally);
      expect(separateManager.isStreamDisposed, isTrue);
    });
  });

  group('SavedMenuInfo - Data Class', () {
    test('should create SavedMenuInfo with all properties', () {
      final savedDate = DateTime.now();
      final menuInfo = SavedMenuInfo(
        key: 'test_menu',
        name: 'Test Menu',
        savedDate: savedDate,
        recipeCount: 5,
        comment: 'Great menu',
        originalAuthor: 'Chef Anna',
        isModified: true,
        isOwned: false,
        firebaseId: 'firebase_123',
      );

      expect(menuInfo.key, equals('test_menu'));
      expect(menuInfo.name, equals('Test Menu'));
      expect(menuInfo.savedDate, equals(savedDate));
      expect(menuInfo.recipeCount, equals(5));
      expect(menuInfo.comment, equals('Great menu'));
      expect(menuInfo.originalAuthor, equals('Chef Anna'));
      expect(menuInfo.isModified, isTrue);
      expect(menuInfo.isOwned, isFalse);
      expect(menuInfo.firebaseId, equals('firebase_123'));
    });

    test('should have correct default values', () {
      final menuInfo = SavedMenuInfo(
        key: 'test_menu',
        name: 'Test Menu',
        savedDate: DateTime.now(),
        recipeCount: 3,
        comment: 'Test comment',
      );

      expect(menuInfo.originalAuthor, isNull);
      expect(menuInfo.isModified, isFalse);
      expect(menuInfo.isOwned, isTrue);
      expect(menuInfo.firebaseId, isNull);
    });

    test('should return correct attribution color types', () {
      final baseDate = DateTime.now();

      // Owned and modified
      final ownedModified = SavedMenuInfo(
        key: 'menu_1',
        name: 'Menu 1',
        savedDate: baseDate,
        recipeCount: 3,
        comment: 'Test',
        isOwned: true,
        isModified: true,
      );
      expect(ownedModified.attributionColorType, equals('modified'));

      // Owned but not modified
      final owned = SavedMenuInfo(
        key: 'menu_2',
        name: 'Menu 2',
        savedDate: baseDate,
        recipeCount: 3,
        comment: 'Test',
        isOwned: true,
        isModified: false,
      );
      expect(owned.attributionColorType, equals('owned'));

      // Not owned (shared)
      final shared = SavedMenuInfo(
        key: 'menu_3',
        name: 'Menu 3',
        savedDate: baseDate,
        recipeCount: 3,
        comment: 'Test',
        isOwned: false,
        originalAuthor: 'Friend',
      );
      expect(shared.attributionColorType, equals('shared'));
    });

    test('should return correct status icons', () {
      final baseDate = DateTime.now();

      // Owned and modified
      final ownedModified = SavedMenuInfo(
        key: 'menu_1',
        name: 'Menu 1',
        savedDate: baseDate,
        recipeCount: 3,
        comment: 'Test',
        isOwned: true,
        isModified: true,
      );
      expect(ownedModified.statusIcon, equals('autoFixHigh'));

      // Owned but not modified
      final owned = SavedMenuInfo(
        key: 'menu_2',
        name: 'Menu 2',
        savedDate: baseDate,
        recipeCount: 3,
        comment: 'Test',
        isOwned: true,
        isModified: false,
      );
      expect(owned.statusIcon, equals('restaurantMenu'));

      // Not owned (shared)
      final shared = SavedMenuInfo(
        key: 'menu_3',
        name: 'Menu 3',
        savedDate: baseDate,
        recipeCount: 3,
        comment: 'Test',
        isOwned: false,
      );
      expect(shared.statusIcon, equals('person'));
    });
  });

  // BUT-1641: the guard, and the reason it is a no-op rather than a throw.
  //
  // The reaching path is the owning ViewModel's own public async method: it
  // resumes after an `await` and calls a setter here without re-checking its
  // own disposed flag. `ChangeNotifier.notifyListeners` asserts against a
  // disposed receiver, and that assert is LIVE in debug and test builds, so
  // before this guard the symptom was a developer-visible crash on any screen
  // left mid-operation. BUT-1628 guarded the parents and judged the leaves
  // covered; that was measured false on 2026-09-04.
  //
  // A local instance, deliberately: the shared fixture is disposed again in
  // tearDown, and ChangeNotifier refuses a second dispose.
  group('MenuStateManager - disposal guard (BUT-1641)', () {
    test(
      'a setter arriving after dispose notifies nobody and does not throw',
      () {
        final subject = MenuStateManager();
        var notifications = 0;
        subject.addListener(() => notifications++);

        subject.setError('varm');
        expect(
          notifications,
          1,
          reason: 'positive control: the listener is wired',
        );

        subject.dispose();
        expect(subject.isStreamDisposed, isTrue);

        // The late continuation. Without the guard this throws a FlutterError
        // from the assert inside notifyListeners.
        expect(() => subject.setError('sent'), returnsNormally);
      },
    );
  });
}
