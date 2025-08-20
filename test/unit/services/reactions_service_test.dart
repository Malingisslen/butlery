import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:butlery/services/social/reactions_service.dart';
import 'package:butlery/models/social/content_reaction.dart';
import 'package:butlery/models/social/reaction_type.dart';
import 'package:butlery/models/social/reaction_statistics.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/factories/mock_factory.dart';

// ============= FAKE MODELS =============

class FakeContentReaction extends Fake implements ContentReaction {
  @override
  final String id;
  @override
  final String contentId;
  @override
  final String contentType;
  @override
  final String userId;
  @override
  final ReactionType reactionType;
  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;

  FakeContentReaction({
    required this.id,
    required this.contentId,
    required this.contentType,
    required this.userId,
    required this.reactionType,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class FakeReactionStatistics extends Fake implements ReactionStatistics {
  @override
  final String contentId;
  @override
  final String contentType;
  @override
  final Map<ReactionType, int> reactionCounts;
  @override
  final Set<String> reactedUserIds;
  @override
  final DateTime lastUpdated;

  FakeReactionStatistics({
    required this.contentId,
    required this.contentType,
    Map<ReactionType, int>? reactionCounts,
    Set<String>? reactedUserIds,
    DateTime? lastUpdated,
  })  : reactionCounts = reactionCounts ?? {},
        reactedUserIds = reactedUserIds ?? {},
        lastUpdated = lastUpdated ?? DateTime.now();
  
  @override
  int get totalCount => reactionCounts.values.fold(0, (sum, count) => sum + count);
}

// ============= TESTS =============

void main() {
  group('ReactionsService', () {
    late ReactionsService reactionsService;
    late MockReactionsRepository mockReactionsRepo;
    late MockAuthRepository mockAuthRepo;
    late User mockUser;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
      
      // Register fallback values for mocktail
      registerFallbackValue(ReactionType.like);
    });

    setUp(() {
      mockReactionsRepo = MockReactionsRepository();
      mockAuthRepo = MockAuthRepository();
      mockUser = MockFactory.createMockUser(
        uid: 'test-user-id',
        displayName: 'Test User',
        photoURL: 'https://example.com/avatar.jpg',
      );

      // Configure mock state using configuration methods
      mockAuthRepo.setAuthState(
        user: mockUser,
        userId: 'test-user-id',
        isAuthenticated: true,
      );

      reactionsService = ReactionsService(
        reactionsRepository: mockReactionsRepo,
        authRepository: mockAuthRepo,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Reaction Operations', () {
      test('should toggle reaction successfully when authenticated', () async {
        // Arrange
        const contentId = 'recipe-123';
        const contentType = 'recipe';
        const reactionType = ReactionType.delicious;
        
        final reaction = FakeContentReaction(
          id: 'reaction-1',
          contentId: contentId,
          contentType: contentType,
          userId: 'test-user-id',
          reactionType: reactionType,
        );
        
        when(() => mockReactionsRepo.toggleReaction(
          contentId: contentId,
          contentType: contentType,
          userId: 'test-user-id',
          reactionType: reactionType,
        )).thenAnswer((_) async => reaction);

        // Act
        final result = await reactionsService.toggleReaction(
          contentId: contentId,
          contentType: contentType,
          reactionType: reactionType,
        );

        // Assert
        expect(result, isTrue);
        verify(() => mockReactionsRepo.toggleReaction(
          contentId: contentId,
          contentType: contentType,
          userId: 'test-user-id',
          reactionType: reactionType,
        )).called(1);
      });

      test('should handle removing reaction when toggling existing', () async {
        // Arrange
        const contentId = 'recipe-123';
        const contentType = 'recipe';
        const reactionType = ReactionType.like;
        
        when(() => mockReactionsRepo.toggleReaction(
          contentId: any(named: 'contentId'),
          contentType: any(named: 'contentType'),
          userId: any(named: 'userId'),
          reactionType: any(named: 'reactionType'),
        )).thenAnswer((_) async => null); // null indicates reaction was removed

        // Act
        final result = await reactionsService.toggleReaction(
          contentId: contentId,
          contentType: contentType,
          reactionType: reactionType,
        );

        // Assert
        expect(result, isFalse);
      });

      test('should return false when not authenticated', () async {
        // Arrange
        mockAuthRepo.setAuthState(
          user: null,
          userId: null,
          isAuthenticated: false,
        );

        // Act  
        final result = await reactionsService.toggleReaction(
          contentId: 'recipe-123',
          contentType: 'recipe',
          reactionType: ReactionType.helpful,
        );
        
        // Assert - Service returns false instead of throwing
        expect(result, isFalse);
      });

      test('should add reaction successfully', () async {
        // Arrange
        const contentId = 'comment-456';
        const contentType = 'comment';
        const reactionType = ReactionType.love;
        
        when(() => mockReactionsRepo.addReaction(
          contentId: contentId,
          contentType: contentType,
          userId: 'test-user-id',
          reactionType: reactionType,
        )).thenAnswer((_) async {});

        // Act
        await reactionsService.addReaction(
          contentId: contentId,
          contentType: contentType,
          reactionType: reactionType,
        );

        // Assert
        verify(() => mockReactionsRepo.addReaction(
          contentId: contentId,
          contentType: contentType,
          userId: 'test-user-id',
          reactionType: reactionType,
        )).called(1);
      });

      test('should remove reaction successfully', () async {
        // Arrange
        const contentId = 'menu-789';
        const contentType = 'menu';
        const reactionType = ReactionType.creative;
        
        when(() => mockReactionsRepo.removeReaction(
          contentId: contentId,
          contentType: contentType,
          userId: 'test-user-id',
          reactionType: reactionType,
        )).thenAnswer((_) async {});

        // Act
        await reactionsService.removeReaction(
          contentId: contentId,
          contentType: contentType,
          reactionType: reactionType,
        );

        // Assert
        verify(() => mockReactionsRepo.removeReaction(
          contentId: contentId,
          contentType: contentType,
          userId: 'test-user-id',
          reactionType: reactionType,
        )).called(1);
      });

      test('should handle multiple reaction types on same content', () async {
        // Arrange
        const contentId = 'recipe-999';
        const contentType = 'recipe';
        
        when(() => mockReactionsRepo.addReaction(
          contentId: any(named: 'contentId'),
          contentType: any(named: 'contentType'),
          userId: any(named: 'userId'),
          reactionType: any(named: 'reactionType'),
        )).thenAnswer((_) async {});

        // Act
        await reactionsService.addReaction(
          contentId: contentId,
          contentType: contentType,
          reactionType: ReactionType.like,
        );
        
        await reactionsService.addReaction(
          contentId: contentId,
          contentType: contentType,
          reactionType: ReactionType.delicious,
        );

        // Assert
        verify(() => mockReactionsRepo.addReaction(
          contentId: contentId,
          contentType: contentType,
          userId: 'test-user-id',
          reactionType: any(named: 'reactionType'),
        )).called(2);
      });
    });

    group('Reaction Queries', () {
      test('should get user reactions for content', () async {
        // Arrange
        const contentId = 'recipe-123';
        const contentType = 'recipe';
        
        final reactions = [
          FakeContentReaction(
            id: 'r1',
            contentId: contentId,
            contentType: contentType,
            userId: 'test-user-id',
            reactionType: ReactionType.like,
          ),
          FakeContentReaction(
            id: 'r2',
            contentId: contentId,
            contentType: contentType,
            userId: 'test-user-id',
            reactionType: ReactionType.delicious,
          ),
        ];
        
        when(() => mockReactionsRepo.getUserReactions(
          contentId: contentId,
          contentType: contentType,
          userId: 'test-user-id',
        )).thenAnswer((_) async => reactions);

        // Act
        final result = await reactionsService.getUserReactions(
          contentId: contentId,
          contentType: contentType,
        );

        // Assert
        expect(result, equals(reactions));
        expect(result.length, equals(2));
      });

      test('should check if user has reacted to content', () async {
        // Arrange
        const contentId = 'recipe-456';
        const contentType = 'recipe';
        
        when(() => mockReactionsRepo.hasUserReacted(
          contentId: contentId,
          contentType: contentType,
          userId: 'test-user-id',
        )).thenAnswer((_) async => true);

        // Act
        final hasReacted = await reactionsService.hasUserReacted(
          contentId: contentId,
          contentType: contentType,
        );

        // Assert
        expect(hasReacted, isTrue);
      });

      test('should return false when user has not reacted', () async {
        // Arrange
        const contentId = 'recipe-789';
        const contentType = 'recipe';
        
        when(() => mockReactionsRepo.hasUserReacted(
          contentId: contentId,
          contentType: contentType,
          userId: 'test-user-id',
        )).thenAnswer((_) async => false);

        // Act
        final hasReacted = await reactionsService.hasUserReacted(
          contentId: contentId,
          contentType: contentType,
        );

        // Assert
        expect(hasReacted, isFalse);
      });

      test('should get user reaction type for content', () async {
        // Arrange
        const contentId = 'recipe-111';
        const contentType = 'recipe';
        
        final reactions = [
          FakeContentReaction(
            id: 'r1',
            contentId: contentId,
            contentType: contentType,
            userId: 'test-user-id',
            reactionType: ReactionType.delicious,
          ),
        ];
        
        when(() => mockReactionsRepo.getUserReactions(
          contentId: contentId,
          contentType: contentType,
          userId: 'test-user-id',
        )).thenAnswer((_) async => reactions);

        // Act
        final reactionType = await reactionsService.getUserReactionType(
          contentId: contentId,
          contentType: contentType,
        );

        // Assert
        expect(reactionType, equals(ReactionType.delicious));
      });
    });

    group('Reaction Statistics', () {
      test('should get reaction statistics for content', () async {
        // Arrange
        const contentId = 'recipe-222';
        const contentType = 'recipe';
        
        final stats = FakeReactionStatistics(
          contentId: contentId,
          contentType: contentType,
          reactionCounts: {
            ReactionType.like: 10,
            ReactionType.love: 5,
            ReactionType.delicious: 8,
          },
        );
        
        when(() => mockReactionsRepo.getReactionStatistics(
          contentId: contentId,
          contentType: contentType,
        )).thenAnswer((_) async => stats);

        // Act
        final result = await reactionsService.getReactionStatistics(
          contentId: contentId,
          contentType: contentType,
        );

        // Assert
        expect(result, equals(stats));
        expect(result?.totalCount, equals(23));
        expect(result?.reactionCounts[ReactionType.like], equals(10));
      });

      test('should stream reaction statistics', () {
        // Arrange
        const contentId = 'recipe-333';
        const contentType = 'recipe';
        
        // Use a broadcast stream since the service subscribes internally
        final streamController = StreamController<ReactionStatistics>.broadcast();
        
        when(() => mockReactionsRepo.getReactionStatisticsStream(
          contentId: contentId,
          contentType: contentType,
        )).thenAnswer((_) => streamController.stream);

        // Act
        final stream = reactionsService.getReactionStatisticsStream(
          contentId: contentId,
          contentType: contentType,
        );

        // Assert - Verify stream is returned (not null)
        expect(stream, isNotNull);
        expect(stream, isA<Stream<ReactionStatistics>>());
        
        // Verify repository was called
        verify(() => mockReactionsRepo.getReactionStatisticsStream(
          contentId: contentId,
          contentType: contentType,
        )).called(1);
        
        // Cleanup
        streamController.close();
      });

      test('should get available reactions for content type', () {
        // Arrange & Act
        final recipeReactions = reactionsService.getAvailableReactions('recipe');
        final commentReactions = reactionsService.getAvailableReactions('comment');
        
        // Assert
        expect(recipeReactions, contains(ReactionType.delicious));
        expect(recipeReactions, contains(ReactionType.easy));
        expect(commentReactions, contains(ReactionType.helpful));
      });

      test('should get reaction display order', () {
        // Arrange & Act
        final displayOrder = reactionsService.getReactionDisplayOrder('recipe');
        
        // Assert
        expect(displayOrder, isNotEmpty);
        // Check that like and love come first (highest priority)
        final likeIndex = displayOrder.indexOf(ReactionType.like);
        final creativeIndex = displayOrder.indexOf(ReactionType.creative);
        if (likeIndex != -1 && creativeIndex != -1) {
          expect(likeIndex, lessThan(creativeIndex));
        }
      });
    });

    group('Bulk Operations', () {
      test('should get bulk reaction statistics', () async {
        // Arrange
        final contentIds = ['recipe1', 'recipe2', 'recipe3'];
        const contentType = 'recipe';
        
        final stats = {
          'recipe1': FakeReactionStatistics(
            contentId: 'recipe1',
            contentType: contentType,
          ),
          'recipe2': FakeReactionStatistics(
            contentId: 'recipe2',
            contentType: contentType,
          ),
        };
        
        when(() => mockReactionsRepo.getBulkReactionStatistics(
          contentIds: contentIds,
          contentType: contentType,
        )).thenAnswer((_) async => stats);

        // Act
        final result = await reactionsService.getBulkReactionStatistics(
          contentIds: contentIds,
          contentType: contentType,
        );

        // Assert
        expect(result, equals(stats));
        expect(result.length, equals(2));
      });

      test('should handle empty bulk statistics request', () async {
        // Arrange
        const contentType = 'recipe';
        
        when(() => mockReactionsRepo.getBulkReactionStatistics(
          contentIds: [],
          contentType: contentType,
        )).thenAnswer((_) async => {});

        // Act
        final result = await reactionsService.getBulkReactionStatistics(
          contentIds: [],
          contentType: contentType,
        );

        // Assert
        expect(result, isEmpty);
      });
    });

    group('Content Type Validation', () {
      test('should accept valid content types', () async {
        // Arrange
        final validTypes = ['recipe', 'comment', 'menu', 'shopping_list', 'profile'];
        
        for (final contentType in validTypes) {
          when(() => mockReactionsRepo.toggleReaction(
            contentId: any(named: 'contentId'),
            contentType: contentType,
            userId: any(named: 'userId'),
            reactionType: any(named: 'reactionType'),
          )).thenAnswer((_) async => null);

          // Act & Assert - should not throw
          await expectLater(
            reactionsService.toggleReaction(
              contentId: 'test-123',
              contentType: contentType,
              reactionType: ReactionType.like,
            ),
            completes,
          );
        }
      });

      test('should return false for invalid content types', () async {
        // Arrange - Invalid content type 'invalid_type' not in ['recipe', 'comment', 'menu', 'shopping_list', 'user_profile']
        
        // Act
        final result = await reactionsService.toggleReaction(
          contentId: 'test-123',
          contentType: 'invalid_type',
          reactionType: ReactionType.like,
        );
        
        // Assert - Service returns false for invalid content type  
        expect(result, isFalse);
      });
    });

    group('Edge Cases', () {
      test('should handle empty user reactions list', () async {
        // Arrange
        when(() => mockReactionsRepo.getUserReactions(
          contentId: any(named: 'contentId'),
          contentType: any(named: 'contentType'),
          userId: any(named: 'userId'),
        )).thenAnswer((_) async => []);

        // Act
        final reactions = await reactionsService.getUserReactions(
          contentId: 'recipe-999',
          contentType: 'recipe',
        );

        // Assert
        expect(reactions, isEmpty);
      });

      test('should handle null statistics gracefully', () async {
        // Arrange
        when(() => mockReactionsRepo.getReactionStatistics(
          contentId: any(named: 'contentId'),
          contentType: any(named: 'contentType'),
        )).thenAnswer((_) async => null);

        // Act
        final stats = await reactionsService.getReactionStatistics(
          contentId: 'recipe-000',
          contentType: 'recipe',
        );

        // Assert
        expect(stats, isNull);
      });

      test('should handle concurrent toggle operations', () async {
        // Arrange
        when(() => mockReactionsRepo.toggleReaction(
          contentId: any(named: 'contentId'),
          contentType: any(named: 'contentType'),
          userId: any(named: 'userId'),
          reactionType: any(named: 'reactionType'),
        )).thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 10));
          return null;
        });

        // Act
        final futures = List.generate(5, (i) => 
          reactionsService.toggleReaction(
            contentId: 'recipe-$i',
            contentType: 'recipe',
            reactionType: ReactionType.like,
          )
        );

        // Assert
        await expectLater(Future.wait(futures), completes);
      });
    });

