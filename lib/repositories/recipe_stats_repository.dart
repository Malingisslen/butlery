import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/admin/recipe_stats.dart';

/// Admin-only, read-only repository for the recipe-overview dashboard tab.
///
/// Counts recipes across all users via a `collectionGroup('recipes')` query and
/// classifies each by `core.sourceArtefact.type`. Admin-gated by
/// `firestore.rules` (collection-group recipes read = isAdmin).
///
/// COST: this fetches recipe documents and classifies them in Dart rather than
/// running per-type `count()` aggregates — that avoids needing a collection
/// group composite index on `core.sourceArtefact.type`. Trivial pre-launch
/// (~tens of recipes). When the user base grows this should move to per-type
/// `count()` aggregates (+ index) or a maintained counter doc; the [_maxScan]
/// cap + a log line keep the current cost bounded and visible.
///
/// Follows the lightweight admin-repo pattern (cf. [SiteConfigRepository]):
/// direct Firestore, no PermissionValidationMixin; read-only admin aggregate.
class RecipeStatsRepository {
  final FirebaseFirestore _firestore;

  /// Upper bound on recipes scanned per load (cost guard). If hit, the counts
  /// are a truncated sample and a warning is logged — never silently capped.
  static const int _maxScan = 5000;

  RecipeStatsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<RecipeStats> getRecipeStats() async {
    try {
      final snapshot = await _firestore
          .collectionGroup(FirestoreCollections.recipes)
          .limit(_maxScan)
          .get();

      final byMethod = <RecipeImportMethod, int>{};
      for (final doc in snapshot.docs) {
        final method = _classify(doc.data());
        byMethod[method] = (byMethod[method] ?? 0) + 1;
      }

      if (snapshot.docs.length >= _maxScan) {
        AppLogger.warning(
          'RecipeStatsRepository: hit scan cap of $_maxScan recipes — '
          'breakdown is a truncated sample',
        );
      }
      return RecipeStats(total: snapshot.docs.length, byMethod: byMethod);
    } catch (e) {
      AppLogger.warning(
        'RecipeStatsRepository: failed to load recipe stats: $e',
      );
      return const RecipeStats(total: 0, byMethod: {});
    }
  }

  /// Classify a recipe document by its `core.sourceArtefact.type`. Missing or
  /// unknown → [RecipeImportMethod.manual] (manual entry / pre-field recipes).
  /// Note: `collectionGroup('recipes')` matches every collection named
  /// `recipes` at any depth — today only the per-user subcollection.
  static RecipeImportMethod _classify(Map<String, dynamic> data) {
    final core = data['core'];
    final artefact = core is Map ? core['sourceArtefact'] : null;
    // Defensive at every level: a malformed doc must not throw — it counts as
    // manual rather than crashing the tab.
    final rawType = artefact is Map ? artefact['type'] : null;
    final type = rawType is String ? rawType : null;
    switch (type) {
      case 'url':
        return RecipeImportMethod.url;
      case 'photoOcr':
        return RecipeImportMethod.photo;
      case 'textPaste':
        return RecipeImportMethod.textPaste;
      case 'youtubeTranscript':
      case 'tiktokCaption':
      case 'instagramCaption':
        return RecipeImportMethod.social;
      default:
        return RecipeImportMethod.manual;
    }
  }
}
