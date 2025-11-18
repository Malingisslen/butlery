/// Component theme system - barrel export for all component themes.
/// This file maintains backward compatibility while organizing themes
/// into logical groupings.

export 'components/button_themes.dart';
export 'components/input_themes.dart';
export 'components/navigation_themes.dart';
export 'components/feedback_themes.dart';

import 'package:flutter/material.dart';
import 'package:butlery/theme/components/button_themes.dart';
import 'package:butlery/theme/components/input_themes.dart';
import 'package:butlery/theme/components/navigation_themes.dart';
import 'package:butlery/theme/components/feedback_themes.dart';

/// Legacy facade maintaining existing API for backward compatibility.
/// New code should import specific theme files directly:
/// - `import 'package:butlery/theme/components/button_themes.dart';`
/// - `import 'package:butlery/theme/components/input_themes.dart';`
/// - `import 'package:butlery/theme/components/navigation_themes.dart';`
/// - `import 'package:butlery/theme/components/feedback_themes.dart';`
class ComponentThemes {
  /// Private constructor
  ComponentThemes._();

  // ===== BUTTON THEMES =====
  static ElevatedButtonThemeData get elevatedButtonTheme => ButtonThemes.elevatedButtonTheme;
  static FilledButtonThemeData get filledButtonTheme => ButtonThemes.filledButtonTheme;
  static OutlinedButtonThemeData get outlinedButtonTheme => ButtonThemes.outlinedButtonTheme;
  static TextButtonThemeData get textButtonTheme => ButtonThemes.textButtonTheme;
  static IconButtonThemeData get iconButtonTheme => ButtonThemes.iconButtonTheme;
  static FloatingActionButtonThemeData get floatingActionButtonTheme => ButtonThemes.floatingActionButtonTheme;

  // ===== INPUT THEMES =====
  static InputDecorationTheme get inputDecorationTheme => InputThemes.inputDecorationTheme;
  static CardThemeData get cardTheme => InputThemes.cardTheme;
  static ListTileThemeData get listTileTheme => InputThemes.listTileTheme;
  static ChipThemeData get chipTheme => InputThemes.chipTheme;

  // ===== NAVIGATION THEMES =====
  static AppBarTheme get appBarTheme => NavigationThemes.appBarTheme;
  static BottomNavigationBarThemeData get bottomNavigationBarTheme => NavigationThemes.bottomNavigationBarTheme;
  static TabBarThemeData get tabBarTheme => NavigationThemes.tabBarTheme;
  static DialogThemeData get dialogTheme => NavigationThemes.dialogTheme;
  static BottomSheetThemeData get bottomSheetTheme => NavigationThemes.bottomSheetTheme;

  // ===== FEEDBACK THEMES =====
  static SnackBarThemeData get snackBarTheme => FeedbackThemes.snackBarTheme;
  static DividerThemeData get dividerTheme => FeedbackThemes.dividerTheme;
  static SwitchThemeData get switchTheme => FeedbackThemes.switchTheme;
  static CheckboxThemeData get checkboxTheme => FeedbackThemes.checkboxTheme;
  static RadioThemeData get radioTheme => FeedbackThemes.radioTheme;
  static SliderThemeData get sliderTheme => FeedbackThemes.sliderTheme;
  static ProgressIndicatorThemeData get progressIndicatorTheme => FeedbackThemes.progressIndicatorTheme;

  // ===== BUTTON STYLES =====
  static ButtonStyle get primaryButtonStyle => ButtonThemes.primaryButtonStyle;
  static ButtonStyle get textButtonStyle => ButtonThemes.textButtonStyle;
  static ButtonStyle get secondaryButtonStyle => ButtonThemes.secondaryButtonStyle;
  static ButtonStyle get dangerButtonStyle => ButtonThemes.dangerButtonStyle;
  static ButtonStyle get outlinedButtonStyle => ButtonThemes.outlinedButtonStyle;
  static ButtonStyle get deleteButtonStyle => ButtonThemes.deleteButtonStyle;
  static ButtonStyle get extendedFabStyle => ButtonThemes.extendedFabStyle;

  // ===== BOX DECORATIONS =====
  static BoxDecoration get trendingRecipeCardDecoration => InputThemes.trendingRecipeCardDecoration;
  static BoxDecoration get activityTimelineItemDecoration => InputThemes.activityTimelineItemDecoration;
  static BoxDecoration get emptyStateContainerDecoration => InputThemes.emptyStateContainerDecoration;
}
