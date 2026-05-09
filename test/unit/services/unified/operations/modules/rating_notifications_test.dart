// test/unit/services/unified/operations/modules/rating_notifications_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/operations/modules/rating_notifications.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import '../../../../../test_support/base_unit_test.dart';
import '../../../../../infrastructure/mocks/production_mocks.dart';
import '../../../../../infrastructure/builders/recipe_builder.dart';

void main() {
  group('RatingNotifications', () {
    late MockNotificationService mockNotificationService;
    late Recipe testRecipe;
    late Recipe collaborativeRecipe;

    setUpAll(() async {
      // Register fallback values for mocktail
      registerFallbackValue(NotificationStrategy.recipeComment);
      registerFallbackValue(<String>[]);
      registerFallbackValue(<String, String>{});
      registerFallbackValue(<String, dynamic>{});
      registerFallbackValue(<NotificationAction>[]);
    });

    setUp(() async {
      await BaseUnitTest.setupUnit();

      // Create mocks
      mockNotificationService = MockNotificationService();

      // Create test data
      testRecipe = RecipeBuilder()
          .withId('recipe_1')
          .withTitle('Köttbullar med lingonsylt')
          .withCreatedBy('user_123')
          .build();

      // Create collaborative recipe with social data
      collaborativeRecipe = Recipe(
        core: RecipeCore(
          id: 'recipe_2',
          title: 'Collaborative Swedish Feast',
          description: 'A collaborative recipe',
          ingredients: ['Potatoes', 'Cream', 'Dill'],
          instructions: ['Cook', 'Season', 'Serve'],
          mealType: 'dinner',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          createdBy: 'user_456',
        ),
        type: RecipeType.collaborative,
        socialData: RecipeSocialData(
          ownerId: 'user_456',
          ownerDisplayName: 'Recipe Owner',
          memberPermissions: {
            'user_456': ResourcePermission.owner,
            'user_789': ResourcePermission.editor,
          },
        ),
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      // Cleanup if needed
    });

    group('Rating Notifications', () {
      test('should send rating notification to recipe owner', () async {
        // Arrange
        when(() => mockNotificationService.sendImmediateNotification(
              targetUserIds: ['user_123'],
              strategy: NotificationStrategy.recipeComment,
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
              actions: any(named: 'actions'),
              imageUrl: any(named: 'imageUrl'),
            )).thenAnswer((_) async {});

        // Act
        await RatingNotifications.sendRatingNotification(
          notificationService: mockNotificationService,
          recipe: testRecipe,
          rating: 5.0,
          raterName: 'Test Rater',
          review: 'Excellent recipe!',
        );

        // Assert
        verify(() => mockNotificationService.sendImmediateNotification(
              targetUserIds: ['user_123'],
              strategy: NotificationStrategy.recipeComment,
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
              actions: any(named: 'actions'),
            )).called(1);
      });

      test('should format rating notification with stars', () async {
        // Arrange
        String? capturedMessage;
        when(() => mockNotificationService.sendImmediateNotification(
              targetUserIds: any(named: 'targetUserIds'),
              strategy: any(named: 'strategy'),
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
              actions: any(named: 'actions'),
              imageUrl: any(named: 'imageUrl'),
            )).thenAnswer((invocation) async {
          final variables =
              invocation.namedArguments[#variables] as Map<String, String>;
          capturedMessage = variables['commentPreview'];
        });

        // Act
        await RatingNotifications.sendRatingNotification(
          notificationService: mockNotificationService,
          recipe: testRecipe,
          rating: 4.0,
          raterName: 'Star Rater',
          review: null, // No review text
        );

        // Assert
        expect(capturedMessage, contains('⭐⭐⭐⭐')); // 4 stars
        expect(capturedMessage,
            contains('Betygsatte ditt recept')); // Swedish message
      });

      test('should truncate long review text', () async {
        // Arrange
        String? capturedReview;
        when(() => mockNotificationService.sendImmediateNotification(
              targetUserIds: any(named: 'targetUserIds'),
              strategy: any(named: 'strategy'),
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
              actions: any(named: 'actions'),
              imageUrl: any(named: 'imageUrl'),
            )).thenAnswer((invocation) async {
          final variables =
              invocation.namedArguments[#variables] as Map<String, String>;
          capturedReview = variables['commentPreview'];
        });

        final longReview =
            'This is a very long review that exceeds fifty characters and should be truncated';

        // Act
        await RatingNotifications.sendRatingNotification(
          notificationService: mockNotificationService,
          recipe: testRecipe,
          rating: 5.0,
          raterName: 'Verbose Rater',
          review: longReview,
        );

        // Assert
        expect(capturedReview, hasLength(53)); // 50 chars + '...'
        expect(capturedReview, endsWith('...'));
      });

      test('should handle collaborative recipe with socialData ownerId',
          () async {
        // Arrange
        when(() => mockNotificationService.sendImmediateNotification(
              targetUserIds: ['user_456'],
              strategy: any(named: 'strategy'),
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
              actions: any(named: 'actions'),
              imageUrl: any(named: 'imageUrl'),
            )).thenAnswer((_) async {});

        // Act
        await RatingNotifications.sendRatingNotification(
          notificationService: mockNotificationService,
          recipe: collaborativeRecipe,
          rating: 4.5,
          raterName: 'Collaborator',
          review: 'Great team effort!',
        );

        // Assert
        verify(() => mockNotificationService.sendImmediateNotification(
              targetUserIds: ['user_456'], // Uses socialData.ownerId
              strategy: any(named: 'strategy'),
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
              actions: any(named: 'actions'),
            )).called(1);
      });

      test('should handle null notification service gracefully', () async {
        // Act & Assert (should not throw)
        await expectLater(
          RatingNotifications.sendRatingNotification(
            notificationService: null,
            recipe: testRecipe,
            rating: 3.0,
            raterName: 'Test',
          ),
          completes,
        );
      });

      test('should handle errors gracefully', () async {
        // Arrange
        when(() => mockNotificationService.sendImmediateNotification(
              targetUserIds: any(named: 'targetUserIds'),
              strategy: any(named: 'strategy'),
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
              actions: any(named: 'actions'),
              imageUrl: any(named: 'imageUrl'),
            )).thenThrow(Exception('Notification failed'));

        // Act & Assert (should not throw)
        await expectLater(
          RatingNotifications.sendRatingNotification(
            notificationService: mockNotificationService,
            recipe: testRecipe,
            rating: 4.0,
            raterName: 'Test',
          ),
          completes,
        );
      });
    });

    group('Milestone Notifications', () {
      test('should send milestone notification for 5 ratings', () async {
        // Arrange
        when(() => mockNotificationService.sendImmediateNotification(
              targetUserIds: any(named: 'targetUserIds'),
              strategy: any(named: 'strategy'),
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
              actions: any(named: 'actions'),
              imageUrl: any(named: 'imageUrl'),
            )).thenAnswer((_) async {});

        // Act
        await RatingNotifications.sendRatingMilestoneNotification(
          notificationService: mockNotificationService,
          recipe: testRecipe,
          totalRatings: 5,
          averageRating: 4.5,
        );

        // Assert
        verify(() => mockNotificationService.sendImmediateNotification(
              targetUserIds: ['user_123'],
              strategy: NotificationStrategy.recipeComment,
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
              actions: any(named: 'actions'),
              imageUrl: any(named: 'imageUrl'),
            )).called(1);
      });

      test('should send milestone notification for 10 ratings', () async {
        // Arrange
        when(() => mockNotificationService.sendImmediateNotification(
              targetUserIds: any(named: 'targetUserIds'),
              strategy: any(named: 'strategy'),
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
              actions: any(named: 'actions'),
              imageUrl: any(named: 'imageUrl'),
            )).thenAnswer((_) async {});

        // Act
        await RatingNotifications.sendRatingMilestoneNotification(
          notificationService: mockNotificationService,
          recipe: testRecipe,
          totalRatings: 10,
          averageRating: 4.2,
        );

        // Assert
        verify(() => mockNotificationService.sendImmediateNotification(
              targetUserIds: any(named: 'targetUserIds'),
              strategy: any(named: 'strategy'),
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
              actions: any(named: 'actions'),
              imageUrl: any(named: 'imageUrl'),
            )).called(1);
      });

      test('should not send milestone for non-milestone counts', () async {
        // Act
        await RatingNotifications.sendRatingMilestoneNotification(
          notificationService: mockNotificationService,
          recipe: testRecipe,
          totalRatings: 7, // Not a milestone
          averageRating: 4.0,
        );

        // Assert
        verifyNever(() => mockNotificationService.sendImmediateNotification(
              targetUserIds: any(named: 'targetUserIds'),
              strategy: any(named: 'strategy'),
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
              actions: any(named: 'actions'),
              imageUrl: any(named: 'imageUrl'),
            ));
      });

      test('should include milestone type for 25 ratings', () async {
        // Arrange
        Map<String, dynamic>? capturedData;
        when(() => mockNotificationService.sendImmediateNotification(
              targetUserIds: any(named: 'targetUserIds'),
              strategy: any(named: 'strategy'),
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
              actions: any(named: 'actions'),
              imageUrl: any(named: 'imageUrl'),
            )).thenAnswer((invocation) async {
          capturedData = invocation.namedArguments[#additionalData]
              as Map<String, dynamic>;
        });

        // Act
        await RatingNotifications.sendRatingMilestoneNotification(
          notificationService: mockNotificationService,
          recipe: testRecipe,
          totalRatings: 25,
          averageRating: 4.8,
        );

        // Assert
        expect(capturedData?['milestone_type'], equals('twenty_five_ratings'));
      });

      test('should handle null notification service for milestones', () async {
        // Act & Assert (should not throw)
        await expectLater(
          RatingNotifications.sendRatingMilestoneNotification(
            notificationService: null,
            recipe: testRecipe,
            totalRatings: 50,
            averageRating: 4.5,
          ),
          completes,
        );
      });
    });

    group('Summary Notifications', () {
      test('should send rating summary notification', () async {
        // Arrange
        when(() => mockNotificationService.sendImmediateNotification(
              targetUserIds: ['user_123'],
              strategy: any(named: 'strategy'),
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
              actions: any(named: 'actions'),
              imageUrl: any(named: 'imageUrl'),
            )).thenAnswer((_) async {});

        final recipeRatingSummaries = [
          {
            'recipeName': 'Recipe 1',
            'averageRating': 4.5,
            'newRatings': 5,
          },
          {
            'recipeName': 'Recipe 2',
            'averageRating': 4.0,
            'newRatings': 3,
          },
        ];

        // Act
        await RatingNotifications.sendRatingSummaryNotification(
          notificationService: mockNotificationService,
          userId: 'user_123',
          recipeRatingSummaries: recipeRatingSummaries,
          period: 'weekly',
        );

        // Assert
        verify(() => mockNotificationService.sendImmediateNotification(
              targetUserIds: ['user_123'],
              strategy: NotificationStrategy.recipeComment,
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
              actions: any(named: 'actions'),
            )).called(1);
      });

      test('should not send empty summary', () async {
        // Act
        await RatingNotifications.sendRatingSummaryNotification(
          notificationService: mockNotificationService,
          userId: 'user_123',
          recipeRatingSummaries: [], // Empty summary
          period: 'daily',
        );

        // Assert
        verifyNever(() => mockNotificationService.sendImmediateNotification(
              targetUserIds: any(named: 'targetUserIds'),
              strategy: any(named: 'strategy'),
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
              actions: any(named: 'actions'),
              imageUrl: any(named: 'imageUrl'),
            ));
      });

      test('should include period in summary data', () async {
        // Arrange
        Map<String, dynamic>? capturedData;
        when(() => mockNotificationService.sendImmediateNotification(
              targetUserIds: any(named: 'targetUserIds'),
              strategy: any(named: 'strategy'),
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
              actions: any(named: 'actions'),
              imageUrl: any(named: 'imageUrl'),
            )).thenAnswer((invocation) async {
          capturedData = invocation.namedArguments[#additionalData]
              as Map<String, dynamic>;
        });

        // Act
        await RatingNotifications.sendRatingSummaryNotification(
          notificationService: mockNotificationService,
          userId: 'user_123',
          recipeRatingSummaries: [
            {'recipeName': 'Test', 'newRatings': 1, 'averageRating': 4.0}
          ],
          period: 'monthly',
        );

        // Assert
        expect(capturedData?['period'], equals('monthly'));
      });
    });

    group('Notification Formatting', () {
      test('should format recipe title in notification', () async {
        // Arrange
        String? capturedRecipeName;
        when(() => mockNotificationService.sendImmediateNotification(
              targetUserIds: any(named: 'targetUserIds'),
              strategy: any(named: 'strategy'),
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
              actions: any(named: 'actions'),
              imageUrl: any(named: 'imageUrl'),
            )).thenAnswer((invocation) async {
          final variables =
              invocation.namedArguments[#variables] as Map<String, String>;
          capturedRecipeName = variables['recipeName'];
        });

        // Act
        await RatingNotifications.sendRatingNotification(
          notificationService: mockNotificationService,
          recipe: testRecipe,
          rating: 5.0,
          raterName: 'Test',
        );

        // Assert
        expect(capturedRecipeName, equals('Köttbullar med lingonsylt'));
      });

      test('should include rating action in notification', () async {
        // Arrange
        List<NotificationAction>? capturedActions;
        when(() => mockNotificationService.sendImmediateNotification(
              targetUserIds: any(named: 'targetUserIds'),
              strategy: any(named: 'strategy'),
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
              actions: any(named: 'actions'),
              imageUrl: any(named: 'imageUrl'),
            )).thenAnswer((invocation) async {
          capturedActions =
              invocation.namedArguments[#actions] as List<NotificationAction>?;
        });

        // Act
        await RatingNotifications.sendRatingNotification(
          notificationService: mockNotificationService,
          recipe: testRecipe,
          rating: 4.0,
          raterName: 'Test',
        );

        // Assert
        // NotificationAction has no value-equality (`viewRecipe` is a getter
        // that constructs a fresh instance each call, with default identity
        // hash). Compare on the stable `id` field instead.
        expect(
          capturedActions?.map((a) => a.id),
          contains(NotificationAction.viewRecipe.id),
        );
      });
    });
  });
}
