// test/unit/viewmodels/menu/menu_storage_test.dart

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/viewmodels/menu/menu_storage.dart';
import 'package:butlery/models/recipe_unified.dart';

import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/di/test_service_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MenuStorage menuStorage;

  setUpAll(() async {
    await TestServiceLocator.initialize();
  });

  setUp(() async {
    menuStorage = MenuStorage();

    // Clear SharedPreferences before each test
    SharedPreferences.setMockInitialValues({});
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
  });

  Map<String, List<Recipe>> createTestMenu() {
    return {
      'Monday': [RecipeFactory.build(title: 'Monday Recipe')],
      'Tuesday': [RecipeFactory.build(title: 'Tuesday Recipe')],
      'Wednesday': [RecipeFactory.build(title: 'Wednesday Recipe')],
    };
  }

  SavedMenuData createTestMenuData({
    String name = 'Test Menu',
    int recipeCount = 3,
    bool isModified = false,
    String? originalAuthor,
  }) {
    return SavedMenuData(
      name: name,
      savedDate: DateTime.now(),
      recipeCount: recipeCount,
      menu: createTestMenu(),
      lastPrompt: 'test prompt',
      comment: 'Test comment',
      originalAuthor: originalAuthor,
      isModified: isModified,
    );
  }

  group('MenuStorage - Save Operations', () {
    test('should save menu locally successfully', () async {
      const menuName = 'Weekly Family Menu';
      const comment = 'Great menu for the week';
      final menu = createTestMenu();
      const lastPrompt = 'vegetarian weekly menu';
      const totalRecipeCount = 3;

      final menuKey = await menuStorage.saveMenu(
        menuName: menuName,
        comment: comment,
        menu: menu,
        lastPrompt: lastPrompt,
        totalRecipeCount: totalRecipeCount,
      );

      expect(menuKey, isNotEmpty);
      expect(menuKey, startsWith('saved_menu_'));
      expect(menuKey, contains(menuName.replaceAll(' ', '_')));

      // Verify it was actually saved
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString(menuKey);
      expect(savedJson, isNotNull);
      expect(savedJson, contains(menuName));
      expect(savedJson, contains(comment));
    });

    test('should trim menu name and comment when saving', () async {
      const menuName = '  Trimmed Menu  ';
      const comment = '  Trimmed comment  ';
      final menu = createTestMenu();

      final menuKey = await menuStorage.saveMenu(
        menuName: menuName,
        comment: comment,
        menu: menu,
        lastPrompt: 'test',
        totalRecipeCount: 3,
      );

      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString(menuKey);
      expect(savedJson, contains('Trimmed Menu'));
      expect(savedJson, contains('Trimmed comment'));
      expect(savedJson, isNot(contains('  Trimmed Menu  ')));
    });

    test('should generate unique menu keys', () async {
      final menu = createTestMenu();

      final key1 = await menuStorage.saveMenu(
        menuName: 'Same Name',
        comment: 'Comment 1',
        menu: menu,
        lastPrompt: 'prompt1',
        totalRecipeCount: 3,
      );

      // Add small delay to ensure different timestamp
      await Future.delayed(const Duration(milliseconds: 10));

      final key2 = await menuStorage.saveMenu(
        menuName: 'Same Name',
        comment: 'Comment 2',
        menu: menu,
        lastPrompt: 'prompt2',
        totalRecipeCount: 3,
      );

      expect(key1, isNot(equals(key2)));
      expect(key1, startsWith('saved_menu_Same_Name_'));
      expect(key2, startsWith('saved_menu_Same_Name_'));
    });

    test('should handle special characters in menu name', () async {
      const menuName = 'Menü with Spëcial Chârs!';
      final menu = createTestMenu();

      final menuKey = await menuStorage.saveMenu(
        menuName: menuName,
        comment: 'Test',
        menu: menu,
        lastPrompt: 'test',
        totalRecipeCount: 3,
      );

      expect(menuKey, contains('Menü'));
      expect(menuKey, contains('Spëcial'));
      expect(menuKey, contains('Chârs!'));
    });

    test('should save menu with complete metadata', () async {
      final menu = createTestMenu();
      const menuName = 'Complete Menu';
      const comment = 'Full metadata test';
      const lastPrompt = 'detailed prompt';
      const totalRecipeCount = 5;

      final menuKey = await menuStorage.saveMenu(
        menuName: menuName,
        comment: comment,
        menu: menu,
        lastPrompt: lastPrompt,
        totalRecipeCount: totalRecipeCount,
      );

      final loadedData = await menuStorage.loadMenuByKey(menuKey);

      expect(loadedData, isNotNull);
      expect(loadedData!.name, equals(menuName));
      expect(loadedData.comment, equals(comment));
      expect(loadedData.lastPrompt, equals(lastPrompt));
      expect(loadedData.recipeCount, equals(totalRecipeCount));
      expect(loadedData.menu.keys.length, equals(3));
      expect(loadedData.isOwned, isTrue);
      expect(loadedData.isModified, isFalse);
    });
  });

  group('MenuStorage - Load Operations', () {
    test('should load menu by key successfully', () async {
      final testMenuData = createTestMenuData();
      final prefs = await SharedPreferences.getInstance();
      const testKey = 'saved_menu_test_123';

      await prefs.setString(testKey, jsonEncode(testMenuData.toJson()));

      final loadedData = await menuStorage.loadMenuByKey(testKey);

      expect(loadedData, isNotNull);
      expect(loadedData!.name, equals(testMenuData.name));
      expect(loadedData.comment, equals(testMenuData.comment));
      expect(loadedData.lastPrompt, equals(testMenuData.lastPrompt));
      expect(loadedData.menu.keys.length, equals(3));
    });

    test('should return null for non-existent key', () async {
      const nonExistentKey = 'saved_menu_not_found_123';

      final loadedData = await menuStorage.loadMenuByKey(nonExistentKey);

      expect(loadedData, isNull);
    });

    test('should handle corrupted menu data gracefully', () async {
      final prefs = await SharedPreferences.getInstance();
      const corruptedKey = 'saved_menu_corrupted_123';

      await prefs.setString(corruptedKey, 'invalid json data');

      expect(
        () => menuStorage.loadMenuByKey(corruptedKey),
        throwsException,
      );
    });

    test('should load all local menus successfully', () async {
      final prefs = await SharedPreferences.getInstance();

      // Save multiple menus
      final menu1 = createTestMenuData(name: 'Menu 1');
      final menu2 = createTestMenuData(
          name: 'Menu 2', originalAuthor: 'Friend'); // Not owned
      final menu3 = createTestMenuData(name: 'Menu 3');

      await prefs.setString('saved_menu_1', jsonEncode(menu1.toJson()));
      await prefs.setString('saved_menu_2', jsonEncode(menu2.toJson()));
      await prefs.setString('saved_menu_3', jsonEncode(menu3.toJson()));
      await prefs.setString('not_a_menu', 'other data'); // Should be ignored

      final loadedMenus = await menuStorage.loadUserMenus();

      expect(
          loadedMenus.length, equals(2)); // Only owned menus (menu1 and menu3)
      expect(loadedMenus.any((m) => m.name == 'Menu 1'), isTrue);
      expect(loadedMenus.any((m) => m.name == 'Menu 3'), isTrue);
      expect(loadedMenus.any((m) => m.name == 'Menu 2'), isFalse); // Not owned
    });

    test('should handle empty storage when loading local menus', () async {
      final loadedMenus = await menuStorage.loadUserMenus();

      expect(loadedMenus, isEmpty);
    });

    test('should skip corrupted entries when loading local menus', () async {
      final prefs = await SharedPreferences.getInstance();

      final validMenu = createTestMenuData(name: 'Valid Menu');
      await prefs.setString('saved_menu_valid', jsonEncode(validMenu.toJson()));
      await prefs.setString('saved_menu_corrupted', 'invalid json');

      final loadedMenus = await menuStorage.loadUserMenus();

      expect(loadedMenus.length, equals(1));
      expect(loadedMenus[0].name, equals('Valid Menu'));
    });

    test('should return empty list when loading fails', () async {
      // Mock SharedPreferences to throw an error
      SharedPreferences.setMockInitialValues(<String, Object>{});

      final loadedMenus = await menuStorage.loadUserMenus();

      expect(loadedMenus, isEmpty);
    });
  });

  group('MenuStorage - Delete Operations', () {
    test('should delete menu by key successfully', () async {
      final prefs = await SharedPreferences.getInstance();
      const testKey = 'saved_menu_to_delete_123';
      final testMenuData = createTestMenuData();

      await prefs.setString(testKey, jsonEncode(testMenuData.toJson()));
      expect(prefs.containsKey(testKey), isTrue);

      final result = await menuStorage.deleteMenuByKey(testKey);

      expect(result, isTrue);
      expect(prefs.containsKey(testKey), isFalse);
    });

    test('should handle deleting non-existent key', () async {
      const nonExistentKey = 'saved_menu_not_found_123';

      final result = await menuStorage.deleteMenuByKey(nonExistentKey);

      expect(result, isTrue); // Should still return true
    });

    test('should handle delete operation errors gracefully', () async {
      const testKey = 'saved_menu_error_123';

      final result = await menuStorage.deleteMenuByKey(testKey);

      expect(result, isTrue);
    });
  });

  group('MenuStorage - Menu Modification', () {
    test('should mark menu as modified successfully', () async {
      final prefs = await SharedPreferences.getInstance();
      const testKey = 'saved_menu_modify_123';
      final originalMenuData = createTestMenuData(isModified: false);

      await prefs.setString(testKey, jsonEncode(originalMenuData.toJson()));

      final result = await menuStorage.markMenuAsModified(testKey);

      expect(result, isTrue);

      final modifiedData = await menuStorage.loadMenuByKey(testKey);
      expect(modifiedData, isNotNull);
      expect(modifiedData!.isModified, isTrue);
      expect(modifiedData.name,
          equals(originalMenuData.name)); // Other data preserved
    });

    test('should return false when marking non-existent menu as modified',
        () async {
      const nonExistentKey = 'saved_menu_not_found_123';

      final result = await menuStorage.markMenuAsModified(nonExistentKey);

      expect(result, isFalse);
    });

    test('should handle modification errors gracefully', () async {
      final prefs = await SharedPreferences.getInstance();
      const corruptedKey = 'saved_menu_corrupted_123';

      await prefs.setString(corruptedKey, 'invalid json');

      final result = await menuStorage.markMenuAsModified(corruptedKey);

      expect(result, isFalse);
    });

    test('should preserve all original data when marking as modified',
        () async {
      final prefs = await SharedPreferences.getInstance();
      const testKey = 'saved_menu_preserve_123';
      final originalMenuData = createTestMenuData(
        name: 'Original Name',
        originalAuthor: 'Original Author',
        isModified: false,
      );

      await prefs.setString(testKey, jsonEncode(originalMenuData.toJson()));

      await menuStorage.markMenuAsModified(testKey);

      final modifiedData = await menuStorage.loadMenuByKey(testKey);
      expect(modifiedData, isNotNull);
      expect(modifiedData!.isModified, isTrue);
      expect(modifiedData.name, equals('Original Name'));
      expect(modifiedData.originalAuthor, equals('Original Author'));
      expect(modifiedData.comment, equals(originalMenuData.comment));
      expect(modifiedData.lastPrompt, equals(originalMenuData.lastPrompt));
    });
  });

  group('MenuStorage - Imported Menu Management', () {
    test('should load imported menu by key successfully', () async {
      final prefs = await SharedPreferences.getInstance();
      const menuKey = 'imported_menu_123';
      final importedMenuData = createTestMenuData(name: 'Imported Menu');

      final importedMenusData = {
        menuKey: importedMenuData.toJson(),
      };

      await prefs.setString('imported_menus', jsonEncode(importedMenusData));

      final loadedData = await menuStorage.loadImportedMenuByKey(menuKey);

      expect(loadedData, isNotNull);
      expect(loadedData!.name, equals('Imported Menu'));
    });

    test('should return null for non-existent imported menu key', () async {
      const nonExistentKey = 'imported_menu_not_found';

      final loadedData =
          await menuStorage.loadImportedMenuByKey(nonExistentKey);

      expect(loadedData, isNull);
    });

    test('should return null when no imported menus exist', () async {
      const menuKey = 'imported_menu_123';

      final loadedData = await menuStorage.loadImportedMenuByKey(menuKey);

      expect(loadedData, isNull);
    });

    test('should handle corrupted imported menus data', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('imported_menus', 'invalid json');

      const menuKey = 'imported_menu_123';
      final loadedData = await menuStorage.loadImportedMenuByKey(menuKey);

      expect(loadedData, isNull);
    });
  });

  group('MenuStorage - Storage Validation', () {
    test('should validate menu names correctly', () {
      expect(menuStorage.validateMenuName('Valid Name'), isTrue);
      expect(menuStorage.validateMenuName('  Valid Name  '), isTrue); // Trimmed
      expect(menuStorage.validateMenuName(''), isFalse);
      expect(menuStorage.validateMenuName('   '), isFalse); // Whitespace only
      expect(
          menuStorage.validateMenuName('x' * 100), isTrue); // Exactly 100 chars
      expect(menuStorage.validateMenuName('x' * 101), isFalse); // Too long
    });

    test('should validate menu data correctly', () {
      final validMenu = createTestMenu();
      final emptyMenu = <String, List<Recipe>>{};
      final menuWithEmptySection = <String, List<Recipe>>{
        'Monday': [RecipeFactory.build()],
        'Tuesday': <Recipe>[], // Empty section
      };

      expect(menuStorage.validateMenuData(validMenu), isTrue);
      expect(menuStorage.validateMenuData(emptyMenu), isFalse);
      expect(menuStorage.validateMenuData(menuWithEmptySection), isFalse);
    });

    test('should handle menu validation edge cases', () {
      final menuWithSingleRecipe = <String, List<Recipe>>{
        'Monday': [RecipeFactory.build()],
      };

      final menuWithMultipleEmptySections = <String, List<Recipe>>{
        'Monday': <Recipe>[],
        'Tuesday': <Recipe>[],
        'Wednesday': <Recipe>[],
      };

      expect(menuStorage.validateMenuData(menuWithSingleRecipe), isTrue);
      expect(
          menuStorage.validateMenuData(menuWithMultipleEmptySections), isFalse);
    });
  });

