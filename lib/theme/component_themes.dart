/// Component theme system - barrel export for all component themes.

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
/// All methods now accept [ColorScheme] for dark/light mode awareness.
class ComponentThemes {
  ComponentThemes._();

  // Buttons
  static ElevatedButtonThemeData elevatedButtonTheme(ColorScheme cs) =>
      ButtonThemes.elevatedButtonTheme(cs);
  static FilledButtonThemeData filledButtonTheme(ColorScheme cs) =>
      ButtonThemes.filledButtonTheme(cs);
  static OutlinedButtonThemeData outlinedButtonTheme(ColorScheme cs) =>
      ButtonThemes.outlinedButtonTheme(cs);
  static TextButtonThemeData textButtonTheme(ColorScheme cs) =>
      ButtonThemes.textButtonTheme(cs);
  static IconButtonThemeData iconButtonTheme(ColorScheme cs) =>
      ButtonThemes.iconButtonTheme(cs);
  static FloatingActionButtonThemeData floatingActionButtonTheme(
          ColorScheme cs) =>
      ButtonThemes.floatingActionButtonTheme(cs);

  // Inputs
  static InputDecorationTheme inputDecorationTheme(ColorScheme cs) =>
      InputThemes.inputDecorationTheme(cs);
  static CardThemeData cardTheme(ColorScheme cs) => InputThemes.cardTheme(cs);
  static ListTileThemeData listTileTheme(ColorScheme cs) =>
      InputThemes.listTileTheme(cs);
  static ChipThemeData chipTheme(ColorScheme cs) => InputThemes.chipTheme(cs);

  // Navigation
  static AppBarTheme appBarTheme(ColorScheme cs) =>
      NavigationThemes.appBarTheme(cs);
  static BottomNavigationBarThemeData bottomNavigationBarTheme(
          ColorScheme cs) =>
      NavigationThemes.bottomNavigationBarTheme(cs);
  static TabBarThemeData tabBarTheme(ColorScheme cs) =>
      NavigationThemes.tabBarTheme(cs);
  static DialogThemeData dialogTheme(ColorScheme cs) =>
      NavigationThemes.dialogTheme(cs);
  static BottomSheetThemeData bottomSheetTheme(ColorScheme cs) =>
      NavigationThemes.bottomSheetTheme(cs);

  // Feedback
  static SnackBarThemeData snackBarTheme(ColorScheme cs) =>
      FeedbackThemes.snackBarTheme(cs);
  static DividerThemeData dividerTheme(ColorScheme cs) =>
      FeedbackThemes.dividerTheme(cs);
  static SwitchThemeData switchTheme(ColorScheme cs) =>
      FeedbackThemes.switchTheme(cs);
  static CheckboxThemeData checkboxTheme(ColorScheme cs) =>
      FeedbackThemes.checkboxTheme(cs);
  static RadioThemeData radioTheme(ColorScheme cs) =>
      FeedbackThemes.radioTheme(cs);
  static SliderThemeData sliderTheme(ColorScheme cs) =>
      FeedbackThemes.sliderTheme(cs);
  static ProgressIndicatorThemeData progressIndicatorTheme(ColorScheme cs) =>
      FeedbackThemes.progressIndicatorTheme(cs);

  // Named styles (accept ColorScheme)
  static ButtonStyle primaryButtonStyle(ColorScheme cs) =>
      ButtonThemes.primaryButtonStyle(cs);
  static ButtonStyle textButtonStyle(ColorScheme cs) =>
      ButtonThemes.textButtonStyle(cs);
  static ButtonStyle secondaryButtonStyle(ColorScheme cs) =>
      ButtonThemes.secondaryButtonStyle(cs);
  static ButtonStyle dangerButtonStyle(ColorScheme cs) =>
      ButtonThemes.dangerButtonStyle(cs);
  static ButtonStyle outlinedButtonStyle(ColorScheme cs) =>
      ButtonThemes.outlinedButtonStyleNamed(cs);
  static ButtonStyle deleteButtonStyle(ColorScheme cs) =>
      ButtonThemes.deleteButtonStyle(cs);
  static ButtonStyle extendedFabStyle(ColorScheme cs) =>
      ButtonThemes.extendedFabStyle(cs);

  // BoxDecorations (still static, not theme-dependent)
  static BoxDecoration get trendingRecipeCardDecoration =>
      InputThemes.trendingRecipeCardDecoration;
  static BoxDecoration get activityTimelineItemDecoration =>
      InputThemes.activityTimelineItemDecoration;
  static BoxDecoration get emptyStateContainerDecoration =>
      InputThemes.emptyStateContainerDecoration;
}
