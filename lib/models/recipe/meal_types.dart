/// BUT-1875: the one meal-type vocabulary. A recipe's `mealType` is one of
/// [all] or, for a recipe saved before this or from free text, whatever it
/// was given; [normalize] turns a known synonym into the app's spelling.
class MealTypes {
  MealTypes._();

  static const frukost = 'Frukost';
  static const lunch = 'Lunch';
  static const middag = 'Middag';
  static const dessert = 'Dessert';
  static const mellanmal = 'Mellanmål';
  static const fika = 'Fika';

  /// The meal types the app offers, in the order it offers them.
  static const List<String> all = [
    frukost,
    lunch,
    middag,
    dessert,
    mellanmal,
    fika,
  ];

  // Mirrored in functions/scripts/migrate-meal-type.js, which rewrites stored
  // values; its test fails when the two differ.
  static const _synonyms = {
    'frukost': frukost,
    'breakfast': frukost,
    'lunch': lunch,
    'middag': middag,
    'dinner': middag,
    'huvudrätt': middag,
    'huvudrätter': middag,
    'main course': middag,
    'main dish': middag,
    'dessert': dessert,
    'desserts': dessert,
    'desserter': dessert,
    'efterrätt': dessert,
    'efterrätter': dessert,
    'mellanmål': mellanmal,
    'mellanmal': mellanmal,
    'snack': mellanmal,
    'snacks': mellanmal,
    'fika': fika,
  };

  /// The app's spelling of [raw] when it names a meal type, ignoring case
  /// and surrounding or repeated spaces; null otherwise.
  static String? match(String raw) =>
      _synonyms[raw.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase()];

  /// [raw] in the app's spelling when it names a meal type, else unchanged.
  static String normalize(String raw) => match(raw) ?? raw;
}
