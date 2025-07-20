// lib/widgets/common/search_filter/filter_chips_widget.dart

import 'package:flutter/material.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_text_styles.dart';
import 'filter_models.dart';

/// Filter chips component for displaying filterable options
class FilterChipsWidget extends StatelessWidget {
  final String title;
  final List<FilterOption> options;
  final Set<String> activeFilters;
  final Function(String) onToggle;

  const FilterChipsWidget({
    super.key,
    required this.title,
    required this.options,
    required this.activeFilters,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppDimensions.spacingM),
          Text(
            title,
            style: AppTextStyles.headlineSmall.copyWith(
              fontSize: AppTextStyles.bodyLarge.fontSize,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Wrap(
            spacing: AppDimensions.spacingXs,
            runSpacing: AppDimensions.spacingXs,
            children: options.map((option) {
              final isSelected = activeFilters.contains(option.id);

              return FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (option.icon != null) ...[
                      Icon(
                        option.icon,
                        size: AppDimensions.iconSizeS,
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: AppDimensions.spacingXs),
                    ],
                    Text(
                      option.label,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                selected: isSelected,
                onSelected: (_) => onToggle(option.id),
                backgroundColor: Theme.of(context).colorScheme.surface,
                selectedColor: Theme.of(context).colorScheme.primary,
                checkmarkColor: Theme.of(context).colorScheme.onPrimary,
                side: BorderSide(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.3),
                  width: isSelected ? 2 : 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.chipRadius),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}