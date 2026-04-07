// lib/widgets/common/stat_item_widget.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Reusable stat item: icon + value + label in a vertical column.
/// Used across profile views, group detail, and category statistics.
class StatItemWidget extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? color;
  final Color? labelColor;
  final double? iconSize;
  final TextStyle? valueStyle;
  final TextStyle? labelStyle;

  const StatItemWidget({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.color,
    this.labelColor,
    this.iconSize,
    this.valueStyle,
    this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveColor = color ?? cs.primary;
    final effectiveLabelColor = labelColor ?? cs.onSurfaceVariant;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            color: effectiveColor, size: iconSize ?? AppDimensions.iconSizeXl),
        const SizedBox(height: AppDimensions.spacingXs),
        Text(
          value,
          style: (valueStyle ?? AppTextStyles.headlineMedium)
              .copyWith(color: effectiveColor),
        ),
        Text(
          label,
          style: (labelStyle ?? AppTextStyles.bodyMedium)
              .copyWith(color: effectiveLabelColor),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
