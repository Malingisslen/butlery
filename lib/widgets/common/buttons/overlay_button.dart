// lib/widgets/common/buttons/overlay_button.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/theme_constants.dart';

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
  })  : child = const Icon(Icons.clear),
        backgroundColor = null;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        // Dark scrim behind the light icon — the previous light-surface scrim
        // gave a light-on-light icon with poor contrast over photos.
        color: backgroundColor ?? ThemeConstants.blackOverlay60,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      ),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: IconTheme(
          data: IconThemeData(color: cs.surfaceContainerHighest),
          child: child,
        ),
      ),
    );
  }
}
