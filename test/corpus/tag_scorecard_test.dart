/// Prediction harness for the tag-accuracy scorecard.
///
/// This is a *script shaped as a test* (it needs the real tagging pipeline) —
/// NOT a CI test. Double-guarded so a normal `flutter test` never runs it:
///   1. Tagged `corpus-tools` (excluded by the default tag config).
///   2. Skips at runtime unless `RUN_TAG_SCORECARD=1`.
///
/// What it does, per VERIFIED recipe (`gold.json`) in the corpus:
///   1. Build a [Recipe] from the verified recipe content.
///   2. Resolve ingredients against the REAL [IngredientLookupService], backed
///      by a fake Firestore seeded from the committed ingredient snapshot
///      (`scripts/crf/data/firebase_ingredients.json`) — so name-matching,
///      fuzzy variations and coverage are computed exactly as in production,
///      with no network and no Firebase project.
///   3. Run the real [TagGenerator] (firebaseConfig: null → static configs, no
///      LLM, no Firebase) and write `tags.draft.json` (the prediction).
///
/// Hand-label `tags.gold.json` next to each recipe, then score with
/// `dart run tools/tag_scorecard.dart`.
///
/// Run it:
///   RUN_TAG_SCORECARD=1 flutter test test/corpus/tag_scorecard_test.dart
@Tags(['corpus-tools'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/repositories/firebase/firebase_ingredient_repository.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/services/tagging/ingredient_lookup_service.dart';
import 'package:butlery/services/tagging/tag_generator.dart';

import '../../tools/corpus/corpus_models.dart';
import '../../tools/corpus/corpus_paths.dart';
import '../../tools/corpus/tag_eval_core.dart';
import '../../tools/corpus/tag_models.dart';

const _enabled = bool.fromEnvironment('dart.vm.product') ? false : true;
bool get _shouldRun =>
    _enabled && Platform.environment['RUN_TAG_SCORECARD'] == '1';

/// The ingredient snapshot already committed for CRF training — a PII-free dump
/// of the global ingredient DB in `IngredientData.fromMap` shape.
const _snapshotPath = 'scripts/crf/data/firebase_ingredients.json';

void main() {
  test(
    'tag scorecard: predict tags for every verified recipe into tags.draft.json',
    () async {
      final paths = CorpusPaths.resolve();
      if (!paths.exists) {
        fail('Corpus root not found: ${paths.root}. Set BUTLERY_CORPUS_DIR.');
      }

      final lookup = await _buildLookupService();
      final generator = TagGenerator(firebaseConfig: null);

      var processed = 0;
      var skipped = 0;

      for (final bookDir in paths.books()) {
        final bookSlug = _basename(bookDir.path);
        for (final entry in paths.recipeEntries(bookSlug)) {
          final gold = _readRecipe(File(entry.goldPath));
          if (gold == null || !gold.verified) {
            skipped++;
            continue;
          }

          final recipe = _recipeFromGold(gold);
          final lookupResult = await lookup.lookupFromRaw(recipe.ingredients);
          final tagResult = generator.generate(
            ingredients: lookupResult,
            recipe: recipe,
          );

          final prediction = _toPrediction(tagResult);
          File(tagsDraftPath(entry.draftPath)).writeAsStringSync(
            const JsonEncoder.withIndent('  ').convert(prediction.toJson()),
          );
          processed++;
          stdout.writeln(
            'Predicted tags for $bookSlug/${entry.recipeId} '
            '(coverage ${(lookupResult.coverage * 100).toStringAsFixed(0)}%)',
          );
        }
      }

      stdout.writeln(
        'Tag prediction done: $processed written, $skipped '
        'skipped (unverified recipes).',
      );
    },
    skip: _shouldRun
        ? false
        : 'set RUN_TAG_SCORECARD=1 to run the tag prediction batch',
  );
}

/// Builds the production [IngredientLookupService] over a fake Firestore seeded
/// from the committed snapshot, so matching/coverage match production exactly.
Future<IngredientLookupService> _buildLookupService() async {
  final snapshotFile = File(_snapshotPath);
  if (!snapshotFile.existsSync()) {
    fail(
      'Ingredient snapshot not found at $_snapshotPath. '
      'Run from the project root.',
    );
  }
  final raw = jsonDecode(snapshotFile.readAsStringSync()) as List;
  final firestore = FakeFirebaseFirestore();
  for (final record in raw.whereType<Map>()) {
    final map = record.cast<String, dynamic>();
    final id = map['id']?.toString();
    if (id == null || id.isEmpty) continue;
    await firestore
        .collection(FirestoreCollections.ingredients)
        .doc(id)
        .set(map);
  }

  final repo = FirebaseIngredientRepository(firestore: firestore);
  await repo.initialize();
  return IngredientLookupService(
    ingredientRepository: repo,
    userIngredientRepository: _NoUserIngredients(),
  );
}

PredictedTags _toPrediction(TagResult result) => PredictedTags(
  allergens: {
    for (final e in result.allergenStatus.entries)
      e.key: TagTriState.fromString(e.value.name),
  },
  dietary: {
    for (final e in result.dietaryStatus.entries)
      e.key: TagTriState.fromString(e.value.name),
  },
  tags: result.tags,
  coverage: result.coverage,
  unmatchedIngredients: result.unknownIngredients.length,
);

Recipe _recipeFromGold(GoldRecipe gold) => Recipe.personal(
  title: gold.title,
  description: '',
  ingredients: gold.ingredients.map((i) => i.originalLine).toList(),
  instructions: gold.instructions,
  mealType: 'middag',
  portions: int.tryParse(gold.portions ?? ''),
  timeMinutes: gold.timeMinutes,
);

GoldRecipe? _readRecipe(File file) {
  if (!file.existsSync()) return null;
  try {
    final json = jsonDecode(file.readAsStringSync());
    if (json is! Map) return null;
    return GoldRecipe.fromJson(json.cast<String, dynamic>());
  } catch (_) {
    return null;
  }
}

String _basename(String p) {
  final cleaned = p.replaceAll('\\', '/');
  final i = cleaned.lastIndexOf('/');
  return i < 0 ? cleaned : cleaned.substring(i + 1);
}

/// No user-defined ingredients in the eval — the global DB is the whole story.
class _NoUserIngredients implements UserIngredientRepository {
  @override
  Future<IngredientData?> findByName(String userId, String name) async => null;
  @override
  Future<IngredientData?> getById(String userId, String ingredientId) async =>
      null;
  @override
  Future<List<IngredientData>> getAll(String userId) async => const [];
  @override
  Future<IngredientData> create(
    String userId,
    IngredientData ingredient,
  ) async => ingredient;
  @override
  Future<void> update(String userId, IngredientData ingredient) async {}
  @override
  Future<void> delete(String userId, String ingredientId) async {}
  @override
  Stream<List<IngredientData>> watchAll(String userId) =>
      Stream.value(const []);
}
