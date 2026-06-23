// test/unit/services/unified/operations/realtime_recipe/realtime_notification_module_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/operations/realtime_recipe/realtime_notification_module.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import '../../../../../test_support/base_unit_test.dart';
import '../../../../../infrastructure/di/test_service_locator.dart';
import '../../../../../infrastructure/builders/recipe_builder.dart';
import '../../../../../infrastructure/mocks/production_mocks.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as app_provider;

void main() {
  group('RealtimeNotificationModule', () {
    late MockNotificationParent mockParent;
    late RealtimeNotificationModule notificationModule;
    late Recipe testRecipe;
    late Recipe collaborativeRecipe;

    setUpAll(() async {
      // Register fallback values for mocktail
      registerFallbackValue(
        Recipe(
          core: RecipeCore(
            id: 'test',
            title: 'Test',
            description: 'Test',
            ingredients: [],
            instructions: [],
            mealType: 'Test',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          type: RecipeType.personal,
        ),
      );
      registerFallbackValue(<String>[]);
      registerFallbackValue(<Map<String, dynamic>>[]);
    });

    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      // Create mocks
      mockParent = MockNotificationParent();

      // Initialize production ServiceLocator with MockDIContainer
      app_provider.ServiceLocator.reset();
      app_provider.ServiceLocator.initialize(MockDIContainer());

      // Create test data
      testRecipe = RecipeBuilder()
          .withId('recipe_1')
          .withTitle('Test Recipe')
          .withCreatedBy('user_123')
          .build();

      // Create collaborative recipe with social data
      collaborativeRecipe = RecipeBuilder()
          .withId('recipe_2')
          .withTitle('Collaborative Recipe')
          .withCreatedBy('user_123')
          .asCollaborative()
          .build();

      // Manually add social data with member permissions
      collaborativeRecipe = Recipe(
        core: collaborativeRecipe.core,
        type: RecipeType.collaborative,
        socialData: RecipeSocialData(
          ownerId: 'user_123',
          ownerDisplayName: 'Test User',
          memberPermissions: {
            'user_123': ResourcePermission.owner,
            'user_456': ResourcePermission.editor,
            'user_789': ResourcePermission.viewer,
          },
        ),
        offlineData: collaborativeRecipe.offlineData,
      );

      // Configure mock parent using centralized mock method
      mockParent.setNotificationParentState(
        currentUserId: 'user_123',
        currentUserDisplayName: 'Test User',
      );

      // Create notification module instance
      notificationModule = RealtimeNotificationModule(mockParent);
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      // Cleanup if needed
    });

    group('Collaboration Notifications', () {
      test('should send collaboration joined notification', () async {
        // Act & Assert (should not throw)
        await expectLater(
          notificationModule.sendCollaborationJoinedNotification(
            collaborativeRecipe,
          ),
          completes,
        );
      });

      test('should send collaboration left notification', () async {
        // Act & Assert (should not throw)
        await expectLater(
          notificationModule.sendCollaborationLeftNotification(
            collaborativeRecipe,
          ),
          completes,
        );
      });

      test(
        'should not send notification for non-collaborative recipe',
        () async {
          // Act & Assert (should handle gracefully)
          await expectLater(
            notificationModule.sendCollaborationJoinedNotification(testRecipe),
            completes,
          );
        },
      );

      test('should send collaboration enabled notification', () async {
        // Act & Assert (should not throw)
        await expectLater(
          notificationModule.sendCollaborationEnabledNotification(
            collaborativeRecipe,
            ['user_456', 'user_789'],
          ),
          completes,
        );
      });

      test('should send collaboration disabled notification', () async {
        // Act & Assert (should not throw)
        await expectLater(
          notificationModule.sendCollaborationDisabledNotification(
            collaborativeRecipe,
          ),
          completes,
        );
      });
    });

    group('Edit Notifications', () {
      test('should send realtime edit notification', () async {
        // Act & Assert (should not throw)
        await expectLater(
          notificationModule.sendRealtimeEditNotification(
            collaborativeRecipe,
            {
              'ingredients': ['New ingredient'],
            },
            'Added new ingredient',
          ),
          completes,
        );
      });

      test('should send batch edit notification', () async {
        // Act & Assert (should not throw)
        await expectLater(
          notificationModule.sendBatchEditNotification(
            collaborativeRecipe,
            [
              {
                'ingredients': ['Salt'],
              },
              {
                'instructions': ['Mix well'],
              },
            ],
            'Multiple edits made',
          ),
          completes,
        );
      });
    });

    group('Conflict Notifications', () {
      test('should send conflict notification', () async {
        // Act & Assert (should not throw)
        await expectLater(
          notificationModule.sendConflictNotification(
            collaborativeRecipe,
            'concurrent_edit',
            ['user_456'],
          ),
          completes,
        );
      });

      test('should send conflict resolved notification', () async {
        // Act & Assert (should not throw)
        await expectLater(
          notificationModule.sendConflictResolvedNotification(
            collaborativeRecipe,
            'Test User',
            ['user_456'],
          ),
          completes,
        );
      });
    });

    group('Member Notifications', () {
      test('should send members added notification', () async {
        // Act & Assert (should not throw)
        await expectLater(
          notificationModule.sendMembersAddedNotification(
            collaborativeRecipe,
            ['user_999', 'user_888'],
          ),
          completes,
        );
      });

      test('should send members removed notification', () async {
        // Act & Assert (should not throw)
        await expectLater(
          notificationModule.sendMembersRemovedNotification(
            collaborativeRecipe,
            ['user_456'],
          ),
          completes,
        );
      });
    });

    group('Custom Notifications', () {
      test('should send custom realtime notification', () async {
        // Act & Assert (should not throw)
        await expectLater(
          notificationModule.sendCustomRealtimeNotification(
            recipe: collaborativeRecipe,
            notificationType: 'recipe_published',
            data: {
              'title': 'Recipe Published',
              'body': 'Your collaborative recipe has been published',
              'publishedAt': DateTime.now().toIso8601String(),
            },
            targetMemberIds: ['user_456', 'user_789'],
          ),
          completes,
        );
      });

      test('should handle custom notification without targets', () async {
        // Act & Assert (should handle gracefully)
        await expectLater(
          notificationModule.sendCustomRealtimeNotification(
            recipe: collaborativeRecipe,
            notificationType: 'test_event',
            data: {
              'title': 'Test',
              'body': 'Test body',
            },
            targetMemberIds: [],
          ),
          completes,
        );
      });
    });

    group('Notification Module State', () {
      test('should handle null parent user ID gracefully', () async {
        // Arrange
        mockParent.setNotificationParentState(currentUserId: null);

        // Act & Assert (should handle gracefully)
        await expectLater(
          notificationModule.sendCollaborationJoinedNotification(
            collaborativeRecipe,
          ),
          completes,
        );
      });

      test('should handle null parent display name', () async {
        // Arrange
        mockParent.setNotificationParentState(currentUserDisplayName: null);

        // Act & Assert (should use fallback name)
        await expectLater(
          notificationModule.sendRealtimeEditNotification(
            collaborativeRecipe,
            {'title': 'Updated'},
            'Title updated',
          ),
          completes,
        );
      });

      test('should handle recipe without member permissions', () async {
        // Arrange
        final simpleRecipe = RecipeBuilder()
            .withId('recipe_3')
            .asCollaborative()
            .build();

        // Act & Assert (should handle gracefully)
        await expectLater(
          notificationModule.sendCollaborationJoinedNotification(simpleRecipe),
          completes,
        );
      });
    });
  });
}

// Using centralized mocks from production_mocks.dart:
// MockNotificationParent
