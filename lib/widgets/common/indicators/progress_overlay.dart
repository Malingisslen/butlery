// lib/widgets/common/indicators/progress_overlay.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Reusable progress overlay component
/// Provides consistent styling for upload/loading overlays.
/// Used for avatar uploads, file processing, etc.
class ProgressOverlay extends StatelessWidget {
  final String text;
  final BoxShape shape;
  final Color? backgroundColor;
  final Color? progressColor;
  final Color? textColor;

  const ProgressOverlay({
    super.key,
    required this.text,
    this.shape = BoxShape.circle,
    this.backgroundColor,
    this.progressColor,
    this.textColor,
  });

  /// Circular progress overlay for avatar uploads
  const ProgressOverlay.avatar({
    super.key,
    required this.text,
  })  : shape = BoxShape.circle,
        backgroundColor = null,
        progressColor = null,
        textColor = null;

  /// Rectangular progress overlay for general use
  const ProgressOverlay.rectangle({
    super.key,
    required this.text,
    this.backgroundColor,
    this.progressColor,
    this.textColor,
  }) : shape = BoxShape.rectangle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: shape,
          color: backgroundColor ??
              cs.onSurface.withValues(alpha: AppDimensions.opacityDark),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                strokeWidth: 2,
                color: progressColor ?? cs.surfaceContainerHighest,
              ),
              const SizedBox(height: AppDimensions.spacingXs),
              Text(
                text,
                style: AppTextStyles.bodySmall.copyWith(
                  color: textColor ?? cs.surfaceContainerHighest,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
