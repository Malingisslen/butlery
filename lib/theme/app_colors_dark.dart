// GENERERAD FIL — ändra källan, inte den här.
// system 2.1 · tokens 1.13
// generator tools/gen-app-theme-dark.mjs v1.0
// källfingeravtryck sha256:a66474dba4e16f9f864277f40b031fc81ef70f3566022e5e07e3648c420c78b4 (5 indatafiler, generatorns källa inräknad)
// genererad ur källdatum 2026-08-05 (tokens.date — reproducerbart, inte klockan)
//
// MÖRKA kanoniska färger. Samma medlemsnamn som i AppColors, men det
// mörka lägets värde. Den här filen finns för att appens
// kompatibilitetsytor ska kunna härleda BÅDA lägena ur EN källa i
// stället för att bära en egen mörk palett.
//
// Här finns inga appspecifika färger. Kategorifärgerna är dekor och ägs
// av appen; se produktregler.md § 8.3b och tokens.json dataScale.
import 'package:flutter/material.dart';

/// Det mörka lägets kanoniska färger, genererade ur tokens.json.
class AppColorsDark {
  AppColorsDark._();

  /// Rubrikyta och primär åtgärd · semantic.surface.ink (dark)
  static const Color forestGreen = Color(0xFF24382C);

  /// Kortens underkant · semantic.border.statusWarning (dark)
  static const Color rustLight = Color(0xFFDCA968);

  /// semantic.surface.base (dark)
  static const Color cream = Color(0xFF17251D);

  /// semantic.surface.raised (dark)
  static const Color creamDark = Color(0xFF2F4437);

  /// Navigering · semantic.border.subtle (dark)
  static const Color creamDarker = Color(0x2EF5F4ED);

  /// semantic.surface.raised (dark)
  static const Color greenPale = Color(0xFF2F4437);

  /// Nav ovald · semantic.text.secondary (dark)
  static const Color greenMuted = Color(0xFF93A48D);

  /// Systemet har inget rent vitt · semantic.surface.base (dark)
  static const Color cardWhite = Color(0xFF17251D);

  /// Överlägg — värdet ligger i tokens.semantic, inte här · semantic.overlay.paperCard (dark)
  static const Color cardWhite54 = Color(0x8AF5F4ED);

  /// semantic.text.primary (dark)
  static const Color textDark = Color(0xFFF5F4ED);

  /// Lasbar sekundartext. Ytsakert varde: text.secondary #627061 ger 4,27:1 pa surface.raised och underkanns av 4,5-kravet, medan .onRaised klarar alla tillatna ytor. · semantic.text.secondary.onRaised (dark)
  static const Color textMedium = Color(0xFFA9B2A0);

  /// semantic.border.control (dark)
  static const Color placeholderIcon = Color(0x59F5F4ED);

  /// LEGACY_ALIAS for lasbar sekundartext. Lag tidigare pa text.disabled, vilket var semantiskt fel: appen anvander den till lasbar text, inte till avstangd. Ytsakert varde eftersom en Flutter-konstant inte kan valja per yta. Pensioneras i paket 7. · semantic.text.secondary.onRaised (dark)
  static const Color textLight = Color(0xFFA9B2A0);

  /// semantic.control.checked.foreground (dark)
  static const Color textOnPrimary = Color(0xFFF5F4ED);

  /// semantic.text.body (dark)
  static const Color textOnCream = Color(0xFFF5F4ED);

  /// semantic.text.success (dark)
  static const Color success = Color(0xFF8FB89A);

  /// Endast ytor och ikoner, aldrig text · semantic.border.statusWarning (dark)
  static const Color warning = Color(0xFFDCA968);

  /// semantic.text.danger (dark)
  static const Color error = Color(0xFFDE9078);

  /// semantic.surface.raised (dark)
  static const Color errorContainer = Color(0xFF2F4437);

  /// semantic.text.danger.onRaised (dark)
  static const Color onErrorContainer = Color(0xFFE5A08A);

  /// semantic.surface.raised (dark)
  static const Color successContainer = Color(0xFF2F4437);

  /// semantic.text.success.onRaised (dark)
  static const Color onSuccessContainer = Color(0xFF8FB89A);

  /// semantic.surface.raised (dark)
  static const Color warningContainer = Color(0xFF2F4437);

  /// semantic.text.accent.onRaised (dark)
  static const Color onWarningContainer = Color(0xFFDCA968);

  /// semantic.surface.raised (dark)
  static const Color infoContainer = Color(0xFF2F4437);

  /// semantic.text.primary (dark)
  static const Color onInfoContainer = Color(0xFFF5F4ED);

