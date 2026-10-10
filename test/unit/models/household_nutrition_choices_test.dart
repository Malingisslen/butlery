import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/household.dart';

Map<String, dynamic> _data({Object? choices = _absent}) => {
  'name': 'Vårt hushåll',
  'members': [
    {
      'userId': 'u1',
      'permission': 'admin',
      'addedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
    },
  ],
  'createdBy': 'u1',
  'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
  'updatedAt': DateTime.utc(2026, 1, 2).toIso8601String(),
  if (!identical(choices, _absent)) 'nutritionFoodChoices': choices,
};

const Object _absent = Object();

Household _household(Map<String, int> choices) => Household(
  id: 'hh-1',
  name: 'Vårt hushåll',
  members: [
    HouseholdMember(
      userId: 'u1',
      permission: SharedListPermission.admin,
      addedAt: DateTime.utc(2026, 1, 1),
    ),
  ],
  createdBy: 'u1',
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 2),
  nutritionFoodChoices: choices,
);

void main() {
  group('fromMap', () {
    test('a household without the field has no choices', () {
      expect(Household.fromMap('hh-1', _data()).nutritionFoodChoices, isEmpty);
    });

    test('whole-number values are read', () {
      final h = Household.fromMap(
        'hh-1',
        _data(choices: {'mjölk': 123, 'gul_lök': 344}),
      );
      expect(h.nutritionFoodChoices, {'mjölk': 123, 'gul_lök': 344});
    });

    test('a value that is not a whole number is dropped, the rest survive', () {
      final h = Household.fromMap(
        'hh-1',
        _data(
          choices: {
            'ok': 7,
            'text': '123',
            'fraction': 1.5,
            'nothing': null,
            'list': [1],
            'flag': true,
          },
        ),
      );
      expect(h.nutritionFoodChoices, {'ok': 7});
      expect(h.name, 'Vårt hushåll');
    });

    test('a double that is a whole number is read as an int', () {
      final h = Household.fromMap('hh-1', _data(choices: {'mjölk': 123.0}));
      expect(h.nutritionFoodChoices, {'mjölk': 123});
    });

    test('a field that is not a map reads as empty', () {
      for (final bad in <Object?>[
        'x',
        5,
        [1, 2],
        null,
      ]) {
        final h = Household.fromMap('hh-1', _data(choices: bad));
        expect(h.nutritionFoodChoices, isEmpty, reason: '$bad');
      }
    });
  });

  group('toFirestore', () {
    test(
      'never carries the choices, so a whole-doc write cannot replace them',
      () {
        final data = _household({'mjölk': 123}).toFirestore();
        expect(data.containsKey('nutritionFoodChoices'), isFalse);
        expect(data.containsKey('nutritionChoiceKey'), isFalse);
        // Positive control: the same call does carry the other fields.
        expect(data['name'], 'Vårt hushåll');
        expect(data['memberUserIds'], ['u1']);
      },
    );

    test(
      'a household with no choices writes the same keys as one with choices',
      () {
        expect(
          _household({}).toFirestore().keys.toSet(),
          _household({'mjölk': 123}).toFirestore().keys.toSet(),
        );
      },
    );
  });

  group('JSON', () {
    test('choices round-trip through toJson / fromJson', () {
      final original = _household({'mjölk': 123, 'gul_lök': 344});
      final json = original.toJson();
      final back = Household.fromJson(json);
      expect(back.nutritionFoodChoices, {'mjölk': 123, 'gul_lök': 344});
      expect(back.id, original.id);
      expect(back.members.single.userId, 'u1');
    });

    test('no choices round-trips to no choices', () {
      final back = Household.fromJson(_household({}).toJson());
      expect(back.nutritionFoodChoices, isEmpty);
    });
  });

  group('copyWith', () {
    test('keeps the choices when a member is added or the name changes', () {
      final h = _household({'mjölk': 123});
      expect(h.copyWith(name: 'Nytt namn').nutritionFoodChoices, {
        'mjölk': 123,
      });
      expect(h.addMember('u2').nutritionFoodChoices, {'mjölk': 123});
    });
  });
}
