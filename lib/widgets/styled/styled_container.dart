/// Comprehensive styled container system providing consistent design patterns and eliminating design-in-views violations.
///
/// This widget system consolidates container styling patterns found throughout the application, providing consistent
/// visual design, spacing management, and layout organization. It eliminates design-in-views violations by
/// centralizing container styling logic and provides comprehensive container variants for all layout contexts
/// with proper theming support and responsive design patterns.

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/theme_constants.dart';
class StyledContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final double? borderRadius;
  final Color? borderColor;
  final double? borderWidth;
  final List<BoxShadow>? boxShadow;
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  const StyledContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderRadius,
    this.borderColor,
    this.borderWidth,
    this.boxShadow,
    this.width,
    this.height,
    this.onTap,
  });

  /// Card-style container with default styling
  const StyledContainer.card({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.onTap,
  }) : borderRadius = AppDimensions.borderRadius8,
       borderColor = null,
       borderWidth = null,
       boxShadow = ThemeConstants.elevationLow,
       width = null,
       height = null;

  /// Form section container
  const StyledContainer.section({
    super.key,
    required this.child,
    this.backgroundColor,
    this.onTap,
  }) : padding = AppDimensions.sectionPadding,
       margin = null,
       borderRadius = AppDimensions.borderRadius8,
       borderColor = null,
       borderWidth = null,
       boxShadow = null,
       width = null,
       height = null;

  /// List item container
  const StyledContainer.listItem({
    super.key,
    required this.child,
    this.backgroundColor,
    this.onTap,
  }) : padding = AppDimensions.listItemPadding,
       margin = null,
       borderRadius = AppDimensions.borderRadius4,
       borderColor = null,
       borderWidth = null,
       boxShadow = null,
       width = null,
       height = null;

  /// Dialog content container
  const StyledContainer.dialog({
    super.key,
    required this.child,
    this.backgroundColor,
  }) : padding = null,
       margin = null,
       borderRadius = AppDimensions.borderRadius12,
       borderColor = null,
       borderWidth = null,
       boxShadow = null,
       width = null,
       height = null,
       onTap = null;

  /// Input field container
  const StyledContainer.inputField({
    super.key,
    required this.child,
    this.backgroundColor,
    this.borderColor,
  }) : padding = null,
       margin = null,
       borderRadius = AppDimensions.borderRadius8,
       borderWidth = AppDimensions.borderWidthStandard,
       boxShadow = null,
       width = null,
       height = null,
       onTap = null;

  @override
  Widget build(BuildContext context) {
    final Widget container = Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? (Theme.of(context).brightness == Brightness.dark 
            ? AppColors.surfaceDark 
            : AppColors.cardWhite),
        borderRadius: borderRadius != null 
            ? BorderRadius.circular(borderRadius!) 
            : null,
        border: borderColor != null && borderWidth != null
            ? Border.all(color: borderColor!, width: borderWidth!)
            : null,
        boxShadow: boxShadow,
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: container,
      );
    }

    return container;
  }
}

/// Specialized styled containers for common use cases
class StyledContainers {
  
  /// Error state container
  static Widget error({
    required Widget child,
    VoidCallback? onRetry,
  }) {
    return StyledContainer(
      backgroundColor: AppColors.errorContainer,
      borderRadius: AppDimensions.borderRadius8,
      padding: const EdgeInsets.all(AppDimensions.spacingMd),
      onTap: onRetry,
      child: child,
    );
  }

  /// Success state container
  static Widget success({
    required Widget child,
  }) {
    return StyledContainer(
      backgroundColor: AppColors.successContainer,
      borderRadius: AppDimensions.borderRadius8,
      padding: const EdgeInsets.all(AppDimensions.spacingMd),
      child: child,
    );
  }

  /// Warning state container
  static Widget warning({
    required Widget child,
  }) {
    return StyledContainer(
      backgroundColor: AppColors.warningContainer,
      borderRadius: AppDimensions.borderRadius8,
      padding: const EdgeInsets.all(AppDimensions.spacingMd),
      child: child,
    );
  }

  /// Info state container
  static Widget info({
    required Widget child,
  }) {
    return StyledContainer(
      backgroundColor: AppColors.infoContainer,
      borderRadius: AppDimensions.borderRadius8,
      padding: const EdgeInsets.all(AppDimensions.spacingMd),
      child: child,
    );
  }
}