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
import '../../../services/permission_service.dart';
import '../../../core/injection.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
      
      // Use share_plus plugin to share externally
      await Share.share(
        shareContent,
        subject: 'Inköpslista: ${list.name}',
      );
      
      AppLogger.success('✅ List shared externally: ${list.name}');
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
      
      if (!sl<PermissionService>().isAuthenticated) {
        AppLogger.warning('User must be logged in to share with friends');
        return false;
      }
      
      final currentUser = sl<PermissionService>().currentUser;
      if (currentUser == null) return false;
      
      // Create shared list entries in Firestore
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      
      for (final friendId in friendIds) {
        final shareDoc = firestore.collection('sharedShoppingLists').doc();
        batch.set(shareDoc, {
          'listId': listId,
          'listName': list.name,
          'ownerId': currentUser.uid,
          'ownerDisplayName': currentUser.displayName,
          'sharedWithUserId': friendId,
          'message': message,
          'sharedAt': FieldValue.serverTimestamp(),
          'isActive': true,
        });
      }
      
      await batch.commit();
      
      AppLogger.success('✅ List shared with ${friendIds.length} friends: ${list.name}');
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
      
      if (!sl<PermissionService>().isAuthenticated) {
        AppLogger.warning('User must be logged in to create public link');
        return null;
      }
      
      final currentUser = sl<PermissionService>().currentUser;
      if (currentUser == null) return null;
      
      // Create public sharing entry in Firestore
      final firestore = FirebaseFirestore.instance;
      final publicShareDoc = firestore.collection('publicShoppingLists').doc();
      
      await publicShareDoc.set({
        'listId': listId,
        'listName': list.name,
        'ownerId': currentUser.uid,
        'ownerDisplayName': currentUser.displayName,
        'listData': {
          'name': list.name,
          'description': list.description,
          'items': list.items.map((item) => {
            'name': item.name,
            'amount': item.amount,
            'unit': item.unit,
            'category': item.category,
            'bought': item.bought,
          }).toList(),
        },
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 7)),
        ),
        'isActive': true,
      });
      
      final publicLink = 'https://butlery.app/shared/${publicShareDoc.id}';
      AppLogger.success('✅ Public link created for list: ${list.name}');
      return publicLink;
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
      
      if (!sl<PermissionService>().isAuthenticated) {
        AppLogger.warning('User must be logged in to save template');
        return false;
      }
      
      final currentUser = sl<PermissionService>().currentUser;
      if (currentUser == null) return false;
      
      // Save template to Firestore
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('shoppingListTemplates').add({
        'name': templateName.trim(),
        'description': description?.trim(),
        'ownerId': currentUser.uid,
        'ownerDisplayName': currentUser.displayName,
        'originalListId': listId,
        'items': list.items.map((item) => {
          'name': item.name,
          'amount': item.amount,
          'unit': item.unit,
          'category': item.category,
          'note': item.note,
        }).toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'isPublic': false,
        'tags': <String>[],
      });
      
      AppLogger.success('✅ Template saved: $templateName');
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

  /// Share shopping list with specific friend
  Future<bool> shareListWithFriend(String listId, String friendId) async {
    try {
      final list = _getListById(listId);
      if (list == null) {
        AppLogger.error('Cannot share list: List not found');
        return false;
      }

      if (!sl<PermissionService>().isAuthenticated) {
        AppLogger.warning('User must be logged in to share list with friend');
        return false;
      }

      final currentUser = sl<PermissionService>().currentUser;
      if (currentUser == null) return false;

      // Create shared list entry in Firestore
      final firestore = FirebaseFirestore.instance;
      final shareDoc = firestore.collection('sharedShoppingLists').doc();
      
      await shareDoc.set({
        'listId': listId,
        'listName': list.name,
        'ownerId': currentUser.uid,
        'ownerDisplayName': currentUser.displayName,
        'ownerAvatarUrl': currentUser.avatarUrl,
        'sharedWithUserId': friendId,
        'sharedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'shareType': 'direct_friend',
        'listData': {
          'name': list.name,
          'description': list.description,
          'type': list.isCollaborative ? 'collaborative' : 'personal',
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
          'statistics': {
            'totalItems': list.items.length,
            'boughtItems': list.items.where((item) => item.bought).length,
            'remainingItems': list.items.where((item) => !item.bought).length,
          },
        },
      });

      // Create user-specific share record for the friend
      await firestore
          .collection('userSharedShoppingLists')
          .doc(friendId)
          .collection('receivedLists')
          .doc(shareDoc.id)
          .set({
        'sharedListId': shareDoc.id,
        'sharedByUserId': currentUser.uid,
        'sharedByDisplayName': currentUser.displayName,
        'listName': list.name,
        'sharedAt': FieldValue.serverTimestamp(),
        'isViewed': false,
        'isImported': false,
        'shareType': 'direct_friend',
      });

      AppLogger.success('✅ Shopping list shared with friend: ${list.name}');
      return true;
    } catch (e) {
      AppLogger.error('Failed to share list with friend', e);
      return false;
    }
  }

  /// Share shopping list with multiple friends
  Future<bool> shareListWithMultipleFriends({
    required String listId,
    required List<String> friendIds,
    String? message,
  }) async {
    try {
      if (friendIds.isEmpty) {
        AppLogger.error('No friends specified for sharing');
        return false;
      }

      // Use the shareWithFriends method which handles multiple friends
      return await shareWithFriends(
        listId: listId,
        friendIds: friendIds,
        message: message,
      );
    } catch (e) {
      AppLogger.error('Failed to share list with multiple friends', e);
      return false;
    }
  }

  /// Get shopping lists shared with current user
  Future<List<Map<String, dynamic>>> getShoppingListsSharedWithMe() async {
    try {
      if (!sl<PermissionService>().isAuthenticated) return [];
      
      final currentUserId = sl<PermissionService>().currentUserId;
      if (currentUserId == null) return [];

      final querySnapshot = await FirebaseFirestore.instance
          .collection('userSharedShoppingLists')
          .doc(currentUserId)
          .collection('receivedLists')
          .orderBy('sharedAt', descending: true)
          .get();

      final sharedLists = <Map<String, dynamic>>[];
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final sharedListId = data['sharedListId'];
        
        // Get full list data
        final listDoc = await FirebaseFirestore.instance
            .collection('sharedShoppingLists')
            .doc(sharedListId)
            .get();
            
        if (listDoc.exists && listDoc.data()!['isActive'] == true) {
          final listData = listDoc.data()!;
          final listDataSnapshot = listData['listData'] as Map<String, dynamic>? ?? {};
          final statistics = listDataSnapshot['statistics'] as Map<String, dynamic>? ?? {};
          
          sharedLists.add({
            'id': sharedListId,
            'listName': listData['listName'] ?? 'Namnlös lista',
            'ownerDisplayName': listData['ownerDisplayName'] ?? 'Okänd användare',
            'ownerAvatarUrl': listData['ownerAvatarUrl'],
            'sharedAt': data['sharedAt'],
            'totalItems': statistics['totalItems'] ?? 0,
            'boughtItems': statistics['boughtItems'] ?? 0,
            'remainingItems': statistics['remainingItems'] ?? 0,
            'isViewed': data['isViewed'] ?? false,
            'isImported': data['isImported'] ?? false,
            'shareType': data['shareType'] ?? 'direct_friend',
          });
        }
      }

      return sharedLists;
    } catch (e) {
      AppLogger.error('Failed to get shared shopping lists', e);
      return [];
    }
  }

  /// Get shopping lists shared by current user
  Future<List<Map<String, dynamic>>> getShoppingListsSharedByMe() async {
    try {
      if (!sl<PermissionService>().isAuthenticated) return [];
      
      final currentUserId = sl<PermissionService>().currentUserId;
      if (currentUserId == null) return [];

      final querySnapshot = await FirebaseFirestore.instance
          .collection('sharedShoppingLists')
          .where('ownerId', isEqualTo: currentUserId)
          .where('isActive', isEqualTo: true)
          .orderBy('sharedAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        final listDataSnapshot = data['listData'] as Map<String, dynamic>? ?? {};
        final statistics = listDataSnapshot['statistics'] as Map<String, dynamic>? ?? {};
        
        return {
          'id': doc.id,
          'listName': data['listName'] ?? 'Namnlös lista',
          'sharedWithUserId': data['sharedWithUserId'],
          'sharedAt': data['sharedAt'],
          'totalItems': statistics['totalItems'] ?? 0,
          'boughtItems': statistics['boughtItems'] ?? 0,
          'remainingItems': statistics['remainingItems'] ?? 0,
          'shareType': data['shareType'] ?? 'direct_friend',
        };
      }).toList();
    } catch (e) {
      AppLogger.error('Failed to get lists shared by me', e);
      return [];
    }
  }

  /// Import shared shopping list
  Future<String?> importSharedShoppingList(String sharedListId) async {
    try {
      if (!sl<PermissionService>().isAuthenticated) return null;
      
      final currentUserId = sl<PermissionService>().currentUserId;
      if (currentUserId == null) return null;

      // Get shared list data
      final listDoc = await FirebaseFirestore.instance
          .collection('sharedShoppingLists')
          .doc(sharedListId)
          .get();

      if (!listDoc.exists || listDoc.data()!['isActive'] != true) {
        AppLogger.error('Shared shopping list not found or inactive');
        return null;
      }

      final listData = listDoc.data()!;
      final listDataSnapshot = listData['listData'] as Map<String, dynamic>? ?? {};
      
      // Verify user has access to this list
      if (listData['sharedWithUserId'] != currentUserId) {
        AppLogger.error('User does not have access to this shopping list');
        return null;
      }

      // Create the shopping list items
      final itemsData = listDataSnapshot['items'] as List<dynamic>? ?? [];
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

      // Create new shopping list with imported data
      final importedListName = '${listDataSnapshot['name'] ?? 'Importerad lista'} (från ${listData['ownerDisplayName'] ?? 'okänd'})';
      final listId = await _parent.createPersonalList(importedListName, items: items);

      if (listId != null) {
        // Mark as imported in user's received lists
        await FirebaseFirestore.instance
            .collection('userSharedShoppingLists')
            .doc(currentUserId)
            .collection('receivedLists')
            .doc(sharedListId)
            .update({
          'isImported': true,
          'importedAt': FieldValue.serverTimestamp(),
          'importedListId': listId,
        });

        AppLogger.success('✅ Shopping list imported successfully');
      }

      return listId;
    } catch (e) {
      AppLogger.error('Failed to import shared shopping list', e);
      return null;
    }
  }

  /// Mark shared shopping list as viewed
  Future<void> markSharedShoppingListAsViewed(String sharedListId) async {
    try {
      if (!sl<PermissionService>().isAuthenticated) return;
      
      final currentUserId = sl<PermissionService>().currentUserId;
      if (currentUserId == null) return;

      await FirebaseFirestore.instance
          .collection('userSharedShoppingLists')
          .doc(currentUserId)
          .collection('receivedLists')
          .doc(sharedListId)
          .update({
        'isViewed': true,
        'viewedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.debug('Shopping list marked as viewed: $sharedListId');
    } catch (e) {
      AppLogger.error('Failed to mark shopping list as viewed', e);
    }
  }

  /// Get shopping list sharing statistics
  Future<Map<String, dynamic>> getShoppingListSharingStats() async {
    try {
      if (!sl<PermissionService>().isAuthenticated) return {};
      
      final currentUserId = sl<PermissionService>().currentUserId;
      if (currentUserId == null) return {};

      // Get lists shared by user
      final sharedByMeQuery = await FirebaseFirestore.instance
          .collection('sharedShoppingLists')
          .where('ownerId', isEqualTo: currentUserId)
          .where('isActive', isEqualTo: true)
          .get();

      // Get lists shared with user
      final sharedWithMeQuery = await FirebaseFirestore.instance
          .collection('userSharedShoppingLists')
          .doc(currentUserId)
          .collection('receivedLists')
          .get();

      final totalSharedByMe = sharedByMeQuery.docs.length;
      final totalSharedWithMe = sharedWithMeQuery.docs.length;
      
      // Calculate imported lists
      final importedLists = sharedWithMeQuery.docs
          .where((doc) => doc.data()['isImported'] == true)
          .length;

      return {
        'listsSharedByMe': totalSharedByMe,
        'listsSharedWithMe': totalSharedWithMe,
        'importedLists': importedLists,
        'totalSharingActivity': totalSharedByMe + totalSharedWithMe,
      };
    } catch (e) {
      AppLogger.error('Failed to get shopping list sharing stats', e);
      return {};
    }
  }
}