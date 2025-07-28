// lib/views/edit_recipe/edit_recipe_banners.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/collaborative_status_viewmodel.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/services/social_recipe_service.dart';
import 'package:butlery/core/injection.dart';

/// Banner components for edit recipe view
class EditRecipeBanners {
  
  /// Build smart banners showing both collaborative and permissions status
  static Widget buildSmartBanners(BuildContext context, Recipe recipe) {
    return Consumer2<CollaborativeStatusViewModel, RecipeFormViewModel>(
      builder: (context, collaborativeViewModel, recipeViewModel, child) {
        return Column(
          children: [
            // 1. Collaborative banner (if recipe is shared)
            _buildCollaborativeBanner(context, recipe),

            // 2. Permissions banner (shows edit mode)
            SocialComponents.smartPermissionsBanner(
              context: context,
              viewModel: recipeViewModel,
            ),
          ],
        );
      },
    );
  }

  /// Build collaborative banner with debug information
  static Widget _buildCollaborativeBanner(BuildContext context, Recipe recipe) {
    return Consumer<CollaborativeStatusViewModel>(
      builder: (context, collaborativeViewModel, child) {
        // Debug collaborative status check
        debugPrint('🔍 === COLLABORATIVE DEBUG START ===');
        debugPrint('🔍 Recipe ID: ${recipe.id}');
        debugPrint('🔍 Recipe owner: ${recipe.createdBy}');

        final socialService = sl<SocialRecipeService>();
        for (final shared in socialService.sharedWithMe) {
          debugPrint(
              '🔍 Shared recipe: ${shared.originalRecipeId} by ${shared.sharedByUserId}');
          if (shared.originalRecipeId == recipe.id) {
            debugPrint('🔍 ⭐ MATCH! This recipe IS shared!');
          }
        }

        // Get collaborative status using new API
        final status = collaborativeViewModel.getRecipeCollaborativeStatus(
          recipe.id,
          recipe,
        );

        final isCollaborative = status.isCollaborative;

        debugPrint(
            '🔍 CollaborativeStatusViewModel says isCollaborative: $isCollaborative');
        debugPrint('🔍 Participants: ${status.participants.length}');
        debugPrint('🔍 === COLLABORATIVE DEBUG END ===');

        if (!isCollaborative) {
          debugPrint('🔍 ❌ No collaborative banner shown');
          return const SizedBox.shrink();
        }

        debugPrint('🔍 ✅ Showing collaborative banner with real participants');
        return SocialComponents.collaborativeBanner(
          title: 'Du redigerar tillsammans med andra',
          subtitle: 'Ändringar synkas automatiskt med andra deltagare',
          context: context,
          contentId: recipe.id,
          contentType: 'recipe',
        );
      },
    );
  }
}