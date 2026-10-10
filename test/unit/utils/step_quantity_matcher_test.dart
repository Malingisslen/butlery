import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/utils/step_quantity_matcher.dart';
import 'package:butlery/widgets/common/input/portion_scaler_logic.dart';

RecipeIngredient _ing(String raw, String name, {num? amount, String? unit}) =>
    RecipeIngredient(raw: raw, name: name, amount: amount, unit: unit);

List<String> _labels(String step, List<RecipeIngredient> ings) {
  final marks = StepQuantityMatcher.matchAll(
    [step],
    ings,
    [for (final i in ings) i.raw],
  ).single;
  return [
    for (final m in marks) '${step.substring(m.start, m.end)}=${m.label}',
  ];
}

void main() {
  final tomater = _ing('4 stora tomater', 'tomater', amount: 4);
  final lok = _ing('1 gul lök', 'gul lök', amount: 1);
  final vitlok = _ing('2 vitlök', 'vitlök', amount: 2);
  final gradde = _ing('2 dl grädde', 'grädde', amount: 2, unit: 'dl');
  final graddfil = _ing('1 dl gräddfil', 'gräddfil', amount: 1, unit: 'dl');

  group('Swedish forms', () {
    test('definite plural, plural and singular all meet', () {
      for (final word in ['tomaterna', 'tomater', 'tomaten', 'tomat']) {
        expect(_labels('Tärna $word.', [tomater]), ['$word=4'], reason: word);
      }
    });

    test('definite singular of an -a noun', () {
      final olja = _ing('3 msk olja', 'olja', amount: 3, unit: 'msk');
      expect(_labels('Hetta upp oljan.', [olja]), ['oljan=3 msk']);
    });

    test('definite singular of lök, smör and grädde', () {
      expect(_labels('Hacka löken fint.', [lok]), ['löken=1']);
      expect(_labels('Vispa grädden.', [gradde]), ['grädden=2 dl']);
      final smor = _ing('50 g smör', 'smör', amount: 50, unit: 'g');
      expect(_labels('Smält smöret.', [smor]), ['smöret=50 g']);
    });

    test('å/ä/ö are letters, not word boundaries', () {
      expect(_labels('Hacka vitlöken.', [lok]), isEmpty);
      expect(_labels('Rör ner gräddfilen.', [gradde]), isEmpty);
      expect(_labels('Rör ner gräddfilen.', [gradde, graddfil]), [
        'gräddfilen=1 dl',
      ]);
    });

    test('the verb grädda does not meet grädde', () {
      expect(_labels('Grädda i ugnen.', [gradde]), isEmpty);
    });

    test('compounds do not meet their parts', () {
      final pure = _ing('2 msk tomatpuré', 'tomatpuré', amount: 2, unit: 'msk');
      expect(_labels('Rör ner tomatpurén.', [tomater]), isEmpty);
      expect(_labels('Tärna tomaterna.', [pure]), isEmpty);
      final mjol = _ing('3 dl vetemjöl', 'vetemjöl', amount: 3, unit: 'dl');
      expect(_labels('Sikta mjölet.', [mjol]), isEmpty);
    });

    test('vitlök and lök stay apart in the same recipe', () {
      expect(_labels('Fräs löken och vitlöken.', [lok, vitlok]), [
        'löken=1',
        'vitlöken=2',
      ]);
    });
  });

  group('fails closed', () {
    test('two ingredients answering to the same word mark nothing', () {
      final smor1 = _ing('50 g smör', 'smör', amount: 50, unit: 'g');
      final smor2 = _ing('1 msk smör', 'smör', amount: 1, unit: 'msk');
      expect(_labels('Smält smöret.', [smor1, smor2]), isEmpty);
    });

    test('an ingredient without a leading amount marks nothing', () {
      final salt = _ing('salt', 'salt');
      final nypa = _ing('en nypa salt', 'salt');
      expect(_labels('Smaka av med salt.', [salt]), isEmpty);
      expect(_labels('Smaka av med salt.', [nypa]), isEmpty);
    });

    test('a step that already states the amount gets no second one', () {
      expect(_labels('Tillsätt 2 dl grädde.', [gradde]), isEmpty);
      expect(_labels('Tillsätt 2 grädde.', [gradde]), isEmpty);
    });

    test('a partitive before the word marks nothing', () {
      for (final lead in [
        'hälften av',
        'resten av',
        'lite av',
        'ytterligare',
        'en del av',
      ]) {
        expect(
          _labels('Häll i $lead grädden.', [gradde]),
          isEmpty,
          reason: lead,
        );
      }
    });

    test('a numeral or count word before the word marks nothing', () {
      final smor = _ing('50 g smör', 'smör', amount: 50, unit: 'g');
      expect(_labels('Tärna 2 stora tomater.', [tomater]), isEmpty);
      expect(_labels('Tärna två tomater.', [tomater]), isEmpty);
      expect(_labels('Tillsätt 2 msk av smöret.', [smor]), isEmpty);
      expect(_labels('Hacka en halv lök.', [lok]), isEmpty);
      expect(_labels('Koka i 5 min. Tärna tomaterna.', [tomater]), [
        'tomaterna=4',
      ]);
    });

    test('a line naming two ingredients is no target', () {
      final sp = _ing('1 krm salt, peppar', 'salt, peppar', amount: 1);
      final sp2 = _ing('1 krm salt & peppar', 'salt & peppar', amount: 1);
      expect(_labels('Krydda med peppar.', [sp]), isEmpty);
      expect(_labels('Krydda med peppar.', [sp2]), isEmpty);
    });

    test('a garnish share marks nothing', () {
      final persilja = _ing('1 dl persilja', 'persilja', amount: 1, unit: 'dl');
      expect(
        _labels('Strö persiljan över.', [persilja]),
        [
          'persiljan=1 dl',
        ],
        reason: 'premise: the word reaches the garnish guard',
      );
      expect(_labels('Strö persiljan till servering.', [persilja]), isEmpty);
    });

    test('"salt och peppar" is no target', () {
      final sp = _ing('1 krm salt och peppar', 'salt och peppar', amount: 1);
      expect(_labels('Krydda med peppar.', [sp]), isEmpty);
    });

    test('misaligned lists mark nothing', () {
      final marks = StepQuantityMatcher.matchAll(
        ['Tärna tomaterna.'],
        [tomater],
        const [],
      );
      expect(marks, [isEmpty]);
    });
  });

  test('only the first mention per step is marked', () {
    expect(_labels('Tärna tomaterna och lägg tomaterna i pannan.', [tomater]), [
      'tomaterna=4',
    ]);
  });

  test('raw-only legacy lines are matched by their parsed name', () {
    final raw = RecipeIngredient.rawOnly('3 dl mjölk');
    expect(_labels('Värm mjölken.', [raw]), ['mjölken=3 dl']);
  });

  group('labelFor', () {
    test('quantity with a known unit', () {
      expect(StepQuantityMatcher.labelFor('2 dl grädde'), '2 dl');
      expect(StepQuantityMatcher.labelFor('1 ½ msk olja'), '1 ½ msk');
      expect(StepQuantityMatcher.labelFor('1,8 dl mjölk'), '1,8 dl');
      expect(StepQuantityMatcher.labelFor('2-3 dl vatten'), '2-3 dl');
    });

    test('quantity alone when no unit follows', () {
      expect(StepQuantityMatcher.labelFor('4 stora tomater'), '4');
      expect(StepQuantityMatcher.labelFor('½ citron'), '½');
    });

    test('no leading number gives null', () {
      expect(StepQuantityMatcher.labelFor('salt och peppar'), isNull);
      expect(StepQuantityMatcher.labelFor('en nypa salt'), isNull);
    });
  });

  test('the label is always text the scaled ingredient list shows', () {
    final ings = [
      tomater,
      gradde,
      _ing('3 msk olja', 'olja', amount: 3, unit: 'msk'),
      _ing('2-3 dl vatten', 'vatten'),
      _ing('1 ½ dl mjölk', 'mjölk', amount: 1.5, unit: 'dl'),
    ];
    const step =
        'Tärna tomaterna, vispa grädden, värm oljan, vattnet, mjölken.';
    for (final target in [1, 2, 3, 4, 6, 8, 16]) {
      final lines = PortionScalerLogic.scaleEntries(ings, 4, target, false);
      final marks = StepQuantityMatcher.matchAll([step], ings, lines).single;
      expect(marks, isNotEmpty, reason: 'target $target');
      for (final m in marks) {
        expect(
          lines.any((l) => l.startsWith('${m.label} ')),
          isTrue,
          reason: '${m.label} at $target not in $lines',
        );
      }
    }
  });
}
