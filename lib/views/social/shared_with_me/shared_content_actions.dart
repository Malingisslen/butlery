// lib/views/social/shared_with_me/shared_content_actions.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/viewmodels/shared_content_viewmodel.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/models/shared_menu.dart';

/// SharedContentActions - Action methods for shared content
///
/// Handles import, dismiss, and other actions for shared content.
class SharedContentActions {
  /// Import a shared recipe
  static Future<void> importRecipe(
    BuildContext context,
    SharedContentViewModel viewModel,
    SharedRecipe sharedRecipe,
  ) async {
    final success = await viewModel.importSharedRecipe(sharedRecipe);

    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '✅ Recept "${sharedRecipe.recipeSnapshot.title}" importerat!'),
          backgroundColor: AppColors.success,
        ),
      );
    } else if (context.mounted && viewModel.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(viewModel.error!),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// Import a shared menu
  static Future<void> importMenu(
    BuildContext context,
    SharedContentViewModel viewModel,
    SharedMenu sharedMenu,
  ) async {
    final success = await viewModel.importSharedMenu(sharedMenu);

    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Meny "${sharedMenu.menuTitle}" importerad!'),
          backgroundColor: AppColors.success,
        ),
      );
    } else if (context.mounted && viewModel.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(viewModel.error!),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// Dismiss a shared recipe
  static Future<void> dismissRecipe(
    BuildContext context,
    SharedContentViewModel viewModel,
    SharedRecipe sharedRecipe,
  ) async {
    final shouldDismiss = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dölj recept'),
        content: Text(
          'Vill du dölja "${sharedRecipe.recipeSnapshot.title}" från din lista?\n\n'
          'Du kan fortfarande komma åt receptet genom att söka eller be '
          '${sharedRecipe.sharedByDisplayName} att dela det igen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Dölj'),
          ),
        ],
      ),
    );

    if (shouldDismiss == true) {
      final success = await viewModel.dismissSharedRecipe(sharedRecipe);

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ "${sharedRecipe.recipeSnapshot.title}" dolt från din lista'),
            backgroundColor: AppColors.success,
            action: SnackBarAction(
              label: 'Ångra',
              onPressed: () => viewModel.undismissSharedRecipe(sharedRecipe),
            ),
          ),
        );
      } else if (context.mounted && viewModel.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(viewModel.error!),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Dismiss a shared menu
  static Future<void> dismissMenu(
    BuildContext context,
    SharedContentViewModel viewModel,
    SharedMenu sharedMenu,
  ) async {
    final shouldDismiss = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dölj meny'),
        content: Text(
          'Vill du dölja "${sharedMenu.menuTitle}" från din lista?\n\n'
          'Du kan fortfarande komma åt menyn genom att be '
          '${sharedMenu.sharedByDisplayName} att dela den igen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Dölj'),
          ),
        ],
      ),
    );

    if (shouldDismiss == true) {
      final success = await viewModel.dismissSharedMenu(sharedMenu);

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ "${sharedMenu.menuTitle}" dold från din lista'),
            backgroundColor: AppColors.success,
            action: SnackBarAction(
              label: 'Ångra',
              onPressed: () => viewModel.undismissSharedMenu(sharedMenu),
            ),
          ),
        );
      } else if (context.mounted && viewModel.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(viewModel.error!),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}