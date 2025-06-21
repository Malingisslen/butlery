// lib/theme/app_theme.dart

import 'package:flutter/material.dart';

/// Centraliserat theme-system för Butlery-appen
/// Baserat på Figma-prototypen med Material 3 design
/// ✨ KOMPLETT SEMANTISK THEME MED ALLA TEXTSTYLES
class AppTheme {
  // ===== FÄRGPALETT BASERAT PÅ FIGMA (UTÖKAD) =====

  static const Color _primaryBlue = Color(
    0xFF4A7C93,
  ); // Header-blå från "Din meny"
  static const Color _darkNavy = Color(0xFF2C3E50); // Bottom navigation
  static const Color _backgroundBeige = Color(0xFFF5F5F0); // Huvudbakgrund
  static const Color _cardWhite = Color(0xFFFFFFFF); // Vita kort
  static const Color _textDark = Color(0xFF2C3E50); // Mörk text
  static const Color _textMedium = Color(0xFF6B7280); // Medium grå text
  static const Color _textLight = Color(0xFF9CA3AF); // Ljus grå text
  static const Color _textSecondary =
      _textMedium; // Alias för bakåtkompatibilitet
  static const Color _accent = Color(0xFF60A5FA); // Accent-blå för knappar
  static const Color _success = Color(0xFF10B981); // Grön för framgång
  static const Color _warning = Color(0xFFF59E0B); // Gul för varningar
  static const Color _error = Color(0xFFEF4444); // Röd för fel
  static const Color _divider = Color(0xFFE5E7EB); // Avdelare

  // Nya färger för förbättrad design
  static const Color _recipeMeta = Color(
    0xFF8B9AAF,
  ); // För "6 portioner | 30 minuter"
  static const Color _sectionHeader = Color(
    0xFF374151,
  ); // För "Middagar", "Lunch" etc
  static const Color _starGold = Color(0xFFFBBF24); // Guldgul för stjärnor

  // ===== MATERIAL 3 COLOR SCHEME (UPPDATERAD) =====

  static ColorScheme get lightColorScheme => const ColorScheme.light(
    // Primära färger
    primary: _primaryBlue,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFE1F5FE),
    onPrimaryContainer: _textDark,

