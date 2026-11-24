import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/user_allergen_preferences.dart';

/// The localized name of an allergen key (`mjölk` → "Mjölk" / "Milk"), shared
/// by onboarding and the shopping-list reminder so the two cannot name the
/// same allergen differently.
String allergenLabel(AppLocalizations l10n, String key) => switch (key) {
  'gluten' => l10n.onboardingAllergenGluten,
  'mjölk' => l10n.onboardingAllergenMilk,
  'nötter' => l10n.onboardingAllergenNuts,
  'ägg' => l10n.onboardingAllergenEgg,
  'soja' => l10n.onboardingAllergenSoy,
  'fisk' => l10n.onboardingAllergenFish,
  'skaldjur' => l10n.onboardingAllergenShellfish,
  'sesam' => l10n.onboardingAllergenSesame,
  'laktos' => l10n.onboardingAllergenLactose,
  'selleri' => l10n.onboardingAllergenCelery,
  'senap' => l10n.onboardingAllergenMustard,
  'lupin' => l10n.onboardingAllergenLupin,
  'sulfiter' => l10n.onboardingAllergenSulfite,
  'jordnötter' => l10n.onboardingAllergenPeanut,
  'trädnötter' => l10n.onboardingAllergenTreeNut,
  'kräftdjur' => l10n.onboardingAllergenCrustacean,
  'blötdjur' => l10n.onboardingAllergenMollusc,
  _ => AllergenPreferenceOptions.getAllergenLabel(key),
};
