// lib/widgets/common/social/social_builders.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

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
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
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
                  color: textColor ?? Theme.of(context).colorScheme.primary,
                ),
          ),
          if (showLabels) ...[
            const SizedBox(height: AppDimensions.spacingXs),
            Text(
              entry.key,
              style: labelStyle ??
                  Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: textColor ??
                            Theme.of(context).colorScheme.onSurfaceVariant,
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
  static Widget quickSelectionButtons(
    BuildContext context, {
    required VoidCallback onSelectAll,
    required VoidCallback onDeselectAll,
    required VoidCallback onInvertSelection,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        TextButton(
          onPressed: onSelectAll,
          child: Text(context.l10n.commonSelectAll),
        ),
        TextButton(
          onPressed: onDeselectAll,
          child: Text(context.l10n.commonDeselectAll),
        ),
        TextButton(
          onPressed: onInvertSelection,
          child: Text(context.l10n.commonInvertSelection),
        ),
      ],
    );
  }
}
