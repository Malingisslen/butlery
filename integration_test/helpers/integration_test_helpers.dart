import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/messaging/conversation.dart';
import '../../test/helpers/mock_factories.dart';
import '../../test/helpers/firebase_test_helper.dart';

/// Helper class for integration tests
class IntegrationTestHelpers {
  static late FakeFirebaseFirestore fakeFirestore;
  static late MockFirebaseAuth mockAuth;
  static const String testUserId = 'test-user-123';
  static const String testEmail = 'test@example.com';
  
  /// Initialize test Firebase for integration tests
  static Future<void> initializeTestFirebase() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    
    // Create test user
    final testUser = FirebaseTestHelper.createMockUser(
      uid: testUserId,
      email: testEmail,
      displayName: 'Test User',
    );
    
    // Initialize Firebase
    await FirebaseTestHelper.initializeFirebase(
      initialUser: testUser,
      firestoreData: _createInitialTestData(),
    );
    
    fakeFirestore = FirebaseTestHelper.fakeFirestore;
    mockAuth = FirebaseTestHelper.mockAuth;
  }
  
  /// Create initial test data
  static Map<String, dynamic> _createInitialTestData() {
    // Create test user profile
    final userProfile = UserProfileFactory.build(
      uid: testUserId,
      email: testEmail,
      displayName: 'Test User',
    );
    
    return {
      'users': {
        testUserId: _userProfileToMap(userProfile),
      },
      'recipes': {},
      'shopping_lists': {},
      'conversations': {},
    };
  }
  
  static Map<String, dynamic> _userProfileToMap(UserProfile profile) {
    return {
      'uid': profile.uid,
      'email': profile.email,
      'displayName': profile.displayName,
      'avatarUrl': profile.avatarUrl,
      'bio': profile.bio,
      'isSearchable': profile.isSearchable,
      'allowEmailSearch': profile.allowEmailSearch,
      'publicRecipeCount': profile.publicRecipeCount,
      'friendsCount': profile.friendsCount,
      'joinedAt': profile.joinedAt.toIso8601String(),
      'lastActiveAt': profile.lastActiveAt.toIso8601String(),
      'isOnline': profile.isOnline,
      'fcmToken': profile.fcmToken,
      'fcmTokenUpdatedAt': profile.fcmTokenUpdatedAt?.toIso8601String(),
      'notificationsEnabled': profile.notificationsEnabled,
    };
  }
  
  /// Seed test recipes
  static Future<void> seedTestRecipes(int count) async {
    final recipes = <String, Map<String, dynamic>>{};
    
    for (int i = 0; i < count; i++) {
      final recipe = RecipeFactory.build(
        id: 'recipe_$i',
        title: 'Recipe $i - ${_getRecipeTitle(i)}',
        description: 'Description for recipe $i',
        userId: testUserId,
        tags: _getRecipeTags(i),
      );
      recipes[recipe.id] = _recipeToMap(recipe);
    }
    
    await fakeFirestore.collection('recipes').doc(testUserId).set({
      'recipes': recipes,
    });
  }
  
  static Map<String, dynamic> _recipeToMap(Recipe recipe) {
    return {
      'id': recipe.id,
      'title': recipe.title,
      'description': recipe.description,
      'ingredients': recipe.ingredients,
      'instructions': recipe.instructions,
      'portions': recipe.portions,
      'timeMinutes': recipe.timeMinutes,
      'imageUrls': recipe.imageUrls,
      'sourceUrl': recipe.sourceUrl,
      'createdBy': recipe.createdBy,
      'createdAt': recipe.createdAt.toIso8601String(),
      'updatedAt': recipe.updatedAt.toIso8601String(),
      'isPublic': recipe.isPublic,
      'tags': recipe.tags,
      'mealType': recipe.mealType,
      'rating': recipe.rating,
    };
  }
  
  /// Get recipe title based on index
  static String _getRecipeTitle(int index) {
    final titles = [
      'Pasta Carbonara',
      'Chicken Tikka Masala',
      'Vegetarian Lasagna',
      'Thai Green Curry',
      'Chocolate Brownies',
      'Caesar Salad',
      'Beef Tacos',
      'Mushroom Risotto',
      'Apple Pie',
      'Sushi Rolls',
    ];
    return titles[index % titles.length];
  }
  
  /// Get recipe tags based on index
  static List<String> _getRecipeTags(int index) {
    final allTags = [
      ['Italian', 'Pasta', 'Quick'],
      ['Indian', 'Spicy', 'Chicken'],
      ['Vegetarian', 'Italian', 'Comfort Food'],
      ['Thai', 'Spicy', 'Vegan'],
      ['Dessert', 'Chocolate', 'Baking'],
      ['Salad', 'Healthy', 'Quick'],
      ['Mexican', 'Beef', 'Easy'],
      ['Italian', 'Vegetarian', 'Rice'],
      ['Dessert', 'Baking', 'Fruit'],
      ['Japanese', 'Seafood', 'Advanced'],
    ];
    return allTags[index % allTags.length];
  }
  
  /// Create test shopping lists
  static Future<void> seedTestShoppingLists(int count) async {
    final lists = <String, Map<String, dynamic>>{};
    
    for (int i = 0; i < count; i++) {
      final list = ShoppingListFactory.build(
        id: 'list_$i',
        name: 'Shopping List $i',
        userId: testUserId,
      );
      lists[list.id] = _shoppingListToMap(list);
    }
    
    await fakeFirestore.collection('shopping_lists').doc(testUserId).set({
      'lists': lists,
    });
  }
  
  static Map<String, dynamic> _shoppingListToMap(UnifiedShoppingList list) {
    return {
      'id': list.id,
      'name': list.name,
      'ownerId': list.ownerId,
      'ownerDisplayName': list.ownerDisplayName,
      'items': list.items.map((item) => {
        'id': item.id,
        'name': item.name,
        'amount': item.amount,
        'unit': item.unit,
        'category': item.category,
        'bought': item.bought,
        'addedByUserId': item.addedByUserId,
        'addedByDisplayName': item.addedByDisplayName,
        'addedAt': item.addedAt?.toIso8601String(),
        'purchasedByUserId': item.purchasedByUserId,
        'purchasedByDisplayName': item.purchasedByDisplayName,
        'purchasedAt': item.purchasedAt?.toIso8601String(),
        'note': item.note,
        'estimatedPrice': item.estimatedPrice,
        'priority': item.priority,
      }).toList(),
      'createdAt': list.createdAt.toIso8601String(),
      'updatedAt': list.updatedAt.toIso8601String(),
      'lastSyncedAt': list.lastSyncedAt?.toIso8601String(),
      'syncStatus': list.syncStatus.name,
      'type': list.type.name,
      'memberPermissions': list.memberPermissions.map((k, v) => MapEntry(k, v.name)),
      'lastActivityAt': list.lastActivityAt?.toIso8601String(),
      'lastActivityByUserId': list.lastActivityByUserId,
      'lastActivityByDisplayName': list.lastActivityByDisplayName,
      'description': list.description,
      'settings': list.settings,
      'categoryIds': list.categoryIds,
      'allowGuestEditing': list.allowGuestEditing,
      'autoRemoveCompleted': list.autoRemoveCompleted,
    };
  }
  
  /// Create test conversations
  static Future<void> seedTestConversations(int count) async {
    for (int i = 0; i < count; i++) {
      final conversation = ConversationFactory.build(
        id: 'conv_$i',
        participantIds: [testUserId, 'friend_$i'],
      );
      
      await fakeFirestore
          .collection('conversations')
          .doc(conversation.id)
          .set(_conversationToMap(conversation));
    }
  }
  
  static Map<String, dynamic> _conversationToMap(Conversation conversation) {
    return {
      'id': conversation.id,
      'participantIds': conversation.participantIds,
      'participantDisplayNames': conversation.participantDisplayNames,
      'participantAvatarUrls': conversation.participantAvatarUrls,
      'lastMessage': conversation.lastMessage != null ? {
        'id': conversation.lastMessage!.id,
        'conversationId': conversation.lastMessage!.conversationId,
        'senderId': conversation.lastMessage!.senderId,
        'senderDisplayName': conversation.lastMessage!.senderDisplayName,
        'content': conversation.lastMessage!.content,
        'sentAt': conversation.lastMessage!.sentAt.toIso8601String(),
        'isRead': conversation.lastMessage!.isRead,
        'isSystemMessage': conversation.lastMessage!.isSystemMessage,
        'metadata': conversation.lastMessage!.metadata,
      } : null,
      'lastReadTimestamps': conversation.lastReadTimestamps.map((k, v) => MapEntry(k, v.toIso8601String())),
      'createdAt': conversation.createdAt.toIso8601String(),
      'updatedAt': conversation.updatedAt.toIso8601String(),
      'title': conversation.title,
      'isGroup': conversation.isGroup,
      'metadata': conversation.metadata,
    };
  }
  
  /// Clean up test data
  static Future<void> cleanup() async {
    // Clear all collections
    await _clearCollection('users');
    await _clearCollection('recipes');
    await _clearCollection('shopping_lists');
    await _clearCollection('conversations');
    await _clearCollection('messages');
    
    FirebaseTestHelper.cleanup();
  }
  
  /// Clear a Firestore collection
  static Future<void> _clearCollection(String collection) async {
    final snapshot = await fakeFirestore.collection(collection).get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
  
  /// Wait for a condition to be true
  static Future<void> waitForCondition(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 10),
    Duration interval = const Duration(milliseconds: 100),
  }) async {
    final endTime = DateTime.now().add(timeout);
    
    while (!condition()) {
      if (DateTime.now().isAfter(endTime)) {
        throw Exception('Condition not met within timeout');
      }
      await Future.delayed(interval);
    }
  }
  
  /// Simulate network delay
  static Future<void> simulateNetworkDelay({
    Duration delay = const Duration(milliseconds: 500),
  }) async {
    await Future.delayed(delay);
  }
  
  /// Get current user ID
  static String getCurrentUserId() {
    return mockAuth.currentUser?.uid ?? testUserId;
  }
  
  /// Sign out current user
  static Future<void> signOut() async {
    await mockAuth.signOut();
  }
  
  /// Sign in test user
  static Future<void> signInTestUser() async {
    await mockAuth.signInWithEmailAndPassword(
      email: testEmail,
      password: 'password123',
    );
  }
}

