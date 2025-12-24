// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/realtime/live_editor.dart';
import 'helpers/model_test_base.dart';

void main() {
  ModelTestBase.testModelGroup('LiveEditor', () {
    group('Construction', () {
      test('should create with required parameters', () {
        final lastSeen = DateTime(2025, 1, 1, 12, 0);

        final editor = LiveEditor(
          userId: 'user_123',
          displayName: 'Anna Andersson',
          lastSeen: lastSeen,
        );

        expect(editor.userId, equals('user_123'));
        expect(editor.displayName, equals('Anna Andersson'));
        expect(editor.lastSeen, equals(lastSeen));
        expect(editor.currentField, isNull);
        expect(editor.isActive, isTrue); // Default value
      });

      test('should create with all parameters', () {
        final lastSeen = DateTime(2025, 1, 1, 12, 0);

        final editor = LiveEditor(
          userId: 'user_123',
          displayName: 'Anna Andersson',
          lastSeen: lastSeen,
          currentField: 'ingredients[2].name',
          isActive: false,
        );

        expect(editor.userId, equals('user_123'));
        expect(editor.displayName, equals('Anna Andersson'));
        expect(editor.lastSeen, equals(lastSeen));
        expect(editor.currentField, equals('ingredients[2].name'));
        expect(editor.isActive, isFalse);
      });
    });

    group('Factory Methods', () {
      test('should create from Firestore data', () {
        final lastSeenTime = DateTime(2025, 1, 1, 12, 0);
        final firestoreData = {
          'userId': 'user_123',
          'displayName': 'Erik Eriksson',
          'lastSeen': lastSeenTime.millisecondsSinceEpoch,
          'currentField': 'instructions[0].description',
          'isActive': true,
        };

        final editor = LiveEditor.fromFirestore(firestoreData);

        expect(editor.userId, equals('user_123'));
        expect(editor.displayName, equals('Erik Eriksson'));
        expect(editor.lastSeen, equals(lastSeenTime));
        expect(editor.currentField, equals('instructions[0].description'));
        expect(editor.isActive, isTrue);
      });

      test('should handle missing optional fields in Firestore', () {
        final lastSeenTime = DateTime(2025, 1, 1, 12, 0);
        final firestoreData = {
          'userId': 'user_123',
          'displayName': 'Anna',
          'lastSeen': lastSeenTime.millisecondsSinceEpoch,
          'currentField': null,
          // isActive missing
        };

        final editor = LiveEditor.fromFirestore(firestoreData);

        expect(editor.currentField, isNull);
        expect(editor.isActive, isTrue); // Defaults to true
      });
    });

    group('Serialization', () {
      test('should serialize to Firestore format', () {
        final lastSeen = DateTime(2025, 1, 1, 12, 0);
        final editor = LiveEditor(
          userId: 'user_123',
          displayName: 'Anna Andersson',
          lastSeen: lastSeen,
          currentField: 'servings',
          isActive: true,
        );

        final firestore = editor.toFirestore();

        expect(firestore['userId'], equals('user_123'));
        expect(firestore['displayName'], equals('Anna Andersson'));
        expect(firestore['lastSeen'], equals(lastSeen.millisecondsSinceEpoch));
        expect(firestore['currentField'], equals('servings'));
        expect(firestore['isActive'], isTrue);
      });

      test('should round-trip through Firestore', () {
        final original = LiveEditor(
          userId: 'user_456',
          displayName: 'Lars Larsson',
          lastSeen: DateTime(2025, 1, 2, 15, 30),
          currentField: 'title',
          isActive: false,
        );

        final firestore = original.toFirestore();
        final restored = LiveEditor.fromFirestore(firestore);

        expect(restored.userId, equals(original.userId));
        expect(restored.displayName, equals(original.displayName));
        expect(restored.lastSeen, equals(original.lastSeen));
        expect(restored.currentField, equals(original.currentField));
        expect(restored.isActive, equals(original.isActive));
      });
    });

    group('copyWith', () {
      late LiveEditor editor;

      setUp(() {
        editor = LiveEditor(
          userId: 'user_123',
          displayName: 'Anna',
          lastSeen: DateTime(2025, 1, 1),
          currentField: 'description',
          isActive: true,
        );
      });

      test('should copy with new values', () {
        final newLastSeen = DateTime(2025, 1, 2);
        final copied = editor.copyWith(
          displayName: 'Anna Andersson',
          lastSeen: newLastSeen,
          currentField: 'ingredients',
          isActive: false,
        );

        expect(copied.userId, equals('user_123')); // Unchanged
        expect(copied.displayName, equals('Anna Andersson'));
        expect(copied.lastSeen, equals(newLastSeen));
        expect(copied.currentField, equals('ingredients'));
        expect(copied.isActive, isFalse);
      });

      test('should preserve original values when not specified', () {
        final copied = editor.copyWith(currentField: 'newField');

        expect(copied.userId, equals(editor.userId));
        expect(copied.displayName, equals(editor.displayName));
        expect(copied.lastSeen, equals(editor.lastSeen));
        expect(copied.currentField, equals('newField'));
        expect(copied.isActive, equals(editor.isActive));
      });
    });

    group('Activity Tracking', () {
      test('should check if editor is recently active', () {
        // Active editor, seen 2 minutes ago
        var editor = LiveEditor(
          userId: 'user_123',
          displayName: 'Anna',
          lastSeen: DateTime.now().subtract(Duration(minutes: 2)),
          isActive: true,
        );
        expect(editor.isRecentlyActive(), isTrue);

        // Active editor, seen 6 minutes ago (outside default 5 min timeout)
        editor = LiveEditor(
          userId: 'user_123',
          displayName: 'Anna',
          lastSeen: DateTime.now().subtract(Duration(minutes: 6)),
          isActive: true,
        );
        expect(editor.isRecentlyActive(), isFalse);

        // Inactive editor, seen recently
        editor = LiveEditor(
          userId: 'user_123',
          displayName: 'Anna',
          lastSeen: DateTime.now().subtract(Duration(minutes: 1)),
          isActive: false,
        );
        expect(editor.isRecentlyActive(), isFalse);

        // Custom timeout
        editor = LiveEditor(
          userId: 'user_123',
          displayName: 'Anna',
          lastSeen: DateTime.now().subtract(Duration(minutes: 8)),
          isActive: true,
        );
        expect(editor.isRecentlyActive(timeoutMinutes: 10), isTrue);
      });

      test('should calculate time since last seen', () {
        final lastSeen =
            DateTime.now().subtract(Duration(hours: 2, minutes: 30));
        final editor = LiveEditor(
          userId: 'user_123',
          displayName: 'Anna',
          lastSeen: lastSeen,
        );

        final timeSince = editor.timeSinceLastSeen;

        // Should be approximately 2.5 hours
        expect(timeSince.inMinutes, greaterThanOrEqualTo(149));
        expect(timeSince.inMinutes, lessThanOrEqualTo(151));
      });

      test('should mark editor as inactive', () {
        final editor = LiveEditor(
          userId: 'user_123',
          displayName: 'Anna',
          lastSeen: DateTime.now(),
          currentField: 'title',
          isActive: true,
        );

        final inactive = editor.markInactive();

        expect(inactive.isActive, isFalse);
        // Other fields should remain unchanged
        expect(inactive.userId, equals(editor.userId));
        expect(inactive.displayName, equals(editor.displayName));
        expect(inactive.lastSeen, equals(editor.lastSeen));
        expect(inactive.currentField, equals(editor.currentField));
      });

      test('should update activity timestamp', () {
        final oldLastSeen = DateTime.now().subtract(Duration(hours: 1));
        final editor = LiveEditor(
          userId: 'user_123',
          displayName: 'Anna',
          lastSeen: oldLastSeen,
        );

        final before = DateTime.now();
        final updated = editor.updateActivity();
        final after = DateTime.now();

        expect(updated.lastSeen.isAfter(oldLastSeen), isTrue);
        expect(
            updated.lastSeen.isAfter(before) ||
                updated.lastSeen.isAtSameMomentAs(before),
            isTrue);
        expect(
            updated.lastSeen.isBefore(after) ||
                updated.lastSeen.isAtSameMomentAs(after),
            isTrue);
      });
    });

    group('Field Editing', () {
      test('should check if editor is editing specific field', () {
        final editor = LiveEditor(
          userId: 'user_123',
          displayName: 'Anna',
          lastSeen: DateTime.now(),
          currentField: 'ingredients[2].name',
          isActive: true,
        );

        expect(editor.isEditingField('ingredients[2].name'), isTrue);
        expect(editor.isEditingField('ingredients[2].quantity'), isFalse);
        expect(editor.isEditingField('title'), isFalse);
      });

      test('should return false for inactive editor even with matching field',
          () {
        final editor = LiveEditor(
          userId: 'user_123',
          displayName: 'Anna',
          lastSeen: DateTime.now(),
          currentField: 'description',
          isActive: false,
        );

        expect(editor.isEditingField('description'), isFalse);
      });

      test('should handle null current field', () {
        final editor = LiveEditor(
          userId: 'user_123',
          displayName: 'Anna',
          lastSeen: DateTime.now(),
          currentField: null,
          isActive: true,
        );

        expect(editor.isEditingField('anyField'), isFalse);
      });

      test('should track complex field paths', () {
        final editor = LiveEditor(
          userId: 'user_123',
          displayName: 'Anna',
          lastSeen: DateTime.now(),
          currentField: 'instructions[0].steps[2].description',
          isActive: true,
        );

        expect(editor.isEditingField('instructions[0].steps[2].description'),
            isTrue);
      });
    });

    group('Equality and HashCode', () {
      test('should be equal when user IDs match', () {
        final editor1 = LiveEditor(
          userId: 'user_123',
          displayName: 'Anna',
          lastSeen: DateTime(2025, 1, 1),
          currentField: 'field1',
          isActive: true,
        );

        final editor2 = LiveEditor(
          userId: 'user_123',
          displayName: 'Different Name',
          lastSeen: DateTime(2025, 2, 1),
          currentField: 'field2',
          isActive: false,
        );

        expect(editor1, equals(editor2));
        expect(editor1.hashCode, equals(editor2.hashCode));
      });

      test('should not be equal when user IDs differ', () {
        final editor1 = LiveEditor(
          userId: 'user_123',
          displayName: 'Anna',
          lastSeen: DateTime.now(),
        );

        final editor2 = LiveEditor(
          userId: 'user_456',
          displayName: 'Anna',
          lastSeen: DateTime.now(),
        );

        expect(editor1, isNot(equals(editor2)));
        expect(editor1.hashCode, isNot(equals(editor2.hashCode)));
      });
    });

    group('toString', () {
      test('should provide readable string representation', () {
        final editor = LiveEditor(
          userId: 'user_123',
          displayName: 'Anna Andersson',
          lastSeen: DateTime.now(),
          currentField: 'title',
          isActive: true,
        );

        final str = editor.toString();

        expect(str, contains('LiveEditor'));
        expect(str, contains('user_123'));
        expect(str, contains('Anna Andersson'));
        expect(str, contains('true')); // isActive
        expect(str, contains('title')); // currentField
      });

      test('should handle null current field in toString', () {
        final editor = LiveEditor(
          userId: 'user_123',
          displayName: 'Anna',
          lastSeen: DateTime.now(),
          currentField: null,
        );

        final str = editor.toString();

        expect(str, contains('null'));
      });
    });

    group('Edge Cases', () {
      test('should handle very old lastSeen timestamps', () {
        final editor = LiveEditor(
          userId: 'user_123',
          displayName: 'Anna',
          lastSeen: DateTime(1970, 1, 1),
          isActive: true,
        );

        expect(editor.isRecentlyActive(), isFalse);
        expect(editor.timeSinceLastSeen.inDays, greaterThan(10000));
      });

      test('should handle future lastSeen timestamps', () {
        final editor = LiveEditor(
          userId: 'user_123',
          displayName: 'Anna',
          lastSeen: DateTime.now().add(Duration(hours: 1)),
          isActive: true,
        );

        // Should still work, though this is an unusual case
        expect(editor.isRecentlyActive(), isTrue);
        expect(editor.timeSinceLastSeen.isNegative, isTrue);
      });

      test('should handle empty field paths', () {
        final editor = LiveEditor(
          userId: 'user_123',
          displayName: 'Anna',
          lastSeen: DateTime.now(),
          currentField: '',
          isActive: true,
        );

        expect(editor.isEditingField(''), isTrue);
        expect(editor.isEditingField('anyField'), isFalse);
      });

      test('should handle Swedish characters in display name', () {
        final editor = LiveEditor(
          userId: 'user_123',
          displayName: 'Åsa Öström',
          lastSeen: DateTime.now(),
        );

        expect(editor.displayName, equals('Åsa Öström'));

        final firestore = editor.toFirestore();
        expect(firestore['displayName'], equals('Åsa Öström'));

        final restored = LiveEditor.fromFirestore(firestore);
        expect(restored.displayName, equals('Åsa Öström'));
      });
    });
  });
}
