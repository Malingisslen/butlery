// lib/utils/shopping_list_formatter.dart

import 'package:butlery/models/unified/unified_shopping_list.dart';

/// Utility for formatting shopping lists as text for sharing/copying.
class ShoppingListFormatter {
  /// Formats shopping list for clipboard (plain text).
  static String formatForClipboard(UnifiedShoppingList shoppingList) {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln(shoppingList.name);
    buffer.writeln('=' * shoppingList.name.length);
    buffer.writeln();

    if (shoppingList.description?.isNotEmpty == true) {
      buffer.writeln(shoppingList.description);
      buffer.writeln();
    }

    buffer.writeln('Inkopslista (${shoppingList.items.length} varor):');

    for (int i = 0; i < shoppingList.items.length; i++) {
      final item = shoppingList.items[i];
      final status = item.bought ? '✓' : '○';
      buffer.writeln('$status ${item.name} (${item.amount} ${item.unit})');
    }

    return buffer.toString();
  }

  /// Formats shopping list for sharing (with emojis).
  static String formatForSharing(UnifiedShoppingList shoppingList) {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('📋 ${shoppingList.name}');
    buffer.writeln();

    if (shoppingList.description?.isNotEmpty == true) {
      buffer.writeln(shoppingList.description);
      buffer.writeln();
    }

    buffer.writeln('🛍️ Inkopslista (${shoppingList.items.length} varor):');

    for (final item in shoppingList.items) {
      final emoji = item.bought ? '✓' : '▪️';
      buffer.writeln('$emoji ${item.name} (${item.amount} ${item.unit})');
    }

    buffer.writeln();
    buffer.writeln('Delad via Butlery 🍳');

    return buffer.toString();
  }

  /// Gets formatted share time text from shopping list metadata.
  static String getShareTimeText(UnifiedShoppingList shoppingList) {
    final shareTime = shoppingList.lastActivityAt ?? shoppingList.createdAt;
    final now = DateTime.now();
    final difference = now.difference(shareTime);

    if (difference.inMinutes < 1) {
      return 'Delad just nu';
    } else if (difference.inMinutes < 60) {
      return 'Delad ${difference.inMinutes} min sedan';
    } else if (difference.inHours < 24) {
      return 'Delad ${difference.inHours} tim sedan';
    } else if (difference.inDays < 7) {
      return 'Delad ${difference.inDays} dag${difference.inDays > 1 ? 'ar' : ''} sedan';
    } else {
      final day = shareTime.day.toString().padLeft(2, '0');
      final month = shareTime.month.toString().padLeft(2, '0');
      return 'Delad $day/$month';
    }
  }
}
