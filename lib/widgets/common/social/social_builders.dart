// lib/widgets/common/social/social_builders.dart

import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

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
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon, size: iconSize ?? 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? AppColors.primaryBlue,
        foregroundColor: foregroundColor ?? Colors.white,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  /// Build social stats widget
  static Widget socialStats({
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
            style: valueStyle ?? const TextStyle(
              fontSize: 16,
              color: Colors.blue,
              fontWeight: FontWeight.bold,
            ).copyWith(color: textColor ?? AppColors.primaryBlue),
          ),
          if (showLabels) ...[
            const SizedBox(height: 4),
            Text(
              entry.key,
              style: labelStyle ?? const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ).copyWith(color: textColor ?? Colors.grey),
            ),
          ],
        ],
      );
    }).toList();

    return Container(
      padding: padding ?? const EdgeInsets.all(16),
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