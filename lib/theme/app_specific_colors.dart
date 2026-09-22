/// APPSPECIFIKA dekorfärger.
///
/// Designsystemet definierar med avsikt ingen kategorisk färgskala:
/// `tokens.json` har `dataScale.categorical = null`, och produktreglerna
/// § 8.3b säger att **kategorin bärs av namnet och att färgrutan är dekor**.
///
/// Därför är de här fyra färgerna appens egna. De är inte designtokens, de
/// får inte växa till en andra palett, och varje tillägg kräver samma
/// positiva produktbelägg som dessa fyra har.

import 'package:flutter/material.dart';

/// De enda färgvärden appen äger själv.
class AppSpecificColors {
  AppSpecificColors._();

  /// Kategorifärg för dryck. Dekor, aldrig informationsbärare.
  static const Color categoryDrinks = Color(0xFF5B8FA8);
  static const Color categoryDrinksDark = Color(0xFF82B5CC);

  /// Kategorifärg för städ. Dekor, aldrig informationsbärare.
  static const Color categoryCleaning = Color(0xFF5A9C8F);
  static const Color categoryCleaningDark = Color(0xFF7ABCAF);

  /// Kategorifärg för snacks. Dekor, aldrig informationsbärare.
  static const Color categorySnacks = Color(0xFFD4903C);
  static const Color categorySnacksDark = Color(0xFFE8B56E);

  /// Kategorifärg för konserv. Dekor, aldrig informationsbärare.
  static const Color categoryCanned = Color(0xFF8B7355);
  static const Color categoryCannedDark = Color(0xFFB09878);

  /// Varje appspecifik färg, för kontroller som räknar dem.
  static const Map<String, Color> light = <String, Color>{
    'categoryDrinks': categoryDrinks,
    'categoryCleaning': categoryCleaning,
    'categorySnacks': categorySnacks,
    'categoryCanned': categoryCanned,
  };
  static const Map<String, Color> dark = <String, Color>{
    'categoryDrinks': categoryDrinksDark,
    'categoryCleaning': categoryCleaningDark,
    'categorySnacks': categorySnacksDark,
    'categoryCanned': categoryCannedDark,
  };
}
