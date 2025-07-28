// lib/views/unified_shopping/widgets/shopping_list_header.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';

/// Header section with list selector and actions
class ShoppingListHeader {
  static Widget build(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    VoidCallback onClearCompleted,
    VoidCallback onUncheckAll,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: AppColors.neutralLight,
        boxShadow: [
          BoxShadow(
            color: AppColors.neutralMedium.withValues(alpha: 0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lista-väljare dropdown
          _buildListSelector(context, viewModel),
          
          if (viewModel.activeList != null) ...[
            const SizedBox(height: AppDimensions.spacingM),
            _buildListActions(context, viewModel, onClearCompleted, onUncheckAll),
          ],
        ],
      ),
    );
  }

  static Widget _buildListSelector(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.neutralLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutralMedium.withValues(alpha: 0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: viewModel.activeList?.id,
          hint: const Text('Välj lista'),
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.neutralMedium),
          onChanged: (listId) {
            if (listId != null) {
              viewModel.setActiveList(listId);
            }
          },
          items: viewModel.lists.map((list) {
            return DropdownMenuItem<String>(
              value: list.id,
              child: Text(
                '${list.name} (${list.items.length} varor)',
                style: const TextStyle(fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
        ),
      ),
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
                side: BorderSide(color: AppColors.warning.withValues(alpha: 0.5)),
              ),
              icon: const Icon(Icons.clear, size: 16, color: AppColors.warning),
              label: Text(
                'Rensa (${viewModel.boughtItems})',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

        if (viewModel.boughtItems > 0 && viewModel.totalItems > viewModel.boughtItems)
          const SizedBox(width: 8),

        // Avbocka alla artiklar
        if (viewModel.boughtItems > 0)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onUncheckAll,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                side: BorderSide(color: AppColors.primaryBlue.withValues(alpha: 0.5)),
              ),
              icon: const Icon(Icons.check_box_outline_blank, size: 16, color: AppColors.primaryBlue),
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
}