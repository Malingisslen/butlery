import 'package:flutter/material.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/recipe_unified.dart';

// Import focused modules
import 'package:butlery/widgets/common/dialogs/recipe_selection_dialogs.dart';
import 'package:butlery/widgets/common/indicators/realtime_indicators.dart';

/// Facade for navigation components. Delegates to specialized navigation modules.
class NavigationComponents {
  /// Dialog for selecting recipes to share with a friend.
  static Future<void> showRecipeSelector(
    BuildContext context, {
    required UserProfile friend,
  }) async {
    return RecipeSelectionDialogs.showRecipeSelector(
      context,
      friend: friend,
    );
  }

  /// Dialog for selecting recipes for a menu category.
  static Future<List<Recipe>?> showMenuRecipeSelector(
    BuildContext context, {
    required String categoryName,
  }) async {
    return RecipeSelectionDialogs.showMenuRecipeSelector(
      context,
      categoryName: categoryName,
    );
  }

  /// Connection status indicator.
  static Widget realtimeStatus({
    required bool isOnline,
    required String statusDescription,
    required String statusEmoji,
    bool showText = false,
    EdgeInsets? padding,
  }) {
    return RealtimeIndicators.realtimeStatus(
      isOnline: isOnline,
      statusDescription: statusDescription,
      statusEmoji: statusEmoji,
      showText: showText,
      padding: padding,
    );
  }

  /// Expanded status banner for larger displays.
  static Widget realtimeStatusBanner({
    required bool isOnline,
    required String statusDescription,
    required String statusEmoji,
    VoidCallback? onRetry,
  }) {
    return RealtimeIndicators.realtimeStatusBanner(
      isOnline: isOnline,
      statusDescription: statusDescription,
      statusEmoji: statusEmoji,
      onRetry: onRetry,
    );
  }
}