// NOTE: Storage Information and Storage Cleanup tests removed
  // These tests were for SharedPreferences-based storage methods that
  // were removed when MenuStorage was refactored to Firestore-only architecture.

  group('MenuStorage - SavedMenuData Class', () {
    test('should create SavedMenuData with all properties', () {
      final now = DateTime.now();
      final menu = createTestMenu();

      final menuData = SavedMenuData(
        name: 'Test Menu',
        savedDate: now,
        recipeCount: 5,
        menu: menu,
        lastPrompt: 'test prompt',
        comment: 'test comment',
        originalAuthor: 'Original Author',
        originalAuthorId: 'author_123',
        isModified: true,
        firebaseId: 'firebase_456',
      );

      expect(menuData.name, equals('Test Menu'));
      expect(menuData.savedDate, equals(now));
      expect(menuData.recipeCount, equals(5));
      expect(menuData.menu, equals(menu));
      expect(menuData.lastPrompt, equals('test prompt'));
      expect(menuData.comment, equals('test comment'));
      expect(menuData.originalAuthor, equals('Original Author'));
      expect(menuData.originalAuthorId, equals('author_123'));
      expect(menuData.isModified, isTrue);
      expect(menuData.firebaseId, equals('firebase_456'));
    });

    test('should have correct default values', () {
      final menu = createTestMenu();

      final menuData = SavedMenuData(
        name: 'Test Menu',
        savedDate: DateTime.now(),
        recipeCount: 3,
        menu: menu,
        lastPrompt: 'test prompt',
        comment: 'test comment',
      );

      expect(menuData.originalAuthor, isNull);
      expect(menuData.originalAuthorId, isNull);
      expect(menuData.isModified, isFalse);
      expect(menuData.firebaseId, isNull);
    });

    test('should determine ownership correctly', () {
      final menu = createTestMenu();

      final ownedMenu = SavedMenuData(
        name: 'Owned Menu',
        savedDate: DateTime.now(),
        recipeCount: 3,
        menu: menu,
        lastPrompt: 'test prompt',
        comment: 'test comment',
      );

      final sharedMenu = SavedMenuData(
        name: 'Shared Menu',
        savedDate: DateTime.now(),
        recipeCount: 3,
        menu: menu,
        lastPrompt: 'test prompt',
        comment: 'test comment',
        originalAuthor: 'Friend',
      );

      expect(ownedMenu.isOwned, isTrue);
      expect(sharedMenu.isOwned, isFalse);
    });

    test('should serialize to JSON correctly', () {
      final now = DateTime.now();
      final menu = createTestMenu();

      final menuData = SavedMenuData(
        name: 'JSON Test Menu',
        savedDate: now,
        recipeCount: 3,
        menu: menu,
        lastPrompt: 'json test prompt',
        comment: 'json test comment',
        originalAuthor: 'JSON Author',
        isModified: true,
      );

      final json = menuData.toJson();

      expect(json['name'], equals('JSON Test Menu'));
      expect(json['savedDate'], equals(now.millisecondsSinceEpoch));
      expect(json['recipeCount'], equals(3));
      expect(json['lastPrompt'], equals('json test prompt'));
      expect(json['comment'], equals('json test comment'));
      expect(json['originalAuthor'], equals('JSON Author'));
      expect(json['isModified'], isTrue);
      expect(json['menu'], isA<Map<String, dynamic>>());
      expect(json['menu']['Monday'], isA<List>());
    });

    test('should deserialize from JSON correctly', () {
      final now = DateTime.now();
      final menu = createTestMenu();

      final originalData = SavedMenuData(
        name: 'JSON Deserialize Test',
        savedDate: now,
        recipeCount: 3,
        menu: menu,
        lastPrompt: 'deserialize prompt',
        comment: 'deserialize comment',
        originalAuthor: 'Deserialize Author',
        isModified: true,
      );

      final json = originalData.toJson();
      final deserializedData = SavedMenuData.fromJson(json);

      expect(deserializedData.name, equals(originalData.name));
      expect(deserializedData.savedDate.millisecondsSinceEpoch,
          equals(originalData.savedDate.millisecondsSinceEpoch));
      expect(deserializedData.recipeCount, equals(originalData.recipeCount));
      expect(deserializedData.lastPrompt, equals(originalData.lastPrompt));
      expect(deserializedData.comment, equals(originalData.comment));
      expect(
          deserializedData.originalAuthor, equals(originalData.originalAuthor));
      expect(deserializedData.isModified, equals(originalData.isModified));
      expect(deserializedData.menu.keys.length, equals(3));
    });

    test('should handle malformed JSON gracefully', () {
      final malformedJson = <String, dynamic>{
        // Missing required fields - uses defaults
        'name': null, // Will use empty string default
        'savedDate': null, // Will use 0 timestamp
        'recipeCount': null, // Will use 0 default
        'menu': null, // Will create empty map
      };

      final deserializedData = SavedMenuData.fromJson(malformedJson);

      expect(deserializedData.name, equals('')); // Default empty string
      expect(deserializedData.savedDate, isA<DateTime>()); // Default timestamp
      expect(deserializedData.recipeCount, equals(0)); // Default value
      expect(deserializedData.menu, isEmpty); // Empty menu
    });

    test('should handle empty menu in JSON serialization', () {
      final menuData = SavedMenuData(
        name: 'Empty Menu Test',
        savedDate: DateTime.now(),
        recipeCount: 0,
        menu: <String, List<Recipe>>{},
        lastPrompt: 'empty test',
        comment: 'empty comment',
      );

      final json = menuData.toJson();
      final deserializedData = SavedMenuData.fromJson(json);

      expect(deserializedData.menu, isEmpty);
      expect(deserializedData.recipeCount, equals(0));
    });
  });

  group('MenuStorage - Edge Cases', () {
    test('should handle concurrent save operations', () async {
      final menu = createTestMenu();

      final futures = List.generate(
        5,
        (index) => menuStorage.saveMenu(
          menuName: 'Concurrent Menu $index',
          comment: 'Comment $index',
          menu: menu,
          lastPrompt: 'prompt $index',
          totalRecipeCount: 3,
        ),
      );

      final keys = await Future.wait(futures);

      expect(keys.length, equals(5));
      expect(keys.toSet().length, equals(5)); // All unique keys

      // Verify all were saved
      for (final key in keys) {
        final loadedData = await menuStorage.loadMenuByKey(key);
        expect(loadedData, isNotNull);
      }
    });

    test('should handle very large menus', () async {
      // Create a menu with many sections and recipes
      final largeMenu = <String, List<Recipe>>{};
      for (int i = 0; i < 20; i++) {
        final recipes = <Recipe>[];
        for (int j = 0; j < 10; j++) {
          recipes.add(RecipeFactory.build(
            id: 'recipe_${i}_$j',
            title: 'Recipe $i-$j',
          ));
        }
        largeMenu['Section_$i'] = recipes;
      }

      final menuKey = await menuStorage.saveMenu(
        menuName: 'Large Menu',
        comment: 'Contains 200 recipes',
        menu: largeMenu,
        lastPrompt: 'large menu prompt',
        totalRecipeCount: 200,
      );

      final loadedData = await menuStorage.loadMenuByKey(menuKey);

      expect(loadedData, isNotNull);
      expect(loadedData!.menu.keys.length, equals(20));
      expect(loadedData.recipeCount, equals(200));
      expect(menuStorage.validateMenuData(loadedData.menu), isTrue);
    });

    test('should handle storage with many menu entries', () async {
      final menu = createTestMenu();
      final keys = <String>[];

      // Save many menus
      for (int i = 0; i < 50; i++) {
        final key = await menuStorage.saveMenu(
          menuName: 'Menu $i',
          comment: 'Comment $i',
          menu: menu,
          lastPrompt: 'prompt $i',
          totalRecipeCount: 3,
        );
        keys.add(key);
      }

      final loadedMenus = await menuStorage.loadUserMenus();
      expect(loadedMenus.length, equals(50));
    });

    test('should handle menu names with various encodings', () async {
      const unicodeMenuName = '🍝 Pasta Menü 中文 العربية';
      final menu = createTestMenu();

      final menuKey = await menuStorage.saveMenu(
        menuName: unicodeMenuName,
        comment: 'Unicode test',
        menu: menu,
        lastPrompt: 'unicode prompt',
        totalRecipeCount: 3,
      );

      final loadedData = await menuStorage.loadMenuByKey(menuKey);

      expect(loadedData, isNotNull);
      expect(loadedData!.name, equals(unicodeMenuName));
      expect(menuStorage.validateMenuName(unicodeMenuName), isTrue);
    });

    test('should handle empty recipes in menu sections', () async {
      final menuWithEmptyRecipes = <String, List<Recipe>>{
        'Monday': [RecipeFactory.build(title: 'Valid Recipe')],
        'Tuesday': [], // Empty section - should fail validation
      };

      expect(menuStorage.validateMenuData(menuWithEmptyRecipes), isFalse);

      // But can still save if needed
      final menuKey = await menuStorage.saveMenu(
        menuName: 'Menu With Empty Section',
        comment: 'Test empty sections',
        menu: menuWithEmptyRecipes,
        lastPrompt: 'empty test',
        totalRecipeCount: 1,
      );

      final loadedData = await menuStorage.loadMenuByKey(menuKey);
      expect(loadedData, isNotNull);
      expect(loadedData!.menu['Tuesday'], isEmpty);
    });
  });
}
