// lib/services/unified/operations/shopping_share/shared/shopping_share_utils.dart

import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';

/// Shared utilities for shopping share operations
/// 
/// Contains helper methods and formatting utilities used across
/// multiple shopping share modules to reduce code duplication.
class ShoppingShareUtils {
  /// Group items by category for organized display
  static Map<String, List<UnifiedShoppingItem>> groupItemsByCategory(
      List<UnifiedShoppingItem> items) {
    final categoryMap = <String, List<UnifiedShoppingItem>>{};
    
    for (final item in items) {
      final category = item.category.isEmpty ? 'Övrigt' : item.category;
      if (!categoryMap.containsKey(category)) {
        categoryMap[category] = [];
      }
      categoryMap[category]!.add(item);
    }
    
    return categoryMap;
  }

  /// Format date for display in exports
  static String formatDate(DateTime date) {
    return '${date.day}/${date.month} ${date.year}';
  }

  /// Escape CSV field for proper formatting
  static String escapeCSV(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Parse item from text line for import operations
  static UnifiedShoppingItem parseItemFromText(String text) {
    // Basic parsing - can be enhanced
    final parts = text.split(' ');
    double amount = 1.0;
    String unit = '';
    String name = text;
    
    if (parts.isNotEmpty) {
      final firstPart = parts[0];
      final parsedAmount = double.tryParse(firstPart.replaceAll(',', '.'));
      if (parsedAmount != null) {
        amount = parsedAmount;
        if (parts.length > 1) {
          unit = parts[1];
          name = parts.skip(2).join(' ');
        }
      }
    }
    
    return UnifiedShoppingItem.basic(
      name: name,
      amount: amount,
      unit: unit,
      category: 'Importerat',
    );
  }

  /// Get list statistics for export metadata
  static Map<String, dynamic> getListStatistics(UnifiedShoppingList list) {
    final boughtItems = list.items.where((item) => item.bought).length;
    final totalItems = list.items.length;
    
    return {
      'totalItems': totalItems,
      'boughtItems': boughtItems,
      'remainingItems': totalItems - boughtItems,
      'completionPercentage': totalItems > 0 
          ? (boughtItems / totalItems * 100).round()
          : 0,
    };
  }

  /// Create standard list header for text exports
  static String createListHeader(UnifiedShoppingList list) {
    final buffer = StringBuffer();
    buffer.writeln('🛒 INKÖPSLISTA');
    buffer.writeln('=' * 50);
    buffer.writeln('📋 ${list.name}');
    
    if (list.description?.isNotEmpty == true) {
      buffer.writeln('📝 ${list.description}');
    }
    
    buffer.writeln('📅 ${formatDate(list.updatedAt)}');
    buffer.writeln();
    
    return buffer.toString();
  }

  /// Create standard list footer for text exports
  static String createListFooter(UnifiedShoppingList list) {
    final buffer = StringBuffer();
    final stats = getListStatistics(list);
    
    buffer.writeln('📊 Statistik:');
    buffer.writeln('• Totalt: ${stats['totalItems']} artiklar');
    buffer.writeln('• Kvar: ${stats['remainingItems']} artiklar');
    buffer.writeln('• Klart: ${stats['boughtItems']} artiklar');
    
    if (list.isCollaborative) {
      buffer.writeln('• Medlemmar: ${list.memberPermissions.length}');
      buffer.writeln('• Skapad av: ${list.ownerDisplayName}');
    }
    
    buffer.writeln();
    buffer.writeln('📱 Skapad med Butlery');
    
    return buffer.toString();
  }

  /// Validate list exists and return error message if not
  static String? validateListExists(UnifiedShoppingList? list) {
    if (list == null) {
      return 'Lista hittades inte';
    }
    return null;
  }

  /// Extract list name from imported text header
  static String? extractListNameFromHeader(String line) {
    if (line.contains('🛒')) {
      final nameMatch = RegExp(r'🛒\s*(.+)').firstMatch(line);
      return nameMatch?.group(1)?.trim();
    }
    return null;
  }

  /// Check if line should be skipped during import
  static bool shouldSkipImportLine(String line) {
    return line.startsWith('🛒') || 
           line.startsWith('=') || 
           line.startsWith('-') ||
           line.startsWith('🏷️') ||
           line.startsWith('📊') ||
           line.startsWith('•') && !line.contains('☐') && !line.contains('✅');
  }

  /// Check if line contains a shopping item
  static bool isShoppingItemLine(String line) {
    return line.startsWith('☐') || 
           line.startsWith('✅') || 
           line.startsWith('•');
  }

  /// Extract item text from line
  static String extractItemText(String line) {
    return line.replaceAll(RegExp(r'^[☐✅•]\s*'), '').trim();
  }
}