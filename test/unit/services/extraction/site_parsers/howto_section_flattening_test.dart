/// Every site parser must flatten a `HowToSection` before it filters steps.
///
/// The four parsers each call `flattenRecipeInstructions`, but only the Arla
/// fixture actually contains a section, so deleting the call from the other
/// three left every suite green. This file sends one sectioned page through
/// all four, so each call site is pinned by something.
///
/// `HowToSection` is standard schema.org, not an Arla quirk — any of these
/// sites can start emitting it (BUT-2020).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/extraction/site_parsers/arla_recipe_parser.dart';
import 'package:butlery/services/extraction/site_parsers/ica_recipe_parser.dart';
import 'package:butlery/services/extraction/site_parsers/koket_recipe_parser.dart';
import 'package:butlery/services/extraction/site_parsers/recept_recipe_parser.dart';
import 'package:butlery/services/extraction/site_parsers/recipe_site_parser.dart';
import 'package:butlery/utils/recipe_scraper.dart';

const _sectionedPage = '''
<!DOCTYPE html>
<html lang="sv">
<head>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Recipe",
    "name": "Sektionerat recept",
    "description": "Stegen ligger i en HowToSection.",
    "totalTime": "PT30M",
    "recipeYield": "4 portioner",
    "image": "https://example.test/bild.jpg",
    "recipeIngredient": ["400 g kassler", "1 msk senap", "2 tomater"],
    "recipeInstructions": [
      {
        "@type": "HowToSection",
        "name": "Rubrik som inte är ett steg",
        "itemListElement": [
          {"@type": "HowToStep", "text": "Steg ett."},
          {"@type": "HowToStep", "text": "Steg två."},
          {"@type": "HowToStep", "text": "Steg tre."}
        ]
      }
    ]
  }
  </script>
</head>
<body></body>
</html>
''';

void main() {
  final parsers = <String, RecipeSiteParser>{
    'arla.se': ArlaRecipeParser(),
    'ica.se': IcaRecipeParser(),
    'koket.se': KoketRecipeParser(),
    'recept.se': ReceptRecipeParser(),
  };

  parsers.forEach((site, parser) {
    group(site, () {
      test('flattens a HowToSection into its steps', () {
        final recipe = parser.parseRecipe(_sectionedPage);

        expect(recipe, isNotNull, reason: 'the page failed to parse at all');
        final steps = recipe!['recipeInstructions'] as List;
        expect(steps, hasLength(3));
        expect((steps.first as Map)['text'], equals('Steg ett.'));
      });

      test('does not promote the section heading to a step', () {
        final recipe = parser.parseRecipe(_sectionedPage)!;
        final steps = recipe['recipeInstructions'] as List;

        expect(
          steps.map((s) => (s as Map)['text']),
          isNot(contains('Rubrik som inte är ett steg')),
        );
      });
    });
  });

  group('flattenRecipeInstructions', () {
    test('leaves a flat list of HowToStep untouched', () {
      const flat = [
        {'@type': 'HowToStep', 'text': 'Ett.'},
        {'@type': 'HowToStep', 'text': 'Två.'},
      ];

      expect(flattenRecipeInstructions(flat), equals(flat));
    });

    test('keeps plain strings, which some sites still emit', () {
      expect(
        flattenRecipeInstructions(['Ett.', 'Två.']),
        equals(['Ett.', 'Två.']),
      );
    });

    test('keeps a section that carries no itemListElement', () {
      // Nothing to lift out, so dropping it would lose whatever `text` it
      // does carry. Downstream filters decide whether it is usable.
      const section = [
        {'@type': 'HowToSection', 'text': 'Allt i ett stycke.'},
      ];

      expect(flattenRecipeInstructions(section), equals(section));
    });

    test('keeps a section whose itemListElement is empty', () {
      const section = [
        {'@type': 'HowToSection', 'text': 'Kvar.', 'itemListElement': []},
      ];

      expect(flattenRecipeInstructions(section), equals(section));
    });

    test('flattens sections nested more than one level deep', () {
      const nested = [
        {
          '@type': 'HowToSection',
          'itemListElement': [
            {
              '@type': 'HowToSection',
              'itemListElement': [
                {'@type': 'HowToStep', 'text': 'Djupt.'},
              ],
            },
          ],
        },
      ];

      final flattened = flattenRecipeInstructions(nested);
      expect(flattened, hasLength(1));
      expect((flattened.first as Map)['text'], equals('Djupt.'));
    });

    test('returns an empty list for anything that is not a list', () {
      // The string form of `recipeInstructions` is the caller's to handle;
      // all current callers stand behind an `is List` check.
      expect(flattenRecipeInstructions('Ett stycke text.'), isEmpty);
      expect(flattenRecipeInstructions(null), isEmpty);
      expect(flattenRecipeInstructions(<String, dynamic>{}), isEmpty);
    });
  });
}
