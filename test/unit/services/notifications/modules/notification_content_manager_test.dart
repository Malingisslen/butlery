/// Unit tests for NotificationContentManager
///
/// Tests notification content generation including template creation,
/// variable substitution, localization, batch content building, and digest generation.
/// Tests against the REAL NotificationContentManager production code.
library;

import 'package:flutter_test/flutter_test.dart';

// Production code being tested
import 'package:butlery/services/notifications/modules/notification_content_manager.dart';
import 'package:butlery/services/notifications/notification_types.dart';

// Test infrastructure
import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/di/test_service_locator.dart';

void main() {
  group('NotificationContentManager', () {
    late NotificationContentManager contentManager;

    // Create test notification strategy
    NotificationStrategy createTestStrategy({
      NotificationType? type,
      NotificationCategory? category,
      NotificationPriority? priority,
      Map<String, String>? localization,
    }) {
      return NotificationStrategy(
        type: type ?? NotificationType.immediate,
        priority: priority ?? NotificationPriority.medium,
        category: category ?? NotificationCategory.social,
        localization:
            localization ??
            {
              'title_sv': 'Test titel {senderName}',
              'body_sv': 'Test meddelande {recipeTitle}',
              'title_en': 'Test title {senderName}',
              'body_en': 'Test message {recipeTitle}',
            },
        requiresInternet: true,
      );
    }

    // Create test notification template
    NotificationTemplate createTestTemplate({
      String? title,
      String? body,
      Map<String, dynamic>? data,
      String? imageUrl,
      List<NotificationAction>? actions,
    }) {
      return NotificationTemplate(
        title: title ?? 'Test Notification',
        body: body ?? 'Test notification body',
        data:
            data ??
            {
              'category': 'social',
              'timestamp': DateTime.now().toIso8601String(),
            },
        imageUrl: imageUrl,
        actions: actions,
      );
    }

    setUp(() async {
      // Initialize test infrastructure
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      // Create the REAL NotificationContentManager
      contentManager = NotificationContentManager(
        userId: 'test-user-123',
      );
    });

    tearDown(() async {
      // Clean up
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    group('Notification ID Generation', () {
      test('should generate unique notification IDs', () {
        // Arrange
        final strategy = createTestStrategy(
          category: NotificationCategory.recipes,
        );

        // Act
        final id1 = contentManager.generateNotificationId('user-456', strategy);
        final id2 = contentManager.generateNotificationId('user-456', strategy);

        // Assert
        expect(id1, isNotEmpty);
        expect(id2, isNotEmpty);
        expect(id1, isNot(equals(id2))); // Should be unique
        expect(id1, contains('recipes'));
        expect(id1, contains('user-456'));
      });

      test('should handle ID generation errors gracefully', () {
        // Arrange
        final strategy = createTestStrategy();

        // Act - Generate with special characters in user ID
        final id = contentManager.generateNotificationId(
          'user/with\\special:chars',
          strategy,
        );

        // Assert
        expect(id, isNotEmpty);
        expect(id, contains('user/with\\special:chars'));
      });

      test('should include timestamp in notification ID', () {
        // Arrange
        final strategy = createTestStrategy();
        final beforeTime = DateTime.now().millisecondsSinceEpoch;

        // Act
        final id = contentManager.generateNotificationId('user-789', strategy);
        final afterTime = DateTime.now().millisecondsSinceEpoch;

        // Assert
        // Extract timestamp from ID (format: category_userId_timestamp_random)
        final parts = id.split('_');
        expect(parts.length, greaterThanOrEqualTo(4));

        final timestamp = int.tryParse(parts[2]);
        expect(timestamp, isNotNull);
        expect(timestamp!, greaterThanOrEqualTo(beforeTime));
        expect(timestamp, lessThanOrEqualTo(afterTime));
      });
    });

    group('Template Creation', () {
      test(
        'should create Swedish notification template with variable substitution',
        () {
          // Arrange
          final strategy = createTestStrategy();
          final variables = {
            'senderName': 'Anna',
            'recipeTitle': 'Köttbullar med gräddsås',
          };

          // Act
          final template = contentManager.createNotificationContent(
            strategy: strategy,
            variables: variables,
          );

          // Assert
          expect(template.title, equals('Test titel Anna'));
          expect(
            template.body,
            equals('Test meddelande Köttbullar med gräddsås'),
          );
          expect(template.data['category'], equals('social'));
          expect(template.data['type'], equals('immediate'));
        },
      );

      test('should create English notification template', () {
        // Arrange
        final strategy = createTestStrategy();
        final variables = {
          'senderName': 'John',
          'recipeTitle': 'Pasta Carbonara',
        };

        // Act
        final template = contentManager.createEnglishTemplate(
          strategy: strategy,
          variables: variables,
        );

        // Assert
        expect(template.title, equals('Test title John'));
        expect(template.body, equals('Test message Pasta Carbonara'));
        expect(template.data['language'], equals('en'));
      });

      test('should handle missing template variables gracefully', () {
        // Arrange
        final strategy = createTestStrategy();
        final variables = <String, String>{}; // Empty variables

        // Act
        final template = contentManager.createNotificationContent(
          strategy: strategy,
          variables: variables,
        );

        // Assert
        expect(
          template.title,
          equals('Test titel {senderName}'),
        ); // Variable not replaced
        expect(template.body, equals('Test meddelande {recipeTitle}'));
      });

      test('should create fallback template on localization error', () {
        // Arrange
        final strategy = createTestStrategy(
          localization: {}, // Empty localization
        );
        final variables = {'test': 'value'};

        // Act
        final template = contentManager.createNotificationContent(
          strategy: strategy,
          variables: variables,
        );

        // Assert
        expect(template.title, equals('Ny aktivitet'));
        expect(template.body, equals('Du har ny aktivitet i Butlery'));
        expect(template.data['fallback'], isNull); // Fallback only on error
      });

      test('should include additional data and actions in template', () {
        // Arrange
        final strategy = createTestStrategy();
        final variables = {'senderName': 'Test'};
        final additionalData = {
          'recipeId': 'recipe-123',
          'actionType': 'shared',
        };
        final actions = [
          const NotificationAction(
            id: 'view',
            title: 'View Recipe',
            data: {'action': 'navigate', 'destination': '/recipe/123'},
          ),
        ];

        // Act
        final template = contentManager.createNotificationContent(
          strategy: strategy,
          variables: variables,
          additionalData: additionalData,
          imageUrl: 'https://example.com/image.jpg',
          actions: actions,
        );

        // Assert
        expect(template.data['recipeId'], equals('recipe-123'));
        expect(template.data['actionType'], equals('shared'));
        expect(template.imageUrl, equals('https://example.com/image.jpg'));
        expect(template.actions, hasLength(1));
        expect(template.actions?.first.id, equals('view'));
      });
    });

    group('Batched Notifications', () {
      test('should return single notification when batch has one item', () {
        // Arrange
        final notifications = [
          createTestTemplate(title: 'Single'),
        ];

        // Act
        final result = contentManager.buildBatchedNotification(notifications);

        // Assert
        expect(result.title, equals('Single'));
        expect(result.data['batched'], isNull);
      });

      test('should build combined notification for multiple items', () {
        // Arrange
        final notifications = [
          createTestTemplate(data: {'category': 'recipes'}),
          createTestTemplate(data: {'category': 'recipes'}),
          createTestTemplate(data: {'category': 'recipes'}),
        ];

        // Act
        final result = contentManager.buildBatchedNotification(notifications);

        // Assert
        expect(result.title, equals('Ny receptaktivitet'));
        expect(result.body, equals('3 nya händelser på dina recept'));
        expect(result.data['batched'], isTrue);
        expect(result.data['count'], equals(3));
      });

      test('should generate appropriate content for each category', () {
        // Test different categories
        final categoryTests = [
          ('recipes', 'Ny receptaktivitet', '2 nya händelser på dina recept'),
          ('friends', 'Vänaktivitet', '2 nya aktiviteter från dina vänner'),
          ('shopping', 'Inköpslistor', '2 uppdateringar av dina inköpslistor'),
          ('collaboration', 'Samarbetsaktivitet', '2 nya samarbetsaktiviteter'),
          ('unknown', 'Ny aktivitet', '2 nya händelser i Butlery'),
        ];

        for (final (category, expectedTitle, expectedBody) in categoryTests) {
          // Arrange
          final notifications = [
            createTestTemplate(data: {'category': category}),
            createTestTemplate(data: {'category': category}),
          ];

          // Act
          final result = contentManager.buildBatchedNotification(notifications);

          // Assert
          expect(
            result.title,
            equals(expectedTitle),
            reason: 'Category: $category',
          );
          expect(
            result.body,
            equals(expectedBody),
            reason: 'Category: $category',
          );
        }
      });

      test('should generate batch actions based on category', () {
        // Arrange
        final recipesNotifications = [
          createTestTemplate(data: {'category': 'recipes'}),
          createTestTemplate(data: {'category': 'recipes'}),
        ];

        final friendsNotifications = [
          createTestTemplate(data: {'category': 'friends'}),
          createTestTemplate(data: {'category': 'friends'}),
        ];

        // Act
        final recipesResult = contentManager.buildBatchedNotification(
          recipesNotifications,
        );
        final friendsResult = contentManager.buildBatchedNotification(
          friendsNotifications,
        );

        // Assert
        expect(recipesResult.actions, hasLength(1));
        expect(recipesResult.actions?.first.id, equals('view_recipes'));
        expect(recipesResult.actions?.first.title, equals('Visa recept'));

        expect(friendsResult.actions, hasLength(1));
        expect(friendsResult.actions?.first.id, equals('view_friends'));
        expect(friendsResult.actions?.first.title, equals('Visa vänner'));
      });

      test('should handle empty notification list error', () {
        // Arrange
        final notifications = <NotificationTemplate>[];

        // Act & Assert
        expect(
          () => contentManager.buildBatchedNotification(notifications),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('Digest Content', () {
      test('should build digest content from activity list', () {
        // Arrange
        final activities = [
          {'category': 'recipes', 'title': 'Recipe 1'},
          {'category': 'recipes', 'title': 'Recipe 2'},
          {'category': 'friends', 'title': 'Friend activity'},
          {'category': 'shopping', 'title': 'Shopping update'},
        ];
        final strategy = createTestStrategy();

        // Act
        final digest = contentManager.buildDigestContent(activities, strategy);

        // Assert
        expect(digest['title'], equals('Daglig sammanfattning'));
        expect(digest['body'], contains('4 nya aktiviteter'));
        expect(digest['body'], contains('2 recept'));
        // Plural-aware in Swedish: 1 -> singular form.
        expect(digest['body'], contains('1 vänaktivitet'));
        expect(digest['body'], contains('1 inköpslistor'));
        expect(digest['count'], equals('4'));
      });

      test('should handle empty activity list', () {
        // Arrange
        final activities = <Map<String, String>>[];
        final strategy = createTestStrategy();

        // Act
        final digest = contentManager.buildDigestContent(activities, strategy);

        // Assert
        expect(digest['title'], equals('Daglig sammanfattning'));
        expect(digest['body'], equals('Ingen ny aktivitet idag'));
        expect(digest['count'], equals('0'));
        expect(digest['summary'], equals('Ingen aktivitet att rapportera'));
      });

      test('should handle digest content generation errors', () {
        // Arrange
        final activities = <Map<String, String>>[
          {'category': 'unknown'}, // Will trigger unknown category path
        ];
        final strategy = createTestStrategy();

        // Act
        final digest = contentManager.buildDigestContent(activities, strategy);

        // Assert
        expect(digest['title'], isNotEmpty);
        expect(digest['body'], isNotEmpty);
        expect(digest['count'], equals('1'));
      });
    });
  });
}
