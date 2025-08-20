/// Unit tests for NotificationTemplates - Localized template system
/// 
/// Tests notification template functionality including:
/// - Template retrieval for all categories
/// - Swedish and English localization
/// - Variable substitution
/// - Template formatting
/// - Category coverage
/// - Special character handling
library;

import 'package:flutter_test/flutter_test.dart';

// Production imports
import 'package:butlery/services/notifications/notification_templates.dart';

// Test infrastructure
import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';

void main() {
  group('NotificationTemplates', () {
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
    
    group('Template Retrieval', () {
      test('should get template title for friend request sent', () {
        // Act
        final title = NotificationTemplates.getTemplate('friend_request_sent', 'title');
        final titleEn = NotificationTemplates.getTemplate('friend_request_sent', 'title', language: 'en');
        
        // Assert
        expect(title, equals('Vänskapsförfrågan skickad'));
        expect(titleEn, equals('Friend request sent'));
      });
      
      test('should get template body for friend request sent', () {
        // Act
        final body = NotificationTemplates.getTemplate('friend_request_sent', 'body');
        final bodyEn = NotificationTemplates.getTemplate('friend_request_sent', 'body', language: 'en');
        
        // Assert
        expect(body, contains('{recipientName}'));
        expect(bodyEn, contains('{recipientName}'));
      });
      
      test('should get template for recipe shared', () {
        // Act
        final title = NotificationTemplates.getTemplate('recipe_shared_direct', 'title');
        final body = NotificationTemplates.getTemplate('recipe_shared_direct', 'body');
        
        // Assert
        expect(title, equals('Recept delat med dig'));
        expect(body, contains('{senderName}'));
        expect(body, contains('{recipeName}'));
      });
      
      test('should get template for cooking timer', () {
        // Act
        final title = NotificationTemplates.getTemplate('cooking_timer_complete', 'title');
        final body = NotificationTemplates.getTemplate('cooking_timer_complete', 'body');
        
        // Assert
        expect(title, equals('Timer klar!'));
        expect(body, contains('{recipeName}'));
        expect(body, contains('{timerName}'));
      });
      
      test('should get template for collaboration invite', () {
        // Act
        final title = NotificationTemplates.getTemplate('collaboration_invite', 'title');
        final body = NotificationTemplates.getTemplate('collaboration_invite', 'body');
        
        // Assert
        expect(title, equals('Inbjudan till samarbete'));
        expect(body, contains('{inviterName}'));
        expect(body, contains('{recipeName}'));
      });
      
      test('should throw error for non-existent template', () {
        // Act & Assert
        expect(
          () => NotificationTemplates.getTemplate('non_existent_template', 'title'),
          throwsArgumentError,
        );
      });
      
      test('should check if template exists', () {
        // Act & Assert
        expect(NotificationTemplates.hasTemplate('friend_request_sent'), isTrue);
        expect(NotificationTemplates.hasTemplate('recipe_shared_direct'), isTrue);
        expect(NotificationTemplates.hasTemplate('non_existent'), isFalse);
      });
    });
    
    group('Variable Substitution', () {
      test('should substitute single variable', () {
        // Arrange
        const template = 'Hej {name}!';
        final variables = {'name': 'Anna'};
        
        // Act
        final formatted = NotificationTemplates.substituteVariables(template, variables);
        
        // Assert
        expect(formatted, equals('Hej Anna!'));
      });
      
      test('should substitute multiple variables', () {
        // Arrange
        const template = '{senderName} delade "{recipeName}" med dig';
        final variables = {
          'senderName': 'Erik',
          'recipeName': 'Köttbullar med gräddsås',
        };
        
        // Act
        final formatted = NotificationTemplates.substituteVariables(template, variables);
        
        // Assert
        expect(formatted, equals('Erik delade "Köttbullar med gräddsås" med dig'));
      });
      
      test('should handle missing variables gracefully', () {
        // Arrange
        const template = 'Hej {name}, din {item} är klar!';
        final variables = {'name': 'Johan'};
        
        // Act
        final formatted = NotificationTemplates.substituteVariables(template, variables);
        
        // Assert
        expect(formatted, equals('Hej Johan, din {item} är klar!'));
      });
      
      test('should handle empty variables map', () {
        // Arrange
        const template = 'Hej {name}!';
        final variables = <String, String>{};
        
        // Act
        final formatted = NotificationTemplates.substituteVariables(template, variables);
        
        // Assert
        expect(formatted, equals('Hej {name}!'));
      });
      
      test('should handle Swedish special characters', () {
        // Arrange
        const template = '{name} lagar {dish}';
        final variables = {
          'name': 'Åsa',
          'dish': 'Räksmörgås',
        };
        
        // Act
        final formatted = NotificationTemplates.substituteVariables(template, variables);
        
        // Assert
        expect(formatted, equals('Åsa lagar Räksmörgås'));
      });
      
      test('should handle emojis in templates', () {
        // Arrange
        const template = '{emoji} {message} {emoji}';
        final variables = {
          'emoji': '🍝',
          'message': 'Maten är klar',
        };
        
        // Act
        final formatted = NotificationTemplates.substituteVariables(template, variables);
        
        // Assert
        expect(formatted, equals('🍝 Maten är klar 🍝'));
      });
    });
    
    group('Category Coverage', () {
      test('should have templates for all friend notifications', () {
        // Arrange
        final friendTemplates = [
          'friend_request_sent',
          'friend_request_received',
          'friend_request_accepted',
          'friend_request_declined',
          'friend_online',
          'friend_joined_butlery',
        ];
        
        // Act & Assert
        for (final templateKey in friendTemplates) {
          expect(NotificationTemplates.hasTemplate(templateKey), isTrue,
              reason: 'Missing template: $templateKey');
        }
      });
      
      test('should have templates for all recipe notifications', () {
        // Arrange
        final recipeTemplates = [
          'recipe_shared_direct',
          'recipe_shared_group',
          'recipe_liked',
          'recipe_commented',
          'recipe_rated',
          'recipe_saved',
          'recipe_copied',
        ];
        
        // Act & Assert
        for (final templateKey in recipeTemplates) {
          expect(NotificationTemplates.hasTemplate(templateKey), isTrue,
              reason: 'Missing template: $templateKey');
        }
      });
      
      test('should have templates for all collaboration notifications', () {
        // Arrange
        final collaborationTemplates = [
          'collaboration_invite',
          'collaboration_joined',
          'collaboration_left',
          'collaboration_editing',
          'collaboration_commented',
          'collaboration_completed',
        ];
        
        // Act & Assert
        for (final templateKey in collaborationTemplates) {
          expect(NotificationTemplates.hasTemplate(templateKey), isTrue,
              reason: 'Missing template: $templateKey');
        }
      });
      
      test('should have templates for all shopping notifications', () {
        // Arrange
        final shoppingTemplates = [
          'shopping_list_shared',
          'shopping_item_added',
          'shopping_item_checked',
          'shopping_list_completed',
        ];
        
        // Act & Assert
        for (final templateKey in shoppingTemplates) {
          expect(NotificationTemplates.hasTemplate(templateKey), isTrue,
              reason: 'Missing template: $templateKey');
        }
      });
      
      test('should have templates for all system notifications', () {
        // Arrange
        final systemTemplates = [
          'app_update_available',
          'feature_announcement',
          'maintenance_scheduled',
          'account_security',
        ];
        
        // Act & Assert
        for (final templateKey in systemTemplates) {
          expect(NotificationTemplates.hasTemplate(templateKey), isTrue,
              reason: 'Missing template: $templateKey');
        }
      });
    });
    
    group('Full Notification Content', () {
      test('should get complete notification content with variables', () {
        // Arrange
        final variables = {'recipientName': 'Anna Andersson'};
        
        // Act
        final content = NotificationTemplates.getNotificationContent(
          templateKey: 'friend_request_sent',
          variables: variables,
          language: 'sv',
        );
        
        // Assert
        expect(content['title'], equals('Vänskapsförfrågan skickad'));
        expect(content['body'], equals('Du skickade en vänskapsförfrågan till Anna Andersson'));
      });
      
      test('should get English notification content', () {
        // Arrange
        final variables = {'recipientName': 'John Doe'};
        
        // Act
        final content = NotificationTemplates.getNotificationContent(
          templateKey: 'friend_request_sent',
          variables: variables,
          language: 'en',
        );
        
        // Assert
        expect(content['title'], equals('Friend request sent'));
        expect(content['body'], equals('You sent a friend request to John Doe'));
      });
      
      test('should format recipe share notification', () {
        // Arrange
        final variables = {
          'senderName': 'Erik',
          'recipeName': 'Pannkakor',
        };
        
        // Act
        final content = NotificationTemplates.getNotificationContent(
          templateKey: 'recipe_shared_direct',
          variables: variables,
        );
        
        // Assert
        expect(content['title'], equals('Recept delat med dig'));
        expect(content['body'], equals('Erik delade "Pannkakor" med dig'));
      });
      
      test('should format cooking timer notification', () {
        // Arrange
        final variables = {
          'recipeName': 'Lasagne',
          'timerName': 'Ugn',
          'duration': '45 minuter',
        };
        
        // Act
        final content = NotificationTemplates.getNotificationContent(
          templateKey: 'cooking_timer_complete',
          variables: variables,
        );
        
        // Assert
        expect(content['title'], equals('Timer klar!'));
        expect(content['body'], contains('Lasagne'));
        expect(content['body'], contains('Ugn'));
      });
    });
    
    group('Action Texts', () {
      test('should get Swedish action texts by default', () {
        // Act
        final actions = NotificationTemplates.getActionTexts();
        
        // Assert
        expect(actions['accept'], equals('Acceptera'));
        expect(actions['decline'], equals('Avvisa'));
        expect(actions['view'], equals('Visa'));
        expect(actions['join'], equals('Gå med'));
      });
      
      test('should get English action texts', () {
        // Act
        final actions = NotificationTemplates.getActionTexts(language: 'en');
        
        // Assert
        expect(actions['accept'], equals('Accept'));
        expect(actions['decline'], equals('Decline'));
        expect(actions['view'], equals('View'));
        expect(actions['join'], equals('Join'));
      });
    });
    
    group('Template Categories', () {
      test('should get all template keys', () {
        // Act
        final keys = NotificationTemplates.getAllTemplateKeys();
        
        // Assert
        expect(keys, isNotEmpty);
        expect(keys, contains('friend_request_sent'));
        expect(keys, contains('recipe_shared_direct'));
        expect(keys, contains('collaboration_invite'));
      });
      
      test('should get templates for specific category', () {
        // Act
        final friendTemplates = NotificationTemplates.getTemplatesForCategory('friend');
        final recipeTemplates = NotificationTemplates.getTemplatesForCategory('recipe');
        
        // Assert
        expect(friendTemplates, isNotEmpty);
        expect(friendTemplates.every((key) => key.startsWith('friend')), isTrue);
        
        expect(recipeTemplates, isNotEmpty);
        expect(recipeTemplates.every((key) => key.startsWith('recipe')), isTrue);
      });
    });
    
    group('Formatting Helpers', () {
      test('should format count for Swedish pluralization', () {
        // Act
        final single = NotificationTemplates.formatCount(1, 'kommentar', 'kommentarer');
        final multiple = NotificationTemplates.formatCount(5, 'kommentar', 'kommentarer');
        
        // Assert
        expect(single, equals('1 kommentar'));
        expect(multiple, equals('5 kommentarer'));
      });
      
      test('should format time in Swedish', () {
        // Arrange
        final now = DateTime.now();
        final justNow = now.subtract(const Duration(seconds: 30));
        final minutesAgo = now.subtract(const Duration(minutes: 15));
        final hoursAgo = now.subtract(const Duration(hours: 3));
        final daysAgo = now.subtract(const Duration(days: 2));
        
        // Act
        final justNowText = NotificationTemplates.formatTime(justNow);
        final minutesText = NotificationTemplates.formatTime(minutesAgo);
        final hoursText = NotificationTemplates.formatTime(hoursAgo);
        final daysText = NotificationTemplates.formatTime(daysAgo);
        
        // Assert
        expect(justNowText, equals('just nu'));
        expect(minutesText, contains('min sedan'));
        expect(hoursText, contains('tim sedan'));
        expect(daysText, contains('dagar sedan'));
      });
    });
    
    group('Batched Content', () {
      test('should create batched content for multiple comments', () {
        // Arrange
        final variables = {'recipeName': 'Köttbullar'};
        
        // Act
        final content = NotificationTemplates.createBatchedContent(
          baseTemplateKey: 'recipe_commented',
          count: 3,
          variables: variables,
        );
        
        // Assert
        expect(content['body'], contains('3'));
      });
      
      test('should use single template for count of 1', () {
        // Arrange
        final variables = {
          'commenterName': 'Erik',
          'recipeName': 'Pannkakor',
        };
        
        // Act
        final content = NotificationTemplates.createBatchedContent(
          baseTemplateKey: 'recipe_commented',
          count: 1,
          variables: variables,
        );
        
        // Assert
        expect(content['body'], contains('Erik'));
      });
    });
    
    group('Edge Cases', () {
      test('should handle very long variable values', () {
        // Arrange
        const template = 'Nytt recept: {recipeName}';
        final longName = 'A' * 200;
        final variables = {'recipeName': longName};
        
        // Act
        final formatted = NotificationTemplates.substituteVariables(template, variables);
        
        // Assert
        expect(formatted, equals('Nytt recept: $longName'));
      });
      
      test('should handle special regex characters in variables', () {
        // Arrange
        const template = 'User {name} sent message';
        final variables = {'name': r'test$user.name[0]'};
        
        // Act
        final formatted = NotificationTemplates.substituteVariables(template, variables);
        
        // Assert
        expect(formatted, equals(r'User test$user.name[0] sent message'));
      });
      
      test('should handle nested braces in template', () {
        // Arrange
        const template = 'Hello {{name}}';
        final variables = {'name': 'Test'};
        
        // Act
        final formatted = NotificationTemplates.substituteVariables(template, variables);
        
        // Assert
        expect(formatted, equals('Hello {Test}'));
      });
      
      test('should handle empty template string', () {
        // Arrange
        const template = '';
        final variables = {'name': 'Test'};
        
        // Act
        final formatted = NotificationTemplates.substituteVariables(template, variables);
        
        // Assert
        expect(formatted, isEmpty);
      });
    });
  });
}