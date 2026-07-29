// C1 (pooled-ratings plan, Data/Integrations must-have): byte-for-byte OUTPUT
// pinning for ContentFingerprint.generate().
//
// GlobalRecipeCache PERSISTS the fingerprint (Firestore field + `fp_<hash>`
// doc-ID fallback + equality query), so ANY change to the fingerprint silently
// orphans already-cached rows and re-triggers duplicate extraction LLM calls.
// The shared-normalizer extraction (plan decision 3) must be behavior-
// preserving; this golden test fails on ANY drift, not just on a red unit test.
//
// If this test fails after an intentional fingerprint change, that change is a
// cache-invalidating event — bump the cache version deliberately and re-pin,
// do NOT just update the strings to make it green.

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/import/cache/content_fingerprint.dart';
import 'package:butlery/services/import/cache/recipe_text_normalizer.dart';

void main() {
  final fp = ContentFingerprint();

  // Fixed, diverse corpus. Do not edit inputs — that defeats the pin.
  final corpus = <String, ({String title, List<String> ingredients, int n})>{
    'kottbullar': (
      title: 'Köttbullar',
      ingredients: [
        '500 g blandfärs',
        '1 gul lök',
        '1 dl ströbröd',
        '1 dl mjölk',
        '1 ägg',
        'salt och peppar',
      ],
      n: 4,
    ),
    'kladdkaka': (
      title: 'Kladdkaka',
      ingredients: [
        '2 ägg',
        '2,5 dl socker',
        '1,5 dl vetemjöl',
        '4 msk kakao',
        '100 g smör',
      ],
      n: 3,
    ),
    'pannkakor': (
      title: 'Pannkakor med sylt',
      ingredients: ['3 dl vetemjöl', '6 dl mjölk', '3 ägg', '0,5 tsk salt'],
      n: 5,
    ),
    'flygande_jakob': (
      title: 'Flygande Jakob',
      ingredients: [
        '800 g kycklingfilé',
        '2 dl grädde',
        '2 msk chilisås',
        '1 banan',
        '3 skivor bacon',
      ],
      n: 6,
    ),
    'artsoppa': (
      title: 'Ärtsoppa',
      ingredients: ['500 g gula ärter', '1 gul lök', '1 morot', '400 g fläsk'],
      n: 3,
    ),
    'parenthetical_and_approx': (
      title: 'Långkok (gryta) på högrev',
      ingredients: [
        'ca 1 kg högrev',
        '2 st lök (gula)',
        'ungefär 3 dl buljong',
      ],
      n: 7,
    ),
  };

  // Pinned outputs captured from the implementation as of 2026-07-27. A change
  // here is a cache-invalidating event — bump the cache version deliberately,
  // do NOT edit these strings to go green.
  //
  // RE-PINNED ONCE, DELIBERATELY (BUT-1713, 2026-07-27). The unit-stripping
  // regex used Dart's ASCII `\b`, which treats å/ä/ö as non-word characters and
  // therefore opened a phantom boundary before a trailing consonant: the unit
  // alternative `l` matched the last letter of "mjöl", "vitkål" and "lök", and
  // `st` the tail of "höst". Five of the six fixtures below hashed a mutilated
  // ingredient name ("mjö", "gul ök"). Swapping the regex onto
  // SwedishWordBoundary is a correctness fix, so the fingerprint MUST move.
  // GlobalRecipeCache has no version constant to bump — the fingerprint IS the
  // key (`contentFingerprint` field + `fp_<hash>` doc id), so the one-time cost
  // is that pre-existing content-fingerprint rows stop matching: URL-hash
  // lookups are unaffected, and a content miss re-extracts once. Accepted.
  // 'flygande_jakob' is unchanged, which is the sanity check that this moved
  // only the Swedish-letter cases.
  const golden = <String, String>{
    'kottbullar': '8417771176dd49fe',
    'kladdkaka': '4da56fe5e263025c',
    'pannkakor': 'ab69349a9c697c8b',
    'flygande_jakob': 'f9df56ab08f511a2',
    'artsoppa': 'acdd392bd5294ccb',
    'parenthetical_and_approx': 'a4e4acce3fadb916',
  };

  // BUT-1713. The hash pins above only prove "no drift"; they cannot say WHICH
  // behaviour is pinned, and a future re-pin would take them along. These
  // assert the readable half directly: a unit token is stripped only when it
  // stands alone, never when it is inside a Swedish word.
  //
  // Measured, not assumed (2026-07-27): reverting
  // [RecipeTextNormalizer._allUnitsRe] to `\b` reddens exactly the FOUR
  // å/ä/ö cases below — "2 dl mjöl", "vitkål", "1 gul lök", "3 st rödlök".
  // The remaining seven are recall controls: they are identical under both
  // regexes and exist to prove the tightening did not stop stripping real
  // units. Do not delete them as redundant, and do not widen this claim.
  group('normalizeIngredientName — Swedish letters survive unit stripping', () {
    const cases = <String, String>{
      '2 dl mjöl': 'mjöl', // 'l' after 'ö' — was 'mjö'
      'vitkål': 'vitkål', // was 'vitkå'
      '1 gul lök': 'gul lök', // was 'gul ök'
      // Sharpest case: the unit sits WHOLLY INSIDE the word. "rödlök" has no
      // ASCII boundary before its 'l' (preceded by 'd'), but 'ö' on both sides
      // of "dl" opened two phantom ones, so `\bdl\b` matched mid-word — "3 st
      // rödlök" normalized to 'röök' (leading 'st' plus the embedded 'dl').
      '3 st rödlök': 'rödlök',
      '2 dl havregryn': 'havregryn',
      '1 dl mjölk': 'mjölk', // already correct — must stay correct
      // Real units must still be stripped, on both edges of the line.
      '500 g blandfärs': 'blandfärs',
      '1 påse socker': 'socker',
      '3 skivor bacon': 'bacon',
      '2 dl grädde': 'grädde',
      // Pre-existing ordering quirk, pinned so it is not mistaken for this
      // fix: the amount regex is anchored at `^`, so an "ca"-prefixed line
      // keeps its digit once the approximate word is removed.
      'ca 2 dl grädde': '2 grädde',
    };

    cases.forEach((input, expected) {
      test('"$input" → "$expected"', () {
        expect(RecipeTextNormalizer.normalizeIngredientName(input), expected);
      });
    });
  });

  group('ContentFingerprint golden output (behavior pin)', () {
    for (final e in corpus.entries) {
      test('pinned: ${e.key}', () {
        final actual = fp.generateFromMap({
          'title': e.value.title,
          'ingredients': e.value.ingredients,
          'instructions': List.filled(e.value.n, 'step'),
        });
        expect(
          actual,
          golden[e.key],
          reason:
              'ContentFingerprint drift for ${e.key} — this invalidates the '
              'live GlobalRecipeCache. Bump the cache version deliberately '
              'instead of re-pinning to green.',
        );
      });
    }
  });
}
