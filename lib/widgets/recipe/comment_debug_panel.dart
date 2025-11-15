// lib/widgets/recipe/comment_debug_panel.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/user_service.dart';

/// Debug panel for comment system showing user authentication and profile state.
/// Only displayed in debug mode to help developers diagnose authentication issues.
class CommentDebugPanel extends StatelessWidget {
  final SocialRecipeViewModel socialViewModel;
  final Function(String message) onShowMessage;

  const CommentDebugPanel({
    super.key,
    required this.socialViewModel,
    required this.onShowMessage,
  });

  @override
  Widget build(BuildContext context) {
    final userService = ServiceLocator.get<UserService>();
    final authUser = socialViewModel.currentUser;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingS),
      color: AppColors.warning.withValues(alpha: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🔍 DEBUG INFO:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          Text(
              'SocialViewModel.currentUser: ${socialViewModel.currentUser?.displayName ?? "NULL"}'),
          Text(
              'UserService.currentUserProfile: ${userService.currentUserProfile?.displayName ?? "NULL"}'),
          Text(
              'SocialViewModel.currentUser.email: ${authUser?.email ?? "NULL"}'),
          Text('UserService loading: ${userService.isLoading}'),
          Text('UserService error: ${userService.error ?? "none"}'),
          const SizedBox(height: AppDimensions.spacingM),
          if (authUser != null && userService.currentUserProfile == null)
            ElevatedButton(
              onPressed: () async {
                final displayName = authUser.displayName.isNotEmpty
                    ? authUser.displayName
                    : (authUser.email.split('@')[0]);

                final profile = await userService.createOrUpdateProfile(
                  displayName: displayName,
                  isSearchable: true,
                  allowEmailSearch: false,
                );

                if (profile != null) {
                  onShowMessage('Profil skapad! Starta om appen.');
                }
              },
              child: const Text('Skapa Profil'),
            ),
        ],
      ),
    );
  }
}
