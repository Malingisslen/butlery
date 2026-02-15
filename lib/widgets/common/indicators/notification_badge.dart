// lib/widgets/common/indicators/notification_badge.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Reusable notification badge component
/// Provides consistent styling for notification count badges.
/// Encapsulates the visual design while allowing flexible content.
class NotificationBadge extends StatelessWidget {
  final int count;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;

  const NotificationBadge({
    super.key,
    required this.count,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingXs),
      decoration: BoxDecoration(
        color: backgroundColor ?? cs.error,
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor ?? cs.surface,
          width: AppDimensions.borderWidthThick,
        ),
      ),
      constraints: const BoxConstraints(
        minWidth: 20,
        minHeight: 20,
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: AppTextStyles.badge.copyWith(
          color: textColor ?? cs.surfaceContainerHighest,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
