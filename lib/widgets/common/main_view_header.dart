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
import 'package:butlery/theme/app_shadows.dart';
import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';

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
    this.ghostIllustration,
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

  /// Optional ghost illustration type for decorative background.
  final VegetableType? ghostIllustration;

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
          color: cs.primary,
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: headerHeight,
              child: IconTheme(
                data: IconThemeData(color: cs.surface),
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    if (ghostIllustration != null)
                      HeaderGhostIllustration(type: ghostIllustration!),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimensions.spacingL,
                        AppDimensions.spacingMd,
                        AppDimensions.spacingL,
                        AppDimensions.spacingL,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title and count badge (count to the right of title)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    // Title — cream on dark green. FittedBox
                                    // scales long single-word titles
                                    // ("inköpslista", "lägg till recept") down
                                    // so they don't mid-word wrap or clip at
                                    // narrow widths, while still wrapping
                                    // multi-word titles naturally.
                                    Flexible(
                                      child: Semantics(
                                        header: true,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.bottomLeft,
                                          child: Text(
                                            title.toLowerCase(),
                                            style: AppTextStyles.mainViewTitle
                                                .copyWith(
                                              color: cs.surface,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Count badge — rust text, to the right
                                    if (countBadge != null) ...[
                                      const SizedBox(
                                          width: AppDimensions.spacingSm),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            bottom: AppDimensions.spacingXs),
                                        child: Semantics(
                                          liveRegion: true,
                                          child: Text(
                                            countBadge!,
                                            style:
                                                AppTextStyles.headerCountBadge,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Actions and trailing — cream icons on dark green
                          IconButtonTheme(
                            data: IconButtonThemeData(
                              style: IconButton.styleFrom(
                                foregroundColor: cs.surface,
                              ),
                            ),
                            child: Column(
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
                          ),
                        ],
                      ),
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
    return Semantics(
      label: label,
      button: true,
      selected: isSelected,
      child: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: isSelected ? AppShadows.activeChip(cs.primary) : null,
        ),
        child: Material(
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
                border:
                    isSelected ? null : Border.all(color: cs.primary, width: 2),
              ),
              child: Text(
                label,
                style: AppTextStyles.filterChip.copyWith(
                  color: isSelected ? cs.surface : cs.primaryContainer,
                ),
              ),
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
    final effectiveAccentColor = accentColor ?? cs.primary;
    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: AppDimensions.spacingSm,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingL,
        vertical: AppDimensions.spacingSm,
      ),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.06),
        border: Border(
          left: BorderSide(
            color: effectiveAccentColor,
            width: 3,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Semantics(
            header: true,
            child: Text(
              label.toLowerCase(),
              style: AppTextStyles.sectionLabel,
            ),
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
