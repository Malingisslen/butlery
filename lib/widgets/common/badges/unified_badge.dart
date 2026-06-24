/// Unified badge system for tags and allergens.
///
/// Provides consistent badge styling across the app for:
/// - Recipe tags (personal categorization)
/// - Allergens (dietary restrictions)
/// - Category labels

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/accessibility_utils.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/hoverable_tap.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';

/// Type of badge to display.
enum BadgeType {
  /// Personal tag (user-created categorization)
  tag,

  /// Allergen/dietary restriction
  allergen,

  /// Shopping category
  category,

  /// Generic/custom badge
  custom,
}

/// Visual variant for badges.
enum BadgeVariant {
  /// Filled background with contrasting text
  filled,

  /// Outlined with colored border
  outlined,

  /// Subtle background tint
  subtle,
}

/// A unified badge widget for tags, allergens, and categories.
///
/// Example:
/// ```dart
/// UnifiedBadge(
///   label: 'Vegetariskt',
///   type: BadgeType.tag,
///   variant: BadgeVariant.filled,
/// )
/// ```
class UnifiedBadge extends StatelessWidget {
  /// Creates a unified badge.
  const UnifiedBadge({
    required this.label,
    this.type = BadgeType.tag,
    this.variant = BadgeVariant.subtle,
    this.color,
    this.icon,
    this.onTap,
    this.onRemove,
    this.isSelected = false,
    this.size = BadgeSize.medium,
    super.key,
  });

  /// The text label for the badge.
  final String label;

  /// The type of badge.
  final BadgeType type;

  /// Visual variant of the badge.
  final BadgeVariant variant;

  /// Custom color override. If null, uses default for type.
  final Color? color;

  /// Optional icon to display before the label.
  final IconData? icon;

  /// Callback when the badge is tapped.
  final VoidCallback? onTap;

  /// Callback to remove the badge (shows X button).
  final VoidCallback? onRemove;

  /// Whether this badge is selected.
  final bool isSelected;

  /// Size of the badge.
  final BadgeSize size;

  Color _getBaseColor(BuildContext context) {
    if (color != null) return color!;

    final cs = Theme.of(context).colorScheme;
    switch (type) {
      case BadgeType.tag:
        return cs.primary;
      case BadgeType.allergen:
        return context.butleryColors.warning;
      case BadgeType.category:
        return cs.secondary;
      case BadgeType.custom:
        return cs.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = _getBaseColor(context);
    final dimensions = _getBadgeDimensions();

    Color backgroundColor;
    Color textColor;
    Color? borderColor;

    final cs = Theme.of(context).colorScheme;
    if (isSelected) {
      backgroundColor = baseColor;
      textColor = cs.surfaceContainerHighest;
      borderColor = null;
    } else {
      switch (variant) {
        case BadgeVariant.filled:
          backgroundColor = baseColor;
          textColor = cs.surfaceContainerHighest;
          borderColor = null;
        case BadgeVariant.outlined:
          backgroundColor = Colors.transparent;
          textColor = baseColor;
          borderColor = baseColor;
        case BadgeVariant.subtle:
          backgroundColor = baseColor.withValues(alpha: 0.1);
          textColor = baseColor;
          borderColor = null;
      }
    }

    final badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: dimensions.horizontalPadding,
        vertical: dimensions.verticalPadding,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.zero,
        border: borderColor != null
            ? Border.all(color: borderColor, width: 1)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: dimensions.iconSize,
              color: textColor,
            ),
            SizedBox(width: dimensions.iconSpacing),
          ],
          Text(
            label,
            style: AppTextStyles.badgeText.copyWith(
              color: textColor,
              fontSize: dimensions.fontSize,
            ),
          ),
          if (onRemove != null) ...[
            SizedBox(width: dimensions.iconSpacing),
            Semantics(
              label: context.l10n.commonRemoveLabel(label),
              button: true,
              child: HoverableTap(
                child: GestureDetector(
                  onTap: onRemove,
                  child: Icon(
                    Icons.close,
                    size: dimensions.iconSize,
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    Widget result = badge;
    if (onTap != null) {
      result = Semantics(
        label: label,
        button: true,
        child: HoverableTap(
          child: GestureDetector(
            onTap: onTap,
            child: badge,
          ),
        ),
      );
    }

    // Clamp text scaling for small badges to prevent overflow
    if (size == BadgeSize.small) {
      result = AccessibilityUtils.clampTextScaling(
        context: context,
        child: result,
      );
    }

    return result;
  }

  _BadgeDimensions _getBadgeDimensions() {
    switch (size) {
      case BadgeSize.small:
        return const _BadgeDimensions(
          horizontalPadding: 8,
          verticalPadding: 2,
          fontSize: 10,
          iconSize: 12,
          iconSpacing: 4,
        );
      case BadgeSize.medium:
        return const _BadgeDimensions(
          horizontalPadding: 12,
          verticalPadding: 4,
          fontSize: 12,
          iconSize: 14,
          iconSpacing: 4,
        );
      case BadgeSize.large:
        return const _BadgeDimensions(
          horizontalPadding: 16,
          verticalPadding: 6,
          fontSize: 14,
          iconSize: 16,
          iconSpacing: 6,
        );
    }
  }
}

/// Size variants for badges.
enum BadgeSize {
  small,
  medium,
  large,
}

class _BadgeDimensions {
  const _BadgeDimensions({
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.fontSize,
    required this.iconSize,
    required this.iconSpacing,
  });

  final double horizontalPadding;
  final double verticalPadding;
  final double fontSize;
  final double iconSize;
  final double iconSpacing;
}

/// A row of badges with proper spacing and wrapping.
class BadgeRow extends StatelessWidget {
  /// Creates a badge row.
  const BadgeRow({
    required this.badges,
    this.spacing = AppDimensions.spacingSm,
    this.runSpacing = AppDimensions.spacingXs,
    this.alignment = WrapAlignment.start,
    super.key,
  });

  /// List of badges to display.
  final List<Widget> badges;

  /// Horizontal spacing between badges.
  final double spacing;

  /// Vertical spacing between badge rows.
  final double runSpacing;

  /// Alignment of badges.
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      alignment: alignment,
      children: badges,
    );
  }
}

/// A badge specifically for allergens with appropriate styling.
class AllergenBadge extends StatelessWidget {
  /// Creates an allergen badge.
  const AllergenBadge({
    required this.allergen,
    this.onTap,
    super.key,
  });

  /// The allergen name.
  final String allergen;

  /// Callback when tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return UnifiedBadge(
      label: allergen,
      type: BadgeType.allergen,
      variant: BadgeVariant.subtle,
      icon: Icons.warning_amber_outlined,
      onTap: onTap,
      size: BadgeSize.small,
    );
  }
}

