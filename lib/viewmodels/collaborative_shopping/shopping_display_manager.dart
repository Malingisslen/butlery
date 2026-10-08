/// Manager handling UI display helpers for collaborative shopping lists.

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart'; // ShoppingCategory + UnifiedShoppingItem
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Manages UI display helpers including colors, status text, and item formatting.
class ShoppingDisplayManager {
  Color getStatusColor(
    ColorScheme cs,
    ModeColors modeColors,
    bool hasData,
    String statusText,
  ) {
    if (!hasData) return cs.onSurfaceVariant;

    final l = AppLocale.current;
    if (statusText == l.statusCompleted) return modeColors.success;
    if (statusText == l.statusInProgress) {
      return AppModeColors.textWarning(cs.brightness);
    }
    return cs.onSurfaceVariant;
  }

  Color getProgressColor(
    ColorScheme cs,
    ModeColors modeColors,
    double completionPercentage,
  ) {
    if (completionPercentage == 100) return modeColors.success;
    if (completionPercentage > 50) return modeColors.warning;
    return cs.onSurface;
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

    if (item.category.isNotEmpty && item.category != ShoppingCategory.other) {
      parts.add(ShoppingCategory.displayName(item.category));
    }

    if (item.bought) {
      parts.add('✓ ${AppLocale.current.statusPurchased}');
    }

    return parts.isNotEmpty ? parts.join(' • ') : null;
  }

  List<Widget> getItemTrailingWidgets(UnifiedShoppingItem item) {
    return [];
  }

  String getStatusText(bool hasData, int totalItems, int completedItems) {
    final l = AppLocale.current;
    if (!hasData) return l.commonLoading;
    if (totalItems == 0) return l.statusEmptyList;
    if (completedItems == totalItems) return l.statusCompleted;
    return l.statusInProgress;
  }

  String getMemberCountText(UnifiedShoppingList? currentList) {
    final count = currentList?.memberCount ?? 0;
    return AppLocale.current.labelMemberCount(count);
  }

  String getActivitySummary(String lastActivity, DateTime lastActivityTime) {
    if (lastActivity.isEmpty) return AppLocale.current.statusNoActivity;
    final timeAgo = _getTimeAgo(lastActivityTime);
    return '$lastActivity $timeAgo';
  }

  String _getTimeAgo(DateTime time) {
    final now = clock.now();
    final difference = now.difference(time);
    final l = AppLocale.current;

    if (difference.inMinutes < 1) return l.timeJustNow;
    if (difference.inMinutes < 60) {
      return l.timeMinutesAgo(difference.inMinutes);
    }
    if (difference.inHours < 24) return l.timeHoursAgo(difference.inHours);
    return l.dateDaysAgo(difference.inDays);
  }
}
