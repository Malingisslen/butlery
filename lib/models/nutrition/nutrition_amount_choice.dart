/// An amount the household entered for an ingredient whose recipe line gave
/// none the app could weigh (BUT-643 follow-up).
class NutritionAmountChoice {
  final double amount;
  final String unit;

  const NutritionAmountChoice({required this.amount, required this.unit});

  /// Units `firestore.rules` accepts.
  static const List<String> allowedUnits = [
    'g',
    'kg',
    'ml',
    'dl',
    'l',
    'msk',
    'tsk',
    'krm',
    'st',
  ];

  static const double maxAmount = 100000;

  /// `firestore.rules` refuses a map with more entries than this.
  static const int maxEntries = 300;

  /// Mirrors the rules' key shapes: an ingredient key for every recipe, or
  /// `r_<recipeId>_<ingredient key>` for one recipe. A recipe id is a UUID or
  /// a Firestore id, so upper case and hyphens are allowed in that part only.
  static final RegExp keyShape = RegExp(
    r'^(?:[a-zåäö0-9_]{1,60}|r_[A-Za-z0-9-]{1,40}_[a-zåäö0-9_]{1,60})$',
  );

  static final RegExp _recipeIdShape = RegExp(r'^[A-Za-z0-9-]{1,40}$');

  /// Null when the id or the ingredient key would not pass the rules. The key
  /// shape alone cannot tell: a lower-case recipe-looking string also fits the
  /// plain ingredient shape.
  static String? recipeKey(String recipeId, String ingredientKey) {
    if (!_recipeIdShape.hasMatch(recipeId)) return null;
    final key = 'r_${recipeId}_$ingredientKey';
    return keyShape.hasMatch(key) ? key : null;
  }

  bool get isValid =>
      amount > 0 && amount <= maxAmount && allowedUnits.contains(unit);

  Map<String, dynamic> toMap() => {'a': amount, 'u': unit};

  /// Null for anything the rules would not have let through.
  static NutritionAmountChoice? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final amount = raw['a'];
    final unit = raw['u'];
    if (amount is! num || unit is! String) return null;
    final choice = NutritionAmountChoice(
      amount: amount.toDouble(),
      unit: unit,
    );
    return choice.isValid ? choice : null;
  }

  @override
  bool operator ==(Object other) =>
      other is NutritionAmountChoice &&
      other.amount == amount &&
      other.unit == unit;

  @override
  int get hashCode => Object.hash(amount, unit);
}

/// The household already holds [NutritionAmountChoice.maxEntries] amounts.
class NutritionAmountChoicesFullException implements Exception {
  const NutritionAmountChoicesFullException();

  @override
  String toString() => 'NutritionAmountChoicesFullException';
}
