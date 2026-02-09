// lib/widgets/common/social/social_builders.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Builder functions for social components
class SocialBuilders {
  /// Build social action button
  static Widget socialActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool enabled = true,
    bool isLoading = false,
    Color? backgroundColor,
    Color? foregroundColor,
    EdgeInsets? padding,
    double? iconSize,
  }) {
    return ElevatedButton.icon(
      onPressed: enabled && !isLoading ? onPressed : null,
      icon: isLoading
          ? const SizedBox(
              width: AppDimensions.iconSizeS,
              height: AppDimensions.iconSizeS,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: iconSize ?? AppDimensions.iconSizeS),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? AppColors.forestGreen,
        foregroundColor: foregroundColor ?? AppColors.cardWhite,
        padding: padding ?? AppDimensions.paddingSymmetric16x8,
      ),
    );
  }

  /// Build social stats widget
  static Widget socialStats(
    BuildContext context, {
    required Map<String, dynamic> stats,
    bool showLabels = true,
    bool horizontal = true,
    EdgeInsets? padding,
    Color? textColor,
    TextStyle? valueStyle,
    TextStyle? labelStyle,
  }) {
    final children = stats.entries.map((entry) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            entry.value.toString(),
            style: valueStyle ??
                AppTextStyles.bodyLargeBold.copyWith(
                  color: textColor ?? AppColors.forestGreen,
                ),
          ),
          if (showLabels) ...[
            const SizedBox(height: AppDimensions.spacingXs),
            Text(
              entry.key,
              style: labelStyle ??
                  Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: textColor ?? AppColors.textMedium,
                      ),
            ),
          ],
        ],
      );
    }).toList();

    return Container(
      padding: padding ?? const EdgeInsets.all(AppDimensions.spacingMd),
      child: horizontal
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: children,
            )
          : Column(
              children: children,
            ),
    );
  }

  /// Build quick selection buttons
  static Widget quickSelectionButtons({
    required VoidCallback onSelectAll,
    required VoidCallback onDeselectAll,
    required VoidCallback onInvertSelection,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        TextButton(
          onPressed: onSelectAll,
          child: const Text('Markera alla'),
        ),
        TextButton(
          onPressed: onDeselectAll,
          child: const Text('Avmarkera alla'),
        ),
        TextButton(
          onPressed: onInvertSelection,
          child: const Text('Invertera'),
        ),
      ],
    );
  }
}
