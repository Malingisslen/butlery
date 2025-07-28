/// 🔍 AI INFO BLOCK:
/// Component: JsonCacheHelper - Eliminates JSON cache duplication in unified services
/// File: lib/core/cache/json_cache_helper.dart
/// Quick Guide: Centralizes the JSON + Hive pattern used by UnifiedRecipeService, UnifiedShoppingService, UnifiedFriendsService
/// Dependencies IN: Hive, Dart JSON, Logger utilities
/// Dependencies OUT: Used by unified services for consistent JSON caching
/// Data flow: Service -> JsonCacheHelper -> Hive String -> Local storage
/// State management: Stateless helper with user-specific box management
/// Purpose: Eliminate the duplicated JSON cache pattern found in 3 unified services
/// Common issues: JSON serialization errors, box management, user session cleanup
/// Test coverage: Unit tests for cache operations and JSON handling
/// Performance: Lazy box opening, efficient JSON operations, batch support
/// Analytics: Cache operations tracking, storage usage monitoring
/// Code smells: None - focused helper for specific existing pattern
/// Connected to: UnifiedRecipeService, UnifiedShoppingService, UnifiedFriendsService
/// Used in phases: Phase 6 - Eliminate Code Duplication Patterns

import 'dart:async';
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:butlery/core/utils/logger.dart';

/// Helper class that eliminates the JSON cache pattern duplicated across unified services
/// 
/// This helper centralizes the exact pattern used by:
/// - UnifiedRecipeService (_hiveBoxBaseName = 'unified_recipes_cache')
/// - UnifiedShoppingService (_hiveBoxBaseName = 'unified_shopping_lists_cache') 
/// - UnifiedFriendsService (_hiveBoxBaseName = 'unified_friends_cache')
/// 
/// Pattern eliminated:
/// ```dart
/// // Before (duplicated in 3 services):
/// String get _userSpecificBoxName => '${_hiveBoxBaseName}_${_authService.currentUserId}';
/// final box = await Hive.openBox<String>(_userSpecificBoxName);
/// await box.put(key, jsonEncode(data));
/// final cached = box.get(key);
/// final data = cached != null ? jsonDecode(cached) : null;
/// 
/// // After (centralized):
/// final helper = JsonCacheHelper('unified_recipes_cache');
/// await helper.saveJson(key, data);
/// final data = await helper.loadJson(key);
/// ```
class JsonCacheHelper {
  /// Base name for the Hive box (e.g., 'unified_recipes_cache')
  final String boxBaseName;
  
  /// Current user ID for user-specific box naming
  String? _currentUserId;
  
  /// Cached reference to the opened Hive box
  Box<String>? _box;
  
  JsonCacheHelper(this.boxBaseName);
  
  // ===== USER SESSION MANAGEMENT =====
  
  /// Set the current user ID (call when user logs in)
  void setCurrentUser(String? userId) {
    if (_currentUserId != userId) {
      _currentUserId = userId;
      _box = null; // Force box reopen with new user
    }
  }
  
  /// Get user-specific box name (matches existing pattern)
  String get _userSpecificBoxName {
    if (_currentUserId == null) {
      throw StateError('User not set - call setCurrentUser() first');
    }
    return '${boxBaseName}_$_currentUserId';
  }
  
  // ===== BOX MANAGEMENT =====
  
  /// Get or open the user-specific Hive box
  Future<Box<String>> get _openBox async {
    if (_box?.isOpen == true) {
      return _box!;
    }
    
    try {
      // Ensure Hive is initialized before opening boxes
      if (!Hive.isBoxOpen(_userSpecificBoxName)) {
        // Initialize Hive if not already done
        try {
          await Hive.initFlutter('butlery_cache');
        } catch (e) {
          // Hive might already be initialized, continue
          AppLogger.debug('Hive already initialized: $e');
        }
      }
      
      _box = await Hive.openBox<String>(_userSpecificBoxName);
      AppLogger.debug('Opened JSON cache box: $_userSpecificBoxName');
      return _box!;
    } catch (e) {
      AppLogger.error('Failed to open JSON cache box $_userSpecificBoxName: $e');
      rethrow;
    }
  }
  
