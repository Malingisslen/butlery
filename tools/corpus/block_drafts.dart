/// A page whose `recipe-NN/` blocks hold a `gold.json` already has its cut
/// decided; the parser's own split must not be laid over it.
library;

import 'dart:io';

import 'corpus_metrics.dart';
import 'corpus_models.dart';

/// Ids of `recipe-NN` dirs under [pageDir] that carry a gold, in numeric order.
List<String> goldBlocks(Directory pageDir) {
  if (!pageDir.existsSync()) return const [];
  final ids = <String>[];
  for (final d in pageDir.listSync().whereType<Directory>()) {
    final id = d.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
    if (!RegExp(r'^recipe-\d+$').hasMatch(id)) continue;
    if (!File('${d.path}/gold.json').existsSync()) continue;
    ids.add(id);
  }
  ids.sort(
    (a, b) => int.parse(a.substring(7)).compareTo(int.parse(b.substring(7))),
  );
  return ids;
}

/// Pairs each block with the parser's draft at the same position — but only
/// when the parser found exactly as many recipes as the human cut. A count
/// mismatch means the cuts differ, and an index pairing would score a block
/// against another recipe's prediction, so nothing is assigned.
Map<String, GoldRecipe> pairBlocksWithDrafts(
  List<String> blockIds,
  List<GoldRecipe> drafts,
) {
  if (blockIds.isEmpty || blockIds.length != drafts.length) return const {};
  return {for (var i = 0; i < blockIds.length; i++) blockIds[i]: drafts[i]};
}

/// How much of the same text two recipes hold: Jaccard over their word sets
/// (title, ingredient lines, steps). Deliberately blind to structure — the
/// question is "is this the same recipe", not "was it parsed well", and the
/// F1 scores would answer the second one with zero for any wrong-named draft.
double contentSimilarity(GoldRecipe a, GoldRecipe b) {
  Set<String> words(GoldRecipe r) => {
    ...tokenize(r.title),
    for (final i in r.ingredients) ...tokenize(i.originalLine),
    for (final s in r.instructions) ...tokenize(s),
  };
  final wa = words(a);
  final wb = words(b);
  if (wa.isEmpty || wb.isEmpty) return 0;
  return wa.intersection(wb).length / wa.union(wb).length;
}

/// A draft chosen for a gold entry, with how alike the two are.
class DraftMatch {
  final int draftIndex;
  final double similarity;
  const DraftMatch(this.draftIndex, this.similarity);
}

/// Assigns the parser's drafts to the gold entries of one page by content,
/// one draft per gold at most, best pairs first. A gold left out is a recipe
/// the parser did not produce — the eval counts it as missed instead of
/// scoring it against some other recipe's draft. [floor] is the least
/// similarity that still counts as the same recipe.
Map<int, DraftMatch> assignDraftsToGolds(
  List<GoldRecipe> golds,
  List<GoldRecipe> drafts, {
  double floor = defaultMatchFloor,
}) {
  // A draft with neither ingredients nor steps is the harness's title-only
  // fallback for a page the parser could not read, not a parsed recipe.
  final pairs = <(int, int, double)>[
    for (var g = 0; g < golds.length; g++)
      for (var d = 0; d < drafts.length; d++)
        if (drafts[d].ingredients.isNotEmpty ||
            drafts[d].instructions.isNotEmpty)
          (g, d, contentSimilarity(golds[g], drafts[d])),
  ]..sort((x, y) => y.$3.compareTo(x.$3));
  final result = <int, DraftMatch>{};
  final usedDrafts = <int>{};
  for (final (g, d, sim) in pairs) {
    if (sim < floor) break;
    if (result.containsKey(g) || usedDrafts.contains(d)) continue;
    result[g] = DraftMatch(d, sim);
    usedDrafts.add(d);
  }
  return result;
}

const defaultMatchFloor = 0.2;
