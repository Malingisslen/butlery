// lib/services/unified/modules/shopping_conflict_resolver.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart';

/// Shopping List Conflict Resolution Module
/// 
/// This module handles real-time conflict resolution for collaborative shopping lists:
/// - Item addition/removal conflicts
/// - Item status (bought/unbought) conflicts  
/// - List metadata conflicts (name, description)
/// - Optimistic update conflict management
/// - Member permission conflicts
/// 
/// Based on the proven RealtimeConflictResolver pattern but adapted for shopping lists
class ShoppingConflictResolver {

  // ===== CONFLICT RESOLUTION ORCHESTRATION =====

  /// Apply real-time shopping list edit with conflict resolution
  static Future<void> applyEditWithConflictResolution({
    required FirebaseFirestore firestore,
    required String listId,
    required Map<String, dynamic> editMetadata,
    required Map<String, Timer> conflictResolutionTimers,
    required Map<String, List<Map<String, dynamic>>> pendingShoppingEdits,
  }) async {
    try {
      // Cancel any existing conflict resolution timer
      conflictResolutionTimers[listId]?.cancel();

      // Apply edit immediately (optimistic update)
      await firestore
          .collection('unified_shopping_lists')
          .doc(listId)
          .update(editMetadata);

      // Set up conflict resolution timer
      conflictResolutionTimers[listId] = Timer(
        const Duration(milliseconds: 300), // Shorter delay for shopping lists
        () => resolveShoppingConflicts(
          firestore: firestore,
          listId: listId,
          pendingShoppingEdits: pendingShoppingEdits,
          conflictResolutionTimers: conflictResolutionTimers,
        ),
      );
    } catch (e) {
      AppLogger.error('Shopping conflict during real-time edit: $e');
      await _handleShoppingConflict(
        listId: listId,
        editMetadata: editMetadata,
        pendingShoppingEdits: pendingShoppingEdits,
        conflictResolutionTimers: conflictResolutionTimers,
        firestore: firestore,
      );
    }
  }

  /// Resolve shopping list conflicts
  static Future<void> resolveShoppingConflicts({
    required FirebaseFirestore firestore,
    required String listId,
    required Map<String, List<Map<String, dynamic>>> pendingShoppingEdits,
    required Map<String, Timer> conflictResolutionTimers,
  }) async {
    try {
      final pendingEdits = pendingShoppingEdits[listId];
      if (pendingEdits == null || pendingEdits.isEmpty) return;

      AppLogger.debug('🛒 Resolving shopping conflicts for list $listId (${pendingEdits.length} pending edits)');

      // Load current shopping list state
      final snapshot = await firestore
          .collection('unified_shopping_lists')
          .doc(listId)
          .get();

      if (!snapshot.exists) {
        AppLogger.warning('Shopping list $listId no longer exists during conflict resolution');
        return;
      }

      // Apply conflict resolution strategy (shopping-optimized merging)
      final currentData = snapshot.data()!;
      final resolvedData = mergeShoppingConflicts(currentData, pendingEdits);

      // Apply resolved changes
      await firestore
          .collection('unified_shopping_lists')
          .doc(listId)
          .update(resolvedData);

      // Clear pending edits
      pendingShoppingEdits[listId]?.clear();

      AppLogger.success('✅ Shopping conflicts resolved for list $listId');
    } catch (e) {
      AppLogger.error('❌ Error resolving shopping conflicts: $e');
      // Don't clear pending edits on failure - they'll be retried
    }
  }

  // ===== SHOPPING-SPECIFIC CONFLICT MERGING =====

