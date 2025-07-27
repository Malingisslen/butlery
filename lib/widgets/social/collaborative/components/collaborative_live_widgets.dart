// lib/widgets/social/collaborative/components/collaborative_live_widgets.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Live editing indicators and animations for collaborative content
class CollaborativeLiveWidgets {
  /// Show real-time "X is editing now" indicator
  static Widget editIndicator({
    required String editorName,
    required String editingWhat,
    Color? color,
    bool isVisible = true,
    Duration animationDuration = const Duration(milliseconds: 300),
  }) {
    if (!isVisible) return const SizedBox.shrink();

    final indicatorColor = color ?? AppColors.warningColor;

    return TweenAnimationBuilder<double>(
      duration: animationDuration,
      tween: Tween<double>(begin: 0.0, end: isVisible ? 1.0 : 0.0),
      builder: (context, opacity, child) {
        return Opacity(
          opacity: opacity,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingS,
              vertical: AppDimensions.spacingXs,
            ),
            decoration: BoxDecoration(
              color: indicatorColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.chipRadius),
              border: Border.all(
                color: indicatorColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                pulsingDot(indicatorColor),
                const SizedBox(width: AppDimensions.spacingXs),
                Text(
                  '$editorName redigerar $editingWhat',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: indicatorColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build a pulsing dot animation
  static Widget pulsingDot(Color color) {
    return SizedBox(
      width: 8,
      height: 8,
      child: _PulsingDot(color: color),
    );
  }
}

/// Pulsing dot animation widget
class _PulsingDot extends StatefulWidget {
  final Color color;

  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: _animation.value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}