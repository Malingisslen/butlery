// lib/services/unified/operations/realtime_recipe/presence_tracking_module.dart

import 'dart:async';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/unified/operations/realtime_recipe/shared/realtime_recipe_utils.dart';

/// Presence tracking module
/// 
/// This module handles ONLY user presence tracking:
/// - Show/hide user presence in recipes
/// - Track who's viewing/editing recipes
/// - Manage presence status updates
/// - Stream presence changes to UI
/// 
/// ❌ DOES NOT CONTAIN: Watching, editing, collaboration management, notifications
class PresenceTrackingModule {
  final dynamic _parent; // UnifiedRecipeService
  final dynamic _realtimeSyncService; // RealtimeSyncService?

  // Local presence tracking
  final Map<String, Set<String>> _recipePresence = {}; // recipeId -> Set<userId>
  final Map<String, DateTime> _presenceTimestamps = {}; // userId_recipeId -> timestamp
  final StreamController<Map<String, List<Map<String, dynamic>>>> _presenceController =
      StreamController<Map<String, List<Map<String, dynamic>>>>.broadcast();

  PresenceTrackingModule(this._parent, [this._realtimeSyncService]) {
    _startPresenceCleanup();
  }

  // ===== PRESENCE MANAGEMENT =====

  /// Show user presence in recipe (user starts viewing/editing)
  Future<bool> showPresence(String recipeId) async {
    try {
      if (!ServiceLocator.get<PermissionService>().isAuthenticated) return false;
      
      final currentUser = ServiceLocator.get<PermissionService>().currentUser;
      if (currentUser == null) return false;

      final currentUserId = currentUser.uid;
      
      // Update local presence tracking
      _updateLocalPresence(recipeId, currentUserId, true);
      
      // In a real implementation, this would update Firebase presence
      if (_realtimeSyncService != null) {
        // await FirebaseFirestore.instance
        //     .collection('recipePresence')
        //     .doc(recipeId)
        //     .collection('activeUsers')
        //     .doc(currentUserId)
        //     .set({
        //   'userId': currentUserId,
        //   'displayName': currentUser.displayName,
        //   'avatarUrl': currentUser.avatarUrl,
        //   'joinedAt': FieldValue.serverTimestamp(),
        //   'lastSeen': FieldValue.serverTimestamp(),
        //   'isActive': true,
        // }, SetOptions(merge: true));
      }

      AppLogger.info('Showing presence for ${currentUser.displayName} in recipe: $recipeId');
      _notifyPresenceChange(recipeId);
      return true;
    } catch (e) {
      AppLogger.error('Failed to show presence', e);
      return false;
    }
  }

  /// Hide user presence in recipe (user stops viewing/editing)
  Future<bool> hidePresence(String recipeId) async {
    try {
      if (!ServiceLocator.get<PermissionService>().isAuthenticated) return false;
      
      final currentUser = ServiceLocator.get<PermissionService>().currentUser;
      if (currentUser == null) return false;

      final currentUserId = currentUser.uid;
      
      // Update local presence tracking
      _updateLocalPresence(recipeId, currentUserId, false);
      
      // In a real implementation, this would update Firebase presence
      if (_realtimeSyncService != null) {
        // await FirebaseFirestore.instance
        //     .collection('recipePresence')
        //     .doc(recipeId)
        //     .collection('activeUsers')
        //     .doc(currentUserId)
        //     .update({
        //   'isActive': false,
        //   'leftAt': FieldValue.serverTimestamp(),
        // });
      }

      AppLogger.info('Hiding presence for ${currentUser.displayName} in recipe: $recipeId');
      _notifyPresenceChange(recipeId);
      return true;
    } catch (e) {
      AppLogger.error('Failed to hide presence', e);
      return false;
    }
  }

  /// Update presence heartbeat (keep user active)
  Future<bool> updatePresenceHeartbeat(String recipeId) async {
    try {
      if (!ServiceLocator.get<PermissionService>().isAuthenticated) return false;
      
      final currentUserId = ServiceLocator.get<PermissionService>().currentUserId;
      if (currentUserId == null) return false;

      // Update local timestamp
      _presenceTimestamps['${currentUserId}_$recipeId'] = DateTime.now();
      
      // In a real implementation, this would update Firebase presence
      if (_realtimeSyncService != null) {
        // await FirebaseFirestore.instance
        //     .collection('recipePresence')
        //     .doc(recipeId)
        //     .collection('activeUsers')
        //     .doc(currentUserId)
        //     .update({
        //   'lastSeen': FieldValue.serverTimestamp(),
        // });
      }

      AppLogger.debug('Updated presence heartbeat for user: $currentUserId in recipe: $recipeId');
      return true;
    } catch (e) {
      AppLogger.error('Failed to update presence heartbeat', e);
      return false;
    }
  }

  // ===== PRESENCE QUERIES =====

