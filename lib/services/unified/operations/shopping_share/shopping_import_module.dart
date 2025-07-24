// lib/services/unified/operations/shopping_share/shopping_import_module.dart

import '../../../../models/unified/unified_shopping_item.dart';
import '../../../../core/utils/logger.dart';
import 'shared/shopping_share_utils.dart';

/// Shopping list import module
/// 
/// This module handles ONLY import operations:
/// - Import from formatted text
/// - Import from JSON data
/// - Parse and validate import data
/// - Handle import errors and validation
/// 
/// ❌ DOES NOT CONTAIN: Export, sharing, templates, social features
class ShoppingImportModule {
  final dynamic _parent; // UnifiedShoppingService

  ShoppingImportModule(this._parent);

  // ===== TEXT IMPORT =====

  /// Import shopping list from text
  Future<String?> importFromText({
    required String text,
    String? listName,
  }) async {
    try {
      if (text.trim().isEmpty) {
        AppLogger.error('Import text cannot be empty');
        return null;
      }

      final lines = text.split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      
      if (lines.isEmpty) {
        AppLogger.error('No valid content found in import text');
        return null;
      }

      String name = listName ?? 'Importerad lista';
      final items = <UnifiedShoppingItem>[];
      
      for (final line in lines) {
        // Extract list name from header if not provided
        if (listName == null) {
          final extractedName = ShoppingShareUtils.extractListNameFromHeader(line);
          if (extractedName != null) {
            name = extractedName;
            continue;
          }
        }

        // Skip decorative and info lines
        if (ShoppingShareUtils.shouldSkipImportLine(line)) {
          continue;
        }
        
        // Parse shopping items
        if (ShoppingShareUtils.isShoppingItemLine(line)) {
          final itemText = ShoppingShareUtils.extractItemText(line);
          if (itemText.isNotEmpty) {
            items.add(ShoppingShareUtils.parseItemFromText(itemText));
          }
        }
      }
      
      if (items.isEmpty) {
        AppLogger.warning('No items found in imported text');
        return null;
      }
      
      final listId = await _parent.createPersonalList(name, items: items);
      if (listId != null) {
        AppLogger.success('✅ Imported list "$name" with ${items.length} items');
      }
      
      return listId;
    } catch (e) {
      AppLogger.error('Failed to import from text', e);
      return null;
    }
  }

  /// Import shopping list from simple text lines
  Future<String?> importFromSimpleText({
    required String text,
    required String listName,
    String defaultCategory = 'Importerat',
  }) async {
    try {
      if (text.trim().isEmpty) {
        AppLogger.error('Import text cannot be empty');
        return null;
      }

      if (listName.trim().isEmpty) {
        AppLogger.error('List name cannot be empty');
        return null;
      }

      final lines = text.split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      if (lines.isEmpty) {
        AppLogger.error('No items found in text');
        return null;
      }

      final items = lines.map((line) {
        return UnifiedShoppingItem.basic(
          name: line,
          amount: 1.0,
          unit: '',
          category: defaultCategory,
        );
      }).toList();

      final listId = await _parent.createPersonalList(listName.trim(), items: items);
      if (listId != null) {
        AppLogger.success('✅ Imported simple list "$listName" with ${items.length} items');
      }

      return listId;
    } catch (e) {
      AppLogger.error('Failed to import from simple text', e);
      return null;
    }
  }

  // ===== JSON IMPORT =====

  /// Import shopping list from JSON
  Future<String?> importFromJson(Map<String, dynamic> jsonData) async {
    try {
      if (!_isValidJsonFormat(jsonData)) {
        AppLogger.error('Invalid JSON format for import');
        return null;
      }

      final listData = jsonData['list'];
      if (listData == null) {
        AppLogger.error('Invalid JSON: Missing list data');
        return null;
      }
      
      final name = listData['name']?.toString().trim() ?? 'Importerad lista';
      final itemsData = listData['items'] as List<dynamic>? ?? [];
      
      if (itemsData.isEmpty) {
        AppLogger.warning('No items found in JSON data');
        return null;
      }

      final items = itemsData.map((itemData) {
        return _createItemFromJsonData(itemData);
      }).toList();
      
      final listId = await _parent.createPersonalList(name, items: items);
      if (listId != null) {
        AppLogger.success('✅ Imported JSON list "$name" with ${items.length} items');
      }
      
      return listId;
    } catch (e) {
      AppLogger.error('Failed to import from JSON', e);
      return null;
    }
  }

