import 'package:butlery/constants/known_ingredients.dart';
import 'package:butlery/core/cache/lru_map.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/tagging/config/compound_suffixes.dart';

/// Intelligent compound word splitter for Swedish ingredients.
///
/// Swedish forms compound words by concatenation, optionally with a genitive
/// linking 's'. This splitter finds the best base ingredient by trying all
/// split points and scoring candidates against a known ingredient vocabulary.
///
/// Strategies (tried in order of reliability):
/// 1. Genitive-s split: "nötköttsgryta" → "nötkött" + s + "gryta"
/// 2. Direct split: "tomatsås" → "tomat" + "sås"
/// 3. Suffix-list split: "hallonmarmelad" → "hallon" + "marmelad"
class CompoundSplitter {
  CompoundSplitter._();

  /// BUT-817: bounded via [LruMap]. Swedish ingredient vocabulary is small
  /// enough that 200 captures essentially all repeat lookups; eviction
  /// telemetry surfaces if the bound is too tight in practice.
  static const _maxCacheSize = 200;
  static final LruMap<String, String> _cache = LruMap(
    maxSize: _maxCacheSize,
    onEvict: (key, _) => AppLogger.info(
      'cache_eviction service=CompoundSplitter key=$key bound=$_maxCacheSize',
    ),
  );

  /// Suffix set built once from CompoundSuffixes for O(1) lookup
  static final Set<String> _suffixSet = {
    ...CompoundSuffixes.extendedEndings,
    ...CompoundSuffixes.primarySuffixes,
  };

  /// Stricter sub-floor than [_minWordLength] — both halves of a split
  /// must reach this length, blocking "ris" + "otto"-style false splits.
  static const _minComponentLength = 3;

  /// 6 = shortest length where Swedish compounds reliably decompose into
  /// two ≥3-char halves (e.g. "laxsås" = lax + sås). Lower → over-splits
  /// ("salt" → "sa"+"lt"); higher → "potatisgratäng" stays atomic. Tuned
  /// against [KnownIngredients]; re-run `compound_splitter_test.dart` if
  /// changed.
  static const _minWordLength = 6;

  /// Score bonus when the right part is a known ingredient or suffix
  static const _rightKnownBonus = 3.0;
  static const _rightSuffixBonus = 2.0;

  /// Penalty for genitive-s assumption (slight, since genitive is common)
  static const _genitivePenalty = 0.5;

  /// Try to extract the base ingredient from a compound word.
  ///
  /// Returns the base ingredient name if a confident split is found,
  /// or the original [word] if no valid split exists.
  ///
  /// [knownIngredients] is the combined set of static + Firestore ingredients.
  static String extractBase(String word, Set<String>? knownIngredients) {
    if (word.length < _minWordLength) return word;

    // Don't split protected compound names (vitpeppar, rödlök, etc.)
    if (KnownIngredients.isCompoundName(word)) return word;

    // Don't split words already known as ingredients
    if (KnownIngredients.isKnown(word)) return word;
    if (knownIngredients != null && knownIngredients.contains(word)) {
      return word;
    }

    final cached = _cache[word];
    if (cached != null) return cached;

    final result = _findBestSplit(word, knownIngredients);
    _cache[word] = result;
    return result;
  }

  /// Clear the cache (useful for testing)
  static void clearCache() => _cache.clear();

  static String _findBestSplit(String word, Set<String>? knownIngredients) {
    String bestBase = word;
    double bestScore = 0;

    final len = word.length;

    // Try every split point where both sides are at least _minComponentLength
    for (var i = _minComponentLength; i <= len - _minComponentLength; i++) {
      // Strategy 2: Direct split
      final left = word.substring(0, i);
      final right = word.substring(i);

      if (_isKnownIngredient(left, knownIngredients)) {
        final score = _scoreSplit(left, right, knownIngredients, 0);
        if (score > bestScore) {
          bestScore = score;
          bestBase = left;
        }
      }

      // Strategy 1: Genitive-s split — the 's' at position i-1 is a linking
      // morpheme, so the real left part ends at i-1
      if (i >= _minComponentLength + 1 && word[i - 1] == 's') {
        final leftGenitive = word.substring(0, i - 1);
        if (_isKnownIngredient(leftGenitive, knownIngredients)) {
          final score = _scoreSplit(
            leftGenitive,
            right,
            knownIngredients,
            _genitivePenalty,
          );
          if (score > bestScore) {
            bestScore = score;
            bestBase = leftGenitive;
          }
        }
      }
    }

    return bestBase;
  }

  /// Score a candidate split. Higher is better.
  /// Prefers longer base ingredients and recognizable right parts.
  static double _scoreSplit(
    String left,
    String right,
    Set<String>? knownIngredients,
    double penalty,
  ) {
    // Base score: length of left component (prefer longer, more specific bases)
    var score = left.length.toDouble() - penalty;

    // Bonus if right part is a known ingredient
    if (_isKnownIngredient(right, knownIngredients)) {
      score += _rightKnownBonus;
    }

    // Bonus if right part is a known compound suffix
    if (_suffixSet.contains(right)) {
      score += _rightSuffixBonus;
    }

    return score;
  }

  static bool _isKnownIngredient(String word, Set<String>? knownIngredients) {
    if (KnownIngredients.isKnown(word)) return true;
    if (knownIngredients != null && knownIngredients.contains(word)) {
      return true;
    }
    return false;
  }
}
