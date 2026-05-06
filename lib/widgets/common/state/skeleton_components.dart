import 'package:flutter/material.dart';
import 'package:butlery/core/utils/animation_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Skeleton loading components.
class SkeletonComponents {
  /// Create a skeleton box with shimmer animation.
  static Widget skeletonBox({
    double? width,
    double? height,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry? margin,
  }) {
    return _SkeletonBox(
      width: width,
      height: height,
      borderRadius: borderRadius,
      margin: margin,
    );
  }
}

class _SkeletonBox extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? margin;

  const _SkeletonBox({
    this.width,
    this.height,
    this.borderRadius,
    this.margin,
  });

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = !AnimationUtils.shouldAnimate(context);
    if (!_reduceMotion && !_shimmerController.isAnimating) {
      _shimmerController.repeat();
    } else if (_reduceMotion && _shimmerController.isAnimating) {
      _shimmerController.stop();
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Show static skeleton when reduced motion is enabled
    if (_reduceMotion) {
      return Container(
        width: widget.width,
        height: widget.height,
        margin: widget.margin,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius ??
              BorderRadius.circular(AppDimensions.borderRadiusS),
          color: cs.surfaceContainerHighest,
        ),
      );
    }

    return Container(
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius ??
            BorderRadius.circular(AppDimensions.borderRadiusS),
        gradient: LinearGradient(
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: [
            cs.onSurfaceVariant,
            cs.surfaceContainerHighest,
            cs.onSurfaceVariant
          ],
          stops: const [0.0, 0.5, 1.0],
          transform: _GradientRotation(_shimmerController),
        ),
      ),
    );
  }
}

/// Transform for shimmer effect
class _GradientRotation extends GradientTransform {
  final Animation<double> animation;

  const _GradientRotation(this.animation);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final double x = animation.value * 3 - 1;
    return Matrix4.translationValues(bounds.width * x, 0, 0);
  }
}
