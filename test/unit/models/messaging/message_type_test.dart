// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/messaging/message_type.dart';
import '../helpers/model_test_base.dart';

void main() {
  ModelTestBase.testModelGroup('MessageType', () {
    group('MessageType Enum', () {
      test('should have all expected message types', () {
        expect(MessageType.values.length, equals(7));
        expect(MessageType.values, contains(MessageType.text));
        expect(MessageType.values, contains(MessageType.recipeShare));
        expect(MessageType.values, contains(MessageType.menuShare));
        expect(MessageType.values, contains(MessageType.shoppingListShare));
        expect(MessageType.values, contains(MessageType.system));
        expect(MessageType.values, contains(MessageType.image));
        expect(MessageType.values, contains(MessageType.voice));
      });

      test('should have correct Swedish display names', () {
        expect(MessageType.text.displayName, equals('Textmeddelande'));
        expect(MessageType.recipeShare.displayName, equals('Receptdelning'));
        expect(MessageType.menuShare.displayName, equals('Menydelning'));
        expect(MessageType.shoppingListShare.displayName, equals('Inköpslistedelning'));
        expect(MessageType.system.displayName, equals('Systemmeddelande'));
        expect(MessageType.image.displayName, equals('Bild'));
        expect(MessageType.voice.displayName, equals('Röstmeddelande'));
      });

      test('should have appropriate emoji icons', () {
        expect(MessageType.text.icon, equals('💬'));
        expect(MessageType.recipeShare.icon, equals('🍽️'));
        expect(MessageType.menuShare.icon, equals('📋'));
        expect(MessageType.shoppingListShare.icon, equals('🛒'));
        expect(MessageType.system.icon, equals('ℹ️'));
        expect(MessageType.image.icon, equals('📷'));
        expect(MessageType.voice.icon, equals('🎤'));
      });

      test('should handle all cases in displayName extension', () {
        for (final type in MessageType.values) {
          expect(type.displayName, isNotEmpty);
          expect(type.displayName, isA<String>());
        }
      });

      test('should handle all cases in icon extension', () {
        for (final type in MessageType.values) {
          expect(type.icon, isNotEmpty);
          expect(type.icon, isA<String>());
        }
      });
    });

    group('MessageStatus Enum', () {
      test('should have all expected status values', () {
        expect(MessageStatus.values.length, equals(5));
        expect(MessageStatus.values, contains(MessageStatus.sending));
        expect(MessageStatus.values, contains(MessageStatus.sent));
        expect(MessageStatus.values, contains(MessageStatus.delivered));
        expect(MessageStatus.values, contains(MessageStatus.read));
        expect(MessageStatus.values, contains(MessageStatus.failed));
      });

      test('should have correct Swedish status names', () {
        expect(MessageStatus.sending.displayName, equals('Skickar...'));
        expect(MessageStatus.sent.displayName, equals('Skickat'));
        expect(MessageStatus.delivered.displayName, equals('Levererat'));
        expect(MessageStatus.read.displayName, equals('Läst'));
        expect(MessageStatus.failed.displayName, equals('Misslyckades'));
      });

      test('should have appropriate status icons', () {
        expect(MessageStatus.sending.icon, equals('⏳'));
        expect(MessageStatus.sent.icon, equals('✓'));
        expect(MessageStatus.delivered.icon, equals('✓✓'));
        expect(MessageStatus.read.icon, equals('👁️'));
        expect(MessageStatus.failed.icon, equals('❌'));
      });

      test('should handle all cases in displayName extension', () {
        for (final status in MessageStatus.values) {
          expect(status.displayName, isNotEmpty);
          expect(status.displayName, isA<String>());
        }
      });

      test('should handle all cases in icon extension', () {
        for (final status in MessageStatus.values) {
          expect(status.icon, isNotEmpty);
          expect(status.icon, isA<String>());
        }
      });

      test('should represent delivery progression correctly', () {
        // Verify the logical progression of statuses
        final progressionOrder = [
          MessageStatus.sending,
          MessageStatus.sent,
          MessageStatus.delivered,
          MessageStatus.read,
        ];

        for (int i = 0; i < progressionOrder.length - 1; i++) {
          expect(progressionOrder[i].index, lessThan(progressionOrder[i + 1].index));
        }

        // Failed is separate from the progression
        expect(MessageStatus.failed.index, equals(4));
      });
    });

    group('UI Integration Tests', () {
      test('should provide consistent localization for all message types', () {
        // All display names should be in Swedish
        for (final type in MessageType.values) {
          final displayName = type.displayName;
          // Check for common Swedish patterns
          expect(displayName, isNot(contains('Share'))); // Should not contain English
          expect(displayName, isNot(contains('Message'))); // Should not contain English
        }
      });

      test('should provide consistent localization for all status types', () {
        // All status names should be in Swedish
        for (final status in MessageStatus.values) {
          final displayName = status.displayName;
          // Check for Swedish patterns
          expect(displayName, isNot(contains('Send'))); // Should not contain English
          expect(displayName, isNot(contains('Read'))); // Should not contain English
          expect(displayName, isNot(contains('Delivered'))); // Should not contain English
        }
      });

      test('should have unique icons for each message type', () {
        final icons = MessageType.values.map((type) => type.icon).toList();
        final uniqueIcons = icons.toSet();
        expect(uniqueIcons.length, equals(icons.length));
      });

      test('should have unique icons for each status', () {
        final icons = MessageStatus.values.map((status) => status.icon).toList();
        final uniqueIcons = icons.toSet();
        expect(uniqueIcons.length, equals(icons.length));
      });

      test('should have emoji icons for all types', () {
        for (final type in MessageType.values) {
          // All icons should be emoji characters
          expect(type.icon.runes.length, greaterThanOrEqualTo(1));
        }
      });

      test('should have visual indicators for all statuses', () {
        for (final status in MessageStatus.values) {
          // All icons should be visual indicators
          expect(status.icon.runes.length, greaterThanOrEqualTo(1));
        }
      });
    });

    group('Use Cases', () {
      test('should support content classification use case', () {
        // Simulate classifying different content types
        final textMessage = MessageType.text;
        expect(textMessage.displayName, equals('Textmeddelande'));
        expect(textMessage.icon, equals('💬'));

        final recipeMessage = MessageType.recipeShare;
        expect(recipeMessage.displayName, equals('Receptdelning'));
        expect(recipeMessage.icon, equals('🍽️'));
      });

      test('should support delivery tracking use case', () {
        // Simulate tracking message delivery
        var status = MessageStatus.sending;
        expect(status.displayName, equals('Skickar...'));
        expect(status.icon, equals('⏳'));

        status = MessageStatus.sent;
        expect(status.displayName, equals('Skickat'));
        expect(status.icon, equals('✓'));

        status = MessageStatus.delivered;
        expect(status.displayName, equals('Levererat'));
        expect(status.icon, equals('✓✓'));

        status = MessageStatus.read;
        expect(status.displayName, equals('Läst'));
        expect(status.icon, equals('👁️'));
      });

      test('should support error handling use case', () {
        final failedStatus = MessageStatus.failed;
        expect(failedStatus.displayName, equals('Misslyckades'));
        expect(failedStatus.icon, equals('❌'));
        
        // Should be distinguishable from success states
        expect(failedStatus.icon, isNot(equals(MessageStatus.sent.icon)));
        expect(failedStatus.icon, isNot(equals(MessageStatus.delivered.icon)));
      });

      test('should support content sharing types', () {
        // All sharing types should be present
        final sharingTypes = [
          MessageType.recipeShare,
          MessageType.menuShare,
          MessageType.shoppingListShare,
        ];

        for (final type in sharingTypes) {
          expect(type.displayName, contains('delning'));
          expect(type.icon, isNotEmpty);
        }
      });
    });
  });
}