  /// Merge conflicting shopping edits using shopping-optimized strategies
  static Map<String, dynamic> mergeShoppingConflicts(
    Map<String, dynamic> currentData,
    List<Map<String, dynamic>> pendingEdits,
  ) {
    final resolvedData = Map<String, dynamic>.from(currentData);

    // Group edits by operation type
    final editsByOperation = <String, List<Map<String, dynamic>>>{};
    for (final edit in pendingEdits) {
      final operation = edit['operation'] as String? ?? 'update';
      editsByOperation.putIfAbsent(operation, () => []).add(edit);
    }

    AppLogger.debug('Merging shopping edits: ${editsByOperation.length} operation types');

    // Apply operation-specific conflict resolution
    for (final entry in editsByOperation.entries) {
      final operation = entry.key;
      final opEdits = entry.value;

      switch (operation) {
        case 'add_item':
          _mergeAddItemOperations(resolvedData, opEdits);
          break;
        case 'remove_item':
          _mergeRemoveItemOperations(resolvedData, opEdits);
          break;
        case 'toggle_item':
          _mergeToggleItemOperations(resolvedData, opEdits);
          break;
        case 'update_item':
          _mergeUpdateItemOperations(resolvedData, opEdits);
          break;
        case 'update_list':
          _mergeListMetadataUpdates(resolvedData, opEdits);
          break;
        case 'update_permissions':
          _mergePermissionUpdates(resolvedData, opEdits);
          break;
        case 'batch_operation':
          _mergeBatchShoppingOperations(resolvedData, opEdits);
          break;
        default:
          _mergeGenericOperation(resolvedData, operation, opEdits);
      }
    }

    // Update activity metadata
    resolvedData['lastActivityAt'] = FieldValue.serverTimestamp();

    return resolvedData;
  }

  /// Merge add item operations - handle duplicates intelligently
  static void _mergeAddItemOperations(
    Map<String, dynamic> resolvedData,
    List<Map<String, dynamic>> addEdits,
  ) {
    final items = List<Map<String, dynamic>>.from(resolvedData['items'] ?? []);
    final addedItemNames = <String>{};

    // Sort by timestamp to maintain order
    addEdits.sort((a, b) => _compareTimestamps(a, b));

    for (final edit in addEdits) {
      final itemData = edit['item'] as Map<String, dynamic>?;
      if (itemData == null) continue;

      final itemName = (itemData['name'] as String? ?? '').toLowerCase().trim();
      if (itemName.isEmpty) continue;

      // Check for duplicates (case-insensitive)
      final isDuplicate = items.any((existing) => 
        (existing['name'] as String? ?? '').toLowerCase().trim() == itemName);

      if (!isDuplicate && !addedItemNames.contains(itemName)) {
        items.add(itemData);
        addedItemNames.add(itemName);
        
        // Update activity info
        resolvedData['lastActivityByUserId'] = edit['userId'];
        resolvedData['lastActivityByDisplayName'] = edit['userDisplayName'];
        
        AppLogger.debug('Added item: $itemName');
      } else {
        AppLogger.debug('Skipped duplicate item: $itemName');
      }
    }

    resolvedData['items'] = items;
  }

  /// Merge remove item operations - handle missing items gracefully
  static void _mergeRemoveItemOperations(
    Map<String, dynamic> resolvedData,
    List<Map<String, dynamic>> removeEdits,
  ) {
    final items = List<Map<String, dynamic>>.from(resolvedData['items'] ?? []);
    final itemsToRemove = <String>{};

    // Collect all item IDs to remove
    for (final edit in removeEdits) {
      final itemId = edit['itemId'] as String?;
      if (itemId != null) {
        itemsToRemove.add(itemId);
      }
    }

    // Remove items (if they still exist)
    final initialCount = items.length;
    items.removeWhere((item) => itemsToRemove.contains(item['id']));
    
    if (items.length < initialCount) {
      resolvedData['items'] = items;
      
      // Use last remove operation for activity info
      final lastEdit = removeEdits.last;
      resolvedData['lastActivityByUserId'] = lastEdit['userId'];
      resolvedData['lastActivityByDisplayName'] = lastEdit['userDisplayName'];
      
      AppLogger.debug('Removed ${initialCount - items.length} items');
    }
  }

