import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/tagging/tag_override_log_entry.dart';

void main() {
  group('TagOverrideLogEntry.toFirestore', () {
    TagOverrideLogEntry make(List<String> ingredients) => TagOverrideLogEntry(
      id: 'e1',
      userId: 'u1',
      recipeId: 'r1',
      type: 'allergen',
      tag: 'gluten',
      direction: 'toFree',
      triggeringIngredients: ingredients,
      timestamp: DateTime.utc(2026, 10, 30),
    );

    test('stamps expireAt a year after the write', () {
      withClock(Clock.fixed(DateTime.utc(2026, 10, 30)), () {
        final json = make(['vetemjöl']).toFirestore();
        expect(
          (json['expireAt'] as Timestamp).toDate().toUtc(),
          DateTime.utc(2027, 10, 30),
        );
      });
    });

    test('scrubs a typed ingredient line that carries contact details', () {
      final json = make(['mjöl från anna@example.com', 'korn']).toFirestore();
      expect(
        json['triggeringIngredients'],
        isNot(contains('mjöl från anna@example.com')),
      );
      expect((json['triggeringIngredients'] as List).last, 'korn');
    });
  });
}
