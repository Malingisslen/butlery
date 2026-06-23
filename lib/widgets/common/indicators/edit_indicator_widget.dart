// lib/widgets/common/indicators/edit_indicator_widget.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/utils/animation_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/indicators/pulse_dot.dart';

/// Edit indicator widget showing active editor.
///
/// BUT-408: the pulsing dot portion is now delegated to the reusable
/// [PulseDot] widget so cooking session cards (and any future live-presence
/// UI) can share the same reduce-motion-aware animation.
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
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    if (widget.isVisible) {
      _fadeController.forward();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fadeController.duration = AnimationUtils.shouldAnimate(context)
        ? widget.animationDuration
        : Duration.zero;
  }

  @override
  void didUpdateWidget(EditIndicatorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _fadeController.forward();
      } else {
        _fadeController.reverse();
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
              vertical: AppDimensions.spacingXs,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: AppDimensions.opacityVeryLight),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadius12),
              border: Border.all(
                color: color.withValues(
                  alpha: AppDimensions.opacityMediumLight,
                ),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PulseDot(color: color, size: 8),
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
    super.dispose();
  }
}
