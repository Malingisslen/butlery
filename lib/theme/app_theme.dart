// lib/theme/app_theme.dart

import 'package:flutter/material.dart';

/// Centraliserat theme-system för Butlery-appen
/// Baserat på Figma-prototypen med Material 3 design
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
  // Oanvända färger som vi kanske kommer använda senare:
  // static const Color _buttonBlue = Color(0xFF3B82F6); // Knappfärg
  // static const Color _cardShadow = Color(0x0A000000); // Subtil skugga

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

  // ===== TYPOGRAFI (FÖRBÄTTRAD) =====

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
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: _divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: _divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: _primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: _error),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

  // ===== STANDARDISERADE SIZED BOXES (GAPS) =====

  /// Förkonfigurerade SizedBox widgets för vanliga mellanrum
  static Widget get tinyGap => SizedBox(height: spacingXs); // 4px
  static Widget get smallGap => SizedBox(height: spacingSm); // 8px
  static Widget get mediumGap => SizedBox(height: spacingMd); // 16px
  static Widget get largeGap => SizedBox(height: spacingLg); // 24px
  static Widget get extraLargeGap => SizedBox(height: spacingXl); // 32px
  static Widget get hugeGap => SizedBox(height: spacingXxl); // 48px

  // ===== BORDER RADIUS (UTÖKADE) =====

  static const double radiusSmall = 4.0;
  static const double radiusMedium = 8.0;
  static const double radiusLarge = 12.0;
  static const double radiusXLarge = 16.0;
  static const double radiusRound = 35.0; // För runda bilder

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
    borderRadius: BorderRadius.circular(16.0),
    boxShadow: cardShadow,
  );

  /// Runda receptbilder decoration
  static BoxDecoration get recipeImageDecoration => BoxDecoration(
    borderRadius: BorderRadius.circular(35.0),
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
      BoxDecoration(color: color, borderRadius: BorderRadius.circular(6.0));

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

  // ===== STANDARDISERADE TEXT STYLES =====

  /// Återkommande text styles som används i flera komponenter
  static TextStyle get errorTextStyle =>
      TextStyle(color: errorColor, fontSize: 14, fontWeight: FontWeight.w500);

  static TextStyle get buttonTextStyle =>
      TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5);

  static TextStyle get sectionTitleStyle => TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.3,
  );

  static TextStyle get cardTitleStyle => TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.3,
  );

  static TextStyle get captionStyle => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textTertiary,
    letterSpacing: 0.3,
  );

  // ===== STANDARDISERADE BUTTON STYLES =====

  /// Förkonfigurerade ButtonStyle för konsistenta knappar
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
    minimumSize: const Size(double.infinity, 56),
    padding: buttonPadding,
    textStyle: buttonTextStyle,
    shape: RoundedRectangleBorder(borderRadius: largeRadius),
  );

  static ButtonStyle get secondaryButtonStyle => OutlinedButton.styleFrom(
    minimumSize: const Size(double.infinity, 56),
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
}