/// A badge specifically for recipe tags.
class TagBadge extends StatelessWidget {
  /// Creates a tag badge.
  const TagBadge({
    required this.tag,
    this.color,
    this.onTap,
    this.onRemove,
    this.isSelected = false,
    super.key,
  });

  /// The tag name.
  final String tag;

  /// Custom color for the tag.
  final Color? color;

  /// Callback when tapped.
  final VoidCallback? onTap;

  /// Callback to remove the tag.
  final VoidCallback? onRemove;

  /// Whether the tag is selected.
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return UnifiedBadge(
      label: tag,
      type: BadgeType.tag,
      variant: isSelected ? BadgeVariant.filled : BadgeVariant.subtle,
      color: color,
      onTap: onTap,
      onRemove: onRemove,
      isSelected: isSelected,
    );
  }
}

/// A badge for shopping list categories.
class CategoryBadge extends StatelessWidget {
  /// Creates a category badge.
  const CategoryBadge({
    required this.category,
    this.color,
    super.key,
  });

  /// The category name.
  final String category;

  /// Custom color for the category.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return UnifiedBadge(
      label: category,
      type: BadgeType.category,
      variant: BadgeVariant.filled,
      color: color ?? _getCategoryColor(context, category),
      size: BadgeSize.small,
    );
  }

  Color _getCategoryColor(BuildContext context, String category) {
    final bc = context.butleryColors;
    final cs = Theme.of(context).colorScheme;
    final normalized = category.toLowerCase();

    if (normalized.contains('kött') || normalized.contains('fisk')) {
      return bc.categoryMeatFish;
    } else if (normalized.contains('mejeri')) {
      return bc.categoryDairy;
    } else if (normalized.contains('grönsak')) {
      return bc.categoryVegetables;
    } else if (normalized.contains('frukt')) {
      return bc.categoryFruit;
    } else if (normalized.contains('bröd') || normalized.contains('spannmål')) {
      return bc.categoryBreadGrains;
    } else if (normalized.contains('frys')) {
      return bc.categoryFrozen;
    } else if (normalized.contains('torr')) {
      return bc.categoryDryGoods;
    }

    // Algorithm for custom categories: hash-based color from palette
    final hash = category.hashCode.abs();
    final colors = [
      cs.primary,
      cs.secondary,
      bc.warning,
      bc.categoryDairy,
      bc.categoryFruit,
    ];
    return colors[hash % colors.length];
  }
}
