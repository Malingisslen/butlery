// lib/views/unified_shopping/widgets/shopping_list_header.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';

/// Header section with list selector and actions
class ShoppingListHeader {
  static Widget build(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    VoidCallback onClearCompleted,
    VoidCallback onUncheckAll,
    VoidCallback onRenameList,
    VoidCallback onDeleteList,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        boxShadow: [
          BoxShadow(
            color: AppColors.textMedium.withValues(alpha: AppDimensions.opacityLight),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lista-väljare dropdown with management buttons
          _buildListSelector(context, viewModel, onRenameList, onDeleteList),

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
  ) {
    return Row(
      children: [
        // Dropdown container
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.backgroundBeige,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadius12),
              border: Border.all(color: AppColors.divider),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: viewModel.activeList?.id,
                hint: const Text('Välj lista'),
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
                    child: _buildListDropdownItem(list),
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
              color: AppColors.backgroundBeige,
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
              tooltip: 'Byt namn på lista',
              padding: const EdgeInsets.all(AppDimensions.spacingS),
              constraints: const BoxConstraints(
                minWidth: AppDimensions.minTouchTarget,
                minHeight: AppDimensions.minTouchTarget,
              ),
            ),
          ),

          const SizedBox(width: AppDimensions.spacingXs),

          // Delete button
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.backgroundBeige,
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
              tooltip: 'Ta bort lista',
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
                padding: const EdgeInsets.symmetric(vertical: 8),
                side: BorderSide(
                    color: AppColors.textMedium.withValues(alpha: AppDimensions.opacityHalf)),
              ),
              icon: const Icon(Icons.clear,
                  size: AppDimensions.iconSizeS, color: AppColors.textMedium),
              label: Text(
                'Rensa (${viewModel.boughtItems})',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMedium,
                  fontWeight: FontWeight.w500,
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
                padding: const EdgeInsets.symmetric(vertical: 8),
                side: BorderSide(
                    color: AppColors.primaryBlue.withValues(alpha: AppDimensions.opacityHalf)),
              ),
              icon: const Icon(Icons.check_box_outline_blank,
                  size: AppDimensions.iconSizeS, color: AppColors.primaryBlue),
              label: Text(
                'Avbocka alla',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Build enhanced dropdown item with sharing status indicators
  static Widget _buildListDropdownItem(UnifiedShoppingList list) {
    final permissionService = ServiceLocator.get<PermissionService>();
    final currentUserId = permissionService.currentUser?.uid;

    // Get sharing status
    IconData sharingIcon;
    Color sharingColor;
    String? permissionText;

    switch (list.type) {
      case ListType.personal:
        sharingIcon = Icons.person;
        sharingColor = AppColors.primaryBlue;
        break;
      case ListType.collaborative:
        if (currentUserId != null) {
          final isOwner = list.ownerId == currentUserId;
          final userPermission = list.memberPermissions[currentUserId];

          if (isOwner) {
            sharingIcon = Icons.admin_panel_settings;
            sharingColor = AppColors.primaryBlue;
            permissionText = 'Ägare';
          } else {
            switch (userPermission) {
              case SharedListPermission.view:
                sharingIcon = Icons.visibility;
                sharingColor = AppColors.textMedium;
                permissionText = 'Kan se';
                break;
              case SharedListPermission.edit:
                sharingIcon = Icons.edit;
                sharingColor = AppColors.accent;
                permissionText = 'Kan redigera';
                break;
              case SharedListPermission.admin:
                sharingIcon = Icons.admin_panel_settings;
                sharingColor = AppColors.primaryBlue;
                permissionText = 'Admin';
                break;
              default:
                sharingIcon = Icons.people;
                sharingColor = AppColors.primaryBlue;
                permissionText = 'Delad';
            }
          }
        } else {
          sharingIcon = Icons.people;
          sharingColor = AppColors.secondaryPurple;
          permissionText = 'Delad';
        }
        break;
      case ListType.template:
        sharingIcon = Icons.bookmark;
        sharingColor = AppColors.textMedium;
        permissionText = 'Mall';
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
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                children: [
                  Text(
                    '${list.items.length} varor',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMedium,
                    ),
                  ),
                  if (permissionText != null) ...[
                    Text(
                      ' • $permissionText',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: sharingColor,
                        fontWeight: FontWeight.w500,
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
