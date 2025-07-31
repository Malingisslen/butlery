// lib/services/unified/operations/realtime_collaborative_shopping_operations.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/modules/shopping_conflict_resolver.dart';
import 'package:butlery/core/injection.dart';

/// Real-time Collaborative Shopping Operations
/// 
/// Extends collaborative shopping with real-time conflict resolution:
/// - Real-time item operations with conflict resolution
/// - Live presence indicators for active shoppers
/// - Collaborative templates and shared lists
/// - Advanced conflict resolution for shopping scenarios
/// - Shopping session management and user presence
class RealtimeCollaborativeShoppingOperations {
  final dynamic _parent; // UnifiedShoppingService
  final FirebaseFirestore _firestore;

  // Real-time state management
  final Map<String, Timer> _conflictResolutionTimers = {};
  final Map<String, List<Map<String, dynamic>>> _pendingShoppingEdits = {};
  final Map<String, StreamSubscription> _realtimeListeners = {};
  final Map<String, Map<String, dynamic>> _activeShoppers = {}; // listId -> userId -> presence info
  final Map<String, Set<String>> _listTemplates = {}; // userId -> template list IDs

  RealtimeCollaborativeShoppingOperations(this._parent, this._firestore);

  // ===== REAL-TIME ITEM OPERATIONS =====