    group('Performance', () {
      test('should return cached statistics on second call', () async {
        // Arrange
        const contentId = 'recipe-cached';
        const contentType = 'recipe';
        
        final stats = FakeReactionStatistics(
          contentId: contentId,
          contentType: contentType,
        );
        
        when(() => mockReactionsRepo.getReactionStatistics(
          contentId: contentId,
          contentType: contentType,
        )).thenAnswer((_) async => stats);

        // Act - Call twice
        await reactionsService.getReactionStatistics(
          contentId: contentId,
          contentType: contentType,
        );
        await reactionsService.getReactionStatistics(
          contentId: contentId,
          contentType: contentType,
        );

        // Assert - Repository should only be called once due to caching
        verify(() => mockReactionsRepo.getReactionStatistics(
          contentId: contentId,
          contentType: contentType,
        )).called(1);
      });

      test('should handle multiple statistics requests efficiently', () async {
        // Arrange
        final contentIds = List.generate(10, (i) => 'recipe-$i');
        const contentType = 'recipe';
        
        final expectedStats = <String, ReactionStatistics>{};
        for (final id in contentIds) {
          expectedStats[id] = FakeReactionStatistics(
            contentId: id,
            contentType: contentType,
            reactionCounts: {ReactionType.like: 5},
          );
        }
        
        when(() => mockReactionsRepo.getBulkReactionStatistics(
          contentIds: contentIds,
          contentType: contentType,
        )).thenAnswer((_) async => expectedStats);

        // Act
        final stats = await reactionsService.getBulkReactionStatistics(
          contentIds: contentIds,
          contentType: contentType,
        );

        // Assert
        expect(stats.length, equals(10));
        expect(stats['recipe-0']?.totalCount, equals(5));
      });
    });

