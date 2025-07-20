// lib/views/realtime/components/menu_app_bar.dart

import 'package:flutter/material.dart';
import '../../../viewmodels/realtime_menu_viewmodel.dart';
import '../../../widgets/common/navigation_components.dart';
import '../handlers/menu_action_handler.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_dimensions.dart';

/// App bar komponent för realtidsmenyer
class MenuAppBar extends StatelessWidget {
  final RealtimeMenuViewModel viewModel;
  final MenuActionHandler actionHandler;

  const MenuAppBar({
    super.key,
    required this.viewModel,
    required this.actionHandler,
  });

  @override
  Widget build(BuildContext context) {
    final menu = viewModel.currentMenu;

    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      flexibleSpace: FlexibleSpaceBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              menu?.menuTitle ?? 'Laddar meny...',
              style: AppTextStyles.titleMedium,
            ),
            if (menu != null) ...[
              const SizedBox(height: AppDimensions.spacingXs),
              Text(
                '${menu.categoriesWithRecipes} kategorier • ${menu.totalRecipeCount} recept',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMedium),
              ),
            ],
          ],
        ),
        titlePadding: const EdgeInsets.all(AppDimensions.paddingL),
      ),
      actions: [
        // ✅ UPPDATERAD: Använder NavigationComponents.realtimeStatus()
        NavigationComponents.realtimeStatus(
          isOnline: viewModel.isOnline,
          statusDescription: viewModel.connectionStatusDescription,
          statusEmoji: viewModel.connectionStatusEmoji,
        ),

        // Participant toggle
        _buildParticipantButton(context),

        // Menu options
        _buildMenuOptions(context),
      ],
    );
  }

  Widget _buildParticipantButton(BuildContext context) {
    return IconButton(
      icon: Stack(
        children: [
          const Icon(Icons.people),
          if (viewModel.activeParticipantCount > 1)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: EdgeInsets.all(AppDimensions.spacingXs),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusRound),
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  '${viewModel.activeParticipantCount}',
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.cardWhite),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      onPressed: viewModel.toggleParticipants,
      tooltip: 'Visa deltagare',
    );
  }

  Widget _buildMenuOptions(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: actionHandler.handleAction,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'refresh',
          child: Row(
            children: [
              const Icon(Icons.refresh),
              const SizedBox(width: AppDimensions.spacingM),
              Text('Uppdatera', style: AppTextStyles.bodyLarge),
            ],
          ),
        ),
        if (viewModel.canManageParticipants) ...[
          PopupMenuItem(
            value: 'invite',
            child: Row(
              children: [
                const Icon(Icons.person_add),
                const SizedBox(width: AppDimensions.spacingM),
                Text('Bjud in', style: AppTextStyles.bodyLarge),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'permissions',
            child: Row(
              children: [
                const Icon(Icons.security),
                const SizedBox(width: AppDimensions.spacingM),
                Text('Hantera behörigheter', style: AppTextStyles.bodyLarge),
              ],
            ),
          ),
        ],
        PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              const Icon(Icons.copy),
              const SizedBox(width: AppDimensions.spacingM),
              Text('Skapa personlig kopia', style: AppTextStyles.bodyLarge),
            ],
          ),
        ),
        if (viewModel.canManageParticipants)
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, color: AppColors.error),
                const SizedBox(width: AppDimensions.spacingM),
                Text('Ta bort meny', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error)),
              ],
            ),
          ),
      ],
    );
  }
}
