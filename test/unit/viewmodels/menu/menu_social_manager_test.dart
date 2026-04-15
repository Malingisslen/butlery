// test/unit/viewmodels/menu/menu_social_manager_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/menu/menu_social_manager.dart';
import 'package:butlery/viewmodels/menu/menu_state_manager.dart';
import 'package:butlery/models/recipe_unified.dart';

import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/di/test_service_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MenuSocialManager socialManager;
  late MockSocialMenuOperations mockSocialMenuOps;

  setUpAll(() async {
    await TestServiceLocator.initialize();

    // Register fallback values for mocktail
    registerFallbackValue(<String, List<Recipe>>{});
    registerFallbackValue(<String>[]);
  });

  setUp(() async {
    mockSocialMenuOps = MockSocialMenuOperations();

    socialManager = MenuSocialManager(
      socialMenuOps: mockSocialMenuOps,
    );
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

  List<String> createTestFriendIds() {
    return ['friend_1', 'friend_2', 'friend_3'];
  }

  Map<String, dynamic> createSharedMenuData({
    String id = 'shared_menu_1',
    String title = 'Shared Menu',
    String sharedByDisplayName = 'Friend Anna',
    int totalRecipes = 5,
    bool isImported = false,
  }) {
    return {
      'id': id,
      'title': title,
      'description': 'Great weekly menu',
      'sharedAt': DateTime.now().toIso8601String(),
      'sharedByDisplayName': sharedByDisplayName,
      'totalRecipes': totalRecipes,
      'isImported': isImported,
    };
  }

  group('MenuSocialManager - Social Sharing', () {
    test('should share menu with friends successfully', () async {
      final menu = createTestMenu();
      final friendIds = createTestFriendIds();
      const menuName = 'Weekly Family Menu';
      const shareMessage = 'Great menu for the week!';

      when(() => mockSocialMenuOps.shareMenuWithFriends(
            menu: any(named: 'menu'),
            friendUserIds: any(named: 'friendUserIds'),
            message: any(named: 'message'),
            customTitle: any(named: 'customTitle'),
          )).thenAnswer((_) async => true);

      final result = await socialManager.shareMenuWithFriends(
        menu: menu,
        friendUserIds: friendIds,
        menuName: menuName,
        shareMessage: shareMessage,
      );

      expect(result, isTrue);

      verify(() => mockSocialMenuOps.shareMenuWithFriends(
            menu: menu,
            friendUserIds: friendIds,
            message: shareMessage,
            customTitle: menuName,
          )).called(1);
    });

    test('should handle sharing failure gracefully', () async {
      final menu = createTestMenu();
      final friendIds = createTestFriendIds();

      when(() => mockSocialMenuOps.shareMenuWithFriends(
            menu: any(named: 'menu'),
            friendUserIds: any(named: 'friendUserIds'),
            message: any(named: 'message'),
            customTitle: any(named: 'customTitle'),
          )).thenAnswer((_) async => false);

      final result = await socialManager.shareMenuWithFriends(
        menu: menu,
        friendUserIds: friendIds,
        menuName: 'Test Menu',
      );

      expect(result, isFalse);
    });

    test('should handle sharing exception', () async {
      final menu = createTestMenu();
      final friendIds = createTestFriendIds();

      when(() => mockSocialMenuOps.shareMenuWithFriends(
            menu: any(named: 'menu'),
            friendUserIds: any(named: 'friendUserIds'),
            message: any(named: 'message'),
            customTitle: any(named: 'customTitle'),
          )).thenThrow(Exception('Network error'));

      expect(
        () => socialManager.shareMenuWithFriends(
          menu: menu,
          friendUserIds: friendIds,
          menuName: 'Test Menu',
        ),
        throwsException,
      );
    });

    test('should trim share message when provided', () async {
      final menu = createTestMenu();
      final friendIds = createTestFriendIds();
      const shareMessage = '  Trimmed message  ';

      when(() => mockSocialMenuOps.shareMenuWithFriends(
            menu: any(named: 'menu'),
            friendUserIds: any(named: 'friendUserIds'),
            message: any(named: 'message'),
            customTitle: any(named: 'customTitle'),
          )).thenAnswer((_) async => true);

      await socialManager.shareMenuWithFriends(
        menu: menu,
        friendUserIds: friendIds,
        menuName: 'Test Menu',
        shareMessage: shareMessage,
      );

      verify(() => mockSocialMenuOps.shareMenuWithFriends(
            menu: menu,
            friendUserIds: friendIds,
            message: 'Trimmed message',
            customTitle: 'Test Menu',
          )).called(1);
    });

    test('should handle null share message', () async {
      final menu = createTestMenu();
      final friendIds = createTestFriendIds();

      when(() => mockSocialMenuOps.shareMenuWithFriends(
            menu: any(named: 'menu'),
            friendUserIds: any(named: 'friendUserIds'),
            message: any(named: 'message'),
            customTitle: any(named: 'customTitle'),
          )).thenAnswer((_) async => true);

      await socialManager.shareMenuWithFriends(
        menu: menu,
        friendUserIds: friendIds,
        menuName: 'Test Menu',
      );

      verify(() => mockSocialMenuOps.shareMenuWithFriends(
            menu: menu,
            friendUserIds: friendIds,
            message: null,
            customTitle: 'Test Menu',
          )).called(1);
    });
  });

  group('MenuSocialManager - Social Discovery', () {
    test('should get available shared menus successfully', () async {
      final sharedMenus = [
        createSharedMenuData(id: 'menu_1', title: 'Menu 1'),
        createSharedMenuData(id: 'menu_2', title: 'Menu 2'),
        createSharedMenuData(id: 'menu_3', title: 'Menu 3'),
      ];

      when(() => mockSocialMenuOps.getMenusSharedWithMe())
          .thenAnswer((_) async => sharedMenus);

      final result = await socialManager.getAvailableSharedMenus();

      expect(result, equals(sharedMenus));
      expect(result.length, equals(3));
    });

    test('should return empty list when discovery fails', () async {
      when(() => mockSocialMenuOps.getMenusSharedWithMe())
          .thenThrow(Exception('Network error'));

      final result = await socialManager.getAvailableSharedMenus();

      expect(result, isEmpty);
    });

    test('should import shared menu successfully', () async {
      const sharedMenuId = 'shared_menu_123';

      when(() => mockSocialMenuOps.importSharedMenu(sharedMenuId))
          .thenAnswer((_) async => true);

      final result = await socialManager.importSharedMenu(sharedMenuId);

      expect(result, isTrue);
      verify(() => mockSocialMenuOps.importSharedMenu(sharedMenuId)).called(1);
    });

    test('should handle import failure', () async {
      const sharedMenuId = 'shared_menu_123';

      when(() => mockSocialMenuOps.importSharedMenu(sharedMenuId))
          .thenAnswer((_) async => false);

      final result = await socialManager.importSharedMenu(sharedMenuId);

      expect(result, isFalse);
    });

    test('should handle import exception', () async {
      const sharedMenuId = 'shared_menu_123';

      when(() => mockSocialMenuOps.importSharedMenu(sharedMenuId))
          .thenThrow(Exception('Import failed'));

      expect(
        () => socialManager.importSharedMenu(sharedMenuId),
        throwsException,
      );
    });

    test('should mark shared menu as viewed', () async {
      const sharedMenuId = 'shared_menu_123';

      when(() => mockSocialMenuOps.markMenuAsViewed(sharedMenuId))
          .thenAnswer((_) async {});

      await socialManager.markSharedMenuAsViewed(sharedMenuId);

      verify(() => mockSocialMenuOps.markMenuAsViewed(sharedMenuId)).called(1);
    });

    test('should handle mark as viewed exception', () async {
      const sharedMenuId = 'shared_menu_123';

      when(() => mockSocialMenuOps.markMenuAsViewed(sharedMenuId))
          .thenThrow(Exception('Mark viewed failed'));

      // Should not throw - should handle gracefully
      await socialManager.markSharedMenuAsViewed(sharedMenuId);

      verify(() => mockSocialMenuOps.markMenuAsViewed(sharedMenuId)).called(1);
    });
  });

  group('MenuSocialManager - Imported Menu Management', () {
    test('should load imported menus successfully', () async {
      final importedMenusData = [
        createSharedMenuData(
            id: 'menu_1', title: 'Imported Menu 1', isImported: true),
        createSharedMenuData(
            id: 'menu_2', title: 'Imported Menu 2', isImported: true),
        createSharedMenuData(
            id: 'menu_3',
            title: 'Not Imported',
            isImported: false), // Should be filtered out
      ];

      when(() => mockSocialMenuOps.getMenusSharedWithMe())
          .thenAnswer((_) async => importedMenusData);

      final result = await socialManager.loadImportedMenus();

      expect(result.length, equals(2)); // Only imported ones
      expect(result[0].name, equals('Imported Menu 1'));
      expect(result[1].name, equals('Imported Menu 2'));
      expect(result[0].isOwned, isFalse); // Imported menus are not owned
      expect(result[1].isOwned, isFalse);
    });

    test('should handle corrupted imported menu data gracefully', () async {
      final importedMenusData = [
        createSharedMenuData(
            id: 'menu_1', title: 'Good Menu', isImported: true),
        // Corrupted data missing required fields
        {
          'id': 'menu_2',
          'isImported': true,
          // Missing title, sharedAt, etc.
        },
        createSharedMenuData(
            id: 'menu_3', title: 'Another Good Menu', isImported: true),
      ];

      when(() => mockSocialMenuOps.getMenusSharedWithMe())
          .thenAnswer((_) async => importedMenusData);

      final result = await socialManager.loadImportedMenus();

      expect(result.length, equals(2)); // Corrupted one should be skipped
      expect(result[0].name, equals('Good Menu'));
      expect(result[1].name, equals('Another Good Menu'));
    });

    test('should return empty list when loading imported menus fails',
        () async {
      when(() => mockSocialMenuOps.getMenusSharedWithMe())
          .thenThrow(Exception('Network error'));

      final result = await socialManager.loadImportedMenus();

      expect(result, isEmpty);
    });

    test('should return null for imported menu data (not implemented)',
        () async {
      final result = await socialManager.loadImportedMenuData('menu_key_123');

      expect(result, isNull);
    });
  });

  group('MenuSocialManager - Social Statistics', () {
    test('should get sharing statistics successfully', () async {
      final expectedStats = {
        'menusShared': 10,
        'menusReceived': 5,
        'totalInteractions': 15,
        'lastSharedAt': '2023-12-01T10:00:00Z',
      };

      when(() => mockSocialMenuOps.getSharingStats())
          .thenAnswer((_) async => expectedStats);

      final result = await socialManager.getSharingStats();

      expect(result, equals(expectedStats));
    });

    test('should return empty stats when getting sharing stats fails',
        () async {
      when(() => mockSocialMenuOps.getSharingStats())
          .thenThrow(Exception('Stats error'));

      final result = await socialManager.getSharingStats();

      expect(result, isEmpty);
    });

    test('should get social activity summary successfully', () async {
      final sharingStats = {
        'menusShared': 8,
        'lastSharedAt': '2023-12-01T10:00:00Z',
      };

      final sharedMenus = [
        createSharedMenuData(id: 'menu_1'),
        createSharedMenuData(id: 'menu_2'),
      ];

      final importedMenus = [
        createSharedMenuData(id: 'menu_3', isImported: true),
      ];

      when(() => mockSocialMenuOps.getSharingStats())
          .thenAnswer((_) async => sharingStats);
      when(() => mockSocialMenuOps.getMenusSharedWithMe())
          .thenAnswer((_) async => [...sharedMenus, ...importedMenus]);

      final result = await socialManager.getSocialActivitySummary();

      expect(result['menusShared'], equals(8));
      expect(result['menusReceived'], equals(3)); // All shared menus
      expect(result['menusImported'], equals(1)); // Only imported ones
      expect(result['totalSocialInteractions'], equals(12)); // 8 + 3 + 1
      expect(result['lastActivity'], isNotNull);
    });

    test('should handle social activity summary with missing data', () async {
      when(() => mockSocialMenuOps.getSharingStats())
          .thenAnswer((_) async => {});
      when(() => mockSocialMenuOps.getMenusSharedWithMe())
          .thenAnswer((_) async => []);

      final result = await socialManager.getSocialActivitySummary();

      expect(result['menusShared'], equals(0));
      expect(result['menusReceived'], equals(0));
      expect(result['menusImported'], equals(0));
      expect(result['totalSocialInteractions'], equals(0));
    });

    test('should return partial summary when individual operations fail',
        () async {
      when(() => mockSocialMenuOps.getSharingStats())
          .thenThrow(Exception('Stats error'));
      when(() => mockSocialMenuOps.getMenusSharedWithMe())
          .thenAnswer((_) async => []); // Some operations succeed

      final result = await socialManager.getSocialActivitySummary();

      expect(result['menusShared'], equals(0));
      expect(result['menusReceived'], equals(0));
      expect(result['menusImported'], equals(0));
      expect(result['totalSocialInteractions'], equals(0));
    });

    test('should calculate last activity from various sources', () async {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final twoDaysAgo = now.subtract(const Duration(days: 2));

      final sharingStats = {
        'menusShared': 5,
        'lastSharedAt': yesterday.toIso8601String(), // Most recent
      };

      final sharedMenus = [
        {
          ...createSharedMenuData(id: 'menu_1'),
          'sharedAt': twoDaysAgo.toIso8601String(), // Older
        },
      ];

      when(() => mockSocialMenuOps.getSharingStats())
          .thenAnswer((_) async => sharingStats);
      when(() => mockSocialMenuOps.getMenusSharedWithMe())
          .thenAnswer((_) async => sharedMenus);

      final result = await socialManager.getSocialActivitySummary();

      // Should pick the most recent activity (yesterday)
      final lastActivity = result['lastActivity'] as DateTime?;
      expect(lastActivity, isNotNull);
      expect(lastActivity!.difference(yesterday).abs().inMinutes, lessThan(1));
    });
  });

  group('MenuSocialManager - Social Validation', () {
    test('should validate sharing prerequisites successfully', () {
      final menu = createTestMenu();
      final friendIds = createTestFriendIds();
      const menuName = 'Valid Menu';

      expect(
        () => socialManager.validateSharingPrerequisites(
          menu: menu,
          friendUserIds: friendIds,
          menuName: menuName,
        ),
        returnsNormally,
      );

      final result = socialManager.validateSharingPrerequisites(
        menu: menu,
        friendUserIds: friendIds,
        menuName: menuName,
      );

      expect(result, isTrue);
    });

    test('should throw error for empty menu', () {
      final friendIds = createTestFriendIds();
      const menuName = 'Valid Menu';

      expect(
        () => socialManager.validateSharingPrerequisites(
          menu: <String, List<Recipe>>{},
          friendUserIds: friendIds,
          menuName: menuName,
        ),
        throwsA(predicate((e) =>
            e is ArgumentError &&
            e.toString().contains('Ingen meny att dela'))),
      );
    });

    test('should throw error for empty menu name', () {
      final menu = createTestMenu();
      final friendIds = createTestFriendIds();

      expect(
        () => socialManager.validateSharingPrerequisites(
          menu: menu,
          friendUserIds: friendIds,
          menuName: '',
        ),
        throwsA(predicate((e) =>
            e is ArgumentError &&
            e.toString().contains('Fyll i alla obligatoriska fält'))),
      );
    });

    test('should throw error for whitespace-only menu name', () {
      final menu = createTestMenu();
      final friendIds = createTestFriendIds();

      expect(
        () => socialManager.validateSharingPrerequisites(
          menu: menu,
          friendUserIds: friendIds,
          menuName: '   ',
        ),
        throwsA(predicate((e) =>
            e is ArgumentError &&
            e.toString().contains('Fyll i alla obligatoriska fält'))),
      );
    });

    test('should throw error for empty friend list', () {
      final menu = createTestMenu();
      const menuName = 'Valid Menu';

      expect(
        () => socialManager.validateSharingPrerequisites(
          menu: menu,
          friendUserIds: [],
          menuName: menuName,
        ),
        throwsA(predicate((e) =>
            e is ArgumentError &&
            e.toString().contains('Välj minst en vän att dela med'))),
      );
    });

    test('should check if menu can be shared', () {
      final validMenu = createTestMenu();
      final emptyMenu = <String, List<Recipe>>{};
      final menuWithNoRecipes = <String, List<Recipe>>{
        'Monday': <Recipe>[],
        'Tuesday': <Recipe>[],
      };

      expect(socialManager.canShareMenu(validMenu), isTrue);
      expect(socialManager.canShareMenu(emptyMenu), isFalse);
      expect(socialManager.canShareMenu(menuWithNoRecipes), isFalse);
    });

    test('should check social features availability', () async {
      final result = await socialManager.areSocialFeaturesAvailable();

      // Currently simplified to always return true
      expect(result, isTrue);
    });
  });

  group('MenuSocialManager - Edge Cases', () {
    test('should handle large friend lists', () async {
      final menu = createTestMenu();
      final largeFriendList = List.generate(100, (index) => 'friend_$index');
      const menuName = 'Test Menu';

      when(() => mockSocialMenuOps.shareMenuWithFriends(
            menu: any(named: 'menu'),
            friendUserIds: any(named: 'friendUserIds'),
            message: any(named: 'message'),
            customTitle: any(named: 'customTitle'),
          )).thenAnswer((_) async => true);

      final result = await socialManager.shareMenuWithFriends(
        menu: menu,
        friendUserIds: largeFriendList,
        menuName: menuName,
      );

      expect(result, isTrue);

      verify(() => mockSocialMenuOps.shareMenuWithFriends(
            menu: menu,
            friendUserIds: largeFriendList,
            message: null,
            customTitle: menuName,
          )).called(1);
    });

    test('should handle menu with many recipes', () {
      final largeMenu = <String, List<Recipe>>{};
      for (int i = 0; i < 10; i++) {
        final recipes = <Recipe>[];
        for (int j = 0; j < 20; j++) {
          recipes.add(RecipeFactory.build(id: 'recipe_${i}_$j'));
        }
        largeMenu['Day_$i'] = recipes;
      }

      expect(socialManager.canShareMenu(largeMenu), isTrue);
      expect(
        () => socialManager.validateSharingPrerequisites(
          menu: largeMenu,
          friendUserIds: ['friend_1'],
          menuName: 'Large Menu',
        ),
        returnsNormally,
      );
    });

    test('should handle network timeouts gracefully', () async {
      when(() => mockSocialMenuOps.getMenusSharedWithMe())
          .thenAnswer((_) => Future.delayed(
                const Duration(seconds: 10),
                () => throw Exception('Timeout'),
              ));

      final result = await socialManager.getAvailableSharedMenus();

      expect(result, isEmpty);
    });

    test('should handle malformed timestamp data in shared menus', () async {
      final malformedMenusData = [
        {
          'id': 'menu_1',
          'title': 'Menu 1',
          'sharedAt': 'not-a-timestamp', // Malformed timestamp
          'sharedByDisplayName': 'Friend',
          'totalRecipes': 3,
          'isImported': true,
        },
      ];

      when(() => mockSocialMenuOps.getMenusSharedWithMe())
          .thenAnswer((_) async => malformedMenusData);

      final result = await socialManager.loadImportedMenus();

      // Should handle gracefully - might be empty if parsing fails
      expect(result, isA<List<SavedMenuInfo>>());
    });

    test('should handle concurrent operations', () async {
      final menu = createTestMenu();
      final friendIds = createTestFriendIds();

      when(() => mockSocialMenuOps.shareMenuWithFriends(
            menu: any(named: 'menu'),
            friendUserIds: any(named: 'friendUserIds'),
            message: any(named: 'message'),
            customTitle: any(named: 'customTitle'),
          )).thenAnswer((_) async => true);

      when(() => mockSocialMenuOps.getMenusSharedWithMe())
          .thenAnswer((_) async => []);

      // Run concurrent operations
      final futures = [
        socialManager.shareMenuWithFriends(
          menu: menu,
          friendUserIds: friendIds,
          menuName: 'Menu 1',
        ),
        socialManager.shareMenuWithFriends(
          menu: menu,
          friendUserIds: friendIds,
          menuName: 'Menu 2',
        ),
        socialManager.getAvailableSharedMenus(),
        socialManager.loadImportedMenus(),
      ];

      final results = await Future.wait(futures);

      expect(results[0], isTrue);
      expect(results[1], isTrue);
      expect(results[2], isA<List>());
      expect(results[3], isA<List<SavedMenuInfo>>());
    });
  });
}
