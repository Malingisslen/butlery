/// Unit tests for NotificationTypes - Type system and enums
///
/// Tests notification type system including:
/// - Enum definitions and values
/// - NotificationStrategy configuration
/// - NotificationTemplate creation
/// - NotificationAction definitions
/// - BatchingConfig validation
/// - Priority and category management
library;

import 'package:flutter_test/flutter_test.dart';

// Production imports
import 'package:butlery/services/notifications/notification_types.dart';

// Test infrastructure
import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';

void main() {
  group('NotificationTypes', () {
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
    });

    setUp(() async {
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDown(() async {
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('NotificationType Enum', () {
      test('should have all expected notification types', () {
        // Assert
        expect(NotificationType.values, hasLength(5));
        expect(NotificationType.values, contains(NotificationType.immediate));
        expect(NotificationType.values, contains(NotificationType.batchable));
        expect(NotificationType.values, contains(NotificationType.silent));
        expect(NotificationType.values, contains(NotificationType.digest));
        expect(NotificationType.values, contains(NotificationType.optional));
      });

      test('should convert to string correctly', () {
        // Assert
        expect(NotificationType.immediate.toString(), contains('immediate'));
        expect(NotificationType.batchable.toString(), contains('batchable'));
        expect(NotificationType.silent.toString(), contains('silent'));
        expect(NotificationType.digest.toString(), contains('digest'));
        expect(NotificationType.optional.toString(), contains('optional'));
      });
    });

    group('NotificationPriority Enum', () {
      test('should have all expected priority levels', () {
        // Assert
        expect(NotificationPriority.values, hasLength(4));
        expect(NotificationPriority.values,
            contains(NotificationPriority.critical));
        expect(
            NotificationPriority.values, contains(NotificationPriority.high));
        expect(
            NotificationPriority.values, contains(NotificationPriority.medium));
        expect(NotificationPriority.values, contains(NotificationPriority.low));
      });

      test('should maintain correct priority order', () {
        // Assert - Index represents priority order
        expect(NotificationPriority.critical.index, equals(0));
        expect(NotificationPriority.high.index, equals(1));
        expect(NotificationPriority.medium.index, equals(2));
        expect(NotificationPriority.low.index, equals(3));
      });
    });

    group('NotificationCategory Enum', () {
      test('should have all expected categories', () {
        // Assert
        expect(NotificationCategory.values, hasLength(7));
        expect(NotificationCategory.values,
            contains(NotificationCategory.friends));
        expect(NotificationCategory.values,
            contains(NotificationCategory.recipes));
        expect(NotificationCategory.values,
            contains(NotificationCategory.collaboration));
        expect(NotificationCategory.values,
            contains(NotificationCategory.shopping));
        expect(NotificationCategory.values,
            contains(NotificationCategory.messaging));
        expect(
            NotificationCategory.values, contains(NotificationCategory.social));
        expect(
            NotificationCategory.values, contains(NotificationCategory.system));
      });
    });

    group('NotificationStrategy', () {
      test('should create strategy with required fields', () {
        // Arrange & Act
        const strategy = NotificationStrategy(
          type: NotificationType.immediate,
          priority: NotificationPriority.high,
          category: NotificationCategory.friends,
        );

        // Assert
        expect(strategy.type, equals(NotificationType.immediate));
        expect(strategy.priority, equals(NotificationPriority.high));
        expect(strategy.category, equals(NotificationCategory.friends));
        expect(strategy.batchWindow, isNull);
        expect(strategy.maxBatchSize, isNull);
        expect(strategy.requiresInternet, isTrue); // Default value
        expect(strategy.localization, isEmpty); // Default empty map
      });

      test('should create strategy with optional batch configuration', () {
        // Arrange & Act
        const strategy = NotificationStrategy(
          type: NotificationType.batchable,
          priority: NotificationPriority.medium,
          category: NotificationCategory.social,
          batchWindow: Duration(minutes: 5),
          maxBatchSize: 10,
        );

        // Assert
        expect(strategy.type, equals(NotificationType.batchable));
        expect(strategy.batchWindow, equals(const Duration(minutes: 5)));
        expect(strategy.maxBatchSize, equals(10));
      });

      test('should create strategy with localization', () {
        // Arrange & Act
        const strategy = NotificationStrategy(
          type: NotificationType.immediate,
          priority: NotificationPriority.critical,
          category: NotificationCategory.recipes,
          localization: {
            'title_sv': 'Nytt recept',
            'title_en': 'New recipe',
            'body_sv': 'Du har fått ett nytt recept',
            'body_en': 'You have received a new recipe',
          },
        );

        // Assert
        expect(strategy.localization, hasLength(4));
        expect(strategy.localization['title_sv'], equals('Nytt recept'));
        expect(strategy.localization['title_en'], equals('New recipe'));
      });

      test('should have friend request strategy', () {
        // Act
        const strategy = NotificationStrategy.friendRequest;

        // Assert
        expect(strategy.type, equals(NotificationType.immediate));
        expect(strategy.priority, equals(NotificationPriority.critical));
        expect(strategy.category, equals(NotificationCategory.friends));
        expect(
            strategy.localization['title_sv'], equals('Ny vänskapsförfrågan'));
        expect(strategy.localization['title_en'], equals('New friend request'));
      });

      test('should have recipe shared strategy', () {
        // Act
        const strategy = NotificationStrategy.recipeShared;

        // Assert
        expect(strategy.type, equals(NotificationType.immediate));
        expect(strategy.priority, equals(NotificationPriority.high));
        expect(strategy.category, equals(NotificationCategory.recipes));
        expect(strategy.localization['title_sv'], equals('Nytt recept delat'));
        expect(strategy.localization['title_en'],
            equals('Recipe shared with you'));
      });

      test('should have recipe comment strategy', () {
        // Act
        const strategy = NotificationStrategy.recipeComment;

        // Assert
        expect(strategy.type, equals(NotificationType.batchable));
        expect(strategy.priority, equals(NotificationPriority.medium));
        expect(strategy.category, equals(NotificationCategory.recipes));
        expect(strategy.batchWindow, equals(const Duration(minutes: 5)));
        expect(strategy.maxBatchSize, equals(5));
      });

      test('should have collaboration invite strategy', () {
        // Act
        const strategy = NotificationStrategy.collaborationInvite;

        // Assert
        expect(strategy.type, equals(NotificationType.immediate));
        expect(strategy.priority, equals(NotificationPriority.high));
        expect(strategy.category, equals(NotificationCategory.collaboration));
      });

      test('should have shopping list update strategy', () {
        // Act
        const strategy = NotificationStrategy.shoppingListUpdate;

        // Assert
        expect(strategy.type, equals(NotificationType.silent));
        expect(strategy.priority, equals(NotificationPriority.low));
        expect(strategy.category, equals(NotificationCategory.shopping));
        expect(strategy.requiresInternet, isFalse);
      });

      test('should have activity digest strategy', () {
        // Act
        const strategy = NotificationStrategy.activityDigest;

        // Assert
        expect(strategy.type, equals(NotificationType.digest));
        expect(strategy.priority, equals(NotificationPriority.low));
        expect(strategy.category, equals(NotificationCategory.social));
      });

      test('should have friend online strategy', () {
        // Act
        const strategy = NotificationStrategy.friendOnline;

        // Assert
        expect(strategy.type, equals(NotificationType.optional));
        expect(strategy.priority, equals(NotificationPriority.low));
        expect(strategy.category, equals(NotificationCategory.friends));
      });
    });

    group('NotificationTemplate', () {
      test('should create template with required fields', () {
        // Arrange & Act
        const template = NotificationTemplate(
          title: 'Test Title',
          body: 'Test Body',
          data: {'key': 'value'},
        );

        // Assert
        expect(template.title, equals('Test Title'));
        expect(template.body, equals('Test Body'));
        expect(template.data, equals({'key': 'value'}));
        expect(template.imageUrl, isNull);
        expect(template.actions, isNull);
      });

      test('should create template with optional fields', () {
        // Arrange & Act
        const template = NotificationTemplate(
          title: 'Recipe Ready',
          body: 'Your recipe is ready to serve',
          data: {'recipeId': '123'},
          imageUrl: 'https://example.com/recipe.jpg',
          actions: [
            NotificationAction(
              id: 'view',
              title: 'View Recipe',
            ),
          ],
        );

        // Assert
        expect(template.imageUrl, equals('https://example.com/recipe.jpg'));
        expect(template.actions, hasLength(1));
        expect(template.actions!.first.id, equals('view'));
      });

      test('should create template from strategy with variables', () {
        // Arrange
        const strategy = NotificationStrategy(
          type: NotificationType.immediate,
          priority: NotificationPriority.high,
          category: NotificationCategory.friends,
          localization: {
            'title_sv': 'Hej {name}!',
            'body_sv': '{sender} skickade ett meddelande',
          },
        );

        final variables = {
          'name': 'Anna',
          'sender': 'Erik',
        };

        // Act
        final template = NotificationTemplate.fromStrategy(
          strategy,
          variables,
        );

        // Assert
        expect(template.title, equals('Hej Anna!'));
        expect(template.body, equals('Erik skickade ett meddelande'));
        expect(template.data['type'], contains('immediate'));
        expect(template.data['priority'], contains('high'));
        expect(template.data['category'], contains('friends'));
      });

      test('should create template from strategy with additional data', () {
        // Arrange
        const strategy = NotificationStrategy(
          type: NotificationType.batchable,
          priority: NotificationPriority.medium,
          category: NotificationCategory.social,
          localization: {
            'title_sv': 'Aktivitet',
            'body_sv': 'Ny aktivitet',
          },
        );

        // Act
        final template = NotificationTemplate.fromStrategy(
          strategy,
          {},
          additionalData: {
            'userId': 'user123',
            'count': 5,
          },
          imageUrl: 'https://example.com/image.jpg',
        );

        // Assert
        expect(template.data['userId'], equals('user123'));
        expect(template.data['count'], equals(5));
        expect(template.imageUrl, equals('https://example.com/image.jpg'));
      });

      test('should use fallback text when localization missing', () {
        // Arrange
        const strategy = NotificationStrategy(
          type: NotificationType.immediate,
          priority: NotificationPriority.high,
          category: NotificationCategory.system,
          localization: {}, // Empty localization
        );

        // Act
        final template = NotificationTemplate.fromStrategy(
          strategy,
          {},
        );

        // Assert
        expect(template.title, equals('Ny aktivitet')); // Swedish fallback
        expect(template.body, equals('Du har ny aktivitet i Butlery'));
      });
    });

    group('NotificationAction', () {
      test('should create action with required fields', () {
        // Arrange & Act
        const action = NotificationAction(
          id: 'test_action',
          title: 'Test Action',
        );

        // Assert
        expect(action.id, equals('test_action'));
        expect(action.title, equals('Test Action'));
        expect(action.data, isNull);
      });

      test('should create action with data', () {
        // Arrange & Act
        const action = NotificationAction(
          id: 'navigate',
          title: 'Go to Recipe',
          data: {'recipeId': '123', 'section': 'ingredients'},
        );

        // Assert
        expect(action.data, isNotNull);
        expect(action.data!['recipeId'], equals('123'));
        expect(action.data!['section'], equals('ingredients'));
      });

      test('should have predefined accept friend action', () {
        // Assert
        expect(NotificationAction.acceptFriend.id, equals('accept_friend'));
        expect(NotificationAction.acceptFriend.title, equals('Acceptera'));
      });

      test('should have predefined decline friend action', () {
        // Assert
        expect(NotificationAction.declineFriend.id, equals('decline_friend'));
        expect(NotificationAction.declineFriend.title, equals('Avvisa'));
      });

      test('should have predefined view recipe action', () {
        // Assert
        expect(NotificationAction.viewRecipe.id, equals('view_recipe'));
        expect(NotificationAction.viewRecipe.title, equals('Visa recept'));
      });

      test('should have predefined join collaboration action', () {
        // Assert
        expect(NotificationAction.joinCollaboration.id,
            equals('join_collaboration'));
        expect(NotificationAction.joinCollaboration.title, equals('Gå med'));
      });
    });

    group('BatchingConfig', () {
      test('should create batching config with required fields', () {
        // Act
        final config = BatchingConfig(
          window: const Duration(minutes: 5),
          maxSize: 10,
          contentBuilder: (notifications) => 'Batch of ${notifications.length}',
        );

        // Assert
        expect(config.window, equals(const Duration(minutes: 5)));
        expect(config.maxSize, equals(10));
        expect(config.contentBuilder, isNotNull);
      });

      test('should build content with contentBuilder', () {
        // Arrange
        final config = BatchingConfig(
          window: const Duration(minutes: 10),
          maxSize: 20,
          contentBuilder: (notifications) {
            if (notifications.length == 1) {
              return notifications.first.body;
            }
            return '${notifications.length} new notifications';
          },
        );

        const template1 = NotificationTemplate(
          title: 'Title 1',
          body: 'Body 1',
          data: {},
        );
        const template2 = NotificationTemplate(
          title: 'Title 2',
          body: 'Body 2',
          data: {},
        );

        // Act
        final singleContent = config.contentBuilder([template1]);
        final multiContent = config.contentBuilder([template1, template2]);

        // Assert
        expect(singleContent, equals('Body 1'));
        expect(multiContent, equals('2 new notifications'));
      });

      test('should have recipe comments batch config', () {
        // Act
        final config = BatchingConfig.recipeComments;

        // Assert
        expect(config.window, equals(const Duration(minutes: 5)));
        expect(config.maxSize, equals(5));

        // Test content builder
        const template = NotificationTemplate(
          title: 'Comment',
          body: 'Erik commented on your recipe',
          data: {},
        );

        final singleContent = config.contentBuilder([template]);
        final multiContent =
            config.contentBuilder([template, template, template]);

        expect(singleContent, equals('Erik commented on your recipe'));
        expect(multiContent, equals('3 nya kommentarer på dina recept'));
      });

      test('should have recipe likes batch config', () {
        // Act
        final config = BatchingConfig.recipeLikes;

        // Assert
        expect(config.window, equals(const Duration(minutes: 10)));
        expect(config.maxSize, equals(10));

        // Test content builder
        const template = NotificationTemplate(
          title: 'Like',
          body: 'Anna liked your recipe',
          data: {},
        );

        final singleContent = config.contentBuilder([template]);
        final multiContent = config
            .contentBuilder([template, template, template, template, template]);

        expect(singleContent, equals('Anna liked your recipe'));
        expect(multiContent, equals('5 personer gillade dina recept'));
      });
    });

    group('Edge Cases', () {
      test('should handle null values in template data', () {
        // Arrange & Act
        const template = NotificationTemplate(
          title: 'Test',
          body: 'Body',
          data: {
            'key1': null,
            'key2': 'value',
          },
        );

        // Assert
        expect(template.data['key1'], isNull);
        expect(template.data['key2'], equals('value'));
      });

      test('should handle empty strings in localization', () {
        // Arrange
        const strategy = NotificationStrategy(
          type: NotificationType.immediate,
          priority: NotificationPriority.high,
          category: NotificationCategory.friends,
          localization: {
            'title_sv': '',
            'body_sv': '',
          },
        );

        // Act
        final template = NotificationTemplate.fromStrategy(
          strategy,
          {},
        );

        // Assert
        // Empty localization strings are passed through (no fallback)
        expect(template.title, isEmpty);
        expect(template.body, isEmpty);
      });

      test('should handle special characters in template variables', () {
        // Arrange
        const strategy = NotificationStrategy(
          type: NotificationType.immediate,
          priority: NotificationPriority.high,
          category: NotificationCategory.recipes,
          localization: {
            'title_sv': 'Recept: {name}',
            'body_sv': 'Ingredienser: {ingredients}',
          },
        );

        final variables = {
          'name': 'Köttbullar & Gräddsås',
          'ingredients': 'Kött, Ägg, Mjölk (3%), "Kryddor"',
        };

        // Act
        final template = NotificationTemplate.fromStrategy(
          strategy,
          variables,
        );

        // Assert
        expect(template.title, equals('Recept: Köttbullar & Gräddsås'));
        expect(template.body,
            equals('Ingredienser: Kött, Ägg, Mjölk (3%), "Kryddor"'));
      });
    });
  });
}