  // ===== JSON CACHE OPERATIONS =====
  
  /// Save data as JSON (eliminates jsonEncode + box.put pattern)
  Future<bool> saveJson(String key, Map<String, dynamic> data) async {
    try {
      final box = await _openBox;
      final jsonString = jsonEncode(data);
      await box.put(key, jsonString);
      
      AppLogger.debug('Saved JSON to cache: $key in $_userSpecificBoxName');
      return true;
    } catch (e) {
      AppLogger.error('Failed to save JSON cache item $key: $e');
      return false;
    }
  }
  
  /// Load data from JSON (eliminates box.get + jsonDecode pattern)
  Future<Map<String, dynamic>?> loadJson(String key) async {
    try {
      final box = await _openBox;
      final jsonString = box.get(key);
      
      if (jsonString == null) {
        return null;
      }
      
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      AppLogger.debug('Loaded JSON from cache: $key from $_userSpecificBoxName');
      return data;
    } catch (e) {
      AppLogger.error('Failed to load JSON cache item $key: $e');
      return null;
    }
  }
  
  /// Save list of items as JSON (for bulk operations)
  Future<bool> saveJsonList(String key, List<Map<String, dynamic>> dataList) async {
    try {
      final box = await _openBox;
      final jsonString = jsonEncode(dataList);
      await box.put(key, jsonString);
      
      AppLogger.debug('Saved JSON list to cache: $key (${dataList.length} items) in $_userSpecificBoxName');
      return true;
    } catch (e) {
      AppLogger.error('Failed to save JSON list $key: $e');
      return false;
    }
  }
  
  /// Load list of items from JSON
  Future<List<Map<String, dynamic>>?> loadJsonList(String key) async {
    try {
      final box = await _openBox;
      final jsonString = box.get(key);
      
      if (jsonString == null) {
        return null;
      }
      
      final dataList = jsonDecode(jsonString) as List;
      final result = dataList.cast<Map<String, dynamic>>();
      AppLogger.debug('Loaded JSON list from cache: $key (${result.length} items) from $_userSpecificBoxName');
      return result;
    } catch (e) {
      AppLogger.error('Failed to load JSON list $key: $e');
      return null;
    }
  }
  
  /// Delete cached item
  Future<bool> delete(String key) async {
    try {
      final box = await _openBox;
      await box.delete(key);
      
      AppLogger.debug('Deleted cache item: $key from $_userSpecificBoxName');
      return true;
    } catch (e) {
      AppLogger.error('Failed to delete cache item $key: $e');
      return false;
    }
  }
  
  /// Check if key exists in cache
  Future<bool> exists(String key) async {
    try {
      final box = await _openBox;
      return box.containsKey(key);
    } catch (e) {
      AppLogger.error('Failed to check cache existence $key: $e');
      return false;
    }
  }
  
  /// Get all keys in cache
  Future<List<String>> getAllKeys() async {
    try {
      final box = await _openBox;
      return box.keys.cast<String>().toList();
    } catch (e) {
      AppLogger.error('Failed to get cache keys: $e');
      return [];
    }
  }
  
  /// Clear all cached data for current user
  Future<bool> clear() async {
    try {
      final box = await _openBox;
      await box.clear();
      
      AppLogger.info('Cleared all cache data from $_userSpecificBoxName');
      return true;
    } catch (e) {
      AppLogger.error('Failed to clear cache: $e');
      return false;
    }
  }
  
  /// Get cache statistics
  Future<JsonCacheStats> getStats() async {
    try {
      final box = await _openBox;
      final keys = box.keys.length;
      final boxName = _userSpecificBoxName;
      
      return JsonCacheStats(
        boxName: boxName,
        keyCount: keys,
        userId: _currentUserId,
      );
    } catch (e) {
      AppLogger.error('Failed to get cache stats: $e');
      return JsonCacheStats(
        boxName: _userSpecificBoxName,
        keyCount: 0,
        userId: _currentUserId,
      );
    }
  }
  
  // ===== BATCH OPERATIONS =====
  
