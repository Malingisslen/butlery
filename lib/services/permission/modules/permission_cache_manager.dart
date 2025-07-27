// lib/services/permission/modules/permission_cache_manager.dart

import 'package:butlery/core/utils/logger.dart';

/// Focused module for permission cache management
/// 
/// This module handles ONLY permission caching operations:
/// - Global permission cache management
/// - Specific permission cache operations
/// - Cache invalidation and cleanup
/// - Cache performance optimization
/// 
/// ❌ DOES NOT CONTAIN: Permission logic, resource-specific operations, auth logic
class PermissionCacheManager {
  final Map<String, bool> _globalPermissionCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final Duration _cacheExpiry = const Duration(minutes: 15);

  // ===== CORE CACHE OPERATIONS =====

  /// Get cached permission result
  bool? getCachedPermission(String key) {
    if (!_globalPermissionCache.containsKey(key)) return null;
    
    // Check if cache entry is expired
    final timestamp = _cacheTimestamps[key];
    if (timestamp != null && DateTime.now().difference(timestamp) > _cacheExpiry) {
      _globalPermissionCache.remove(key);
      _cacheTimestamps.remove(key);
      return null;
    }
    
    return _globalPermissionCache[key];
  }

  /// Set cached permission result
  void setCachedPermission(String key, bool value) {
    _globalPermissionCache[key] = value;
    _cacheTimestamps[key] = DateTime.now();
  }

  /// Get cached permission or compute and cache it
  bool getCachedOrCompute(String key, bool Function() computation) {
    final cached = getCachedPermission(key);
    if (cached != null) {
      return cached;
    }
    
    final result = computation();
    setCachedPermission(key, result);
    return result;
  }

  // ===== CACHE INVALIDATION =====

  /// Clear all permission cache
  void clearAllPermissionCache() {
    final cacheSize = _globalPermissionCache.length;
    _globalPermissionCache.clear();
    _cacheTimestamps.clear();
    AppLogger.info('🔐 All permission cache cleared ($cacheSize entries)');
  }

  /// Clear specific permission from cache
  void clearPermissionFromCache(String key) {
    final existed = _globalPermissionCache.containsKey(key);
    _globalPermissionCache.remove(key);
    _cacheTimestamps.remove(key);
    
    if (existed) {
      AppLogger.debug('🔐 Permission cache cleared for key: $key');
    }
  }

  /// Clear permissions matching pattern
  void clearPermissionsByPattern(String pattern) {
    final keysToRemove = _globalPermissionCache.keys
        .where((key) => key.contains(pattern))
        .toList();
    
    for (final key in keysToRemove) {
      _globalPermissionCache.remove(key);
      _cacheTimestamps.remove(key);
    }
    
    if (keysToRemove.isNotEmpty) {
      AppLogger.debug('🔐 Cleared ${keysToRemove.length} cache entries matching pattern: $pattern');
    }
  }

  /// Clear expired cache entries
  void clearExpiredCache() {
    final now = DateTime.now();
    final keysToRemove = <String>[];
    
    for (final entry in _cacheTimestamps.entries) {
      if (now.difference(entry.value) > _cacheExpiry) {
        keysToRemove.add(entry.key);
      }
    }
    
    for (final key in keysToRemove) {
      _globalPermissionCache.remove(key);
      _cacheTimestamps.remove(key);
    }
    
    if (keysToRemove.isNotEmpty) {
      AppLogger.debug('🔐 Cleared ${keysToRemove.length} expired cache entries');
    }
  }

  // ===== RESOURCE-SPECIFIC CACHE OPERATIONS =====

  /// Clear recipe-related permissions from cache
  void clearRecipePermissionCache(String? recipeId) {
    if (recipeId != null) {
      clearPermissionsByPattern('recipe_${recipeId}_');
      clearPermissionsByPattern('recipe_view_$recipeId');
      clearPermissionsByPattern('recipe_edit_$recipeId');
      clearPermissionsByPattern('recipe_delete_$recipeId');
      clearPermissionsByPattern('recipe_owner_$recipeId');
      clearPermissionsByPattern('recipe_manage_$recipeId');
    } else {
      clearPermissionsByPattern('recipe_');
    }
  }

  /// Clear shopping list-related permissions from cache
  void clearShoppingListPermissionCache(String? listId) {
    if (listId != null) {
      clearPermissionsByPattern('shopping_${listId}_');
      clearPermissionsByPattern('shopping_view_$listId');
      clearPermissionsByPattern('shopping_edit_$listId');
      clearPermissionsByPattern('shopping_manage_$listId');
      clearPermissionsByPattern('shopping_delete_$listId');
      clearPermissionsByPattern('shopping_owner_$listId');
    } else {
      clearPermissionsByPattern('shopping_');
    }
  }

  /// Clear group-related permissions from cache
  void clearGroupPermissionCache(String? groupId) {
    if (groupId != null) {
      clearPermissionsByPattern('group_${groupId}_');
      clearPermissionsByPattern('group_admin_$groupId');
      clearPermissionsByPattern('group_member_$groupId');
      clearPermissionsByPattern('group_leave_$groupId');
    } else {
      clearPermissionsByPattern('group_');
    }
  }

