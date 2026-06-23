/// Tests for RecipeStatsRepository classification — the core of the recipe
/// metric: a collection-group scan classified by core.sourceArtefact.type, with
/// missing field / missing core / unrecognized type all falling to manual. A
/// bug here would miscount how recipes entered the app. (The metric shaping is
/// covered separately by the recipe resolver test.)
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/admin/recipe_stats.dart';
import 'package:butlery/repositories/recipe_stats_repository.dart';

import '../../test_support/base_unit_test.dart';

Future<void> _seedRecipe(
  FakeFirebaseFirestore db,
  String uid,
  String id,
  String? type,
) async {
  final core = <String, dynamic>{'title': 'x'};
  if (type != null) {
    core['sourceArtefact'] = {'type': type, 'payload': 'p'};
  }
  await db.collection('users').doc(uid).collection('recipes').doc(id).set({
    'core': core,
  });
}

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  test('classifies each source type and treats missing as manual', () async {
    final db = FakeFirebaseFirestore();
    await _seedRecipe(db, 'u1', 'r1', 'url');
    await _seedRecipe(db, 'u1', 'r2', 'photoOcr');
    await _seedRecipe(db, 'u1', 'r3', 'tiktokCaption'); // social
    await _seedRecipe(db, 'u2', 'r4', 'textPaste');
    await _seedRecipe(db, 'u2', 'r5', null); // manual (no artefact)
    await _seedRecipe(db, 'u2', 'r7', 'legacyUnknown'); // unknown → manual
    await db.collection('users').doc('u2').collection('recipes').doc('r6').set({
      'title': 'no core',
    }); // manual (no core)

    final stats = await RecipeStatsRepository(firestore: db).getRecipeStats();

    expect(stats.total, 7);
    expect(stats.count(RecipeImportMethod.url), 1);
    expect(stats.count(RecipeImportMethod.photo), 1);
    expect(stats.count(RecipeImportMethod.social), 1);
    expect(stats.count(RecipeImportMethod.textPaste), 1);
    // missing-artefact + missing-core + unrecognized type all fall to manual
    expect(stats.count(RecipeImportMethod.manual), 3);
    expect(stats.imported, 4); // total - manual
  });

  test('empty database yields zero total, no crash', () async {
    final stats = await RecipeStatsRepository(
      firestore: FakeFirebaseFirestore(),
    ).getRecipeStats();
    expect(stats.total, 0);
    expect(stats.imported, 0);
  });
}
