import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/messaging/poll.dart';

void main() {
  group('PollOption serialization round-trip', () {
    test('preserves nullable recipe fields when null (backward compat)', () {
      final option = PollOption.create(text: 'Tacos');
      final map = option.toMap();

      // Backward compat: null fields must not leak into the map.
      expect(map.containsKey('recipeId'), isFalse);
      expect(map.containsKey('recipeImageUrl'), isFalse);
      expect(map.containsKey('recipePortions'), isFalse);

      final roundTripped = PollOption.fromMap(map);
      expect(roundTripped.text, equals('Tacos'));
      expect(roundTripped.recipeId, isNull);
      expect(roundTripped.recipeImageUrl, isNull);
      expect(roundTripped.recipePortions, isNull);
      expect(roundTripped.hasRecipe, isFalse);
    });

    test('preserves nullable recipe fields when present', () {
      final option = PollOption.create(
        text: 'Kycklinggryta med ris',
        recipeId: 'recipe-abc',
        recipeImageUrl: 'https://example.com/img.jpg',
        recipePortions: 4,
      );
      final map = option.toMap();

      expect(map['recipeId'], equals('recipe-abc'));
      expect(map['recipeImageUrl'], equals('https://example.com/img.jpg'));
      expect(map['recipePortions'], equals(4));

      final roundTripped = PollOption.fromMap(map);
      expect(roundTripped.recipeId, equals('recipe-abc'));
      expect(
        roundTripped.recipeImageUrl,
        equals('https://example.com/img.jpg'),
      );
      expect(roundTripped.recipePortions, equals(4));
      expect(roundTripped.hasRecipe, isTrue);
    });

    test('deserializes legacy map without recipe fields', () {
      // Simulates an old Firestore doc predating BUT-340.
      final legacyMap = <String, dynamic>{
        'id': 'opt-legacy',
        'text': 'Pasta',
        'voterIds': ['user-1', 'user-2'],
      };
      final option = PollOption.fromMap(legacyMap);
      expect(option.recipeId, isNull);
      expect(option.recipeImageUrl, isNull);
      expect(option.recipePortions, isNull);
      expect(option.voterIds, hasLength(2));
    });

    test('copyWith preserves recipe metadata', () {
      final option = PollOption.create(
        text: 'Tacos',
        recipeId: 'recipe-1',
        recipePortions: 6,
      );
      final copy = option.copyWith(voterIds: ['user-a']);
      expect(copy.recipeId, equals('recipe-1'));
      expect(copy.recipePortions, equals(6));
      expect(copy.voterIds, equals(['user-a']));
    });
  });

  group('Poll serialization with recipe options', () {
    test(
      'Poll.fromOptions preserves recipe metadata through full round-trip',
      () {
        final options = [
          PollOption.create(
            text: 'Tacos',
            recipeId: 'r-1',
            recipeImageUrl: 'https://example.com/tacos.jpg',
            recipePortions: 4,
          ),
          PollOption.create(
            text: 'Pasta bolognese',
            recipeId: 'r-2',
            recipePortions: 2,
          ),
        ];
        final poll = Poll.fromOptions(
          question: 'Vad ska vi äta?',
          options: options,
          creatorId: 'creator-1',
        );

        final roundTripped = Poll.fromMap(poll.toMap());
        expect(roundTripped.options, hasLength(2));
        expect(roundTripped.options[0].recipeId, equals('r-1'));
        expect(
          roundTripped.options[0].recipeImageUrl,
          equals('https://example.com/tacos.jpg'),
        );
        expect(roundTripped.options[0].recipePortions, equals(4));
        expect(roundTripped.options[1].recipeId, equals('r-2'));
        expect(roundTripped.options[1].recipeImageUrl, isNull);
        expect(roundTripped.options[1].recipePortions, equals(2));
      },
    );

    test('Poll.create (text-only) remains backward compatible', () {
      final poll = Poll.create(
        question: 'Pizza or Sushi?',
        optionTexts: ['Pizza', 'Sushi'],
        creatorId: 'creator-1',
      );
      final roundTripped = Poll.fromMap(poll.toMap());
      expect(roundTripped.options, hasLength(2));
      expect(roundTripped.options[0].hasRecipe, isFalse);
      expect(roundTripped.options[1].hasRecipe, isFalse);
    });
  });
}
