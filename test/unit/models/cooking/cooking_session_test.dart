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

  // ---------------------------------------------------------------------------
  // BUT-408 follow-up: currentStep / totalSteps round-trip + validation.
  // ---------------------------------------------------------------------------

  group('CookingSession step fields', () {
    final startedAt = DateTime.fromMillisecondsSinceEpoch(1700000000000);

    test('both null round-trips cleanly and omits keys from the map', () {
      final original = CookingSession(
        recipeId: 'r1',
        recipeTitle: 'Pasta',
        startedAt: startedAt,
        userId: 'u1',
        userName: 'Erik',
      );

      final map = original.toMap();
      // Omit-when-null keeps old clients free of phantom keys.
      expect(map.containsKey('currentStep'), isFalse);
      expect(map.containsKey('totalSteps'), isFalse);

      final roundTripped = CookingSession.fromMap(map);
      expect(roundTripped.currentStep, isNull);
      expect(roundTripped.totalSteps, isNull);
      expect(roundTripped, equals(original));
    });

    test('both populated round-trip through map with no data loss', () {
      final original = CookingSession(
        recipeId: 'r1',
        recipeTitle: 'Gryta',
        startedAt: startedAt,
        userId: 'u1',
        userName: 'Erik',
        currentStep: 3,
        totalSteps: 7,
      );

      final map = original.toMap();
      expect(map['currentStep'], 3);
      expect(map['totalSteps'], 7);

      final roundTripped = CookingSession.fromMap(map);
      expect(roundTripped.currentStep, 3);
      expect(roundTripped.totalSteps, 7);
      expect(roundTripped, equals(original));
    });

    test('legacy doc missing step fields parses without crashing', () {
      // Simulates a pre-follow-up client that never wrote the two keys.
      final legacyMap = <dynamic, dynamic>{
        'recipeId': 'r1',
        'recipeTitle': 'Soppa',
        'startedAt': startedAt.millisecondsSinceEpoch,
        'userId': 'u1',
        'userName': 'Ben',
      };

      final parsed = CookingSession.fromMap(legacyMap);
      expect(parsed.currentStep, isNull);
      expect(parsed.totalSteps, isNull);
      expect(parsed.recipeTitle, 'Soppa');
    });

    test('malformed half-pair (currentStep only) is normalized to null', () {
      // Defensive: fromMap must not pass a half-set pair into the constructor
      // (would trigger the assertion in debug and render "steg 3 av null").
      final driftedMap = <dynamic, dynamic>{
        'recipeId': 'r1',
        'recipeTitle': 'Drift',
        'startedAt': startedAt.millisecondsSinceEpoch,
        'userId': 'u1',
        'userName': 'X',
        'currentStep': 3,
        // totalSteps intentionally missing — schema drift.
      };

      final parsed = CookingSession.fromMap(driftedMap);
      expect(parsed.currentStep, isNull);
      expect(parsed.totalSteps, isNull);
    });

    test('constructor rejects currentStep > totalSteps', () {
      expect(
        () => CookingSession(
          recipeId: 'r1',
          recipeTitle: 'A',
          startedAt: startedAt,
          userId: 'u1',
          userName: 'Erik',
          currentStep: 5,
          totalSteps: 3,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('constructor rejects currentStep < 1 (0-based slipup)', () {
      expect(
        () => CookingSession(
          recipeId: 'r1',
          recipeTitle: 'A',
          startedAt: startedAt,
          userId: 'u1',
          userName: 'Erik',
          currentStep: 0,
          totalSteps: 7,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('constructor rejects half-set pair (one null, one non-null)', () {
      expect(
        () => CookingSession(
          recipeId: 'r1',
          recipeTitle: 'A',
          startedAt: startedAt,
          userId: 'u1',
          userName: 'Erik',
          currentStep: 3,
          // totalSteps omitted = null
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
