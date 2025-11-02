# Integration Testing Patterns

Integration tests verify that multiple components work together correctly in realistic scenarios. This guide covers end-to-end testing patterns for Butlery.

## Testing Philosophy

Integration tests validate:
- Complete user flows across multiple screens
- Real Firebase operations (with test projects)
- Authentication and authorization flows
- Real-time synchronization between clients
- Data persistence and consistency
- Cross-layer integration (UI → ViewModel → Service → Repository → Firebase)

**When to write integration tests:**
- Critical user journeys (account creation, recipe sharing, collaborative shopping)
- Features requiring multi-step interactions
- Real-time collaboration features
- Payment or security-critical flows
- Features with complex state management

## Test Structure

Integration tests live in `test/integration/`:

```
test/
  integration/
    firebase/
      account_deletion_integration_test.dart
      recipe_sharing_integration_test.dart
      collaborative_shopping_integration_test.dart
    flows/
      recipe_creation_flow_test.dart
      friend_request_flow_test.dart
      menu_planning_flow_test.dart
    realtime/
      realtime_recipe_sync_test.dart
      presence_tracking_test.dart
```

## Basic Integration Test Setup

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:butlery/core/di/application_bootstrap.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    // Initialize DI with test doubles
    await ApplicationBootstrap.initializeForTesting(
      firestore: firestore,
    );
  });

  tearDown(() async {
    await ApplicationBootstrap.dispose();
  });

  group('Recipe Creation Flow', () {
    testWidgets('complete recipe creation journey', (tester) async {
      // Integration test implementation
    });
  });
}
```

## Testing Complete User Flows

### Recipe Creation Flow

```dart
testWidgets('user creates and saves recipe', (tester) async {
  // Arrange - Setup authenticated user
  final authService = ServiceLocator.get<AuthService>();
  await authService.signInForTesting('test@example.com');

  await tester.pumpWidget(MyApp());
  await tester.pumpAndSettle();

  // Act - Navigate to create recipe
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();

  // Enter recipe details
  await tester.enterText(
    find.byKey(Key('title_field')),
    'Integration Test Recipe',
  );
  await tester.enterText(
    find.byKey(Key('portions_field')),
    '4',
  );

  // Add ingredients
  await tester.tap(find.text('Add Ingredient'));
  await tester.pumpAndSettle();

  await tester.enterText(
    find.byKey(Key('ingredient_name')),
    'Flour',
  );
  await tester.enterText(
    find.byKey(Key('ingredient_amount')),
    '2 cups',
  );
  await tester.tap(find.text('Done'));
  await tester.pumpAndSettle();

  // Add instructions
  await tester.tap(find.text('Add Instruction'));
  await tester.pumpAndSettle();

  await tester.enterText(
    find.byKey(Key('instruction_field')),
    'Mix ingredients well',
  );

  // Save recipe
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();

  // Assert - Verify recipe saved and appears in list
  expect(find.text('Integration Test Recipe'), findsOneWidget);

  // Verify in Firebase
  final recipeService = ServiceLocator.get<UnifiedRecipeService>();
  final recipes = await recipeService.personal.getUserRecipes();

  expect(recipes.length, 1);
  expect(recipes.first.title, 'Integration Test Recipe');
  expect(recipes.first.portions, 4);
  expect(recipes.first.ingredients.first.name, 'Flour');
});
```

### Recipe Sharing Flow

```dart
testWidgets('user shares recipe with friend', (tester) async {
  // Arrange - Setup two users
  final firestore = FakeFirebaseFirestore();

  // Create owner user
  await firestore.collection('users').doc('user_1').set({
    'email': 'owner@example.com',
    'displayName': 'Recipe Owner',
  });

  // Create friend user
  await firestore.collection('users').doc('user_2').set({
    'email': 'friend@example.com',
    'displayName': 'Friend User',
  });

  // Create recipe
  final recipeDoc = await firestore
      .collection('users')
      .doc('user_1')
      .collection('recipes')
      .add({
    'title': 'Shared Recipe',
    'userId': 'user_1',
    'visibility': 'private',
  });

  // Sign in as owner
  final authService = ServiceLocator.get<AuthService>();
  await authService.signInForTesting('owner@example.com');

  await tester.pumpWidget(MyApp());
  await tester.pumpAndSettle();

  // Act - Open recipe detail
  await tester.tap(find.text('Shared Recipe'));
  await tester.pumpAndSettle();

  // Tap share button
  await tester.tap(find.byIcon(Icons.share));
  await tester.pumpAndSettle();

  // Select friend
  await tester.tap(find.text('Friend User'));
  await tester.pumpAndSettle();

  // Confirm sharing
  await tester.tap(find.text('Share'));
  await tester.pumpAndSettle();

  // Assert - Verify shared recipe created
  final sharedRecipes = await firestore
      .collection('sharedRecipes')
      .where('ownerId', isEqualTo: 'user_1')
      .get();

  expect(sharedRecipes.docs.length, 1);
  expect(sharedRecipes.docs.first['sharedWith'], contains('user_2'));

  // Verify friend can see recipe
  await authService.signInForTesting('friend@example.com');
  await tester.pumpAndSettle();

  await tester.tap(find.text('Shared With Me'));
  await tester.pumpAndSettle();

  expect(find.text('Shared Recipe'), findsOneWidget);
});
```

## Testing Real-time Features

### Collaborative Recipe Editing

```dart
testWidgets('two users edit recipe simultaneously', (tester) async {
  // Arrange - Create shared recipe
  final firestore = FakeFirebaseFirestore();

  final recipeRef = firestore.collection('sharedRecipes').doc('recipe_1');
  await recipeRef.set({
    'title': 'Collaborative Recipe',
    'ownerId': 'user_1',
    'sharedWith': ['user_2'],
    'currentEditors': [],
  });

  // User 1 opens recipe for editing
  final realtimeService1 = UnifiedRecipeService(
    firestore: firestore,
    userId: 'user_1',
  );
  await realtimeService1.realtime.startEditing('recipe_1');

  // User 2 opens same recipe
  final realtimeService2 = UnifiedRecipeService(
    firestore: firestore,
    userId: 'user_2',
  );
  await realtimeService2.realtime.startEditing('recipe_1');

  // Act - User 1 updates title
  await realtimeService1.realtime.updateField(
    'recipe_1',
    'title',
    'Updated by User 1',
  );

  // Wait for real-time sync
  await Future.delayed(Duration(milliseconds: 100));

  // Assert - User 2 sees the change
  final recipe2 = await realtimeService2.realtime.getRecipe('recipe_1');
  expect(recipe2?.title, 'Updated by User 1');

  // Verify both users shown as current editors
  final recipeDoc = await recipeRef.get();
  final editors = List<String>.from(recipeDoc['currentEditors']);
  expect(editors, containsAll(['user_1', 'user_2']));

  // Cleanup - Both users stop editing
  await realtimeService1.realtime.stopEditing('recipe_1');
  await realtimeService2.realtime.stopEditing('recipe_1');

  final finalDoc = await recipeRef.get();
  expect(finalDoc['currentEditors'], isEmpty);
});
```

### Presence Tracking

```dart
test('tracks user presence in collaborative list', () async {
  final firestore = FakeFirebaseFirestore();
  final presenceService = PresenceService(firestore: firestore);

  // User joins
  await presenceService.joinList('list_1', 'user_1');

  var presence = await firestore
      .collection('shoppingLists')
      .doc('list_1')
      .get();

  expect(presence['activeUsers'], contains('user_1'));

  // Second user joins
  await presenceService.joinList('list_1', 'user_2');

  presence = await firestore
      .collection('shoppingLists')
      .doc('list_1')
      .get();

  expect(presence['activeUsers'], containsAll(['user_1', 'user_2']));

  // First user leaves
  await presenceService.leaveList('list_1', 'user_1');

  presence = await firestore
      .collection('shoppingLists')
      .doc('list_1')
      .get();

  expect(presence['activeUsers'], ['user_2']);
});
```

## Testing Authentication Flows

### Account Creation Flow

```dart
testWidgets('new user creates account', (tester) async {
  await tester.pumpWidget(MyApp());
  await tester.pumpAndSettle();

  // Navigate to sign up
  await tester.tap(find.text('Create Account'));
  await tester.pumpAndSettle();

  // Enter account details
  await tester.enterText(
    find.byKey(Key('email_field')),
    'newuser@example.com',
  );
  await tester.enterText(
    find.byKey(Key('password_field')),
    'SecurePassword123',
  );
  await tester.enterText(
    find.byKey(Key('display_name_field')),
    'New User',
  );

  // Submit
  await tester.tap(find.text('Sign Up'));
  await tester.pumpAndSettle();

  // Assert - User created and navigated to home
  expect(find.text('My Recipes'), findsOneWidget);

  final authService = ServiceLocator.get<AuthService>();
  final currentUser = authService.currentUser;
  expect(currentUser, isNotNull);
  expect(currentUser!.email, 'newuser@example.com');
});
```

### Password Reset Flow

```dart
testWidgets('user resets password', (tester) async {
  // Arrange - Create existing user
  final authService = ServiceLocator.get<AuthService>();
  await authService.createUser('user@example.com', 'OldPassword123');

  await tester.pumpWidget(MyApp());
  await tester.pumpAndSettle();

  // Navigate to forgot password
  await tester.tap(find.text('Forgot Password?'));
  await tester.pumpAndSettle();

  // Enter email
  await tester.enterText(
    find.byKey(Key('email_field')),
    'user@example.com',
  );

  await tester.tap(find.text('Send Reset Link'));
  await tester.pumpAndSettle();

  // Assert - Success message shown
  expect(find.text('Password reset email sent'), findsOneWidget);

  // Verify email sent (in test environment, just verify method called)
  final mockEmailService = ServiceLocator.get<EmailService>();
  verify(() => mockEmailService.sendPasswordReset('user@example.com'))
      .called(1);
});
```

## Testing GDPR Compliance

### Account Deletion Flow

```dart
test('account deletion removes all user data', () async {
  // Arrange - Create user with full data set
  final firestore = FakeFirebaseFirestore();
  final userId = 'user_1';

  // Create user profile
  await firestore.collection('users').doc(userId).set({
    'email': 'user@example.com',
    'displayName': 'Test User',
  });

  // Create user content
  await firestore
      .collection('users')
      .doc(userId)
      .collection('recipes')
      .add({'title': 'Recipe 1'});

  await firestore
      .collection('users')
      .doc(userId)
      .collection('menus')
      .add({'title': 'Menu 1'});

  await firestore
      .collection('users')
      .doc(userId)
      .collection('shoppingLists')
      .add({'title': 'List 1'});

  // Create social data
  await firestore.collection('comments').add({
    'userId': userId,
    'text': 'Comment',
  });

  await firestore.collection('ratings').add({
    'userId': userId,
    'rating': 5,
  });

  // Act - Delete account
  final deletionService = ServiceLocator.get<AccountDeletionService>();
  await deletionService.deleteAccount(userId);

  // Assert - All user data removed
  final userDoc = await firestore.collection('users').doc(userId).get();
  expect(userDoc.exists, isFalse);

  final recipes = await firestore
      .collection('users')
      .doc(userId)
      .collection('recipes')
      .get();
  expect(recipes.docs, isEmpty);

  final menus = await firestore
      .collection('users')
      .doc(userId)
      .collection('menus')
      .get();
  expect(menus.docs, isEmpty);

  final comments = await firestore
      .collection('comments')
      .where('userId', isEqualTo: userId)
      .get();
  expect(comments.docs, isEmpty);

  // Verify audit log created
  final auditLogs = await firestore
      .collection('auditLogs')
      .where('userId', isEqualTo: userId)
      .where('action', isEqualTo: 'account_deleted')
      .get();
  expect(auditLogs.docs.length, 1);
});
```

### Data Export Flow

```dart
test('data export includes all user content', () async {
  // Arrange - Create user with content
  final userId = 'user_1';
  final firestore = FakeFirebaseFirestore();

  await firestore.collection('users').doc(userId).set({
    'email': 'user@example.com',
    'displayName': 'Test User',
  });

  await firestore
      .collection('users')
      .doc(userId)
      .collection('recipes')
      .add({
    'title': 'Recipe 1',
    'ingredients': ['Flour', 'Sugar'],
  });

  // Act - Request data export
  final exportService = ServiceLocator.get<DataExportService>();
  final exportData = await exportService.exportUserData(userId);

  // Assert - Export contains all data
  expect(exportData['user']['email'], 'user@example.com');
  expect(exportData['recipes'].length, 1);
  expect(exportData['recipes'][0]['title'], 'Recipe 1');
  expect(exportData['recipes'][0]['ingredients'], ['Flour', 'Sugar']);

  // Verify export audit logged
  final auditLogs = await firestore
      .collection('auditLogs')
      .where('userId', isEqualTo: userId)
      .where('action', isEqualTo: 'data_exported')
      .get();
  expect(auditLogs.docs.length, 1);
});
```

## Testing Permission Validation

### Unauthorized Access Prevention

```dart
test('prevents unauthorized recipe access', () async {
  // Arrange - Create recipe owned by user_1
  final firestore = FakeFirebaseFirestore();

  await firestore
      .collection('users')
      .doc('user_1')
      .collection('recipes')
      .doc('recipe_1')
      .set({
    'userId': 'user_1',
    'title': 'Private Recipe',
    'visibility': 'private',
  });

  final repository = FirebaseRecipeRepository(
    firestore: firestore,
    authRepository: MockAuthRepository(currentUserId: 'user_2'),
  );

  // Act & Assert - User 2 cannot access user 1's private recipe
  expect(
    () => repository.getById('recipe_1'),
    throwsA(isA<UnauthorizedException>()),
  );
});

