// lib/views/edit_recipe/edit_recipe_app_bar.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/collaborative_status_viewmodel.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// AppBar component for edit recipe view with collaborative status
class EditRecipeAppBar {
  
  /// Build AppBar with collaborative status indicator
  static PreferredSizeWidget build(BuildContext context, Recipe recipe) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Consumer<CollaborativeStatusViewModel>(
        builder: (context, collaborativeViewModel, child) {
          // Get collaborative status using new API
          final status = collaborativeViewModel.getRecipeCollaborativeStatus(
            recipe.id,
            recipe,
          );

          final isCollaborative = status.isCollaborative;

          return AppBar(
            title: const Text('Redigera recept'),
            backgroundColor: isCollaborative
                ? AppColors.primaryBlue.withValues(alpha: 0.1)
                : null,
            actions: [
              if (isCollaborative)
                Padding(
                  padding: const EdgeInsets.only(right: AppDimensions.spacingL),
                  child: Center(
                    child: SocialComponents.collaborativeStatusBadge(
                      text: 'Delat',
                      icon: Icons.people,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}