/// Unit tests for [ImportCorrectionSnapshot] (BUT-1469).
///
/// The snapshot is the anchor that lets NON-URL import paths (text, photo,
/// voice, archive) feed the parser feedback loop. These tests pin the two
/// properties the widening depends on:
///
///   1. **Parser symmetry / zero-diff.** A snapshot built from a produced
///      recipe, diffed against that same recipe unchanged, yields NO
///      corrections — so a user who imports and saves without editing never
///      generates a spurious training row. This only holds because the
///      snapshot structures ingredients with the same [IngredientParser] the
///      diff calculator uses on the corrected side.
///   2. **Real edits are captured, tagged with the import source.** When the
///      user changes the recipe, the diff off the snapshot produces a
///      correction carrying the source the snapshot was tagged with.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/parsing/cache/parsed_recipe_cache.dart';
import 'package:butlery/services/parsing/feedback/import_correction_snapshot.dart';
import 'package:butlery/services/parsing/feedback/recipe_diff_calculator.dart';

void main() {
  final calculator = RecipeDiffCalculator();

  Recipe makeRecipe({
    String id = 'r1',
    String title = 'Pannkakor',
    List<String> ingredients = const ['3 ägg', '5 dl mjölk', '2 dl vetemjöl'],
    List<String> instructions = const ['Vispa ihop.', 'Grädda i stekpanna.'],
    int? portions = 4,
    int? timeMinutes = 30,
  }) {
    return Recipe(
      core: RecipeCore(
        id: id,
        title: title,
        description: '',
        ingredients: ingredients,
        instructions: instructions,
        mealType: 'Middag',
        portions: portions,
        timeMinutes: timeMinutes,
      ),
      type: RecipeType.personal,
    );
  }

  group('ImportCorrectionSnapshot.build', () {
    test(
      'tags the snapshot with the given source and the sentinel version',
      () {
        final snapshot = ImportCorrectionSnapshot.build(
          makeRecipe(),
          source: ImportSource.photo,
        );

        expect(snapshot.metadata.source, ImportSource.photo);
        expect(
          snapshot.metadata.parserVersion,
          ImportCorrectionSnapshot.snapshotParserVersion,
        );
        expect(snapshot.title.value, 'Pannkakor');
        expect(snapshot.ingredients.value, hasLength(3));
        expect(snapshot.instructions.value, hasLength(2));
        expect(snapshot.portions.value, 4);
        expect(snapshot.totalTime.value, const Duration(minutes: 30));
      },
    );

    test('empty optional fields degrade to failed FieldResults', () {
      final snapshot = ImportCorrectionSnapshot.build(
        makeRecipe(title: '', portions: null, timeMinutes: null),
        source: ImportSource.text,
      );

      expect(snapshot.title.hasValue, isFalse);
      expect(snapshot.portions.hasValue, isFalse);
      expect(snapshot.totalTime.hasValue, isFalse);
    });
  });

  group(
    'snapshot + RecipeDiffCalculator (the correction-capture contract)',
    () {
      test('unedited save yields NO corrections (parser symmetry)', () {
        final recipe = makeRecipe();
        final snapshot = ImportCorrectionSnapshot.build(
          recipe,
          source: ImportSource.text,
        );

        final correction = calculator.calculateDiff(
          original: snapshot,
          corrected: recipe,
          userId: 'u1',
        );

        expect(
          correction,
          isNull,
          reason:
              'importing and saving without edits must not train the parser',
        );
      });

      test('an ingredient edit is captured as a correction', () {
        final imported = makeRecipe();
        final snapshot = ImportCorrectionSnapshot.build(
          imported,
          source: ImportSource.voice,
        );

        // User corrects a quantity and adds an ingredient.
        final edited = imported.copyWith(
          ingredients: const [
            '4 ägg', // 3 -> 4
            '5 dl mjölk',
            '2 dl vetemjöl',
            '1 krm salt', // added
          ],
        );

        final correction = calculator.calculateDiff(
          original: snapshot,
          corrected: edited,
          userId: 'u1',
        );

        expect(correction, isNotNull);
        expect(correction!.totalCorrections, greaterThan(0));
        expect(
          correction.source,
          ImportSource.voice,
          reason:
              'the correction must carry the import source it was tagged with',
        );
      });

      // DOMAIN INVARIANT the widening promises and now upholds (BUT-1469).
      // A quantity+unit-only ingredient line ("2 dl") parses to an EMPTY name
      // (IngredientParser: unit-first match consumes everything after the
      // quantity), so the identical line could never self-match by name and
      // fabricated a phantom removed+added pair on an UNEDITED save — training
      // the parser on noise, the exact thing zero-diff must prevent. Fixed:
      // RecipeDiffCalculator now pairs name-less lines by raw line (and treats
      // two empty names as unchanged), so an unedited save yields no corrections.
      test(
        'unedited save with a name-less line ("2 dl") yields NO corrections',
        () {
          final recipe = makeRecipe(
            ingredients: const ['2 dl grädde', '2 dl', '1 msk smör'],
          );
          final snapshot = ImportCorrectionSnapshot.build(
            recipe,
            source: ImportSource.text,
          );

          final correction = calculator.calculateDiff(
            original: snapshot,
            corrected: recipe,
            userId: 'u1',
          );

          expect(
            correction,
            isNull,
            reason:
                'an unedited save must never fabricate corrections, even when '
                'a line parses to an empty ingredient name',
          );
        },
      );

      // Guards the OTHER direction of the BUT-1469 fix: raw-line self-matching
      // must not over-correct. Two distinct name-less lines ("2 dl", "3 dl")
      // both parse to an empty name, so the fix pairs them by raw line. A real
      // edit to one of them ("3 dl" -> "4 dl") must still surface as a
      // correction, and the untouched "2 dl" must NOT be dragged into a phantom
      // merge with it. If a future refactor drops the raw-line check and treats
      // "both name-less" as an unconditional match, a genuine edit would be
      // silently swallowed — this pins against that regression.
      test(
        'a genuine edit to a name-less line is captured and distinct '
        'name-less lines are not merged',
        () {
          final imported = makeRecipe(
            ingredients: const ['2 dl grädde', '2 dl', '3 dl', '1 msk smör'],
          );
          final snapshot = ImportCorrectionSnapshot.build(
            imported,
            source: ImportSource.text,
          );

          final edited = imported.copyWith(
            ingredients: const [
              '2 dl grädde',
              '2 dl', // unchanged name-less line — must stay matched
              '4 dl', // 3 dl -> 4 dl, a real name-less edit
              '1 msk smör',
            ],
          );

          final correction = calculator.calculateDiff(
            original: snapshot,
            corrected: edited,
            userId: 'u1',
          );

          expect(
            correction,
            isNotNull,
            reason: 'a real edit to a name-less line must be captured',
          );
          expect(correction!.totalCorrections, greaterThan(0));
        },
      );
    },
  );

  // The capture→cache→retrieve wiring is what actually makes non-URL paths
  // feed the feedback loop; build()+diff symmetry alone proves nothing ships.
  group('ImportCorrectionSnapshot.capture (cache wiring)', () {
    test('stores a snapshot keyed by recipe id, tagged with the source', () {
      final cache = ParsedRecipeCache();
      ImportCorrectionSnapshot.capture(
        makeRecipe(id: 'cap-1'),
        source: ImportSource.archive,
        cache: cache,
      );

      final stored = cache.retrieve('cap-1');
      expect(stored, isNotNull);
      expect(stored!.metadata.source, ImportSource.archive);
      expect(
        stored.metadata.parserVersion,
        ImportCorrectionSnapshot.snapshotParserVersion,
      );
    });

    test(
      'photo capture overwrites the inner text snapshot under the same id',
      () {
        // Mirrors PhotoImportStrategy: the delegated TextImportStrategy stores
        // a `text` snapshot first, then photo re-captures the same recipe id.
        // Last write must win so dictation/OCR corrections never land in the
        // pasted-text training bucket.
        final cache = ParsedRecipeCache();
        final recipe = makeRecipe(id: 'cap-2');

        ImportCorrectionSnapshot.capture(
          recipe,
          source: ImportSource.text,
          cache: cache,
        );
        ImportCorrectionSnapshot.capture(
          recipe,
          source: ImportSource.photo,
          cache: cache,
        );

        expect(cache.retrieve('cap-2')!.metadata.source, ImportSource.photo);
      },
    );

    test('no-ops for an empty recipe id (never keys the cache by "")', () {
      final cache = ParsedRecipeCache();
      ImportCorrectionSnapshot.capture(
        makeRecipe(id: ''),
        source: ImportSource.text,
        cache: cache,
      );

      expect(cache.contains(''), isFalse);
    });
  });
}
