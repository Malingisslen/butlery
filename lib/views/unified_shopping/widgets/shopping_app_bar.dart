// lib/views/unified_shopping/widgets/shopping_app_bar.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/component_themes.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/common/icons/adaptive_icon.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';

enum _ShoppingRootAction {
  newList,
  templates,
  shareWithFriends,
  shareExternally,
  sharingStatus,
}

/// App bar actions for shopping view
class ShoppingAppBar {
  static List<Widget> buildActions(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    VoidCallback onCreateList,
    VoidCallback onShowShareDialog,
    VoidCallback onShareExternally,
    VoidCallback onShowSyncStatus, {
    VoidCallback? onBrowseTemplates,
  }) {
    final cs = Theme.of(context).colorScheme;
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
                color: cs.onSurface.withValues(
                  alpha: AppDimensions.opacityDark,
                ),
              ),
              onPressed: onCreateList,
              tooltip: context.l10n.shoppingNewList,
            ),
          ),

          // Browse templates
          if (onBrowseTemplates != null)
            IconButton(
              icon: Icon(
                Icons.list_alt_outlined,
                color: cs.onSurface.withValues(
                  alpha: AppDimensions.opacityDark,
                ),
              ),
              onPressed: onBrowseTemplates,
              tooltip: context.l10n.shoppingTemplateBrowse,
            ),

          // Share with friends button (social)
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
                    ? cs.onSurface.withValues(alpha: AppDimensions.opacityDark)
                    : cs.outlineVariant,
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
                    ? cs.onSurface.withValues(alpha: AppDimensions.opacityDark)
                    : cs.outlineVariant,
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
                  color: _getSharingStatusColor(context, viewModel),
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

  /// The actions on the shopping list's root bar. The bar gives every icon
  /// its foreground, text.primary on the light root bar in both modes
  /// (ButleryTopBar; Komponentark v1:62), so no icon sets its own colour.
  static List<Widget> buildHeaderActions(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    VoidCallback onCreateList,
    VoidCallback onShowShareDialog,
    VoidCallback onShareExternally,
    VoidCallback onShowSyncStatus, {
    VoidCallback? onBrowseTemplates,
  }) {
    final canShare = viewModel.hasItems;

    // Skarmar v12 del 2 #inkop draws one outlined "more" button on the root
    // bar and nothing else, so the list's secondary actions live in one
    // overflow menu. Five 48 dp icons would leave the title "Inköp" and its
    // count line almost no width on a 320-360 dp phone. Each item keeps the
    // name it had as an icon; the sharing status says what the list is.
    return [
      PopupMenuButton<_ShoppingRootAction>(
        key: const ValueKey('shopping-root-more'),
        icon: const Icon(Icons.more_vert),
        tooltip: context.l10n.rootBarMoreActions,
        onSelected: (action) {
          switch (action) {
            case _ShoppingRootAction.newList:
              onCreateList();
            case _ShoppingRootAction.templates:
              onBrowseTemplates?.call();
            case _ShoppingRootAction.shareWithFriends:
              onShowShareDialog();
            case _ShoppingRootAction.shareExternally:
              onShareExternally();
            case _ShoppingRootAction.sharingStatus:
              onShowSyncStatus();
          }
        },
        itemBuilder: (menuContext) => [
          _item(
            _ShoppingRootAction.newList,
            AdaptiveIcons.add,
            context.l10n.shoppingNewList,
          ),
          if (onBrowseTemplates != null)
            _item(
              _ShoppingRootAction.templates,
              Icons.list_alt_outlined,
              context.l10n.shoppingTemplateBrowse,
            ),
          if (canShare)
            _item(
              _ShoppingRootAction.shareWithFriends,
              AdaptiveIcons.peopleOutlined,
              context.l10n.shoppingShareWithFriends,
            ),
          if (canShare)
            _item(
              _ShoppingRootAction.shareExternally,
              AdaptiveIcons.share,
              context.l10n.shoppingShareExternally,
            ),
          _item(
            _ShoppingRootAction.sharingStatus,
            _getSharingStatusIcon(viewModel),
            _getSharingStatusTooltip(context, viewModel),
          ),
        ],
      ),
    ];
  }

  /// One overflow row: the icon and text take the menu's own foreground,
  /// text.primary in both modes (onSurface), never cs.primary.
  static ButleryMenuItem<_ShoppingRootAction> _item(
    _ShoppingRootAction value,
    IconData icon,
    String label,
  ) {
    return ButleryMenuItem<_ShoppingRootAction>(
      key: ValueKey('shopping-root-${value.name}'),
      value: value,
      child: Row(
        children: [
          Icon(icon, size: AppDimensions.iconSizeM),
          const SizedBox(width: AppDimensions.spacingM),
          Flexible(child: Text(label)),
        ],
      ),
    );
  }

  static Widget buildFloatingActionButton(
    BuildContext context,
    VoidCallback onAddItem,
  ) {
    final cs = Theme.of(context).colorScheme;

    // BUT-403: `btn-add-shopping-item` identifier for browser a11y queries.
    return Semantics(
      identifier: 'btn-add-shopping-item',
      label: context.l10n.a11yAddItem,
      button: true,
      enabled: true,
      // The list's one saffron action (Skarmar v12 del 2 #inkop draws the
      // add button in saffron; Komponentark v1:843-844). The hero's colours
      // (action.primary / text.onActionPrimary, pressed action.primaryPressed
      // / text.onActionPrimaryPressed) over the extended button's shape; the
      // icon takes the button's foreground.
      child: ElevatedButton.icon(
        key: const ValueKey('test-shopping-list-add'),
        onPressed: onAddItem,
        style: ComponentThemes.heroButtonStyle(
          cs,
        ).merge(ComponentThemes.extendedFabStyle(cs)),
        icon: Icon(AdaptiveIcons.add),
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
                ? Icons
                      .admin_panel_settings // No SF Symbol equivalent
                : AdaptiveIcons.people;
        }
      case ListType.template:
        return AdaptiveIcons.savedTemplate;
    }
  }

  /// Get the appropriate color for sharing status based on list type and user permissions
  static Color _getSharingStatusColor(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
  ) {
    final cs = Theme.of(context).colorScheme;
    final activeList = viewModel.activeList;
    if (activeList == null) return cs.primary;

    switch (activeList.type) {
      case ListType.personal:
        return cs.primary;
      case ListType.collaborative:
        final permissionService = ServiceLocator.get<PermissionService>();
        final currentUserId = permissionService.currentUser?.uid;
        if (currentUserId == null) return cs.primary;

        final userPermission = activeList.memberPermissions[currentUserId];
        switch (userPermission) {
          case SharedListPermission.view:
            return cs.onSurfaceVariant; // Subtle for view-only
          case SharedListPermission.edit:
            return cs.secondary; // Trusted access
          case SharedListPermission.admin:
            return cs.primary; // Blue for admin
          default:
            // If not in permissions map, check if owner (admin)
            return activeList.ownerId == currentUserId
                ? cs.primary
                : cs.secondary;
        }
      case ListType.template:
        return cs.onSurfaceVariant;
    }
  }

  /// Get the appropriate tooltip for sharing status based on list type and user permissions
  static String _getSharingStatusTooltip(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
  ) {
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
        final memberCount =
            activeList.memberPermissions.length +
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

        return context.l10n.shoppingSharedWithMembers(
          memberCount,
          permissionText,
        );
      case ListType.template:
        return context.l10n.shoppingTemplateList;
    }
  }
}
