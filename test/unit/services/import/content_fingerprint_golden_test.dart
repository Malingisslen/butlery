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

  // Pinned outputs captured from the implementation as of 2026-07-03. A change
  // here is a cache-invalidating event — bump the cache version deliberately,
  // do NOT edit these strings to go green.
  const golden = <String, String>{
    'kottbullar': 'b64f5490cdaa7f43',
    'kladdkaka': '26b2bcc913e9989d',
    'pannkakor': 'ea181d15c78f3dc9',
    'flygande_jakob': 'f9df56ab08f511a2',
    'artsoppa': '316fd24c3a90e310',
    'parenthetical_and_approx': 'a49575bc5bfe40a8',
  };

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