  /// Get users currently viewing/editing the recipe
  Future<List<Map<String, dynamic>>> getRecipePresence(String recipeId) async {
    try {
      final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
      if (recipe == null || !recipe.isCollaborative) return [];

      final presence = <Map<String, dynamic>>[];
      
      // Get local presence data
      final activeUserIds = _recipePresence[recipeId] ?? <String>{};
      
      for (final userId in activeUserIds) {
        final timestampKey = '${userId}_$recipeId';
        final lastSeen = _presenceTimestamps[timestampKey] ?? DateTime.now();
        
        // Check if user is still active (within last 2 minutes)
        final isActive = DateTime.now().difference(lastSeen).inMinutes < 2;
        
        if (isActive) {
          final member = recipe.socialData?.memberPermissions?[userId];
          if (member != null) {
            presence.add({
              'userId': userId,
              'displayName': _getUserDisplayName(userId),
              'avatarUrl': _getUserAvatarUrl(userId),
              'isEditing': RealtimeRecipeUtils.isUserActivelyViewing(userId, recipeId),
              'permission': member.toString().split('.').last,
              'lastSeen': lastSeen,
              'joinedAt': lastSeen, // Simplified - would track actual join time
            });
          }
        }
      }

      // Add active editors from recipe metadata
      final activeEditors = RealtimeRecipeUtils.getActiveEditorsFromRecipe(recipe);
      for (final editorId in activeEditors) {
        if (!presence.any((p) => p['userId'] == editorId)) {
          final member = recipe.socialData?.memberPermissions?[editorId];
          if (member != null) {
            presence.add({
              'userId': editorId,
              'displayName': _getUserDisplayName(editorId),
              'avatarUrl': _getUserAvatarUrl(editorId),
              'isEditing': true,
              'permission': member.toString().split('.').last,
              'lastSeen': DateTime.now(),
              'joinedAt': DateTime.now().subtract(const Duration(minutes: 1)),
            });
          }
        }
      }

      AppLogger.debug('Recipe presence for $recipeId: ${presence.length} active users');
      return presence;
    } catch (e) {
      AppLogger.error('Failed to get recipe presence', e);
      return [];
    }
  }

  /// Get presence for multiple recipes
  Future<Map<String, List<Map<String, dynamic>>>> getMultipleRecipePresence(
    List<String> recipeIds
  ) async {
    final presenceMap = <String, List<Map<String, dynamic>>>{};
    
    for (final recipeId in recipeIds) {
      presenceMap[recipeId] = await getRecipePresence(recipeId);
    }
    
    return presenceMap;
  }

  /// Check if user is present in recipe
  bool isUserPresent(String recipeId, String userId) {
    final activeUsers = _recipePresence[recipeId] ?? <String>{};
    if (!activeUsers.contains(userId)) return false;
    
    // Check timestamp
    final timestampKey = '${userId}_$recipeId';
    final lastSeen = _presenceTimestamps[timestampKey];
    if (lastSeen == null) return false;
    
    return DateTime.now().difference(lastSeen).inMinutes < 2;
  }

  /// Get presence count for recipe
  int getPresenceCount(String recipeId) {
    final activeUsers = _recipePresence[recipeId] ?? <String>{};
    return activeUsers.where((userId) => isUserPresent(recipeId, userId)).length;
  }

  // ===== PRESENCE STREAMS =====

  /// Stream of presence updates for a recipe
  Stream<List<Map<String, dynamic>>> watchRecipePresence(String recipeId) {
    return _presenceController.stream
        .map((presenceMap) => presenceMap[recipeId] ?? [])
        .distinct();
  }

  /// Stream of presence updates for multiple recipes
  Stream<Map<String, List<Map<String, dynamic>>>> watchMultipleRecipePresence(
    List<String> recipeIds
  ) {
    return _presenceController.stream
        .map((presenceMap) {
          final filtered = <String, List<Map<String, dynamic>>>{};
          for (final recipeId in recipeIds) {
            filtered[recipeId] = presenceMap[recipeId] ?? [];
          }
          return filtered;
        })
        .distinct();
  }

  /// Stream of presence count for recipe
  Stream<int> watchPresenceCount(String recipeId) {
    return watchRecipePresence(recipeId)
        .map((presence) => presence.length);
  }

  // ===== PRESENCE UTILITIES =====

  /// Start automatic presence tracking for recipe
  StreamSubscription<void>? startAutomaticPresenceTracking(
    String recipeId, {
    Duration heartbeatInterval = const Duration(seconds: 30),
  }) {
    return Stream.periodic(heartbeatInterval)
        .listen((_) async {
          if (isUserPresent(recipeId, _parent.currentUserId ?? '')) {
            await updatePresenceHeartbeat(recipeId);
          }
        });
  }

  /// Bulk update presence for multiple recipes
  Future<void> updateMultipleRecipePresence(
    Map<String, bool> recipePresenceMap
  ) async {
    for (final entry in recipePresenceMap.entries) {
      if (entry.value) {
        await showPresence(entry.key);
      } else {
        await hidePresence(entry.key);
      }
    }
  }

