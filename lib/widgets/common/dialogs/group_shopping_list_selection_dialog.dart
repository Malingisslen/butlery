// lib/widgets/common/dialogs/group_shopping_list_selection_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/providers/application_provider.dart';

/// Simple dialog for selecting a shopping list to share with a group
class GroupShoppingListSelectionDialog extends StatelessWidget {
  final String groupName;

  const GroupShoppingListSelectionDialog({
    super.key,
    required this.groupName,
  });

  @override
  Widget build(BuildContext context) {
    final shoppingService = ServiceLocator.get<UnifiedShoppingService>();
    final lists = shoppingService
        .personalLists; // Only show personal lists (not already collaborative)

    return AlertDialog(
      title: Text(
        'Dela inköpslista med $groupName',
        style: AppTextStyles.headlineSmall,
      ),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.5,
        child: lists.isEmpty
            ? StateWidget.empty(
                title: 'Inga inköpslistor',
                subtitle: 'Du har inga inköpslistor att dela än',
                icon: Icons.shopping_cart,
              )
            : ListView.builder(
                itemCount: lists.length,
                itemBuilder: (context, index) {
                  final list = lists[index];
                  return _ShoppingListItem(
                    list: list,
                    onTap: () => Navigator.pop(context, list),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Avbryt', style: AppTextStyles.labelLarge),
        ),
      ],
    );
  }
}

/// Shopping list item widget
class _ShoppingListItem extends StatelessWidget {
  final UnifiedShoppingList list;
  final VoidCallback onTap;

  const _ShoppingListItem({
    required this.list,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final completedCount = list.items.where((item) => item.bought).length;
    final totalCount = list.items.length;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingL,
        vertical: AppDimensions.paddingM,
      ),
      leading: Container(
        width: AppDimensions.iconSizeXl,
        height: AppDimensions.iconSizeXl,
        decoration: BoxDecoration(
          color: AppColors.primaryBlue.withValues(alpha: AppDimensions.opacityVeryLight),
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        ),
        child: const Icon(
          Icons.shopping_cart,
          color: AppColors.primaryBlue,
          size: AppDimensions.iconSizeAction,
        ),
      ),
      title: Text(
        list.name,
        style: AppTextStyles.titleMedium,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (list.description != null && list.description!.isNotEmpty)
            Text(
              list.description!,
              style: AppTextStyles.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            '$completedCount/$totalCount artiklar',
            style: AppTextStyles.metadataEmphasized.copyWith(
              color: AppColors.primaryBlue,
            ),
          ),
        ],
      ),
      trailing:
          const Icon(Icons.arrow_forward_ios, size: AppDimensions.iconSizeS),
      onTap: onTap,
    );
  }
}
