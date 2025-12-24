// lib/widgets/common/dialogs/recipe_selection_dialogs.dart - FACADE PATTERN

import 'package:flutter/material.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/recipe_unified.dart';

// Focused Components
import 'package:butlery/widgets/common/dialogs/recipe_selection/friend_recipe_sharing_dialog.dart';
import 'package:butlery/widgets/common/dialogs/recipe_selection/menu_recipe_selection_dialog.dart';

/// Recipe Selection Dialogs API
/// This class provides a unified API for recipe selection dialogs:
/// - Friend recipe sharing dialog for social sharing
/// - Menu recipe selection dialog for category management
/// MIGRATION GUIDE:
/// ```dart
/// // Before: No change needed
/// RecipeSelectionDialogs.showRecipeSelector(context, friend: friend);
/// RecipeSelectionDialogs.showMenuRecipeSelector(context, categoryName: 'Lunch');
/// ```
class RecipeSelectionDialogs {
  /// 🤝 Dialog för att välja recept att dela med en vän
  /// Replaces: RecipeSelectionDialog
  static Future<void> showRecipeSelector(
    BuildContext context, {
    required UserProfile friend,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => FriendRecipeSharingDialog(friend: friend),
    );
  }

  /// 📋 Dialog för att välja recept för meny-kategori
  /// Replaces: MenuRecipeSelectionDialog
  static Future<List<Recipe>?> showMenuRecipeSelector(
    BuildContext context, {
    required String categoryName,
  }) async {
    return await showDialog<List<Recipe>>(
      context: context,
      builder: (context) =>
          MenuRecipeSelectionDialog(categoryName: categoryName),
    );
  }
}
