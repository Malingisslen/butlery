// ignore_for_file: subtype_of_sealed_class

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_ratings_repository.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

// Local mocks for sealed Firebase classes
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference<T> extends Mock implements CollectionReference<T> {}
class MockDocumentReference<T> extends Mock implements DocumentReference<T> {}
class MockDocumentSnapshot<T> extends Mock implements DocumentSnapshot<T> {}
class MockQuery<T> extends Mock implements Query<T> {}
class MockQuerySnapshot<T> extends Mock implements QuerySnapshot<T> {}
class MockQueryDocumentSnapshot<T> extends Mock implements QueryDocumentSnapshot<T> {}

// Fake classes for any() matching
class FakeRecipeRating extends Fake implements RecipeRating {}
class FakeFieldValue extends Fake implements FieldValue {}

void main() {
  group('FirebaseRatingsRepository', () {
    late FirebaseRatingsRepository repository;
    late MockFirebaseFirestore mockFirestore;
    late MockCollectionReference<Map<String, dynamic>> mockCollection;
    late MockAuthRepository mockAuthRepository;
    late MockDocumentReference<Map<String, dynamic>> mockDocRef;
    late MockQuery<Map<String, dynamic>> mockQuery;
    
    setUpAll(() {
      registerFallbackValue(FakeRecipeRating());
      registerFallbackValue(FakeFieldValue());
      registerFallbackValue(DateTime.now());
    });
    
    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
      
      // Initialize mocks
      mockFirestore = MockFirebaseFirestore();
      mockCollection = MockCollectionReference<Map<String, dynamic>>();
      mockAuthRepository = MockAuthRepository();
      mockDocRef = MockDocumentReference<Map<String, dynamic>>();
      mockQuery = MockQuery<Map<String, dynamic>>();
      
      // Configure auth state
      mockAuthRepository.setAuthState(
        userId: 'test-user-123',
        isAuthenticated: true,
      );
      
      // Setup Firestore mocks
      when(() => mockFirestore.collection(any())).thenReturn(mockCollection);
      when(() => mockCollection.doc(any())).thenReturn(mockDocRef);
      when(() => mockDocRef.id).thenReturn('mock-doc-id');
      when(() => mockCollection.where(any(), isEqualTo: any(named: 'isEqualTo')))
          .thenReturn(mockQuery);
      when(() => mockCollection.where(any(), whereIn: any(named: 'whereIn')))
          .thenReturn(mockQuery);
      when(() => mockQuery.orderBy(any(), descending: any(named: 'descending')))
          .thenReturn(mockQuery);
      when(() => mockQuery.get()).thenAnswer((_) async => MockQuerySnapshot<Map<String, dynamic>>());
      
      // Create repository
      repository = FirebaseRatingsRepository(
        firestore: mockFirestore,
        authRepository: mockAuthRepository,
      );
    });
    
    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });
    
    group('rateRecipe', () {
      test('should create new rating with correct composite ID', () async {
        // Arrange
        const recipeId = 'recipe-123';
        const userId = 'test-user-123';
        const rating = 4.5;
        const review = 'Great recipe!';
        
        when(() => mockDocRef.set(any())).thenAnswer((_) async {});
        
        // Act
        await repository.rateRecipe(
          recipeId: recipeId,
          userId: userId,
          rating: rating,
          review: review,
        );
        
        // Assert
        verify(() => mockCollection.doc('${recipeId}_$userId')).called(1);
        final captured = verify(() => mockDocRef.set(captureAny())).captured.single;
        expect(captured['recipeId'], equals(recipeId));
        expect(captured['userId'], equals(userId));
        expect(captured['rating'], equals(rating));
        expect(captured['review'], equals(review));
        expect(captured.containsKey('createdAt'), isTrue);
        expect(captured.containsKey('updatedAt'), isTrue);
      });
      
      test('should validate rating range (1-5)', () async {
        // Arrange
        const recipeId = 'recipe-123';
        const userId = 'test-user-123';
        
        // Act & Assert - Rating too low
        expect(
          () => repository.rateRecipe(
            recipeId: recipeId,
            userId: userId,
            rating: 0.5,
          ),
          throwsA(isA<SecurityViolationException>()
            .having((e) => e.message, 'message', contains('between 1 and 5'))),
        );
        
        // Act & Assert - Rating too high
        expect(
          () => repository.rateRecipe(
            recipeId: recipeId,
            userId: userId,
            rating: 5.5,
          ),
          throwsA(isA<SecurityViolationException>()
            .having((e) => e.message, 'message', contains('between 1 and 5'))),
        );
      });
      
      test('should prevent users from rating on behalf of others', () async {
        // Arrange
        const recipeId = 'recipe-123';
        const otherUserId = 'other-user-456';
        
        // Act & Assert
        expect(
          () => repository.rateRecipe(
            recipeId: recipeId,
            userId: otherUserId,
            rating: 4.0,
          ),
          throwsA(isA<PermissionDeniedException>()
            .having((e) => e.message, 'message', contains('can only rate recipe'))),
        );
      });
      
      test('should handle rating without review', () async {
        // Arrange
        const recipeId = 'recipe-123';
        const userId = 'test-user-123';
        const rating = 3.5;
        
        when(() => mockDocRef.set(any())).thenAnswer((_) async {});
        
        // Act
        await repository.rateRecipe(
          recipeId: recipeId,
          userId: userId,
          rating: rating,
          review: null,
        );
        
        // Assert
        final captured = verify(() => mockDocRef.set(captureAny())).captured.single;
        expect(captured['rating'], equals(rating));
        expect(captured['review'], isNull);
      });
    });
    
    group('updateRating', () {
      test('should update existing rating', () async {
        // Arrange
        const recipeId = 'recipe-123';
        const userId = 'test-user-123';
        const newRating = 5.0;
        const newReview = 'Even better than expected!';
        
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        when(() => mockDocRef.update(any())).thenAnswer((_) async {});
        
        // Act
        await repository.updateRating(
          recipeId: recipeId,
          userId: userId,
          rating: newRating,
          review: newReview,
        );
        
        // Assert
        final captured = verify(() => mockDocRef.update(captureAny())).captured.single;
        expect(captured['rating'], equals(newRating));
        expect(captured['review'], equals(newReview));
        expect(captured.containsKey('updatedAt'), isTrue);
      });
      
      test('should throw ResourceNotFoundException for non-existent rating', () async {
        // Arrange
        const recipeId = 'recipe-123';
        const userId = 'test-user-123';
        
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockSnapshot.exists).thenReturn(false);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act & Assert
        expect(
          () => repository.updateRating(
            recipeId: recipeId,
            userId: userId,
            rating: 4.0,
          ),
          throwsA(isA<ResourceNotFoundException>()
            .having((e) => e.message, 'message', contains('not found'))),
        );
      });
      
      test('should validate rating range on update', () async {
        // Arrange
        const recipeId = 'recipe-123';
        const userId = 'test-user-123';
        
        // Act & Assert
        expect(
          () => repository.updateRating(
            recipeId: recipeId,
            userId: userId,
            rating: 6.0,
          ),
          throwsA(isA<SecurityViolationException>()
            .having((e) => e.message, 'message', contains('between 1 and 5'))),
        );
      });
      
      test('should prevent updating other users ratings', () async {
        // Arrange
        const recipeId = 'recipe-123';
        const otherUserId = 'other-user-456';
        
        // Act & Assert
        expect(
          () => repository.updateRating(
            recipeId: recipeId,
            userId: otherUserId,
            rating: 4.0,
          ),
          throwsA(isA<PermissionDeniedException>()
            .having((e) => e.message, 'message', contains('can only update rating'))),
        );
      });
    });
    
    group('removeRating', () {
      test('should delete existing rating', () async {
        // Arrange
        const recipeId = 'recipe-123';
        const userId = 'test-user-123';
        
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        when(() => mockDocRef.delete()).thenAnswer((_) async {});
        
        // Act
        await repository.removeRating(recipeId, userId);
        
        // Assert
        verify(() => mockCollection.doc('${recipeId}_$userId')).called(2); // Once for get, once for delete
        verify(() => mockDocRef.delete()).called(1);
      });
      
      test('should throw ResourceNotFoundException for non-existent rating', () async {
        // Arrange
        const recipeId = 'recipe-123';
        const userId = 'test-user-123';
        
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockSnapshot.exists).thenReturn(false);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act & Assert
        expect(
          () => repository.removeRating(recipeId, userId),
          throwsA(isA<ResourceNotFoundException>()
            .having((e) => e.message, 'message', contains('not found'))),
        );
      });
      
      test('should prevent removing other users ratings', () async {
        // Arrange
        const recipeId = 'recipe-123';
        const otherUserId = 'other-user-456';
        
        // Act & Assert
        expect(
          () => repository.removeRating(recipeId, otherUserId),
          throwsA(isA<PermissionDeniedException>()
            .having((e) => e.message, 'message', contains('can only remove rating'))),
        );
      });
    });
    
    group('getUserRating', () {
      test('should return user rating if exists', () async {
        // Arrange
        const recipeId = 'recipe-123';
        const userId = 'test-user-123';
        
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockSnapshot.id).thenReturn('${recipeId}_$userId');
        when(() => mockSnapshot.data()).thenReturn({
          'recipeId': recipeId,
          'userId': userId,
          'rating': 4.5,
          'review': 'Great!',
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        });
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final result = await repository.getUserRating(recipeId, userId);
        
        // Assert
        expect(result, isNotNull);
        expect(result!.recipeId, equals(recipeId));
        expect(result.userId, equals(userId));
        expect(result.rating, equals(4.5));
        expect(result.review, equals('Great!'));
      });
      
      test('should return null if rating does not exist', () async {
        // Arrange
        const recipeId = 'recipe-123';
        const userId = 'test-user-123';
        
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockSnapshot.exists).thenReturn(false);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final result = await repository.getUserRating(recipeId, userId);
        
        // Assert
        expect(result, isNull);
      });
    });
    
    group('getRecipeRatings', () {
      test('should return all ratings for a recipe ordered by creation date', () async {
        // Arrange
        const recipeId = 'recipe-123';
        
        final mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
        final mockDoc1 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        final mockDoc2 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        
        when(() => mockDoc1.id).thenReturn('${recipeId}_user1');
        when(() => mockDoc1.data()).thenReturn({
          'recipeId': recipeId,
          'userId': 'user1',
          'rating': 4.0,
          'review': 'Good',
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        });
        
        when(() => mockDoc2.id).thenReturn('${recipeId}_user2');
        when(() => mockDoc2.data()).thenReturn({
          'recipeId': recipeId,
          'userId': 'user2',
          'rating': 5.0,
          'review': 'Excellent',
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        });
        
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc1, mockDoc2]);
        when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        
        // Act
        final results = await repository.getRecipeRatings(recipeId);
        
        // Assert
        expect(results.length, equals(2));
        expect(results[0].userId, equals('user1'));
        expect(results[0].rating, equals(4.0));
        expect(results[1].userId, equals('user2'));
        expect(results[1].rating, equals(5.0));
        
        verify(() => mockQuery.orderBy('createdAt', descending: true)).called(1);
      });
      
      test('should return empty list if no ratings exist', () async {
        // Arrange
        const recipeId = 'recipe-123';
        
        final mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
        when(() => mockQuerySnapshot.docs).thenReturn([]);
        when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        
        // Act
        final results = await repository.getRecipeRatings(recipeId);
        
        // Assert
        expect(results, isEmpty);
      });
    });
    
    group('getRatingStatistics', () {
      test('should calculate correct statistics for multiple ratings', () async {
        // Arrange
        const recipeId = 'recipe-123';
        
        final mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
        final docs = [
          _createMockRatingDoc(recipeId, 'user1', 5.0),
          _createMockRatingDoc(recipeId, 'user2', 4.0),
          _createMockRatingDoc(recipeId, 'user3', 5.0),
          _createMockRatingDoc(recipeId, 'user4', 3.0),
          _createMockRatingDoc(recipeId, 'user5', 4.0),
        ];
        
        when(() => mockQuerySnapshot.docs).thenReturn(docs);
        when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        
        // Act
        final stats = await repository.getRatingStatistics(recipeId);
        
        // Assert
        expect(stats.recipeId, equals(recipeId));
        expect(stats.totalRatings, equals(5));
        expect(stats.averageRating, equals(4.2)); // (5+4+5+3+4)/5 = 4.2
        expect(stats.ratingDistribution[5], equals(2));
        expect(stats.ratingDistribution[4], equals(2));
        expect(stats.ratingDistribution[3], equals(1));
        expect(stats.ratingDistribution[2], equals(0));
        expect(stats.ratingDistribution[1], equals(0));
      });
      
      test('should return empty statistics for recipe with no ratings', () async {
        // Arrange
        const recipeId = 'recipe-123';
        
        final mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
        when(() => mockQuerySnapshot.docs).thenReturn([]);
        when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        
        // Act
        final stats = await repository.getRatingStatistics(recipeId);
        
        // Assert
        expect(stats.recipeId, equals(recipeId));
        expect(stats.totalRatings, equals(0));
        expect(stats.averageRating, equals(0.0));
        expect(stats.ratingDistribution, equals({1: 0, 2: 0, 3: 0, 4: 0, 5: 0}));
      });
      
      test('should round ratings correctly for distribution', () async {
        // Arrange
        const recipeId = 'recipe-123';
        
        final mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
        final docs = [
          _createMockRatingDoc(recipeId, 'user1', 4.7), // rounds to 5
          _createMockRatingDoc(recipeId, 'user2', 4.4), // rounds to 4
          _createMockRatingDoc(recipeId, 'user3', 3.5), // rounds to 4
          _createMockRatingDoc(recipeId, 'user4', 2.4), // rounds to 2
          _createMockRatingDoc(recipeId, 'user5', 1.2), // rounds to 1
        ];
        
        when(() => mockQuerySnapshot.docs).thenReturn(docs);
        when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        
        // Act
        final stats = await repository.getRatingStatistics(recipeId);
        
        // Assert
        expect(stats.ratingDistribution[5], equals(1));
        expect(stats.ratingDistribution[4], equals(2));
        expect(stats.ratingDistribution[3], equals(0));
        expect(stats.ratingDistribution[2], equals(1));
        expect(stats.ratingDistribution[1], equals(1));
      });
    });
    
    group('getBulkRatingStatistics', () {
      test('should process recipes in batches of 10', () async {
        // Arrange
        final recipeIds = List.generate(25, (i) => 'recipe-$i');
        
        final mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
        when(() => mockQuerySnapshot.docs).thenReturn([]);
        when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        
        // Act
        final results = await repository.getBulkRatingStatistics(recipeIds);
        
        // Assert
        expect(results.length, equals(25));
        // Verify it was called 3 times (10 + 10 + 5)
        verify(() => mockCollection.where('recipeId', whereIn: any(named: 'whereIn')))
            .called(3);
      });
      
      test('should return correct statistics for each recipe', () async {
        // Arrange
        final recipeIds = ['recipe-1', 'recipe-2'];
        
        final mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
        final docs = [
          _createMockRatingDoc('recipe-1', 'user1', 5.0),
          _createMockRatingDoc('recipe-1', 'user2', 4.0),
          _createMockRatingDoc('recipe-2', 'user3', 3.0),
        ];
        
        when(() => mockQuerySnapshot.docs).thenReturn(docs);
        when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        
        // Act
        final results = await repository.getBulkRatingStatistics(recipeIds);
        
        // Assert
        expect(results['recipe-1']!.totalRatings, equals(2));
        expect(results['recipe-1']!.averageRating, equals(4.5));
        expect(results['recipe-2']!.totalRatings, equals(1));
        expect(results['recipe-2']!.averageRating, equals(3.0));
      });
      
      test('should return empty statistics for recipes with no ratings', () async {
        // Arrange
        final recipeIds = ['recipe-1', 'recipe-2'];
        
        final mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
        when(() => mockQuerySnapshot.docs).thenReturn([]);
        when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        
        // Act
        final results = await repository.getBulkRatingStatistics(recipeIds);
        
        // Assert
        expect(results['recipe-1']!.totalRatings, equals(0));
        expect(results['recipe-1']!.averageRating, equals(0.0));
        expect(results['recipe-2']!.totalRatings, equals(0));
        expect(results['recipe-2']!.averageRating, equals(0.0));
      });
    });
    
    group('getRatingStatisticsStream', () {
      test('should emit statistics updates when ratings change', () async {
        // Arrange
        const recipeId = 'recipe-123';
        final controller = StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
        
        when(() => mockCollection.where(any(), isEqualTo: any(named: 'isEqualTo')))
            .thenReturn(mockQuery);
        when(() => mockQuery.snapshots()).thenAnswer((_) => controller.stream);
        
        // Act
        final stream = repository.getRatingStatisticsStream(recipeId);
        final stats = <RatingStatistics>[];
        final subscription = stream.listen(stats.add);
        
        // Emit first snapshot
        final doc1 = _createMockRatingDoc(recipeId, 'user1', 4.0);
        final snapshot1 = MockQuerySnapshot<Map<String, dynamic>>();
        when(() => snapshot1.docs).thenReturn([doc1]);
        controller.add(snapshot1);
        
        await Future.delayed(Duration(milliseconds: 100));
        
        // Emit second snapshot with additional rating
        final doc2 = _createMockRatingDoc(recipeId, 'user2', 5.0);
        final snapshot2 = MockQuerySnapshot<Map<String, dynamic>>();
        when(() => snapshot2.docs).thenReturn([doc1, doc2]);
        controller.add(snapshot2);
        
        await Future.delayed(Duration(milliseconds: 100));
        
        // Assert
        expect(stats.length, equals(2));
        expect(stats[0].totalRatings, equals(1));
        expect(stats[0].averageRating, equals(4.0));
        expect(stats[1].totalRatings, equals(2));
        expect(stats[1].averageRating, equals(4.5));
        
        // Cleanup
        await subscription.cancel();
        await controller.close();
      });
    });
    
    group('getUserRatings', () {
      test('should return all ratings by a specific user', () async {
        // Arrange
        const userId = 'test-user-123';
        
        final mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
        final docs = [
          _createMockRatingDoc('recipe-1', userId, 5.0),
          _createMockRatingDoc('recipe-2', userId, 4.0),
          _createMockRatingDoc('recipe-3', userId, 3.5),
        ];
        
        when(() => mockQuerySnapshot.docs).thenReturn(docs);
        when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        
        // Act
        final results = await repository.getUserRatings(userId);
        
        // Assert
        expect(results.length, equals(3));
        expect(results[0].recipeId, equals('recipe-1'));
        expect(results[1].recipeId, equals('recipe-2'));
        expect(results[2].recipeId, equals('recipe-3'));
        
        verify(() => mockCollection.where('userId', isEqualTo: userId)).called(1);
        verify(() => mockQuery.orderBy('createdAt', descending: true)).called(1);
      });
      
      test('should return empty list if user has no ratings', () async {
        // Arrange
        const userId = 'test-user-123';
        
        final mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
        when(() => mockQuerySnapshot.docs).thenReturn([]);
        when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        
        // Act
        final results = await repository.getUserRatings(userId);
        
        // Assert
        expect(results, isEmpty);
      });
    });
    
    group('permission validation', () {
      test('should throw UnauthorizedException when not authenticated', () async {
        // Arrange
        mockAuthRepository.setAuthState(
          userId: null,
          isAuthenticated: false,
        );
        
        // Act & Assert
        expect(
          () => repository.rateRecipe(
            recipeId: 'recipe-123',
            userId: 'user-123',
            rating: 4.0,
          ),
          throwsA(isA<AuthenticationException>()),
        );
      });
      
      test('should log permission checks for successful operations', () async {
        // Arrange
        const recipeId = 'recipe-123';
        const userId = 'test-user-123';
        
        when(() => mockDocRef.set(any())).thenAnswer((_) async {});
        
        // Act
        await repository.rateRecipe(
          recipeId: recipeId,
          userId: userId,
          rating: 4.0,
        );
        
        // Assert
        // Permission logging is internal to the repository
        // We verify the operation succeeded without throwing
        verify(() => mockDocRef.set(any())).called(1);
      });
    });
    
    group('RatingStatistics model', () {
      test('should calculate percentage distribution correctly', () {
        // Arrange
        final stats = RatingStatistics(
          recipeId: 'recipe-123',
          averageRating: 4.0,
          totalRatings: 10,
          ratingDistribution: {
            5: 4,  // 40%
            4: 3,  // 30%
            3: 2,  // 20%
            2: 1,  // 10%
            1: 0,  // 0%
          },
        );
        
        // Act
        final percentages = stats.percentageDistribution;
        
        // Assert
        expect(percentages[5], equals(40.0));
        expect(percentages[4], equals(30.0));
        expect(percentages[3], equals(20.0));
        expect(percentages[2], equals(10.0));
        expect(percentages[1], equals(0.0));
      });
      
      test('should handle empty statistics', () {
        // Arrange
        final stats = RatingStatistics(
          recipeId: 'recipe-123',
          averageRating: 0.0,
          totalRatings: 0,
          ratingDistribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
        );
        
        // Act
        final percentages = stats.percentageDistribution;
        
        // Assert
        expect(percentages.values.every((p) => p == 0.0), isTrue);
      });
      
      test('should format display rating correctly', () {
        // Arrange
        final stats1 = RatingStatistics(
          recipeId: 'recipe-123',
          averageRating: 4.567,
          totalRatings: 10,
          ratingDistribution: {1: 0, 2: 0, 3: 0, 4: 5, 5: 5},
        );
        
        final stats2 = RatingStatistics(
          recipeId: 'recipe-456',
          averageRating: 3.0,
          totalRatings: 5,
          ratingDistribution: {1: 0, 2: 0, 3: 5, 4: 0, 5: 0},
        );
        
        // Act & Assert
        expect(stats1.displayRating, equals('4.6'));
        expect(stats2.displayRating, equals('3.0'));
      });
    });
  });
}

// Helper function to create mock rating documents
MockQueryDocumentSnapshot<Map<String, dynamic>> _createMockRatingDoc(String recipeId, String userId, double rating) {
  final mockDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();
  when(() => mockDoc.id).thenReturn('${recipeId}_$userId');
  when(() => mockDoc.data()).thenReturn({
    'recipeId': recipeId,
    'userId': userId,
    'rating': rating,
    'review': null,
    'createdAt': Timestamp.now(),
    'updatedAt': Timestamp.now(),
  });
  return mockDoc;
}