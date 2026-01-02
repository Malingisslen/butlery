// lib/widgets/common/search_filter/personal_tag_filter_chips.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Filter chips for personal tags with include/exclude support.
///
/// Displays user's personal tags as filterable chips with separate
/// sections for including and excluding tags from search results.
class PersonalTagFilterChipsWidget extends StatelessWidget {
  /// Title for the include filter section.
  final String title;

  /// Available personal tags to show as filter options.
  final List<PersonalTag> tags;

  /// Currently selected tag IDs for inclusion (AND logic).
  final Set<String> selectedTagIds;

  /// Callback when an include tag is toggled.
  final Function(String tagId) onToggle;

  /// Currently selected tag IDs for exclusion (OR logic).
  final Set<String> excludedTagIds;

  /// Callback when an exclude tag is toggled.
  final Function(String tagId)? onExcludeToggle;

  /// Whether to show the exclude section.
  final bool showExcludeSection;

  /// Optional callback to navigate to tag management.
  final VoidCallback? onManageTags;

  const PersonalTagFilterChipsWidget({
    super.key,
    this.title = 'Personliga taggar',
    required this.tags,
    required this.selectedTagIds,
    required this.onToggle,
    this.excludedTagIds = const {},
    this.onExcludeToggle,
    this.showExcludeSection = true,
    this.onManageTags,
  });

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return _buildEmptyState(context);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Include section
          const SizedBox(height: AppDimensions.spacingM),
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.headlineSmall.copyWith(
                    fontSize: AppTextStyles.bodyLarge.fontSize,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              if (onManageTags != null)
                IconButton(
                  icon: const Icon(Icons.settings, size: 18),
                  onPressed: onManageTags,
                  tooltip: 'Hantera taggar',
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Wrap(
            spacing: AppDimensions.spacingXs,
            runSpacing: AppDimensions.spacingXs,
            children: tags.map((tag) {
              final isSelected = selectedTagIds.contains(tag.id);
              return _PersonalTagFilterChip(
                tag: tag,
                isSelected: isSelected,
                onSelected: () => onToggle(tag.id),
              );
            }).toList(),
          ),
          // Exclude section
          if (showExcludeSection && onExcludeToggle != null) ...[
            const SizedBox(height: AppDimensions.spacingL),
            Text(
              'Exkludera taggar',
              style: AppTextStyles.headlineSmall.copyWith(
                fontSize: AppTextStyles.bodyLarge.fontSize,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingXs),
            Wrap(
              spacing: AppDimensions.spacingXs,
              runSpacing: AppDimensions.spacingXs,
              children: tags.map((tag) {
                final isExcluded = excludedTagIds.contains(tag.id);
                return _PersonalTagExcludeChip(
                  tag: tag,
                  isExcluded: isExcluded,
                  onSelected: () => onExcludeToggle!(tag.id),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    if (onManageTags == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingL),
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
          TextButton.icon(
            onPressed: onManageTags,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Skapa personliga taggar'),
          ),
        ],
      ),
    );
  }
}

/// Individual filter chip for a personal tag with accent color.
class _PersonalTagFilterChip extends StatelessWidget {
  final PersonalTag tag;
  final bool isSelected;
  final VoidCallback onSelected;

  const _PersonalTagFilterChip({
    required this.tag,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FilterChip(
      label: Text(tag.name),
      avatar: isSelected
          ? null
          : CircleAvatar(
              radius: 6,
              backgroundColor: colorScheme.primary,
            ),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      backgroundColor: colorScheme.surface,
      selectedColor: colorScheme.primary.withValues(alpha: 0.25),
      checkmarkColor: colorScheme.primary,
      side: BorderSide(
        color: isSelected ? colorScheme.primary : colorScheme.outline,
        width: isSelected ? 2 : 1,
      ),
      labelStyle: AppTextStyles.bodyMedium.copyWith(
        color: isSelected ? colorScheme.primary : colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      showCheckmark: isSelected,
    );
  }
}

/// Exclude filter chip with red/error styling.
class _PersonalTagExcludeChip extends StatelessWidget {
  final PersonalTag tag;
  final bool isExcluded;
  final VoidCallback onSelected;

  const _PersonalTagExcludeChip({
    required this.tag,
    required this.isExcluded,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FilterChip(
      label: Text(tag.name),
      avatar: isExcluded
          ? null
          : Icon(
              Icons.remove_circle_outline,
              size: 16,
              color: colorScheme.error.withValues(alpha: 0.6),
            ),
      selected: isExcluded,
      onSelected: (_) => onSelected(),
      backgroundColor: colorScheme.surface,
      selectedColor: colorScheme.error.withValues(alpha: 0.15),
      checkmarkColor: colorScheme.error,
      side: BorderSide(
        color: isExcluded ? colorScheme.error : colorScheme.outline,
        width: isExcluded ? 2 : 1,
      ),
      labelStyle: AppTextStyles.bodyMedium.copyWith(
        color: isExcluded ? colorScheme.error : colorScheme.onSurface,
        fontWeight: isExcluded ? FontWeight.w600 : FontWeight.normal,
      ),
      showCheckmark: isExcluded,
    );
  }
}
