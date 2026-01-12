// lib/widgets/common/content_cards/image_preview_card.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Reusable image preview card component
/// Provides consistent styling for image preview displays.
/// Supports different states (loading, with image, empty).
class ImagePreviewCard extends StatelessWidget {
  final Widget child;
  final double? height;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? boxShadow;
  final bool showBorder;
  final Color? borderColor;
  final double? borderWidth;

  const ImagePreviewCard({
    super.key,
    required this.child,
    this.height,
    this.backgroundColor,
    this.borderRadius,
    this.boxShadow,
    this.showBorder = false,
    this.borderColor,
    this.borderWidth,
  });

  /// Loading state card
  const ImagePreviewCard.loading({
    super.key,
    required this.child,
    this.height,
  })  : backgroundColor = AppColors.cardWhite,
        borderRadius = const BorderRadius.all(
            Radius.circular(AppDimensions.borderRadiusL)),
        boxShadow = AppDimensions.cardShadow,
        showBorder = false,
        borderColor = null,
        borderWidth = null;

  /// Empty state card with border
  ImagePreviewCard.empty({
    super.key,
    required this.child,
    this.height,
    required BuildContext context,
  })  : backgroundColor = Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius = const BorderRadius.all(
            Radius.circular(AppDimensions.borderRadiusL)),
        boxShadow = null,
        showBorder = true,
        borderColor = Theme.of(context).colorScheme.outline,
        borderWidth = 2.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height ?? AppDimensions.imageHeightMedium,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius:
            borderRadius ?? BorderRadius.circular(AppDimensions.borderRadiusL),
        boxShadow: boxShadow,
        border: showBorder
            ? Border.all(
                color: borderColor ?? Theme.of(context).colorScheme.outline,
                width: borderWidth ?? 1.0,
                style: BorderStyle.solid,
              )
            : null,
      ),
      child: child,
    );
  }
}
