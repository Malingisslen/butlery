/// Tests for ContentType enum + wire serialization.
///
/// The wireName values are persisted in `reports/*` documents in
/// production, so any change here is a Firestore migration. The tests
/// pin every wire string and verify round-trip + unknown-tolerance.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/social/content_type.dart';

void main() {
  group('ContentType', () {
    test('every value has a unique wireName', () {
      final wireNames = ContentType.values.map((t) => t.wireName).toList();
      expect(wireNames.toSet().length, equals(wireNames.length));
    });

    test('wireName matches the persisted Firestore string', () {
      // Pin each value so a rename surfaces as a test failure (which forces
      // a Firestore migration discussion).
      expect(ContentType.recipe.wireName, equals('recipe'));
      expect(ContentType.comment.wireName, equals('comment'));
      expect(ContentType.message.wireName, equals('message'));
      expect(ContentType.profile.wireName, equals('profile'));
      expect(ContentType.cookSnap.wireName, equals('cook_snap'));
      expect(ContentType.group.wireName, equals('group'));
    });

    test('fromWire round-trips every value', () {
      for (final type in ContentType.values) {
        expect(ContentType.fromWire(type.wireName), equals(type));
      }
    });

    test('fromWire returns null for retired types', () {
      // Phase 3 removed these; legacy reports may still carry them.
      expect(ContentType.fromWire('rating'), isNull);
      expect(ContentType.fromWire('shopping_list'), isNull);
    });

    test('fromWire returns null for unknown / null / empty', () {
      expect(ContentType.fromWire(null), isNull);
      expect(ContentType.fromWire(''), isNull);
      expect(ContentType.fromWire('unknown_future_type'), isNull);
      expect(ContentType.fromWire('PROFILE'), isNull,
          reason: 'wireNames are case-sensitive');
    });
  });
}
