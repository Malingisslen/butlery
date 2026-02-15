/// Main view header widget matching the UI redesign mockups.
///
/// Features:
/// - Dark green background with rust accent bar
/// - Large lowercase Josefin Sans title (e.g., "dina recept")
/// - Count badge below title (e.g., "48 recept")
/// - Action buttons in top right (avatar, settings)

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Header widget for main views with large title and count badge.
///
/// Use this for main navigation views like "dina recept", "veckans meny", etc.
///
/// Example:
/// ```dart
/// MainViewHeader(
///   title: 'dina recept',
///   countBadge: '48 recept',
///   trailing: UserAvatarButton(),
/// )
/// ```
class MainViewHeader extends StatelessWidget implements PreferredSizeWidget {
  const MainViewHeader({
    required this.title,
    this.countBadge,
    this.trailing,
    this.actions,
    this.showAccentBar = true,
    super.key,
  });

  /// The title text displayed in the header (will be lowercased).
  final String title;

  /// Optional count badge text (e.g., "48 recept", "Vecka 6 · 5 rätter").
  final String? countBadge;

  /// Widget to display at the top right (usually avatar button).
  final Widget? trailing;

  /// Additional action widgets (icon buttons).
  final List<Widget>? actions;

  /// Whether to show the rust-colored accent bar at the bottom.
  final bool showAccentBar;

  /// Height of the accent bar at the bottom.
  static const double accentBarHeight = 4.0;

  /// Total header height including safe area.
  static const double headerHeight = 140.0;

  @override
  Size get preferredSize => Size.fromHeight(
        headerHeight + (showAccentBar ? accentBarHeight : 0),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ColoredBox(
          color: cs.primaryContainer,
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: headerHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.spacingL,
                  AppDimensions.spacingMd,
                  AppDimensions.spacingL,
                  AppDimensions.spacingL,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and count badge
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Title
                          Text(
                            title.toLowerCase(),
                            style: AppTextStyles.mainViewTitle,
                          ),
                          // Count badge
                          if (countBadge != null) ...[
                            const SizedBox(height: AppDimensions.spacingXs),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDimensions.spacingSm,
                                vertical: AppDimensions.spacingXxs,
                              ),
                              decoration: BoxDecoration(
                                color: cs.surface,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Text(
                                countBadge!,
                                style: AppTextStyles.headerCountBadge,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Actions and trailing
                    Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (actions != null) ...actions!,
                            if (trailing != null) trailing!,
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Rust accent bar
        if (showAccentBar)
          ColoredBox(
            color: cs.secondary,
            child: const SizedBox(
              height: accentBarHeight,
              width: double.infinity,
            ),
          ),
      ],
    );
  }
}

/// Search box widget matching the UI redesign mockup.
///
/// White background with green border and rust bottom accent.
class ButlerySearchBox extends StatelessWidget {
  const ButlerySearchBox({
    required this.controller,
    this.onChanged,
    this.hintText,
    this.onFilterTap,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final String? hintText;
  final VoidCallback? onFilterTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingMd,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: cs.primary, width: 2),
          left: BorderSide(color: cs.primary, width: 2),
          right: BorderSide(color: cs.primary, width: 2),
          bottom:
              BorderSide(color: cs.secondary.withValues(alpha: 0.7), width: 4),
        ),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppDimensions.spacingMd),
            child: Icon(
              Icons.search,
              color: cs.primary,
              size: 18,
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: AppTextStyles.bodyMedium.copyWith(
                color: cs.onSurface,
              ),
              decoration: InputDecoration(
                hintText: hintText ?? context.l10n.searchRecipesHint,
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: cs.outline,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingMd,
                  vertical: AppDimensions.spacingMd,
                ),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, size: 18),
              color: cs.onSurfaceVariant,
              onPressed: () {
                controller.clear();
                onChanged?.call('');
              },
            ),
        ],
      ),
    );
  }
}

/// Filter chips row matching the UI redesign mockup.
///
/// Horizontal scrollable row of filter chips.
class ButleryFilterChips extends StatelessWidget {
  const ButleryFilterChips({
    required this.chips,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  /// List of chip labels.
  final List<String> chips;

  /// Currently selected chip index (-1 for none).
  final int selectedIndex;

  /// Callback when a chip is selected.
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
      ),
      child: Row(
        children: chips.asMap().entries.map((entry) {
          final index = entry.key;
          final label = entry.value;
          final isSelected = index == selectedIndex;

          return Padding(
            padding: EdgeInsets.only(
              right: index < chips.length - 1 ? AppDimensions.spacingSm : 0,
            ),
            child: _FilterChip(
              label: label,
              isSelected: isSelected,
              onTap: () => onSelected(index),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: isSelected ? cs.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(0),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingMd,
            vertical: AppDimensions.spacingSm,
          ),
          decoration: BoxDecoration(
            border: isSelected ? null : Border.all(color: cs.primary, width: 2),
          ),
          child: Text(
            label,
            style: AppTextStyles.filterChip.copyWith(
              color: isSelected ? cs.surface : cs.primaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

/// Section header with left accent border (e.g., "SENAST TILLAGDA").
class ButlerySectionHeader extends StatelessWidget {
  const ButlerySectionHeader({
    required this.label,
    this.count,
    this.accentColor,
    super.key,
  });

  /// Section label text (will be uppercased).
  final String label;

  /// Optional count to show on the right.
  final String? count;

  /// Accent color for the left border (defaults to rust).
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveAccentColor = accentColor ?? cs.secondary;
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      decoration: BoxDecoration(
        color: effectiveAccentColor.withValues(alpha: 0.08),
        border: Border(
          left: BorderSide(
            color: effectiveAccentColor,
            width: 4,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTextStyles.sectionLabel,
          ),
          if (count != null)
            Text(
              count!,
              style: AppTextStyles.bodySmall.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
