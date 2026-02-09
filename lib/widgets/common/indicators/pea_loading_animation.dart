/// Animated pea pod loading indicator with stop-motion style animation.
///
/// Uses the arta/artskida0-5.PNG frames to create a breathing animation
/// where peas fill and empty (0→5→0 loop) with 100-150ms frame swaps.

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Animated pea pod loading indicator.
///
/// Displays a 6-frame stop-motion animation of a pea pod filling
/// with peas, then emptying, creating a breathing loop effect.
///
/// Example:
/// ```dart
/// PeaLoadingAnimation(
///   size: 80,
/// )
/// ```
class PeaLoadingAnimation extends StatefulWidget {
  /// Creates a pea loading animation.
  ///
  /// UI Redesign: Updated frame interval to ~310ms for 3.1s cycle
  /// matching the mockup CSS timing (10 frames × 310ms = 3.1s).
  const PeaLoadingAnimation({
    this.size = 80,
    this.frameInterval = const Duration(milliseconds: 310),
    super.key,
  });

  /// The size (width and height) of the animation.
  final double size;

  /// Duration between frame changes (100-150ms for stop-motion feel).
  final Duration frameInterval;

  @override
  State<PeaLoadingAnimation> createState() => _PeaLoadingAnimationState();
}

class _PeaLoadingAnimationState extends State<PeaLoadingAnimation>
    with SingleTickerProviderStateMixin {
  /// Frame paths for the animation (0→5 fills up, then 5→0 empties)
  static const _framePaths = [
    'assets/illustrations/arta/artskida0.PNG',
    'assets/illustrations/arta/artskida1.PNG',
    'assets/illustrations/arta/artskida2.PNG',
    'assets/illustrations/arta/artskida3.PNG',
    'assets/illustrations/arta/artskida4.PNG',
    'assets/illustrations/arta/artskida5.PNG',
  ];

  /// Animation sequence: 0,1,2,3,4,5,4,3,2,1 (breathing pattern)
  static const _frameSequence = [0, 1, 2, 3, 4, 5, 4, 3, 2, 1];

  int _currentSequenceIndex = 0;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _startAnimation() {
    if (_isDisposed) return;

    Future.delayed(widget.frameInterval, () {
      if (_isDisposed || !mounted) return;

      setState(() {
        _currentSequenceIndex =
            (_currentSequenceIndex + 1) % _frameSequence.length;
      });

      _startAnimation();
    });
  }

  @override
  Widget build(BuildContext context) {
    final frameIndex = _frameSequence[_currentSequenceIndex];

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Image.asset(
        _framePaths[frameIndex],
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        gaplessPlayback: true, // Smooth frame transitions
        errorBuilder: (context, error, stackTrace) {
          // Fallback to a standard loading indicator
          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A loading overlay that uses the pea animation.
///
/// Displays a semi-transparent overlay with the pea animation centered.
class PeaLoadingOverlay extends StatelessWidget {
  /// Creates a pea loading overlay.
  const PeaLoadingOverlay({
    this.message,
    this.subtitle,
    this.size = 100,
    super.key,
  });

  /// Optional message to display below the animation.
  final String? message;

  /// Optional subtitle below the message.
  final String? subtitle;

  /// Size of the animation.
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ColoredBox(
      color: theme.colorScheme.surface.withValues(alpha: 0.9),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PeaLoadingAnimation(size: size),
            if (message != null) ...[
              const SizedBox(height: AppDimensions.spacingMd),
              Text(
                message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (subtitle != null) ...[
              const SizedBox(height: AppDimensions.spacingSm),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A small inline pea loading indicator.
///
/// Use this for smaller loading states within content.
class PeaLoadingIndicatorSmall extends StatelessWidget {
  /// Creates a small pea loading indicator.
  const PeaLoadingIndicatorSmall({
    this.size = 40,
    super.key,
  });

  /// Size of the animation.
  final double size;

  @override
  Widget build(BuildContext context) {
    return PeaLoadingAnimation(
      size: size,
      frameInterval:
          const Duration(milliseconds: 100), // Slightly faster for small
    );
  }
}
