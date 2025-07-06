// lib/widgets/filter_chips.dart

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Filter chip data model
class FilterOption {
  final String id;
  final String label;
  final IconData? icon;
  final dynamic value;

  const FilterOption({
    required this.id,
    required this.label,
    this.icon,
    this.value,
  });
}

/// Återanvändbar filter chips widget
class FilterChips extends StatelessWidget {
  final List<FilterOption> options;
  final Set<String> selectedIds;
  final Function(String) onToggle;
  final String? title;
  final bool scrollable;

  const FilterChips({
    super.key,
    required this.options,
    required this.selectedIds,
    required this.onToggle,
    this.title,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final chips = Wrap(
      spacing: AppTheme.spacingXs, // ✅ AppTheme spacing
      runSpacing: AppTheme.spacingXs, // ✅ AppTheme spacing
      children: options.map((option) {
        final isSelected = selectedIds.contains(option.id);

        return FilterChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (option.icon != null) ...[
                Icon(option.icon,
                    size: AppTheme.iconSizeSmall), // ✅ AppTheme size
                AppTheme.tinyGap, // ✅ AppTheme gap
              ],
              Text(option.label),
            ],
          ),
          selected: isSelected,
          onSelected: (_) => onToggle(option.id),
          backgroundColor: Theme.of(context).colorScheme.surface,
          selectedColor: AppTheme.primaryColor
              .withValues(alpha: 0.2), // ✅ FIXED: withValues
          checkmarkColor: AppTheme.primaryColor, // ✅ AppTheme color
          side: BorderSide(
            color: isSelected
                ? AppTheme.primaryColor // ✅ AppTheme color
                : Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.3), // ✅ FIXED: withValues
            width: isSelected ? 2 : 1,
          ),
        );
      }).toList(),
    );

    if (!scrollable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Padding(
              padding: EdgeInsets.only(
                left: AppTheme.spacingMd, // ✅ AppTheme spacing
                bottom: AppTheme.spacingXs, // ✅ AppTheme spacing
              ),
              child: Text(
                title!,
                style: AppTheme.cardTitleStyle, // ✅ AppTheme style
              ),
            ),
          ],
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMd), // ✅ AppTheme spacing
            child: chips,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: EdgeInsets.only(
              left: AppTheme.spacingMd, // ✅ AppTheme spacing
              bottom: AppTheme.spacingXs, // ✅ AppTheme spacing
            ),
            child: Text(
              title!,
              style: AppTheme.cardTitleStyle, // ✅ AppTheme style
            ),
          ),
        ],
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(
              horizontal: AppTheme.spacingMd), // ✅ AppTheme spacing
          child: chips,
        ),
      ],
    );
  }
}

/// Predefinerade filter för recept
class RecipeFilters {
  static const List<FilterOption> timeFilters = [
    FilterOption(id: 'quick', label: '< 30 min', icon: Icons.timer, value: 30),
    FilterOption(
        id: 'medium', label: '30-60 min', icon: Icons.timer, value: 60),
    FilterOption(id: 'long', label: '> 60 min', icon: Icons.timer, value: 999),
  ];

  static const List<FilterOption> mealTypeFilters = [
    FilterOption(
        id: 'breakfast',
        label: 'Frukost',
        icon: Icons.breakfast_dining,
        value: 'Frukost'),
    FilterOption(
        id: 'lunch', label: 'Lunch', icon: Icons.lunch_dining, value: 'Lunch'),
    FilterOption(
        id: 'dinner',
        label: 'Middag',
        icon: Icons.dinner_dining,
        value: 'Middag'),
    FilterOption(
        id: 'snack',
        label: 'Mellanmål',
        icon: Icons.cookie,
        value: 'Mellanmål'),
    FilterOption(
        id: 'dessert',
        label: 'Efterrätt',
        icon: Icons.cake,
        value: 'Efterrätt'),
  ];

  static const List<FilterOption> ratingFilters = [
    FilterOption(id: 'high_rated', label: '4+ ⭐', value: 4.0),
    FilterOption(id: 'top_rated', label: '5 ⭐', value: 5.0),
  ];
}
