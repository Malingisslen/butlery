// lib/views/unified_shopping/widgets/shopping_app_bar.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/component_themes.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/shopping/restorable_rows.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/press_fill.dart';

enum _ShoppingRootAction {
  newList,
  templates,
  shareWithFriends,
  shareExternally,
  sharingStatus,
  sortCategories,
  uncheckAll,
  restoreItems,
}

/// App bar actions for shopping view
class ShoppingAppBar {
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
    VoidCallback? onSortCategories,
    VoidCallback? onUncheckAll,
    VoidCallback? onRestoreItems,
  }) {
    final canShare = viewModel.hasItems;
    final hasActiveList = viewModel.activeList != null;
    final hasBoughtItems = viewModel.boughtItems > 0;
    // BUT-2140: the row exists only while something from the last 30 days can
    // be put back, and only for someone who may edit the list.
    final activeList = viewModel.activeList;
    final canRestore =
        onRestoreItems != null &&
        activeList != null &&
        RestorableRows.hasRestorable(activeList, DateTime.now()) &&
        viewModel.canEditActiveList;

    // Skarmar v12 del 2 #inkop draws one outlined "more" button on the root
    // bar and nothing else, so the list's secondary actions live in one
    // overflow menu. Five 48 dp icons would leave the title "Inköp" and its
    // count line almost no width on a 320-360 dp phone. Each item keeps the
    // name it had as an icon; the sharing status says what the list is.
    return [
      PressFill(
        surface: PressSurface.base,
        child: PopupMenuButton<_ShoppingRootAction>(
          key: const ValueKey('shopping-root-more'),
          icon: const ButleryIcon(ButleryIcons.moreVertical),
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
              case _ShoppingRootAction.sortCategories:
                onSortCategories?.call();
              case _ShoppingRootAction.uncheckAll:
                onUncheckAll?.call();
              case _ShoppingRootAction.restoreItems:
                onRestoreItems?.call();
            }
          },
          itemBuilder: (menuContext) => [
            _item(
              _ShoppingRootAction.newList,
              ButleryIcons.plus,
              context.l10n.shoppingNewList,
            ),
            if (onBrowseTemplates != null)
              _item(
                _ShoppingRootAction.templates,
                ButleryIcons.list,
                context.l10n.shoppingTemplateBrowse,
              ),
            if (hasActiveList && onSortCategories != null)
              _item(
                _ShoppingRootAction.sortCategories,
                ButleryIcons.arrowUpDown,
                context.l10n.shoppingSortCategories,
              ),
            if (hasBoughtItems && onUncheckAll != null)
              _item(
                _ShoppingRootAction.uncheckAll,
                ButleryIcons.square,
                context.l10n.shoppingUncheckAll,
              ),
            if (canRestore)
              _item(
                _ShoppingRootAction.restoreItems,
                ButleryIcons.history,
                context.l10n.shoppingRestoreItems,
              ),
            if (canShare)
              _item(
                _ShoppingRootAction.shareWithFriends,
                ButleryIcons.users,
                context.l10n.shoppingShareWithFriends,
              ),
            if (canShare)
              _item(
                _ShoppingRootAction.shareExternally,
                ButleryIcons.share2,
                context.l10n.shoppingShareExternally,
              ),
            _item(
              _ShoppingRootAction.sharingStatus,
              _getSharingStatusIcon(viewModel),
              _getSharingStatusTooltip(context, viewModel),
            ),
          ],
        ),
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
          ButleryIcon(icon, size: AppDimensions.iconSizeM),
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
        icon: const ButleryIcon(ButleryIcons.plus),
        label: Text(context.l10n.shoppingAddItem),
      ),
    );
  }

  /// Get the appropriate icon for sharing status based on list type and user permissions
  static IconData _getSharingStatusIcon(UnifiedShoppingViewModel viewModel) {
    final activeList = viewModel.activeList;
    if (activeList == null) return ButleryIcons.user;

    switch (activeList.type) {
      case ListType.personal:
        return ButleryIcons.user;
      case ListType.collaborative:
        final permissionService = ServiceLocator.get<PermissionService>();
        final currentUserId = permissionService.currentUser?.uid;
        if (currentUserId == null) return ButleryIcons.users;

        final userPermission = activeList.memberPermissions[currentUserId];
        switch (userPermission) {
          case SharedListPermission.view:
            return ButleryIcons.eye;
          case SharedListPermission.edit:
            return ButleryIcons.users;
          case SharedListPermission.admin:
            return ButleryIcons.crown; // No SF Symbol equivalent
          default:
            // If not in permissions map, check if owner
            return activeList.ownerId == currentUserId
                ? ButleryIcons.crown
                : ButleryIcons.users;
        }
      case ListType.template:
        return ButleryIcons.savedTemplate;
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
