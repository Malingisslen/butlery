import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/edit_mode.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'helpers/model_test_base.dart';
import '../../infrastructure/factories/recipe_factory.dart';

void main() {
  ModelTestBase.testModelGroup('SharedRecipe', () {
    late Recipe testRecipe;
    
    setUp(() {
      testRecipe = RecipeFactory.build(
        id: 'recipe_123',
        title: 'Köttbullar',
        description: 'Traditionella svenska köttbullar',
      );
    });
    
    group('Construction', () {
      test('should create with required parameters', () {
        final shared = SharedRecipe(
          id: 'shared_123',
          originalRecipeId: 'recipe_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna Andersson',
          sharedToUserIds: ['user_2'],
          recipeSnapshot: testRecipe,
        );
        
        expect(shared.id, equals('shared_123'));
        expect(shared.originalRecipeId, equals('recipe_123'));
        expect(shared.sharedByUserId, equals('user_1'));
        expect(shared.sharedByDisplayName, equals('Anna Andersson'));
        expect(shared.sharedToUserIds, equals(['user_2']));
        expect(shared.recipeSnapshot, equals(testRecipe));
        expect(shared.sharedAt, isNotNull);
        expect(shared.shareMessage, isNull);
        expect(shared.scope, equals(ShareScope.individual));
        expect(shared.allowImport, isTrue);
        expect(shared.allowCollaboration, isFalse);
        expect(shared.viewCount, equals(0));
        expect(shared.importCount, equals(0));
        expect(shared.viewedByUserIds, isEmpty);
        expect(shared.importedByUserIds, isEmpty);
        expect(shared.dismissedByUserIds, isEmpty);
      });
      
      test('should create with all parameters', () {
        final sharedTime = DateTime(2024, 1, 15, 10, 30);
        
        final shared = SharedRecipe(
          id: 'shared_123',
          originalRecipeId: 'recipe_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna Andersson',
          sharedToUserIds: ['user_2', 'user_3'],
          sharedAt: sharedTime,
          shareMessage: 'Hoppas ni gillar detta!',
          scope: ShareScope.multiple,
          allowImport: true,
          allowCollaboration: true,
          viewCount: 5,
          importCount: 2,
          viewedByUserIds: const ['user_2'],
          importedByUserIds: const ['user_3'],
          dismissedByUserIds: const ['user_4'],
          recipeSnapshot: testRecipe,
        );
        
        expect(shared.sharedAt, equals(sharedTime));
        expect(shared.shareMessage, equals('Hoppas ni gillar detta!'));
        expect(shared.scope, equals(ShareScope.multiple));
        expect(shared.allowCollaboration, isTrue);
        expect(shared.viewCount, equals(5));
        expect(shared.importCount, equals(2));
        expect(shared.viewedByUserIds, equals(['user_2']));
        expect(shared.importedByUserIds, equals(['user_3']));
        expect(shared.dismissedByUserIds, equals(['user_4']));
      });
    });
    
    group('Factory Methods', () {
      test('should create with auto-generated ID', () {
        final shared = SharedRecipe.create(
          originalRecipeId: 'recipe_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna Andersson',
          sharedToUserIds: ['user_2'],
          shareMessage: 'Varsågod!',
          recipeSnapshot: testRecipe,
        );
        
        expect(shared.id, isNotEmpty);
        expect(shared.id.length, equals(36)); // UUID v4 length
        expect(shared.shareMessage, equals('Varsågod!'));
      });
      
      test('should determine scope automatically for single recipient', () {
        final shared = SharedRecipe.create(
          originalRecipeId: 'recipe_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          recipeSnapshot: testRecipe,
        );
        
        expect(shared.scope, equals(ShareScope.individual));
      });
      
      test('should determine scope automatically for multiple recipients', () {
        final shared = SharedRecipe.create(
          originalRecipeId: 'recipe_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2', 'user_3', 'user_4'],
          recipeSnapshot: testRecipe,
        );
        
        expect(shared.scope, equals(ShareScope.multiple));
      });
      
      test('should use provided scope when specified', () {
        final shared = SharedRecipe.create(
          originalRecipeId: 'recipe_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          scope: ShareScope.friends,
          recipeSnapshot: testRecipe,
        );
        
        expect(shared.scope, equals(ShareScope.friends));
      });
    });
    
    group('User Engagement Tracking', () {
      late SharedRecipe shared;
      
      setUp(() {
        shared = SharedRecipe(
          id: 'shared_123',
          originalRecipeId: 'recipe_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2', 'user_3'],
          recipeSnapshot: testRecipe,
        );
      });
      
      test('should mark as viewed by user', () {
        final viewed = shared.markViewedBy('user_2');
        
        expect(viewed.viewCount, equals(1));
        expect(viewed.viewedByUserIds, contains('user_2'));
        expect(viewed.isViewedBy('user_2'), isTrue);
      });
      
      test('should not duplicate view count for same user', () {
        final viewed1 = shared.markViewedBy('user_2');
        final viewed2 = viewed1.markViewedBy('user_2');
        
        expect(viewed2.viewCount, equals(1));
        expect(viewed2.viewedByUserIds.length, equals(1));
        expect(viewed2, same(viewed1)); // Returns same instance
      });
      
      test('should mark as imported by user', () {
        final imported = shared.markImportedBy('user_3');
        
        expect(imported.importCount, equals(1));
        expect(imported.importedByUserIds, contains('user_3'));
        expect(imported.isImportedBy('user_3'), isTrue);
      });
      
      test('should not duplicate import count for same user', () {
        final imported1 = shared.markImportedBy('user_3');
        final imported2 = imported1.markImportedBy('user_3');
        
        expect(imported2.importCount, equals(1));
        expect(imported2.importedByUserIds.length, equals(1));
        expect(imported2, same(imported1)); // Returns same instance
      });
      
      test('should mark as dismissed by user', () {
        final dismissed = shared.markDismissedBy('user_2');
        
        expect(dismissed.dismissedByUserIds, contains('user_2'));
        expect(dismissed.isDismissedBy('user_2'), isTrue);
      });
      
      test('should not duplicate dismissal for same user', () {
        final dismissed1 = shared.markDismissedBy('user_2');
        final dismissed2 = dismissed1.markDismissedBy('user_2');
        
        expect(dismissed2.dismissedByUserIds.length, equals(1));
        expect(dismissed2, same(dismissed1)); // Returns same instance
      });
      
      test('should undismiss recipe for user', () {
        final dismissed = shared.markDismissedBy('user_2');
        final undismissed = dismissed.undismissBy('user_2');
        
        expect(undismissed.dismissedByUserIds, isEmpty);
        expect(undismissed.isDismissedBy('user_2'), isFalse);
      });
      
      test('should not change when undismissing non-dismissed user', () {
        final undismissed = shared.undismissBy('user_999');
        
        expect(undismissed, same(shared)); // Returns same instance
      });
    });
    
    group('Permission Checks', () {
      late SharedRecipe shared;
      
      setUp(() {
        shared = SharedRecipe(
          id: 'shared_123',
          originalRecipeId: 'recipe_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2', 'user_3'],
          viewedByUserIds: const ['user_2'],
          importedByUserIds: const ['user_3'],
          dismissedByUserIds: const ['user_4'],
          recipeSnapshot: testRecipe,
        );
      });
      
      test('should check if user is recipient', () {
        expect(shared.isSharedTo('user_2'), isTrue);
        expect(shared.isSharedTo('user_3'), isTrue);
        expect(shared.isSharedTo('user_4'), isFalse);
        expect(shared.isSharedTo('user_1'), isFalse); // Owner not in recipients
      });
      
      test('should check if user has viewed', () {
        expect(shared.isViewedBy('user_2'), isTrue);
        expect(shared.isViewedBy('user_3'), isFalse);
      });
      
      test('should check if user has imported', () {
        expect(shared.isImportedBy('user_3'), isTrue);
        expect(shared.isImportedBy('user_2'), isFalse);
      });
      
      test('should check if user has dismissed', () {
        expect(shared.isDismissedBy('user_4'), isTrue);
        expect(shared.isDismissedBy('user_2'), isFalse);
      });
      
      test('should check if user can view recipe', () {
        expect(shared.canBeViewedBy('user_1'), isTrue); // Owner can view
        expect(shared.canBeViewedBy('user_2'), isTrue); // Recipient can view
        expect(shared.canBeViewedBy('user_3'), isTrue); // Recipient can view
        expect(shared.canBeViewedBy('user_999'), isFalse); // Non-recipient cannot view
      });
    });
    
    group('Edit Mode Determination', () {
      test('should return owner mode for recipe owner', () {
        final shared = SharedRecipe(
          id: 'shared_123',
          originalRecipeId: 'recipe_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          recipeSnapshot: testRecipe,
        );
        
        expect(shared.getEditModeFor('user_1'), equals(EditMode.owner));
      });
      
      test('should return collaborative mode for recipient with collaboration', () {
        final shared = SharedRecipe(
          id: 'shared_123',
          originalRecipeId: 'recipe_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          allowCollaboration: true,
          recipeSnapshot: testRecipe,
        );
        
        expect(shared.getEditModeFor('user_2'), equals(EditMode.collaborative));
      });
      
      test('should return read-only mode for recipient without collaboration', () {
        final shared = SharedRecipe(
          id: 'shared_123',
          originalRecipeId: 'recipe_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          allowCollaboration: false,
          recipeSnapshot: testRecipe,
        );
        
        expect(shared.getEditModeFor('user_2'), equals(EditMode.readOnlyWithFork));
      });
      
      test('should return no access for non-recipient', () {
        final shared = SharedRecipe(
          id: 'shared_123',
          originalRecipeId: 'recipe_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          recipeSnapshot: testRecipe,
        );
        
        expect(shared.getEditModeFor('user_999'), equals(EditMode.noAccess));
      });
    });
    
    group('Recipe Import and Attribution', () {
      test('should create imported recipe with attribution', () {
        final shared = SharedRecipe(
          id: 'shared_123',
          originalRecipeId: 'recipe_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna Andersson',
          sharedToUserIds: ['user_2'],
          recipeSnapshot: testRecipe,
        );
        
        final imported = shared.createImportRecipe(newOwnerId: 'user_2');
        
        expect(imported.sourceUrl, equals('Inspirerat av recept från Anna Andersson'));
        expect(imported.id, equals(testRecipe.id)); // Keeps original ID structure
        expect(imported.title, equals(testRecipe.title));
      });
    });
    
    group('Display Properties', () {
      test('should provide correct permission level', () {
        final withCollab = SharedRecipe(
          id: 'shared_123',
          originalRecipeId: 'recipe_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          allowCollaboration: true,
          recipeSnapshot: testRecipe,
        );
        
        expect(withCollab.permission, equals(ResourcePermission.editor));
        
        final withoutCollab = SharedRecipe(
          id: 'shared_123',
          originalRecipeId: 'recipe_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          allowCollaboration: false,
          recipeSnapshot: testRecipe,
        );
        
        expect(withoutCollab.permission, equals(ResourcePermission.viewer));
      });
      
      test('should provide recipe alias getter', () {
        final shared = SharedRecipe(
          id: 'shared_123',
          originalRecipeId: 'recipe_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          recipeSnapshot: testRecipe,
        );
        
        expect(shared.recipe, equals(testRecipe));
        expect(shared.recipe, same(shared.recipeSnapshot));
      });
      
      test('should format time ago text in Swedish', () {
        // Just now
        var shared = SharedRecipe(
          id: 'shared_123',
          originalRecipeId: 'recipe_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          sharedAt: DateTime.now().subtract(Duration(seconds: 30)),
          recipeSnapshot: testRecipe,
        );
        expect(shared.timeAgoText, equals('Nu'));
        
        // Minutes
        shared = SharedRecipe(
          id: 'shared_123',
          originalRecipeId: 'recipe_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          sharedAt: DateTime.now().subtract(Duration(minutes: 30)),
          recipeSnapshot: testRecipe,
        );
        expect(shared.timeAgoText, equals('30 min sedan'));
        
        // Hours
        shared = SharedRecipe(
          id: 'shared_123',
          originalRecipeId: 'recipe_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          sharedAt: DateTime.now().subtract(Duration(hours: 5)),
          recipeSnapshot: testRecipe,
        );
        expect(shared.timeAgoText, equals('5 tim sedan'));
        
        // Days
        shared = SharedRecipe(
          id: 'shared_123',
          originalRecipeId: 'recipe_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          sharedAt: DateTime.now().subtract(Duration(days: 3)),
          recipeSnapshot: testRecipe,
        );
        expect(shared.timeAgoText, equals('3 dagar sedan'));
        
        // Weeks
        shared = SharedRecipe(
          id: 'shared_123',
          originalRecipeId: 'recipe_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          sharedAt: DateTime.now().subtract(Duration(days: 14)),
          recipeSnapshot: testRecipe,
        );
        expect(shared.timeAgoText, equals('2 veckor sedan'));
      });
    });
    
    group('JSON Serialization', () {
      test('should serialize to JSON', () {
        final sharedTime = DateTime(2024, 1, 15, 10, 30);
        
        final shared = SharedRecipe(
          id: 'shared_123',
          originalRecipeId: 'recipe_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2', 'user_3'],
          sharedAt: sharedTime,
          shareMessage: 'Enjoy!',
          scope: ShareScope.multiple,
          allowImport: true,
          allowCollaboration: true,
          viewCount: 5,
          importCount: 2,
          viewedByUserIds: const ['user_2'],
          importedByUserIds: const ['user_3'],
          dismissedByUserIds: const ['user_4'],
          recipeSnapshot: testRecipe,
        );
        
        final json = shared.toJson();
        
        expect(json['id'], equals('shared_123'));
        expect(json['originalRecipeId'], equals('recipe_123'));
        expect(json['sharedByUserId'], equals('user_1'));
        expect(json['sharedByDisplayName'], equals('Anna'));
        expect(json['sharedToUserIds'], equals(['user_2', 'user_3']));
        expect(json['sharedAt'], equals(sharedTime.toIso8601String()));
        expect(json['shareMessage'], equals('Enjoy!'));
        expect(json['scope'], equals('multiple'));
        expect(json['allowImport'], isTrue);
        expect(json['allowCollaboration'], isTrue);
        expect(json['viewCount'], equals(5));
        expect(json['importCount'], equals(2));
        expect(json['viewedByUserIds'], equals(['user_2']));
        expect(json['importedByUserIds'], equals(['user_3']));
        expect(json['dismissedByUserIds'], equals(['user_4']));
        expect(json['recipeSnapshot'], isNotNull);
      });
      
      test('should deserialize from JSON', () {
        final json = {
          'id': 'shared_123',
          'originalRecipeId': 'recipe_123',
          'sharedByUserId': 'user_1',
          'sharedByDisplayName': 'Anna',
          'sharedToUserIds': ['user_2'],
          'sharedAt': '2024-01-15T10:30:00.000',
          'shareMessage': 'Test',
          'scope': 'individual',
          'allowImport': true,
          'allowCollaboration': false,
          'viewCount': 3,
          'importCount': 1,
          'viewedByUserIds': ['user_2'],
          'importedByUserIds': [],
          'dismissedByUserIds': ['user_3'],
          'recipeSnapshot': testRecipe.toJson(),
        };
        
        final shared = SharedRecipe.fromJson(json);
        
        expect(shared.id, equals('shared_123'));
        expect(shared.originalRecipeId, equals('recipe_123'));
        expect(shared.sharedByUserId, equals('user_1'));
        expect(shared.sharedByDisplayName, equals('Anna'));
        expect(shared.sharedToUserIds, equals(['user_2']));
        expect(shared.sharedAt, equals(DateTime(2024, 1, 15, 10, 30)));
        expect(shared.shareMessage, equals('Test'));
        expect(shared.scope, equals(ShareScope.individual));
        expect(shared.viewCount, equals(3));
        expect(shared.dismissedByUserIds, equals(['user_3']));
      });
    });
    
    group('Firestore Serialization', () {
      test('should serialize to Firestore format', () {
        final shared = SharedRecipe(
          id: 'shared_123',
          originalRecipeId: 'recipe_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          shareMessage: 'Enjoy!',
          allowCollaboration: true,
          recipeSnapshot: testRecipe,
        );
        
        final firestore = shared.toFirestore();
        
        expect(firestore['originalRecipeId'], equals('recipe_123'));
        expect(firestore['sharedByUserId'], equals('user_1'));
        expect(firestore['sharedByDisplayName'], equals('Anna'));
        expect(firestore['sharedToUserIds'], equals(['user_2']));
        expect(firestore['shareMessage'], equals('Enjoy!'));
        expect(firestore['scope'], equals('individual'));
        expect(firestore['allowImport'], isTrue);
        expect(firestore['allowCollaboration'], isTrue);
        expect(firestore['viewCount'], equals(0));
        expect(firestore['importCount'], equals(0));
        expect(firestore['viewedByUserIds'], isEmpty);
        expect(firestore['importedByUserIds'], isEmpty);
        expect(firestore['dismissedByUserIds'], isEmpty);
        expect(firestore.containsKey('id'), isFalse); // ID is document ID
        expect(firestore['recipeSnapshot'], isNotNull);
      });
    });
    
    group('fromMap Factory', () {
      test('should create from map with recipe snapshot', () {
        final data = {
          'originalRecipeId': 'recipe_123',
          'sharedByUserId': 'user_1',
          'sharedByDisplayName': 'Anna',
          'sharedToUserIds': ['user_2'],
          'sharedAt': DateTime(2024, 1, 15),
          'shareMessage': 'Test',
          'scope': 'individual',
          'allowImport': true,
          'allowCollaboration': false,
          'viewCount': 2,
          'importCount': 1,
          'viewedByUserIds': ['user_2'],
          'importedByUserIds': [],
          'dismissedByUserIds': [],
          'recipeSnapshot': {
            'id': 'recipe_123',
            'title': 'Test Recipe',
            'description': 'Test description',
            'ingredients': ['Ingredient 1'],
            'instructions': ['Step 1'],
            'imageUrls': [],
            'mealType': 'Lunch',
            'portions': 4,
            'timeMinutes': 30,
            'rating': 4.5,
            'tags': ['test'],
            'sourceUrl': null,
            'createdAt': DateTime(2024, 1, 15).toIso8601String(),
            'updatedAt': DateTime(2024, 1, 15).toIso8601String(),
            'lastCookedAt': null,
          },
        };
        
        final shared = SharedRecipe.fromMap('shared_123', data);
        
        expect(shared.id, equals('shared_123'));
        expect(shared.originalRecipeId, equals('recipe_123'));
        expect(shared.sharedByUserId, equals('user_1'));
        expect(shared.recipeSnapshot.title, equals('Test Recipe'));
        expect(shared.recipeSnapshot.type, equals(RecipeType.shared));
      });
    });
    
    group('Equality and Hashing', () {
      test('should be equal when IDs match', () {
        final shared1 = SharedRecipe(
          id: 'shared_123',
          originalRecipeId: 'recipe_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          recipeSnapshot: testRecipe,
        );
        
        final shared2 = SharedRecipe(
          id: 'shared_123',
          originalRecipeId: 'recipe_456',
          sharedByUserId: 'user_3',
          sharedByDisplayName: 'Erik',
          sharedToUserIds: ['user_4'],
          recipeSnapshot: testRecipe,
        );
        
        expect(shared1, equals(shared2));
        expect(shared1.hashCode, equals(shared2.hashCode));
      });
      
      test('should not be equal when IDs differ', () {
        final shared1 = SharedRecipe(
          id: 'shared_123',
          originalRecipeId: 'recipe_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          recipeSnapshot: testRecipe,
        );
        
        final shared2 = SharedRecipe(
          id: 'shared_456',
          originalRecipeId: 'recipe_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          recipeSnapshot: testRecipe,
        );
        
        expect(shared1, isNot(equals(shared2)));
      });
      
      test('should be equal to itself', () {
        final shared = SharedRecipe(
          id: 'shared_123',
          originalRecipeId: 'recipe_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          recipeSnapshot: testRecipe,
        );
        
        expect(shared, equals(shared));
      });
    });
    
    group('toString', () {
      test('should provide meaningful string representation', () {
        final shared = SharedRecipe(
          id: 'shared_123',
          originalRecipeId: 'recipe_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna Andersson',
          sharedToUserIds: ['user_2', 'user_3'],
          recipeSnapshot: testRecipe,
        );
        
        final str = shared.toString();
        
        expect(str, contains('shared_123'));
        expect(str, contains('Köttbullar')); // Recipe title
        expect(str, contains('Anna Andersson'));
        expect(str, contains('2')); // Number of recipients
      });
    });
    
    group('Edge Cases', () {
      test('should handle empty recipient list', () {
        final shared = SharedRecipe.create(
          originalRecipeId: 'recipe_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: [],
          recipeSnapshot: testRecipe,
        );
        
        expect(shared.sharedToUserIds, isEmpty);
        expect(shared.scope, equals(ShareScope.multiple)); // Empty list treated as multiple
      });
      
      test('should handle very long message', () {
        final longMessage = 'A' * 1000;
        final shared = SharedRecipe.create(
          originalRecipeId: 'recipe_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          shareMessage: longMessage,
          recipeSnapshot: testRecipe,
        );
        
        expect(shared.shareMessage, equals(longMessage));
      });
      
      test('should handle sharing to self', () {
        final shared = SharedRecipe(
          id: 'shared_123',
          originalRecipeId: 'recipe_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_1'], // Sharing to self
          recipeSnapshot: testRecipe,
        );
        
        expect(shared.canBeViewedBy('user_1'), isTrue);
        expect(shared.getEditModeFor('user_1'), equals(EditMode.owner));
      });
      
      test('should preserve immutability with copyWith', () {
        final original = SharedRecipe(
          id: 'shared_123',
          originalRecipeId: 'recipe_123',
          sharedByUserId: 'user_1',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['user_2'],
          viewCount: 0,
          recipeSnapshot: testRecipe,
        );
        
        final modified = original.copyWith(viewCount: 5);
        
        expect(original.viewCount, equals(0));
        expect(modified.viewCount, equals(5));
        expect(original.id, equals(modified.id));
      });
    });
  });
}