import 'package:butlery/constants/known_ingredients.dart';
import 'package:butlery/constants/preparation_words.dart';
import 'package:butlery/utils/text/quantity_parser.dart';
import 'package:butlery/utils/text/swedish_compound_splitter.dart';
import 'package:butlery/utils/text/unit_definitions.dart';

/// Extracts per-token features for CRF ingredient parsing.
///
/// Returns sparse feature vectors (`Map<String, double>`) for each token,
/// including context window features from neighboring tokens.
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
    features['${prefix}word.isFood'] =
        KnownIngredients.isKnown(lower) ? 1.0 : 0.0;
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

    // Compound word detection
    final compoundSplit = SwedishCompoundSplitter.trySplit(lower);
    features['${prefix}word.isCompound'] = compoundSplit != null ? 1.0 : 0.0;
    if (compoundSplit != null) {
      features['${prefix}word.compoundSuffix=${compoundSplit.$2}'] = 1.0;
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
    features['${prefix}word.isFood'] =
        KnownIngredients.isKnown(lower) ? 1.0 : 0.0;
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
    return s.endsWith(':') && s.length > 1;
  }
}
