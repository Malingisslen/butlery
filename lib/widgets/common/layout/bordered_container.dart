// lib/widgets/common/layout/bordered_container.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Reusable bordered container component
/// 
/// Provides consistent styling for containers with borders.
/// Used for selection areas, content boxes, etc.
class BorderedContainer extends StatelessWidget {
  final Widget child;
  final double? height;
  final double? width;
  final Color? borderColor;
  final EdgeInsetsGeometry? padding;

  const BorderedContainer({
    super.key,
    required this.child,
    this.height,
    this.width,
    this.borderColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        border: Border.all(
          color: borderColor ?? Theme.of(context).colorScheme.outline,
        ),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      ),
      child: child,
    );
  }
}