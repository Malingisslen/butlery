// lib/widgets/common/buttons/overlay_button.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Reusable overlay button component
/// Provides consistent styling for buttons overlaid on content.
/// Used for remove buttons, edit buttons, etc. on images and cards.
class OverlayButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final String? tooltip;

  const OverlayButton({
    super.key,
    required this.child,
    this.onPressed,
    this.backgroundColor,
    this.tooltip,
  });

  /// Remove button variant
  const OverlayButton.remove({
    super.key,
    required this.onPressed,
    this.tooltip,
  })  : child = const Icon(Icons.clear, color: AppColors.neutralLight),
        backgroundColor = null;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color:
            backgroundColor ?? AppColors.backgroundBeige.withValues(alpha: AppDimensions.opacityVeryDark),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      ),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: child,
      ),
    );
  }
}
