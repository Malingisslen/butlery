import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/utils/text/ingredient_normalizer.dart';
import 'package:butlery/utils/text/ingredient_parser.dart';

abstract final class IngredientLineParts {
  /// The ingredient names in one raw line, each as parsed and as normalized:
  /// "2 dl mjölk" is "mjölk", "salt och peppar" is two names, and the parsed
  /// name keeps words the normalizer drops ("rökt lax" normalizes to "lax").
  static List<({String parsed, String normalized})> of(
    String raw, {
    Set<String>? additionalKnown,
  }) {
    // M2: Parse raw ingredient to extract name (strips quantity and unit)
    // BUT-1496: parse och-conjunctions ("salt och peppar") into separate
    // ingredients — the compound parser existed but was never used here, so
    // conjunction lines stayed one unmatchable blob.
    // LOW-2: Wrap parsing in try-catch to prevent failures from bad input
    List<String> namesToNormalize;
    try {
      final parsedParts = IngredientParser.parseCompoundIngredient(raw);
      namesToNormalize = [
        for (final parsed in parsedParts)
          if (parsed.name.isNotEmpty) parsed.name,
      ];
      if (namesToNormalize.isEmpty) namesToNormalize = [raw];
    } catch (e) {
      AppLogger.warning(
        'LOW-2: Failed to parse ingredient "$raw": $e, using raw string',
      );
      namesToNormalize = [raw];
    }
    return [
      for (final name in namesToNormalize)
        (
          parsed: name,
          normalized: IngredientNormalizer.normalize(
            name,
            additionalKnown: additionalKnown,
          ).normalized,
        ),
    ].where((part) => part.normalized.isNotEmpty).toList();
  }
}
