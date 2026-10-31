import 'package:butlery/utils/text/quantity_parser.dart';
import 'package:butlery/utils/text/text_formatting.dart';

/// An ingredient line cut into the amount ("400 g") and the rest ("pasta"),
/// so cooking mode can set the amount in its own bold column.
class IngredientQuantitySplit {
  const IngredientQuantitySplit({required this.quantity, required this.name});

  final String quantity;
  final String name;
}

const _units =
    'kg|hg|g|mg|l|dl|cl|ml|msk|tsk|krm|st|port|portioner|paket|förp|burk|'
    'burkar|klyfta|klyftor|nypa|skiva|skivor|knippe|kvist|kvistar';

const _fractionGlyphs = '½¼¾⅓⅔';

// Dart's \b is ASCII-only, so the unit is closed with a lookahead instead.
// The mixed forms ("1 1/2", "2 ½") come first: alternation takes the first
// branch that matches and a bare "1" would leave "1/2" in the name.
final _quantityPattern = RegExp(
  '^\\s*(\\d+\\s+\\d+/\\d+|\\d+\\s*[$_fractionGlyphs]|'
  '\\d+(?:[.,/]\\d+)?|[$_fractionGlyphs])'
  '((?:\\s*[-–]\\s*\\d+(?:[.,/]\\d+)?)?'
  '(?:\\s+(?:$_units)\\.?(?=\\s|\$))?)'
  '\\s+(\\S.*)\$',
  caseSensitive: false,
);

// ASCII fractions are shown as the recipe page shows them (¾), reusing its
// parser and formatter; decimals, ranges and glyphs stay as written.
String _displayNumber(String number) {
  final value = QuantityParser.parseAsciiFraction(number);
  return value == null
      ? number.trim()
      : TextFormatting.toSwedishHalfFraction(value);
}

IngredientQuantitySplit splitIngredientQuantity(String text) {
  final match = _quantityPattern.firstMatch(text);
  if (match == null) return IngredientQuantitySplit(quantity: '', name: text);
  return IngredientQuantitySplit(
    quantity: '${_displayNumber(match.group(1)!)}${match.group(2)!}'.trim(),
    name: match.group(3)!.trim(),
  );
}
