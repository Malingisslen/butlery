import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'helpers/model_test_base.dart';
import '../../infrastructure/factories/recipe_factory.dart';

void main() {
  ModelTestBase.testModelGroup('SharedMenu', () {
    late Map<String, List<Recipe>> testMenuSnapshot;
    late Recipe breakfastRecipe;
    late Recipe lunchRecipe1;
    late Recipe lunchRecipe2;
    late Recipe dinnerRecipe1;
    late Recipe dinnerRecipe2;
    late Recipe dinnerRecipe3;
    
    setUp(() {
      // Create test recipes for menu
      breakfastRecipe = RecipeFactory.build(
        id: 'breakfast_1',
        title: 'Havregrynsgröt',
        mealType: 'Frukost',
      );
      
      lunchRecipe1 = RecipeFactory.build(
        id: 'lunch_1',
        title: 'Sallad med kyckling',
        mealType: 'Lunch',
      );
      
      lunchRecipe2 = RecipeFactory.build(
        id: 'lunch_2',
        title: 'Soppa',
        mealType: 'Lunch',
      );
      
      dinnerRecipe1 = RecipeFactory.build(
        id: 'dinner_1',
        title: 'Köttbullar',
        mealType: 'Middag',
      );
      
      dinnerRecipe2 = RecipeFactory.build(
        id: 'dinner_2',
        title: 'Fiskgratäng',
        mealType: 'Middag',
      );
      
      dinnerRecipe3 = RecipeFactory.build(
        id: 'dinner_3',
        title: 'Pasta Carbonara',
        mealType: 'Middag',
      );
      
      // Create menu snapshot organized by category
      testMenuSnapshot = {
        'Frukost': [breakfastRecipe],
        'Lunch': [lunchRecipe1, lunchRecipe2],
        'Middag': [dinnerRecipe1, dinnerRecipe2, dinnerRecipe3],
      };
    });
    
    group('Construction', () {
      test('should create with required parameters', () {
        final menu = SharedMenu(
          id: 'menu_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna Andersson',
          sharedToUserIds: ['user_2'],
          menuTitle: 'Veckans meny',
          menuSnapshot: testMenuSnapshot,
        );
        
        expect(menu.id, equals('menu_123'));
        expect(menu.sharedByUserId, equals('user_1'));
        expect(menu.sharedByDisplayName, equals('Anna Andersson'));
        expect(menu.sharedToUserIds, equals(['user_2']));
        expect(menu.menuTitle, equals('Veckans meny'));
        expect(menu.menuSnapshot, equals(testMenuSnapshot));
        expect(menu.sharedAt, isNotNull);
        expect(menu.shareMessage, isNull);
        expect(menu.totalRecipeCount, equals(6));
        expect(menu.categories, equals(['Frukost', 'Lunch', 'Middag']));
        expect(menu.viewCount, equals(0));
        expect(menu.importCount, equals(0));
        expect(menu.viewedByUserIds, isEmpty);
        expect(menu.importedByUserIds, isEmpty);
        expect(menu.dismissedByUserIds, isEmpty);
        expect(menu.allowCollaboration, isFalse);
      });
      
      test('should create with all parameters', () {
        final sharedTime = DateTime(2024, 1, 15, 10, 30);
        
        final menu = SharedMenu(
          id: 'menu_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna Andersson',
          sharedToUserIds: ['user_2', 'user_3'],
          sharedAt: sharedTime,
          shareMessage: 'Här är min veckomeny!',
          menuTitle: 'Annas veckomeny v.45',
          menuSnapshot: testMenuSnapshot,
          viewedByUserIds: ['user_2'],
          importedByUserIds: ['user_3'],
          dismissedByUserIds: ['user_4'],
          allowCollaboration: true,
        );
        
        expect(menu.sharedAt, equals(sharedTime));
        expect(menu.shareMessage, equals('Här är min veckomeny!'));
        expect(menu.allowCollaboration, isTrue);
        expect(menu.viewedByUserIds, equals(['user_2']));
        expect(menu.importedByUserIds, equals(['user_3']));
        expect(menu.dismissedByUserIds, equals(['user_4']));
      });
      
      test('should calculate recipe count correctly', () {
        final menu = SharedMenu(
          id: 'menu_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          menuTitle: 'Test',
          menuSnapshot: testMenuSnapshot,
        );
        
        expect(menu.totalRecipeCount, equals(6)); // 1 + 2 + 3
      });
      
      test('should extract categories correctly', () {
        final menu = SharedMenu(
          id: 'menu_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          menuTitle: 'Test',
          menuSnapshot: testMenuSnapshot,
        );
        
        expect(menu.categories, containsAll(['Frukost', 'Lunch', 'Middag']));
        expect(menu.categories.length, equals(3));
      });
    });
    
    group('Factory Methods', () {
      test('should create with auto-generated ID', () {
        final menu = SharedMenu.create(
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna Andersson',
          sharedToUserIds: ['user_2'],
          shareMessage: 'Varsågod!',
          menuTitle: 'Min meny',
          menuSnapshot: testMenuSnapshot,
        );
        
        expect(menu.id, isNotEmpty);
        expect(menu.id.length, equals(36)); // UUID v4 length
        expect(menu.menuTitle, equals('Min meny'));
        expect(menu.shareMessage, equals('Varsågod!'));
      });
      
      test('should generate default menu title if not provided', () {
        final menu = SharedMenu.create(
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Erik',
          sharedToUserIds: ['user_2'],
          menuSnapshot: testMenuSnapshot,
        );
        
        expect(menu.menuTitle, equals('Eriks veckomeny'));
      });
      
      test('should support collaboration flag', () {
        final menu = SharedMenu.create(
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          menuSnapshot: testMenuSnapshot,
          allowCollaboration: true,
        );
        
        expect(menu.allowCollaboration, isTrue);
      });
    });
    
    group('User Engagement Tracking', () {
      late SharedMenu menu;
      
      setUp(() {
        menu = SharedMenu(
          id: 'menu_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2', 'user_3'],
          menuTitle: 'Test Menu',
          menuSnapshot: testMenuSnapshot,
        );
      });
      
      test('should mark as viewed by user', () {
        final viewed = menu.markViewedBy('user_2');
        
        expect(viewed.viewCount, equals(1));
        expect(viewed.viewedByUserIds, contains('user_2'));
        expect(viewed.isViewedBy('user_2'), isTrue);
      });
      
      test('should not duplicate view count for same user', () {
        final viewed1 = menu.markViewedBy('user_2');
        final viewed2 = viewed1.markViewedBy('user_2');
        
        expect(viewed2.viewCount, equals(1));
        expect(viewed2.viewedByUserIds.length, equals(1));
        expect(viewed2, same(viewed1)); // Returns same instance
      });
      
      test('should mark as imported by user', () {
        final imported = menu.markImportedBy('user_3');
        
        expect(imported.importCount, equals(1));
        expect(imported.importedByUserIds, contains('user_3'));
        expect(imported.isImportedBy('user_3'), isTrue);
      });
      
      test('should not duplicate import count for same user', () {
        final imported1 = menu.markImportedBy('user_3');
        final imported2 = imported1.markImportedBy('user_3');
        
        expect(imported2.importCount, equals(1));
        expect(imported2.importedByUserIds.length, equals(1));
        expect(imported2, same(imported1)); // Returns same instance
      });
      
      test('should mark as dismissed by user', () {
        final dismissed = menu.markDismissedBy('user_2');
        
        expect(dismissed.dismissedByUserIds, contains('user_2'));
        expect(dismissed.isDismissedBy('user_2'), isTrue);
      });
      
      test('should not duplicate dismissal for same user', () {
        final dismissed1 = menu.markDismissedBy('user_2');
        final dismissed2 = dismissed1.markDismissedBy('user_2');
        
        expect(dismissed2.dismissedByUserIds.length, equals(1));
        expect(dismissed2, same(dismissed1)); // Returns same instance
      });
      
      test('should undismiss menu for user', () {
        final dismissed = menu.markDismissedBy('user_2');
        final undismissed = dismissed.undismissBy('user_2');
        
        expect(undismissed.dismissedByUserIds, isEmpty);
        expect(undismissed.isDismissedBy('user_2'), isFalse);
      });
      
      test('should not change when undismissing non-dismissed user', () {
        final undismissed = menu.undismissBy('user_999');
        
        expect(undismissed, same(menu)); // Returns same instance
      });
    });
    
    group('Permission Checks', () {
      late SharedMenu menu;
      
      setUp(() {
        menu = SharedMenu(
          id: 'menu_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2', 'user_3'],
          menuTitle: 'Test Menu',
          menuSnapshot: testMenuSnapshot,
          viewedByUserIds: ['user_2'],
          importedByUserIds: ['user_3'],
          dismissedByUserIds: ['user_4'],
        );
      });
      
      test('should check if user can view menu', () {
        expect(menu.canBeViewedBy('user_1'), isTrue); // Owner can view
        expect(menu.canBeViewedBy('user_2'), isTrue); // Recipient can view
        expect(menu.canBeViewedBy('user_3'), isTrue); // Recipient can view
        expect(menu.canBeViewedBy('user_999'), isFalse); // Non-recipient cannot view
      });
      
      test('should check if user has viewed', () {
        expect(menu.isViewedBy('user_2'), isTrue);
        expect(menu.isViewedBy('user_3'), isFalse);
      });
      
      test('should check if user has imported', () {
        expect(menu.isImportedBy('user_3'), isTrue);
        expect(menu.isImportedBy('user_2'), isFalse);
      });
      
      test('should check if user has dismissed', () {
        expect(menu.isDismissedBy('user_4'), isTrue);
        expect(menu.isDismissedBy('user_2'), isFalse);
      });
      
      test('should check if menu should be shown to user', () {
        // User 2 can view and has not dismissed
        expect(menu.shouldBeShownTo('user_2'), isTrue);
        
        // User 4 cannot view (not recipient)
        expect(menu.shouldBeShownTo('user_4'), isFalse);
        
        // Test dismissed recipient
        final dismissedMenu = menu.markDismissedBy('user_2');
        expect(dismissedMenu.shouldBeShownTo('user_2'), isFalse);
      });
    });
    
    group('Import Permission', () {
      test('should allow import when menu has content', () {
        final menu = SharedMenu(
          id: 'menu_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          menuTitle: 'Test',
          menuSnapshot: testMenuSnapshot,
        );
        
        expect(menu.allowImport, isTrue);
        expect(menu.hasContent, isTrue);
      });
      
      test('should not allow import when menu is empty', () {
        final emptyMenu = SharedMenu(
          id: 'menu_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          menuTitle: 'Empty',
          menuSnapshot: {},
        );
        
        expect(emptyMenu.allowImport, isFalse);
        expect(emptyMenu.hasContent, isFalse);
        expect(emptyMenu.totalRecipeCount, equals(0));
      });
    });
    
    group('Display Properties', () {
      test('should provide menu summary in Swedish', () {
        final menu = SharedMenu(
          id: 'menu_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          menuTitle: 'Test',
          menuSnapshot: testMenuSnapshot,
        );
        
        expect(menu.menuSummary, equals('1 frukost, 2 lunch, 3 middag'));
      });
      
      test('should handle empty categories in summary', () {
        final partialMenu = SharedMenu(
          id: 'menu_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          menuTitle: 'Test',
          menuSnapshot: {
            'Middag': [dinnerRecipe1, dinnerRecipe2],
            'Lunch': [],
          },
        );
        
        expect(partialMenu.menuSummary, equals('2 middag'));
      });
      
      test('should format time ago text in Swedish', () {
        // Just now
        var menu = SharedMenu(
          id: 'menu_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          menuTitle: 'Test',
          menuSnapshot: testMenuSnapshot,
          sharedAt: DateTime.now().subtract(Duration(seconds: 30)),
        );
        expect(menu.timeAgoText, equals('Nu'));
        
        // Minutes
        menu = SharedMenu(
          id: 'menu_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          menuTitle: 'Test',
          menuSnapshot: testMenuSnapshot,
          sharedAt: DateTime.now().subtract(Duration(minutes: 30)),
        );
        expect(menu.timeAgoText, equals('30 min sedan'));
        
        // Hours
        menu = SharedMenu(
          id: 'menu_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          menuTitle: 'Test',
          menuSnapshot: testMenuSnapshot,
          sharedAt: DateTime.now().subtract(Duration(hours: 5)),
        );
        expect(menu.timeAgoText, equals('5 tim sedan'));
        
        // Days
        menu = SharedMenu(
          id: 'menu_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          menuTitle: 'Test',
          menuSnapshot: testMenuSnapshot,
          sharedAt: DateTime.now().subtract(Duration(days: 3)),
        );
        expect(menu.timeAgoText, equals('3 dagar sedan'));
        
        // Weeks
        menu = SharedMenu(
          id: 'menu_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          menuTitle: 'Test',
          menuSnapshot: testMenuSnapshot,
          sharedAt: DateTime.now().subtract(Duration(days: 14)),
        );
        expect(menu.timeAgoText, equals('2 veckor sedan'));
      });
    });
    
    group('Analytics Properties', () {
      test('should calculate conversion rate', () {
        // Start with base menu
        final baseMenu = SharedMenu(
          id: 'menu_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2', 'user_3', 'user_4', 'user_5'],
          menuTitle: 'Test',
          menuSnapshot: testMenuSnapshot,
        );
        
        // Simulate views and imports
        final viewedMenu = baseMenu
            .markViewedBy('user_2')
            .markViewedBy('user_3')
            .markViewedBy('user_4')
            .markViewedBy('user_5');
        
        final importedMenu = viewedMenu
            .markImportedBy('user_2')
            .markImportedBy('user_3');
        
        expect(importedMenu.conversionRate, equals(50.0)); // 2/4 * 100
      });
      
      test('should handle zero views in conversion rate', () {
        final menu = SharedMenu(
          id: 'menu_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          menuTitle: 'Test',
          menuSnapshot: testMenuSnapshot,
        );
        
        expect(menu.conversionRate, equals(0.0));
      });
      
      test('should count total interactions', () {
        final menu = SharedMenu(
          id: 'menu_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2', 'user_3'],
          menuTitle: 'Test',
          menuSnapshot: testMenuSnapshot,
          viewedByUserIds: ['user_2', 'user_3'],
          importedByUserIds: ['user_2'], // user_2 both viewed and imported
          dismissedByUserIds: ['user_4'],
        );
        
        expect(menu.totalInteractions, equals(3)); // 3 unique users
      });
      
      test('should identify most popular category', () {
        final menu = SharedMenu(
          id: 'menu_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          menuTitle: 'Test',
          menuSnapshot: testMenuSnapshot,
        );
        
        expect(menu.mostPopularCategory, equals('Middag')); // Has 3 recipes
      });
      
      test('should handle empty menu for most popular category', () {
        final emptyMenu = SharedMenu(
          id: 'menu_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          menuTitle: 'Empty',
          menuSnapshot: {},
        );
        
        expect(emptyMenu.mostPopularCategory, isNull);
      });
    });
    
    group('JSON Serialization', () {
      test('should serialize to JSON', () {
        final sharedTime = DateTime(2024, 1, 15, 10, 30);
        
        // Create menu with basic constructor and use markViewedBy/markImportedBy for counts
        final baseMenu = SharedMenu(
          id: 'menu_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2', 'user_3'],
          sharedAt: sharedTime,
          shareMessage: 'Enjoy!',
          menuTitle: 'Veckomeny',
          menuSnapshot: {'Middag': [dinnerRecipe1]},
          viewedByUserIds: ['user_2'],
          importedByUserIds: ['user_3'],
          dismissedByUserIds: ['user_4'],
          allowCollaboration: true,
        );
        
        // Simulate view and import counts
        var menu = baseMenu;
        for (int i = 0; i < 5; i++) {
          menu = menu.markViewedBy('viewer_$i');
        }
        for (int i = 0; i < 2; i++) {
          menu = menu.markImportedBy('importer_$i');
        }
        
        final json = menu.toJson();
        
        expect(json['id'], equals('menu_123'));
        expect(json['sharedByUserId'], equals('user_1'));
        expect(json['sharedByDisplayName'], equals('Anna'));
        expect(json['sharedToUserIds'], equals(['user_2', 'user_3']));
        expect(json['sharedAt'], equals(sharedTime.toIso8601String()));
        expect(json['shareMessage'], equals('Enjoy!'));
        expect(json['menuTitle'], equals('Veckomeny'));
        expect(json['totalRecipeCount'], equals(1));
        expect(json['categories'], equals(['Middag']));
        expect(json['viewCount'], equals(5));
        expect(json['importCount'], equals(2));
        expect(json['viewedByUserIds'], contains('user_2'));
        expect(json['viewedByUserIds'], contains('viewer_0'));
        expect(json['importedByUserIds'], contains('user_3'));
        expect(json['importedByUserIds'], contains('importer_0'));
        expect(json['dismissedByUserIds'], equals(['user_4']));
        expect(json['allowCollaboration'], isTrue);
        expect(json['menuSnapshot'], isNotNull);
        expect(json['menuSnapshot']['Middag'], isList);
      });
      
      test('should deserialize from JSON', () {
        final json = {
          'id': 'menu_123',
          'sharedByUserId': 'user_1',
          'sharedByDisplayName': 'Anna',
          'sharedToUserIds': ['user_2'],
          'sharedAt': '2024-01-15T10:30:00.000',
          'shareMessage': 'Test',
          'menuTitle': 'Test Menu',
          'menuSnapshot': {
            'Middag': [dinnerRecipe1.toJson()],
          },
          'totalRecipeCount': 1,
          'categories': ['Middag'],
          'viewCount': 3,
          'importCount': 1,
          'viewedByUserIds': ['user_2'],
          'importedByUserIds': [],
          'dismissedByUserIds': ['user_3'],
          'allowCollaboration': false,
        };
        
        final menu = SharedMenu.fromJson(json);
        
        expect(menu.id, equals('menu_123'));
        expect(menu.sharedByUserId, equals('user_1'));
        expect(menu.sharedByDisplayName, equals('Anna'));
        expect(menu.sharedToUserIds, equals(['user_2']));
        expect(menu.sharedAt, equals(DateTime(2024, 1, 15, 10, 30)));
        expect(menu.shareMessage, equals('Test'));
        expect(menu.menuTitle, equals('Test Menu'));
        expect(menu.totalRecipeCount, equals(1));
        expect(menu.viewCount, equals(3));
        expect(menu.dismissedByUserIds, equals(['user_3']));
        expect(menu.allowCollaboration, isFalse);
      });
    });
    
    group('Firestore Serialization', () {
      test('should serialize to Firestore format', () {
        final menu = SharedMenu(
          id: 'menu_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          shareMessage: 'Enjoy!',
          menuTitle: 'Veckomeny',
          menuSnapshot: {'Middag': [dinnerRecipe1]},
          allowCollaboration: true,
        );
        
        final firestore = menu.toFirestore();
        
        expect(firestore['sharedByUserId'], equals('user_1'));
        expect(firestore['sharedByDisplayName'], equals('Anna'));
        expect(firestore['sharedToUserIds'], equals(['user_2']));
        expect(firestore['shareMessage'], equals('Enjoy!'));
        expect(firestore['menuTitle'], equals('Veckomeny'));
        expect(firestore['totalRecipeCount'], equals(1));
        expect(firestore['categories'], equals(['Middag']));
        expect(firestore['viewCount'], equals(0));
        expect(firestore['importCount'], equals(0));
        expect(firestore['viewedByUserIds'], isEmpty);
        expect(firestore['importedByUserIds'], isEmpty);
        expect(firestore['dismissedByUserIds'], isEmpty);
        expect(firestore['allowCollaboration'], isTrue);
        expect(firestore.containsKey('id'), isFalse); // ID is document ID
        expect(firestore['menuSnapshot'], isNotNull);
      });
    });
    
    group('fromMap Factory', () {
      test('should create from map with menu snapshot', () {
        final data = {
          'sharedByUserId': 'user_1',
          'sharedByDisplayName': 'Anna',
          'sharedToUserIds': ['user_2'],
          'sharedAt': DateTime(2024, 1, 15),
          'shareMessage': 'Test',
          'menuTitle': 'Test Menu',
          'menuSnapshot': {
            'Middag': [
              {
                'id': 'recipe_1',
                'title': 'Test Recipe',
                'description': 'Test description',
                'ingredients': ['Ingredient 1'],
                'instructions': ['Step 1'],
                'imageUrls': [],
                'mealType': 'Middag',
                'portions': 4,
                'timeMinutes': 30,
                'rating': 4.5,
                'tags': ['test'],
                'sourceUrl': null,
                'createdAt': DateTime(2024, 1, 15).toIso8601String(),
                'updatedAt': DateTime(2024, 1, 15).toIso8601String(),
                'lastCookedAt': null,
              }
            ],
          },
          'totalRecipeCount': 1,
          'categories': ['Middag'],
          'viewCount': 2,
          'importCount': 1,
          'viewedByUserIds': ['user_2'],
          'importedByUserIds': [],
          'dismissedByUserIds': [],
          'allowCollaboration': false,
        };
        
        final menu = SharedMenu.fromMap('menu_123', data);
        
        expect(menu.id, equals('menu_123'));
        expect(menu.sharedByUserId, equals('user_1'));
        expect(menu.menuTitle, equals('Test Menu'));
        expect(menu.totalRecipeCount, equals(1));
        expect(menu.categories, equals(['Middag']));
        expect(menu.menuSnapshot['Middag']!.length, equals(1));
        expect(menu.menuSnapshot['Middag']!.first.title, equals('Test Recipe'));
      });
      
      test('should handle empty menu snapshot', () {
        final data = {
          'sharedByUserId': 'user_1',
          'sharedByDisplayName': 'Anna',
          'sharedToUserIds': ['user_2'],
          'sharedAt': DateTime(2024, 1, 15),
          'menuTitle': 'Empty Menu',
          'menuSnapshot': <String, dynamic>{},
          'totalRecipeCount': 0,
          'categories': <String>[],
        };
        
        final menu = SharedMenu.fromMap('menu_123', data);
        
        expect(menu.menuSnapshot, isEmpty);
        expect(menu.totalRecipeCount, equals(0));
        expect(menu.categories, isEmpty);
      });
    });
    
    group('Equality and Hashing', () {
      test('should be equal when IDs match', () {
        final menu1 = SharedMenu(
          id: 'menu_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          menuTitle: 'Menu 1',
          menuSnapshot: testMenuSnapshot,
        );
        
        final menu2 = SharedMenu(
          id: 'menu_123',
          sharedByUserId: 'user_3',
          sharedByDisplayName: 'Erik',
          sharedToUserIds: ['user_4'],
          menuTitle: 'Menu 2',
          menuSnapshot: {},
        );
        
        expect(menu1, equals(menu2));
        expect(menu1.hashCode, equals(menu2.hashCode));
      });
      
      test('should not be equal when IDs differ', () {
        final menu1 = SharedMenu(
          id: 'menu_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          menuTitle: 'Menu',
          menuSnapshot: testMenuSnapshot,
        );
        
        final menu2 = SharedMenu(
          id: 'menu_456',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          menuTitle: 'Menu',
          menuSnapshot: testMenuSnapshot,
        );
        
        expect(menu1, isNot(equals(menu2)));
      });
      
      test('should be equal to itself', () {
        final menu = SharedMenu(
          id: 'menu_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          menuTitle: 'Menu',
          menuSnapshot: testMenuSnapshot,
        );
        
        expect(menu, equals(menu));
      });
    });
    
    group('toString', () {
      test('should provide meaningful string representation', () {
        final menu = SharedMenu(
          id: 'menu_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna Andersson',
          sharedToUserIds: ['user_2', 'user_3'],
          menuTitle: 'Veckomeny v.45',
          menuSnapshot: testMenuSnapshot,
        );
        
        final str = menu.toString();
        
        expect(str, contains('menu_123'));
        expect(str, contains('Veckomeny v.45'));
        expect(str, contains('Anna Andersson'));
        expect(str, contains('6')); // Total recipe count
      });
    });
    
    group('Edge Cases', () {
      test('should handle empty recipient list', () {
        final menu = SharedMenu.create(
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: [],
          menuSnapshot: testMenuSnapshot,
        );
        
        expect(menu.sharedToUserIds, isEmpty);
      });
      
      test('should handle very long message', () {
        final longMessage = 'A' * 1000;
        final menu = SharedMenu.create(
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          shareMessage: longMessage,
          menuSnapshot: testMenuSnapshot,
        );
        
        expect(menu.shareMessage, equals(longMessage));
      });
      
      test('should handle menu with single category', () {
        final singleCategoryMenu = SharedMenu(
          id: 'menu_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          menuTitle: 'Middag Only',
          menuSnapshot: {
            'Middag': [dinnerRecipe1],
          },
        );
        
        expect(singleCategoryMenu.categories.length, equals(1));
        expect(singleCategoryMenu.menuSummary, equals('1 middag'));
        expect(singleCategoryMenu.mostPopularCategory, equals('Middag'));
      });
      
      test('should handle sharing to self', () {
        final menu = SharedMenu(
          id: 'menu_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_1'], // Sharing to self
          menuTitle: 'Self Share',
          menuSnapshot: testMenuSnapshot,
        );
        
        expect(menu.canBeViewedBy('user_1'), isTrue);
      });
      
      test('should preserve immutability with copyWith', () {
        final original = SharedMenu(
          id: 'menu_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          menuTitle: 'Original',
          menuSnapshot: testMenuSnapshot,
        );
        
        final modified = original.copyWith(
          viewCount: 5,
          allowCollaboration: true,
        );
        
        expect(original.viewCount, equals(0));
        expect(original.allowCollaboration, isFalse);
        expect(modified.viewCount, equals(5));
        expect(modified.allowCollaboration, isTrue);
        expect(original.id, equals(modified.id));
      });
    });
  });
}