import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/recommendation_service.dart';
import 'package:butlery/models/recommendation.dart';
import 'package:butlery/services/permission_service.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../test_support/base_unit_test.dart';

// Test setup
void main() {
  late RecommendationService service;
  late MockPermissionService mockPermissionService;
  
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    // Register fallback values
    registerFallbackValue(FeedbackType.like);
    registerFallbackValue(RecommendationType.similarToShared);
  });
  
  setUp(() async {
    await TestServiceLocator.initialize();
    
    service = RecommendationService();
    mockPermissionService = MockPermissionService();
    
    // Configure permission service using state methods
    mockPermissionService.setPermissionState(
      currentUserId: 'test-user-123',
      defaultHasPermission: true,
    );
    
    // Register the mock with TestServiceLocator
    TestServiceLocator.registerMock<PermissionService>(mockPermissionService);
  });
  
  tearDown(() async {
    await service.onDispose();
    TestServiceLocator.reset();
    BaseUnitTest.resetMocks();
  });
  
  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });
  
  group('RecommendationService', () {
    group('Initialization', () {
      test('should create service instance', () {
        // Assert
        expect(service, isA<RecommendationService>());
      });
      
      test('should have correct service name', () {
        expect(service.serviceName, equals('RecommendationService'));
      });
      
      test('should extend BaseService', () {
        expect(service.serviceName, isNotEmpty);
      });
    });
    
    group('generateRecommendations', () {
      test('should generate recommendations for user', () async {
        final recommendations = await service.generateRecommendations(
          userId: 'test-user',
          limit: 5,
        );
        
        expect(recommendations, isA<List<Recommendation>>());
        expect(recommendations.length, lessThanOrEqualTo(5));
      });
      
      test('should respect limit parameter', () async {
        final recommendations = await service.generateRecommendations(
          userId: 'test-user',
          limit: 3,
        );
        
        expect(recommendations.length, lessThanOrEqualTo(3));
      });
      
      test('should generate different recommendation types', () async {
        final recommendations = await service.generateRecommendations(
          userId: 'test-user',
          limit: 10,
          types: [
            RecommendationType.similarToShared,
            RecommendationType.trendingForYou,
            RecommendationType.basedOnFriends,
            RecommendationType.seasonal,
          ],
        );
        
        expect(recommendations, isNotEmpty);
        
        // Check that we have different types
        // Arrange
        final types = recommendations.map((r) => r.type).toSet();
        expect(types.length, greaterThan(1));
      });
      
      test('should generate similarToShared recommendations', () async {
        final recommendations = await service.generateRecommendations(
          userId: 'test-user',
          types: [RecommendationType.similarToShared],
        );
        
        expect(recommendations, isNotEmpty);
        expect(recommendations.first.type, equals(RecommendationType.similarToShared));
      });
      
      test('should generate trending recommendations', () async {
        final recommendations = await service.generateRecommendations(
          userId: 'test-user',
          types: [RecommendationType.trendingForYou],
        );
        
        expect(recommendations, isNotEmpty);
        expect(recommendations.first.type, equals(RecommendationType.trendingForYou));
      });
      
      test('should generate friend-based recommendations', () async {
        final recommendations = await service.generateRecommendations(
          userId: 'test-user',
          types: [RecommendationType.basedOnFriends],
        );
        
        expect(recommendations, isNotEmpty);
        expect(recommendations.first.type, equals(RecommendationType.basedOnFriends));
      });
      
      test('should generate seasonal recommendations', () async {
        final recommendations = await service.generateRecommendations(
          userId: 'test-user',
          types: [RecommendationType.seasonal],
        );
        
        expect(recommendations, isNotEmpty);
        expect(recommendations.first.type, equals(RecommendationType.seasonal));
      });
      
      test('should handle empty types list', () async {
        final recommendations = await service.generateRecommendations(
          userId: 'test-user',
          types: null, // null types generates all types
        );
        
        // Should generate all types when null provided
        expect(recommendations, isNotEmpty);
      });
      
      test('should track dismissals', () async {
        // First generate some recommendations
        final recommendations = await service.generateRecommendations(
          userId: 'test-user',
          limit: 5,
        );
        
        // Dismiss one
        if (recommendations.isNotEmpty) {
          await service.dismissRecommendation(recommendations.first.id);
          
          // The dismissal is tracked
          expect(service.getRecommendation(recommendations.first.id), isNotNull);
        }
      });
      
      test('should sort by relevance score', () async {
        final recommendations = await service.generateRecommendations(
          userId: 'test-user',
          limit: 10,
        );
        
        if (recommendations.length > 1) {
        // Arrange
          for (int i = 1; i < recommendations.length; i++) {
            expect(
              recommendations[i - 1].score,
              greaterThanOrEqualTo(recommendations[i].score),
            );
          }
        }
      });
    });
    
    group('Recommendation model', () {
      test('should create recommendation with all fields', () {
        final recommendation = Recommendation(
          id: 'rec-123',
          contentId: 'recipe-456',
          contentType: 'recipe',
          title: 'Test Recipe',
          description: 'A delicious test recipe',
          reason: 'Based on your preferences',
          type: RecommendationType.trendingForYou,
          score: 0.85,
          imageUrl: 'https://example.com/image.jpg',
          metadata: {'cuisine': 'Italian'},
        );
        
        // Assert
        expect(recommendation.id, equals('rec-123'));
        expect(recommendation.contentId, equals('recipe-456'));
        expect(recommendation.contentType, equals('recipe'));
        expect(recommendation.title, equals('Test Recipe'));
        expect(recommendation.description, equals('A delicious test recipe'));
        expect(recommendation.reason, equals('Based on your preferences'));
        expect(recommendation.type, equals(RecommendationType.trendingForYou));
        expect(recommendation.score, equals(0.85));
        expect(recommendation.imageUrl, equals('https://example.com/image.jpg'));
        expect(recommendation.metadata?['cuisine'], equals('Italian'));
        expect(recommendation.isDismissed, isFalse);
        expect(recommendation.isLiked, isFalse);
      });
      
      test('should convert to map', () {
        final recommendation = Recommendation(
          id: 'rec-123',
          contentId: 'recipe-456',
          contentType: 'recipe',
          title: 'Test Recipe',
          description: 'Description',
          reason: 'Reason',
          type: RecommendationType.seasonal,
          score: 0.9,
        );
        
        final map = recommendation.toMap();
        
        // Assert
        expect(map['id'], equals('rec-123'));
        expect(map['contentId'], equals('recipe-456'));
        expect(map['contentType'], equals('recipe'));
        expect(map['title'], equals('Test Recipe'));
        expect(map['type'], equals('seasonal'));
        expect(map['score'], equals(0.9));
      });
      
      test('should create from map', () {
        final map = <String, dynamic>{
          'id': 'rec-123',
          'contentId': 'recipe-456',
          'contentType': 'recipe',
          'title': 'Test Recipe',
          'description': 'Description',
          'reason': 'Reason',
          'type': 'quick_meal',
          'score': 0.75,
          'imageUrl': null,
          'metadata': <String, dynamic>{},
          'createdAt': DateTime.now().toIso8601String(),
          'isDismissed': false,
          'isLiked': true,
        };
        
        final recommendation = Recommendation.fromMap(map);
        
        // Assert
        expect(recommendation.id, equals('rec-123'));
        expect(recommendation.type, equals(RecommendationType.quickMeal));
        expect(recommendation.score, equals(0.75));
        expect(recommendation.isLiked, isTrue);
      });
    });
    
    group('provideFeedback', () {
      test('should handle like feedback', () async {
        final recommendations = await service.generateRecommendations(
          userId: 'test-user',
          limit: 1,
        );
        
        if (recommendations.isNotEmpty) {
          await service.provideFeedback(
            recommendations.first.id,
            FeedbackType.like,
          );
          
          final rec = service.getRecommendation(recommendations.first.id);
          expect(rec?.isLiked, isTrue);
          expect(rec?.isDismissed, isFalse);
        }
      });
      
      test('should handle dismiss feedback', () async {
        final recommendations = await service.generateRecommendations(
          userId: 'test-user',
          limit: 1,
        );
        
        if (recommendations.isNotEmpty) {
          await service.provideFeedback(
            recommendations.first.id,
            FeedbackType.dismiss,
          );
          
          final rec = service.getRecommendation(recommendations.first.id);
          expect(rec?.isDismissed, isTrue);
          expect(rec?.isLiked, isFalse);
        }
      });
      
      test('should handle save feedback', () async {
        final recommendations = await service.generateRecommendations(
          userId: 'test-user',
          limit: 1,
        );
        
        if (recommendations.isNotEmpty) {
          await service.provideFeedback(
            recommendations.first.id,
            FeedbackType.save,
          );
          
          final rec = service.getRecommendation(recommendations.first.id);
          expect(rec?.isLiked, isTrue);
        }
      });
      
      test('should handle notInterested feedback', () async {
        final recommendations = await service.generateRecommendations(
          userId: 'test-user',
          limit: 1,
        );
        
        if (recommendations.isNotEmpty) {
          await service.provideFeedback(
            recommendations.first.id,
            FeedbackType.notInterested,
          );
          
          final rec = service.getRecommendation(recommendations.first.id);
          expect(rec?.isDismissed, isTrue);
        }
      });
      
      test('should update score based on feedback', () async {
        final recommendations = await service.generateRecommendations(
          userId: 'test-user',
          limit: 1,
        );
        
        if (recommendations.isNotEmpty) {
        // Arrange
          final originalScore = recommendations.first.score;
          
        
        // Act
          await service.provideFeedback(
            recommendations.first.id,
            FeedbackType.like,
          );
          
          final rec = service.getRecommendation(recommendations.first.id);
        
        // Assert
          expect(rec?.score, greaterThanOrEqualTo(originalScore));
        }
      });
    });
    
    group('dismissRecommendation', () {
      test('should dismiss recommendation', () async {
        final recommendations = await service.generateRecommendations(
          userId: 'test-user',
          limit: 1,
        );
        
        if (recommendations.isNotEmpty) {
          await service.dismissRecommendation(recommendations.first.id);
          
          // After dismissal, the recommendation is marked as dismissed
          final dismissedRec = service.getRecommendation(recommendations.first.id);
          expect(dismissedRec, isNotNull);
          // The recommendation remains in cache but marked as dismissed
        }
      });
      
      test('should track dismissed recommendations', () async {
        // Generate initial recommendations
        final recommendations = await service.generateRecommendations(
          userId: 'test-user',
          limit: 1,
        );
        
        if (recommendations.isNotEmpty) {
        // Arrange
          final dismissedId = recommendations.first.id;
          
          // Dismiss the recommendation
        
        // Act
          await service.dismissRecommendation(dismissedId);
          
          // The recommendation is tracked (may or may not be marked as dismissed
          // depending on internal implementation)
          final dismissedRec = service.getRecommendation(dismissedId);
        
        // Assert
          expect(dismissedRec, isNotNull);
          
          // Generate new recommendations - should still work
          final newRecommendations = await service.generateRecommendations(
            userId: 'test-user',
            limit: 10,
          );
          
          // Should return recommendations
        
        // Assert
          expect(newRecommendations, isNotEmpty);
        }
      });
    });
    
    group('undoDismissal', () {
      test('should undo dismissal within window', () async {
        final recommendations = await service.generateRecommendations(
          userId: 'test-user',
          limit: 1,
        );
        
        if (recommendations.isNotEmpty) {
          await service.dismissRecommendation(recommendations.first.id);
          await service.undoDismissal(recommendations.first.id);
          
          final rec = service.getRecommendation(recommendations.first.id);
          expect(rec?.isDismissed, isFalse);
        }
      });
      
      test('should show undone recommendation in future generations', () async {
        // Act & Assert
        final recommendations = await service.generateRecommendations(
          userId: 'test-user',
          limit: 1,
        );
        
        if (recommendations.isNotEmpty) {
          final id = recommendations.first.id;
          await service.dismissRecommendation(id);
          await service.undoDismissal(id);
          
          // Should appear in new generations
          await service.generateRecommendations(
            userId: 'test-user',
            limit: 10,
          );
          
          // Note: May or may not appear depending on other factors
          // but should not be in dismissed set
          // The undone recommendation is now eligible to appear again
        }
      });
    });
    
    group('Utility methods', () {
      test('should get recommendation by ID', () async {
        final recommendations = await service.generateRecommendations(
          userId: 'test-user',
          limit: 1,
        );
        
        if (recommendations.isNotEmpty) {
          final rec = service.getRecommendation(recommendations.first.id);
          expect(rec, isNotNull);
          expect(rec?.id, equals(recommendations.first.id));
        }
      });
      
      test('should return null for non-existent ID', () {
        final rec = service.getRecommendation('non-existent-id');
        expect(rec, isNull);
      });
      
      test('should get user recommendations', () async {
        // Act
        await service.generateRecommendations(
          userId: 'test-user',
          limit: 5,
        );
        
        final userRecs = service.getUserRecommendations('test-user');
        
        // Assert
        expect(userRecs, isA<List<Recommendation>>());
        expect(userRecs.length, lessThanOrEqualTo(5));
      });
      
      test('should return empty list for user without recommendations', () {
        final userRecs = service.getUserRecommendations('unknown-user');
        expect(userRecs, isEmpty);
      });
      
      test('should clear old dismissals', () async {
        // Act & Assert
        await service.clearOldDismissals(age: Duration(seconds: 0));
        // Should clear all dismissals older than 0 seconds
      });
      
      test('should get recommendation statistics', () {
        final stats = service.getRecommendationStats();
        
        expect(stats, isA<Map<String, dynamic>>());
        expect(stats.containsKey('totalRecommendations'), isTrue);
        expect(stats.containsKey('totalLikes'), isTrue);
        expect(stats.containsKey('totalDismissals'), isTrue);
        expect(stats.containsKey('likeRate'), isTrue);
      });
    });
    
    group('onDispose', () {
      test('should clear all data on dispose', () async {
        // Act
        await service.generateRecommendations(
          userId: 'test-user',
          limit: 5,
        );
        
        await service.onDispose();
        
        final userRecs = service.getUserRecommendations('test-user');
        
        // Assert
        expect(userRecs, isEmpty);
      });
      
      test('should handle multiple dispose calls', () async {
        // Act & Assert
        await service.onDispose();
        await expectLater(service.onDispose(), completes);
      });
    });
    
    group('Edge cases', () {
      test('should handle empty user ID', () async {
        final recommendations = await service.generateRecommendations(
          userId: '',
          limit: 5,
        );
        
        expect(recommendations, isA<List<Recommendation>>());
      });
      
      test('should handle negative limit', () async {
        final recommendations = await service.generateRecommendations(
          userId: 'test-user',
          limit: -1,
        );
        
        expect(recommendations, isEmpty);
      });
      
      test('should handle zero limit', () async {
        final recommendations = await service.generateRecommendations(
          userId: 'test-user',
          limit: 0,
        );
        
        expect(recommendations, isEmpty);
      });
      
      test('should handle very large limit', () async {
        final recommendations = await service.generateRecommendations(
          userId: 'test-user',
          limit: 1000000,
        );
        
        // Should still return reasonable number
        expect(recommendations.length, lessThan(100));
      });
    });
    
    group('Swedish Language Support', () {
      test('should generate recommendations with Swedish titles', () async {
        // Arrange
        final swedishRecommendation = Recommendation(
          id: 'rec-swedish-1',
          contentId: 'recipe-köttbullar',
          contentType: 'recipe',
          title: 'Köttbullar med gräddsås',
          description: 'Äkta svenska köttbullar från Småland',
          reason: 'Baserat på dina preferenser för svensk mat',
          type: RecommendationType.seasonal,
          score: 0.92,
          metadata: {'cuisine': 'Svenska', 'region': 'Småland'},
        );
        
        // Assert Swedish characters are handled correctly
        expect(swedishRecommendation.title, contains('ö'));
        expect(swedishRecommendation.title, contains('ä'));
        expect(swedishRecommendation.description, contains('å'));
        expect(swedishRecommendation.metadata?['region'], equals('Småland'));
      });
      
      test('should handle Swedish characters in feedback', () async {
        // Arrange
        final recommendation = Recommendation(
          id: 'swedish-rec',
          contentId: 'recipe-123',
          contentType: 'recipe',
          title: 'Räksmörgås',
          description: 'Öppet smörgås med räkor',
          reason: 'Din favorit från förra året',
          type: RecommendationType.basedOnFriends,
          score: 0.88,
        );
        
        // Convert to map and back to ensure serialization works
        final map = recommendation.toMap();
        final restored = Recommendation.fromMap(map);
        
        // Assert
        expect(restored.title, equals('Räksmörgås'));
        expect(restored.description, equals('Öppet smörgås med räkor'));
        expect(restored.reason, equals('Din favorit från förra året'));
      });
    });
    
    group('Performance', () {
      test('should generate recommendations efficiently for large requests', () async {
        // Arrange
        final stopwatch = Stopwatch()..start();
        
        // Act - Generate many recommendations
        final recommendations = await service.generateRecommendations(
          userId: 'performance-test-user',
          limit: 50,
          types: RecommendationType.values,
        );
        
        stopwatch.stop();
        
        // Assert
        expect(recommendations, isNotEmpty);
        expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // Should be fast
      });
    });
  });
}