/// Comprehensive unit tests for FirebaseRatingsRepository.
///
/// Tests recipe rating system functionality including rating CRUD operations,
/// statistics calculation, permission validation, and real-time updates.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_ratings_repository.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/utils/timestamp_provider.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('FirebaseRatingsRepository - Rating System', () {
    late FirebaseRatingsRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late FakeAuthRepository mockAuthRepo;
    late FakeUser mockUser;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      // Create fake Firestore instance
      fakeFirestore = FakeFirebaseFirestore();

      // Create mocks
      mockAuthRepo = FakeAuthRepository();
      mockUser = FakeUser(uid: 'user-123');

      // Setup default auth state
      mockAuthRepo.setAuthState(
        user: mockUser,
        userId: 'user-123',
        isAuthenticated: true,
      );

      // Create repository with fake Firestore and test timestamp provider
      repository = FirebaseRatingsRepository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepo,
        timestampProvider: const TestTimestampProvider(),
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    group('Permission Validation', () {
      test('should allow user to create rating for themselves', () async {
        // Arrange
        final rating = _createRating('recipe-1', 'user-123', 4.5);

        // Act
        final canCreate =
            await repository.validateCreatePermission('user-123', rating);

        // Assert
        expect(canCreate, isTrue);
      });

      test('should reject user from creating rating for another user',
          () async {
        // Arrange
        final rating = _createRating('recipe-1', 'other-user', 4.5);

        // Act
        final canCreate =
            await repository.validateCreatePermission('user-123', rating);

        // Assert
        expect(canCreate, isFalse);
      });

      test('should allow all users to read ratings (public)', () async {
        // Arrange
        final rating = _createRating('recipe-1', 'user-123', 4.5);

        // Act
        final canRead = await repository.validateReadPermission(
            'anyone', 'rating-id', rating);

        // Assert
        expect(canRead, isTrue);
      });

      test('should allow user to update their own rating', () async {
        // Arrange
        final rating = _createRating('recipe-1', 'user-123', 4.5);

        // Act
        final canUpdate = await repository.validateUpdatePermission(
            'user-123', 'rating-id', rating);

        // Assert
        expect(canUpdate, isTrue);
      });

      test('should reject user from updating another user\'s rating', () async {
        // Arrange
        final rating = _createRating('recipe-1', 'other-user', 4.5);

        // Act
        final canUpdate = await repository.validateUpdatePermission(
            'user-123', 'rating-id', rating);

        // Assert
        expect(canUpdate, isFalse);
      });

      test('should allow user to delete their own rating', () async {
        // Arrange
        const ratingId = 'recipe-1_user-123';
        final rating = _createRating('recipe-1', 'user-123', 4.5, id: ratingId);
        await _seedRating(fakeFirestore, ratingId, rating);

        // Act
        final canDelete =
            await repository.validateDeletePermission('user-123', ratingId);

        // Assert
        expect(canDelete, isTrue);
      });

      test('should reject user from deleting another user\'s rating', () async {
        // Arrange
        const ratingId = 'recipe-1_other-user';
        final rating =
            _createRating('recipe-1', 'other-user', 4.5, id: ratingId);
        await _seedRating(fakeFirestore, ratingId, rating);

        // Act
        final canDelete =
            await repository.validateDeletePermission('user-123', ratingId);

        // Assert
        expect(canDelete, isFalse);
      });
    });

    group('Rate Recipe', () {
      // NOTE: These tests are skipped due to FakeFirebaseFirestore limitations
      // with FieldValue.serverTimestamp(). The rateRecipe() method uses server timestamps.
      // These operations are tested in integration tests with real Firebase.

      test('should rate recipe successfully', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const rating = 4.5;

        // Act
        await repository.rateRecipe(
          recipeId: recipeId,
          userId: 'user-123',
          rating: rating,
          review: 'Great recipe!',
        );

        // Assert
        final ratingId = '${recipeId}_user-123';
        final doc = await fakeFirestore
            .collection('recipe_ratings')
            .doc(ratingId)
            .get();
        expect(doc.exists, isTrue);
        final data = doc.data()!;
        expect(data['recipeId'], equals(recipeId));
        expect(data['userId'], equals('user-123'));
        expect(data['rating'], equals(rating));
        expect(data['review'], equals('Great recipe!'));
      });

      test('should reject invalid rating below 1', () async {
        // Act & Assert
        expect(
          () => repository.rateRecipe(
            recipeId: 'recipe-1',
            userId: 'user-123',
            rating: 0.5,
          ),
          throwsA(isA<SecurityViolationException>()),
        );
      });

      test('should reject invalid rating above 5', () async {
        // Act & Assert
        expect(
          () => repository.rateRecipe(
            recipeId: 'recipe-1',
            userId: 'user-123',
            rating: 5.5,
          ),
          throwsA(isA<SecurityViolationException>()),
        );
      });

      test('should reject rating for another user', () async {
        // Act & Assert
        expect(
          () => repository.rateRecipe(
            recipeId: 'recipe-1',
            userId: 'other-user',
            rating: 4.0,
          ),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });

    group('Update Rating', () {
      test('should update existing rating successfully', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const ratingId = '${recipeId}_user-123';
        final existingRating =
            _createRating(recipeId, 'user-123', 3.0, id: ratingId);
        await _seedRating(fakeFirestore, ratingId, existingRating);

        // Act
        await repository.updateRating(
          recipeId: recipeId,
          userId: 'user-123',
          rating: 4.5,
          review: 'Updated review',
        );

        // Assert
        final doc = await fakeFirestore
            .collection('recipe_ratings')
            .doc(ratingId)
            .get();
        final data = doc.data()!;
        expect(data['rating'], equals(4.5));
        expect(data['review'], equals('Updated review'));
      });

      test('should reject invalid rating during update', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const ratingId = '${recipeId}_user-123';
        final existingRating =
            _createRating(recipeId, 'user-123', 3.0, id: ratingId);
        await _seedRating(fakeFirestore, ratingId, existingRating);

        // Act & Assert
        expect(
          () => repository.updateRating(
            recipeId: recipeId,
            userId: 'user-123',
            rating: 6.0,
          ),
          throwsA(isA<SecurityViolationException>()),
        );
      });

      test('should reject updating another user\'s rating', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const ratingId = '${recipeId}_other-user';
        final existingRating =
            _createRating(recipeId, 'other-user', 3.0, id: ratingId);
        await _seedRating(fakeFirestore, ratingId, existingRating);

        // Act & Assert
        expect(
          () => repository.updateRating(
            recipeId: recipeId,
            userId: 'other-user',
            rating: 4.0,
          ),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('should throw when rating does not exist', () async {
        // Act & Assert
        expect(
          () => repository.updateRating(
            recipeId: 'recipe-1',
            userId: 'user-123',
            rating: 4.0,
          ),
          throwsA(isA<ResourceNotFoundException>()),
        );
      });
    });

    group('Remove Rating', () {
      test('should remove rating successfully', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const ratingId = '${recipeId}_user-123';
        final rating = _createRating(recipeId, 'user-123', 4.0, id: ratingId);
        await _seedRating(fakeFirestore, ratingId, rating);

        // Act
        await repository.removeRating(recipeId, 'user-123');

        // Assert
        final doc = await fakeFirestore
            .collection('recipe_ratings')
            .doc(ratingId)
            .get();
        expect(doc.exists, isFalse);
      });

      test('should reject removing another user\'s rating', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const ratingId = '${recipeId}_other-user';
        final rating = _createRating(recipeId, 'other-user', 4.0, id: ratingId);
        await _seedRating(fakeFirestore, ratingId, rating);

        // Act & Assert
        expect(
          () => repository.removeRating(recipeId, 'other-user'),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('should throw when rating does not exist', () async {
        // Act & Assert
        expect(
          () => repository.removeRating('recipe-1', 'user-123'),
          throwsA(isA<ResourceNotFoundException>()),
        );
      });
    });

    group('Get User Rating', () {
      test('should retrieve user\'s rating for a recipe', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const ratingId = '${recipeId}_user-123';
        final rating = _createRating(recipeId, 'user-123', 4.5,
            id: ratingId, review: 'Excellent!');
        await _seedRating(fakeFirestore, ratingId, rating);

        // Act
        final result = await repository.getUserRating(recipeId, 'user-123');

        // Assert
        expect(result, isNotNull);
        expect(result!.recipeId, equals(recipeId));
        expect(result.userId, equals('user-123'));
        expect(result.rating, equals(4.5));
        expect(result.review, equals('Excellent!'));
      });

      test('should return null when user has not rated recipe', () async {
        // Act
        final result = await repository.getUserRating('recipe-1', 'user-123');

        // Assert
        expect(result, isNull);
      });
    });

    group('Get Recipe Ratings', () {
      test('should retrieve all ratings for a recipe', () async {
        // Arrange
        const recipeId = 'recipe-1';
        final rating1 =
            _createRating(recipeId, 'user-1', 5.0, id: '${recipeId}_user-1');
        final rating2 =
            _createRating(recipeId, 'user-2', 4.0, id: '${recipeId}_user-2');
        final rating3 =
            _createRating(recipeId, 'user-3', 3.5, id: '${recipeId}_user-3');
        final otherRecipeRating =
            _createRating('recipe-2', 'user-4', 4.0, id: 'recipe-2_user-4');

        await _seedRating(fakeFirestore, rating1.id, rating1);
        await _seedRating(fakeFirestore, rating2.id, rating2);
        await _seedRating(fakeFirestore, rating3.id, rating3);
        await _seedRating(
            fakeFirestore, otherRecipeRating.id, otherRecipeRating);

        // Act
        final results = await repository.getRecipeRatings(recipeId);

        // Assert
        expect(results.length, equals(3));
        expect(results.map((r) => r.userId),
            containsAll(['user-1', 'user-2', 'user-3']));
        expect(results.map((r) => r.userId), isNot(contains('user-4')));
      });

      test('should return empty list when recipe has no ratings', () async {
        // Act
        final results = await repository.getRecipeRatings('recipe-1');

        // Assert
        expect(results, isEmpty);
      });
    });

    group('Get Rating Statistics', () {
      test('should calculate statistics correctly', () async {
        // Arrange
        const recipeId = 'recipe-1';
        await _seedRating(fakeFirestore, '${recipeId}_user-1',
            _createRating(recipeId, 'user-1', 5.0, id: '${recipeId}_user-1'));
        await _seedRating(fakeFirestore, '${recipeId}_user-2',
            _createRating(recipeId, 'user-2', 4.0, id: '${recipeId}_user-2'));
        await _seedRating(fakeFirestore, '${recipeId}_user-3',
            _createRating(recipeId, 'user-3', 4.0, id: '${recipeId}_user-3'));
        await _seedRating(fakeFirestore, '${recipeId}_user-4',
            _createRating(recipeId, 'user-4', 3.0, id: '${recipeId}_user-4'));
        await _seedRating(fakeFirestore, '${recipeId}_user-5',
            _createRating(recipeId, 'user-5', 2.0, id: '${recipeId}_user-5'));

        // Act
        final stats = await repository.getRatingStatistics(recipeId);

        // Assert
        expect(stats.recipeId, equals(recipeId));
        expect(stats.totalRatings, equals(5));
        expect(stats.averageRating, equals(3.6)); // (5+4+4+3+2)/5 = 3.6
        expect(stats.ratingDistribution[5], equals(1));
        expect(stats.ratingDistribution[4], equals(2));
        expect(stats.ratingDistribution[3], equals(1));
        expect(stats.ratingDistribution[2], equals(1));
        expect(stats.ratingDistribution[1], equals(0));
      });

      test('should return zero statistics for recipe with no ratings',
          () async {
        // Act
        final stats = await repository.getRatingStatistics('recipe-1');

        // Assert
        expect(stats.recipeId, equals('recipe-1'));
        expect(stats.totalRatings, equals(0));
        expect(stats.averageRating, equals(0.0));
        expect(stats.ratingDistribution.values.every((value) => value == 0),
            isTrue);
      });

      test('should include last rated timestamp', () async {
        // Arrange
        const recipeId = 'recipe-1';
        final now = DateTime.now();
        final oldRating = _createRating(
          recipeId,
          'user-1',
          4.0,
          id: '${recipeId}_user-1',
          createdAt: now.subtract(const Duration(days: 2)),
        );
        final newRating = _createRating(
          recipeId,
          'user-2',
          5.0,
          id: '${recipeId}_user-2',
          createdAt: now.subtract(const Duration(hours: 1)),
        );

        await _seedRating(fakeFirestore, oldRating.id, oldRating);
        await _seedRating(fakeFirestore, newRating.id, newRating);

        // Act
        final stats = await repository.getRatingStatistics(recipeId);

        // Assert
        expect(stats.lastRatedAt, isNotNull);
        expect(stats.lastRatedAt!.isAfter(oldRating.createdAt), isTrue);
      });
    });

    group('Bulk Rating Statistics', () {
      test('should calculate statistics for multiple recipes', () async {
        // Arrange
        await _seedRating(fakeFirestore, 'recipe-1_user-1',
            _createRating('recipe-1', 'user-1', 5.0, id: 'recipe-1_user-1'));
        await _seedRating(fakeFirestore, 'recipe-1_user-2',
            _createRating('recipe-1', 'user-2', 4.0, id: 'recipe-1_user-2'));
        await _seedRating(fakeFirestore, 'recipe-2_user-1',
            _createRating('recipe-2', 'user-1', 3.0, id: 'recipe-2_user-1'));
        await _seedRating(fakeFirestore, 'recipe-3_user-1',
            _createRating('recipe-3', 'user-1', 5.0, id: 'recipe-3_user-1'));

        // Act
        final bulkStats = await repository
            .getBulkRatingStatistics(['recipe-1', 'recipe-2', 'recipe-3']);

        // Assert
        expect(
            bulkStats.keys, containsAll(['recipe-1', 'recipe-2', 'recipe-3']));
        expect(bulkStats['recipe-1']!.totalRatings, equals(2));
        expect(bulkStats['recipe-1']!.averageRating, equals(4.5));
        expect(bulkStats['recipe-2']!.totalRatings, equals(1));
        expect(bulkStats['recipe-2']!.averageRating, equals(3.0));
        expect(bulkStats['recipe-3']!.totalRatings, equals(1));
        expect(bulkStats['recipe-3']!.averageRating, equals(5.0));
      });

      test('should handle recipes with no ratings in bulk query', () async {
        // Arrange
        await _seedRating(fakeFirestore, 'recipe-1_user-1',
            _createRating('recipe-1', 'user-1', 4.0, id: 'recipe-1_user-1'));

        // Act
        final bulkStats = await repository
            .getBulkRatingStatistics(['recipe-1', 'recipe-2', 'recipe-3']);

        // Assert
        expect(bulkStats['recipe-1']!.totalRatings, equals(1));
        expect(bulkStats['recipe-2']!.totalRatings, equals(0));
        expect(bulkStats['recipe-3']!.totalRatings, equals(0));
      });

      test('should handle more than 10 recipes (batch processing)', () async {
        // Arrange
        final recipeIds = List.generate(15, (i) => 'recipe-$i');
        for (int i = 0; i < 15; i++) {
          final ratingId = 'recipe-${i}_user-1';
          await _seedRating(fakeFirestore, ratingId,
              _createRating('recipe-$i', 'user-1', 4.0, id: ratingId));
        }

        // Act
        final bulkStats = await repository.getBulkRatingStatistics(recipeIds);

        // Assert
        expect(bulkStats.length, equals(15));
        expect(
            bulkStats.values.every((stats) => stats.totalRatings == 1), isTrue);
      });
    });

    group('Rating Statistics Stream', () {
      test('should stream aggregate stats from recipe_social_stats doc',
          () async {
        // Arrange — Cloud Functions own writes to recipe_social_stats; the
        // stream must read the denormalized doc, not aggregate per-rating
        // snapshots (BUT-430).
        const recipeId = 'recipe-1';
        await fakeFirestore
            .collection('recipe_social_stats')
            .doc(recipeId)
            .set({
          'ratingCount': 3,
          'averageRating': 4.0,
          'ratingDistribution': {1: 0, 2: 0, 3: 1, 4: 1, 5: 1},
          'lastRatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
        });

        // Act
        final stream = repository.getRatingStatisticsStream(recipeId);
        final stats = await stream.first;

        // Assert
        expect(stats.recipeId, equals(recipeId));
        expect(stats.totalRatings, equals(3));
        expect(stats.averageRating, equals(4.0));
        expect(stats.ratingDistribution[5], equals(1));
        expect(stats.lastRatedAt, equals(DateTime(2026, 1, 1)));
      });

      test('should emit empty stats when stats doc missing', () async {
        // Arrange — no doc in recipe_social_stats means no ratings yet.
        const recipeId = 'recipe-no-ratings';

        // Act
        final stream = repository.getRatingStatisticsStream(recipeId);
        final stats = await stream.first;

        // Assert
        expect(stats.totalRatings, equals(0));
        expect(stats.averageRating, equals(0.0));
        expect(stats.ratingDistribution.values.every((c) => c == 0), isTrue);
      });
    });

    group('Get User Ratings', () {
      test('should retrieve all ratings by a user', () async {
        // Arrange
        const userId = 'user-123';
        await _seedRating(fakeFirestore, 'recipe-1_$userId',
            _createRating('recipe-1', userId, 5.0, id: 'recipe-1_$userId'));
        await _seedRating(fakeFirestore, 'recipe-2_$userId',
            _createRating('recipe-2', userId, 4.0, id: 'recipe-2_$userId'));
        await _seedRating(fakeFirestore, 'recipe-3_$userId',
            _createRating('recipe-3', userId, 3.5, id: 'recipe-3_$userId'));
        await _seedRating(fakeFirestore, 'recipe-4_other',
            _createRating('recipe-4', 'other-user', 4.0, id: 'recipe-4_other'));

        // Act
        final results = await repository.getUserRatings(userId);

        // Assert
        expect(results.length, equals(3));
        expect(results.map((r) => r.recipeId),
            containsAll(['recipe-1', 'recipe-2', 'recipe-3']));
        expect(results.every((r) => r.userId == userId), isTrue);
      });

      test('should return empty list when user has no ratings', () async {
        // Act
        final results = await repository.getUserRatings('user-123');

        // Assert
        expect(results, isEmpty);
      });
    });
  });
}

// ===== TEST HELPERS =====

/// Create a test recipe rating
RecipeRating _createRating(
  String recipeId,
  String userId,
  double rating, {
  String? id,
  String? review,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final now = DateTime.now();
  return RecipeRating(
    id: id ?? '${recipeId}_$userId',
    recipeId: recipeId,
    userId: userId,
    rating: rating,
    review: review,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
  );
}

/// Seed rating into fake Firestore
Future<void> _seedRating(
  FakeFirebaseFirestore firestore,
  String ratingId,
  RecipeRating rating,
) async {
  final data = {
    'recipeId': rating.recipeId,
    'userId': rating.userId,
    'rating': rating.rating,
    'review': rating.review,
    'createdAt': Timestamp.fromDate(rating.createdAt),
    'updatedAt': Timestamp.fromDate(rating.updatedAt),
  };

  await firestore.collection('recipe_ratings').doc(ratingId).set(data);
}
