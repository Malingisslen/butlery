/// Shopping analytics and insights manager for statistics and export functionality.
/// Handles shopping insights, completion tracking, and export operations.
/// Part of UnifiedShoppingViewModel's modular architecture.

import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';

/// Shopping analytics and insights manager for statistics and export functionality.
class ShoppingAnalyticsManager {
  final UnifiedShoppingService _shoppingService;

  ShoppingAnalyticsManager(this._shoppingService);

  /// Get comprehensive shopping insights
  Map<String, dynamic> getShoppingInsights(
    UnifiedShoppingList? activeList,
    List<UnifiedShoppingItem> items,
    List<String> usedCategories,
  ) {
    if (activeList == null) return {};

    return {
      'totalItems': activeList.totalItems,
      'boughtItems': activeList.boughtItems,
      'completionPercentage': activeList.completionPercentage,
      'isCollaborative': activeList.isCollaborative,
      'memberCount': activeList.memberCount,
      'lastActivity': activeList.activitySummary,
      'hasRecentActivity': activeList.hasRecentActivity,
      'categories': usedCategories.length,
      'priorityItems': items.where((item) => item.priority > 3).length,
    };
  }

  /// Export list as plain text
  String exportListAsText() {
    return _shoppingService.exportListAsText();
  }

  /// Export list with category grouping
  String exportListAsTextWithCategories(
    UnifiedShoppingList? activeList,
    Map<String, List<UnifiedShoppingItem>> itemsByCategory,
  ) {
    if (activeList == null) return '';

    final buffer = StringBuffer();
    buffer.writeln('📝 ${activeList.name}');
    buffer.writeln('');

    for (final category in itemsByCategory.keys) {
      buffer.writeln('🏷️ $category:');
      for (final item in itemsByCategory[category]!) {
        final check = item.bought ? '✅' : '⬜';
        buffer.writeln('  $check ${item.displayText}');
      }
      buffer.writeln('');
    }

    buffer.writeln('📊 ${activeList.summary}');
    return buffer.toString();
  }
}
