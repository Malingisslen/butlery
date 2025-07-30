// lib/widgets/common/layout/card_content.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Reusable card content component
/// 
/// Provides consistent padding inside cards.
/// This component is allowed to use Padding since it's a reusable pattern.
class CardContent extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const CardContent({
    super.key,
    required this.child,
    this.padding,
  });

  /// Standard padding card content
  const CardContent.standard({
    super.key,
    required this.child,
  }) : padding = const EdgeInsets.all(AppDimensions.spacingL);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppDimensions.spacingL),
        child: child,
      ),
    );
  }
}