test('allows authorized shared recipe access', () async {
  // Arrange - Create shared recipe
  final firestore = FakeFirebaseFirestore();

  await firestore.collection('sharedRecipes').doc('recipe_1').set({
    'ownerId': 'user_1',
    'sharedWith': ['user_2'],
    'title': 'Shared Recipe',
  });

  final repository = FirebaseSocialRecipeRepository(
    firestore: firestore,
    authRepository: MockAuthRepository(currentUserId: 'user_2'),
  );

  // Act - User 2 can access shared recipe
  final recipe = await repository.getById('recipe_1');

  // Assert
  expect(recipe, isNotNull);
  expect(recipe!.title, 'Shared Recipe');
});
```

## Testing Multi-Screen Navigation

```dart
testWidgets('complete menu planning flow', (tester) async {
  // Arrange
  await tester.pumpWidget(MyApp());
  await tester.pumpAndSettle();

  // Navigate to menu planning
  await tester.tap(find.text('Menu Planning'));
  await tester.pumpAndSettle();

  // Create new menu
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(Key('menu_title')), 'Week Menu');
  await tester.tap(find.text('Create'));
  await tester.pumpAndSettle();

  // Add recipe to Monday dinner
  await tester.tap(find.byKey(Key('monday_dinner_add')));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Pasta Carbonara'));
  await tester.pumpAndSettle();

  // Verify recipe added
  expect(find.text('Pasta Carbonara'), findsOneWidget);

  // Generate shopping list from menu
  await tester.tap(find.text('Generate Shopping List'));
  await tester.pumpAndSettle();

  // Verify shopping list created with ingredients
  expect(find.text('Shopping List'), findsOneWidget);
  expect(find.text('Pasta'), findsOneWidget);
  expect(find.text('Eggs'), findsOneWidget);
});
```

## Testing Error Recovery

```dart
testWidgets('recovers from network error', (tester) async {
  // Arrange - Mock network failure
  final mockService = MockRecipeService();
  when(() => mockService.personal.getUserRecipes())
      .thenThrow(NetworkException('No connection'));

  await tester.pumpWidget(
    MaterialApp(
      home: Provider<UnifiedRecipeService>.value(
        value: mockService,
        child: RecipeListView(),
      ),
    ),
  );
  await tester.pumpAndSettle();

  // Assert - Error shown
  expect(find.text('No connection'), findsOneWidget);
  expect(find.text('Retry'), findsOneWidget);

  // Act - Mock network recovery
  when(() => mockService.personal.getUserRecipes())
      .thenAnswer((_) async => RecipeFactory.createList());

  await tester.tap(find.text('Retry'));
  await tester.pumpAndSettle();

  // Assert - Data loaded
  expect(find.byType(RecipeCard), findsWidgets);
  expect(find.text('No connection'), findsNothing);
});
```

## Testing Offline Functionality

```dart
test('syncs data when coming back online', () async {
  // Arrange - Create offline changes
  final offlineService = ServiceLocator.get<OfflineService>();
  final recipeService = ServiceLocator.get<UnifiedRecipeService>();

  // Simulate offline
  offlineService.setOffline(true);

  // Create recipe while offline
  final recipe = await recipeService.personal.createRecipe(
    RecipeFactory.create(title: 'Offline Recipe'),
  );

  // Verify stored locally
  final localRecipes = await offlineService.getLocalRecipes();
  expect(localRecipes.length, 1);

  // Act - Come back online
  offlineService.setOffline(false);
  await offlineService.syncPendingChanges();

  // Assert - Changes synced to Firebase
  final firestore = ServiceLocator.get<FirebaseFirestore>();
  final syncedRecipe = await firestore
      .collection('users')
      .doc('user_1')
      .collection('recipes')
      .doc(recipe.id)
      .get();

  expect(syncedRecipe.exists, isTrue);
  expect(syncedRecipe['title'], 'Offline Recipe');
});
```

## Best Practices

1. **Test Critical Paths**: Focus on high-value user journeys
2. **Use Real Firebase**: Use FakeFirebaseFirestore for realistic integration
3. **Test Cross-User Scenarios**: Verify sharing, permissions, real-time sync
4. **Verify Data Consistency**: Check Firebase state after operations
5. **Test Error Recovery**: Simulate failures and verify graceful handling
6. **Test GDPR Compliance**: Verify data deletion and export completeness
7. **Keep Tests Independent**: Each test should setup and teardown its own data
8. **Use Meaningful Test Data**: Create realistic scenarios that mirror production

## Common Pitfalls

**Don't skip teardown:**
```dart
// ❌ Wrong - data bleeds between tests
test('first test', () async {
  await firestore.collection('users').add({...});
});

