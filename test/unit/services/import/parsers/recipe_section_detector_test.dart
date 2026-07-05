/// Ingredient sections (PR #211) — the audited heading heuristic.
///
/// [RecipeSectionDetector.componentSubHeadingLabel] is the single safety hinge
/// shared by the schema.org and rule-based import tiers: it decides whether a
/// line is a component sub-heading (pulled OUT of the flat ingredient list) or
/// an ingredient (kept). The dangerous direction is a false positive — it would
/// strip an allergen-bearing line from the list that tagging reads. These
/// cases pin that it fails OPEN: every ambiguous line stays an ingredient.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/import/parsers/recipe_section_detector.dart';

void main() {
  group('componentSubHeadingLabel — detected as headings', () {
    // (input, expected label)
    const headings = <(String, String)>[
      ('Deg:', 'Deg'),
      ('Fyllning:', 'Fyllning'),
      ('Glasyr:', 'Glasyr'),
      ('Till glasyren:', 'Till glasyren'),
      ('Garnering:', 'Garnering'),
      ('DEG:', 'DEG'),
      ('  Fyllning:  ', 'Fyllning'), // surrounding whitespace tolerated
      ('Till servering', 'Till servering'), // curated vocab, no colon needed
      ('såsen', 'såsen'), // curated vocab
    ];

    for (final (input, label) in headings) {
      test('"$input" → "$label"', () {
        expect(RecipeSectionDetector.componentSubHeadingLabel(input), label);
      });
    }
  });

  group(
    'componentSubHeadingLabel — fails OPEN (stays an ingredient → null)',
    () {
      // Every one of these is ambiguous or ingredient-like and MUST return null
      // so the line is kept for allergen tagging.
      const notHeadings = <String>[
        // Bare allergen words with no colon and not curated vocab.
        'salt',
        'socker',
        'mjöl',
        'ägg',
        // Digit-bearing, even with a trailing colon ("2 såser:").
        '2 såser:',
        '3 dl grädde:',
        // Unit token present → ingredient.
        '1 dl mjölk:',
        'smör 100 g:',
        // Generic block markers are not component groups — incl. the
        // colon-terminated forms the classifier's anchored regexes caught
        // before delegating here (equivalence guard for the consolidation).
        'Ingredienser:',
        'Ingredienser',
        'Gör så här:',
        'Instruktioner:',
        'Metod:',
        'Så gör du:',
        'Framställning:',
        'Tillagning:',
        'Detta behövs:',
        'Det här behöver du:',
        // Real ingredient lines (no colon).
        '2 dl vetemjöl',
        'en nypa salt',
        '1 msk soja',
        // Over-length label (a sentence that happens to end with a colon).
        'Detta är en väldigt lång rad som absolut inte är en rubrik alls:',
        // Empty / whitespace.
        '',
        '   ',
      ];

      for (final input in notHeadings) {
        test('"$input" → null (kept as ingredient)', () {
          expect(RecipeSectionDetector.componentSubHeadingLabel(input), isNull);
        });
      }
    },
  );

  test(
    'allergen-safety invariant: no bare allergen word is ever a heading',
    () {
      // The load-bearing guarantee. If any of these flipped to non-null, that
      // allergen line would vanish from the tagging input.
      const allergenWords = [
        'salt',
        'mjölk',
        'ägg',
        'vetemjöl',
        'jordnötter',
        'gluten',
        'soja',
        'sesam',
      ];
      for (final w in allergenWords) {
        expect(
          RecipeSectionDetector.componentSubHeadingLabel(w),
          isNull,
          reason: '"$w" must stay an ingredient',
        );
      }
    },
  );

  group('documented tradeoff: a colon-terminated bare word IS a heading', () {
    // The audited contract treats a trailing colon as a strong heading signal.
    // So "Mjölk:" (a lone allergen word WITH a colon) is classified as a group
    // heading, not an ingredient — it would be pulled from the tagging input.
    // This is DELIBERATE and low-risk: a real ingredient line reads "2 dl
    // mjölk", never a bare "Mjölk:"; structurally a lone-word-plus-colon IS a
    // heading. The items grouped UNDER such a heading are still tagged. These
    // tests pin the tradeoff so it stays a visible decision, not a silent one.
    // (No known import source emits "Allergen:" as its own recipeIngredient.)
    test('"Mjölk:" → "Mjölk" (colon wins — accepted, not an allergen-safety '
        'regression because lone "Mjölk:" is structurally a heading)', () {
      expect(
        RecipeSectionDetector.componentSubHeadingLabel('Mjölk:'),
        'Mjölk',
      );
    });

    test('but the SAME word without a colon stays an ingredient', () {
      expect(RecipeSectionDetector.componentSubHeadingLabel('Mjölk'), isNull);
    });
  });
}