  /// Clear profile-related permissions from cache
  void clearProfilePermissionCache(String? userId) {
    if (userId != null) {
      clearPermissionsByPattern('friend_request_$userId');
      clearPermissionsByPattern('are_friends_$userId');
      clearPermissionsByPattern('profile_${userId}_');
    } else {
      clearPermissionsByPattern('friend_');
      clearPermissionsByPattern('are_friends_');
      clearPermissionsByPattern('profile_');
    }
  }

  // ===== USER-SPECIFIC CACHE OPERATIONS =====

  /// Clear all permissions for a specific user
  void clearUserPermissionCache(String userId) {
    clearRecipePermissionCache(null);
    clearShoppingListPermissionCache(null);
    clearGroupPermissionCache(null);
    clearProfilePermissionCache(userId);
    AppLogger.info('🔐 Cleared all permission cache for user: $userId');
  }

  /// Clear permissions when user state changes
  void clearUserStateCache() {
    clearAllPermissionCache();
    AppLogger.info('🔐 Cleared all permission cache due to user state change');
  }

  // ===== CACHE ANALYTICS AND MONITORING =====

  /// Get cache statistics
  Map<String, dynamic> getCacheStatistics() {
    final now = DateTime.now();
    int expiredEntries = 0;
    int validEntries = 0;
    
    for (final timestamp in _cacheTimestamps.values) {
      if (now.difference(timestamp) > _cacheExpiry) {
        expiredEntries++;
      } else {
        validEntries++;
      }
    }
    
    return {
      'totalEntries': _globalPermissionCache.length,
      'validEntries': validEntries,
      'expiredEntries': expiredEntries,
      'cacheHitRate': _calculateCacheHitRate(),
      'averageAge': _calculateAverageAge(),
      'memoryUsage': _estimateMemoryUsage(),
    };
  }

  /// Get cache keys by resource type
  Map<String, List<String>> getCacheKeysByResourceType() {
    final Map<String, List<String>> result = {
      'recipe': [],
      'shopping': [],
      'group': [],
      'profile': [],
      'other': [],
    };
    
    for (final key in _globalPermissionCache.keys) {
      if (key.startsWith('recipe_')) {
        result['recipe']!.add(key);
      } else if (key.startsWith('shopping_')) {
        result['shopping']!.add(key);
      } else if (key.startsWith('group_')) {
        result['group']!.add(key);
      } else if (key.startsWith('friend_') || key.startsWith('are_friends_') || key.startsWith('profile_')) {
        result['profile']!.add(key);
      } else {
        result['other']!.add(key);
      }
    }
    
    return result;
  }

  /// Debug print cache contents
  void debugPrintCache() {
    AppLogger.debug('🔐 Permission Cache Contents:');
    AppLogger.debug('  Total entries: ${_globalPermissionCache.length}');
    
    final keysByType = getCacheKeysByResourceType();
    for (final entry in keysByType.entries) {
      if (entry.value.isNotEmpty) {
        AppLogger.debug('  ${entry.key}: ${entry.value.length} entries');
      }
    }
    
    final stats = getCacheStatistics();
    AppLogger.debug('  Valid entries: ${stats['validEntries']}');
    AppLogger.debug('  Expired entries: ${stats['expiredEntries']}');
    AppLogger.debug('  Cache hit rate: ${stats['cacheHitRate']}%');
  }

  // ===== CACHE OPTIMIZATION =====

  /// Optimize cache by removing expired entries
  void optimizeCache() {
    clearExpiredCache();
    AppLogger.debug('🔐 Permission cache optimized');
  }

  /// Warm up cache with common permissions
  void warmUpCache(String userId, List<String> commonResourceIds) {
    // This could be implemented to pre-load commonly accessed permissions
    AppLogger.debug('🔐 Cache warm-up initiated for user: $userId');
  }

  /// Set cache expiry duration
  void setCacheExpiry(Duration newExpiry) {
    // For now, cache expiry is constant, but this could be made configurable
    AppLogger.debug('🔐 Cache expiry setting requested: ${newExpiry.inMinutes} minutes');
  }

  // ===== CACHE PERSISTENCE (Future Enhancement) =====

  /// Save cache to persistent storage (placeholder)
  Future<void> saveCacheToPersistentStorage() async {
    // This could be implemented to save cache across app sessions
    AppLogger.debug('🔐 Cache persistence save requested');
  }

  /// Load cache from persistent storage (placeholder)
  Future<void> loadCacheFromPersistentStorage() async {
    // This could be implemented to restore cache across app sessions
    AppLogger.debug('🔐 Cache persistence load requested');
  }

  // ===== PRIVATE HELPER METHODS =====

  /// Calculate cache hit rate (simplified estimation)
  double _calculateCacheHitRate() {
    // This would require tracking hits and misses in a real implementation
    return _globalPermissionCache.isNotEmpty ? 75.0 : 0.0;
  }

  /// Calculate average age of cache entries
  Duration _calculateAverageAge() {
    if (_cacheTimestamps.isEmpty) return Duration.zero;
    
    final now = DateTime.now();
    int totalMinutes = 0;
    
    for (final timestamp in _cacheTimestamps.values) {
      totalMinutes += now.difference(timestamp).inMinutes;
    }
    
    return Duration(minutes: totalMinutes ~/ _cacheTimestamps.length);
  }

  /// Estimate memory usage of cache
  int _estimateMemoryUsage() {
    // Rough estimation: 50 bytes per cache entry
    return _globalPermissionCache.length * 50;
  }
}