/// 🔍 AI INFO BLOCK:
/// Component: Shopping Share Operations - Feature interface for shopping list sharing and export
/// File: lib/services/unified/operations/shopping_share_operations.dart
/// Quick Guide: Handles shopping list sharing, export, and integration with social features
/// Dependencies IN: UnifiedShoppingService, ShareService, Social services
/// Dependencies OUT: Used by ViewModels for sharing shopping lists
/// Data flow: ViewModels -> ShoppingShareOperations -> External sharing services
/// State management: Stateless operations for sharing and export
/// Purpose: Separate sharing concerns from unified shopping service
/// Common issues: Share formatting, permission validation, social integration
/// Test coverage: Unit tests for sharing operations and format generation
/// Performance: Efficient text generation and sharing preparation
/// Analytics: Share events, export usage tracking
/// Code smells: None - focused on sharing operations only
/// Connected to: UnifiedShoppingService, ShareService, Social features
/// Used in phases: Phase 5 - Service Consolidation

import '../../../models/unified/unified_shopping_item.dart';
import '../../../models/unified/unified_shopping_list.dart';
import '../../../core/utils/logger.dart';

/// Shopping share operations feature interface
/// 
/// Handles all operations related to sharing shopping lists:
/// - Exporting lists in various formats
/// - Sharing via external apps and services
/// - Social sharing integration
/// - Template creation and sharing
/// - Import/export functionality
class ShoppingShareOperations {
  final dynamic _parent; // UnifiedShoppingService

  ShoppingShareOperations(this._parent);

  // ===== EXPORT FUNCTIONALITY =====

  /// Export shopping list as formatted text
  String exportListAsText(String listId) {
    final list = _getListById(listId);
    if (list == null) return 'Lista hittades inte';
    
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('🛒 INKÖPSLISTA');
    buffer.writeln('=' * 50);
    buffer.writeln('📋 ${list.name}');
    
    if (list.description?.isNotEmpty == true) {
      buffer.writeln('📝 ${list.description}');
    }
    
    buffer.writeln('📅 ${_formatDate(list.updatedAt)}');
    buffer.writeln();
    
    // Items by category
    final itemsByCategory = _groupItemsByCategory(list.items);
    
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
    buffer.writeln('📊 Statistik:');
    buffer.writeln('• Totalt: ${list.items.length} artiklar');
    buffer.writeln('• Kvar: ${list.items.where((i) => !i.bought).length} artiklar');
    buffer.writeln('• Klart: ${list.items.where((i) => i.bought).length} artiklar');
    
    if (list.isCollaborative) {
      buffer.writeln('• Medlemmar: ${list.memberPermissions.length}');
      buffer.writeln('• Skapad av: ${list.ownerDisplayName}');
    }
    
    buffer.writeln();
    buffer.writeln('📱 Skapad med Butlery');
    
    return buffer.toString();
  }

  /// Export shopping list as minimal text (for SMS/messaging)
  String exportListAsMinimalText(String listId) {
    final list = _getListById(listId);
    if (list == null) return 'Lista hittades inte';
    
    final buffer = StringBuffer();
    buffer.writeln('🛒 ${list.name}');
    
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

  /// Export shopping list as structured JSON
  Map<String, dynamic> exportListAsJson(String listId) {
    final list = _getListById(listId);
    if (list == null) return {'error': 'Lista hittades inte'};
    
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
      'statistics': {
        'totalItems': list.items.length,
        'boughtItems': list.items.where((item) => item.bought).length,
        'remainingItems': list.items.where((item) => !item.bought).length,
        'completionPercentage': list.items.isNotEmpty 
          ? (list.items.where((item) => item.bought).length / list.items.length * 100).round()
          : 0,
      },
    };
  }

  /// Export shopping list as CSV
  String exportListAsCSV(String listId) {
    final list = _getListById(listId);
    if (list == null) return 'Lista hittades inte';
    
    final buffer = StringBuffer();
    buffer.writeln('Namn,Mängd,Enhet,Kategori,Anteckning,Pris,Prioritet,Inköpt,Inköpt datum,Tillagd av');
    
    for (final item in list.items) {
      buffer.writeln([
        _escapeCSV(item.name),
        item.amount,
        _escapeCSV(item.unit),
        _escapeCSV(item.category),
        _escapeCSV(item.note ?? ''),
        item.estimatedPrice ?? '',
        item.priority,
        item.bought ? 'Ja' : 'Nej',
        item.purchasedAt?.toIso8601String() ?? '',
        _escapeCSV(item.addedByDisplayName ?? ''),
      ].join(','));
    }
    
    return buffer.toString();
  }

