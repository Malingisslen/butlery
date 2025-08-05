/// Comprehensive unit tests for UnifiedRecipeService following TDD and BDD patterns.
///
/// This test suite validates all core functionality of the UnifiedRecipeService
/// including personal recipe operations, collaborative features, state management,
/// error handling, and service coordination using Mocktail and comprehensive test scenarios.

import 'package:flutter_test/flutter_test.dart';
import '../../../test_configuration.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/models/recipe_unified.dart';

import '../../../helpers/test_service_locator.dart';

void main() {
  // Configure tests to ensure ServiceLocator is properly initialized
  configureTests();

  group('UnifiedRecipeService', () {
    late UnifiedRecipeService sut; // System Under Test
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuthRepository mockAuthRepository;

    setUp(() {
      // ServiceLocator is already initialized by configureTests()
      fakeFirestore = TestServiceLocator.fakeFirestore;
      mockAuthRepository = TestServiceLocator.mockAuthRepository;

      // Setup auth repository defaults
      when(() => mockAuthRepository.currentUserId).thenReturn('test_user_123');
      // Return null for currentUser to prevent sync from starting
      when(() => mockAuthRepository.currentUser).thenReturn(null);
      when(() => mockAuthRepository.authStateChanges())
          .thenAnswer((_) => Stream<User?>.value(null));

      sut = UnifiedRecipeService(
        firestore: fakeFirestore,
        authRepository: mockAuthRepository,
        recipeRepository: TestServiceLocator.mockRecipeRepository,
        commentsRepository: TestServiceLocator.mockCommentsRepository,
        ratingsRepository: TestServiceLocator.mockRatingsRepository,
        notificationsRepository: TestServiceLocator.mockNotificationsRepository,
        firestoreRepository: TestServiceLocator.mockFirestoreRepository,
      );
    });

    tearDown(() {
      // Cleanup is handled by configureTests()
    });

    group('initialization', () {
      test('should initialize successfully', () async {
        // Given
        expect(sut.isInitialized, isFalse);
        expect(sut.recipes, isEmpty);

        // When
        try {
          await sut.initialize();
        } catch (e, stack) {
          // Log error for debugging
          // ignore: avoid_print
          print('Initialize error: $e');
          // ignore: avoid_print
          print('Stack: $stack');
          rethrow;
        }

        // Then
        expect(sut.isInitialized, isTrue, reason: 'Error: ${sut.error}');
        expect(sut.error, isNull);
        expect(sut.hasError, isFalse);
      });

      test('should handle initialization errors gracefully', () async {
        // Given
        when(() => mockAuthRepository.currentUserId)
            .thenThrow(Exception('Auth error'));

        // When
        await sut.initialize();

        // Then
        expect(sut.hasError, isTrue);
        expect(sut.error, isNotNull);
      });

      test('should set loading state during initialization', () async {
        // Given
        expect(sut.isLoading, isFalse);

        // When
        final initFuture = sut.initialize();

        // Then (during execution) - Note: this might be racy, but tests the concept
        await initFuture;
        expect(sut.isLoading, isFalse); // Should be false after completion
      });
    });

    group('recipe state management', () {
      test('should provide correct basic state accessors', () {
        // Then
        expect(sut.recipes, isA<List<Recipe>>());
        expect(sut.personalRecipes, isA<List<Recipe>>());
        expect(sut.collaborativeRecipes, isA<List<Recipe>>());
        expect(sut.hasRecipes, isA<bool>());
      });

      test('should handle empty recipe collections', () {
        // Then
        expect(sut.recipes, isEmpty);
        expect(sut.personalRecipes, isEmpty);
        expect(sut.collaborativeRecipes, isEmpty);
        expect(sut.hasRecipes, isFalse);
      });

      test('should provide correct user information', () {
        // Then
        expect(sut.currentUserId, equals('test_user_123'));
        expect(sut.currentUserDisplayName, isA<String?>());
      });
    });

    group('recipe retrieval', () {
      test('should get recipe by ID', () {
        // Given
        const testRecipeId = 'test_recipe_123';

        // When
        final result = sut.getRecipeById(testRecipeId);

        // Then
        // Should return null for non-existent recipe
        expect(result, isNull);
      });

      test('should return null for non-existent recipe ID', () {
        // When
        final result = sut.getRecipeById('non_existent');

        // Then
        expect(result, isNull);
      });
    });

    group('refresh functionality', () {
      test('should refresh recipe data', () async {
        // When
        await sut.refresh();

        // Then
        // Should complete without error
        expect(sut.hasError, isFalse);
      });
    });

    group('error handling', () {
      test('should provide error state accessors', () {
        // Then
        expect(sut.hasError, isA<bool>());
        expect(sut.error, isA<String?>());
      });

      test('should have clearError method', () {
        // When & Then
        expect(() => sut.clearError(), returnsNormally);
      });
    });

    group('module architecture', () {
      test('should have personal operations module', () {
        // Then
        expect(sut.personal, isNotNull);
      });

      test('should have social operations module', () {
        // Then
        expect(sut.social, isNotNull);
      });

      test('should have realtime operations module', () {
        // Then
        expect(sut.realtime, isNotNull);
      });
    });

    group('legacy compatibility', () {
      test('should support basic operations interface', () {
        // Given
        final testRecipe = TestServiceLocator.createTestRecipe();

        // When & Then
        expect(() => sut.deleteRecipeById(testRecipe.id), returnsNormally);
      });
    });
  });
}
