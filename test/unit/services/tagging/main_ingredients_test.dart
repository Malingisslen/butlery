import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/models/tagging/ingredient_line.dart';
import 'package:butlery/services/tagging/main_ingredients.dart';
import 'package:flutter_test/flutter_test.dart';

IngredientData _row(String id, [String group = 'vegetable']) => IngredientData(
  id: id,
  swedish: id,
  english: id,
  group: group,
  properties: const {},
);

IngredientLine _line(String id, {double? grams, String group = 'vegetable'}) =>
    IngredientLine(
      names: [id],
      ingredients: [_row(id, group)],
      known: true,
      grams: grams,
    );

IngredientLine _unmatched(String name, {double? grams}) => IngredientLine(
  names: [name],
  ingredients: const [],
  known: false,
  grams: grams,
);

List<String> _mainNames(List<IngredientLine> lines) => [
  for (final l in MainIngredients.of(lines)) l.names.first,
];

void main() {
  group('MainIngredients.of with weights', () {
    test('exactly 15 % of the weighed total is not main, just above is', () {
      expect(
        _mainNames([_line('kyckling', grams: 85), _line('morot', grams: 15)]),
        ['kyckling'],
      );
      expect(
        _mainNames([_line('kyckling', grams: 85), _line('morot', grams: 15.5)]),
        ['kyckling', 'morot'],
      );
    });

    test('a staple does not count towards the total the share is taken of', () {
      // Without salt: 16 / 101 = 15.8 %. With 1 kg of salt in the total it
      // would be 1.5 % and the carrot would drop out.
      final lines = [
        _line('kyckling', grams: 85),
        _line('morot', grams: 16),
        _line('salt', grams: 1000),
      ];

      expect(_mainNames(lines), ['kyckling', 'morot']);
    });

    test('a heavy weighed line pushes a light one out of main', () {
      final lines = [_line('potatis', grams: 1000), _line('dill', grams: 20)];

      expect(_mainNames(lines), ['potatis']);
    });

    test('a lone weighed line is 100 % and so main', () {
      expect(_mainNames([_line('lax', grams: 3)]), ['lax']);
    });

    test('a weight of zero is treated as no weight', () {
      // Position 0 among non-staples: main by order, not by share (0 / 100).
      final lines = [_line('persilja', grams: 0), _line('pasta', grams: 100)];

      expect(_mainNames(lines), ['persilja', 'pasta']);
    });
  });

  group('MainIngredients.of without weights', () {
    test('the first three non-staple lines are main, the fourth is not', () {
      final lines = [
        for (final n in ['a', 'b', 'c', 'd']) _line(n),
      ];

      expect(_mainNames(lines), ['a', 'b', 'c']);
    });

    test('staples do not use up the three places', () {
      final lines = [
        _line('salt'),
        _line('vatten'),
        _line('a'),
        _line('svartpeppar'),
        _line('b'),
        _line('c'),
        _line('d'),
      ];

      expect(_mainNames(lines), ['a', 'b', 'c']);
    });

    test('an unmatched, unweighed line is main when it is early', () {
      final lines = [_unmatched('mystisk sås'), _line('pasta')];

      expect(_mainNames(lines), ['mystisk sås', 'pasta']);
    });
  });

  group('MainIngredients.of with weighed and unweighed lines mixed', () {
    test('an unweighed line is judged by position, not by the weights', () {
      final lines = [
        _line('pasta', grams: 400),
        _line('lax', grams: 300),
        _line('dill'), // third non-staple line
        _line('citron'), // fourth
      ];

      expect(_mainNames(lines), ['pasta', 'lax', 'dill']);
    });

    test('weighed lines count towards the position of unweighed ones', () {
      final lines = [
        _line('a', grams: 100),
        _line('b', grams: 100),
        _line('c', grams: 100),
        _line('d'),
      ];

      expect(_mainNames(lines), ['a', 'b', 'c']);
    });

    test('a later unweighed line is not main although light weighed ones are '
        'main by share', () {
      final lines = [
        _line('a', grams: 100),
        _line('b', grams: 100),
        _line('c', grams: 100),
        _line('d', grams: 100),
        _line('e'),
      ];

      expect(_mainNames(lines), ['a', 'b', 'c', 'd']);
    });
  });

  group('staples', () {
    test('salt, pepper, water and sugar are never main', () {
      final lines = [
        for (final id in [
          'salt',
          'peppar',
          'svartpeppar',
          'vitpeppar',
          'vatten',
          'socker',
          'strösocker',
          'flingsalt',
          'malen svartpeppar',
        ])
          _line(id, grams: 500),
        _line('torsk', grams: 10),
      ];

      expect(_mainNames(lines), ['torsk']);
    });

    test('anything in the fat/oil group is a staple whatever its name', () {
      expect(
        MainIngredients.isStaple(_line('rapsolja', group: 'fat/oil')),
        isTrue,
      );
      expect(
        MainIngredients.isStaple(_line('kokosfett', group: 'fat/oil')),
        isTrue,
      );
      expect(
        MainIngredients.isStaple(_line('smör', group: 'protein/dairy')),
        isFalse,
      );
    });

    test('a known line is a staple only when every row is one', () {
      final saltAndTomato = IngredientLine(
        names: ['salt', 'tomat'],
        ingredients: [_row('salt'), _row('tomat')],
        known: true,
      );
      final saltAndPepper = IngredientLine(
        names: ['salt', 'peppar'],
        ingredients: [_row('salt'), _row('peppar')],
        known: true,
      );

      expect(MainIngredients.isStaple(saltAndTomato), isFalse);
      expect(MainIngredients.isStaple(saltAndPepper), isTrue);
    });

    test('unmatched staple names are recognised by name', () {
      for (final name in [
        'salt',
        'Salt',
        '  peppar ',
        'svartpeppar',
        'vitpeppar',
        'vatten',
        'socker',
        'strösocker',
        'olivolja',
        'Rapsolja',
      ]) {
        expect(
          MainIngredients.isStaple(_unmatched(name)),
          isTrue,
          reason: name,
        );
      }
    });

    test('unmatched names that only resemble a staple are not staples', () {
      for (final name in [
        'saltgurka',
        'sockerärtor',
        'vattenmelon',
        'oljesardiner',
        'basilika',
      ]) {
        expect(
          MainIngredients.isStaple(_unmatched(name)),
          isFalse,
          reason: name,
        );
      }
    });

    test('an unmatched line is a staple only when every name is', () {
      final saltAndPepper = IngredientLine(
        names: ['salt', 'peppar'],
        ingredients: const [],
        known: false,
      );
      final saltAndBasil = IngredientLine(
        names: ['salt', 'basilika'],
        ingredients: const [],
        known: false,
      );

      expect(MainIngredients.isStaple(saltAndPepper), isTrue);
      expect(MainIngredients.isStaple(saltAndBasil), isFalse);
    });

    test('an unmatched staple name is left out of the weighed total', () {
      // 16 / 101 is main only when the 1 kg of unmatched olive oil is a staple.
      final lines = [
        _line('kyckling', grams: 85),
        _line('morot', grams: 16),
        _unmatched('olivolja', grams: 1000),
      ];

      expect(_mainNames(lines), ['kyckling', 'morot']);
    });

    test('a line with no names is not a staple', () {
      const empty = IngredientLine(names: [], ingredients: [], known: false);

      expect(MainIngredients.isStaple(empty), isFalse);
    });
  });

  group('MainIngredients.gramsWhere', () {
    bool isMeat(IngredientData i) => i.group.startsWith('protein/meat');

    test('sums the weighed lines whose rows all pass', () {
      final lines = [
        _line('kyckling', grams: 300, group: 'protein/meat/poultry'),
        _line('fläsk', grams: 150, group: 'protein/meat/pork'),
        _line('ris', grams: 400, group: 'grain'),
      ];

      expect(MainIngredients.gramsWhere(lines, isMeat), 450);
    });

    test('an unweighed line adds nothing', () {
      final lines = [
        _line('kyckling', grams: 300, group: 'protein/meat/poultry'),
        _line('fläsk', group: 'protein/meat/pork'),
      ];

      expect(MainIngredients.gramsWhere(lines, isMeat), 300);
    });

    test('a line with one failing row adds nothing', () {
      final mixed = IngredientLine(
        names: ['kyckling och ris'],
        ingredients: [
          _row('kyckling', 'protein/meat/poultry'),
          _row('ris', 'grain'),
        ],
        known: true,
        grams: 500,
      );

      expect(MainIngredients.gramsWhere([mixed], isMeat), 0);
    });

    test('a line with no matched rows adds nothing, whatever its weight', () {
      expect(
        MainIngredients.gramsWhere([
          _unmatched('mystisk', grams: 200),
        ], (_) => true),
        0,
      );
    });

    test('no lines is zero', () {
      expect(MainIngredients.gramsWhere(const [], (_) => true), 0);
    });
  });

  // Review of steg 5C: staples are matched on the last word of the name.
  group('staple names', () {
    test('kolja is a fish, not an oil', () {
      expect(MainIngredients.isStaple(_line('kolja')), isFalse);
      expect(MainIngredients.isStaple(_unmatched('rökt kolja')), isFalse);
      expect(MainIngredients.isStaple(_unmatched('rapsolja')), isTrue);
    });

    test('a known row is a staple by its Swedish name', () {
      expect(MainIngredients.isStaple(_line('farinsocker')), isTrue);
      expect(MainIngredients.isStaple(_line('havssalt')), isTrue);
      expect(MainIngredients.isStaple(_line('sockerärta')), isFalse);
    });
  });

  group('lines that name nothing', () {
    test('a blank line takes no place among the first three', () {
      final blank = IngredientLine(
        names: const [],
        ingredients: const [],
        known: false,
      );
      expect(
        _mainNames([blank, _line('a'), _line('b'), _line('c'), _line('d')]),
        ['a', 'b', 'c'],
      );
      expect(MainIngredients.countable([blank, _line('a')]).length, 1);
    });
  });
}
