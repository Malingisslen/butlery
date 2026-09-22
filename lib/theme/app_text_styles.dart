// GENERERAD FIL — ändra källan, inte den här.
// system 2.1 · tokens 1.13
// generator tools/gen-app-theme.mjs v2.3
// källfingeravtryck sha256:cf6a27d42dd668eb9e6c7eeba8e564180ce9bfdcbbc4411012b4c33715627ec1 (6 indatafiler, generatorns källa inräknad)
// genererad ur källdatum 2026-08-05 (tokens.date — reproducerbart, inte klockan)
//
// Migration (etapp 8.2): samma medlemsnamn som i det frysta kontraktet, värden ur
// tokens.json → typography.roles. Tre ändringar som INTE är kosmetiska:
//
//  1. **En familj, inte två.** Josefin Sans (rubrik) och Space Grotesk (brödtext)
//     ersätts av Butlery Sans. Den plattformsberoende gaffeln — iOS fick
//     `null` och därmed San Francisco — är borta: appen såg olika ut på iOS
//     och Android, vilket ingen bad om.
//  2. **10 px utgår.** Systemets regel: ingen 400-vikt under 12 px, och 10,5 px
//     endast i 700. `textXs`, `badge` och `navLabel` följer nu overline/navLabel.
//  3. **44 px finns inte.** `mainViewTitle` bar 44 px utan token; närmaste
//     avsedda roll är display (32/700). Skalan slutar där med flit.
import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  /// En familj för allt. Namnen headerFont/bodyFont behålls för anropande kod.
  static const String family = 'ButlerySans';
  static const String headerFont = family;
  static const String bodyFont = family;

  /// tokens: typography.roles.display.compact — 26/700
  static TextStyle get displaySmall => const TextStyle(
    fontFamily: family,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.3,
  );

  /// tokens: typography.roles.display.compact — 26/700
  static TextStyle get headlineMedium => const TextStyle(
    fontFamily: family,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.3,
  );

  /// tokens: typography.roles.title — 22/700
  static TextStyle get headlineSmall => const TextStyle(
    fontFamily: family,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.3,
  );

  /// tokens: typography.roles.display — 32/700
  static TextStyle get headlineBold => const TextStyle(
    fontFamily: family,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -1,
    height: 1.3,
  );

  /// tokens: typography.roles.stepper — 17/600
  static TextStyle get titleLarge => const TextStyle(
    fontFamily: family,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  /// tokens: typography.roles.cardTitle — 15/600
  static TextStyle get titleMedium => const TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  /// tokens: typography.roles.body — 16/400
  static TextStyle get bodyLarge => const TextStyle(
    fontFamily: family,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// tokens: typography.roles.bodyMedium — 14/400 · appens vanligaste brödtext — 14/400. Fas 1 (tredje vändan): värdet låg som derivedStyles i tools/app-theme-map.json, dessförinnan som ett dolt medelvärde i generatorn. Steget 14 finns i skalan; ingen 400-vikt under 12 px.
  static TextStyle get bodyMedium => const TextStyle(
    fontFamily: family,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// tokens: typography.roles.listItem — 13/600
  static TextStyle get bodySmall => const TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  /// tokens: typography.roles.label — 14/600 · knappar: 14/600 — inte 700
  static TextStyle get labelLarge => const TextStyle(
    fontFamily: family,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  /// tokens: typography.roles.meta — 12.5/600 · säkerhets- och samtyckestext 12,5–13
  static TextStyle get labelMedium => const TextStyle(
    fontFamily: family,
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  /// tokens: typography.roles.navLabel — 11/700 · höjd från 10,5 — kökskontext
  static TextStyle get labelSmall => const TextStyle(
    fontFamily: family,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.45,
  );

  /// tokens: typography.roles.overline — 10.5/700 · endast kategorier och systemetiketter
  static TextStyle get overline => const TextStyle(
    fontFamily: family,
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
    height: 1.45,
  );

  /// tokens: typography.roles.stat — 38/700 · endast statistikvyn
  static TextStyle get statNumber => const TextStyle(
    fontFamily: family,
    fontSize: 38,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  /// tokens: typography.roles.cookingStep — 19/600 · matlagningsläget — läsavstånd
  static TextStyle get cookingStep => const TextStyle(
    fontFamily: family,
    fontSize: 19,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  /// tokens: typography.roles.caption — 12/400 · minsta 400-storlek
  static TextStyle get captionBase => const TextStyle(
    fontFamily: family,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  // ── Alias · samma stil, historiska namn ──
  static TextStyle get titleSmall => headlineSmall;
  static TextStyle get buttonText => labelLarge;
  static TextStyle get labelText => labelMedium;
  static TextStyle get captionText => captionBase;
  static TextStyle get buttonPrimary => labelLarge;
  static TextStyle get buttonTextStyle => labelLarge;
  static TextStyle get tabText => labelMedium;
  static TextStyle get navigationText => labelSmall;
  static TextStyle get navLabel => labelSmall;
  static TextStyle get cardTitle => titleMedium;
  static TextStyle get cardTitleStyle => titleMedium;
  static TextStyle get listTileTitle => titleMedium;
  static TextStyle get listTileSubtitle => bodyMedium;
  static TextStyle get dialogTitle => titleLarge;
  static TextStyle get dialogContent => bodyLarge;
  static TextStyle get appBarTitle => headlineSmall;
  static TextStyle get headerTitle => headlineSmall;
  static TextStyle get mainViewTitle => headlineBold;
  static TextStyle get sectionTitleStyle => sectionHeader;
  static TextStyle get emptyStateBody => bodyMedium;
  static TextStyle get bodyMediumMuted => bodyMedium;
  static TextStyle get titleMediumMuted => titleMedium;
  static TextStyle get labelMediumMuted => labelMedium;
  static TextStyle get badge => overline;
  static TextStyle get badgeLarge => labelMedium;
  static TextStyle get badgeText => labelMedium;
  static TextStyle get textXs => overline;
  static TextStyle get textXsBold => overline;
  static TextStyle get textSm => labelSmall;
  static TextStyle get filterChip => labelMedium;
  static TextStyle get formOption => bodyMedium;
  static TextStyle get contentLabel => labelLarge;
  static TextStyle get contentTitle => bodyLarge;
  static TextStyle get groupTitle => headlineSmall;
  static TextStyle get recipeCardTitle => titleMedium;
  static TextStyle get recipeCardDescription => bodySmall;
  static TextStyle get recipeCardMeta => labelSmall;
  static TextStyle get emptyStateTitle => headlineSmall;
  static TextStyle get recipeMetaBase => labelMedium;

  // ── Semantiska varianter · färgen bär betydelsen ──
  static TextStyle get recipeMeta =>
      labelMedium.copyWith(color: AppColors.recipeMeta);
  static TextStyle get sectionHeader =>
      headlineSmall.copyWith(color: AppColors.sectionHeader);
  static TextStyle get errorText => bodySmall.copyWith(color: AppColors.error);
  static TextStyle get successText =>
      bodySmall.copyWith(color: AppColors.success);
  static TextStyle get warningText =>
      bodySmall.copyWith(color: AppColors.warningText);
  static TextStyle get infoText => bodySmall.copyWith(color: AppColors.info);
  static TextStyle get hintText =>
      bodyMedium.copyWith(color: AppColors.textLight);
  static TextStyle get metadataEmphasized => labelMedium.copyWith();
  static TextStyle get titleBold =>
      titleMedium.copyWith(fontWeight: FontWeight.w700);
  static TextStyle get bodyBold =>
      bodyMedium.copyWith(fontWeight: FontWeight.w700);
  static TextStyle get bodyLargeBold =>
      bodyLarge.copyWith(fontWeight: FontWeight.w700);
  static TextStyle get bodyMediumError =>
      bodyMedium.copyWith(color: AppColors.error);
  static TextStyle get bodyMediumSuccess =>
      bodyMedium.copyWith(color: AppColors.success);
  static TextStyle get bodyMediumWarning =>
      bodyMedium.copyWith(color: AppColors.warningText);
  static TextStyle get labelSmallSuccess =>
      labelSmall.copyWith(color: AppColors.onSuccessContainer);
  static TextStyle get linkSmall => bodySmall.copyWith(color: AppColors.info);
  static TextStyle get bodyLargeLight =>
      bodyLarge.copyWith(color: AppColors.neutralLight);
  static TextStyle get snackbarText =>
      bodyMedium.copyWith(color: AppColors.neutralLight);
  static TextStyle get buttonTextLight =>
      labelLarge.copyWith(color: AppColors.textOnPrimary);
  static TextStyle get headerCountBadge =>
      labelMedium.copyWith(color: AppColors.rustLight);
  static TextStyle get sectionLabel =>
      overline.copyWith(color: AppColors.onWarningContainer);

  /// Material 3-TextTheme. Färg utelämnad — M3 lägger på colorScheme.onSurface.
  static TextTheme createTextTheme() {
    return TextTheme(
      displaySmall: displaySmall,
      headlineMedium: headlineMedium,
      headlineSmall: headlineSmall,
      titleLarge: titleLarge,
      titleMedium: titleMedium,
      bodyLarge: bodyLarge,
      bodyMedium: bodyMedium,
      bodySmall: bodySmall,
      labelLarge: labelLarge,
      labelMedium: labelMedium,
      labelSmall: labelSmall,
    );
  }
}
