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

// Dart's \b is ASCII-only, so the unit is closed with a lookahead instead.
final _quantityPattern = RegExp(
  '^\\s*((?:\\d+(?:[.,/]\\d+)?|[½¼¾⅓⅔])'
  '(?:\\s*[-–]\\s*\\d+(?:[.,/]\\d+)?)?'
  '(?:\\s+(?:$_units)\\.?(?=\\s|\$))?)'
  '\\s+(\\S.*)\$',
  caseSensitive: false,
);

IngredientQuantitySplit splitIngredientQuantity(String text) {
  final match = _quantityPattern.firstMatch(text);
  if (match == null) return IngredientQuantitySplit(quantity: '', name: text);
  return IngredientQuantitySplit(
    quantity: match.group(1)!.trim(),
    name: match.group(2)!.trim(),
  );
}