// PatrolTesterHelpers extension removed - Patrol has different API
// Use Patrol's built-in methods instead
/*
extension PatrolTesterHelpers on PatrolIntegrationTester {
  /// Wait for a widget with retry
  Future<void> waitFor(
    Finder finder, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final endTime = DateTime.now().add(timeout);
    
    while (!any(finder)) {
      if (DateTime.now().isAfter(endTime)) {
        throw TestFailure('Widget not found: $finder');
      }
      await pump(const Duration(milliseconds: 100));
    }
  }
  
  /// Scroll to a widget with retry
  Future<void> scrollTo(
    Finder finder, {
    Finder? scrollable,
    double delta = 300,
    int maxScrolls = 20,
  }) async {
    scrollable ??= find.byType(Scrollable).first;
    
    for (int i = 0; i < maxScrolls; i++) {
      if (any(finder)) {
        return;
      }
      
      await drag(scrollable, Offset(0, -delta));
      await pumpAndSettle();
    }
    
    throw TestFailure('Could not find widget after $maxScrolls scrolls');
  }
  
  /// Long press with options
  Future<void> longPress(
    Finder finder, {
    Duration duration = const Duration(seconds: 1),
  }) async {
    final gesture = await startGesture(getCenter(finder));
    await pump(duration);
    await gesture.up();
    await pumpAndSettle();
  }
  
  /// Verify accessibility
  Future<void> verifyAccessibility(Finder finder) async {
    final semantics = getSemantics(finder);
    
    // Check for basic accessibility properties
    expect(semantics.label.isNotEmpty || semantics.hint.isNotEmpty, isTrue,
        reason: 'Widget should have label or hint for accessibility');
    
    // Check touch target size (minimum 48x48)
    final renderObject = firstRenderObject(finder);
    if (renderObject != null) {
      final size = renderObject.paintBounds.size;
      expect(size.width >= 48 && size.height >= 48, isTrue,
          reason: 'Touch target should be at least 48x48 pixels');
    }
  }
}
*/

