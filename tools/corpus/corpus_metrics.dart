/// Scoring functions for the cookbook gold corpus.
///
/// Pure Dart, deterministic, side-effect-free — the always-green core that
/// runs under `dart test`. Two families:
///   * [goldTokenRecall]  → OCR-eval (did the key facts survive bild→text?)
///   * [scoreRecipe]      → parser-eval (did text→struktur reconstruct them?)
library;

import 'corpus_models.dart';
import 'ingredient_core_name.dart';

/// Precision / recall / F1 for a set-style comparison.
class Prf {
  final double precision;
  final double recall;
  final double f1;
  final int matched;
  final int goldCount;
  final int predCount;

  const Prf({
    required this.precision,
    required this.recall,
    required this.f1,
    required this.matched,
    required this.goldCount,
    required this.predCount,
  });

  /// Builds a [Prf] from a match count and the two cardinalities. When both
  /// sides are empty the comparison is vacuously perfect (1.0) — there was
  /// nothing to get wrong.
  factory Prf.from({
    required int matched,
    required int goldCount,
    required int predCount,
  }) {
    if (goldCount == 0 && predCount == 0) {
      return const Prf(
        precision: 1,
        recall: 1,
        f1: 1,
        matched: 0,
        goldCount: 0,
        predCount: 0,
      );
    }
    final precision = predCount == 0 ? 0.0 : matched / predCount;
    final recall = goldCount == 0 ? 0.0 : matched / goldCount;
    final denom = precision + recall;
    final f1 = denom == 0 ? 0.0 : 2 * precision * recall / denom;
    return Prf(
      precision: precision,
      recall: recall,
      f1: f1,
      matched: matched,
      goldCount: goldCount,
      predCount: predCount,
    );
  }
}

/// Result of [goldTokenRecall]: fraction of salient gold tokens that appear in
/// the raw OCR text, plus the specific misses (so a low score is debuggable).
class TokenRecallResult {
  final double recall;
  final int foundCount;
  final int totalCount;
  final List<String> missing;

  const TokenRecallResult({
    required this.recall,
    required this.foundCount,
    required this.totalCount,
    required this.missing,
  });
}

/// Per-recipe parser score. Scalar fields are booleans; list fields are [Prf].
/// [ingredientNames] scores name-only recall (did we find the right items?);
/// [ingredientsFull] additionally requires matching quantity+unit (did we
/// parse the structure?). The gap between them localizes parser weakness.
/// Both compare the core name ([ingredientCoreName]). [ingredientDetails] scores
/// the words the core leaves out (preparation, alternative, size, asides); it is
/// null when the facit has none, so such a recipe does not count as perfect.
class RecipeScore {
  final bool titleMatch;
  final double titleSimilarity;
  final bool? portionsMatch;
  final bool? timeMatch;
  final Prf ingredientNames;
  final Prf ingredientsFull;
  final Prf instructions;
  final Prf? ingredientDetails;

  const RecipeScore({
    required this.titleMatch,
    required this.titleSimilarity,
    required this.portionsMatch,
    required this.timeMatch,
    required this.ingredientNames,
    required this.ingredientsFull,
    required this.instructions,
    this.ingredientDetails,
  });
}

