// lib/views/realtime/components/menu_app_bar.dart

import 'package:flutter/material.dart';
import '../../../viewmodels/realtime_menu_viewmodel.dart';
import '../../../widgets/common/navigation_components.dart';
import '../handlers/menu_action_handler.dart';
import '../../../theme/app_theme.dart';

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
              style: AppTheme.cardTitleStyle,
            ),
            if (menu != null) ...[
              AppTheme.tinyGap,
              Text(
                '${menu.categoriesWithRecipes} kategorier • ${menu.totalRecipeCount} recept',
                style: AppTheme.metadataStyle,
              ),
            ],
          ],
        ),
        titlePadding: AppTheme.cardPadding,
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
          AppTheme.actionIcon(context, Icons.people),
          if (viewModel.activeParticipantCount > 1)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: EdgeInsets.all(AppTheme.spacingXs),
                decoration: BoxDecoration(
                  color: AppTheme.successColor,
                  borderRadius: AppTheme.chipRadius,
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  '${viewModel.activeParticipantCount}',
                  style: AppTheme.chipOnPrimaryTextStyle,
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
              AppTheme.actionIcon(context, Icons.refresh),
              AppTheme.smallHorizontalGap,
              Text('Uppdatera', style: AppTheme.bodyStyle),
            ],
          ),
        ),
        if (viewModel.canManageParticipants) ...[
          PopupMenuItem(
            value: 'invite',
            child: Row(
              children: [
                AppTheme.actionIcon(context, Icons.person_add),
                AppTheme.smallHorizontalGap,
                Text('Bjud in', style: AppTheme.bodyStyle),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'permissions',
            child: Row(
              children: [
                AppTheme.actionIcon(context, Icons.security),
                AppTheme.smallHorizontalGap,
                Text('Hantera behörigheter', style: AppTheme.bodyStyle),
              ],
            ),
          ),
        ],
        PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              AppTheme.actionIcon(context, Icons.copy),
              AppTheme.smallHorizontalGap,
              Text('Skapa personlig kopia', style: AppTheme.bodyStyle),
            ],
          ),
        ),
        if (viewModel.canManageParticipants)
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                AppTheme.actionIcon(context, Icons.delete,
                    color: AppTheme.errorColor),
                AppTheme.smallHorizontalGap,
                Text('Ta bort meny', style: AppTheme.errorTextStyle),
              ],
            ),
          ),
      ],
    );
  }
}