/// Test data patterns for common scenarios
class TestDataPatterns {
  /// Create a recipe with all features
  static Map<String, dynamic> createFullFeaturedRecipe() {
    final recipe = RecipeFactory.build(
      title: 'Full Featured Recipe',
      description: 'A recipe showcasing all features',
      ingredients: List.generate(10, (i) => 'Ingredient ${i + 1}'),
      instructions: List.generate(8, (i) => 'Step ${i + 1}: Detailed instruction'),
      timeMinutes: 60,
      portions: 6,
      tags: ['Gourmet', 'Special Occasion', 'Advanced'],
      imageUrls: ['https://example.com/featured-recipe.jpg'],
    );
    return IntegrationTestHelpers._recipeToMap(recipe);
  }
  
  /// Create a minimal recipe
  static Map<String, dynamic> createMinimalRecipe() {
    return {
      'id': faker.guid.guid(),
      'title': 'Quick Recipe',
      'ingredients': [
        {'name': 'Main ingredient', 'amount': 1, 'unit': 'st'},
      ],
      'instructions': ['Cook and serve'],
      'servings': 2,
      'ownerId': IntegrationTestHelpers.testUserId,
    };
  }
  
  /// Create recipes for search testing
  static List<Map<String, dynamic>> createSearchTestRecipes() {
    return [
      IntegrationTestHelpers._recipeToMap(RecipeFactory.build(title: 'Pasta Carbonara', tags: ['Italian', 'Pasta'])),
      IntegrationTestHelpers._recipeToMap(RecipeFactory.build(title: 'Pasta Bolognese', tags: ['Italian', 'Pasta'])),
      IntegrationTestHelpers._recipeToMap(RecipeFactory.build(title: 'Chicken Pasta', tags: ['Italian', 'Chicken'])),
      IntegrationTestHelpers._recipeToMap(RecipeFactory.build(title: 'Vegetarian Lasagna', tags: ['Italian', 'Vegetarian'])),
      IntegrationTestHelpers._recipeToMap(RecipeFactory.build(title: 'Thai Curry', tags: ['Thai', 'Spicy'])),
    ];
  }
}