/// Manager handling UI display helpers for collaborative shopping lists.

import 'package:flutter/material.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';

/// Manages UI display helpers including colors, status text, and item formatting.
class ShoppingDisplayManager {
  Color getStatusColor(ColorScheme cs, ButleryColors butleryColors,
      bool hasData, String statusText) {
    if (!hasData) return cs.onSurfaceVariant;

    switch (statusText) {
      case 'Klar':
        return butleryColors.success;
      case 'Pågående':
        return butleryColors.warning;
      case 'Tom lista':
        return cs.onSurfaceVariant;
      default:
        return cs.onSurfaceVariant;
    }
  }

  Color getProgressColor(ColorScheme cs, ButleryColors butleryColors,
      double completionPercentage) {
    if (completionPercentage == 100) return butleryColors.success;
    if (completionPercentage > 50) return butleryColors.warning;
    return cs.primary;
  }

  String? getItemSubtitle(UnifiedShoppingItem item) {
    final parts = <String>[];

    if (item.amount > 1 || item.unit.isNotEmpty) {
      final quantityText = item.amount > 1 ? '${item.amount}' : '';
      final unitText = item.unit.isNotEmpty ? item.unit : '';
      if (quantityText.isNotEmpty || unitText.isNotEmpty) {
        parts.add('$quantityText $unitText'.trim());
      }
    }

    if (item.category.isNotEmpty && item.category != 'Övrigt') {
      parts.add(item.category);
    }

    if (item.bought) {
      parts.add('✓ Inhandlad');
    }

    return parts.isNotEmpty ? parts.join(' • ') : null;
  }

  List<Widget> getItemTrailingWidgets(UnifiedShoppingItem item) {
    return [];
  }

  String getStatusText(bool hasData, int totalItems, int completedItems) {
    if (!hasData) return 'Laddar...';
    if (totalItems == 0) return 'Tom lista';
    if (completedItems == totalItems) return 'Klar';
    return 'Pågående';
  }

  String getMemberCountText(UnifiedShoppingList? currentList) {
    final count = currentList?.memberCount ?? 0;
    return '$count ${count == 1 ? 'medlem' : 'medlemmar'}';
  }

  String getActivitySummary(String lastActivity, DateTime lastActivityTime) {
    if (lastActivity.isEmpty) return 'Ingen aktivitet';
    final timeAgo = _getTimeAgo(lastActivityTime);
    return '$lastActivity $timeAgo';
  }

  String _getTimeAgo(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) return 'just nu';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m sedan';
    if (difference.inHours < 24) return '${difference.inHours}h sedan';
    return '${difference.inDays}d sedan';
  }
}
