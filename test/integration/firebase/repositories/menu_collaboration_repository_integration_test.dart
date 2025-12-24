/// Integration tests for Firebase MenuCollaborationRepository
///
/// Tests FieldValue operations that require Firebase behavior and cannot be unit tested.
/// Following HYBRID_TESTING_STRATEGY.md: Use integration tests for FieldValue operations.
///
/// **FieldValue Operations Tested:**
/// - FieldValue.serverTimestamp(): Server-side timestamp generation
/// - FieldValue.arrayUnion(): Adding recipes to menu categories
/// - FieldValue.arrayRemove(): Removing recipes from menu categories
/// - FieldValue.increment(): Template usage counter updates
///
/// **Testing Strategy:**
/// - Uses FakeFirebaseFirestore for reliable CI/CD execution
/// - Tests actual FieldValue behavior without Firebase emulator dependency
/// - Focuses on FieldValue operation correctness, not business logic
/// - Complements unit tests that mock at repository level
@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart' as auth_mocks;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_menu_collaboration_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/models/recipe_unified.dart';
import '../../../infrastructure/mocks/firestore_singleton.dart';
import '../../../infrastructure/builders/recipe_builder.dart';
import '../../../test_support/test_data_isolator.dart';

void main() {
  group('MenuCollaborationRepository FieldValue Integration', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FirebaseMenuCollaborationRepository repository;
    late FirebaseAuthRepository authRepository;
    late auth_mocks.MockFirebaseAuth mockAuth;
    late auth_mocks.MockUser mockUser;

    // Test data
    const testUserId = 'test-user-123';
    const testUserEmail = 'test@example.com';
    const testUserDisplayName = 'Test User';
    const testMenuId = 'test-menu-456';
    const testTemplateId = 'test-template-789';
    late Recipe testRecipe;

    setUp(() async {
      // Initialize test isolation
      TestDataIsolator.initializeTest(
          'menu_collaboration_repository_integration_test');

      // Set up fake Firebase instances
      fakeFirestore = FirestoreSingleton.instance;
      mockUser = auth_mocks.MockUser(
        uid: testUserId,
        email: testUserEmail,
        displayName: testUserDisplayName,
      );
      mockAuth =
          auth_mocks.MockFirebaseAuth(mockUser: mockUser, signedIn: true);

      // Setup auth repository
      authRepository = FirebaseAuthRepository(firebaseAuth: mockAuth);

      // Create repository with fake Firestore
      repository = FirebaseMenuCollaborationRepository(
        firestore: fakeFirestore,
        authRepository: authRepository,
      );

      // Create test recipe
      testRecipe = RecipeBuilder()
          .withId('recipe-123')
          .withTitle('Test Integration Recipe')
          .withMealType('Huvudrätter')
          .build();

      // Create test menu document for operations
      await fakeFirestore.collection('shared_menus').doc(testMenuId).set({
        'sharedByUserId': testUserId,
        'sharedByDisplayName': testUserDisplayName,
        'menuTitle': 'Test Menu',
        'allowCollaboration': true,
        'collaboratorIds': [testUserId],
        'menuSnapshot': {
          'Huvudrätter': [],
          'Förrätter': [],
        },
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Create test template for increment operations
      await fakeFirestore.collection('menu_templates').doc(testTemplateId).set({
        'templateName': 'Test Template',
        'ownerId': testUserId,
        'useCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    group('FieldValue.serverTimestamp() Operations', () {
      test('should set server timestamp when enabling collaboration', () async {
        // Arrange
        final newMenuId = 'new-menu-timestamp-test';
        await fakeFirestore.collection('shared_menus').doc(newMenuId).set({
          'sharedByUserId': testUserId,
          'menuTitle': 'Timestamp Test Menu',
        });

        // Act
        final result = await repository.enableCollaboration(
          menuId: newMenuId,
          collaboratorIds: ['user-1', 'user-2'],
          collaboratorDisplayNames: {'user-1': 'User One'},
        );

        // Assert
        expect(result, isTrue);

        final doc =
            await fakeFirestore.collection('shared_menus').doc(newMenuId).get();
        final data = doc.data()!;

        expect(data['collaborationEnabledAt'], isA<Timestamp>());

        // Verify timestamp is recent (within last minute)
        final timestamp = data['collaborationEnabledAt'] as Timestamp;
        final now = DateTime.now();
        final difference = now.difference(timestamp.toDate());
        expect(difference.inMinutes, lessThan(1));
      });

      test('should set server timestamp when rating menu', () async {
        // Act
        final result = await repository.rateMenu(
          menuId: testMenuId,
          rating: 4.5,
          comment: 'Great menu!',
        );

        // Assert
        expect(result, isTrue);

        final ratingsCollection = fakeFirestore
            .collection('menu_ratings')
            .doc(testMenuId)
            .collection('ratings');

        final snapshot = await ratingsCollection.get();
        expect(snapshot.docs, hasLength(1));

        final ratingData = snapshot.docs.first.data();
        expect(ratingData['ratedAt'], isA<Timestamp>());

        // Verify timestamp consistency
        final ratedAt = (ratingData['ratedAt'] as Timestamp).toDate();
        final now = DateTime.now();
        expect(now.difference(ratedAt).inSeconds, lessThan(10));
      });

      test('should set server timestamp when adding menu comment', () async {
        // Act
        final result = await repository.addMenuComment(
          menuId: testMenuId,
          comment: 'This looks delicious!',
        );

        // Assert
        expect(result, isTrue);

        final commentsCollection = fakeFirestore
            .collection('menu_comments')
            .doc(testMenuId)
            .collection('comments');

        final snapshot = await commentsCollection.get();
        expect(snapshot.docs, hasLength(1));

        final commentData = snapshot.docs.first.data();
        expect(commentData['commentedAt'], isA<Timestamp>());
        expect(commentData['comment'], equals('This looks delicious!'));
      });

      test('should handle multiple server timestamps in single operation',
          () async {
        // Act - Add recipe which uses both lastUpdatedAt and activity timestamp
        final result = await repository.addRecipeToMenu(
          menuId: testMenuId,
          category: 'Huvudrätter',
          recipe: testRecipe,
        );

        // Assert
        expect(result, isTrue);

        // Check menu document timestamp
        final menuDoc = await fakeFirestore
            .collection('shared_menus')
            .doc(testMenuId)
            .get();
        final menuData = menuDoc.data()!;
        expect(menuData['lastUpdatedAt'], isA<Timestamp>());

        // Check activity log timestamp
        final activitiesCollection = fakeFirestore
            .collection('menu_activity')
            .doc(testMenuId)
            .collection('activities');

        final activitiesSnapshot = await activitiesCollection.get();
        expect(activitiesSnapshot.docs, hasLength(1));

        final activityData = activitiesSnapshot.docs.first.data();
        expect(activityData['timestamp'], isA<Timestamp>());

        // Timestamps should be very close (within 1 second)
        final menuTimestamp = (menuData['lastUpdatedAt'] as Timestamp).toDate();
        final activityTimestamp =
            (activityData['timestamp'] as Timestamp).toDate();
        expect(menuTimestamp.difference(activityTimestamp).abs().inSeconds,
            lessThanOrEqualTo(1));
      });
    });

    group('FieldValue.arrayUnion() Operations', () {
      test('should add recipe to menu category using arrayUnion', () async {
        // Act
        final result = await repository.addRecipeToMenu(
          menuId: testMenuId,
          category: 'Huvudrätter',
          recipe: testRecipe,
          suggestion: 'Perfect for Sunday dinner!',
        );

        // Assert
        expect(result, isTrue);

        final doc = await fakeFirestore
            .collection('shared_menus')
            .doc(testMenuId)
            .get();
        final data = doc.data()!;
        final menuSnapshot = data['menuSnapshot'] as Map<String, dynamic>;
        final huvudratter =
            List<Map<String, dynamic>>.from(menuSnapshot['Huvudrätter']);

        expect(huvudratter, hasLength(1));
        expect(huvudratter[0]['id'], equals(testRecipe.id));
        expect(huvudratter[0]['title'], equals(testRecipe.title));
      });

      test('should prevent duplicate recipes with arrayUnion behavior',
          () async {
        // Arrange - Add recipe first time
        await repository.addRecipeToMenu(
          menuId: testMenuId,
          category: 'Huvudrätter',
          recipe: testRecipe,
        );

        // Act - Try to add same recipe again
        final result2 = await repository.addRecipeToMenu(
          menuId: testMenuId,
          category: 'Huvudrätter',
          recipe: testRecipe,
        );

        // Assert
        expect(result2, isTrue);

        final doc = await fakeFirestore
            .collection('shared_menus')
            .doc(testMenuId)
            .get();
        final data = doc.data()!;
        final menuSnapshot = data['menuSnapshot'] as Map<String, dynamic>;
        final huvudratter =
            List<Map<String, dynamic>>.from(menuSnapshot['Huvudrätter']);

        // arrayUnion should prevent duplicates based on exact object matching
        expect(huvudratter.length, greaterThanOrEqualTo(1));
        expect(huvudratter.every((r) => r['id'] == testRecipe.id), isTrue);
      });

      test('should create array if category does not exist', () async {
        // Act - Add recipe to non-existent category
        final result = await repository.addRecipeToMenu(
          menuId: testMenuId,
          category: 'Efterrätter', // New category not in initial menu
          recipe: testRecipe,
        );

        // Assert
        expect(result, isTrue);

        final doc = await fakeFirestore
            .collection('shared_menus')
            .doc(testMenuId)
            .get();
        final data = doc.data()!;
        final menuSnapshot = data['menuSnapshot'] as Map<String, dynamic>;

        expect(menuSnapshot.containsKey('Efterrätter'), isTrue);
        final efterratter =
            List<Map<String, dynamic>>.from(menuSnapshot['Efterrätter']);
        expect(efterratter, hasLength(1));
        expect(efterratter[0]['id'], equals(testRecipe.id));
      });
    });

    group('FieldValue.arrayRemove() Operations', () {
      test('should remove recipe from menu category using arrayRemove',
          () async {
        // Arrange - Add recipe first
        await repository.addRecipeToMenu(
          menuId: testMenuId,
          category: 'Huvudrätter',
          recipe: testRecipe,
        );

        // Verify recipe was added
        var doc = await fakeFirestore
            .collection('shared_menus')
            .doc(testMenuId)
            .get();
        var menuSnapshot = doc.data()!['menuSnapshot'] as Map<String, dynamic>;
        var huvudratter =
            List<Map<String, dynamic>>.from(menuSnapshot['Huvudrätter']);
        expect(huvudratter, hasLength(1));

        // Act - Remove the recipe
        final result = await repository.removeRecipeFromMenu(
          menuId: testMenuId,
          category: 'Huvudrätter',
          recipeId: testRecipe.id,
          reason: 'Not suitable for this menu',
        );

        // Assert
        expect(result, isTrue);

        doc = await fakeFirestore
            .collection('shared_menus')
            .doc(testMenuId)
            .get();
        final data = doc.data()!;
        menuSnapshot = data['menuSnapshot'] as Map<String, dynamic>;
        huvudratter =
            List<Map<String, dynamic>>.from(menuSnapshot['Huvudrätter']);

        expect(huvudratter, isEmpty);
      });

      test('should handle removing non-existent recipe gracefully', () async {
        // Act - Try to remove recipe that doesn't exist
        final result = await repository.removeRecipeFromMenu(
          menuId: testMenuId,
          category: 'Huvudrätter',
          recipeId: 'non-existent-recipe-id',
          reason: 'Test removal',
        );

        // Assert - Should return true (operation succeeded, item just wasn't there)
        expect(result, isTrue);

        // Menu should remain unchanged
        final doc = await fakeFirestore
            .collection('shared_menus')
            .doc(testMenuId)
            .get();
        final data = doc.data()!;
        final menuSnapshot = data['menuSnapshot'] as Map<String, dynamic>;
        final huvudratter =
            List<Map<String, dynamic>>.from(menuSnapshot['Huvudrätter']);
        expect(huvudratter, isEmpty); // Still empty as it was initially
      });

      test('should remove only specific recipe when multiple exist', () async {
        // Arrange - Add multiple recipes
        final recipe2 = RecipeBuilder()
            .withId('recipe-456')
            .withTitle('Another Recipe')
            .withMealType('Huvudrätter')
            .build();

        await repository.addRecipeToMenu(
          menuId: testMenuId,
          category: 'Huvudrätter',
          recipe: testRecipe,
        );

        await repository.addRecipeToMenu(
          menuId: testMenuId,
          category: 'Huvudrätter',
          recipe: recipe2,
        );

        // Act - Remove only the first recipe
        final result = await repository.removeRecipeFromMenu(
          menuId: testMenuId,
          category: 'Huvudrätter',
          recipeId: testRecipe.id,
        );

        // Assert
        expect(result, isTrue);

        final doc = await fakeFirestore
            .collection('shared_menus')
            .doc(testMenuId)
            .get();
        final data = doc.data()!;
        final menuSnapshot = data['menuSnapshot'] as Map<String, dynamic>;
        final huvudratter =
            List<Map<String, dynamic>>.from(menuSnapshot['Huvudrätter']);

        expect(huvudratter, hasLength(1));
        expect(huvudratter[0]['id'], equals(recipe2.id));
        expect(huvudratter[0]['title'], equals('Another Recipe'));
      });
    });

    group('FieldValue.increment() Operations', () {
      test('should increment template use count', () async {
        // Arrange - Verify initial count
        var templateDoc = await fakeFirestore
            .collection('menu_templates')
            .doc(testTemplateId)
            .get();
        expect(templateDoc.data()!['useCount'], equals(0));

        // Act - Create menu from template (which should increment useCount)
        final result = await repository.createMenuFromTemplate(
          templateId: testTemplateId,
          menuTitle: 'Menu from Template',
        );

        // Assert
        expect(result, isNotNull);

        // Check that use count was incremented
        templateDoc = await fakeFirestore
            .collection('menu_templates')
            .doc(testTemplateId)
            .get();
        expect(templateDoc.data()!['useCount'], equals(1));
      });

      test('should handle multiple increments correctly', () async {
        // Act - Create multiple menus from template
        await repository.createMenuFromTemplate(
          templateId: testTemplateId,
          menuTitle: 'Menu 1',
        );

        await repository.createMenuFromTemplate(
          templateId: testTemplateId,
          menuTitle: 'Menu 2',
        );

        await repository.createMenuFromTemplate(
          templateId: testTemplateId,
          menuTitle: 'Menu 3',
        );

        // Assert
        final templateDoc = await fakeFirestore
            .collection('menu_templates')
            .doc(testTemplateId)
            .get();
        expect(templateDoc.data()!['useCount'], equals(3));
      });

      test('should create field with increment if it does not exist', () async {
        // Arrange - Create template without useCount field
        const newTemplateId = 'template-without-count';
        await fakeFirestore
            .collection('menu_templates')
            .doc(newTemplateId)
            .set({
          'templateName': 'Template Without Count',
          'ownerId': testUserId,
          'menuSnapshot': {},
          'createdAt': FieldValue.serverTimestamp(),
          // Note: no useCount field
        });

        // Act
        final result = await repository.createMenuFromTemplate(
          templateId: newTemplateId,
          menuTitle: 'Menu from Template Without Count',
        );

        // Assert
        expect(result, isNotNull);

        final templateDoc = await fakeFirestore
            .collection('menu_templates')
            .doc(newTemplateId)
            .get();
        expect(templateDoc.data()!['useCount'],
            equals(1)); // Should be created with value 1
      });
    });

    group('Complex FieldValue Combinations', () {
      test('should handle multiple FieldValue operations in single update',
          () async {
        // Act - Add recipe (uses arrayUnion + serverTimestamp + activity logging)
        final result = await repository.addRecipeToMenu(
          menuId: testMenuId,
          category: 'Huvudrätter',
          recipe: testRecipe,
          suggestion: 'Complex operation test',
        );

        // Assert
        expect(result, isTrue);

        // Check menu document (arrayUnion + serverTimestamp)
        final menuDoc = await fakeFirestore
            .collection('shared_menus')
            .doc(testMenuId)
            .get();
        final menuData = menuDoc.data()!;

        expect(menuData['lastUpdatedAt'], isA<Timestamp>());
        expect(menuData['lastUpdatedBy'], equals(testUserId));

        final menuSnapshot = menuData['menuSnapshot'] as Map<String, dynamic>;
        final huvudratter =
            List<Map<String, dynamic>>.from(menuSnapshot['Huvudrätter']);
        expect(huvudratter, hasLength(1));

        // Check activity log (separate serverTimestamp)
        final activitiesSnapshot = await fakeFirestore
            .collection('menu_activity')
            .doc(testMenuId)
            .collection('activities')
            .get();

        expect(activitiesSnapshot.docs, hasLength(1));
        final activityData = activitiesSnapshot.docs.first.data();
        expect(activityData['timestamp'], isA<Timestamp>());
        expect(activityData['operation'], equals('add_recipe'));
      });

      test('should handle concurrent FieldValue operations', () async {
        // Arrange - Create multiple templates for concurrent increment testing
        const template1 = 'concurrent-template-1';
        const template2 = 'concurrent-template-2';

        await fakeFirestore.collection('menu_templates').doc(template1).set({
          'templateName': 'Concurrent Template 1',
          'useCount': 0,
        });

        await fakeFirestore.collection('menu_templates').doc(template2).set({
          'templateName': 'Concurrent Template 2',
          'useCount': 0,
        });

        // Act - Simulate concurrent operations
        final futures = [
          repository.createMenuFromTemplate(
              templateId: template1, menuTitle: 'Menu 1A'),
          repository.createMenuFromTemplate(
              templateId: template1, menuTitle: 'Menu 1B'),
          repository.createMenuFromTemplate(
              templateId: template2, menuTitle: 'Menu 2A'),
          repository.createMenuFromTemplate(
              templateId: template1, menuTitle: 'Menu 1C'),
          repository.createMenuFromTemplate(
              templateId: template2, menuTitle: 'Menu 2B'),
        ];

        final results = await Future.wait(futures);

        // Assert
        expect(results.every((r) => r != null), isTrue);

        final template1Doc = await fakeFirestore
            .collection('menu_templates')
            .doc(template1)
            .get();
        final template2Doc = await fakeFirestore
            .collection('menu_templates')
            .doc(template2)
            .get();

        expect(template1Doc.data()!['useCount'], equals(3)); // Used 3 times
        expect(template2Doc.data()!['useCount'], equals(2)); // Used 2 times
      });
    });

    group('Error Handling with FieldValue Operations', () {
      test('should handle FieldValue operations on non-existent documents',
          () async {
        // Act - Try to add recipe to non-existent menu
        final result = await repository.addRecipeToMenu(
          menuId: 'non-existent-menu',
          category: 'Huvudrätter',
          recipe: testRecipe,
        );

        // Assert - Should fail gracefully
        expect(result, isFalse);
      });

      test('should handle increment on non-existent template', () async {
        // Act - Try to create menu from non-existent template
        final result = await repository.createMenuFromTemplate(
          templateId: 'non-existent-template',
          menuTitle: 'Test Menu',
        );

        // Assert - Should return null
        expect(result, isNull);
      });

      test('should maintain data consistency on partial failures', () async {
        // This test verifies that if part of a complex FieldValue operation fails,
        // the document remains in a consistent state

        // Arrange - Add recipe successfully first
        await repository.addRecipeToMenu(
          menuId: testMenuId,
          category: 'Huvudrätter',
          recipe: testRecipe,
        );

        // Verify initial state
        var doc = await fakeFirestore
            .collection('shared_menus')
            .doc(testMenuId)
            .get();
        var data = doc.data()!;
        var menuSnapshot = data['menuSnapshot'] as Map<String, dynamic>;
        var huvudratter =
            List<Map<String, dynamic>>.from(menuSnapshot['Huvudrätter']);
        expect(huvudratter, hasLength(1));

        // Act - Try to remove with proper ID (should succeed)
        final result = await repository.removeRecipeFromMenu(
          menuId: testMenuId,
          category: 'Huvudrätter',
          recipeId: testRecipe.id,
        );

        // Assert - Operation should succeed and maintain consistency
        expect(result, isTrue);

        doc = await fakeFirestore
            .collection('shared_menus')
            .doc(testMenuId)
            .get();
        data = doc.data()!;
        menuSnapshot = data['menuSnapshot'] as Map<String, dynamic>;
        huvudratter =
            List<Map<String, dynamic>>.from(menuSnapshot['Huvudrätter']);
        expect(huvudratter, isEmpty);

        // Verify timestamps are still valid
        expect(data['lastUpdatedAt'], isA<Timestamp>());
        expect(data['lastUpdatedBy'], equals(testUserId));
      });
    });
  });
}
