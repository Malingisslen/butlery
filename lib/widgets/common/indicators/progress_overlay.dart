// lib/widgets/common/indicators/progress_overlay.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';

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
  }) : shape = BoxShape.circle,
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

  /// The line's width inside the overlay. Interpretation: the avatar overlay
  /// is small, so the line is 48 dp, one touch target, not the drawn 300.
  static const double overlayLineWidth = AppDimensions.minTouchTarget;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: shape,
          color:
              backgroundColor ??
              cs.onSurface.withValues(alpha: AppDimensions.opacityDark),
        ),
        // Text plus the plate line, never a spinner (produktregler.md:163,
        // B-18). The overlay is a dark scrim, so the line takes the in-button
        // form in the overlay's own text colour (Komponentark v1:307).
        child: Center(
          child: Semantics(
            liveRegion: true,
            label: text,
            child: ExcludeSemantics(
              child: SizedBox(
                width: overlayLineWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      text,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: textColor ?? cs.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingXs),
                    ButtonPlateLine(
                      color: progressColor ?? cs.surfaceContainerHighest,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
