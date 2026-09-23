// lib/widgets/common/search_filter/personal_tag_filter_chips.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// Filter chips for personal tags with include/exclude support.
///
/// Displays user's personal tags as filterable chips with separate
/// sections for including and excluding tags from search results.
class PersonalTagFilterChipsWidget extends StatelessWidget {
  /// Title for the include filter section.
  final String? title;

  /// Available personal tags to show as filter options.
  final List<PersonalTag> tags;

  /// Currently selected tag IDs for inclusion (AND logic).
  final Set<String> selectedTagIds;

  /// Callback when an include tag is toggled (passes tag ID).
  final Function(String tagId) onToggle;

  /// Currently selected tag IDs for exclusion (OR logic).
  final Set<String> excludedTagIds;

  /// Callback when an exclude tag is toggled (passes tag ID).
  final Function(String tagId)? onExcludeToggle;

  /// Whether to show the exclude section.
  final bool showExcludeSection;

  /// Optional callback to navigate to tag management.
  final VoidCallback? onManageTags;

  const PersonalTagFilterChipsWidget({
    super.key,
    this.title,
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
                  title ?? context.l10n.filterPersonalTags,
                  style: AppTextStyles.headlineSmall.copyWith(
                    fontSize: AppTextStyles.bodyLarge.fontSize,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              if (onManageTags != null)
                IconButton(
                  icon: const Icon(
                    Icons.settings,
                    size: AppDimensions.iconSize18,
                  ),
                  onPressed: onManageTags,
                  tooltip: context.l10n.filterManageTags,
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
              context.l10n.filterExcludeTags,
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
            title ?? context.l10n.filterPersonalTags,
            style: AppTextStyles.headlineSmall.copyWith(
              fontSize: AppTextStyles.bodyLarge.fontSize,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          // The empty state is the shared one, not a hand-built button row
          // (P4-U03 test plan): it says what is missing and offers the one
          // way forward.
          StateWidget.empty(
            title: context.l10n.taggingNoPersonalTags,
            icon: Icons.label_outline,
            actionLabel: context.l10n.filterCreatePersonalTags,
            onAction: onManageTags,
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

    return Semantics(
      label: context.l10n.a11yFilterTag(
        tag.name,
        isSelected ? context.l10n.a11yActive : context.l10n.a11yInactive,
      ),
      selected: isSelected,
      button: true,
      // The shared grip: ring around the chip's 48 dp target and no saffron
      // focus tint (Grafisk manual v6:209, :381).
      child: ButleryControlFocus(
        borderRadius: BorderRadius.circular(AppDimensions.chipRadius),
        child: FilterChip(
          label: Text(tag.name),
          avatar: isSelected
              ? null
              : CircleAvatar(
                  radius: 6,
                  backgroundColor: colorScheme.onSurface,
                ),
          selected: isSelected,
          onSelected: (_) => onSelected(),
          backgroundColor: colorScheme.surface,
          // Chosen is the drawn chip: an ink fill with paper text and check,
          // never an ink tint (Komponentark v1:142; opacity is never a
          // state, tokens.json:40-53). The text.primary edge is the paper
          // edge of the dark drawing (Komponentark v1:523).
          selectedColor: colorScheme.primary,
          checkmarkColor: colorScheme.onPrimary,
          side: BorderSide(
            color: isSelected ? colorScheme.onSurface : colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
          labelStyle: isSelected
              ? AppTextStyles.bodyBold.copyWith(color: colorScheme.onPrimary)
              : AppTextStyles.bodyMedium.copyWith(color: colorScheme.onSurface),
          showCheckmark: isSelected,
        ),
      ),
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

    return Semantics(
      label: context.l10n.a11yExcludeTag(
        tag.name,
        isExcluded ? context.l10n.a11yActive : context.l10n.a11yInactive,
      ),
      selected: isExcluded,
      button: true,
      // The shared grip: ring around the chip's 48 dp target and no saffron
      // focus tint (Grafisk manual v6:209, :381).
      child: ButleryControlFocus(
        borderRadius: BorderRadius.circular(AppDimensions.chipRadius),
        child: FilterChip(
          label: Text(tag.name),
          avatar: isExcluded
              ? null
              : Icon(
                  Icons.remove_circle_outline,
                  size: AppDimensions.iconSizeS,
                  color: colorScheme.error.withValues(
                    alpha: AppDimensions.opacityMediumDark,
                  ),
                ),
          selected: isExcluded,
          onSelected: (_) => onSelected(),
          backgroundColor: colorScheme.surface,
          selectedColor: colorScheme.error.withValues(
            alpha: AppDimensions.opacityLightSubtle,
          ),
          checkmarkColor: colorScheme.error,
          side: BorderSide(
            color: isExcluded ? colorScheme.error : colorScheme.outline,
            width: isExcluded ? 2 : 1,
          ),
          labelStyle: isExcluded
              ? AppTextStyles.bodyBold.copyWith(color: colorScheme.error)
              : AppTextStyles.bodyMedium.copyWith(color: colorScheme.onSurface),
          showCheckmark: isExcluded,
        ),
      ),
    );
  }
}
