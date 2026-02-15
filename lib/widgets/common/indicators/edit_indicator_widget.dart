// lib/widgets/common/indicators/edit_indicator_widget.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/utils/animation_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Edit indicator widget showing active editor
class EditIndicatorWidget extends StatefulWidget {
  final String editorName;
  final String? editorId;
  final String editingWhat;
  final Color? color;
  final bool isVisible;
  final Duration animationDuration;

  const EditIndicatorWidget({
    super.key,
    required this.editorName,
    this.editorId,
    required this.editingWhat,
    this.color,
    this.isVisible = true,
    this.animationDuration = AppDimensions.animationDurationCommon,
  });

  @override
  State<EditIndicatorWidget> createState() => _EditIndicatorWidgetState();
}

class _EditIndicatorWidgetState extends State<EditIndicatorWidget>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.isVisible) {
      _fadeController.forward();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = !AnimationUtils.shouldAnimate(context);
    if (_reduceMotion) {
      _fadeController.duration = Duration.zero;
      _pulseController.stop();
    } else {
      _fadeController.duration = widget.animationDuration;
      if (widget.isVisible && !_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    }
  }

  @override
  void didUpdateWidget(EditIndicatorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _fadeController.forward();
        // Only start pulse animation if reduced motion is not enabled
        if (!_reduceMotion) {
          _pulseController.repeat(reverse: true);
        }
      } else {
        _fadeController.reverse();
        _pulseController.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingS,
                vertical: AppDimensions.spacingXs),
            decoration: BoxDecoration(
              color: color.withValues(alpha: AppDimensions.opacityVeryLight),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadius12),
              border: Border.all(
                color:
                    color.withValues(alpha: AppDimensions.opacityMediumLight),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Show static dot when reduced motion is enabled
                if (_reduceMotion)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.borderRadius4),
                    ),
                  )
                else
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(
                                AppDimensions.borderRadius4),
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(width: AppDimensions.spacingTight),
                Text(
                  '${widget.editorName} redigerar ${widget.editingWhat}',
                  style: AppTextStyles.metadataEmphasized.copyWith(
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }
}
