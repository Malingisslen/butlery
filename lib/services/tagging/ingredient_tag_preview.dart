import 'package:butlery/models/tagging/firebase_tag_config.dart';

/// What the tagger would conclude from one ingredient's properties alone.
class IngredientTagPreview {
  /// Allergen keys in config display order.
  final List<String> allergenKeys;

  /// Diet keys (config display order) that the properties break.
  final List<String> brokenDietKeys;

  const IngredientTagPreview({
    required this.allergenKeys,
    required this.brokenDietKeys,
  });
}

/// Mirrors the rules in `Phase1AllergenCalculator` / `Phase1DietaryCalculator`
/// for a single ingredient, so the admin view never shows a different answer
/// than the tagger gives. A diet is broken by
/// an excluded property; required properties only widen what is allowed and
/// never break a diet by themselves.
IngredientTagPreview previewIngredientTags(
  Set<String> properties,
  FirebaseTagConfig config,
) {
  final allergens = <String>[];
  for (final entry in config.allergens.enabledEntries) {
    final triggers = entry.triggerProperties;
    if (triggers.isEmpty) continue;
    final fires = entry.isCombined
        ? triggers.any(properties.contains)
        : properties.contains(triggers.first);
    if (fires) allergens.add(entry.key);
  }

  final broken = <String>[
    for (final diet in config.dietary.enabledEntries)
      if (diet.excludedProperties.any(properties.contains)) diet.key,
  ];

  return IngredientTagPreview(allergenKeys: allergens, brokenDietKeys: broken);
}
