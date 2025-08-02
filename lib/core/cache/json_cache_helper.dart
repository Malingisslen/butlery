import 'dart:async';
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:butlery/core/utils/logger.dart';

class JsonCacheHelper {
  final String boxBaseName;
  
  String? _currentUserId;
  
  Box<String>? _box;
  
  JsonCacheHelper(this.boxBaseName);
  
  void setCurrentUser(String? userId) {
    if (_currentUserId != userId) {
      _currentUserId = userId;
      _box = null;
    }
  }
  
  String get _userSpecificBoxName {
    if (_currentUserId == null) {
      throw StateError('User not set - call setCurrentUser() first');
    }
    return '${boxBaseName}_$_currentUserId';
  }
  
  Future<Box<String>> get _openBox async {
    if (_box?.isOpen == true) {
      return _box!;
    }
    
    try {
      if (!Hive.isBoxOpen(_userSpecificBoxName)) {
        try {
          await Hive.initFlutter('butlery_cache');
        } catch (e) {
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
  
  Future<bool> exists(String key) async {
    try {
      final box = await _openBox;
      return box.containsKey(key);
    } catch (e) {
      AppLogger.error('Failed to check cache existence $key: $e');
      return false;
    }
  }
  
  Future<List<String>> getAllKeys() async {
    try {
      final box = await _openBox;
      return box.keys.cast<String>().toList();
    } catch (e) {
      AppLogger.error('Failed to get cache keys: $e');
      return [];
    }
  }
  
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
  
  Future<int> saveJsonBatch(Map<String, Map<String, dynamic>> items) async {
    int successCount = 0;
    
    try {
      final box = await _openBox;
      
      final jsonBatch = <String, String>{};
      for (final entry in items.entries) {
        try {
          jsonBatch[entry.key] = jsonEncode(entry.value);
        } catch (e) {
          AppLogger.warning('Failed to encode item ${entry.key}: $e');
        }
      }
      
      await box.putAll(jsonBatch);
      successCount = jsonBatch.length;
      
      AppLogger.info('Batch saved $successCount JSON items to $_userSpecificBoxName');
    } catch (e) {
      AppLogger.error('Failed to batch save JSON items: $e');
    }
    
    return successCount;
  }
  
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

class JsonCacheFactory {
  static JsonCacheHelper recipeCache() {
    return JsonCacheHelper('unified_recipes_cache');
  }
  
  static JsonCacheHelper shoppingCache() {
    return JsonCacheHelper('unified_shopping_lists_cache');
  }
  
  static JsonCacheHelper friendsCache() {
    return JsonCacheHelper('unified_friends_cache');
  }
  
  static JsonCacheHelper custom(String baseName) {
    return JsonCacheHelper(baseName);
  }
}