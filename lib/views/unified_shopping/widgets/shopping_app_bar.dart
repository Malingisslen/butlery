// lib/views/unified_shopping/widgets/shopping_app_bar.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/component_themes.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/common/icons/adaptive_icon.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

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
            label: context.l10n.shoppingNewList,
            button: true,
            enabled: true,
            child: IconButton(
              icon: Icon(
                AdaptiveIcons.add,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: AppDimensions.opacityDark),
              ),
              onPressed: onCreateList,
              tooltip: context.l10n.shoppingNewList,
            ),
          ),

          // Dela med vänner-knapp (social)
          Semantics(
            label: canShare
                ? context.l10n.a11yShareWithFriends
                : context.l10n.a11yNoItemsToShare,
            button: true,
            enabled: canShare,
            child: IconButton(
              icon: Icon(
                AdaptiveIcons.peopleOutlined,
                color: canShare
                    ? Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: AppDimensions.opacityDark)
                    : AppColors.textTertiary,
              ),
              onPressed: canShare ? onShowShareDialog : null,
              tooltip: canShare
                  ? context.l10n.shoppingShareWithFriends
                  : context.l10n.shoppingNoItemsToShare,
            ),
          ),

          // Dela externt-knapp
          Semantics(
            label: canShare
                ? context.l10n.a11yShareExternally
                : context.l10n.a11yNoItemsToShare,
            button: true,
            enabled: canShare,
            child: IconButton(
              icon: Icon(
                AdaptiveIcons.share,
                color: canShare
                    ? Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: AppDimensions.opacityDark)
                    : AppColors.textTertiary,
              ),
              onPressed: canShare ? onShareExternally : null,
              tooltip: canShare
                  ? context.l10n.shoppingShareExternally
                  : context.l10n.shoppingNoItemsToShare,
            ),
          ),

          // Sharing status indicator
          Container(
            margin: AppDimensions.marginDirectionalOnlyStart8,
            child: Semantics(
              label: _getSharingStatusTooltip(context, viewModel),
              button: true,
              enabled: true,
              child: IconButton(
                icon: Icon(
                  _getSharingStatusIcon(viewModel),
                  color: _getSharingStatusColor(viewModel),
                ),
                onPressed: () => onShowSyncStatus(),
                tooltip: _getSharingStatusTooltip(context, viewModel),
              ),
            ),
          ),
        ],
      ),
    ];
  }

  /// Build header actions for MainViewHeader (UI Redesign)
  /// Uses headerForeground color for icons
  static List<Widget> buildHeaderActions(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    VoidCallback onCreateList,
    VoidCallback onShowShareDialog,
    VoidCallback onShareExternally,
    VoidCallback onShowSyncStatus,
  ) {
    final canShare = viewModel.hasItems;

    return [
      // Ny lista-knapp
      IconButton(
        icon: Icon(
          AdaptiveIcons.add,
          color: AppColors.headerForeground,
        ),
        onPressed: onCreateList,
        tooltip: context.l10n.shoppingNewList,
      ),

      // Dela med vänner-knapp (social)
      if (canShare)
        IconButton(
          icon: Icon(
            AdaptiveIcons.peopleOutlined,
            color: AppColors.headerForeground,
          ),
          onPressed: onShowShareDialog,
          tooltip: context.l10n.shoppingShareWithFriends,
        ),

      // Dela externt-knapp
      if (canShare)
        IconButton(
          icon: Icon(
            AdaptiveIcons.share,
            color: AppColors.headerForeground,
          ),
          onPressed: onShareExternally,
          tooltip: context.l10n.shoppingShareExternally,
        ),

      // Sharing status indicator
      IconButton(
        icon: Icon(
          _getSharingStatusIcon(viewModel),
          color: AppColors.headerForeground.withValues(alpha: 0.8),
        ),
        onPressed: onShowSyncStatus,
        tooltip: _getSharingStatusTooltip(context, viewModel),
      ),
    ];
  }

  static Widget buildFloatingActionButton(
    BuildContext context,
    VoidCallback onAddItem,
  ) {
    return Semantics(
      label: context.l10n.a11yAddItem,
      button: true,
      enabled: true,
      child: ElevatedButton.icon(
        onPressed: onAddItem,
        style: ComponentThemes.extendedFabStyle,
        icon: Icon(
          AdaptiveIcons.add,
          color: AppColors.cardWhite,
        ),
        label: Text(context.l10n.shoppingAddItem),
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
    if (activeList == null) return AppColors.forestGreen;

    switch (activeList.type) {
      case ListType.personal:
        return AppColors.forestGreen;
      case ListType.collaborative:
        final permissionService = ServiceLocator.get<PermissionService>();
        final currentUserId = permissionService.currentUser?.uid;
        if (currentUserId == null) return AppColors.forestGreen;

        final userPermission = activeList.memberPermissions[currentUserId];
        switch (userPermission) {
          case SharedListPermission.view:
            return AppColors.textMedium; // Subtle for view-only
          case SharedListPermission.edit:
            return AppColors.accent; // Trusted access
          case SharedListPermission.admin:
            return AppColors.forestGreen; // Blue for admin
          default:
            // If not in permissions map, check if owner (admin)
            return activeList.ownerId == currentUserId
                ? AppColors.forestGreen
                : AppColors.accent;
        }
      case ListType.template:
        return AppColors.textMedium;
    }
  }

  /// Get the appropriate tooltip for sharing status based on list type and user permissions
  static String _getSharingStatusTooltip(
      BuildContext context, UnifiedShoppingViewModel viewModel) {
    final activeList = viewModel.activeList;
    if (activeList == null) return context.l10n.shoppingList;

    switch (activeList.type) {
      case ListType.personal:
        return context.l10n.shoppingPersonalList;
      case ListType.collaborative:
        final permissionService = ServiceLocator.get<PermissionService>();
        final currentUserId = permissionService.currentUser?.uid;
        if (currentUserId == null) return context.l10n.shoppingSharedList;

        final userPermission = activeList.memberPermissions[currentUserId];
        final memberCount = activeList.memberPermissions.length +
            (activeList.memberPermissions.containsKey(activeList.ownerId)
                ? 0
                : 1);

        String permissionText;
        switch (userPermission) {
          case SharedListPermission.view:
            permissionText = context.l10n.shoppingPermissionViewOnly;
            break;
          case SharedListPermission.edit:
            permissionText = context.l10n.shoppingPermissionEdit;
            break;
          case SharedListPermission.admin:
            permissionText = context.l10n.shoppingPermissionAdministrator;
            break;
          default:
            // If not in permissions map, check if owner
            permissionText = activeList.ownerId == currentUserId
                ? context.l10n.shoppingPermissionAdministrator
                : context.l10n.shoppingPermissionEdit;
        }

        return context.l10n
            .shoppingSharedWithMembers(memberCount, permissionText);
      case ListType.template:
        return context.l10n.shoppingTemplateList;
    }
  }
}
