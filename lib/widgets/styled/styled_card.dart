// lib/widgets/styled/styled_card.dart

import 'package:flutter/material.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_constants.dart';

/// Pre-styled card widgets to eliminate design-in-views violations
/// Provides consistent card styling patterns used throughout the app
class StyledCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double? elevation;
  final double? borderRadius;
  final bool showBorder;
  final Color? borderColor;

  const StyledCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.elevation,
    this.borderRadius,
    this.showBorder = false,
    this.borderColor,
  });

  /// Standard card with default Material Design styling
  const StyledCard.standard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
  }) : elevation = AppDimensions.elevationLow,
       borderRadius = AppDimensions.borderRadius8,
       showBorder = false,
       borderColor = null;

  /// Elevated card with higher shadow
  const StyledCard.elevated({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
  }) : elevation = AppDimensions.elevationMedium,
       borderRadius = AppDimensions.borderRadius12,
       showBorder = false,
       borderColor = null;

  /// Outlined card with border instead of shadow
  const StyledCard.outlined({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
  }) : elevation = 0,
       borderRadius = AppDimensions.borderRadius8,
       showBorder = true;

  /// Recipe card styling
  const StyledCard.recipe({
    super.key,
    required this.child,
    this.onTap,
    this.backgroundColor,
  }) : padding = null,
       margin = null,
       elevation = AppDimensions.elevationLow,
       borderRadius = AppDimensions.borderRadius12,
       showBorder = false,
       borderColor = null;

  /// List item card (lower elevation)
  const StyledCard.listItem({
    super.key,
    required this.child,
    this.onTap,
    this.backgroundColor,
  }) : padding = null,
       margin = null,
       elevation = 1,
       borderRadius = AppDimensions.borderRadius8,
       showBorder = false,
       borderColor = null;

  /// Dialog card (high elevation)
  const StyledCard.dialog({
    super.key,
    required this.child,
  }) : padding = null,
       margin = null,
       onTap = null,
       backgroundColor = null,
       elevation = AppDimensions.elevationHigh,
       borderRadius = AppDimensions.borderRadius16,
       showBorder = false,
       borderColor = null;

  /// Selection card (for pickers, selectors)
  const StyledCard.selection({
    super.key,
    required this.child,
    this.onTap,
    this.backgroundColor,
    required bool isSelected,
  }) : padding = null,
       margin = null,
       elevation = isSelected ? AppDimensions.elevationMedium : 1,
       borderRadius = AppDimensions.borderRadius8,
       showBorder = isSelected,
       borderColor = isSelected ? AppColors.primaryBlue : null;

  @override
  Widget build(BuildContext context) {
    final cardTheme = Theme.of(context).cardTheme;
    
    // Determine default padding based on card type
    EdgeInsetsGeometry? effectivePadding = padding;
    EdgeInsetsGeometry? effectiveMargin = margin;
    
    // Apply default spacing for specific card types
    if (padding == null) {
      if (runtimeType.toString().contains('recipe')) {
        effectivePadding = EdgeInsets.all(AppDimensions.spacing12);
        effectiveMargin = EdgeInsets.all(AppDimensions.spacing8);
      } else if (runtimeType.toString().contains('listItem')) {
        effectivePadding = AppDimensions.listItemPadding;
        effectiveMargin = EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing8,
          vertical: AppDimensions.spacing4,
        );
      } else if (runtimeType.toString().contains('dialog')) {
        effectivePadding = EdgeInsets.all(AppDimensions.spacing24);
      } else if (runtimeType.toString().contains('selection')) {
        effectivePadding = EdgeInsets.all(AppDimensions.spacing12);
        effectiveMargin = EdgeInsets.all(AppDimensions.spacing4);
      }
    }
    
    Widget card = Card(
      color: backgroundColor ?? cardTheme.color,
      elevation: elevation ?? cardTheme.elevation,
      margin: effectiveMargin ?? EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          borderRadius ?? AppDimensions.borderRadius8,
        ),
        side: showBorder
            ? BorderSide(
                color: borderColor ?? Theme.of(context).colorScheme.outline,
                width: AppDimensions.borderWidthStandard,
              )
            : BorderSide.none,
      ),
      child: effectivePadding != null
          ? Padding(
              padding: effectivePadding,
              child: child,
            )
          : child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          borderRadius ?? AppDimensions.borderRadius8,
        ),
        child: card,
      );
    }

    return card;
  }
}

/// Specialized card variants for specific content types
class StyledCards {
  
  /// Empty state card
  static Widget emptyState({
    required Widget child,
    VoidCallback? onAction,
  }) {
    return StyledCard.outlined(
      padding: EdgeInsets.all(AppDimensions.spacing24),
      onTap: onAction,
      child: child,
    );
  }

  /// Error state card
  static Widget error({
    required Widget child,
    VoidCallback? onRetry,
  }) {
    return StyledCard.outlined(
      backgroundColor: AppColors.errorContainer,
      borderColor: AppColors.error,
      padding: EdgeInsets.all(AppDimensions.spacing16),
      onTap: onRetry,
      child: child,
    );
  }

  /// Info card
  static Widget info({
    required Widget child,
  }) {
    return StyledCard.outlined(
      backgroundColor: AppColors.infoContainer,
      borderColor: AppColors.info,
      padding: EdgeInsets.all(AppDimensions.spacing16),
      child: child,
    );
  }

  /// Success card
  static Widget success({
    required Widget child,
  }) {
    return StyledCard.outlined(
      backgroundColor: AppColors.successContainer,
      borderColor: AppColors.success,
      padding: EdgeInsets.all(AppDimensions.spacing16),
      child: child,
    );
  }

  /// Warning card
  static Widget warning({
    required Widget child,
  }) {
    return StyledCard.outlined(
      backgroundColor: AppColors.warningContainer,
      borderColor: AppColors.warning,
      padding: EdgeInsets.all(AppDimensions.spacing16),
      child: child,
    );
  }

  /// Loading card placeholder
  static Widget loading({
    double? height,
    double? width,
  }) {
    return StyledCard.standard(
      child: Container(
        height: height ?? 100,
        width: width,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.grey.shade200,
              Colors.grey.shade100,
              Colors.grey.shade200,
            ],
            stops: const [0.0, 0.5, 1.0],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
      ),
    );
  }

  /// Image card for galleries
  static Widget image({
    required Widget imageWidget,
    Widget? overlay,
    VoidCallback? onTap,
  }) {
    return StyledCard.standard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
        child: Stack(
          children: [
            imageWidget,
            if (overlay != null)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: ThemeConstants.blackOverlay20,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.borderRadius8,
                    ),
                  ),
                  child: overlay,
                ),
              ),
          ],
        ),
      ),
    );
  }
}