  /// Clear all presence for current user
  Future<void> clearAllPresence() async {
    try {
      final currentUserId = _parent.currentUserId;
      if (currentUserId == null) return;

      final recipesToClear = <String>[];
      
      // Find all recipes where user is present
      for (final entry in _recipePresence.entries) {
        if (entry.value.contains(currentUserId)) {
          recipesToClear.add(entry.key);
        }
      }

      // Clear presence from all recipes
      for (final recipeId in recipesToClear) {
        await hidePresence(recipeId);
      }

      AppLogger.info('Cleared presence from ${recipesToClear.length} recipes');
    } catch (e) {
      AppLogger.error('Failed to clear all presence', e);
    }
  }

  // ===== PRESENCE ANALYTICS =====

  /// Get presence statistics
  Map<String, dynamic> getPresenceStatistics() {
    final totalActiveRecipes = _recipePresence.keys.length;
    final totalActiveUsers = _recipePresence.values
        .expand((users) => users)
        .toSet()
        .length;
    
    final presenceByRecipe = <String, int>{};
    for (final entry in _recipePresence.entries) {
      presenceByRecipe[entry.key] = entry.value.length;
    }

    final mostActiveRecipe = presenceByRecipe.isNotEmpty
        ? presenceByRecipe.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key
        : null;

    return {
      'totalActiveRecipes': totalActiveRecipes,
      'totalActiveUsers': totalActiveUsers,
      'averageUsersPerRecipe': totalActiveRecipes > 0 
          ? (totalActiveUsers / totalActiveRecipes).round() 
          : 0,
      'mostActiveRecipeId': mostActiveRecipe,
      'presenceByRecipe': presenceByRecipe,
    };
  }

  /// Get user's presence history
  List<Map<String, dynamic>> getUserPresenceHistory(String userId) {
    final history = <Map<String, dynamic>>[];
    
    for (final entry in _presenceTimestamps.entries) {
      final parts = entry.key.split('_');
      if (parts.length == 2 && parts[0] == userId) {
        final recipeId = parts[1];
        history.add({
          'recipeId': recipeId,
          'timestamp': entry.value,
          'isActive': isUserPresent(recipeId, userId),
        });
      }
    }

    // Sort by timestamp (newest first)
    history.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
    
    return history;
  }

  // ===== PRIVATE METHODS =====

  /// Update local presence tracking
  void _updateLocalPresence(String recipeId, String userId, bool isActive) {
    if (isActive) {
      _recipePresence.putIfAbsent(recipeId, () => <String>{}).add(userId);
      _presenceTimestamps['${userId}_$recipeId'] = DateTime.now();
    } else {
      _recipePresence[recipeId]?.remove(userId);
      _presenceTimestamps.remove('${userId}_$recipeId');
      
      // Clean up empty recipe presence
      if (_recipePresence[recipeId]?.isEmpty == true) {
        _recipePresence.remove(recipeId);
      }
    }
  }

  /// Notify presence change
  void _notifyPresenceChange(String recipeId) {
    _updatePresenceStream();
  }

  /// Update presence stream with current data
  Future<void> _updatePresenceStream() async {
    try {
      final presenceMap = <String, List<Map<String, dynamic>>>{};
      
      for (final recipeId in _recipePresence.keys) {
        presenceMap[recipeId] = await getRecipePresence(recipeId);
      }
      
      _presenceController.add(presenceMap);
    } catch (e) {
      AppLogger.error('Failed to update presence stream', e);
    }
  }

  /// Start periodic presence cleanup
  void _startPresenceCleanup() {
    Timer.periodic(const Duration(minutes: 1), (_) {
      _cleanupStalePresence();
    });
  }

  /// Clean up stale presence data
  void _cleanupStalePresence() {
    final now = DateTime.now();
    const staleThreshold = Duration(minutes: 5);
    final keysToRemove = <String>[];
    
    for (final entry in _presenceTimestamps.entries) {
      if (now.difference(entry.value) > staleThreshold) {
        keysToRemove.add(entry.key);
      }
    }
    
    for (final key in keysToRemove) {
      _presenceTimestamps.remove(key);
      
      // Remove from recipe presence
      final parts = key.split('_');
      if (parts.length == 2) {
        final userId = parts[0];
        final recipeId = parts[1];
        _recipePresence[recipeId]?.remove(userId);
        
        if (_recipePresence[recipeId]?.isEmpty == true) {
          _recipePresence.remove(recipeId);
        }
      }
    }
    
    if (keysToRemove.isNotEmpty) {
      AppLogger.debug('Cleaned up ${keysToRemove.length} stale presence entries');
      _updatePresenceStream();
    }
  }

  /// Get user display name (simplified - would use user service)
  String _getUserDisplayName(String userId) {
    return 'User ${userId.substring(0, 6)}...';
  }

  /// Get user avatar URL (simplified - would use user service)
  String? _getUserAvatarUrl(String userId) {
    return null; // Would fetch from user service
  }

  /// Dispose resources
  void dispose() {
    _presenceController.close();
  }
}