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
import 'package:butlery/services/import/parsers/heading_word_lists.dart';
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
    //
    // The old "no known import source emits 'Allergen:' as its own
    // recipeIngredient" line is GONE on purpose: BUT-1714 found that OCR'd
    // cookbooks do exactly that when the quantity lands in another column.
    // The tradeoff therefore survives for dairy/egg/soy only, and gluten is
    // carved out below — do not re-generalise it from this group alone.
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

    // BUT-1691 ENLARGED this set: before the Swedish word boundary landed the
    // unit guard used ASCII `\b`, so `\bl\b` matched the trailing letter of
    // "Kål" and `\bg\b` that of "Råg", and those lines were kept as
    // ingredients by accident. With a correct boundary the NON-gluten ones
    // follow the colon-wins contract; "Råg:" itself does not — BUT-1714 moved
    // it back to ingredient deliberately (see the carve-out group below), so
    // only non-allergen words are pinned here.
    const colonWins = <(String, String)>[
      ('Kål:', 'Kål'),
      ('Rödkål:', 'Rödkål'),
    ];

    for (final (input, label) in colonWins) {
      test('"$input" → "$label" (colon wins)', () {
        expect(RecipeSectionDetector.componentSubHeadingLabel(input), label);
      });
    }

    test('the same words without a colon stay ingredients', () {
      for (final w in const ['Mjölk', 'Kål', 'Rödkål']) {
        expect(
          RecipeSectionDetector.componentSubHeadingLabel(w),
          isNull,
          reason: '"$w" must stay an ingredient without a colon',
        );
      }
    });
  });

  // BUT-1714. The colon-wins contract above is CARVED OUT for gluten. BUT-1691
  // made "Mjöl:", "Vetemjöl:", "Råg:" and "Öl:" headings — correct boundary
  // handling, but it enlarged the set of allergen lines that leave the flat
  // ingredient list tagging reads, and it did so as a side effect rather than
  // as a decision. A bare gluten word plus a colon is genuinely ambiguous: in
  // an OCR'd cookbook the quantity often sits in another column, so "Mjöl:" is
  // as likely a quantity-less ingredient row as a group name. The two errors
  // are not symmetric — reading it as a heading DELETES the gluten from the
  // tagging input, reading it as an ingredient only adds a noisy row — so the
  // conservative reading wins.
  group('BUT-1714: a bare gluten word + colon stays an ingredient', () {
    const glutenLabels = <String>[
      'Mjöl:',
      'MJÖL:',
      'Vetemjöl:',
      'Rågmjöl:',
      'Grahamsmjöl:',
      'Råg:',
      'Öl:',
      'Vete:',
      'Korn:',
      'Havre:',
      'Havregryn:',
      'Dinkel:',
      'Mannagryn:',
      'Ströbröd:',
      'Bulgur:',
      'Couscous:',
      'Malt:',
      '  Mjöl:  ',
    ];

    for (final input in glutenLabels) {
      test('"$input" → null (kept for gluten tagging)', () {
        expect(RecipeSectionDetector.componentSubHeadingLabel(input), isNull);
      });
    }

    // The carve-out is narrow on purpose: it must not eat ordinary component
    // groups, including ones that merely contain a gluten word.
    //
    // "Deg:", "Fyllning:" and "Rödkål:" are deliberately NOT repeated here —
    // they are asserted verbatim in the two groups above, and a mutation that
    // widened the carve-out to eat them reddens there first. Only fixtures
    // this group is the sole owner of are listed.
    const stillHeadings = <(String, String)>[
      ('Till degen:', 'Till degen'),
      ('Mjölblandning:', 'Mjölblandning'), // gluten word as a PREFIX, not lone
      // The two below are the only fixtures that can fail if the LONE-word
      // half of [HeadingWordLists.isBareGlutenWord] is dropped: both END in a
      // gluten word, so without the whitespace guard they would return null
      // and a real component group would collapse into an ingredient row.
      // "Till degen:" above cannot catch that — it is not a gluten word under
      // either version. Single-word-only is the recorded BUT-1714 scope
      // (ACCEPTED_DEVIATIONS.md), so it is pinned rather than left implicit.
      ('Ljust vetemjöl:', 'Ljust vetemjöl'),
      ('Till mjöl:', 'Till mjöl'),
    ];

    for (final (input, label) in stillHeadings) {
      test('"$input" is still a heading → "$label"', () {
        expect(RecipeSectionDetector.componentSubHeadingLabel(input), label);
      });
    }

    // Scope boundary, pinned so the asymmetry is visible rather than looking
    // like an oversight: the carve-out covers gluten only. The other EU
    // allergens keep the colon-wins contract until that widening is evidenced
    // and decided on its own.
    // The `endsWith('mjöl')` suffix rule deliberately over-captures: these
    // flours carry no gluten, yet they too stay ingredients. Pinned because
    // the direction is what makes it acceptable — an extra ingredient row is
    // noise a user clears, whereas narrowing the suffix to an enumerated
    // gluten-flour list would put a lone "Mjöl:"-shaped OCR row one typo away
    // from being read as a heading and losing the allergen.
    test('gluten-free -mjöl compounds ride along, by design', () {
      for (final w in const ['Potatismjöl:', 'Majsmjöl:', 'Mandelmjöl:']) {
        expect(
          RecipeSectionDetector.componentSubHeadingLabel(w),
          isNull,
          reason: 'the suffix rule is intentionally wider than gluten',
        );
      }
    });

    test('non-gluten allergen words keep the colon-wins contract', () {
      for (final w in const ['Mjölk:', 'Ägg:', 'Soja:']) {
        expect(
          RecipeSectionDetector.componentSubHeadingLabel(w),
          w.substring(0, w.length - 1),
          reason: 'the BUT-1714 carve-out is deliberately gluten-only',
        );
      }
    });
  });

  // BUT-1714, the two halves the hand-typed fixture lists above cannot reach.
  //
  // The carve-out has TWO entry points over the SAME vocabulary:
  // [RecipeSectionDetector.componentSubHeadingLabel] refuses the line by
  // returning null, and [RecipeSectionDetector.bareGlutenIngredientLabel]
  // re-derives the same predicate for a caller with no ingredient fallback
  // (`swedish_line_classifier`'s `LineType.sectionHeader` branch — reading the
  // null as "clear the group" there DELETED the gluten row). It returns the
  // COLON-STRIPPED label, which is what that caller re-inserts: lookup keys
  // strip no punctuation, so a re-inserted "Mjöl:" queries `mjol:`, matches no
  // registry document and takes every allergen verdict to UNKNOWN. Both the
  // agreement of the two derivations AND the stripped shape are pinned here;
  // two copies of one predicate can drift, and the fixture lists above pin
  // neither the drift nor the vocabulary itself.
  group('BUT-1714: the gluten vocabulary and its two entry points agree', () {
    // Premise of the whole ticket: these are the words BUT-1691's boundary fix
    // moved into the heading bucket. If the set stops containing them, every
    // "→ null" fixture above still passes for the wrong reason.
    test('the vocabulary still covers the words BUT-1691 moved', () {
      expect(
        HeadingWordLists.bareGlutenWords,
        containsAll(<String>['mjöl', 'råg', 'öl', 'vete']),
      );
    });

    test('every bareGlutenWords entry is reachable', () {
      // isBareGlutenWord lowercases and refuses multi-word labels, so an entry
      // carrying a space, a stray colon or an uppercase letter would be dead
      // on arrival — present in the set, matching nothing, reading as coverage.
      // Nothing else in this suite drives the set itself, so a word added
      // later ships untested without this.
      for (final word in HeadingWordLists.bareGlutenWords) {
        expect(
          HeadingWordLists.isBareGlutenWord(word),
          isTrue,
          reason: '"$word" is in the set but can never match a label',
        );
      }
    });

    test('every vocabulary word is a candidate AND is refused as a heading', () {
      // The invariant the classifier's rescue branch rests on: it consults the
      // candidate check only AFTER the detector returned null. Should the two
      // derivations ever disagree the other way — candidate true, label
      // non-null — the classifier takes the heading branch and the gluten row
      // vanishes from the tagging input, silently, with every fixture above
      // green. Four surface forms per word, because the two functions strip
      // the colon and the whitespace independently of each other.
      final forms = <String>[
        for (final w in HeadingWordLists.bareGlutenWords) ...[
          w,
          '$w:',
          w.toUpperCase(),
          '  ${w.toUpperCase()}:  ',
        ],
        // Suffix-rule forms, which are not set members at all.
        'rågmjöl:',
        'Grahamsmjöl:',
        'Potatismjöl:',
      ];

      for (final form in forms) {
        final kept = RecipeSectionDetector.bareGlutenIngredientLabel(form);
        expect(
          kept,
          isNotNull,
          reason: '"$form" must be recognisable without reading a null',
        );
        // The re-inserted text is what tagging looks up, so its SHAPE is part
        // of the contract: no trailing colon (the key would become `mjol:` and
        // match nothing) and no surrounding whitespace.
        expect(
          kept,
          isNot(contains(':')),
          reason: '"$form" would be looked up with its colon and miss',
        );
        expect(kept, kept!.trim());
        expect(
          RecipeSectionDetector.componentSubHeadingLabel(form),
          isNull,
          reason:
              'the two derivations disagree on "$form" — the classifier would '
              'take the heading branch and drop the gluten row',
        );
      }
    });

    test('an ordinary component heading yields no ingredient label', () {
      // Recall control for the check above: without it, a function hardcoded to
      // return its argument would satisfy every assertion in this group, and
      // the classifier would push real group labels into the ingredient list.
      for (final w in const ['Deg:', 'Fyllning:', 'Till degen:', 'Mjölk:']) {
        expect(
          RecipeSectionDetector.bareGlutenIngredientLabel(w),
          isNull,
          reason: '"$w" is a real heading — the classifier must set the group',
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