  /// Merge toggle item operations - prioritize most recent toggle per item
  static void _mergeToggleItemOperations(
    Map<String, dynamic> resolvedData,
    List<Map<String, dynamic>> toggleEdits,
  ) {
    final items = List<Map<String, dynamic>>.from(resolvedData['items'] ?? []);
    
    // Group toggles by item ID and take the most recent for each
    final latestToggles = <String, Map<String, dynamic>>{};
    for (final edit in toggleEdits) {
      final itemId = edit['itemId'] as String?;
      if (itemId != null) {
        final existing = latestToggles[itemId];
        if (existing == null || _compareTimestamps(edit, existing) > 0) {
          latestToggles[itemId] = edit;
        }
      }
    }

    // Apply the latest toggle for each item
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final itemId = item['id'] as String?;
      if (itemId != null && latestToggles.containsKey(itemId)) {
        final toggleEdit = latestToggles[itemId]!;
        
        items[i] = Map<String, dynamic>.from(item);
        items[i]['bought'] = toggleEdit['bought'] as bool? ?? false;
        items[i]['boughtAt'] = toggleEdit['boughtAt'];
        items[i]['boughtBy'] = toggleEdit['boughtBy'];
        items[i]['boughtByDisplayName'] = toggleEdit['boughtByDisplayName'];
        
        // Update activity info
        resolvedData['lastActivityByUserId'] = toggleEdit['userId'];
        resolvedData['lastActivityByDisplayName'] = toggleEdit['userDisplayName'];
      }
    }

