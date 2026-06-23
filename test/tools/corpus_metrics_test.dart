@TestOn('vm')
library;

import 'package:test/test.dart';

import '../../tools/corpus/corpus_metrics.dart';
import '../../tools/corpus/corpus_models.dart';

GoldIngredient _ing(
  String name, {
  String? quantity,
  String? unit,
}) => GoldIngredient(
  name: name,
  originalLine: [quantity, unit, name].where((e) => e != null).join(' '),
  quantity: quantity,
  unit: unit,
);

GoldRecipe _recipe({
  String title = 'Köttbullar',
  String? portions,
  int? timeMinutes,
  List<GoldIngredient> ingredients = const [],
  List<String> instructions = const [],
}) => GoldRecipe(
  verified: true,
  title: title,
  portions: portions,
  timeMinutes: timeMinutes,
  ingredients: ingredients,
  instructions: instructions,
);

void main() {
  group('normalizeText / tokenize', () {
    test('preserves Swedish letters and strips punctuation', () {
      // Proves OCR artifacts (punctuation, casing) do not split a real word,
      // and that åäö are not stripped as "non-letters".
      expect(normalizeText('Färska Ägg, hackade!'), 'färska ägg hackade');
    });

    test('drops single-character noise tokens', () {
      // A stray bullet "•" or split letter must not count as a matchable token.
      expect(tokenize('a dl mjölk x'), ['dl', 'mjölk']);
    });
  });

  group('Prf.from', () {
    test('both sides empty is vacuously perfect', () {
      final p = Prf.from(matched: 0, goldCount: 0, predCount: 0);
      expect(p.f1, 1.0);
    });

    test('perfect match yields f1 = 1', () {
      final p = Prf.from(matched: 3, goldCount: 3, predCount: 3);
      expect(p.precision, 1.0);
      expect(p.recall, 1.0);
      expect(p.f1, 1.0);
    });

    test('over-prediction lowers precision but not recall', () {
      // Gold has 2, parser emitted 4, both gold items matched: recall stays
      // perfect, precision halves. This is the asymmetry that catches a parser
      // that splits one ingredient line into several.
      final p = Prf.from(matched: 2, goldCount: 2, predCount: 4);
      expect(p.recall, 1.0);
      expect(p.precision, 0.5);
      expect(p.f1, closeTo(0.6667, 0.001));
    });

    test('no overlap yields zero f1', () {
      final p = Prf.from(matched: 0, goldCount: 3, predCount: 3);
      expect(p.f1, 0.0);
    });
  });

  group('goldTokenRecall (OCR-eval)', () {
    test('full recall when every salient token survives OCR', () {
      final gold = _recipe(
        title: 'Pannkakor',
        ingredients: [_ing('vetemjöl', quantity: '3', unit: 'dl')],
      );
      final res = goldTokenRecall(gold, 'Pannkakor\n3 dl vetemjöl\n2 ägg');
      expect(res.recall, 1.0);
      expect(res.missing, isEmpty);
    });

    test('reports the specific missing tokens on a partial OCR', () {
      // The OCR dropped "saffran" entirely — recall must fall and name the
      // miss, so a bad scan is debuggable rather than a mystery number.
      final gold = _recipe(
        title: 'Lussebullar',
        ingredients: [
          _ing('vetemjöl', quantity: '13', unit: 'dl'),
          _ing('saffran', quantity: '1', unit: 'g'),
        ],
      );
      final res = goldTokenRecall(gold, 'Lussebullar 13 dl vetemjöl');
      expect(res.missing, contains('saffran'));
      expect(res.recall, lessThan(1.0));
    });

    test('quantity embedded in a merged OCR token still counts', () {
      // OCR often glues "1.5dl"; the quantity "1.5" must still be found.
      final gold = _recipe(
        title: 'Smet',
        ingredients: [_ing('grädde', quantity: '1.5', unit: 'dl')],
      );
      final res = goldTokenRecall(gold, 'Smet\n1.5dl grädde');
      expect(res.recall, 1.0);
    });
  });

  group('scoreRecipe (parser-eval)', () {
    test('identical recipe scores perfectly across all fields', () {
      final gold = _recipe(
        title: 'Köttbullar',
        portions: '4',
        timeMinutes: 30,
        ingredients: [
          _ing('nötfärs', quantity: '500', unit: 'g'),
          _ing('lök', quantity: '1', unit: 'st'),
        ],
        instructions: ['Blanda allt.', 'Stek köttbullarna.'],
      );
      final score = scoreRecipe(gold, gold);

      expect(score.titleMatch, isTrue);
      expect(score.portionsMatch, isTrue);
      expect(score.timeMatch, isTrue);
      expect(score.ingredientNames.f1, 1.0);
      expect(score.ingredientsFull.f1, 1.0);
      expect(score.instructions.f1, 1.0);
    });

    test(
      'right names but wrong quantities: name-F1 perfect, full-F1 drops',
      () {
        // This gap is the whole point of tracking two ingredient metrics — it
        // localizes failure to the CRF quantity/unit head, not item detection.
        final gold = _recipe(
          ingredients: [
            _ing('nötfärs', quantity: '500', unit: 'g'),
            _ing('lök', quantity: '1', unit: 'st'),
          ],
        );
        final predicted = _recipe(
          ingredients: [
            _ing('nötfärs', quantity: '5', unit: 'dl'),
            _ing('lök'),
          ],
        );
        final score = scoreRecipe(gold, predicted);

        expect(score.ingredientNames.f1, 1.0);
        expect(score.ingredientsFull.f1, lessThan(1.0));
      },
    );

    test('scalar fields are null when the facit does not assert them', () {
      // Gold left portions/time unspecified → eval must not penalize the
      // parser for whatever it guessed; the field is simply not scored.
      final gold = _recipe(title: 'Soppa');
      final score = scoreRecipe(gold, _recipe(title: 'Soppa', portions: '6'));
      expect(score.portionsMatch, isNull);
      expect(score.timeMatch, isNull);
    });

    test('title similarity is fuzzy and order-insensitive', () {
      final gold = _recipe(title: 'Klassiska svenska köttbullar');
      final predicted = _recipe(title: 'köttbullar, klassiska svenska');
      final score = scoreRecipe(gold, predicted);
      expect(score.titleSimilarity, 1.0);
    });

    test('instruction F1 is segmentation-invariant (token-level)', () {
      // Same content, different step boundaries: 1 merged paragraph vs 2 steps.
      // Whole-string set-match scored this 0; token-level must score it 1.0 —
      // the parser captured the content, only the segmentation differs.
      final gold = _recipe(instructions: ['Blanda allt väl. Stek i smör.']);
      final pred = _recipe(instructions: ['Blanda allt väl.', 'Stek i smör.']);
      expect(scoreRecipe(gold, pred).instructions.f1, 1.0);
    });

    test('instruction F1 still drops when content is genuinely missing', () {
      // Token-level must not become a free pass — a step the parser dropped
      // lowers recall.
      final gold = _recipe(
        instructions: ['Vispa smeten slät.', 'Stek i smör på medelvärme.'],
      );
      final pred = _recipe(instructions: ['Vispa smeten slät.']);
      expect(scoreRecipe(gold, pred).instructions.f1, lessThan(1.0));
    });
  });

  group('GoldRecipe JSON round-trip', () {
    test('survives serialize → deserialize unchanged', () {
      final original = _recipe(
        title: 'Äppelpaj',
        portions: '8 bitar',
        timeMinutes: 45,
        ingredients: [_ing('äpplen', quantity: '4', unit: 'st')],
        instructions: ['Skala äpplena.'],
      );
      final restored = GoldRecipe.fromJson(original.toJson());

      expect(restored.title, original.title);
      expect(restored.portions, original.portions);
      expect(restored.timeMinutes, original.timeMinutes);
      expect(restored.ingredients.single.quantity, '4');
      expect(restored.instructions.single, 'Skala äpplena.');
    });
  });
}
