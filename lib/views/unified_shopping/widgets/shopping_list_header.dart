// lib/views/unified_shopping/widgets/shopping_list_header.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_colors.dart';
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
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lista-väljare dropdown with management buttons
          _buildListSelector(
              context, viewModel, onRenameList, onDeleteList, onConvertList),

          if (viewModel.activeList != null) ...[
            const SizedBox(height: AppDimensions.spacingM),
            _buildListActions(
                context, viewModel, onClearCompleted, onUncheckAll),
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
    return Row(
      children: [
        // Dropdown container
        Expanded(
          child: Container(
            padding: AppDimensions.paddingSymmetric16x12,
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadius12),
              border: Border.all(color: AppColors.divider),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: viewModel.activeList?.id,
                hint: Text(context.l10n.shoppingSelectList),
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down,
                    color: AppColors.textMedium),
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
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadius12),
              border: Border.all(color: AppColors.divider),
            ),
            child: IconButton(
              onPressed: onRenameList,
              icon: Icon(
                Icons.edit,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: AppDimensions.opacityDark),
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
                color: AppColors.cream,
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadius12),
                border: Border.all(color: AppColors.divider),
              ),
              child: IconButton(
                onPressed: onConvertList,
                icon: Icon(
                  Icons.swap_horiz,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: AppDimensions.opacityDark),
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
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadius12),
              border: Border.all(color: AppColors.divider),
            ),
            child: IconButton(
              onPressed: onDeleteList,
              icon: Icon(
                Icons.delete,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: AppDimensions.opacityDark),
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
    VoidCallback onUncheckAll,
  ) {
    if (viewModel.activeList == null) return const SizedBox.shrink();

    return Row(
      children: [
        // Rensa färdiga artiklar
        if (viewModel.boughtItems > 0)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onClearCompleted,
              style: OutlinedButton.styleFrom(
                padding: AppDimensions.paddingVertical8,
                side: BorderSide(
                    color: AppColors.textMedium
                        .withValues(alpha: AppDimensions.opacityHalf)),
              ),
              icon: const Icon(Icons.clear,
                  size: AppDimensions.iconSizeS, color: AppColors.textMedium),
              label: Text(
                context.l10n.shoppingClearCount(viewModel.boughtItems),
                style: AppTextStyles.metadataEmphasized.copyWith(
                  color: AppColors.textMedium,
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
                    color: AppColors.forestGreen
                        .withValues(alpha: AppDimensions.opacityHalf)),
              ),
              icon: const Icon(Icons.check_box_outline_blank,
                  size: AppDimensions.iconSizeS, color: AppColors.forestGreen),
              label: Text(
                context.l10n.shoppingUncheckAll,
                style: AppTextStyles.metadataEmphasized.copyWith(
                  color: AppColors.forestGreen,
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
    final permissionService = ServiceLocator.get<PermissionService>();
    final currentUserId = permissionService.currentUser?.uid;

    // Get sharing status
    IconData sharingIcon;
    Color sharingColor;
    String? permissionText;

    switch (list.type) {
      case ListType.personal:
        sharingIcon = Icons.person;
        sharingColor = AppColors.forestGreen;
        break;
      case ListType.collaborative:
        if (currentUserId != null) {
          final isOwner = list.ownerId == currentUserId;
          final userPermission = list.memberPermissions[currentUserId];

          if (isOwner) {
            sharingIcon = Icons.admin_panel_settings;
            sharingColor = AppColors.forestGreen;
            permissionText = context.l10n.shoppingPermissionOwner;
          } else {
            switch (userPermission) {
              case SharedListPermission.view:
                sharingIcon = Icons.visibility;
                sharingColor = AppColors.textMedium;
                permissionText = context.l10n.shoppingPermissionView;
                break;
              case SharedListPermission.edit:
                sharingIcon = Icons.edit;
                sharingColor = AppColors.accent;
                permissionText = context.l10n.shoppingPermissionEdit;
                break;
              case SharedListPermission.admin:
                sharingIcon = Icons.admin_panel_settings;
                sharingColor = AppColors.forestGreen;
                permissionText = context.l10n.shoppingPermissionAdmin;
                break;
              default:
                sharingIcon = Icons.people;
                sharingColor = AppColors.forestGreen;
                permissionText = context.l10n.shoppingPermissionShared;
            }
          }
        } else {
          sharingIcon = Icons.people;
          sharingColor = AppColors.secondaryPurple;
          permissionText = context.l10n.shoppingPermissionShared;
        }
        break;
      case ListType.template:
        sharingIcon = Icons.bookmark;
        sharingColor = AppColors.textMedium;
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
                      color: AppColors.textMedium,
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
