import 'package:butlery/constants/known_ingredients.dart';
import 'package:butlery/constants/preparation_words.dart';
import 'package:butlery/utils/text/quantity_parser.dart';
import 'package:butlery/utils/text/swedish_compound_splitter.dart';
import 'package:butlery/utils/text/swedish_definite_normalizer.dart';
import 'package:butlery/utils/text/unit_definitions.dart';

/// Extracts per-token features for CRF ingredient parsing.
///
/// Returns sparse feature vectors (`Map<String, double>`) for each token,
/// including context window features from neighboring tokens.
///
/// Accepts an optional [enrichedIngredients] set from Firebase to supplement
/// the static [KnownIngredients] registry. When provided, food detection
/// checks both the static and enriched sets.
class CrfFeatureExtractor {
  static final _digitPattern = RegExp(r'^[\d,.\-/]+$');
  static final _rangePattern = RegExp(r'^\d+-\d+$');
  static final _parenPattern = RegExp(r'^[()]$');

  static const _conjunctions = {'eller', 'och', 'alternativt'};
  static const _optionalMarkers = {
    'ev',
    'ev.',
    'eventuellt',
    'gärna',
    'ca',
    'cirka',
    'valfritt',
    'drygt',
    'knappt',
    'lite',
  };

  /// Swedish number words that can appear as text quantities.
  static const _textQuantities = {
    'en',
    'ett',
    'två',
    'tre',
    'fyra',
    'fem',
    'sex',
    'sju',
    'åtta',
    'nio',
    'tio',
    'halv',
    'halva',
    'halvt',
  };

  /// Purpose clause marker — "till stekning", "till garnering" etc.
  static const _purposeMarker = 'till';

  /// Optional enriched ingredient set from Firebase/Firestore.
  /// When provided, supplements the static KnownIngredients for food detection.
  final Set<String>? _enrichedIngredients;

  CrfFeatureExtractor({Set<String>? enrichedIngredients})
      : _enrichedIngredients = enrichedIngredients;

  /// Checks if a token is a known food ingredient.
  /// Uses enriched Firebase ingredients when available, falls back to static.
  bool _isFood(String lower) {
    if (KnownIngredients.isKnown(lower)) return true;
    return _enrichedIngredients?.contains(lower) ?? false;
  }

  /// Extracts features for all tokens in a sequence.
  ///
  /// Pre-lowercases tokens once to avoid repeated toLowerCase calls.
  List<Map<String, double>> extractAll(List<String> tokens) {
    final lowered = tokens.map((t) => t.toLowerCase()).toList();
    return List.generate(
      lowered.length,
      (i) => _extractAtLowered(lowered, i),
    );
  }

  /// Extracts features for the token at position [index].
  Map<String, double> extractAt(List<String> tokens, int index) {
    final lowered = tokens.map((t) => t.toLowerCase()).toList();
    return _extractAtLowered(lowered, index);
  }

  Map<String, double> _extractAtLowered(List<String> lowered, int index) {
    final features = <String, double>{};

    // Current token features (full set)
    _addTokenFeatures(features, lowered[index], '');

    // Boundary markers
    if (index == 0) features['BOS'] = 1.0;
    if (index == lowered.length - 1) features['EOS'] = 1.0;

    // Window-1 context (full feature set)
    if (index > 0) {
      _addTokenFeatures(features, lowered[index - 1], 'prev.');
    }
    if (index < lowered.length - 1) {
      _addTokenFeatures(features, lowered[index + 1], 'next.');
    }

    // Bigram features (captures word transitions)
    final current = lowered[index];
    if (index > 0) {
      features['bigram.prev=${lowered[index - 1]}|cur=$current'] = 1.0;
    }
    if (index < lowered.length - 1) {
      features['bigram.cur=$current|next=${lowered[index + 1]}'] = 1.0;
    }

    // Type-level bigram features (more generalizable than word-level)
    if (index > 0) {
      final prevType = _tokenType(lowered[index - 1]);
      final curType = _tokenType(current);
      features['typeBigram.prev=$prevType|cur=$curType'] = 1.0;
    }
    if (index < lowered.length - 1) {
      final curType = _tokenType(current);
      final nextType = _tokenType(lowered[index + 1]);
      features['typeBigram.cur=$curType|next=$nextType'] = 1.0;
    }

    // Window-2 context (reduced feature set for efficiency)
    if (index > 1) {
      _addReducedFeatures(features, lowered[index - 2], 'prev2.');
    }
    if (index < lowered.length - 2) {
      _addReducedFeatures(features, lowered[index + 2], 'next2.');
    }

    return features;
  }

