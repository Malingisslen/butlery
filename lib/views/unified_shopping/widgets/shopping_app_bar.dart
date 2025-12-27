// lib/views/unified_shopping/widgets/shopping_app_bar.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/component_themes.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/common/icons/adaptive_icon.dart';

/// App bar actions for shopping view
class ShoppingAppBar {
  static List<Widget> buildActions(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    VoidCallback onCreateList,
    VoidCallback onShowShareDialog,
    VoidCallback onShareExternally,
    VoidCallback onShowSyncStatus,
  ) {
    final canShare = viewModel.hasItems;

    return [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ny lista-knapp
          Semantics(
            label: 'Ny lista',
            button: true,
            enabled: true,
            child: IconButton(
              icon: Icon(
                AdaptiveIcons.add,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
              onPressed: onCreateList,
              tooltip: 'Ny lista',
            ),
          ),

          // Dela med vänner-knapp (social)
          Semantics(
            label: canShare ? 'Dela med vänner' : 'Inga artiklar att dela',
            button: true,
            enabled: canShare,
            child: IconButton(
              icon: Icon(
                AdaptiveIcons.peopleOutlined,
                color: canShare
                    ? Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7)
                    : AppColors.textTertiary,
              ),
              onPressed: canShare ? onShowShareDialog : null,
              tooltip: canShare ? 'Dela med vänner' : 'Inga artiklar att dela',
            ),
          ),

          // Dela externt-knapp
          Semantics(
            label: canShare ? 'Dela externt' : 'Inga artiklar att dela',
            button: true,
            enabled: canShare,
            child: IconButton(
              icon: Icon(
                AdaptiveIcons.share,
                color: canShare
                    ? Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7)
                    : AppColors.textTertiary,
              ),
              onPressed: canShare ? onShareExternally : null,
              tooltip: canShare ? 'Dela externt' : 'Inga artiklar att dela',
            ),
          ),

          // Sharing status indicator
          Container(
            margin: const EdgeInsetsDirectional.only(start: 8),
            child: Semantics(
              label: _getSharingStatusTooltip(viewModel),
              button: true,
              enabled: true,
              child: IconButton(
                icon: Icon(
                  _getSharingStatusIcon(viewModel),
                  color: _getSharingStatusColor(viewModel),
                ),
                onPressed: () => onShowSyncStatus(),
                tooltip: _getSharingStatusTooltip(viewModel),
              ),
            ),
          ),
        ],
      ),
    ];
  }

  static Widget buildFloatingActionButton(
    BuildContext context,
    VoidCallback onAddItem,
  ) {
    return Semantics(
      label: 'Lägg till vara',
      button: true,
      enabled: true,
      child: ElevatedButton.icon(
        onPressed: onAddItem,
        style: ComponentThemes.extendedFabStyle,
        icon: Icon(
          AdaptiveIcons.add,
          color: AppColors.cardWhite,
        ),
        label: const Text('Lägg till vara'),
      ),
    );
  }

  /// Get the appropriate icon for sharing status based on list type and user permissions
  static IconData _getSharingStatusIcon(UnifiedShoppingViewModel viewModel) {
    final activeList = viewModel.activeList;
    if (activeList == null) return AdaptiveIcons.person;

    switch (activeList.type) {
      case ListType.personal:
        return AdaptiveIcons.person;
      case ListType.collaborative:
        final permissionService = ServiceLocator.get<PermissionService>();
        final currentUserId = permissionService.currentUser?.uid;
        if (currentUserId == null) return AdaptiveIcons.people;

        final userPermission = activeList.memberPermissions[currentUserId];
        switch (userPermission) {
          case SharedListPermission.view:
            return AdaptiveIcons.visibility;
          case SharedListPermission.edit:
            return AdaptiveIcons.people;
          case SharedListPermission.admin:
            return Icons.admin_panel_settings; // No SF Symbol equivalent
          default:
            // If not in permissions map, check if owner
            return activeList.ownerId == currentUserId
                ? Icons.admin_panel_settings // No SF Symbol equivalent
                : AdaptiveIcons.people;
        }
      case ListType.template:
        return AdaptiveIcons.bookmark;
    }
  }

  /// Get the appropriate color for sharing status based on list type and user permissions
  static Color _getSharingStatusColor(UnifiedShoppingViewModel viewModel) {
    final activeList = viewModel.activeList;
    if (activeList == null) return AppColors.primaryBlue;

    switch (activeList.type) {
      case ListType.personal:
        return AppColors.primaryBlue;
      case ListType.collaborative:
        final permissionService = ServiceLocator.get<PermissionService>();
        final currentUserId = permissionService.currentUser?.uid;
        if (currentUserId == null) return AppColors.primaryBlue;

        final userPermission = activeList.memberPermissions[currentUserId];
        switch (userPermission) {
          case SharedListPermission.view:
            return AppColors.textMedium; // Subtle for view-only
          case SharedListPermission.edit:
            return AppColors.accent; // Trusted access
          case SharedListPermission.admin:
            return AppColors.primaryBlue; // Blue for admin
          default:
            // If not in permissions map, check if owner (admin)
            return activeList.ownerId == currentUserId
                ? AppColors.primaryBlue
                : AppColors.accent;
        }
      case ListType.template:
        return AppColors.textMedium;
    }
  }

  /// Get the appropriate tooltip for sharing status based on list type and user permissions
  static String _getSharingStatusTooltip(UnifiedShoppingViewModel viewModel) {
    final activeList = viewModel.activeList;
    if (activeList == null) return 'Lista';

    switch (activeList.type) {
      case ListType.personal:
        return 'Personlig lista';
      case ListType.collaborative:
        final permissionService = ServiceLocator.get<PermissionService>();
        final currentUserId = permissionService.currentUser?.uid;
        if (currentUserId == null) return 'Delad lista';

        final userPermission = activeList.memberPermissions[currentUserId];
        final memberCount = activeList.memberPermissions.length +
            (activeList.memberPermissions.containsKey(activeList.ownerId)
                ? 0
                : 1);

        String permissionText;
        switch (userPermission) {
          case SharedListPermission.view:
            permissionText = 'Kan bara se';
            break;
          case SharedListPermission.edit:
            permissionText = 'Kan redigera';
            break;
          case SharedListPermission.admin:
            permissionText = 'Administratör';
            break;
          default:
            // If not in permissions map, check if owner
            permissionText = activeList.ownerId == currentUserId
                ? 'Administratör'
                : 'Kan redigera';
        }

        return 'Delad med $memberCount medlemmar - $permissionText';
      case ListType.template:
        return 'Mall-lista';
    }
  }
}