  /// Systemet har ingen bla - info bar lankfargen. Lag tidigare pa palette.saffronLink (#A15A0A), vilket ar exakt det varde text.link ersatte: det foll pa upphojd yta. Som palettfarg saknade den dessutom morkt lage och gav 1,99:1 mot surface.raised i morkt. · semantic.text.link (dark)
  static const Color info = Color(0xFFDCA968);

  /// semantic.border.subtle (dark)
  static const Color divider = Color(0x2EF5F4ED);

  /// semantic.text.secondary (dark)
  static const Color recipeMeta = Color(0xFF93A48D);

  /// semantic.text.body (dark)
  static const Color sectionHeader = Color(0xFFF5F4ED);

  /// semantic.surface.raised (dark)
  static const Color backgroundTint = Color(0xFF2F4437);

  /// semantic.scrim (dark)
  static const Color overlay = Color(0x9917251D);

  /// semantic.surface.base (dark)
  static const Color neutralLight = Color(0xFF17251D);

  /// semantic.text.secondary (dark)
  static const Color sharedRecipeText = Color(0xFF93A48D);

  /// semantic.surface.raised (dark)
  static const Color sharedRecipeBackground = Color(0xFF2F4437);

  /// Överlägg — värdet ligger i tokens.semantic, inte här · semantic.elevation.shadow (dark)
  static const Color shadowColor = Color(0x1A17251D);

  /// Överlägg — värdet ligger i tokens.semantic, inte här · semantic.overlay.paperWash (dark)
  static const Color overlayWhite40 = Color(0x66F5F4ED);

  /// Överlägg — värdet ligger i tokens.semantic, inte här · semantic.overlay.inkSubtle (dark)
  static const Color overlayBlack10 = Color(0x1A17251D);

  /// Överlägg — värdet ligger i tokens.semantic, inte här · semantic.overlay.inkLight (dark)
  static const Color overlayBlack20 = Color(0x3317251D);

  /// Överlägg — värdet ligger i tokens.semantic, inte här · semantic.overlay.inkMedium (dark)
  static const Color overlayBlack40 = Color(0x6617251D);

  /// Överlägg — värdet ligger i tokens.semantic, inte här · semantic.overlay.inkStrong (dark)
  static const Color overlayBlack60 = Color(0x9917251D);

  /// Tallrikslinjens ranna · semantic.progressTrack (dark)
  static const Color progressTrack = Color(0x2EF5F4ED);

  /// Tallrikslinjen sjalv - appens enda laddningsindikator (beslut B-18) · semantic.progressIndicator (dark)
  static const Color progressIndicator = Color(0xFFCE7C1E);

  /// Avstangd kontrollyta, avstangd kontur och avstangd reglageknopp (Komponentark 164, 174). Aldrig via opacitet. Yta, inte text: contrastPolicy undantar den. · semantic.surface.disabled (dark)
  static const Color surfaceDisabled = Color(0xFF4A5C50);

  /// Avstangd text. Ytsakert varde: text.disabled #7D897C ger 2,985:1 pa surface.raised och underkanns av det egna 3:1-golvet, och i morkt 2,0:1. .onRaised klarar papper och upphojd yta i bada lagen. · semantic.text.disabled.onRaised (dark)
  static const Color textDisabled = Color(0xFF93A48D);

  /// Fokusringen: 2 px med 3 px avstand (tokens focusRing.width/offset). Ink pa ljust, papper pa morkt, aldrig saffran. · semantic.focusRing (dark)
  static const Color focusRing = Color(0xFFF5F4ED);

  /// Saffran - vyns enda hjaltehandling, exakt en per vy (Komponentark 843). Aldrig textfarg. · semantic.action.primary (dark)
  static const Color actionPrimary = Color(0xFFCE7C1E);

  /// Nedtryckt hjaltehandling. Byts alltid i par med onActionPrimaryPressed. · semantic.action.primaryPressed (dark)
  static const Color actionPrimaryPressed = Color(0xFF9A5C14);

  /// Text pa saffran. Star bara pa actionPrimary. · semantic.text.onActionPrimary (dark)
  static const Color onActionPrimary = Color(0xFF17251D);

  /// Text pa nedtryckt saffran: papper, aldrig ink (beslut B-14, ink ger 2,97:1). Star bara pa actionPrimaryPressed. · semantic.text.onActionPrimaryPressed (dark)
  static const Color onActionPrimaryPressed = Color(0xFFF5F4ED);

