import 'package:butlery/constants/known_ingredients.dart';
import 'package:butlery/constants/preparation_words.dart';
import 'package:butlery/utils/text/unit_definitions.dart';

/// Extracts per-token features for CRF ingredient parsing.
///
/// Returns sparse feature vectors (`Map<String, double>`) for each token,
/// including context window features from neighboring tokens.
class CrfFeatureExtractor {
  static const _fractionChars = {'½', '¼', '¾', '⅓', '⅔', '⅛', '⅜', '⅝'};
  static final _digitPattern = RegExp(r'^[\d,.\-/]+$');
  static final _fractionPattern = RegExp(r'^\d+/\d+$');

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

    // Current token features
    _addTokenFeatures(features, lowered[index], '');

    // Boundary markers
    if (index == 0) features['BOS'] = 1.0;
    if (index == lowered.length - 1) features['EOS'] = 1.0;

    // Previous token features (window-1)
    if (index > 0) {
      _addTokenFeatures(features, lowered[index - 1], 'prev.');
    }

    // Next token features (window-1)
    if (index < lowered.length - 1) {
      _addTokenFeatures(features, lowered[index + 1], 'next.');
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
    features['${prefix}word.isFraction'] = _isFraction(lower) ? 1.0 : 0.0;
    features['${prefix}word.isUnit'] =
        UnitDefinitions.isKnownUnit(lower) ? 1.0 : 0.0;
    features['${prefix}word.isFood'] =
        KnownIngredients.isKnown(lower) ? 1.0 : 0.0;
    features['${prefix}word.isPrep'] =
        PreparationWords.isPreparationState(lower) ? 1.0 : 0.0;
    features['${prefix}word.isSize'] =
        PreparationWords.isSizeDescriptor(lower) ? 1.0 : 0.0;
    features['${prefix}word.hasComma'] = lower.contains(',') ? 1.0 : 0.0;

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

  bool _isDigit(String s) {
    return s.isNotEmpty && _digitPattern.hasMatch(s);
  }

  bool _isFraction(String s) {
    return _fractionChars.contains(s) || _fractionPattern.hasMatch(s);
  }
}