    resolvedData['items'] = items;
    AppLogger.debug('Applied ${latestToggles.length} item toggles');
  }

  /// Merge update item operations - use last update per item
  static void _mergeUpdateItemOperations(
    Map<String, dynamic> resolvedData,
    List<Map<String, dynamic>> updateEdits,
  ) {
    final items = List<Map<String, dynamic>>.from(resolvedData['items'] ?? []);
    
    // Group updates by item ID and take the most recent for each field
    final latestUpdates = <String, Map<String, dynamic>>{};
    for (final edit in updateEdits) {
      final itemId = edit['itemId'] as String?;
      if (itemId != null) {
        final existing = latestUpdates[itemId];
        if (existing == null || _compareTimestamps(edit, existing) > 0) {
          latestUpdates[itemId] = edit;
        }
      }
    }

    // Apply the latest update for each item
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final itemId = item['id'] as String?;
      if (itemId != null && latestUpdates.containsKey(itemId)) {
        final updateEdit = latestUpdates[itemId]!;
        final updatedItem = updateEdit['updatedItem'] as Map<String, dynamic>?;
        
        if (updatedItem != null) {
          items[i] = Map<String, dynamic>.from(updatedItem);
          
          // Update activity info
          resolvedData['lastActivityByUserId'] = updateEdit['userId'];
          resolvedData['lastActivityByDisplayName'] = updateEdit['userDisplayName'];
        }
      }
    }

    resolvedData['items'] = items;
    AppLogger.debug('Applied ${latestUpdates.length} item updates');
  }

  /// Merge list metadata updates (name, description, settings)
  static void _mergeListMetadataUpdates(
    Map<String, dynamic> resolvedData,
    List<Map<String, dynamic>> metadataEdits,
  ) {
    // Sort by timestamp and apply in order (last-write-wins for metadata)
    metadataEdits.sort((a, b) => _compareTimestamps(a, b));
    
    for (final edit in metadataEdits) {
      final updates = edit['updates'] as Map<String, dynamic>?;
      if (updates != null) {
        for (final entry in updates.entries) {
          resolvedData[entry.key] = entry.value;
        }
        
        // Update activity info
        resolvedData['lastActivityByUserId'] = edit['userId'];
        resolvedData['lastActivityByDisplayName'] = edit['userDisplayName'];
      }
    }
    
    AppLogger.debug('Applied ${metadataEdits.length} metadata updates');
  }

  /// Merge permission updates - maintain permission hierarchy
  static void _mergePermissionUpdates(
    Map<String, dynamic> resolvedData,
    List<Map<String, dynamic>> permissionEdits,
  ) {
    final memberPermissions = Map<String, String>.from(
      resolvedData['memberPermissions'] ?? {}
    );

    // Sort by timestamp and apply in order
    permissionEdits.sort((a, b) => _compareTimestamps(a, b));
    
    for (final edit in permissionEdits) {
      final userId = edit['targetUserId'] as String?;
      final permission = edit['permission'] as String?;
      final editorUserId = edit['userId'] as String?;
      
      if (userId != null && permission != null && editorUserId != null) {
        // Verify editor has admin permissions
        final editorPermission = memberPermissions[editorUserId];
        if (editorPermission == 'admin' || editorUserId == resolvedData['ownerId']) {
          memberPermissions[userId] = permission;
          
          resolvedData['lastActivityByUserId'] = edit['userId'];
          resolvedData['lastActivityByDisplayName'] = edit['userDisplayName'];
        }
      }
    }

    resolvedData['memberPermissions'] = memberPermissions;
    AppLogger.debug('Applied ${permissionEdits.length} permission updates');
  }

  /// Merge batch shopping operations
  static void _mergeBatchShoppingOperations(
    Map<String, dynamic> resolvedData,
    List<Map<String, dynamic>> batchEdits,
  ) {
    // Sort batch operations by timestamp
    batchEdits.sort((a, b) => _compareTimestamps(a, b));
    
    for (final batchEdit in batchEdits) {
      final operations = batchEdit['operations'] as List<dynamic>? ?? [];
      
      for (final operation in operations) {
        final opMap = operation as Map<String, dynamic>;
        final opType = opMap['operation'] as String?;
        
        if (opType != null) {
          _mergeGenericOperation(resolvedData, opType, [opMap]);
        }
      }
    }
    
    AppLogger.debug('Applied ${batchEdits.length} batch operations');
  }

  /// Merge generic operation - fallback for unknown operations
  static void _mergeGenericOperation(
    Map<String, dynamic> resolvedData,
    String operation,
    List<Map<String, dynamic>> opEdits,
  ) {
    // For unknown operations, apply the most recent one
    if (opEdits.isEmpty) return;
    
    opEdits.sort((a, b) => _compareTimestamps(a, b));
    final lastEdit = opEdits.last;
    
    // Apply any direct field updates
    for (final entry in lastEdit.entries) {
      if (!['operation', 'userId', 'userDisplayName', 'timestamp'].contains(entry.key)) {
        resolvedData[entry.key] = entry.value;
      }
    }
    
    resolvedData['lastActivityByUserId'] = lastEdit['userId'];
    resolvedData['lastActivityByDisplayName'] = lastEdit['userDisplayName'];
    
    AppLogger.debug('Applied generic operation: $operation');
  }

  // ===== CONFLICT HANDLING =====

  /// Handle shopping conflict when Firebase update fails
  static Future<void> _handleShoppingConflict({
    required String listId,
    required Map<String, dynamic> editMetadata,
    required Map<String, List<Map<String, dynamic>>> pendingShoppingEdits,
    required Map<String, Timer> conflictResolutionTimers,
    required FirebaseFirestore firestore,
  }) async {
    AppLogger.warning('⚠️ Shopping conflict detected for list $listId');
    
    // Add to pending edits for later resolution
    pendingShoppingEdits.putIfAbsent(listId, () => []);
    pendingShoppingEdits[listId]!.add(editMetadata);

    // Trigger conflict resolution with delay
    conflictResolutionTimers[listId] = Timer(
      const Duration(milliseconds: 600), // Slightly longer delay for shopping conflicts
      () => resolveShoppingConflicts(
        firestore: firestore,
        listId: listId,
        pendingShoppingEdits: pendingShoppingEdits,
        conflictResolutionTimers: conflictResolutionTimers,
      ),
    );
  }

  // ===== CONFLICT PREVENTION =====

  /// Check if shopping edit would cause conflict
  static bool wouldCauseShoppingConflict({
    required Map<String, dynamic> currentData,
    required Map<String, dynamic> editData,
    required String operation,
  }) {
    // Check if the list was modified recently by another user
    final lastActivityByUserId = currentData['lastActivityByUserId'] as String?;
    final editUserId = editData['userId'] as String?;
    
    if (lastActivityByUserId != null && editUserId != null && lastActivityByUserId != editUserId) {
      final lastActivityAt = currentData['lastActivityAt'] as Timestamp?;
      if (lastActivityAt != null) {
        final timeSinceLastActivity = DateTime.now().difference(lastActivityAt.toDate());
        // Consider shopping edits within 3 seconds as potential conflicts
        return timeSinceLastActivity.inSeconds < 3;
      }
    }
    
    return false;
  }

  /// Get conflict resolution strategy for shopping operation
  static String getShoppingConflictStrategy(String operation) {
    switch (operation) {
      case 'add_item':
        return 'merge-duplicates';
      case 'remove_item':
        return 'remove-if-exists';
      case 'toggle_item':
        return 'last-toggle-wins';
      case 'update_item':
        return 'last-update-wins';
      case 'update_list':
        return 'last-write-wins';
      case 'update_permissions':
        return 'admin-only-with-timestamp';
      default:
        return 'last-write-wins';
    }
  }

  // ===== UTILITY METHODS =====

  /// Compare timestamps from edit metadata
  static int _compareTimestamps(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aTime = a['timestamp'] as Timestamp? ?? a['editedAt'] as Timestamp?;
    final bTime = b['timestamp'] as Timestamp? ?? b['editedAt'] as Timestamp?;
    
    if (aTime == null && bTime == null) return 0;
    if (aTime == null) return -1;
    if (bTime == null) return 1;
    
    return aTime.compareTo(bTime);
  }

  // ===== CONFLICT ANALYTICS =====

  /// Get shopping conflict statistics
  static Map<String, dynamic> getShoppingConflictStatistics({
    required Map<String, List<Map<String, dynamic>>> pendingShoppingEdits,
    required Map<String, Timer> conflictResolutionTimers,
  }) {
    final totalPendingEdits = pendingShoppingEdits.values
        .fold<int>(0, (total, edits) => total + edits.length);
    
    final activeConflictTimers = conflictResolutionTimers.values
        .where((timer) => timer.isActive)
        .length;

    final listsWithConflicts = pendingShoppingEdits.keys
        .where((listId) => (pendingShoppingEdits[listId]?.length ?? 0) > 1)
        .length;

    return {
      'total_pending_edits': totalPendingEdits,
      'active_conflict_timers': activeConflictTimers,
      'lists_with_conflicts': listsWithConflicts,
      'lists_with_pending_edits': pendingShoppingEdits.length,
    };
  }

  /// Clear resolved shopping conflicts
  static void clearResolvedShoppingConflicts({
    required String listId,
    required Map<String, List<Map<String, dynamic>>> pendingShoppingEdits,
    required Map<String, Timer> conflictResolutionTimers,
  }) {
    pendingShoppingEdits.remove(listId);
    conflictResolutionTimers[listId]?.cancel();
    conflictResolutionTimers.remove(listId);
  }

  /// Force resolve all conflicts for a shopping list
  static Future<void> forceResolveShoppingConflicts({
    required FirebaseFirestore firestore,
    required String listId,
    required Map<String, List<Map<String, dynamic>>> pendingShoppingEdits,
    required Map<String, Timer> conflictResolutionTimers,
  }) async {
    AppLogger.info('🔧 Force resolving shopping conflicts for list $listId');
    
    // Cancel any existing timer
    conflictResolutionTimers[listId]?.cancel();
    
    // Resolve immediately
    await resolveShoppingConflicts(
      firestore: firestore,
      listId: listId,
      pendingShoppingEdits: pendingShoppingEdits,
      conflictResolutionTimers: conflictResolutionTimers,
    );
  }
}