    // Sekundära färger
    secondary: _accent,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFE3F2FD),
    onSecondaryContainer: _textDark,

    // Bakgrunder (uppdaterade för Material 3)
    surface: _cardWhite,
    onSurface: _textDark,
    surfaceContainerHighest: Color(0xFFF8F9FA),

    // Fel och varningar
    error: _error,
    onError: Colors.white,
    errorContainer: Color(0xFFFFEBEE),
    onErrorContainer: _error,

    // Gränser och dividers
    outline: _divider,
    outlineVariant: Color(0xFFF3F4F6),

    // Variabler för text
    onSurfaceVariant: _textMedium,
  );

  // ===== TYPOGRAFI (FÖRBÄTTRAD MED ALLA SEMANTISKA STYLES) =====

  static TextTheme get textTheme => const TextTheme(
    // Headers
    displayLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: _textDark,
      letterSpacing: -0.5,
    ),
    displayMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: _textDark,
      letterSpacing: -0.25,
    ),
    displaySmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: _textDark,
    ),

    // Headlines (för "Din meny", section headers)
    headlineLarge: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: _primaryBlue, // Blå som i Figma
      letterSpacing: -0.5,
    ),
    headlineMedium: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: _sectionHeader, // Mörk för "Middagar", "Lunch"
      letterSpacing: -0.25,
    ),
    headlineSmall: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: _textDark,
    ),

    // Titles (för receptnamn)
    titleLarge: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      color: _textDark,
      height: 1.3,
    ),
    titleMedium: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: _textDark,
      height: 1.3,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: _textDark,
    ),

    // Body text
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: _textDark,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: _textMedium,
      height: 1.4,
    ),
    bodySmall: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.normal,
      color: _recipeMeta, // Särskild färg för metadata
      height: 1.3,
    ),

    // Labels (för knappar etc.)
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: _textDark,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: _textMedium,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: _textLight,
    ),
  );

  // ===== KOMPONENT-THEMES =====

  static AppBarTheme get appBarTheme => const AppBarTheme(
    backgroundColor: _backgroundBeige,
    foregroundColor: _textDark,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: _textDark,
    ),
    iconTheme: IconThemeData(color: _textDark),
  );

  static CardTheme get cardTheme => const CardTheme(
    color: _cardWhite,
    elevation: 2,
    shadowColor: Color(0x1A2C3E50), // _textDark med opacity som Color
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  );

  static InputDecorationTheme get inputDecorationTheme =>
      const InputDecorationTheme(
        filled: true,
        fillColor: _cardWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusMedium)),
          borderSide: BorderSide(color: _divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusMedium)),
          borderSide: BorderSide(color: _divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusMedium)),
          borderSide: BorderSide(color: _primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusMedium)),
          borderSide: BorderSide(color: _error),
        ),
        hintStyle: TextStyle(color: _textLight),
        labelStyle: TextStyle(color: _textMedium),
      );

  // ===== HUVUDTHEME - SUPER FÖRENKLAD =====

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: lightColorScheme,
    textTheme: textTheme,
    appBarTheme: appBarTheme,
    cardTheme: CardThemeData(
      color: _cardWhite,
      elevation: 2,
      shadowColor: const Color(0x1A2C3E50),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      margin: EdgeInsets.symmetric(horizontal: spacingSm, vertical: spacingXs),
    ),
    inputDecorationTheme: inputDecorationTheme,

    // Grundläggande inställningar
    scaffoldBackgroundColor: _backgroundBeige,
    dividerColor: _divider,
    splashColor: const Color(0x1A4A7C93), // _primaryBlue med opacity som Color
    highlightColor: const Color(
      0x1A4A7C93,
    ), // _primaryBlue med opacity som Color
  );

  // ===== HJÄLP-METODER FÖR KOMPONENTER =====

  /// Returnerar styling för BottomNavigationBar som fungerar direkt i widgeten
  static BottomNavigationBar styledBottomNavBar({
    required int currentIndex,
    required Function(int) onTap,
    required List<BottomNavigationBarItem> items,
  }) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      items: items,
      type: BottomNavigationBarType.fixed,
      backgroundColor: navBarColor,
      selectedItemColor: accentColor,
      unselectedItemColor: textTertiary,
      elevation: 8,
      selectedLabelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
      ),
    );
  }

  static const Color primaryColor = _primaryBlue;
  static const Color backgroundColor = _backgroundBeige;
  static const Color cardColor = _cardWhite;
  static const Color textPrimary = _textDark;
  static const Color textSecondary =
      _textSecondary; // Använder alias vi skapade ovan
  static const Color textTertiary = _textLight;
  static const Color accentColor = _accent;
  static const Color successColor = _success;
  static const Color warningColor = _warning;
  static const Color errorColor = _error;
  static const Color dividerColor = _divider;
  static const Color navBarColor = _darkNavy;

  // ===== FORMATERINGS-SYMBOLER (för ShareService etc.) =====

  /// Punkt-symbol för listor
  static const String bulletPoint = '•';

  /// Horisontell linje-symbol
  static const String dividerChar = '─';

  /// Nummer-avdelare för numrerade listor
  static const String numberDivider = '. ';

  // ===== SPACING CONSTANTS (UTÖKADE) =====

  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;

  // Ytterligare spacing för specifika användningsfall:
  static const double spacingXxs = 2.0; // För mycket små mellanrum
  static const double spacingHuge = 64.0; // För stora section-separatorer

  // ===== SEMANTISKA SPACING KOMBINATIONER =====

  /// Ofta använd kombination: spacingSm + 4 = 12px
  static const double spacingSmPlus = 12.0; // För input padding och liknande

  // ===== OVERLAY OCH DIVIDER KONSTANTER (NYA TILLÄGG) =====

  // Overlay opacity för loading screens och dialogs
  static const double overlayOpacity = 0.7;
  static const double cardOverlayOpacity = 0.8;

  // Divider height (du använder redan dividerColor)
  static const double dividerHeight = 1.0;

  // ===== STANDARDISERADE EDGE INSETS =====

  /// Standardiserade EdgeInsets för vanliga användningsfall
  static EdgeInsets get screenPadding =>
      EdgeInsets.all(spacingMd); // 16px - för screen padding
  static EdgeInsets get sectionPadding =>
      EdgeInsets.all(spacingLg); // 24px - för section padding
  static EdgeInsets get cardPadding =>
      EdgeInsets.all(spacingMd); // 16px - för card padding
  static EdgeInsets get listItemPadding => EdgeInsets.symmetric(
    // För list items
    horizontal: spacingMd,
    vertical: spacingSm,
  );
  static EdgeInsets get buttonPadding => EdgeInsets.symmetric(
    // För button padding
    vertical: spacingMd,
    horizontal: spacingLg,
  );
  static EdgeInsets get inputPadding => EdgeInsets.symmetric(
    // För input content padding
    horizontal: spacingMd,
    vertical: spacingSmPlus,
  );

  // ===== STANDARDISERADE SIZED BOXES (GAPS) =====

  /// Förkonfigurerade SizedBox widgets för vanliga mellanrum
  static Widget get tinyGap => SizedBox(height: spacingXs); // 4px
  static Widget get smallGap => SizedBox(height: spacingSm); // 8px
  static Widget get mediumGap => SizedBox(height: spacingMd); // 16px
  static Widget get largeGap => SizedBox(height: spacingLg); // 24px
  static Widget get extraLargeGap => SizedBox(height: spacingXl); // 32px
  static Widget get hugeGap => SizedBox(height: spacingXxl); // 48px

  // ===== HORISONTELLA GAPS (NYTT TILLÄGG) =====

  // Horisontella SizedBox widgets för mellanrum mellan element
  static Widget get smallHorizontalGap => SizedBox(width: spacingSm); // 8px
  static Widget get mediumHorizontalGap => SizedBox(width: spacingMd); // 16px
  static Widget get largeHorizontalGap => SizedBox(width: spacingLg); // 24px

  // ===== SEMANTISKA ICON-STORLEKAR =====

  /// Specifika storlekar för olika användningsområden
  static const double iconSizeInfo = 16.0; // Info, filter, metadata
  static const double iconSizeAction = 20.0; // Edit, delete, add i knappar
  static const double iconSizeNavigation = 24.0; // Bottom navigation, tabs
  static const double iconSizeDisplay = 32.0; // Placeholders, stora ikoner
  static const double iconSizeHero = 48.0; // Import foto, huvudåtgärder
  static const double iconSizeEmptyState = 64.0; // Empty state ikoner

  // Gamla för bakåtkompatibilitet
  static const double iconSizeSmall = iconSizeInfo;
  static const double iconSizeMedium = iconSizeNavigation;
  static const double iconSizeLarge = iconSizeDisplay;
  static const double iconSizeXLarge = iconSizeHero;
  static const double iconSizeXXLarge = iconSizeEmptyState;

  // ===== ELEVATION KONSTANTER (NYA TILLÄGG) =====

  static const double elevationLow = 2.0;
  static const double elevationMedium = 4.0;
  static const double elevationHigh = 8.0;

  // ===== BORDER RADIUS (UTÖKADE) =====

  static const double radiusSmall = 4.0;
  static const double radiusMedium = 8.0;
  static const double radiusLarge = 12.0;
  static const double radiusXLarge = 16.0;
  static const double radiusRound = 35.0; // För runda bilder
  static const double radiusChip = 6.0; // För chips och taggar

  // ===== STANDARDISERADE BORDER RADIUS =====

  /// Förkonfigurerade BorderRadius för vanliga användningsfall
  static BorderRadius get smallRadius =>
      BorderRadius.circular(radiusSmall); // 4px
  static BorderRadius get mediumRadius =>
      BorderRadius.circular(radiusMedium); // 8px
  static BorderRadius get largeRadius =>
      BorderRadius.circular(radiusLarge); // 12px
  static BorderRadius get extraLargeRadius =>
      BorderRadius.circular(radiusXLarge); // 16px
  static BorderRadius get roundRadius =>
      BorderRadius.circular(radiusRound); // 35px
  static BorderRadius get chipRadius =>
      BorderRadius.circular(radiusChip); // 6px

  // ===== NYA BORDER RADIUS KONSTANTER (TILLÄGG) =====

  // Bottom sheet radius
  static const BorderRadius bottomSheetBorderRadius = BorderRadius.only(
    topLeft: Radius.circular(radiusXLarge), // 16px
    topRight: Radius.circular(radiusXLarge), // 16px
  );

  // Card border radius alias
  static const BorderRadius cardBorderRadius = BorderRadius.all(
    Radius.circular(radiusMedium), // 8px
  );

  // ===== SAKNADE BORDER RADIUS KONSTANTER =====

  static const double borderRadiusSm =
      radiusSmall; // 4px - alias för RecipeImageManager

  // ===== SHADOWS (FÖRBÄTTRADE) =====

  static List<BoxShadow> get cardShadow => const [
    BoxShadow(
      color: Color(0x0A000000), // Subtil skugga som i Figma
      blurRadius: 12,
      offset: Offset(0, 4),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x05000000), // Extra subtil skugga för djup
      blurRadius: 4,
      offset: Offset(0, 2),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get buttonShadow => const [
    BoxShadow(
      color: Color(0x1A3B82F6), // Blå skugga för knappar
      blurRadius: 8,
      offset: Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get floatingButtonShadow => const [
    BoxShadow(
      color: Color(0x1F000000), // Starkare skugga för floating buttons
      blurRadius: 16,
      offset: Offset(0, 8),
      spreadRadius: 0,
    ),
  ];

  // ===== STYLING GETTERS (KOMPLETT LÖSNING) =====

  /// Receptkort container decoration
  static BoxDecoration get recipeCardDecoration => BoxDecoration(
    color: cardColor,
    borderRadius: extraLargeRadius,
    boxShadow: cardShadow,
  );

  /// Runda receptbilder decoration
  static BoxDecoration get recipeImageDecoration => BoxDecoration(
    borderRadius: roundRadius,
    boxShadow: const [
      BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
    ],
  );

  /// Receptkort margins
  static EdgeInsets get recipeCardMargin =>
      const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0);

  /// Receptkort padding
  static EdgeInsets get recipeCardPadding =>
      const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0);

  /// Section header text style ("Middagar", "Lunch")
  static TextStyle get sectionHeaderStyle => const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: Color(0xFF374151),
    letterSpacing: -0.3,
  );

  /// Receptmetadata text style ("6 portioner | 30 minuter")
  static TextStyle get recipeMetaStyle => const TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: Color(0xFF8B9AAF),
    letterSpacing: 0.2,
  );

  /// Meal type chip decoration
  static BoxDecoration mealTypeChipDecoration(Color color) =>
      BoxDecoration(color: color, borderRadius: chipRadius);

  /// Tag chip decoration
  static BoxDecoration get tagChipDecoration => BoxDecoration(
    color: backgroundColor,
    borderRadius: BorderRadius.circular(12.0),
    border: Border.all(color: dividerColor, width: 1),
  );

  // ===== SAKNADE EGENSKAPER SOM ANVÄNDS I RECIPE_CARD =====

  /// Storleken på receptbilder (70x70 pixels)
  static const double recipeImageSize = 70.0;

  /// Färg för stjärnor i betyg
  static const Color starColor = _starGold;

  // ===== MEAL TYPE COLORS (TIDIGARE HARDKODADE) =====

  /// Färger för olika måltidstyper - nu centraliserade istället för hardkodade
  static const Color frukostColor = Color(0xFFFF8C00); // Orange
  static const Color lunchColor = Color(0xFF16A085); // Teal
  static const Color middagColor = _primaryBlue; // Använder theme blue
  static const Color dessertColor = Color(0xFFE91E63); // Pink
  static const Color mellanmalColor = Color(0xFF9C27B0); // Purple
  static const Color fikaColor = Color(0xFF8D6E63); // Brown
  static const Color defaultMealColor = _textSecondary; // Fallback färg

  // ===== CONTAINER HEIGHTS (SLUTGILTIGA CENTRALISERINGAR) =====

  /// Standardiserade container höjder för konsistens
  static const double imageHeightSmall = 100.0; // Små bilder
  static const double imageHeightMedium =
      200.0; // Medium bilder (standard för receptbilder)
  static const double imageHeightLarge = 300.0; // Stora bilder
  static const double buttonHeight = 56.0; // Standard knapp-höjd
  static const double inputHeight = 48.0; // Standard input-höjd

  // ===== NYA BILDSTORLEKAR (TILLÄGG) =====

  // Bildstorlekar för RecipeImageManager
  static const double imageWidthSmall = 120.0;
  static const double imageCarouselHeight = 250.0;

  // Thumbnails
  static const double thumbnailSize = 60.0;
  static const double thumbnailSmallSize = 40.0;
  static const double thumbnailLargeSize = 80.0;

  // Aspect ratios
  static const double imageAspectRatio = 16 / 9;
  static const double thumbnailAspectRatio = 1.0;

  // ===== SEMANTISKA WIDGET BUILDERS =====

  /// Info-ikoner för metadata och statusinfo
  static Widget infoIcon(BuildContext context, {IconData? icon}) => Icon(
    icon ?? Icons.info_outline,
    size: iconSizeInfo,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );

  /// Filter-ikon för sök och filter-funktioner
  static Widget filterIcon(BuildContext context) => Icon(
    Icons.filter_list,
    size: iconSizeInfo,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );

  /// Action-ikoner för interaktiva element
  static Widget actionIcon(
    BuildContext context,
    IconData icon, {
    Color? color,
    double? size,
  }) => Icon(
    icon,
    size: size ?? iconSizeAction,
    color: color ?? Theme.of(context).colorScheme.onSurface,
  );

  /// Status-ikoner med semantiska färger
  static Widget successIcon(BuildContext context) =>
      Icon(Icons.check_circle, size: iconSizeInfo, color: successColor);

  static Widget errorIcon(BuildContext context) =>
      Icon(Icons.error_outline, size: iconSizeInfo, color: errorColor);

  static Widget warningIcon(BuildContext context) =>
      Icon(Icons.warning_outlined, size: iconSizeInfo, color: warningColor);

  /// Loading indicators för olika storlekar
  static Widget smallLoadingIndicator() => const SizedBox(
    width: 16,
    height: 16,
    child: CircularProgressIndicator(strokeWidth: 2),
  );

  static Widget mediumLoadingIndicator() => const CircularProgressIndicator();

  static Widget largeLoadingIndicator() =>
      const CircularProgressIndicator.adaptive();

  // ===== ✨ NYA SEMANTISKA TEXT STYLES (KRITISKA TILLÄGG) =====

  /// Error text style för felmeddelanden
  static TextStyle get errorTextStyle => const TextStyle(
    color: errorColor,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  /// Success text style för framgångsmeddelanden
  static TextStyle get successTextStyle => const TextStyle(
    color: successColor,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  /// Warning text style för varningsmeddelanden
  static TextStyle get warningTextStyle => const TextStyle(
    color: warningColor,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  /// Info text style för informationsmeddelanden
  static TextStyle get infoTextStyle => const TextStyle(
    color: _textMedium,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  /// Chip label style för taggar och filter chips
  static TextStyle get chipLabelStyle => const TextStyle(
    fontSize: 11,
    color: textSecondary,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );

  /// Chip på primär bakgrund (vit text på färgad bakgrund)
  static TextStyle get chipOnPrimaryTextStyle => const TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 0.2,
  );

  /// Form label style för formulärfält
  static TextStyle get formLabelStyle => const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: _textMedium,
    height: 1.2,
  );

  /// Input hint style för placeholder text
  static TextStyle get inputHintStyle => const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: _textLight,
    height: 1.2,
  );

  /// Metadata style för receptdetaljer (portioner, tid, etc.)
  static TextStyle get metadataStyle => const TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: _recipeMeta,
    letterSpacing: 0.2,
    height: 1.3,
  );

  /// Section title style för större rubriker
  static TextStyle get sectionTitleStyle => const TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.3,
    height: 1.2,
  );

  /// Card title style för kort-rubriker
  static TextStyle get cardTitleStyle => const TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.3,
    letterSpacing: -0.1,
  );

  /// Subtitle style för undertexter
  static TextStyle get subtitleStyle => const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: _textMedium,
    height: 1.4,
  );

  /// Caption style för små texter
  static TextStyle get captionStyle => const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textTertiary,
    letterSpacing: 0.3,
    height: 1.2,
  );

  // ===== STANDARDISERADE TEXT STYLES =====

  /// Återkommande text styles som används i flera komponenter
  static TextStyle get buttonTextStyle => const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.2,
  );

  /// Body style alias för enklare användning
  static TextStyle get bodyStyle => const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: _textMedium,
    height: 1.4,
  );

  // ===== STANDARDISERADE BUTTON STYLES =====

  /// Förkonfigurerade ButtonStyle för konsistenta knappar
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
    minimumSize: Size(
      double.infinity,
      buttonHeight,
    ), // ✅ Använder theme konstant
    padding: buttonPadding,
    textStyle: buttonTextStyle,
    shape: RoundedRectangleBorder(borderRadius: largeRadius),
  );

  static ButtonStyle get secondaryButtonStyle => OutlinedButton.styleFrom(
    minimumSize: Size(
      double.infinity,
      buttonHeight,
    ), // ✅ Använder theme konstant
    padding: buttonPadding,
    textStyle: buttonTextStyle,
    shape: RoundedRectangleBorder(borderRadius: largeRadius),
  );

  // ===== STANDARDISERADE DECORATIONS =====

  /// Förkonfigurerade BoxDecoration för vanliga användningsfall
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: cardColor,
    borderRadius: largeRadius,
    boxShadow: cardShadow,
  );

  static BoxDecoration get errorContainerDecoration => BoxDecoration(
    color: errorColor.withValues(alpha: 0.1),
    borderRadius: mediumRadius,
    border: Border.all(color: errorColor),
  );

  static BoxDecoration get successContainerDecoration => BoxDecoration(
    color: successColor.withValues(alpha: 0.1),
    borderRadius: mediumRadius,
    border: Border.all(color: successColor),
  );

  static BoxDecoration get inputContainerDecoration => BoxDecoration(
    color: cardColor,
    borderRadius: mediumRadius,
    border: Border.all(color: dividerColor),
  );

  /// Information box decoration (för sourceUrl, metadata etc.)
  static BoxDecoration infoBoxDecoration(BuildContext context) => BoxDecoration(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    borderRadius: mediumRadius,
    border: Border.all(color: Theme.of(context).colorScheme.outline),
  );

  // ===== NYA HELPER-METODER (KRITISKA TILLÄGG) =====

  /// Skapa overlay färg baserat på theme
  static Color overlayColor(BuildContext context) {
    return Theme.of(
      context,
    ).colorScheme.surface.withValues(alpha: overlayOpacity);
  }

  /// Skapa card overlay färg baserat på theme
  static Color cardOverlayColor(BuildContext context) {
    return Theme.of(
      context,
    ).colorScheme.surface.withValues(alpha: cardOverlayOpacity);
  }

  /// Skapa text med konsistent färg baserat på theme
  static TextStyle getTextStyle(
    BuildContext context,
    TextStyle baseStyle, {
    Color? color,
  }) {
    return baseStyle.copyWith(
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );
  }

  /// Error container för felmeddelanden
  static Widget errorContainer(
    BuildContext context,
    String message, {
    IconData? icon,
  }) => Container(
    padding: EdgeInsets.all(spacingMd),
    decoration: BoxDecoration(
      color: errorColor.withValues(alpha: 0.1),
      borderRadius: mediumRadius,
      border: Border.all(color: errorColor),
    ),
    child: Row(
      children: [
        Icon(
          icon ?? Icons.error_outline,
          color: errorColor,
          size: iconSizeInfo,
        ),
        SizedBox(width: spacingSm),
        Expanded(child: Text(message, style: errorTextStyle)),
      ],
    ),
  );

  /// Success container för framgångsmeddelanden
  static Widget successContainer(BuildContext context, String message) =>
      Container(
        padding: EdgeInsets.all(spacingMd),
        decoration: BoxDecoration(
          color: successColor.withValues(alpha: 0.1),
          borderRadius: mediumRadius,
          border: Border.all(color: successColor),
        ),
        child: Row(
          children: [
            successIcon(context),
            SizedBox(width: spacingSm),
            Expanded(child: Text(message, style: successTextStyle)),
          ],
        ),
      );

  /// Filter chip för sök och filter
  static Widget filterChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) => FilterChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onSelected(),
    selectedColor: primaryColor.withValues(alpha: 0.2),
    checkmarkColor: primaryColor,
  );

  /// Choice chip för alternativ
  static Widget choiceChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onSelected(),
    selectedColor: primaryColor.withValues(alpha: 0.2),
  );

  /// Måltidstyp chip med semantiska färger
  static Widget mealTypeChip(String mealType) => Container(
    padding: EdgeInsets.symmetric(horizontal: spacingSm, vertical: 3),
    decoration: mealTypeChipDecoration(_getMealTypeColorForChip(mealType)),
    child: Text(mealType, style: chipOnPrimaryTextStyle),
  );

  /// Tag chip för mindre taggar
  static Widget tagChip(String tag) => Container(
    padding: EdgeInsets.symmetric(horizontal: spacingSm, vertical: 3),
    decoration: tagChipDecoration,
    child: Text(tag, style: chipLabelStyle),
  );

  /// Hjälpfunktion för måltidsfärger
  static Color _getMealTypeColorForChip(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'frukost':
        return frukostColor;
      case 'lunch':
        return lunchColor;
      case 'middag':
        return middagColor;
      case 'dessert':
        return dessertColor;
      case 'mellanmål':
        return mellanmalColor;
      case 'fika':
        return fikaColor;
      default:
        return defaultMealColor;
    }
  }
}