  /// Add item with real-time conflict resolution
  Future<bool> addItemRealtime({
    required String listId,
    required UnifiedShoppingItem item,
    String? userId,
    String? userDisplayName,
  }) async {
    try {
      userId ??= _parent.currentUserId;
      userDisplayName ??= _parent.currentUserDisplayName;

      if (userId == null || userDisplayName == null) {
        AppLogger.error('Cannot add item: User not authenticated');
        return false;
      }

      // Check permissions
      if (!_canEditList(listId)) {
        AppLogger.error('Cannot add item: No edit permission');
        return false;
      }

      // Prepare edit metadata for conflict resolution
      final editMetadata = {
        'operation': 'add_item',
        'item': item.toFirestore(),
        'items': FieldValue.arrayUnion([item.toFirestore()]),
        'lastActivityAt': FieldValue.serverTimestamp(),
        'lastActivityByUserId': userId,
        'lastActivityByDisplayName': userDisplayName,
        'userId': userId,
        'userDisplayName': userDisplayName,
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Apply with conflict resolution
      await ShoppingConflictResolver.applyEditWithConflictResolution(
        firestore: _firestore,
        listId: listId,
        editMetadata: editMetadata,
        conflictResolutionTimers: _conflictResolutionTimers,
        pendingShoppingEdits: _pendingShoppingEdits,
      );

      AppLogger.success('Added item "${item.name}" to list with real-time sync');
      return true;
    } catch (e) {
      AppLogger.error('Failed to add item with real-time sync', e);
      return false;
    }
  }

  /// Remove item with real-time conflict resolution
  Future<bool> removeItemRealtime({
    required String listId,
    required String itemId,
    String? userId,
    String? userDisplayName,
  }) async {
    try {
      userId ??= _parent.currentUserId;
      userDisplayName ??= _parent.currentUserDisplayName;

      if (userId == null || userDisplayName == null) {
        AppLogger.error('Cannot remove item: User not authenticated');
        return false;
      }

      // Check permissions
      if (!_canEditList(listId)) {
        AppLogger.error('Cannot remove item: No edit permission');
        return false;
      }

      // Get current list to find the item
      final listDoc = await _firestore.collection('unified_shopping_lists').doc(listId).get();
      if (!listDoc.exists) {
        AppLogger.error('List not found');
        return false;
      }

      final items = List<Map<String, dynamic>>.from(listDoc.data()?['items'] ?? []);
      final itemToRemove = items.where((item) => item['id'] == itemId).firstOrNull;
      
      if (itemToRemove == null) {
        AppLogger.warning('Item not found in list, may have been already removed');
        return true; // Not an error if item doesn't exist
      }

      // Prepare edit metadata for conflict resolution
      final editMetadata = {
        'operation': 'remove_item',
        'itemId': itemId,
        'items': FieldValue.arrayRemove([itemToRemove]),
        'lastActivityAt': FieldValue.serverTimestamp(),
        'lastActivityByUserId': userId,
        'lastActivityByDisplayName': userDisplayName,
        'userId': userId,
        'userDisplayName': userDisplayName,
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Apply with conflict resolution
      await ShoppingConflictResolver.applyEditWithConflictResolution(
        firestore: _firestore,
        listId: listId,
        editMetadata: editMetadata,
        conflictResolutionTimers: _conflictResolutionTimers,
        pendingShoppingEdits: _pendingShoppingEdits,
      );

      AppLogger.success('Removed item from list with real-time sync');
      return true;
    } catch (e) {
      AppLogger.error('Failed to remove item with real-time sync', e);
      return false;
    }
  }

  /// Toggle item bought status with real-time conflict resolution
  Future<bool> toggleItemBoughtRealtime({
    required String listId,
    required String itemId,
    required bool bought,
    String? userId,
    String? userDisplayName,
  }) async {
    try {
      userId ??= _parent.currentUserId;
      userDisplayName ??= _parent.currentUserDisplayName;

      if (userId == null || userDisplayName == null) {
        AppLogger.error('Cannot toggle item: User not authenticated');
        return false;
      }

      // Check permissions
      if (!_canEditList(listId)) {
        AppLogger.error('Cannot toggle item: No edit permission');
        return false;
      }

      // Get current list to find and update the item
      final listDoc = await _firestore.collection('unified_shopping_lists').doc(listId).get();
      if (!listDoc.exists) {
        AppLogger.error('List not found');
        return false;
      }

      final items = List<Map<String, dynamic>>.from(listDoc.data()?['items'] ?? []);
      final itemIndex = items.indexWhere((item) => item['id'] == itemId);
      
      if (itemIndex == -1) {
        AppLogger.error('Item not found in list');
        return false;
      }

      // Update the item
      final updatedItem = Map<String, dynamic>.from(items[itemIndex]);
      updatedItem['bought'] = bought;
      updatedItem['boughtAt'] = bought ? FieldValue.serverTimestamp() : null;
      updatedItem['boughtBy'] = bought ? userId : null;
      updatedItem['boughtByDisplayName'] = bought ? userDisplayName : null;

      final updatedItems = List<Map<String, dynamic>>.from(items);
      updatedItems[itemIndex] = updatedItem;

      // Prepare edit metadata for conflict resolution
      final editMetadata = {
        'operation': 'toggle_item',
        'itemId': itemId,
        'bought': bought,
        'boughtAt': bought ? FieldValue.serverTimestamp() : null,
        'boughtBy': bought ? userId : null,
        'boughtByDisplayName': bought ? userDisplayName : null,
        'items': updatedItems,
        'lastActivityAt': FieldValue.serverTimestamp(),
        'lastActivityByUserId': userId,
        'lastActivityByDisplayName': userDisplayName,
        'userId': userId,
        'userDisplayName': userDisplayName,
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Apply with conflict resolution
      await ShoppingConflictResolver.applyEditWithConflictResolution(
        firestore: _firestore,
        listId: listId,
        editMetadata: editMetadata,
        conflictResolutionTimers: _conflictResolutionTimers,
        pendingShoppingEdits: _pendingShoppingEdits,
      );

      AppLogger.success('Toggled item "${updatedItem['name']}" (${bought ? 'bought' : 'unbought'}) with real-time sync');
      return true;
    } catch (e) {
      AppLogger.error('Failed to toggle item with real-time sync', e);
      return false;
    }
  }

  /// Batch operations with conflict resolution
  Future<bool> batchOperationsRealtime({
    required String listId,
    required List<Map<String, dynamic>> operations,
    String? userId,
    String? userDisplayName,
  }) async {
    try {
      userId ??= _parent.currentUserId;
      userDisplayName ??= _parent.currentUserDisplayName;

      if (userId == null || userDisplayName == null) {
        AppLogger.error('Cannot perform batch operations: User not authenticated');
        return false;
      }

      // Check permissions
      if (!_canEditList(listId)) {
        AppLogger.error('Cannot perform batch operations: No edit permission');
        return false;
      }

      // Prepare batch edit metadata for conflict resolution
      final editMetadata = {
        'operation': 'batch_operation',
        'operations': operations,
        'lastActivityAt': FieldValue.serverTimestamp(),
        'lastActivityByUserId': userId,
        'lastActivityByDisplayName': userDisplayName,
        'userId': userId,
        'userDisplayName': userDisplayName,
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Apply with conflict resolution
      await ShoppingConflictResolver.applyEditWithConflictResolution(
        firestore: _firestore,
        listId: listId,
        editMetadata: editMetadata,
        conflictResolutionTimers: _conflictResolutionTimers,
        pendingShoppingEdits: _pendingShoppingEdits,
      );

      AppLogger.success('Applied ${operations.length} batch operations with real-time sync');
      return true;
    } catch (e) {
      AppLogger.error('Failed to apply batch operations with real-time sync', e);
      return false;
    }
  }

  // ===== SHOPPING PRESENCE MANAGEMENT =====

  /// Start shopping session (mark user as actively shopping)
  Future<void> startShoppingSession(String listId) async {
    try {
      final userId = _parent.currentUserId;
      final userDisplayName = _parent.currentUserDisplayName;
      
      if (userId == null || userDisplayName == null) return;

      final presenceData = {
        'userId': userId,
        'displayName': userDisplayName,
        'startedAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
        'status': 'shopping',
        'currentSection': null, // Store/aisle section if available
      };

      // Update presence in Firestore
      await _firestore
          .collection('shopping_presence')
          .doc(listId)
          .collection('active_shoppers')
          .doc(userId)
          .set(presenceData);

      // Update local state
      _activeShoppers.putIfAbsent(listId, () => {});
      _activeShoppers[listId]![userId] = presenceData;

      // Set up presence heartbeat
      _startPresenceHeartbeat(listId, userId);

      AppLogger.info('Started shopping session for list $listId');
    } catch (e) {
      AppLogger.error('Failed to start shopping session', e);
    }
  }

  /// End shopping session
  Future<void> endShoppingSession(String listId) async {
    try {
      final userId = _parent.currentUserId;
      if (userId == null) return;

      // Remove from Firestore
      await _firestore
          .collection('shopping_presence')
          .doc(listId)
          .collection('active_shoppers')
          .doc(userId)
          .delete();

      // Update local state
      _activeShoppers[listId]?.remove(userId);

      AppLogger.info('Ended shopping session for list $listId');
    } catch (e) {
      AppLogger.error('Failed to end shopping session', e);
    }
  }

  /// Get active shoppers for a list
  List<Map<String, dynamic>> getActiveShoppers(String listId) {
    return _activeShoppers[listId]?.values.map((value) => 
        Map<String, dynamic>.from(value)).toList() ?? [];
  }

  /// Start presence heartbeat to keep user marked as active
  void _startPresenceHeartbeat(String listId, String userId) {
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!_activeShoppers.containsKey(listId) || 
          !_activeShoppers[listId]!.containsKey(userId)) {
        timer.cancel();
        return;
      }

      _firestore
          .collection('shopping_presence')
          .doc(listId)
          .collection('active_shoppers')
          .doc(userId)
          .update({'lastSeenAt': FieldValue.serverTimestamp()});
    });
  }

  // ===== SHOPPING TEMPLATES =====

  /// Create shopping list template
  Future<String?> createShoppingTemplate({
    required String name,
    required List<UnifiedShoppingItem> templateItems,
    String? description,
    List<String>? tags,
  }) async {
    try {
      final userId = _parent.currentUserId;
      final userDisplayName = _parent.currentUserDisplayName;
      
      if (userId == null || userDisplayName == null) {
        AppLogger.error('Cannot create template: User not authenticated');
        return null;
      }

      final templateData = {
        'name': name,
        'description': description,
        'ownerId': userId,
        'ownerDisplayName': userDisplayName,
        'items': templateItems.map((item) => item.toFirestore()).toList(),
        'tags': tags ?? [],
        'isTemplate': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'useCount': 0,
      };

      final docRef = await _firestore
          .collection('shopping_templates')
          .add(templateData);

      // Update local templates
      _listTemplates.putIfAbsent(userId, () => {});
      _listTemplates[userId]!.add(docRef.id);

      AppLogger.success('Created shopping template: $name');
      return docRef.id;
    } catch (e) {
      AppLogger.error('Failed to create shopping template', e);
      return null;
    }
  }

  /// Create list from template
  Future<String?> createListFromTemplate({
    required String templateId,
    required String listName,
    List<String>? memberIds,
    Map<String, String>? memberDisplayNames,
  }) async {
    try {
      // Get template
      final templateDoc = await _firestore
          .collection('shopping_templates')
          .doc(templateId)
          .get();

      if (!templateDoc.exists) {
        AppLogger.error('Template not found');
        return null;
      }

      final templateData = templateDoc.data()!;
      final templateItems = (templateData['items'] as List<dynamic>?)
          ?.map((item) => UnifiedShoppingItem.fromJson(item as Map<String, dynamic>))
          .toList() ?? [];

      // Create collaborative or personal list based on members
      String? listId;
      if (memberIds != null && memberIds.isNotEmpty && memberDisplayNames != null) {
        // Create collaborative list
        listId = await _parent.createCollaborativeList(
          name: listName,
          description: 'Created from template: ${templateData['name']}',
          memberIds: memberIds,
          memberDisplayNames: memberDisplayNames,
          items: templateItems,
        );
      } else {
        // Create personal list
        listId = await _parent.createPersonalList(
          listName,
          items: templateItems,
        );
      }

      if (listId != null) {
        // Increment template use count
        await _firestore
            .collection('shopping_templates')
            .doc(templateId)
            .update({'useCount': FieldValue.increment(1)});
      }

      AppLogger.success('Created list from template: $listName');
      return listId;
    } catch (e) {
      AppLogger.error('Failed to create list from template', e);
      return null;
    }
  }

  // ===== CONFLICT RESOLUTION UTILITIES =====

  /// Force resolve conflicts for a list
  Future<void> forceResolveConflicts(String listId) async {
    await ShoppingConflictResolver.forceResolveShoppingConflicts(
      firestore: _firestore,
      listId: listId,
      pendingShoppingEdits: _pendingShoppingEdits,
      conflictResolutionTimers: _conflictResolutionTimers,
    );
  }

  /// Get conflict statistics
  Map<String, dynamic> getConflictStatistics() {
    return ShoppingConflictResolver.getShoppingConflictStatistics(
      pendingShoppingEdits: _pendingShoppingEdits,
      conflictResolutionTimers: _conflictResolutionTimers,
    );
  }

  /// Check if list has pending conflicts
  bool hasConflicts(String listId) {
    return (_pendingShoppingEdits[listId]?.length ?? 0) > 0;
  }

  // ===== PERMISSION HELPERS =====

  bool _canEditList(String listId) {
    final permissionService = sl<PermissionService>();
    return permissionService.canEditShoppingList(listId);
  }


  // ===== CLEANUP =====

  /// Dispose of real-time resources
  void dispose() {
    // Cancel all conflict resolution timers
    for (final timer in _conflictResolutionTimers.values) {
      timer.cancel();
    }
    _conflictResolutionTimers.clear();

    // Cancel all real-time listeners
    for (final subscription in _realtimeListeners.values) {
      subscription.cancel();
    }
    _realtimeListeners.clear();

    // Clear state
    _pendingShoppingEdits.clear();
    _activeShoppers.clear();
    _listTemplates.clear();

    AppLogger.info('Disposed real-time collaborative shopping operations');
  }
}