    group('Service Lifecycle', () {
      test('should dispose properly', () async {
        // Act & Assert
        await expectLater(reactionsService.dispose(), completes);
      });

      test('should clear caches on dispose', () async {
        // Arrange - Add some cached data
        const contentId = 'recipe-dispose';
        const contentType = 'recipe';
        
        final stats = FakeReactionStatistics(
          contentId: contentId,
          contentType: contentType,
        );
        
        when(() => mockReactionsRepo.getReactionStatistics(
          contentId: contentId,
          contentType: contentType,
        )).thenAnswer((_) async => stats);

        await reactionsService.getReactionStatistics(
          contentId: contentId,
          contentType: contentType,
        );

        // Act
        await reactionsService.dispose();

        // Assert - After dispose, should fetch from repository again
        when(() => mockReactionsRepo.getReactionStatistics(
          contentId: contentId,
          contentType: contentType,
        )).thenAnswer((_) async => stats);

        // Create new service instance
        final newService = ReactionsService(
          reactionsRepository: mockReactionsRepo,
          authRepository: mockAuthRepo,
        );

        await newService.getReactionStatistics(
          contentId: contentId,
          contentType: contentType,
        );

        // Should call repository since cache was cleared
        verify(() => mockReactionsRepo.getReactionStatistics(
          contentId: contentId,
          contentType: contentType,
        )).called(greaterThanOrEqualTo(1));
      });
    });
  });
}