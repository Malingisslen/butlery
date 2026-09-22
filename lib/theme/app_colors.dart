// GENERERAD FIL — ändra källan, inte den här.
// system 2.1 · tokens 1.13
// generator tools/gen-app-theme.mjs v2.3
// källfingeravtryck sha256:242102edd8d1337b2d1204c71ea77beea5ba1a79162fc8d5c81e5ae6064f6ec7 (6 indatafiler, generatorns källa inräknad)
// genererad ur källdatum 2026-08-05 (tokens.date — reproducerbart, inte klockan)
//
// Migration (etapp 8.1): varje medlem har samma NAMN som i det FRYSTA
// leveranskontraktet (legacy-api-contract.json), som TG-01 mäter med exakt
// mängdlikhet. Att ytan motsvarar app-repots faktiska anrop är OVERIFIERAT
// till Fas 2 (styrdokumentet § 9E). VÄRDET kommer ur tokens.json. Färgnamn som
// forestGreen och cream är därför historiska: de bär ink respektive paper.
// Att döpa om dem är en separat, mekanisk vända (BUT-nr saknas).
//
// Undantag: brand*-färgerna nedan är externa varumärkesidentiteter och
// tokeniseras inte — de är citat, inte design.
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  /// Rubrikyta och primär åtgärd · semantic.surface.ink
  static const Color forestGreen = Color(0xFF24382C);

  /// Nedtryckt / betoning · palette.inkDeep
  static const Color forestGreenDark = Color(0xFF17251D);

  /// Ljus variant · palette.greenLight
  static const Color forestGreenLight = Color(0xFF8FB89A);

  /// Dekorativ accent · palette.saffron
  static const Color rust = Color(0xFFCE7C1E);

  /// Kortens underkant · semantic.border.statusWarning
  static const Color rustLight = Color(0xFFD8B784);

  /// semantic.surface.base
  static const Color cream = Color(0xFFF5F4ED);

  /// semantic.surface.raised
  static const Color creamDark = Color(0xFFE6EAD9);

  /// Navigering · semantic.border.subtle
  static const Color creamDarker = Color(0xFFCCD1C2);

  /// semantic.surface.raised
  static const Color greenPale = Color(0xFFE6EAD9);

  /// Nav ovald · semantic.text.secondary
  static const Color greenMuted = Color(0xFF627061);

  /// Systemet har inget rent vitt · semantic.surface.base
  static const Color cardWhite = Color(0xFFF5F4ED);

  /// Överlägg — värdet ligger i tokens.semantic, inte här · semantic.overlay.paperCard
  static const Color cardWhite54 = Color(0x8AF5F4ED);

  /// semantic.text.primary
  static const Color textDark = Color(0xFF24382C);

  /// Lasbar sekundartext. Ytsakert varde: text.secondary #627061 ger 4,27:1 pa surface.raised och underkanns av 4,5-kravet, medan .onRaised klarar alla tillatna ytor. · semantic.text.secondary.onRaised
  static const Color textMedium = Color(0xFF5B6959);

  /// semantic.border.control
  static const Color placeholderIcon = Color(0xFF7D897C);

  /// LEGACY_ALIAS for lasbar sekundartext. Lag tidigare pa text.disabled, vilket var semantiskt fel: appen anvander den till lasbar text, inte till avstangd. Ytsakert varde eftersom en Flutter-konstant inte kan valja per yta. Pensioneras i paket 7. · semantic.text.secondary.onRaised
  static const Color textLight = Color(0xFF5B6959);

  /// palette.sagePale
  static const Color textTertiary = Color(0xFFB4BFA6);

  /// semantic.control.checked.foreground
  static const Color textOnPrimary = Color(0xFFF5F4ED);

  /// semantic.text.body
  static const Color textOnCream = Color(0xFF37453A);

  /// semantic.text.success
  static const Color success = Color(0xFF3F6B4F);

  /// Endast ytor och ikoner, aldrig text · semantic.border.statusWarning
  static const Color warning = Color(0xFFD8B784);

  /// semantic.text.danger
  static const Color error = Color(0xFF9C3B23);

  /// semantic.surface.raised
  static const Color errorContainer = Color(0xFFE6EAD9);

  /// semantic.text.danger.onRaised
  static const Color onErrorContainer = Color(0xFF9C3B23);

  /// semantic.surface.raised
  static const Color successContainer = Color(0xFFE6EAD9);

  /// semantic.text.success.onRaised
  static const Color onSuccessContainer = Color(0xFF3F6B4F);

  /// semantic.surface.raised
  static const Color warningContainer = Color(0xFFE6EAD9);

  /// semantic.text.accent.onRaised
  static const Color onWarningContainer = Color(0xFF8A5212);

  /// semantic.surface.raised
  static const Color infoContainer = Color(0xFFE6EAD9);

  /// semantic.text.primary
  static const Color onInfoContainer = Color(0xFF24382C);

  /// Systemet har ingen bla - info bar lankfargen. Lag tidigare pa palette.saffronLink (#A15A0A), vilket ar exakt det varde text.link ersatte: det foll pa upphojd yta. Som palettfarg saknade den dessutom morkt lage och gav 1,99:1 mot surface.raised i morkt. · semantic.text.link
  static const Color info = Color(0xFF8A5212);

  /// semantic.border.subtle
  static const Color divider = Color(0xFFCCD1C2);

  /// semantic.text.secondary
  static const Color recipeMeta = Color(0xFF627061);

  /// semantic.text.body
  static const Color sectionHeader = Color(0xFF37453A);

  /// palette.saffron
  static const Color starGold = Color(0xFFCE7C1E);

  /// palette.wheat
  static const Color categoryDairy = Color(0xFFD8B784);

  /// palette.green
  static const Color categoryVegetables = Color(0xFF3F6B4F);

  /// palette.greenLight
  static const Color categoryFruit = Color(0xFF8FB89A);

  /// palette.saffronPale
  static const Color categoryBreadGrains = Color(0xFFDCA968);

  /// palette.sage
  static const Color categoryFrozen = Color(0xFF93A48D);

  /// palette.saffronDeep
  static const Color categoryDryGoods = Color(0xFF8A5212);

  /// palette.sageMuted
  static const Color categoryOther = Color(0xFFA9B2A0);

  /// semantic.surface.raised
  static const Color backgroundTint = Color(0xFFE6EAD9);

  /// palette.saffronDeep
  static const Color illustrationBrown = Color(0xFF8A5212);

  /// palette.saffron
  static const Color illustrationOrange = Color(0xFFCE7C1E);

  /// palette.clay
  static const Color illustrationPurpleRed = Color(0xFF9C3B23);

  /// semantic.scrim
  static const Color overlay = Color(0x6624382C);

  /// semantic.surface.base
  static const Color neutralLight = Color(0xFFF5F4ED);

  /// palette.sageMuted
  static const Color neutralMedium = Color(0xFFA9B2A0);

  /// palette.inkDeep
  static const Color neutralDark = Color(0xFF17251D);

  /// semantic.text.secondary
  static const Color sharedRecipeText = Color(0xFF627061);

  /// palette.sagePale
  static const Color sharedRecipeIcon = Color(0xFFB4BFA6);

  /// semantic.surface.raised
  static const Color sharedRecipeBackground = Color(0xFFE6EAD9);

  /// Överlägg — värdet ligger i tokens.semantic, inte här · semantic.elevation.shadow
  static const Color shadowColor = Color(0x1A17251D);

  /// Lila fanns inte i systemet — närmaste avsikt är clay · palette.clay
  static const Color secondaryPurple = Color(0xFF9C3B23);

  /// palette.inkRaised
  static const Color surfaceDark = Color(0xFF2F4437);

  /// Överlägg — värdet ligger i tokens.semantic, inte här · semantic.overlay.paperWash
  static const Color overlayWhite40 = Color(0x66F5F4ED);

  /// Överlägg — värdet ligger i tokens.semantic, inte här · semantic.overlay.inkSubtle
  static const Color overlayBlack10 = Color(0x1A17251D);

  /// Överlägg — värdet ligger i tokens.semantic, inte här · semantic.overlay.inkLight
  static const Color overlayBlack20 = Color(0x3317251D);

  /// Överlägg — värdet ligger i tokens.semantic, inte här · semantic.overlay.inkMedium
  static const Color overlayBlack40 = Color(0x6617251D);

  /// Överlägg — värdet ligger i tokens.semantic, inte här · semantic.overlay.inkStrong
  static const Color overlayBlack60 = Color(0x9917251D);

  /// Tallrikslinjens ranna · semantic.progressTrack
  static const Color progressTrack = Color(0xFFE6EAD9);

  /// Tallrikslinjen sjalv - appens enda laddningsindikator (beslut B-18) · semantic.progressIndicator
  static const Color progressIndicator = Color(0xFFCE7C1E);

  /// Avstangd kontrollyta, avstangd kontur och avstangd reglageknopp (Komponentark 164, 174). Aldrig via opacitet. Yta, inte text: contrastPolicy undantar den. · semantic.surface.disabled
  static const Color surfaceDisabled = Color(0xFFA9B2A0);

  /// Avstangd text. Ytsakert varde: text.disabled #7D897C ger 2,985:1 pa surface.raised och underkanns av det egna 3:1-golvet, och i morkt 2,0:1. .onRaised klarar papper och upphojd yta i bada lagen. · semantic.text.disabled.onRaised
  static const Color textDisabled = Color(0xFF788477);

  /// Fokusringen: 2 px med 3 px avstand (tokens focusRing.width/offset). Ink pa ljust, papper pa morkt, aldrig saffran. · semantic.focusRing
  static const Color focusRing = Color(0xFF24382C);

  /// Saffran - vyns enda hjaltehandling, exakt en per vy (Komponentark 843). Aldrig textfarg. · semantic.action.primary
  static const Color actionPrimary = Color(0xFFCE7C1E);

  /// Nedtryckt hjaltehandling. Byts alltid i par med onActionPrimaryPressed. · semantic.action.primaryPressed
  static const Color actionPrimaryPressed = Color(0xFF9A5C14);

  /// Text pa saffran. Star bara pa actionPrimary. · semantic.text.onActionPrimary
  static const Color onActionPrimary = Color(0xFF17251D);

  /// Text pa nedtryckt saffran: papper, aldrig ink (beslut B-14, ink ger 2,97:1). Star bara pa actionPrimaryPressed. · semantic.text.onActionPrimaryPressed
  static const Color onActionPrimaryPressed = Color(0xFFF5F4ED);

  // Alias — oförändrade, pekar på medlemmar ovan. Deklarerade i
  // tools/app-theme-map.json; högersidan mäts mot utdata av TG-01.
  static const Color textSecondary = textMedium;
  static const Color accent = rust;
  static const Color warningText = onWarningContainer;
  static const Color sharedRecipeTextColor = sharedRecipeText;
  static const Color sharedRecipeIconColor = sharedRecipeIcon;
  static const Color sharedRecipeBackgroundColor = sharedRecipeBackground;
  static const Color chatBubbleOutgoing = forestGreen;
  static const Color chatBubbleIncoming = creamDark;
  static const Color chatTextOutgoing = textOnPrimary;
  static const Color chatTextIncoming = textDark;
  static const Color categoryMeatFish = illustrationPurpleRed;
  static const Color backgroundLight = cream;
  static const Color backgroundDark = neutralDark;
  static const Color primary = forestGreen;
  static const Color secondary = rust;
  static const Color surface = cream;
  static const Color surfaceVariant = creamDark;
  static const Color onSurface = textDark;
  static const Color primaryContainer = creamDark;
  static const Color secondaryContainer = creamDark;
  static const Color onPrimaryContainer = forestGreen;
  static const Color onPrimary = textOnPrimary;
  static const Color outline = placeholderIcon;
  static const Color shadow = shadowColor;
  static const Color onSuccess = textOnPrimary;
  static const Color onError = textOnPrimary;
  static const Color onWarning = textDark;
  static const Color onInfo = textOnPrimary;
  static const Color recipeCardLeftBorder = forestGreen;
  static const Color recipeCardBottomBorder = rustLight;
  static const Color headerBackground = forestGreen;
  static const Color headerAccent = rust;
  static const Color headerForeground = textOnPrimary;
  static const Color navBackground = creamDarker;
  static const Color navSelectedIndicator = rust;
  static const Color navSelectedItem = forestGreenDark;
  static const Color navUnselectedItem = greenMuted;
  static const Color transparent = Colors.transparent;

  /// Ljust schema — varje slot ur tokens.json, inga härledda toner.
  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF24382C),
    onPrimary: Color(0xFFF5F4ED),
    primaryContainer: Color(0xFFE6EAD9),
    onPrimaryContainer: Color(0xFF24382C),
    secondary: Color(0xFFCE7C1E),
    onSecondary: Color(0xFF17251D),
    secondaryContainer: Color(0xFFE6EAD9),
    onSecondaryContainer: Color(0xFF8A5212),
    tertiary: Color(0xFF3F6B4F),
    onTertiary: Color(0xFFF5F4ED),
    tertiaryContainer: Color(0xFFE6EAD9),
    onTertiaryContainer: Color(0xFF3F6B4F),
    error: Color(0xFF9C3B23),
    onError: Color(0xFFF5F4ED),
    errorContainer: Color(0xFFE6EAD9),
    onErrorContainer: Color(0xFF9C3B23),
    surface: Color(0xFFF5F4ED),
    onSurface: Color(0xFF24382C),
    surfaceContainerHighest: Color(0xFFE6EAD9),
    onSurfaceVariant: Color(0xFF627061),
    outline: Color(0xFF7D897C),
    outlineVariant: Color(0xFFCCD1C2),
    shadow: Color(0x1A17251D),
    scrim: Color(0x6624382C),
    inverseSurface: Color(0xFF24382C),
    onInverseSurface: Color(0xFFF5F4ED),
    inversePrimary: Color(0xFF8FB89A),
    surfaceTint: Color(0xFF24382C),
  );

  /// Mörkt schema. **Ändring mot tidigare:** det byggdes med
  /// `ColorScheme.fromSeed`, som räknade fram toner systemet aldrig godkänt
  /// och som därför behövde tio handöverskrivningar. Nu är varje slot en
  /// token med ett mätt kontrastpar bakom sig, och schemat är `const`.
  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF24382C),
    onPrimary: Color(0xFFF5F4ED),
    primaryContainer: Color(0xFF2F4437),
    onPrimaryContainer: Color(0xFFF5F4ED),
    secondary: Color(0xFFCE7C1E),
    onSecondary: Color(0xFF17251D),
    secondaryContainer: Color(0xFF2F4437),
    onSecondaryContainer: Color(0xFFDCA968),
    tertiary: Color(0xFF8FB89A),
    onTertiary: Color(0xFFF5F4ED),
    tertiaryContainer: Color(0xFF2F4437),
    onTertiaryContainer: Color(0xFF8FB89A),
    error: Color(0xFFDE9078),
    onError: Color(0xFF17251D),
    errorContainer: Color(0xFF2F4437),
    onErrorContainer: Color(0xFFE5A08A),
    surface: Color(0xFF17251D),
    onSurface: Color(0xFFF5F4ED),
    surfaceContainerHighest: Color(0xFF2F4437),
    onSurfaceVariant: Color(0xFF93A48D),
    outline: Color(0x59F5F4ED),
    outlineVariant: Color(0x2EF5F4ED),
    shadow: Color(0x1A17251D),
    scrim: Color(0x9917251D),
    inverseSurface: Color(0xFF17251D),
    onInverseSurface: Color(0xFFF5F4ED),
    inversePrimary: Color(0xFF8FB89A),
    surfaceTint: Color(0xFF24382C),
  );

  // ── Externa varumärken · tokeniseras inte (se kommentaren ovan) ──
  static const Color brandYoutube = Color(0xFFFF0000);
  static const Color brandYoutubeBackground = Color(0xFFFFE0E0);
  static const Color brandYoutubeText = Color(0xFFCC0000);
  static const Color brandTiktok = Color(0xFF00F2EA);
  static const Color brandTiktokBackground = Color(0xFFE0F7FA);
  static const Color brandTiktokText = Color(0xFF161823);
  static const Color brandInstagram = Color(0xFFE1306C);
  static const Color brandInstagramBackground = Color(0xFFFCE4EC);
  static const Color brandInstagramText = Color(0xFFC13584);
  static const Color brandTwitter = Color(0xFF1DA1F2);
  static const Color brandPinterest = Color(0xFFE60023);
  static const Color brandWhatsapp = Color(0xFF25D366);
  static const Color brandTelegram = Color(0xFF0088CC);
  static const Color brandFacebook = Color(0xFF1877F2);
  static const Color brandReddit = Color(0xFFFF4500);
  static const Color brandAllrecipes = Color(0xFFBD081C);
  static const Color brandIca = Color(0xFFFF6600);
  static const Color brandCoop = Color(0xFF006341);
  static const Color brandArla = Color(0xFFE30613);
  static const Color brandKoketSe = Color(0xFF000000);
  static const Color brandGeneric = Color(0xFF6B7280);
}
