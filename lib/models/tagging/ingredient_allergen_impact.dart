import 'package:butlery/services/tagging/config/allergen_config.dart';

/// Properties whose change can flip an allergen or diet verdict. Built from the
/// tagger's own allergen triggers so a new allergen cannot be missed here; the
/// two umbrella properties are not triggers but feed the same verdicts. A drift
/// test pins this set against `ALLERGEN_RELEVANT_PROPERTIES` in the functions.
final Set<String> kAllergenRelevantProperties = Set.unmodifiable({
  for (final entry in AllergenConfig.all) ...entry.triggerProperties,
  'shellfish',
  'seafood',
});

const Set<String> _veganClaims = {'vegan-friendly', 'plant-based'};

const Set<String> _animalProperties = {
  'animal-product',
  'meat',
  'dairy',
  'egg',
  'seafood',
};

/// Whether moving a row from [oldProperties] to [newProperties] touches
/// allergen safety: an allergen-relevant property is removed, or a vegan claim
/// is added to a row that still carries an animal or allergen property.
bool propertyChangeAffectsAllergens(
  Iterable<String> oldProperties,
  Iterable<String> newProperties,
) {
  final before = oldProperties.toSet();
  final after = newProperties.toSet();
  if (before.difference(after).any(kAllergenRelevantProperties.contains)) {
    return true;
  }
  final addedClaim = after.difference(before).any(_veganClaims.contains);
  return addedClaim &&
      after.any(
        (p) =>
            _animalProperties.contains(p) ||
            kAllergenRelevantProperties.contains(p),
      );
}
