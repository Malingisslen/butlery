/// Unit tests for MenuStorage — Firestore-based menu persistence
///
/// Tests menu storage operations including:
/// - Save/load/delete via Firestore
/// - Menu validation (name, data)
/// - SavedMenuData serialization
/// - Edge cases and error handling
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/viewmodels/menu/menu_storage.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/factories/recipe_factory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MenuStorage menuStorage;
  late FakePermissionService mockPermissionService;
  late FakeFirestoreRepository mockFirestoreRepo;

  const testUserId = 'test-user-123';
  const testUserName = 'Test User';

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  setUp(() async {
    await TestServiceLocator.reset();
    await TestServiceLocator.initialize();

    // Bridge production ServiceLocator (MenuStorage uses it internally)
    production.ServiceLocator.initialize(DIContainer());

    // Configure permission service with authenticated user
    mockPermissionService = FakePermissionService();
    mockPermissionService.setPermissionState(
      currentUserId: testUserId,
      userDisplayName: testUserName,
      isAuthenticated: true,
      defaultHasPermission: true,
    );
    TestServiceLocator.registerMock<PermissionService>(mockPermissionService);

    // Get the Firestore repository from TestServiceLocator
    mockFirestoreRepo = TestServiceLocator.get<FirestoreRepository>()
        as FakeFirestoreRepository;

    // Create MenuStorage with injected repository
    menuStorage = MenuStorage(firestoreRepository: mockFirestoreRepo);
  });

  tearDown(() async {
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  Map<String, List<Recipe>> createTestMenu() {
    return {
      'Monday': [RecipeFactory.build(title: 'Monday Recipe')],
      'Tuesday': [RecipeFactory.build(title: 'Tuesday Recipe')],
      'Wednesday': [RecipeFactory.build(title: 'Wednesday Recipe')],
    };
  }

  group('MenuStorage - Save Operations', () {
    test('should save menu to Firestore and return document ID', () async {
      final menu = createTestMenu();

      final docId = await menuStorage.saveMenu(
        menuName: 'Weekly Menu',
        comment: 'Great for the week',
        menu: menu,
        lastPrompt: 'vegetarian weekly',
        totalRecipeCount: 3,
      );

      expect(docId, isNotEmpty);
    });

    test('should save menu with trimmed name and comment', () async {
      final menu = createTestMenu();

      final docId = await menuStorage.saveMenu(
        menuName: '  Trimmed Menu  ',
        comment: '  Trimmed comment  ',
        menu: menu,
        lastPrompt: 'test',
        totalRecipeCount: 3,
      );

      expect(docId, isNotEmpty);
    });

    test('should generate unique IDs for multiple saves', () async {
      final menu = createTestMenu();

      final id1 = await menuStorage.saveMenu(
        menuName: 'Menu A',
        comment: 'A',
        menu: menu,
        lastPrompt: 'a',
        totalRecipeCount: 3,
      );

      final id2 = await menuStorage.saveMenu(
        menuName: 'Menu B',
        comment: 'B',
        menu: menu,
        lastPrompt: 'b',
        totalRecipeCount: 3,
      );

      expect(id1, isNot(equals(id2)));
    });
  });

  group('MenuStorage - Load Operations', () {
    test('should load saved menu by document ID', () async {
      final menu = createTestMenu();

      final docId = await menuStorage.saveMenu(
        menuName: 'Loadable Menu',
        comment: 'Comment',
        menu: menu,
        lastPrompt: 'prompt',
        totalRecipeCount: 3,
      );

      final loaded = await menuStorage.loadMenuByKey(docId);

      expect(loaded, isNotNull);
      expect(loaded!.name, equals('Loadable Menu'));
      expect(loaded.menu.keys.length, equals(3));
    });

    test('should return null for non-existent document', () async {
      final loaded = await menuStorage.loadMenuByKey('nonexistent_id');
      expect(loaded, isNull);
    });

    test('should load user menus from Firestore', () async {
      final menu = createTestMenu();

      await menuStorage.saveMenu(
        menuName: 'Menu 1',
        comment: 'c1',
        menu: menu,
        lastPrompt: 'p1',
        totalRecipeCount: 3,
      );
      await menuStorage.saveMenu(
        menuName: 'Menu 2',
        comment: 'c2',
        menu: menu,
        lastPrompt: 'p2',
        totalRecipeCount: 3,
      );

      final userMenus = await menuStorage.loadUserMenus();

      expect(userMenus.length, equals(2));
      expect(userMenus.any((m) => m.name == 'Menu 1'), isTrue);
      expect(userMenus.any((m) => m.name == 'Menu 2'), isTrue);
    });

    test('should return empty list when no menus exist', () async {
      final userMenus = await menuStorage.loadUserMenus();
      expect(userMenus, isEmpty);
    });
  });

  group('MenuStorage - Delete Operations', () {
    test('should delete menu by document ID', () async {
      final menu = createTestMenu();

      final docId = await menuStorage.saveMenu(
        menuName: 'To Delete',
        comment: '',
        menu: menu,
        lastPrompt: '',
        totalRecipeCount: 3,
      );

      final deleted = await menuStorage.deleteMenuByKey(docId);
      expect(deleted, isTrue);

      final loaded = await menuStorage.loadMenuByKey(docId);
      expect(loaded, isNull);
    });

    test('should return false for non-existent document', () async {
      final deleted = await menuStorage.deleteMenuByKey('nonexistent_id');
      expect(deleted, isFalse);
    });
  });

  group('MenuStorage - Mark Modified', () {
    test('should return false for non-existent document', () async {
      final result = await menuStorage.markMenuAsModified('nonexistent');
      expect(result, isFalse);
    });
  });

  group('MenuStorage - Imported Menu Stub', () {
    test('should return null for imported menu (stub)', () async {
      final loaded = await menuStorage.loadImportedMenuByKey('any_key');
      expect(loaded, isNull);
    });
  });

  group('MenuStorage - Validation', () {
    test('should validate menu names correctly', () {
      expect(menuStorage.validateMenuName('Valid Name'), isTrue);
      expect(menuStorage.validateMenuName('  Valid Name  '), isTrue);
      expect(menuStorage.validateMenuName(''), isFalse);
      expect(menuStorage.validateMenuName('   '), isFalse);
      expect(menuStorage.validateMenuName('x' * 100), isTrue);
      expect(menuStorage.validateMenuName('x' * 101), isFalse);
    });

    test('should validate menu data correctly', () {
      final validMenu = createTestMenu();
      final emptyMenu = <String, List<Recipe>>{};
      final menuWithEmptySection = <String, List<Recipe>>{
        'Monday': [RecipeFactory.build()],
        'Tuesday': <Recipe>[],
      };

      expect(menuStorage.validateMenuData(validMenu), isTrue);
      expect(menuStorage.validateMenuData(emptyMenu), isFalse);
      expect(menuStorage.validateMenuData(menuWithEmptySection), isFalse);
    });

    test('should handle validation edge cases', () {
      final singleRecipeMenu = <String, List<Recipe>>{
        'Monday': [RecipeFactory.build()],
      };
      final allEmptySections = <String, List<Recipe>>{
        'Monday': <Recipe>[],
        'Tuesday': <Recipe>[],
      };

      expect(menuStorage.validateMenuData(singleRecipeMenu), isTrue);
      expect(menuStorage.validateMenuData(allEmptySections), isFalse);
    });
  });

  group('SavedMenuData', () {
    test('should create with all properties', () {
      final now = DateTime.now();
      final menu = createTestMenu();

      final data = SavedMenuData(
        name: 'Test Menu',
        savedDate: now,
        recipeCount: 5,
        menu: menu,
        lastPrompt: 'test prompt',
        comment: 'test comment',
        originalAuthor: 'Author',
        originalAuthorId: 'author_123',
        isModified: true,
        firebaseId: 'fb_456',
      );

      expect(data.name, equals('Test Menu'));
      expect(data.savedDate, equals(now));
      expect(data.recipeCount, equals(5));
      expect(data.lastPrompt, equals('test prompt'));
      expect(data.comment, equals('test comment'));
      expect(data.originalAuthor, equals('Author'));
      expect(data.originalAuthorId, equals('author_123'));
      expect(data.isModified, isTrue);
      expect(data.firebaseId, equals('fb_456'));
    });

    test('should have correct default values', () {
      final data = SavedMenuData(
        name: 'Test',
        savedDate: DateTime.now(),
        recipeCount: 3,
        menu: createTestMenu(),
        lastPrompt: 'prompt',
        comment: 'comment',
      );

      expect(data.originalAuthor, isNull);
      expect(data.originalAuthorId, isNull);
      expect(data.isModified, isFalse);
      expect(data.firebaseId, isNull);
    });

    test('should determine ownership correctly', () {
      final menu = createTestMenu();

      final ownedMenu = SavedMenuData(
        name: 'Owned',
        savedDate: DateTime.now(),
        recipeCount: 3,
        menu: menu,
        lastPrompt: '',
        comment: '',
      );

      final sharedMenu = SavedMenuData(
        name: 'Shared',
        savedDate: DateTime.now(),
        recipeCount: 3,
        menu: menu,
        lastPrompt: '',
        comment: '',
        originalAuthor: 'Friend',
      );

      expect(ownedMenu.isOwned, isTrue);
      expect(sharedMenu.isOwned, isFalse);
    });

    test('should serialize to JSON correctly', () {
      final now = DateTime.now();
      final menu = createTestMenu();

      final data = SavedMenuData(
        name: 'JSON Test',
        savedDate: now,
        recipeCount: 3,
        menu: menu,
        lastPrompt: 'json prompt',
        comment: 'json comment',
        originalAuthor: 'JSON Author',
        isModified: true,
      );

      final json = data.toJson();

      expect(json['name'], equals('JSON Test'));
      expect(json['savedDate'], equals(now.millisecondsSinceEpoch));
      expect(json['recipeCount'], equals(3));
      expect(json['lastPrompt'], equals('json prompt'));
      expect(json['comment'], equals('json comment'));
      expect(json['originalAuthor'], equals('JSON Author'));
      expect(json['isModified'], isTrue);
      expect(json['menu'], isA<Map<String, dynamic>>());
    });

    test('should roundtrip through JSON correctly', () {
      final now = DateTime.now();
      final menu = createTestMenu();

      final original = SavedMenuData(
        name: 'Roundtrip',
        savedDate: now,
        recipeCount: 3,
        menu: menu,
        lastPrompt: 'prompt',
        comment: 'comment',
        originalAuthor: 'Author',
        isModified: true,
      );

      final json = original.toJson();
      final restored = SavedMenuData.fromJson(json);

      expect(restored.name, equals(original.name));
      expect(restored.savedDate.millisecondsSinceEpoch,
          equals(original.savedDate.millisecondsSinceEpoch));
      expect(restored.recipeCount, equals(original.recipeCount));
      expect(restored.lastPrompt, equals(original.lastPrompt));
      expect(restored.comment, equals(original.comment));
      expect(restored.originalAuthor, equals(original.originalAuthor));
      expect(restored.isModified, equals(original.isModified));
      expect(restored.menu.keys.length, equals(3));
    });

    test('should handle malformed JSON gracefully', () {
      final malformed = <String, dynamic>{
        'name': null,
        'savedDate': null,
        'recipeCount': null,
        'menu': null,
      };

      final data = SavedMenuData.fromJson(malformed);

      expect(data.name, equals(''));
      expect(data.savedDate, isA<DateTime>());
      expect(data.recipeCount, equals(0));
      expect(data.menu, isEmpty);
    });

    test('should handle empty menu in JSON', () {
      final data = SavedMenuData(
        name: 'Empty',
        savedDate: DateTime.now(),
        recipeCount: 0,
        menu: <String, List<Recipe>>{},
        lastPrompt: '',
        comment: '',
      );

      final json = data.toJson();
      final restored = SavedMenuData.fromJson(json);

      expect(restored.menu, isEmpty);
      expect(restored.recipeCount, equals(0));
    });
  });
}