  /// Import multiple lists from JSON array
  Future<List<String>> importMultipleFromJson(List<Map<String, dynamic>> jsonDataList) async {
    final importedListIds = <String>[];

    for (int i = 0; i < jsonDataList.length; i++) {
      try {
        final listId = await importFromJson(jsonDataList[i]);
        if (listId != null) {
          importedListIds.add(listId);
        }
      } catch (e) {
        AppLogger.error('Failed to import list ${i + 1}: $e');
      }
    }

    AppLogger.info('✅ Imported ${importedListIds.length}/${jsonDataList.length} lists');
    return importedListIds;
  }

  // ===== IMPORT VALIDATION =====

  /// Validate import format
  bool isValidImportFormat(String format) {
    const validFormats = ['text', 'simple', 'json'];
    return validFormats.contains(format.toLowerCase());
  }

  /// Validate text import content
  Map<String, dynamic> validateTextImport(String text) {
    if (text.trim().isEmpty) {
      return {
        'isValid': false,
        'error': 'Tom text kan inte importeras',
      };
    }

    final lines = text.split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final itemCount = lines.where(ShoppingShareUtils.isShoppingItemLine).length;

    if (itemCount == 0) {
      return {
        'isValid': false,
        'error': 'Inga inköpsartiklar hittades i texten',
      };
    }

    return {
      'isValid': true,
      'estimatedItemCount': itemCount,
      'totalLines': lines.length,
    };
  }

  /// Validate JSON import content
  Map<String, dynamic> validateJsonImport(Map<String, dynamic> jsonData) {
    if (!_isValidJsonFormat(jsonData)) {
      return {
        'isValid': false,
        'error': 'Ogiltigt JSON-format',
      };
    }

    final listData = jsonData['list'];
    if (listData == null) {
      return {
        'isValid': false,
        'error': 'Saknar lista-data',
      };
    }

    final itemsData = listData['items'] as List<dynamic>? ?? [];
    if (itemsData.isEmpty) {
      return {
        'isValid': false,
        'error': 'Inga artiklar hittades',
      };
    }

    return {
      'isValid': true,
      'listName': listData['name']?.toString() ?? 'Namnlös lista',
      'itemCount': itemsData.length,
      'hasDescription': listData['description']?.toString().isNotEmpty == true,
    };
  }

  // ===== HELPER METHODS =====

  /// Check if JSON data has valid format
  bool _isValidJsonFormat(Map<String, dynamic> jsonData) {
    // Check for Butlery format
    if (jsonData['format'] == 'butlery_shopping_list') {
      return true;
    }

    // Check for basic structure
    if (jsonData.containsKey('list') && jsonData['list'] is Map) {
      final listData = jsonData['list'] as Map<String, dynamic>;
      return listData.containsKey('items') && listData['items'] is List;
    }

    return false;
  }

  /// Create shopping item from JSON data
  UnifiedShoppingItem _createItemFromJsonData(dynamic itemData) {
    if (itemData is! Map<String, dynamic>) {
      return UnifiedShoppingItem.basic(
        name: itemData.toString(),
        amount: 1.0,
        unit: '',
        category: 'Importerat',
      );
    }

    return UnifiedShoppingItem(
      name: itemData['name']?.toString() ?? 'Okänd artikel',
      amount: (itemData['amount'] as num?)?.toDouble() ?? 1.0,
      unit: itemData['unit']?.toString() ?? '',
      category: itemData['category']?.toString() ?? 'Importerat',
      note: itemData['note']?.toString(),
      estimatedPrice: (itemData['estimatedPrice'] as num?)?.toDouble(),
      priority: itemData['priority'] as int? ?? 3,
      bought: itemData['bought'] as bool? ?? false,
    );
  }
}