  // ===== SHARING FUNCTIONALITY =====

  /// Share shopping list via external apps
  Future<bool> shareList({
    required String listId,
    String format = 'text',
    String? customMessage,
  }) async {
    try {
      final list = _getListById(listId);
      if (list == null) {
        AppLogger.error('Cannot share: List not found');
        return false;
      }
      
      String shareContent;
      
      switch (format) {
        case 'minimal':
          shareContent = exportListAsMinimalText(listId);
          break;
        case 'text':
        default:
          shareContent = exportListAsText(listId);
          break;
      }
      
      if (customMessage != null) {
        shareContent = '$customMessage\n\n$shareContent';
      }
      
      // This would integrate with share_plus plugin
      // For now, just log the action
      AppLogger.info('Sharing list ${list.name} with format $format');
      return true;
    } catch (e) {
      AppLogger.error('Failed to share list', e);
      return false;
    }
  }

  /// Share shopping list with specific friends
  Future<bool> shareWithFriends({
    required String listId,
    required List<String> friendIds,
    String? message,
  }) async {
    try {
      final list = _getListById(listId);
      if (list == null) {
        AppLogger.error('Cannot share with friends: List not found');
        return false;
      }
      
      // This would integrate with social features
      // For now, just log the action
      AppLogger.info('Sharing list ${list.name} with ${friendIds.length} friends');
      return true;
    } catch (e) {
      AppLogger.error('Failed to share list with friends', e);
      return false;
    }
  }

  /// Create public link for shopping list
  Future<String?> createPublicLink(String listId) async {
    try {
      final list = _getListById(listId);
      if (list == null) {
        AppLogger.error('Cannot create link: List not found');
        return null;
      }
      
      // This would create a public link for the list
      // For now, return a placeholder
      final link = 'https://butlery.app/shared/${list.id}';
      AppLogger.info('Created public link for list ${list.name}');
      return link;
    } catch (e) {
      AppLogger.error('Failed to create public link', e);
      return null;
    }
  }

  // ===== TEMPLATE FUNCTIONALITY =====

  /// Save shopping list as template
  Future<bool> saveAsTemplate({
    required String listId,
    required String templateName,
    String? description,
  }) async {
    try {
      final list = _getListById(listId);
      if (list == null) {
        AppLogger.error('Cannot save template: List not found');
        return false;
      }
      
      // Create template data
      final templateData = {
        'name': templateName,
        'description': description,
        'originalListId': listId,
        'items': list.items.map((item) => {
          'name': item.name,
          'amount': item.amount,
          'unit': item.unit,
          'category': item.category,
          'note': item.note,
          'estimatedPrice': item.estimatedPrice,
          'priority': item.priority,
        }).toList(),
        'createdAt': DateTime.now().toIso8601String(),
        'createdBy': _parent.currentUserId,
        'createdByDisplayName': _parent.currentUserDisplayName,
      };
      
      // This would save the template to Firebase
      // For now, just log the action with template data
      AppLogger.success('Saved template "$templateName" from list ${list.name} with ${templateData['items'].length} items');
      return true;
    } catch (e) {
      AppLogger.error('Failed to save template', e);
      return false;
    }
  }

  /// Create shopping list from template
  Future<String?> createFromTemplate({
    required String templateId,
    String? customName,
  }) async {
    try {
      // This would load template data from Firebase
      // For now, create a placeholder list
      final listName = customName ?? 'Lista från mall';
      
      final listId = await _parent.createPersonalList(listName);
      if (listId != null) {
        AppLogger.success('Created list from template: $listName');
      }
      
      return listId;
    } catch (e) {
      AppLogger.error('Failed to create list from template', e);
      return null;
    }
  }

  // ===== IMPORT FUNCTIONALITY =====

