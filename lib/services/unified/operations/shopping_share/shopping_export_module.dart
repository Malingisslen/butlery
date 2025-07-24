// lib/services/unified/operations/shopping_share/shopping_export_module.dart

import '../../../../models/unified/unified_shopping_list.dart';
import '../../../../core/utils/logger.dart';
import 'shared/shopping_share_utils.dart';

/// Shopping list export module
/// 
/// This module handles ONLY export operations for shopping lists:
/// - Text format export (full and minimal)
/// - CSV format export
/// - JSON format export
/// - Format validation and error handling
/// 
/// ❌ DOES NOT CONTAIN: Sharing, templates, import, social features
class ShoppingExportModule {
  final dynamic _parent; // UnifiedShoppingService

  ShoppingExportModule(this._parent);

  // ===== TEXT EXPORT =====

  /// Export shopping list as formatted text
  String exportListAsText(String listId) {
    final list = _getListById(listId);
    final errorMessage = ShoppingShareUtils.validateListExists(list);
    if (errorMessage != null) return errorMessage;
    
    final buffer = StringBuffer();
    
    // Header
    buffer.write(ShoppingShareUtils.createListHeader(list!));
    
    // Items by category
    final itemsByCategory = ShoppingShareUtils.groupItemsByCategory(list.items);
    
    for (final category in itemsByCategory.keys) {
      final items = itemsByCategory[category]!;
      final activeItems = items.where((item) => !item.bought).toList();
      final boughtItems = items.where((item) => item.bought).toList();
      
      if (activeItems.isNotEmpty || boughtItems.isNotEmpty) {
        buffer.writeln('🏷️ $category');
        buffer.writeln('-' * 20);
        
        // Active items
        for (final item in activeItems) {
          buffer.writeln('☐ ${item.displayText}');
          if (item.note?.isNotEmpty == true) {
            buffer.writeln('   💭 ${item.note}');
          }
        }
        
        // Bought items
        for (final item in boughtItems) {
          buffer.writeln('✅ ${item.displayText}');
        }
        
        buffer.writeln();
      }
    }
    
    // Footer
    buffer.write(ShoppingShareUtils.createListFooter(list));
    
    return buffer.toString();
  }

  /// Export shopping list as minimal text (for SMS/messaging)
  String exportListAsMinimalText(String listId) {
    final list = _getListById(listId);
    final errorMessage = ShoppingShareUtils.validateListExists(list);
    if (errorMessage != null) return errorMessage;
    
    final buffer = StringBuffer();
    buffer.writeln('🛒 ${list!.name}');
    
    final activeItems = list.items.where((item) => !item.bought).toList();
    
    if (activeItems.isEmpty) {
      buffer.writeln('✅ Allt inhandlat!');
    } else {
      for (final item in activeItems) {
        buffer.writeln('• ${item.displayText}');
      }
    }
    
    return buffer.toString();
  }

  // ===== CSV EXPORT =====

  /// Export shopping list as CSV
  String exportListAsCSV(String listId) {
    final list = _getListById(listId);
    final errorMessage = ShoppingShareUtils.validateListExists(list);
    if (errorMessage != null) return errorMessage;
    
    final buffer = StringBuffer();
    buffer.writeln('Namn,Mängd,Enhet,Kategori,Anteckning,Pris,Prioritet,Inköpt,Inköpt datum,Tillagd av');
    
    for (final item in list!.items) {
      buffer.writeln([
        ShoppingShareUtils.escapeCSV(item.name),
        item.amount,
        ShoppingShareUtils.escapeCSV(item.unit),
        ShoppingShareUtils.escapeCSV(item.category),
        ShoppingShareUtils.escapeCSV(item.note ?? ''),
        item.estimatedPrice ?? '',
        item.priority,
        item.bought ? 'Ja' : 'Nej',
        item.purchasedAt?.toIso8601String() ?? '',
        ShoppingShareUtils.escapeCSV(item.addedByDisplayName ?? ''),
      ].join(','));
    }
    
    return buffer.toString();
  }

  // ===== JSON EXPORT =====

  /// Export shopping list as structured JSON
  Map<String, dynamic> exportListAsJson(String listId) {
    final list = _getListById(listId);
    if (list == null) {
      return {'error': 'Lista hittades inte'};
    }
    
    try {
      final statistics = ShoppingShareUtils.getListStatistics(list);
      
      return {
        'format': 'butlery_shopping_list',
        'version': '1.0',
        'exportDate': DateTime.now().toIso8601String(),
        'list': {
          'id': list.id,
          'name': list.name,
          'description': list.description,
          'type': list.isCollaborative ? 'collaborative' : 'personal',
          'createdAt': list.createdAt.toIso8601String(),
          'updatedAt': list.updatedAt.toIso8601String(),
          'owner': {
            'id': list.ownerId,
            'displayName': list.ownerDisplayName,
          },
          'items': list.items.map((item) => {
            'id': item.id,
            'name': item.name,
            'amount': item.amount,
            'unit': item.unit,
            'category': item.category,
            'note': item.note,
            'estimatedPrice': item.estimatedPrice,
            'priority': item.priority,
            'bought': item.bought,
            'purchasedAt': item.purchasedAt?.toIso8601String(),
            'addedBy': item.addedByUserId != null ? {
              'id': item.addedByUserId,
              'displayName': item.addedByDisplayName,
            } : null,
          }).toList(),
          'members': list.isCollaborative ? list.memberPermissions.map((userId, permission) => 
            MapEntry(userId, permission.toString().split('.').last)
          ) : null,
        },
        'statistics': statistics,
      };
    } catch (e) {
      AppLogger.error('Failed to export list as JSON', e);
      return {'error': 'Kunde inte exportera lista som JSON'};
    }
  }

  // ===== EXPORT VALIDATION =====

  /// Validate export format
  bool isValidExportFormat(String format) {
    const validFormats = ['text', 'minimal', 'csv', 'json'];
    return validFormats.contains(format.toLowerCase());
  }

  /// Get available export formats
  List<String> getAvailableExportFormats() {
    return ['text', 'minimal', 'csv', 'json'];
  }

  /// Get export format description
  String getExportFormatDescription(String format) {
    switch (format.toLowerCase()) {
      case 'text':
        return 'Formaterad text med kategorier och statistik';
      case 'minimal':
        return 'Enkel text för meddelanden';
      case 'csv':
        return 'Kalkylblad-format (CSV)';
      case 'json':
        return 'Strukturerad data (JSON)';
      default:
        return 'Okänt format';
    }
  }

  // ===== HELPER METHODS =====

  /// Get list by ID from parent service
  UnifiedShoppingList? _getListById(String listId) {
    return _parent.lists.where((list) => list.id == listId).firstOrNull;
  }
}