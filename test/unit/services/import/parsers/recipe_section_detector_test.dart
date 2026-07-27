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
        // Digit-FREE, so the `RegExp(r'\d')` check above cannot answer first:
        // these reach the unit guard itself. Without them the guard is
        // deletable with the suite green, and every digit-free unit-bearing
        // line becomes a heading — i.e. leaves the tagging input.
        'nypa salt:',
        'påse spenat:',
        'burk krossade tomater:',
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

    // BUT-1691 ENLARGED this set, and that must be visible rather than
    // discovered later. Before the Swedish word boundary landed, the unit guard
    // used ASCII `\b`, so `\bl\b` matched the trailing letter of "Kål" and
    // `\bg\b` that of "Råg": those lines were treated as unit-bearing and
    // therefore kept as ingredients — by accident, not by decision. With a
    // correct boundary they now follow the same colon-wins contract as
    // "Mjölk:". Same reasoning, same low risk (a lone word plus a colon is
    // structurally a heading, and the rows grouped under it are still tagged),
    // but three of these are gluten-bearing, so it is pinned explicitly.
    const enlargedByBoundaryFix = <(String, String)>[
      ('Mjöl:', 'Mjöl'),
      ('Vetemjöl:', 'Vetemjöl'),
      ('Kål:', 'Kål'),
      ('Råg:', 'Råg'),
      ('Öl:', 'Öl'),
    ];

    for (final (input, label) in enlargedByBoundaryFix) {
      test(
        '"$input" → "$label" (colon wins; was an accident of ASCII \\b)',
        () {
          expect(RecipeSectionDetector.componentSubHeadingLabel(input), label);
        },
      );
    }

    test('the same words without a colon stay ingredients', () {
      for (final w in const ['Mjöl', 'Vetemjöl', 'Kål', 'Råg', 'Öl']) {
        expect(
          RecipeSectionDetector.componentSubHeadingLabel(w),
          isNull,
          reason: '"$w" must stay an ingredient without a colon',
        );
      }
    });
  });

  // BUT-1691, the other half: `instructionScore` is a DROP gate. At >= 2 the
  // line never reaches the measurement extractor (`text_import_strategy`
  // `continue`s), so a phantom point deletes a real ingredient row. With ASCII
  // `\b` the "sen" alternative matched the tail of any word ending in "-sen"
  // after a Swedish vowel, and "såsen" is itself in the curated section
  // vocabulary. Reverting the boundary reddens these.
  group('instructionScore — no phantom sequencing points', () {
    const ingredientLinesThatMustSurvive = <String>[
      '2 st burkar krossade tomater samt lite av spadet till såsen',
      '1 påse riven ost till gratängen och lite extra i gräddsåsen',
      'ett par nävar färska gräsen och örter till garneringen ovanpå',
    ];

    for (final line in ingredientLinesThatMustSurvive) {
      test('"$line" scores below the drop gate', () {
        expect(
          RecipeSectionDetector.instructionScore(line),
          lessThan(2),
          reason:
              'a phantom "sen" match plus the >40-char point reaches 2, and '
              'the caller drops the line outright',
        );
      });
    }

    test('a real sequencing word still scores', () {
      expect(
        RecipeSectionDetector.instructionScore('Sedan rör du om i grytan'),
        greaterThanOrEqualTo(1),
      );
    });
  });

  // BUT-1661. The word list used to be bounded with Dart's ASCII word
  // boundary, which never borders å/ä/ö: with one on either side of a token
  // like "ägg" the pattern could not match at all, so a headerless "2 ägg"
  // line was silently dropped from the ingredient list.
  //
  // The boundary is now a TRAILING lookahead only — `ägg(?![a-zåäö0-9])` — and
  // that asymmetry is the point, not an oversight. `looksLikeIngredient` has an
  // asymmetric cost: a false positive merely keeps a line in the ingredient
  // list (harmless), while a false negative DELETES it, because
  // `text_import_strategy` has no fallback branch after this check. So the
  // guard is deliberately loose on the leading edge and strict on the trailing
  // edge, and these tests encode that direction rather than "tight is better".
  group('looksLikeIngredient — Unicode-safe Swedish word boundaries', () {
    const shouldMatch = <String>[
      '2 ägg', // the regression case: åäö-leading, unit-less
      'Ägg', // capitalised
      '2 dl råsocker', // measurement branch — matches before the word list
      'ägg och mjölk',
      'ett ägg',
      'smör',
      'lite mjöl',
      'riven ost och kött',
    ];

    for (final line in shouldMatch) {
      test('"$line" is an ingredient', () {
        expect(RecipeSectionDetector.looksLikeIngredient(line), isTrue);
      });
    }

    // Proves that a bare compound-TAIL ingredient word survives the boundary,
    // so the line is never deleted from a headerless import.
    //
    // These five previously returned FALSE and were dropped outright. Two
    // different mechanisms put them there, and both are now closed:
    //   * 'Råsocker'/'råmjölk'/'strösocker' — a two-sided boundary
    //     `(?<![a-zåäö0-9])socker(?!...)` rejects them because the token sits
    //     at the END of the compound. (The pre-BUT-1661 ASCII `\b` accidentally
    //     matched these, because å/ö are not ASCII word chars, so a two-sided
    //     Unicode boundary would have been a RECALL REGRESSION against the
    //     behaviour it replaced.)
    //   * 'Havssalt'/'vetemjöl' — all-ASCII prefixes, so neither `\b` nor a
    //     two-sided lookaround ever matched them. Bare, unmeasured, they were
    //     dropped by every previous version of this function.
    // 'råmjölk' is the safety case: unpasteurised milk carries an allergen, so
    // losing the line loses the allergen.
    const compoundTailsThatMustSurvive = <String>[
      'strösocker',
      'råsocker',
      'Råsocker', // capitalised, as an OCR/caption line actually arrives
      'råmjölk', // allergen-bearing — the reason this is a safety fix
      'havssalt',
      'Havssalt',
      'vetemjöl',
    ];

    for (final line in compoundTailsThatMustSurvive) {
      test('"$line" (bare compound tail) stays an ingredient', () {
        expect(
          RecipeSectionDetector.looksLikeIngredient(line),
          isTrue,
          reason:
              'a false negative deletes this line — text_import_strategy has '
              'no fallback branch after looksLikeIngredient',
        );
      });
    }

    // The trailing edge is what still keeps the real false positives out: a
    // listed token followed by MORE letters is a different word (a dish name or
    // a section label), not an ingredient. Each of these goes red the moment
    // the `(?![a-zåäö0-9])` lookahead is dropped for a bare `contains()`, which
    // is the only remaining mutation this function is exposed to.
    const shouldNotMatch = <String>[
      'Äggröra', // 'ägg' + suffix
      'Mjölkchoklad', // 'mjölk' + suffix
      'Riskaka', // 'ris' + suffix
      'Vitlöksbröd', // 'vitlök' + suffix
    ];

    for (final line in shouldNotMatch) {
      test('"$line" is not matched by the word list', () {
        expect(RecipeSectionDetector.looksLikeIngredient(line), isFalse);
      });
    }

    // The ticket's three named forms, kept together so the contract reads in
    // one place: bare word, quantity-prefixed unit-less line, and the token
    // inside a sentence. The third is an accepted FALSE POSITIVE at line level
    // — "lägg till ägg och rör om" is an instruction — and it is listed here
    // precisely because true is the safe answer: this predicate only ever
    // decides whether to KEEP a line, and callers that need to reject
    // instructions score them separately (instructionScore).
    test('the three BUT-1661 "ägg" forms all count as ingredients', () {
      for (final line in const [
        'ägg',
        '2 ägg',
        'lägg till ägg och rör om',
      ]) {
        expect(
          RecipeSectionDetector.looksLikeIngredient(line),
          isTrue,
          reason: '"$line" must not be dropped by the word-boundary guard',
        );
      }
    });
  });
}