  /// Varningstext och varningsglyf pa papper: offlinebannerns kontur och wifi-off (Komponentark 753, morkt 571). Inte warning (border.statusWarning, aldrig text) och inte onWarningContainer (text.accent.onRaised, samma ljusa hex men annat token). · semantic.text.warning (dark)
  static const Color textWarning = Color(0xFFDCA968);

  /// Accenttext (produktbeslut R6-01 = A): Hem-kortets Ikvall-rubrik i morkt lage tar text.accent #DCA968 pa surface.ink, som ritningen Skarmar v12 del 1:47 (--r04slot-765). Ytbunden, inte ytblind: det ljusa #A15A0A klarar surface.base (4,78:1) men inte surface.raised (4,30:1, dar galler text.accent.onRaised) och aldrig surface.ink (2,37:1, dar galler textAccentOnInk). · semantic.text.accent (dark)
  static const Color textAccent = Color(0xFFDCA968);

  /// Avstangd text pa papper (BUT-2191). Ytbunden till surface.base: golvet ar 3:1 (contrastPolicy disabled), och det nas dar (3,32:1 ljust, 3,04:1 morkt) men inte pa surface.raised (2,98:1 ljust, 2,00:1 morkt; dar galler textDisabled, som ar text.disabled.onRaised). Namnet textDisabled ar upptaget i det frysta kontraktet. Aldrig via opacitet. · semantic.text.disabled (dark)
  static const Color textDisabledOnBase = Color(0xFF627061);

  /// Avklarad rad (BUT-2147): genomstrykningen bar betydelsen, completed ar inte disabled. Ytbunden till surface.base: morkt #93A48D ger 6,02:1 dar men 3,96:1 pa surface.raised. · semantic.text.completed (dark)
  static const Color textCompleted = Color(0xFF93A48D);

  /// Sekundar brodtext (BUT-2159): behorighetsforklaringen, matlagningslaget utan steg och fotoimportens hjalptext. Ytblind: minst 6,79:1 (morkt pa surface.raised). · semantic.text.bodyMuted (dark)
  static const Color textBodyMuted = Color(0xFFC9D3C4);

  /// Vald yta (BUT-2198). Yta, inte text. · semantic.surface.selected (dark)
  static const Color surfaceSelected = Color(0xFF2F4437);

  /// Avgransning mellan ytor pa ink och inkRaised (BUT-2198). Dekorativ linje utan kontrastgolv, bar aldrig information. Anvands den som yta galler inkRaised #2F4437 i stallet. · semantic.border.onInk (dark)
  static const Color borderOnInk = Color(0xFF3F5145);

  /// Saffranstonad yta (BUT-2191): vald plats, i dag, pagaende. Bar text.primary och text.accent.onRaised; text.accent (#A15A0A, 4,38:1) ar forbjuden har. · semantic.surface.tint.accent (dark)
  static const Color surfaceTintAccent = Color(0xFF2F4437);

  /// Lerrod statusyta (BUT-2191). Bar text.danger och ink. · semantic.surface.tint.danger (dark)
  static const Color surfaceTintDanger = Color(0xFF2F4437);

  /// Gron statusyta (BUT-2191). Bar text.success och ink. · semantic.surface.tint.success (dark)
  static const Color surfaceTintSuccess = Color(0xFF2F4437);

  /// Varm notisyta pa papper (BUT-2191): upplysningar och kvar-att-losa-rutor. Bar text.body, ink, text.accent.onRaised och text.danger. · semantic.surface.tint.warning (dark)
  static const Color surfaceTintWarning = Color(0xFF2F4437);

  /// Ifylld kryssruta och radio (BUT-2191). Bar control.checked.foreground (textOnPrimary), 11,36:1 i bada lagena. · semantic.control.checked.background (dark)
  static const Color controlCheckedBackground = Color(0xFF24382C);

  // Alias — oförändrade, pekar på medlemmar ovan. Deklarerade i
  // tools/app-theme-map.json.
  static const Color textSecondary = textMedium;
  static const Color warningText = onWarningContainer;
  static const Color sharedRecipeTextColor = sharedRecipeText;
  static const Color sharedRecipeBackgroundColor = sharedRecipeBackground;
  static const Color chatBubbleOutgoing = forestGreen;
  static const Color chatBubbleIncoming = creamDark;
  static const Color chatTextOutgoing = textOnPrimary;
  static const Color chatTextIncoming = textDark;
  static const Color backgroundLight = cream;
  static const Color primary = forestGreen;
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
  static const Color headerForeground = textOnPrimary;
  static const Color navBackground = creamDarker;
  static const Color navUnselectedItem = greenMuted;
}