  /// Save multiple JSON items in one operation
  Future<int> saveJsonBatch(Map<String, Map<String, dynamic>> items) async {
    int successCount = 0;
    
    try {
      final box = await _openBox;
      
      // Convert all to JSON strings
      final jsonBatch = <String, String>{};
      for (final entry in items.entries) {
        try {
          jsonBatch[entry.key] = jsonEncode(entry.value);
        } catch (e) {
          AppLogger.warning('Failed to encode item ${entry.key}: $e');
        }
      }
      
      // Batch write to Hive
      await box.putAll(jsonBatch);
      successCount = jsonBatch.length;
      
      AppLogger.info('Batch saved $successCount JSON items to $_userSpecificBoxName');
    } catch (e) {
      AppLogger.error('Failed to batch save JSON items: $e');
    }
    
    return successCount;
  }
  
  /// Load multiple JSON items
  Future<Map<String, Map<String, dynamic>>> loadJsonBatch(List<String> keys) async {
    final result = <String, Map<String, dynamic>>{};
    
    try {
      final box = await _openBox;
      
      for (final key in keys) {
        try {
          final jsonString = box.get(key);
          if (jsonString != null) {
            final data = jsonDecode(jsonString) as Map<String, dynamic>;
            result[key] = data;
          }
        } catch (e) {
          AppLogger.warning('Failed to decode item $key: $e');
        }
      }
      
      AppLogger.debug('Batch loaded ${result.length}/${keys.length} JSON items from $_userSpecificBoxName');
    } catch (e) {
      AppLogger.error('Failed to batch load JSON items: $e');
    }
    
    return result;
  }
  
  // ===== ACTIVE ITEM TRACKING =====
  // Special support for UnifiedShoppingService's _activeListKey pattern
  
  /// Save active item ID (for patterns like UnifiedShoppingService)
  Future<bool> saveActiveId(String activeKey, String? itemId) async {
    try {
      final box = await _openBox;
      
      if (itemId != null) {
        await box.put(activeKey, itemId);
        AppLogger.debug('Saved active ID: $activeKey = $itemId');
      } else {
        await box.delete(activeKey);
        AppLogger.debug('Cleared active ID: $activeKey');
      }
      
      return true;
    } catch (e) {
      AppLogger.error('Failed to save active ID $activeKey: $e');
      return false;
    }
  }
  
  /// Load active item ID
  Future<String?> loadActiveId(String activeKey) async {
    try {
      final box = await _openBox;
      final activeId = box.get(activeKey);
      
      if (activeId != null) {
        AppLogger.debug('Loaded active ID: $activeKey = $activeId');
      }
      
      return activeId;
    } catch (e) {
      AppLogger.error('Failed to load active ID $activeKey: $e');
      return null;
    }
  }
  
  // ===== CLEANUP =====
  
  /// Close the cache box and cleanup resources
  Future<void> dispose() async {
    try {
      await _box?.close();
      _box = null;
      AppLogger.debug('Disposed JSON cache helper: $boxBaseName');
    } catch (e) {
      AppLogger.error('Failed to dispose JSON cache helper: $e');
    }
  }
}

/// Cache statistics for monitoring JSON cache usage
class JsonCacheStats {
  final String boxName;
  final int keyCount;
  final String? userId;

  JsonCacheStats({
    required this.boxName,
    required this.keyCount,
    required this.userId,
  });

  @override
  String toString() {
    return 'JsonCacheStats($boxName: $keyCount items, user: $userId)';
  }
}

/// Factory for creating commonly used JSON cache helpers (matches existing service names)
class JsonCacheFactory {
  /// Create helper for UnifiedRecipeService
  static JsonCacheHelper recipeCache() {
    return JsonCacheHelper('unified_recipes_cache');
  }
  
  /// Create helper for UnifiedShoppingService  
  static JsonCacheHelper shoppingCache() {
    return JsonCacheHelper('unified_shopping_lists_cache');
  }
  
  /// Create helper for UnifiedFriendsService
  static JsonCacheHelper friendsCache() {
    return JsonCacheHelper('unified_friends_cache');
  }
  
  /// Create helper for any custom cache
  static JsonCacheHelper custom(String baseName) {
    return JsonCacheHelper(baseName);
  }
}