/// Lowercase, strip punctuation/symbols (Unicode-aware so åäö survive),
/// collapse whitespace. The canonical form every comparison runs through.
String normalizeText(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Tokenize via [normalizeText]. Single-character tokens are dropped — they
/// are noise (stray OCR marks, list bullets) and inflate recall spuriously.
List<String> tokenize(String s) =>
    normalizeText(s).split(' ').where((t) => t.length > 1).toList();

const _unicodeFractions = {
  '½': '1/2',
  '¼': '1/4',
  '¾': '3/4',
  '⅓': '1/3',
  '⅔': '2/3',
  '⅛': '1/8',
};

/// "½" and "1/2", "1 ½" and "1½", "1–2" and "1-2" are the same amount; the
/// facit keeps whichever form the page printed, so comparing the strings
/// would count a correct read as a miss.
String _normalizeQuantity(String? q) {
  var out = (q ?? '').replaceAll(',', '.').replaceAll('–', '-');
  _unicodeFractions.forEach((glyph, ascii) {
    out = out.replaceAll(glyph, ' $ascii');
  });
  return out.replaceAll(RegExp(r'\s+'), '');
}

int _multisetMatch(Iterable<String> gold, Iterable<String> pred) {
  final counts = <String, int>{};
  for (final k in gold) {
    counts[k] = (counts[k] ?? 0) + 1;
  }
  var matched = 0;
  for (final k in pred) {
    final c = counts[k] ?? 0;
    if (c > 0) {
      counts[k] = c - 1;
      matched++;
    }
  }
  return matched;
}

/// Jaccard similarity over token sets — order-insensitive, length-tolerant.
/// Used for the fuzzy title score; 1.0 means identical token bags.
double tokenSetSimilarity(String a, String b) {
  final sa = tokenize(a).toSet();
  final sb = tokenize(b).toSet();
  if (sa.isEmpty && sb.isEmpty) return 1;
  if (sa.isEmpty || sb.isEmpty) return 0;
  final inter = sa.intersection(sb).length;
  final union = sa.union(sb).length;
  return inter / union;
}

/// OCR-eval. Salient gold tokens = title words + ingredient-name words +
/// normalized quantities. Returns the fraction present in [ocrText].
///
/// Deliberately NOT full character-error-rate: scoring the survival of the
/// facts that matter (names, amounts, title) needs no word-perfect page
/// transcription, which is the expensive part to hand-produce. Upgrade to CER
/// later only if this proves too coarse.
TokenRecallResult goldTokenRecall(GoldRecipe gold, String ocrText) {
  final ocrNorm = normalizeText(ocrText);
  final ocrTokens = ocrNorm.split(' ').where((t) => t.length > 1).toSet();
  // Quantities match on a separate digits-only track: OCR routinely glues
  // amount+unit ("1.5dl") and decimal separators get normalized away, so a
  // word-level comparison would always miss them. Collapsing both sides to
  // bare digits asks the question that matters — did the number survive?
  final ocrDigits = ocrText.replaceAll(RegExp(r'[^\d]'), '');

  final wordTokens = <String>{
    ...tokenize(gold.title),
    for (final ing in gold.ingredients) ...tokenize(ing.name),
  }..removeWhere((t) => t.isEmpty);

  final qtyTokens = <String>{
    for (final ing in gold.ingredients)
      if (ing.quantity != null && ing.quantity!.isNotEmpty)
        ing.quantity!.replaceAll(RegExp(r'[^\d]'), ''),
  }..removeWhere((t) => t.isEmpty);

  final total = wordTokens.length + qtyTokens.length;
  if (total == 0) {
    return const TokenRecallResult(
      recall: 1,
      foundCount: 0,
      totalCount: 0,
      missing: [],
    );
  }

  final missing = <String>[];
  var found = 0;

  for (final t in wordTokens) {
    if (ocrTokens.contains(t) || ocrNorm.contains(t)) {
      found++;
    } else {
      missing.add(t);
    }
  }

  for (final q in qtyTokens) {
    if (ocrDigits.contains(q)) {
      found++;
    } else {
      missing.add(q);
    }
  }

  return TokenRecallResult(
    recall: found / total,
    foundCount: found,
    totalCount: total,
    missing: missing,
  );
}

String _ingredientNameKey(GoldIngredient i) => ingredientCoreName(i.name);

String _ingredientFullKey(GoldIngredient i) =>
    '${ingredientCoreName(i.name)}|${_normalizeQuantity(i.quantity)}'
    '|${normalizeText(i.unit ?? '')}';

List<String> _detailTokens(GoldIngredient i) => ingredientDetailTokens(
  i.name,
  [i.name, i.size ?? '', i.preparation ?? ''].join(' '),
);

/// Pooled over the recipe, like the instructions: the facit and the parser put
/// the same words in different fields ("hackad" in the name or in the
/// preparation), so only whether the words came along is compared.
Prf? _ingredientDetailF1(GoldRecipe gold, GoldRecipe predicted) {
  final goldTokens = gold.ingredients.expand(_detailTokens).toList();
  if (goldTokens.isEmpty) return null;
  final predTokens = predicted.ingredients.expand(_detailTokens).toList();
  return Prf.from(
    matched: _multisetMatch(goldTokens, predTokens),
    goldCount: goldTokens.length,
    predCount: predTokens.length,
  );
}

/// Token-level F1 over ALL instruction text pooled together — segmentation-
/// invariant. A whole-string set match scores 0 when the parser splits steps
/// differently than the facit (e.g. 18 short fragments vs 5 merged paragraphs)
/// even though the words match; pooling tokens measures content capture instead
/// of paragraph boundaries. (Ingredients deliberately stay set-matched by item
/// — those ARE discrete, unlike arbitrarily-segmented prose steps.)
Prf instructionTokenF1(List<String> gold, List<String> pred) {
  final goldTokens = gold.expand(tokenize).toList();
  final predTokens = pred.expand(tokenize).toList();
  return Prf.from(
    matched: _multisetMatch(goldTokens, predTokens),
    goldCount: goldTokens.length,
    predCount: predTokens.length,
  );
}

/// Parser-eval. Compares predicted structure against the facit field-by-field.
RecipeScore scoreRecipe(GoldRecipe gold, GoldRecipe predicted) {
  final titleSim = tokenSetSimilarity(gold.title, predicted.title);

  bool? portions;
  if (gold.portions != null) {
    portions =
        normalizeText(gold.portions!) ==
        normalizeText(predicted.portions ?? '');
  }

  bool? time;
  if (gold.timeMinutes != null) {
    time = gold.timeMinutes == predicted.timeMinutes;
  }

  final nameF1 = Prf.from(
    matched: _multisetMatch(
      gold.ingredients.map(_ingredientNameKey),
      predicted.ingredients.map(_ingredientNameKey),
    ),
    goldCount: gold.ingredients.length,
    predCount: predicted.ingredients.length,
  );

  final fullF1 = Prf.from(
    matched: _multisetMatch(
      gold.ingredients.map(_ingredientFullKey),
      predicted.ingredients.map(_ingredientFullKey),
    ),
    goldCount: gold.ingredients.length,
    predCount: predicted.ingredients.length,
  );

  final instrF1 = instructionTokenF1(gold.instructions, predicted.instructions);

  return RecipeScore(
    titleMatch: titleSim >= 0.999,
    titleSimilarity: titleSim,
    portionsMatch: portions,
    timeMatch: time,
    ingredientNames: nameF1,
    ingredientsFull: fullF1,
    instructions: instrF1,
    ingredientDetails: _ingredientDetailF1(gold, predicted),
  );
}
