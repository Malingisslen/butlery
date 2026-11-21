/// A page whose `recipe-NN/` blocks hold a `gold.json` already has its cut
/// decided; the parser's own split must not be laid over it.
library;

import 'dart:io';

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
