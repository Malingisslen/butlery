// lib/widgets/common/layout/bottom_action_container.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Reusable bottom action container component
/// 
/// Provides consistent styling for bottom action bars and containers.
/// Features a top border and background color with safe area handling.
class BottomActionContainer extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final Color? borderColor;
  final EdgeInsets? padding;

  const BottomActionContainer({
    super.key,
    required this.child,
    this.backgroundColor,
    this.borderColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.backgroundBeige,
        border: Border(
          top: BorderSide(
            color: borderColor ?? AppColors.divider,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(child: child),
    );
  }
}