  void _addTokenFeatures(
    Map<String, double> features,
    String lower,
    String prefix,
  ) {
    features['${prefix}word.lower=$lower'] = 1.0;
    features['${prefix}word.isDigit'] = _isDigit(lower) ? 1.0 : 0.0;
    features['${prefix}word.isFraction'] =
        QuantityParser.isFraction(lower) ? 1.0 : 0.0;
    features['${prefix}word.isUnit'] =
        UnitDefinitions.isKnownUnit(lower) ? 1.0 : 0.0;
    features['${prefix}word.isFood'] = _isFood(lower) ? 1.0 : 0.0;
    features['${prefix}word.isPrep'] =
        PreparationWords.isPreparationState(lower) ? 1.0 : 0.0;
    features['${prefix}word.isSize'] =
        PreparationWords.isSizeDescriptor(lower) ? 1.0 : 0.0;
    features['${prefix}word.hasComma'] = lower.contains(',') ? 1.0 : 0.0;

    // Edge case features
    features['${prefix}word.isRange'] = _isRange(lower) ? 1.0 : 0.0;
    features['${prefix}word.isConjunction'] =
        _conjunctions.contains(lower) ? 1.0 : 0.0;
    features['${prefix}word.isOptional'] =
        _optionalMarkers.contains(lower) ? 1.0 : 0.0;
    features['${prefix}word.isGroupHeader'] = _isGroupHeader(lower) ? 1.0 : 0.0;
    features['${prefix}word.isParen'] =
        _parenPattern.hasMatch(lower) ? 1.0 : 0.0;
    features['${prefix}word.isTextQty'] =
        _textQuantities.contains(lower) ? 1.0 : 0.0;
    features['${prefix}word.isPurpose'] = lower == _purposeMarker ? 1.0 : 0.0;

    // Compound word detection
    final compoundSplit = SwedishCompoundSplitter.trySplit(lower);
    features['${prefix}word.isCompound'] = compoundSplit != null ? 1.0 : 0.0;
    if (compoundSplit != null) {
      features['${prefix}word.compoundSuffix=${compoundSplit.$2}'] = 1.0;
    }

    // Definite form detection (löken → lök)
    final baseForm = SwedishDefiniteNormalizer.tryNormalize(lower);
    features['${prefix}word.isDefinite'] = baseForm != null ? 1.0 : 0.0;
    if (baseForm != null) {
      features['${prefix}word.baseForm=$baseForm'] = 1.0;
    }

    // Length feature (normalized)
    features['${prefix}word.len'] = lower.length / 20.0;

    // Suffix features
    if (lower.length >= 2) {
      features['${prefix}word.suffix2=${lower.substring(lower.length - 2)}'] =
          1.0;
    }
    if (lower.length >= 3) {
      features['${prefix}word.suffix3=${lower.substring(lower.length - 3)}'] =
          1.0;
    }

    // Prefix features (helps distinguish units like "dl" and preps like "de")
    if (lower.length >= 2) {
      features['${prefix}word.prefix2=${lower.substring(0, 2)}'] = 1.0;
    }
  }

  /// Reduced feature set for window-2 context (only most discriminative).
  void _addReducedFeatures(
    Map<String, double> features,
    String lower,
    String prefix,
  ) {
    features['${prefix}word.isDigit'] = _isDigit(lower) ? 1.0 : 0.0;
    features['${prefix}word.isUnit'] =
        UnitDefinitions.isKnownUnit(lower) ? 1.0 : 0.0;
    features['${prefix}word.isFood'] = _isFood(lower) ? 1.0 : 0.0;
    features['${prefix}word.isPrep'] =
        PreparationWords.isPreparationState(lower) ? 1.0 : 0.0;
  }

  bool _isDigit(String s) {
    return s.isNotEmpty && _digitPattern.hasMatch(s);
  }

  bool _isRange(String s) {
    return s.isNotEmpty && _rangePattern.hasMatch(s);
  }

  bool _isGroupHeader(String s) {
    return s.endsWith(':') && s.length > 1 && s.length < 40;
  }

  /// Classifies a token into a coarse type for type-level bigram features.
  String _tokenType(String lower) {
    if (_isDigit(lower) || QuantityParser.isFraction(lower)) return 'NUM';
    if (_textQuantities.contains(lower)) return 'NUM';
    if (UnitDefinitions.isKnownUnit(lower)) return 'UNIT';
    if (_isFood(lower)) return 'FOOD';
    if (SwedishDefiniteNormalizer.isDefiniteForm(lower)) return 'FOOD';
    if (PreparationWords.isPreparationState(lower)) return 'PREP';
    if (PreparationWords.isSizeDescriptor(lower)) return 'SIZE';
    if (_conjunctions.contains(lower)) return 'CONJ';
    if (_optionalMarkers.contains(lower)) return 'OPT';
    if (lower == _purposeMarker) return 'PURPOSE';
    if (_parenPattern.hasMatch(lower)) return 'PAREN';
    if (_isGroupHeader(lower)) return 'HEADER';
    return 'WORD';
  }
}
