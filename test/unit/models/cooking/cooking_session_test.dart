// test/unit/models/cooking/cooking_session_test.dart
//
// BUT-408: round-trip tests covering every nullable-field permutation so
// the RTDB serializer never silently drops data on re-parse.

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/cooking/cooking_session.dart';

void main() {
  group('CookingSession round-trip', () {
    final startedAt = DateTime.fromMillisecondsSinceEpoch(1700000000000);

    test('fully populated session round-trips byte-for-byte', () {
      final original = CookingSession(
        recipeId: 'recipe_42',
        recipeTitle: 'Kycklinggryta',
        recipeImageUrl: 'https://cdn.example.com/hero.jpg',
        startedAt: startedAt,
        userId: 'user_erik',
        userName: 'Erik',
        userAvatar: 'https://cdn.example.com/erik.jpg',
      );

      final roundTripped = CookingSession.fromMap(original.toMap());

      expect(roundTripped, equals(original));
      expect(roundTripped.recipeImageUrl, 'https://cdn.example.com/hero.jpg');
      expect(roundTripped.userAvatar, 'https://cdn.example.com/erik.jpg');
    });

    test('null recipeImageUrl preserved through round-trip', () {
      final original = CookingSession(
        recipeId: 'r1',
        recipeTitle: 'Pasta',
        startedAt: startedAt,
        userId: 'u1',
        userName: 'Anna',
        userAvatar: 'https://a/anna.jpg',
        // recipeImageUrl intentionally omitted
      );

      final roundTripped = CookingSession.fromMap(original.toMap());

      expect(roundTripped.recipeImageUrl, isNull);
      expect(roundTripped, equals(original));
    });

    test('null userAvatar preserved through round-trip', () {
      final original = CookingSession(
        recipeId: 'r2',
        recipeTitle: 'Sallad',
        recipeImageUrl: 'https://a/sallad.jpg',
        startedAt: startedAt,
        userId: 'u2',
        userName: 'Sara',
        // userAvatar intentionally omitted
      );

      final roundTripped = CookingSession.fromMap(original.toMap());

      expect(roundTripped.userAvatar, isNull);
      expect(roundTripped, equals(original));
    });

    test('both nullable fields null round-trips cleanly', () {
      final original = CookingSession(
        recipeId: 'r3',
        recipeTitle: 'Soppa',
        startedAt: startedAt,
        userId: 'u3',
        userName: 'Ben',
      );

      final roundTripped = CookingSession.fromMap(original.toMap());

      expect(roundTripped.recipeImageUrl, isNull);
      expect(roundTripped.userAvatar, isNull);
      expect(roundTripped, equals(original));
    });

    test('malformed map falls back to safe defaults without throwing', () {
      // Simulates a row with every optional field missing and a badly-typed
      // startedAt — the repository needs this to be non-throwing so a single
      // bad row doesn't crash the whole presence stream.
      final fromGarbage = CookingSession.fromMap(<dynamic, dynamic>{
        'recipeId': 'r4',
        'recipeTitle': 'Minimalt',
        // startedAt missing entirely
        'userId': 'u4',
        'userName': 'X',
      });

      expect(fromGarbage.recipeId, 'r4');
      expect(fromGarbage.recipeTitle, 'Minimalt');
      expect(fromGarbage.recipeImageUrl, isNull);
      expect(fromGarbage.userAvatar, isNull);
      // epoch=0 marks "unknown" without breaking the sort predicate
      expect(fromGarbage.startedAt.millisecondsSinceEpoch, 0);
    });
  });

  group('CookingSession.copyWith', () {
    test('overrides only the provided fields', () {
      final base = CookingSession(
        recipeId: 'r1',
        recipeTitle: 'A',
        startedAt: DateTime(2026),
        userId: 'u1',
        userName: 'Erik',
      );
      final copy = base.copyWith(userName: 'Erik Svensson');

      expect(copy.userName, 'Erik Svensson');
      expect(copy.recipeId, 'r1');
      expect(copy.recipeTitle, 'A');
    });
  });
}
