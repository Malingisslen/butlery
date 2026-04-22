// lib/widgets/common/tappable_wrapper.dart
//
// Wraps a tappable child in a 48x48dp hit region (WCAG 2.5.5).
// Use for custom chip/badge/icon tappables where the visual is smaller than
// the Material minimum touch target. `IconButton` already enforces 48dp via
// Material defaults — do NOT wrap those.

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Wraps a tappable child so the hit region is at least
/// [AppDimensions.minTouchTarget] in both axes, regardless of child size.
///
/// Uses [HitTestBehavior.opaque] so the full 48dp area catches taps even
/// around transparent padding. Announces as a button via [Semantics].
///
/// Example:
/// ```dart
/// TappableWrapper(
///   semanticLabel: 'Ta bort tagg',
///   onTap: _remove,
///   child: const Icon(Icons.close, size: 14),
/// )
/// ```
class TappableWrapper extends StatelessWidget {
  const TappableWrapper({
    required this.onTap,
    required this.child,
    required this.semanticLabel,
    this.onLongPress,
    this.useMaterialInk = false,
    this.alignment = Alignment.center,
    this.enabled = true,
    super.key,
  });

  /// Called on single tap. Disabled when [enabled] is false.
  final VoidCallback? onTap;

  /// Called on long-press. Optional.
  final VoidCallback? onLongPress;

  /// The visual content being wrapped (chip, icon, badge, etc.).
  final Widget child;

  /// Required screen-reader label (WCAG 4.1.2).
  final String semanticLabel;

  /// When true, uses [InkWell] for Material ripple feedback.
  /// When false (default), uses [GestureDetector] — no visual feedback.
  /// Prefer [InkWell] in Material surfaces, [GestureDetector] on custom paint.
  final bool useMaterialInk;

  /// Alignment of the child inside the enforced 48dp area.
  final AlignmentGeometry alignment;

  /// Whether taps are active. Disabled targets still claim the 48dp area.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? effectiveOnTap = enabled ? onTap : null;
    final VoidCallback? effectiveOnLongPress = enabled ? onLongPress : null;

    final Widget padded = Align(
      alignment: alignment,
      child: child,
    );

    final Widget gestureLayer = useMaterialInk
        ? InkWell(
            onTap: effectiveOnTap,
            onLongPress: effectiveOnLongPress,
            child: padded,
          )
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: effectiveOnTap,
            onLongPress: effectiveOnLongPress,
            child: padded,
          );

    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: enabled && effectiveOnTap != null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: AppDimensions.minTouchTarget,
          minHeight: AppDimensions.minTouchTarget,
        ),
        child: gestureLayer,
      ),
    );
  }
}