test('second test', () async {
  // Uses data from first test!
});

// ✅ Correct
setUp(() {
  firestore = FakeFirebaseFirestore();
});

tearDown(() async {
  await firestore.clearPersistence();
});
```

**Don't test implementation details:**
```dart
// ❌ Wrong - testing internal state
expect(viewModel.internalCache.length, 5);

// ✅ Correct - testing observable behavior
expect(viewModel.recipes.length, 5);
```

**Don't forget to wait for async operations:**
```dart
// ❌ Wrong - assertion runs before operation completes
recipeService.createRecipe(recipe);
expect(find.text('Recipe created'), findsOneWidget);

// ✅ Correct
await recipeService.createRecipe(recipe);
await tester.pumpAndSettle();
expect(find.text('Recipe created'), findsOneWidget);
```

## Running Integration Tests

```bash
# Run all integration tests
flutter test test/integration/

# Run specific integration test suite
flutter test test/integration/firebase/account_deletion_integration_test.dart

# Run with coverage
flutter test --coverage test/integration/

# Run integration tests on real device (for platform-specific features)
flutter test --device-id=<device-id> integration_test/
```

## Related Resources

- [Repository Testing](repository-testing.md) - Foundation for integration tests
- [Service Testing](service-testing.md) - Testing business logic layer
- [Widget Testing](widget-testing.md) - Testing UI components
- [Test Factories](test-factories.md) - Generating consistent test data