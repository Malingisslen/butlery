// lib/widgets/social/collaborative/components/collaborative_live_widgets.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/utils/animation_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';

/// Live editing indicators and animations for collaborative content
class CollaborativeLiveWidgets {
  /// Show real-time "X is editing now" indicator
  static Widget editIndicator({
    required String editorName,
    required String editingWhat,
    Color? color,
    bool isVisible = true,
    Duration animationDuration = AppDimensions.animationDurationCommon,
  }) {
    if (!isVisible) return const SizedBox.shrink();

    return Builder(builder: (context) {
      return TweenAnimationBuilder<double>(
        duration: AnimationUtils.getDuration(context, animationDuration),
        tween: Tween<double>(begin: 0.0, end: isVisible ? 1.0 : 0.0),
        builder: (context, opacity, child) {
          final indicatorColor = color ?? context.butleryColors.warning;
          return Opacity(
            opacity: opacity,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacingS,
                vertical: AppDimensions.spacingXs,
              ),
              decoration: BoxDecoration(
                color: indicatorColor.withValues(
                    alpha: AppDimensions.opacityVeryLight),
                borderRadius: BorderRadius.circular(AppDimensions.chipRadius),
                border: Border.all(
                  color: indicatorColor.withValues(
                      alpha: AppDimensions.opacityMediumLight),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  pulsingDot(indicatorColor),
                  const SizedBox(width: AppDimensions.spacingXs),
                  Text(
                    '$editorName redigerar $editingWhat',
                    style: AppTextStyles.metadataEmphasized.copyWith(
                      color: indicatorColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
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
  bool _reduceMotion = false;

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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = !AnimationUtils.shouldAnimate(context);
    if (_reduceMotion) {
      _controller.stop();
      _controller.value = 1.0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
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
