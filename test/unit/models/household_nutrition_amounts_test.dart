/// BUT-643 follow-up: a household's own nutrition amounts survive a read, and
/// an entry the rules would not have accepted is dropped, not fatal.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/household.dart';

Map<String, dynamic> _data({Object? amounts}) => {
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
  'nutritionAmountChoices': ?amounts,
};

void main() {
  test('a household without the field has no amounts', () {
    expect(
      Household.fromMap('hh-1', _data()).nutritionAmountChoices,
      isEmpty,
    );
  });

  test('amount, unit and both key shapes are read', () {
    final h = Household.fromMap(
      'hh-1',
      _data(
        amounts: {
          'kycklingfile': {'a': 600, 'u': 'g'},
          'r_3f2b8e1a-1111-2222-3333-444455556666_salt': {'a': 1.5, 'u': 'tsk'},
        },
      ),
    );

    expect(h.nutritionAmountChoices['kycklingfile']!.amount, 600);
    expect(h.nutritionAmountChoices['kycklingfile']!.unit, 'g');
    expect(
      h
          .nutritionAmountChoices['r_3f2b8e1a-1111-2222-3333-444455556666_salt']!
          .amount,
      1.5,
    );
  });

  test('a bad key or a bad value is dropped and the rest survive', () {
    final h = Household.fromMap(
      'hh-1',
      _data(
        amounts: {
          'ok': {'a': 2, 'u': 'dl'},
          'Versaler': {'a': 2, 'u': 'dl'},
          'zero': {'a': 0, 'u': 'g'},
          'huge': {'a': 100001, 'u': 'g'},
          'unit': {'a': 1, 'u': 'lass'},
          'text': {'a': '1', 'u': 'g'},
          'flat': 5,
        },
      ),
    );

    expect(h.nutritionAmountChoices.keys, ['ok']);
    expect(h.name, 'Vårt hushåll');
  });

  test('a field that is not a map reads as empty', () {
    for (final bad in <Object?>[
      'x',
      5,
      [1],
    ]) {
      expect(
        Household.fromMap('hh-1', _data(amounts: bad)).nutritionAmountChoices,
        isEmpty,
      );
    }
  });

  test('toJson and fromJson keep the amounts', () {
    final h = Household.fromMap(
      'hh-1',
      _data(
        amounts: {
          'salt': {'a': 1, 'u': 'tsk'},
        },
      ),
    );

    final back = Household.fromJson(h.toJson());

    expect(back.nutritionAmountChoices['salt']!.unit, 'tsk');
    expect(back.nutritionAmountChoices['salt']!.amount, 1);
  });

  test('copyWith keeps the amounts, and toFirestore never writes them', () {
    final h = Household.fromMap(
      'hh-1',
      _data(
        amounts: {
          'salt': {'a': 1, 'u': 'tsk'},
        },
      ),
    );

    expect(h.copyWith(name: 'Nytt').nutritionAmountChoices, hasLength(1));
    expect(h.toFirestore().containsKey('nutritionAmountChoices'), isFalse);
  });
}
