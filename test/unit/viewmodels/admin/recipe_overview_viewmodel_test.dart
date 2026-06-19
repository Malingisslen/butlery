/// Tests for the admin recipe-overview tab: the RecipeStatsRepository must
/// classify recipes by `core.sourceArtefact.type` (missing → manual) across a
/// collection-group scan, and the ViewModel must surface total / imported /
/// per-method counts and degrade to empty/error without crashing. A bug here
/// would miscount how recipes entered the app.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/admin/recipe_stats.dart';
import 'package:butlery/repositories/recipe_stats_repository.dart';
import 'package:butlery/viewmodels/admin/recipe_overview_viewmodel.dart';

import '../../../test_support/base_unit_test.dart';

class _FakeRecipeStatsRepository extends RecipeStatsRepository {
  _FakeRecipeStatsRepository(this._stats)
      : super(firestore: FakeFirebaseFirestore());

  final RecipeStats _stats;
  bool throwOnLoad = false;

  @override
  Future<RecipeStats> getRecipeStats() async {
    if (throwOnLoad) throw Exception('boom');
    return _stats;
  }
}

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

  group('RecipeStatsRepository classification', () {
    test('classifies each source type and treats missing as manual', () async {
      final db = FakeFirebaseFirestore();
      await _seedRecipe(db, 'u1', 'r1', 'url');
      await _seedRecipe(db, 'u1', 'r2', 'photoOcr');
      await _seedRecipe(db, 'u1', 'r3', 'tiktokCaption'); // social
      await _seedRecipe(db, 'u2', 'r4', 'textPaste');
      await _seedRecipe(db, 'u2', 'r5', null); // manual (no artefact)
      await _seedRecipe(db, 'u2', 'r7', 'legacyUnknown'); // unknown → manual
      await db
          .collection('users')
          .doc('u2')
          .collection('recipes')
          .doc('r6')
          .set({'title': 'no core'}); // manual (no core)

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
      final stats =
          await RecipeStatsRepository(firestore: FakeFirebaseFirestore())
              .getRecipeStats();
      expect(stats.total, 0);
      expect(stats.imported, 0);
    });
  });

  group('RecipeOverviewViewModel', () {
    test('surfaces total, imported and manual from stats', () async {
      final vm = RecipeOverviewViewModel(
        repository: _FakeRecipeStatsRepository(
          const RecipeStats(
            total: 5,
            byMethod: {
              RecipeImportMethod.url: 3,
              RecipeImportMethod.manual: 2,
            },
          ),
        ),
      );
      await vm.load();
      expect(vm.total, 5);
      expect(vm.manual, 2);
      expect(vm.imported, 3);
      expect(vm.countOf(RecipeImportMethod.url), 3);
      expect(vm.countOf(RecipeImportMethod.photo), 0);
      vm.dispose();
    });

    test('zero recipes is a clean empty state, not a crash', () async {
      final vm = RecipeOverviewViewModel(
        repository: _FakeRecipeStatsRepository(
          const RecipeStats(total: 0, byMethod: {}),
        ),
      );
      await vm.load();
      expect(vm.total, 0);
      expect(vm.imported, 0);
      expect(vm.error, isNull);
      vm.dispose();
    });

    test('load failure sets error state', () async {
      final repo = _FakeRecipeStatsRepository(
        const RecipeStats(total: 0, byMethod: {}),
      )..throwOnLoad = true;
      final vm = RecipeOverviewViewModel(repository: repo);
      await vm.load();
      expect(vm.error, isNotNull);
      vm.dispose();
    });
  });
}
