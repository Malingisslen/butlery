import 'package:flutter/widgets.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/services/nutrition/nutrient_values.dart';
import 'package:butlery/viewmodels/nutrition_viewmodel.dart';

/// Number formatting for nutrition values: whole kcal, grams with one
/// decimal under 10 and whole numbers from 10, decimal comma in Swedish.
class NutritionFormat {
  const NutritionFormat._();

  static String number(
    BuildContext context,
    double value, {
    bool kcal = false,
  }) {
    final tenths = (value * 10).round() / 10;
    final text = kcal || tenths >= 10
        ? value.round().toString()
        : tenths.toStringAsFixed(1);
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';
    return isEnglish ? text : text.replaceAll('.', ',');
  }

  static String basisPhrase(BuildContext context, NutritionBasis basis) =>
      basis == NutritionBasis.perPortion
      ? context.l10n.nutritionBasisPhrasePerPortion
      : context.l10n.nutritionBasisPhraseWhole;

  static String spokenKcal(BuildContext context, NutrientValues v) =>
      context.l10n.a11yNutritionSpokenKcal(number(context, v.kcal, kcal: true));

  static String spokenGrams(BuildContext context, double grams) =>
      context.l10n.a11yNutritionSpokenGrams(number(context, grams));
}
