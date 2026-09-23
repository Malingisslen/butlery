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
    ColorScheme cs,
  ) => ButtonThemes.floatingActionButtonTheme(cs);

  // Inputs
  static InputDecorationTheme inputDecorationTheme(ColorScheme cs) =>
      InputThemes.inputDecorationTheme(cs);
  static CardThemeData cardTheme(ColorScheme cs) => InputThemes.cardTheme(cs);
  static ListTileThemeData listTileTheme(ColorScheme cs) =>
      InputThemes.listTileTheme(cs);

  /// The chip with its locked geometry (P5-U34): 13 px across and 7 px
  /// down inside a 1 px edge, a pill, and the label straight after the
  /// padding (tokens.json controls.chip, :824-832; Komponentark v1:33 "Låst
  /// geometri" and §03 :134-140, `padding:7px 13px`). That makes the visible
  /// chip 34 px high, as drawn ("Synlig 80 × 34"), inside the 48 dp hit
  /// area. A selected chip's check is followed by the label with no extra
  /// padding: the 18 dp check box then puts the label where the drawing's
  /// 12 px check and 6 px gap do.
  static ChipThemeData chipTheme(ColorScheme cs) =>
      InputThemes.chipTheme(cs).copyWith(
        padding: chipPadding,
        labelPadding: EdgeInsetsDirectional.zero,
      );

  /// tokens.json controls.chip paddingX 13, paddingY 7.
  static const EdgeInsets chipPadding = EdgeInsets.symmetric(
    horizontal: 13,
    vertical: 7,
  );

  // Navigation
  static AppBarTheme appBarTheme(ColorScheme cs) =>
      NavigationThemes.appBarTheme(cs);
  static BottomNavigationBarThemeData bottomNavigationBarTheme(
    ColorScheme cs,
  ) => NavigationThemes.bottomNavigationBarTheme(cs);
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
  static ScrollbarThemeData scrollbarTheme(ColorScheme cs) =>
      FeedbackThemes.scrollbarTheme(cs);

  // Named styles (accept ColorScheme)
  static ButtonStyle primaryButtonStyle(ColorScheme cs) =>
      ButtonThemes.primaryButtonStyle(cs);
  static ButtonStyle heroButtonStyle(ColorScheme cs) =>
      ButtonThemes.heroButtonStyle(cs);
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
