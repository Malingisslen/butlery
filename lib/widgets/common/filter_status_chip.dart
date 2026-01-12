// lib/widgets/common/filter_status_chip.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Chip widget to display filter status with selected count
class FilterStatusChip extends StatelessWidget {
  final List<String> filterParts;
  final int selectedCount;

  const FilterStatusChip({
    super.key,
    required this.filterParts,
    required this.selectedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingL,
        vertical: AppDimensions.spacingXs,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .secondaryContainer
            .withValues(alpha: AppDimensions.opacityMediumLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: AppDimensions.opacityLight),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.filter_list,
            color: AppColors.textMedium,
            size: AppDimensions.iconSizeM,
          ),
          const SizedBox(width: AppDimensions.spacingXs),
          Expanded(
            child: Text(
              'Filter: ${filterParts.join(' • ')}',
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '$selectedCount valda',
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
