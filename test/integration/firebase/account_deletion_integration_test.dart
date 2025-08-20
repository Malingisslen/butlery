/// Integration tests for AccountDeletionService with real Firebase operations
/// 
/// Tests Firebase batch operations and FieldValue operations that cannot
/// be properly tested with mocks. Uses FakeFirebaseFirestore for realistic testing.
/// 
/// Run with: flutter test --tags=integration
@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:mocktail/mocktail.dart';

// Production imports
import 'package:butlery/services/account/account_deletion_service.dart';

// Test infrastructure
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

// Local mocks for Firebase sealed classes
class MockUser extends Mock implements User {}

// Fake classes for fallback values
class FakeException extends Fake implements Exception {}

void main() {
  group('AccountDeletionService Integration', () {
    late AccountDeletionService service;
    late FirebaseFirestore firestore;
    late MockFirebaseAuth mockAuth;
    late MockAuthService mockAuthService;
    late MockUserService mockUserService;
    late MockUnifiedRecipeService mockRecipeService;
    late MockOfflineService mockOfflineService;
    late MockAnalyticsService mockAnalyticsService;
    late MockUser mockUser;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(FakeException());
    });
    
    setUp(() async {
      await TestServiceLocator.initialize();
      
      // Use FakeFirebaseFirestore for integration testing
      // This supports FieldValue operations better than mocks
      firestore = FakeFirebaseFirestore();
      
      // Create mocks for non-Firebase services
      mockAuth = MockFirebaseAuth();
      mockAuthService = MockAuthService();
      mockUserService = MockUserService();
      mockRecipeService = MockUnifiedRecipeService();
      mockOfflineService = MockOfflineService();
      mockAnalyticsService = MockAnalyticsService();
      
      // Setup mock user
      mockUser = MockUser();
      when(() => mockUser.uid).thenReturn('test-user-123');
      when(() => mockUser.email).thenReturn('test@example.com');
      when(() => mockUser.displayName).thenReturn('Test User');
      
      // Configure mocks
      mockAuth.setAuthState(currentUser: mockUser);
      mockAuthService.setAuthState(
        currentUser: mockUser,
        isAuthenticated: true,
      );
      
      mockOfflineService.setOfflineState(
        isInitialized: true,
        currentUserId: 'test-user-123',
      );
      
      when(() => mockOfflineService.clearUserData(any())).thenAnswer((_) async => true);
      when(() => mockAnalyticsService.logAccountDeleted(any())).thenAnswer((_) async {});
      when(() => mockUser.delete()).thenAnswer((_) async {});
      
      // Create service with real Firestore
      service = AccountDeletionService(
        auth: mockAuth,
        firestore: firestore,
        authService: mockAuthService,
        userService: mockUserService,
        recipeService: mockRecipeService,
        offlineService: mockOfflineService,
        analyticsService: mockAnalyticsService,
      );
    });
    
    tearDown(() async {
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });
    
    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });
    
    group('Firebase Batch Operations', () {
      test('should handle batch operations correctly', () async {
        // Arrange
        final userId = 'test-user-123';
        
        // Add test data
        await firestore.collection('users').doc(userId).set({
          'displayName': 'Test User',
          'email': 'test@example.com',
        });
        
        // Add user's recipes subcollection
        await firestore.collection('users').doc(userId)
            .collection('recipes').doc('recipe-1').set({
          'title': 'Recipe 1',
          'userId': userId,
        });
        await firestore.collection('users').doc(userId)
            .collection('recipes').doc('recipe-2').set({
          'title': 'Recipe 2',
          'userId': userId,
        });
        
        // Add unified recipes
        await firestore.collection('recipes').doc('unified-1').set({
          'userId': userId,
          'title': 'Unified Recipe 1',
        });
        
        // Act
        final result = await service.deleteUserAccount(
          reason: 'Integration test',
          createAuditLog: true,
        );
        
        // Assert
        expect(result['success'], isTrue);
        expect(result['deletedCollections'], contains('recipes'));
        expect(result['auditLogId'], isNotNull);
        
        // Verify data was deleted
        final userDoc = await firestore.collection('users').doc(userId).get();
        expect(userDoc.exists, isFalse);
        
        final recipes = await firestore
            .collection('recipes')
            .where('userId', isEqualTo: userId)
            .get();
        expect(recipes.docs, isEmpty);
      });
      
      test('should handle FieldValue.serverTimestamp in audit log', () async {
        // Arrange
        final userId = 'test-user-123';
        
        // Act
        final result = await service.deleteUserAccount(
          reason: 'Test timestamp',
          createAuditLog: true,
        );
        
        // Assert
        expect(result['success'], isTrue);
        expect(result['auditLogId'], isNotNull);
        
        // Check audit log
        final auditLogs = await firestore.collection('deletion_audit_logs').get();
        expect(auditLogs.docs, isNotEmpty);
        
        final auditLog = auditLogs.docs.first.data();
        expect(auditLog['userId'], equals(userId));
        expect(auditLog['reason'], equals('Test timestamp'));
        // FakeFirebaseFirestore will have set a timestamp
        expect(auditLog['deletionTimestamp'], isNotNull);
      });
    });
    
    group('Array Operations', () {
      test('should handle FieldValue.arrayUnion for shared content', () async {
        // Arrange
        final userId = 'test-user-123';
        
        // Create shared recipe with array field
        await firestore.collection('shared_recipes').doc('shared-1').set({
          'ownerId': 'owner-123',
          'sharedWith': ['user-1', 'user-2', userId],
          'title': 'Shared Recipe',
        });
        
        // Act
        final result = await service.deleteUserAccount(
          reason: 'Test array operations',
        );
        
        // Assert
        expect(result['success'], isTrue);
        
        // Verify user was removed from array
        final sharedDoc = await firestore
            .collection('shared_recipes')
            .doc('shared-1')
            .get();
        expect(sharedDoc.exists, isTrue);
        expect(sharedDoc.data()?['sharedWith'], isNot(contains(userId)));
        expect(sharedDoc.data()?['sharedWith'], contains('user-1'));
      });
      
      test('should handle FieldValue.increment for statistics', () async {
        // Arrange
        // Create document with counter
        await firestore.collection('statistics').doc('global').set({
          'totalUsers': 100,
          'deletedUsers': 5,
        });
        
        // Note: AccountDeletionService doesn't directly use increment,
        // but this tests the capability for future enhancements
        await firestore.collection('statistics').doc('global').update({
          'deletedUsers': FieldValue.increment(1),
        });
        
        // Assert
        final stats = await firestore.collection('statistics').doc('global').get();
        expect(stats.data()?['deletedUsers'], equals(6));
      });
    });
    
    group('Transaction Support', () {
      test('should handle batch commit properly', () async {
        // Arrange
        final userId = 'test-user-123';
        final batch = firestore.batch();
        
        // Add multiple operations to batch
        for (int i = 0; i < 5; i++) {
          final docRef = firestore.collection('test_collection').doc('doc-$i');
          await docRef.set({'userId': userId, 'index': i});
          batch.delete(docRef);
        }
        
        // Act
        await batch.commit();
        
        // Assert
        final remaining = await firestore.collection('test_collection').get();
        expect(remaining.docs, isEmpty);
      });
      
      test('should handle large batch operations', () async {
        // Arrange
        final userId = 'test-user-123';
        
        // Create many documents
        for (int i = 0; i < 50; i++) {
          await firestore.collection('recipes').doc('recipe-$i').set({
            'userId': userId,
            'title': 'Recipe $i',
          });
        }
        
        // Act
        final result = await service.deleteUserAccount(
          reason: 'Large batch test',
        );
        
        // Assert
        expect(result['success'], isTrue);
        
        // Verify all were deleted
        final remaining = await firestore
            .collection('recipes')
            .where('userId', isEqualTo: userId)
            .get();
        expect(remaining.docs, isEmpty);
      });
    });
    
    group('Complex Data Structures', () {
      test('should handle nested collections', () async {
        // Arrange
        final userId = 'test-user-123';
        
        // Create nested structure
        final userDoc = firestore.collection('users').doc(userId);
        await userDoc.set({'name': 'Test User'});
        
        await userDoc.collection('recipes').doc('r1').set({'title': 'Recipe 1'});
        await userDoc.collection('menus').doc('m1').set({'name': 'Menu 1'});
        await userDoc.collection('shopping_lists').doc('s1').set({'items': []});
        
        // Act
        final result = await service.deleteUserAccount(
          reason: 'Nested collections test',
        );
        
        // Assert
        expect(result['success'], isTrue);
        expect(result['deletedCollections'], containsAll([
          'recipes',
          'menus',
          'shopping_lists',
        ]));
      });
      
      test('should handle map fields with FieldValue operations', () async {
        // Arrange
        final userId = 'test-user-123';
        
        await firestore.collection('complex_docs').doc('doc-1').set({
          'metadata': {
            'createdBy': userId,
            'createdAt': FieldValue.serverTimestamp(),
            'tags': ['tag1', 'tag2'],
          },
          'stats': {
            'views': 0,
            'likes': 0,
          },
        });
        
        // Update with FieldValue
        await firestore.collection('complex_docs').doc('doc-1').update({
          'stats.views': FieldValue.increment(1),
          'metadata.lastModified': FieldValue.serverTimestamp(),
        });
        
        // Assert
        final doc = await firestore.collection('complex_docs').doc('doc-1').get();
        expect(doc.data()?['stats']['views'], equals(1));
        expect(doc.data()?['metadata']['lastModified'], isNotNull);
      });
    });
  });
}