// test/unit/services/menu/menu_allergen_trust_stale_cascade_test.dart
//
// BUT-1963: the client's only handle on "an ingredient's allergen properties
// changed after this recipe was tagged" is the generatorVersion marker the
// Cloud Functions cascade writes (`stale-ingredient`, `stale-properties`,
// `outdated` — STALE_TAG_MARKERS in cleanup-deleted-ingredients.ts).
//
// Part 1 pins that every marker is honoured: a marked FREE is distrusted,
// a marked CONTAINS is kept. Part 2 measures the gap the ticket names: a
// recipe the cascade never reached carries NO marker, so nothing on the
// recipe lets the menu filter, the retag scheduler or the list filter tell
// it from a correctly tagged one. The fix therefore has to WRITE something
// (ticket option 3) — no client-side rule can be added without a signal.

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/menu/menu_allergen_trust.dart';
import 'package:butlery/services/tagging/tag_generator.dart'
    show kTagGeneratorVersion;

import '../../../infrastructure/factories/recipe_factory.dart';

/// Mirrors STALE_TAG_MARKERS in
/// functions/src/cleanup/cleanup-deleted-ingredients.ts. If the server adds
/// a marker, add it here: an unlisted marker is one the client never proved
/// it distrusts.
const _cascadeMarkers = ['stale-ingredient', 'stale-properties', 'outdated'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TagResult tag({
    Map<String, TriState> allergen = const {},
    Map<String, TriState> dietary = const {},
    String? version = kTagGeneratorVersion,
    int? configRevision,
  }) => TagResult(
    tags: const {},
    allergenStatus: allergen,
    dietaryStatus: dietary,
    coverage: 1.0,
    generatedAt: DateTime(2026),
    generatorVersion: version,
    configRevision: configRevision,
  );

  Recipe recipeWith(TagResult t) {
    final base = RecipeFactory.build(id: 'r1', title: 'r1');
    return Recipe(
      core: base.core.copyWith(tagResult: t),
      type: base.type,
    );
  }

  group('every cascade marker is honoured by the client', () {
    for (final marker in _cascadeMarkers) {
      test('"$marker" makes needsRetagging true', () {
        expect(tag(version: marker).needsRetagging, isTrue);
      });

      test('"$marker": a FREE verdict is downgraded to UNKNOWN for menus', () {
        final r = recipeWith(
          tag(
            allergen: {'gluten': TriState.free},
            dietary: {'vegansk': TriState.free},
            version: marker,
          ),
        );
        expect(
          MenuAllergenTrust.effectiveAllergenStatus(r, 'gluten'),
          TriState.unknown,
        );
        expect(
          MenuAllergenTrust.effectiveDietaryStatus(r, 'vegansk'),
          TriState.unknown,
        );
      });

      test('"$marker": a CONTAINS verdict is kept', () {
        final r = recipeWith(
          tag(allergen: {'gluten': TriState.contains}, version: marker),
        );
        expect(
          MenuAllergenTrust.effectiveAllergenStatus(r, 'gluten'),
          TriState.contains,
        );
      });
    }

    test('the marker list matches the one the cascade writes', () {
      // on-ingredient-properties-changed.ts writes "stale-properties"; the
      // soft-delete cascade writes "stale-ingredient"; the bulk drain writes
      // "outdated". A fourth server marker without a row here is unproven.
      expect(_cascadeMarkers, hasLength(3));
    });
  });

  group('BUT-1963 measured: an abandoned cascade leaves no trace the client '
      'can read', () {
    // A recipe tagged "gluten FREE" under the current generator, with full
    // coverage. Its ingredient has since gained gluten, but the cascade that
    // would have stamped it ran out its 1h window and wrote NOTHING.
    final unreached = recipeWith(tag(allergen: {'gluten': TriState.free}));

    // The same recipe had the cascade reached it.
    final reached = recipeWith(
      tag(allergen: {'gluten': TriState.free}, version: 'stale-properties'),
    );

    test('needsRetagging is false: the retag scheduler and the list filter '
        'both treat it as fresh', () {
      expect(unreached.tagResult!.needsRetagging, isFalse);
      expect(reached.tagResult!.needsRetagging, isTrue);
    });

    test('the menu filter trusts the stale FREE as proven absence', () {
      expect(
        MenuAllergenTrust.effectiveAllergenStatus(unreached, 'gluten'),
        TriState.free,
      );
      expect(
        MenuAllergenTrust.effectiveAllergenStatus(reached, 'gluten'),
        TriState.unknown,
      );
    });

    test('configRevision is recorded but drives nothing: a recipe tagged '
        'under an older config revision still reads as fresh', () {
      // tag_result.dart documents this as deferred (BUT-1482). Pinned here so
      // that whoever closes BUT-1963 knows this field is NOT yet a signal.
      final olderConfig = tag(
        allergen: {'gluten': TriState.free},
        configRevision: 1,
      );
      expect(olderConfig.needsRetagging, isFalse);
      expect(
        MenuAllergenTrust.effectiveAllergenStatus(
          recipeWith(olderConfig),
          'gluten',
        ),
        TriState.free,
      );
    });

    test('the two recipes are equal in every field the filters read', () {
      // The ONLY difference is the marker. Remove it and the recipes are
      // indistinguishable — which is the whole ticket.
      final a = unreached.tagResult!;
      final b = reached.tagResult!;
      expect(a.allergenStatus, b.allergenStatus);
      expect(a.coverage, b.coverage);
      expect(a.hasCoverageAnomaly, b.hasCoverageAnomaly);
      expect(a.generatorVersion, isNot(b.generatorVersion));
    });
  });
}
