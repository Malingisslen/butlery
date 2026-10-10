/// The nutrients the app shows, in the units Livsmedelsverket publishes:
/// kcal for energy, grams for the rest.
class NutrientValues {
  final double kcal;
  final double fat;
  final double satFat;
  final double carbs;
  final double sugar;
  final double fiber;
  final double protein;
  final double salt;

  const NutrientValues({
    this.kcal = 0,
    this.fat = 0,
    this.satFat = 0,
    this.carbs = 0,
    this.sugar = 0,
    this.fiber = 0,
    this.protein = 0,
    this.salt = 0,
  });

  static const zero = NutrientValues();

  /// A food row from the bundled table; a nutrient the table lacks reads as 0.
  factory NutrientValues.fromJson(Map<String, dynamic> json) {
    double read(String key) => (json[key] as num?)?.toDouble() ?? 0;
    return NutrientValues(
      kcal: read('kcal'),
      fat: read('fat'),
      satFat: read('satFat'),
      carbs: read('carbs'),
      sugar: read('sugar'),
      fiber: read('fiber'),
      protein: read('protein'),
      salt: read('salt'),
    );
  }

  NutrientValues operator +(NutrientValues other) => NutrientValues(
    kcal: kcal + other.kcal,
    fat: fat + other.fat,
    satFat: satFat + other.satFat,
    carbs: carbs + other.carbs,
    sugar: sugar + other.sugar,
    fiber: fiber + other.fiber,
    protein: protein + other.protein,
    salt: salt + other.salt,
  );

  NutrientValues scale(double factor) => NutrientValues(
    kcal: kcal * factor,
    fat: fat * factor,
    satFat: satFat * factor,
    carbs: carbs * factor,
    sugar: sugar * factor,
    fiber: fiber * factor,
    protein: protein * factor,
    salt: salt * factor,
  );
}
