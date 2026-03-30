// lib/views/unified_shopping/widgets/shopping_list_header.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_shadows.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Header section with list selector and actions
class ShoppingListHeader {
  static Widget build(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    VoidCallback onClearCompleted,
    VoidCallback onUncheckAll,
    VoidCallback onRenameList,
    VoidCallback onDeleteList, {
    VoidCallback? onConvertList,
    VoidCallback? onSortCategories,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // List selector dropdown with management buttons
          _buildListSelector(
              context, viewModel, onRenameList, onDeleteList, onConvertList),

          if (viewModel.activeList != null) ...[
            const SizedBox(height: AppDimensions.spacingM),
            _buildListActions(
                context, viewModel, onClearCompleted, onUncheckAll,
                onSortCategories: onSortCategories),
          ],
        ],
      ),
    );
  }

  static Widget _buildListSelector(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    VoidCallback onRenameList,
    VoidCallback onDeleteList,
    VoidCallback? onConvertList,
  ) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        // Dropdown container
        Expanded(
          child: Container(
            padding: AppDimensions.paddingSymmetric16x12,
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadius12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: viewModel.activeList?.id,
                hint: Text(context.l10n.shoppingSelectList),
                isExpanded: true,
                icon: Icon(Icons.arrow_drop_down, color: cs.onSurfaceVariant),
                onChanged: (listId) {
                  if (listId != null) {
                    viewModel.setActiveList(listId);
                  }
                },
                items: viewModel.lists.map((list) {
                  return DropdownMenuItem<String>(
                    value: list.id,
                    child: _buildListDropdownItem(context, list),
                  );
                }).toList(),
              ),
            ),
          ),
        ),

        // Management buttons (only show if there's an active list)
        if (viewModel.activeList != null) ...[
          const SizedBox(width: AppDimensions.spacingS),

          // Rename button
          DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadius12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: IconButton(
              onPressed: onRenameList,
              icon: Icon(
                Icons.edit,
                color:
                    cs.onSurface.withValues(alpha: AppDimensions.opacityDark),
                size: AppDimensions.iconSizeAction,
              ),
              tooltip: context.l10n.shoppingRenameList,
              padding: const EdgeInsets.all(AppDimensions.spacingS),
              constraints: const BoxConstraints(
                minWidth: AppDimensions.minTouchTarget,
                minHeight: AppDimensions.minTouchTarget,
              ),
            ),
          ),

          // Convert button - show when user owns the list
          if (onConvertList != null) ...[
            const SizedBox(width: AppDimensions.spacingXs),
            DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadius12),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: IconButton(
                onPressed: onConvertList,
                icon: Icon(
                  Icons.swap_horiz,
                  color:
                      cs.onSurface.withValues(alpha: AppDimensions.opacityDark),
                  size: AppDimensions.iconSizeAction,
                ),
                tooltip: viewModel.activeList?.isPersonal == true
                    ? context.l10n.shoppingConvertToCollaborative
                    : context.l10n.shoppingConvertToPersonal,
                padding: const EdgeInsets.all(AppDimensions.spacingS),
                constraints: const BoxConstraints(
                  minWidth: AppDimensions.minTouchTarget,
                  minHeight: AppDimensions.minTouchTarget,
                ),
              ),
            ),
          ],

          const SizedBox(width: AppDimensions.spacingXs),

          // Delete button
          DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadius12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: IconButton(
              onPressed: onDeleteList,
              icon: Icon(
                Icons.delete,
                color:
                    cs.onSurface.withValues(alpha: AppDimensions.opacityDark),
                size: AppDimensions.iconSizeAction,
              ),
              tooltip: context.l10n.shoppingDeleteList,
              padding: const EdgeInsets.all(AppDimensions.spacingS),
              constraints: const BoxConstraints(
                minWidth: AppDimensions.minTouchTarget,
                minHeight: AppDimensions.minTouchTarget,
              ),
            ),
          ),
        ],
      ],
    );
  }

  static Widget _buildListActions(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    VoidCallback onClearCompleted,
    VoidCallback onUncheckAll, {
    VoidCallback? onSortCategories,
  }) {
    final cs = Theme.of(context).colorScheme;

    if (viewModel.activeList == null) return const SizedBox.shrink();

    return Row(
      children: [
        // Sort categories button
        if (onSortCategories != null)
          OutlinedButton.icon(
            onPressed: onSortCategories,
            style: OutlinedButton.styleFrom(
              padding: AppDimensions.paddingVertical8,
              side: BorderSide(
                  color: cs.onSurfaceVariant
                      .withValues(alpha: AppDimensions.opacityHalf)),
            ),
            icon: Icon(Icons.sort,
                size: AppDimensions.iconSizeS, color: cs.onSurfaceVariant),
            label: Text(
              context.l10n.shoppingSortCategories,
              style: AppTextStyles.metadataEmphasized.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),

        if (onSortCategories != null && viewModel.boughtItems > 0)
          const SizedBox(width: AppDimensions.spacingSm),

        // Clear completed items
        if (viewModel.boughtItems > 0)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onClearCompleted,
              style: OutlinedButton.styleFrom(
                padding: AppDimensions.paddingVertical8,
                side: BorderSide(
                    color: cs.onSurfaceVariant
                        .withValues(alpha: AppDimensions.opacityHalf)),
              ),
              icon: Icon(Icons.clear,
                  size: AppDimensions.iconSizeS, color: cs.onSurfaceVariant),
              label: Text(
                context.l10n.shoppingClearCount(viewModel.boughtItems),
                style: AppTextStyles.metadataEmphasized.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),

        if (viewModel.boughtItems > 0 &&
            viewModel.totalItems > viewModel.boughtItems)
          const SizedBox(width: AppDimensions.spacingSm),

        // Avbocka alla artiklar
        if (viewModel.boughtItems > 0)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onUncheckAll,
              style: OutlinedButton.styleFrom(
                padding: AppDimensions.paddingVertical8,
                side: BorderSide(
                    color: cs.primary
                        .withValues(alpha: AppDimensions.opacityHalf)),
              ),
              icon: Icon(Icons.check_box_outline_blank,
                  size: AppDimensions.iconSizeS, color: cs.primary),
              label: Text(
                context.l10n.shoppingUncheckAll,
                style: AppTextStyles.metadataEmphasized.copyWith(
                  color: cs.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Build enhanced dropdown item with sharing status indicators
  static Widget _buildListDropdownItem(
      BuildContext context, UnifiedShoppingList list) {
    final cs = Theme.of(context).colorScheme;
    final permissionService = ServiceLocator.get<PermissionService>();
    final currentUserId = permissionService.currentUser?.uid;

    // Get sharing status
    IconData sharingIcon;
    Color sharingColor;
    String? permissionText;

    switch (list.type) {
      case ListType.personal:
        sharingIcon = Icons.person;
        sharingColor = cs.primary;
        break;
      case ListType.collaborative:
        if (currentUserId != null) {
          final isOwner = list.ownerId == currentUserId;
          final userPermission = list.memberPermissions[currentUserId];

          if (isOwner) {
            sharingIcon = Icons.admin_panel_settings;
            sharingColor = cs.primary;
            permissionText = context.l10n.shoppingPermissionOwner;
          } else {
            switch (userPermission) {
              case SharedListPermission.view:
                sharingIcon = Icons.visibility;
                sharingColor = cs.onSurfaceVariant;
                permissionText = context.l10n.shoppingPermissionView;
                break;
              case SharedListPermission.edit:
                sharingIcon = Icons.edit;
                sharingColor = cs.secondary;
                permissionText = context.l10n.shoppingPermissionEdit;
                break;
              case SharedListPermission.admin:
                sharingIcon = Icons.admin_panel_settings;
                sharingColor = cs.primary;
                permissionText = context.l10n.shoppingPermissionAdmin;
                break;
              default:
                sharingIcon = Icons.people;
                sharingColor = cs.primary;
                permissionText = context.l10n.shoppingPermissionShared;
            }
          }
        } else {
          sharingIcon = Icons.people;
          sharingColor = cs.tertiary;
          permissionText = context.l10n.shoppingPermissionShared;
        }
        break;
      case ListType.template:
        sharingIcon = Icons.bookmark;
        sharingColor = cs.onSurfaceVariant;
        permissionText = context.l10n.shoppingPermissionTemplate;
        break;
    }

    return Row(
      children: [
        Icon(
          sharingIcon,
          size: AppDimensions.iconSizeM,
          color: sharingColor,
        ),
        const SizedBox(width: AppDimensions.spacingS),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                list.name,
                style: AppTextStyles.contentLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                children: [
                  Text(
                    context.l10n.shoppingItemCount(list.items.length),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  if (permissionText != null) ...[
                    Text(
                      ' • $permissionText',
                      style: AppTextStyles.metadataEmphasized.copyWith(
                        color: sharingColor,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
