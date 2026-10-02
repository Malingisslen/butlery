// lib/widgets/common/filter_status_chip.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

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
      // A neutral info chip: the raised surface with no border (B83-2).
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      ),
      child: Row(
        children: [
          ButleryIcon(
            ButleryIcons.filter,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: AppDimensions.iconSizeM,
          ),
          const SizedBox(width: AppDimensions.spacingXs),
          Expanded(
            child: Text(
              'Filter: ${filterParts.join(' • ')}',
              style: AppTextStyles.metadataEmphasized.copyWith(
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          Text(
            '$selectedCount valda',
            style: AppTextStyles.metadataEmphasized.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
