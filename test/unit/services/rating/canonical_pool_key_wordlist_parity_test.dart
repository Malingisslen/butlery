// Condition C5 (drift guard): the pooled-ratings word-lists are duplicated as
// native consts in the Dart hint and the TS server authority (native for
// synchronous, no-runtime-IO reasons). This test pins the Dart copies IN ORDER
// to the shared source of truth test/fixtures/pool_key_wordlists.json; its TS
// twin (functions/src/__tests__/pool-key-wordlist-parity.test.ts) pins the TS
// copies to the SAME file. A word added to one language but not the JSON — or
// to the JSON but not both languages — fails one of these two suites in CI,
// before it can route the client pool badge to a different pool than the server
// aggregates into (the silent wrong-rating bug C5 exists to prevent).
//
// Order matters, not just membership: ingredientUnits / approximateWords are
// joined into a regex alternation, so the two languages must agree on order.

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/import/cache/recipe_text_normalizer.dart';
import 'package:butlery/services/rating/canonical_pool_key.dart';

void main() {
  final json =
      jsonDecode(
            File('test/fixtures/pool_key_wordlists.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  List<String> shared(String key) => (json[key] as List).cast<String>();

  group('CanonicalPoolKey word-list parity (C5 drift guard)', () {
    // Completeness: pin the SET of lists in the JSON, not only their contents,
    // so editing the JSON's key set (adding/removing/renaming a list there)
    // can't pass silently, and a per-list assertion below can't be quietly
    // dropped without this failing. LIMIT: it compares the JSON against a
    // hardcoded expected set — it does NOT see a sixth list added to the
    // algorithm code but never registered here or in the JSON (nothing
    // enumerates the algorithm's lists). That residual is backstopped by the C4
    // end-to-end parity fixture (a new list that changes any sampled key fails
    // Dart↔TS parity) plus review. `_`-prefixed keys (e.g. `_comment`) are metadata.
    test('the JSON pins exactly the five expected lists', () {
      expect(json.keys.where((k) => !k.startsWith('_')).toSet(), {
        'ingredientUnits',
        'titleStopWords',
        'approximateWords',
        'dishQualifiers',
        'genericAnchors',
      });
    });

    test(
      'ingredientUnits matches the shared JSON source of truth, in order',
      () {
        expect(
          RecipeTextNormalizer.ingredientUnits.toList(),
          shared('ingredientUnits'),
        );
      },
    );

    test(
      'titleStopWords matches the shared JSON source of truth, in order',
      () {
        expect(
          RecipeTextNormalizer.titleStopWords.toList(),
          shared('titleStopWords'),
        );
      },
    );

    test(
      'approximateWords matches the shared JSON source of truth, in order',
      () {
        expect(
          RecipeTextNormalizer.approximateWords.toList(),
          shared('approximateWords'),
        );
      },
    );

    test(
      'dishQualifiers matches the shared JSON source of truth, in order',
      () {
        expect(
          CanonicalPoolKey.dishQualifiers.toList(),
          shared('dishQualifiers'),
        );
      },
    );

    test(
      'genericAnchors matches the shared JSON source of truth, in order',
      () {
        expect(
          CanonicalPoolKey.genericAnchors.toList(),
          shared('genericAnchors'),
        );
      },
    );
  });
}