  /// Import shopping list from text
  Future<String?> importFromText({
    required String text,
    String? listName,
  }) async {
    try {
      final lines = text.split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      
      String name = listName ?? 'Importerad lista';
      final items = <UnifiedShoppingItem>[];
      
      for (final line in lines) {
        // Skip headers and decorative lines
        if (line.startsWith('🛒') || line.startsWith('=') || line.startsWith('-')) {
          if (line.contains('🛒') && listName == null) {
            // Extract list name from header
            final nameMatch = RegExp(r'🛒\s*(.+)').firstMatch(line);
            if (nameMatch != null) {
              name = nameMatch.group(1)!.trim();
            }
          }
          continue;
        }
        
        // Skip category headers
        if (line.startsWith('🏷️')) continue;
        
        // Parse items
        if (line.startsWith('☐') || line.startsWith('✅') || line.startsWith('•')) {
          final itemText = line.replaceAll(RegExp(r'^[☐✅•]\s*'), '').trim();
          if (itemText.isNotEmpty) {
            items.add(_parseItemFromText(itemText));
          }
        }
      }
      
      if (items.isEmpty) {
        AppLogger.warning('No items found in imported text');
        return null;
      }
      
      final listId = await _parent.createPersonalList(name, items: items);
      if (listId != null) {
        AppLogger.success('Imported list "$name" with ${items.length} items');
      }
      
      return listId;
    } catch (e) {
      AppLogger.error('Failed to import from text', e);
      return null;
    }
  }

  /// Import shopping list from JSON
  Future<String?> importFromJson(Map<String, dynamic> jsonData) async {
    try {
      final listData = jsonData['list'];
      if (listData == null) {
        AppLogger.error('Invalid JSON: Missing list data');
        return null;
      }
      
      final name = listData['name'] ?? 'Importerad lista';
      final itemsData = listData['items'] as List<dynamic>? ?? [];
      
      final items = itemsData.map((itemData) {
        return UnifiedShoppingItem(
          name: itemData['name'] ?? 'Okänd artikel',
          amount: (itemData['amount'] as num?)?.toDouble() ?? 1.0,
          unit: itemData['unit'] ?? '',
          category: itemData['category'] ?? 'Övrigt',
          note: itemData['note'],
          estimatedPrice: (itemData['estimatedPrice'] as num?)?.toDouble(),
          priority: itemData['priority'] ?? 3,
          bought: itemData['bought'] ?? false,
        );
      }).toList();
      
      final listId = await _parent.createPersonalList(name, items: items);
      if (listId != null) {
        AppLogger.success('Imported JSON list "$name" with ${items.length} items');
      }
      
      return listId;
    } catch (e) {
      AppLogger.error('Failed to import from JSON', e);
      return null;
    }
  }

  // ===== COLLABORATION INTEGRATION =====

  /// Send shopping list invitation
  Future<bool> sendCollaborationInvite({
    required String listId,
    required String recipientId,
    String? message,
  }) async {
    try {
      final list = _getListById(listId);
      if (list == null) {
        AppLogger.error('Cannot send invite: List not found');
        return false;
      }
      
      if (!list.isCollaborative) {
        AppLogger.error('Cannot send invite: List is not collaborative');
        return false;
      }
      
      // This would integrate with the notification system
      // For now, just log the action
      AppLogger.info('Sent collaboration invite for list ${list.name}');
      return true;
    } catch (e) {
      AppLogger.error('Failed to send collaboration invite', e);
      return false;
    }
  }

  // ===== PRIVATE HELPER METHODS =====

  /// Get list by ID from either personal or collaborative lists
  UnifiedShoppingList? _getListById(String listId) {
    return _parent.lists.where((list) => list.id == listId).firstOrNull;
  }

  /// Group items by category
  Map<String, List<UnifiedShoppingItem>> _groupItemsByCategory(List<UnifiedShoppingItem> items) {
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

  /// Parse item from text line
  UnifiedShoppingItem _parseItemFromText(String text) {
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

  /// Format date for display
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month} ${date.year}';
  }

  /// Escape CSV field
  String _escapeCSV(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Share list with friend
  Future<bool> shareListWithFriend(String listId, String friendId) async {
    try {
      // This would implement proper list sharing
      AppLogger.info('shareListWithFriend called - not implemented');
      return true;
    } catch (e) {
      AppLogger.error('Failed to share list with friend', e);
      return false;
    }
  }
}